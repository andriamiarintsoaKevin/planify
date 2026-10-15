import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../domain/planner.dart';
import 'auth_repository.dart';
import 'task_repository.dart';

enum SyncStatus { upToDate, pending, error, offline }

abstract interface class TaskSyncRemote {
  Future<void> upsertTask(Map<String, Object?> task);

  Future<List<PlanoTask>> fetchTasks({
    required DateTime updatedAfter,
    required DateTime updatedThrough,
    required DateTime? afterUpdatedAt,
    required String? afterId,
    required int pageSize,
  });
}

abstract interface class SyncNetworkMonitor {
  Future<bool> get isOnline;

  Stream<bool> get connectivityChanges;
}

class TaskSyncService extends ChangeNotifier {
  TaskSyncService({
    required this._repository,
    required this._remote,
    required this._network,
    required this._authRepository,
    this.maxAttempts = 5,
    this.pageSize = 100,
  });

  static const _baseRetryDelay = Duration(seconds: 2);
  static const _maxRetryDelay = Duration(minutes: 30);

  final SyncTaskRepository _repository;
  final TaskSyncRemote _remote;
  final SyncNetworkMonitor _network;
  final AuthRepository _authRepository;
  final int maxAttempts;
  final int pageSize;
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<dynamic>? _authSubscription;
  Timer? _retryTimer;
  bool _online = false;
  bool _authenticated = false;
  bool _running = false;
  bool _syncRequested = false;
  Completer<void>? _activeSync;
  bool _lastSyncFailed = false;
  bool _disposed = false;
  int _consecutivePullFailures = 0;
  int _remoteChangesVersion = 0;
  SyncStatus _status = SyncStatus.offline;

  SyncStatus get status => _status;
  int get remoteChangesVersion => _remoteChangesVersion;

  Future<void> start() async {
    _connectivitySubscription ??= _network.connectivityChanges.listen(
      (online) {
        _online = online;
        if (online) unawaited(syncNow());
        unawaited(_refreshStatus());
      },
      onError: (Object error) {
        _lastSyncFailed = true;
        unawaited(_refreshStatus());
      },
    );
    _authSubscription ??= _authRepository.authStateChanges.listen(
      (_) {
        _authenticated = _authRepository.currentUser != null;
        if (_authenticated) unawaited(syncNow());
        unawaited(_refreshStatus());
      },
      onError: (Object error) {
        _lastSyncFailed = true;
        unawaited(_refreshStatus());
      },
    );
    try {
      _online = await _network.isOnline;
      _authenticated = _authRepository.currentUser != null;
      await _refreshStatus();
      if (_online && _authenticated) await syncNow();
    } on Object {
      _lastSyncFailed = true;
      await _refreshStatus();
    }
  }

  Future<void> syncNow() async {
    if (_disposed) return;
    if (_running) {
      _syncRequested = true;
      await _activeSync?.future;
      return;
    }
    if (!_online || !_authenticated) {
      await _refreshStatus();
      return;
    }
    _running = true;
    final completion = Completer<void>();
    _activeSync = completion;
    _retryTimer?.cancel();
    try {
      await _refreshStatus();
      await _pullRemoteChanges();
      _consecutivePullFailures = 0;
      _lastSyncFailed = false;
      final operations = await _repository.loadSyncQueue();
      for (final operation in operations) {
        final retryAt = operation.nextAttemptAt;
        if (retryAt != null && retryAt.isAfter(DateTime.now())) {
          _scheduleRetry(retryAt.difference(DateTime.now()));
          break;
        }
        try {
          if (operation.entity != 'task') {
            throw UnsupportedError('Entité de synchronisation inconnue');
          }
          await _remote.upsertTask(operation.payload);
          await _repository.completeSyncOperation(operation.id);
        } on Object catch (error) {
          final nextAttempt = operation.attempts + 1;
          final delay = _retryDelay(nextAttempt);
          await _repository.failSyncOperation(
            operation.id,
            error: error.runtimeType.toString(),
            maxAttempts: maxAttempts,
            retryAt: DateTime.now().add(delay),
          );
          _lastSyncFailed = nextAttempt >= maxAttempts;
          if (!_lastSyncFailed) _scheduleRetry(delay);
          break;
        }
      }
    } on Object {
      _lastSyncFailed = true;
      _consecutivePullFailures += 1;
      _scheduleRetry(_retryDelay(_consecutivePullFailures));
    } finally {
      _running = false;
      _activeSync = null;
      try {
        await _refreshStatus();
      } finally {
        completion.complete();
        if (_syncRequested && !_disposed) {
          _syncRequested = false;
          unawaited(syncNow());
        }
      }
    }
  }

  Future<void> retryFailedOperations() async {
    await _repository.retryFailedSyncOperations();
    _lastSyncFailed = false;
    await syncNow();
  }

  Future<void> _pullRemoteChanges() async {
    final cursor =
        await _repository.loadSyncCursor() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final upperBound = DateTime.now().toUtc();
    DateTime? afterUpdatedAt;
    String? afterId;
    var hasRemoteChanges = false;
    while (true) {
      final page = await _remote.fetchTasks(
        updatedAfter: cursor,
        updatedThrough: upperBound,
        afterUpdatedAt: afterUpdatedAt,
        afterId: afterId,
        pageSize: pageSize,
      );
      for (final task in page) {
        final result = await _repository.mergeRemoteTask(task);
        if (result == RemoteMergeResult.remoteApplied) {
          hasRemoteChanges = true;
        }
      }
      if (page.length < pageSize) break;
      final lastUpdatedAt = page.last.updatedAt;
      if (lastUpdatedAt == null) {
        throw const FormatException('updated_at absent dans une page distante');
      }
      afterUpdatedAt = lastUpdatedAt;
      afterId = page.last.id;
    }
    await _repository.saveSyncCursor(upperBound);
    if (hasRemoteChanges) {
      _remoteChangesVersion += 1;
      notifyListeners();
    }
  }

  Duration _retryDelay(int attempt) {
    final multiplier = math.pow(2, math.max(0, attempt - 1)).toInt();
    final milliseconds = _baseRetryDelay.inMilliseconds * multiplier;
    return Duration(
      milliseconds: math.min(milliseconds, _maxRetryDelay.inMilliseconds),
    );
  }

  void _scheduleRetry(Duration delay) {
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(syncNow()));
  }

  Future<void> _refreshStatus() async {
    if (_disposed) return;
    final pending = await _repository.countPendingSyncOperations();
    if (_disposed) return;
    final failed = await _repository.countFailedSyncOperations();
    if (_disposed) return;
    final nextStatus = !_online || !_authenticated
        ? SyncStatus.offline
        : failed > 0 || _lastSyncFailed
        ? SyncStatus.error
        : pending > 0
        ? SyncStatus.pending
        : SyncStatus.upToDate;
    if (_status == nextStatus) return;
    _status = nextStatus;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    unawaited(_connectivitySubscription?.cancel());
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }
}
