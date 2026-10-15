import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:planify/data/auth_repository.dart';
import 'package:planify/data/sqlite_planify_repository.dart';
import 'package:planify/data/task_sync_service.dart';
import 'package:planify/domain/planner.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfi, sqfliteFfiInit;
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState, User;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory temporaryDirectory;
  late SqlitePlanifyRepository repository;
  late _FakeNetwork network;
  late _FakeRemote remote;
  late TaskSyncService service;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'planify_sync_test_',
    );
    repository = SqlitePlanifyRepository(
      databasePath: path.join(temporaryDirectory.path, 'planify.db'),
    );
    network = _FakeNetwork();
    remote = _FakeRemote();
    service = TaskSyncService(
      repository: repository,
      remote: remote,
      network: network,
      authRepository: _FakeAuthRepository(),
    );
  });

  tearDown(() async {
    service.dispose();
    await network.close();
    await repository.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('envoie une tâche créée hors ligne à la reconnexion', () async {
    await repository.saveTasks(const [
      PlanoTask(id: 'offline-task', title: 'Créée hors ligne'),
    ]);
    network.online = false;
    await service.start();

    expect(remote.tasks, isEmpty);
    network.setOnline(true);
    await service.syncNow();
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(remote.tasks.keys, contains('offline-task'));
    expect(await repository.countPendingSyncOperations(), 0);
  });

  test('un double envoi reste idempotent par UUID', () async {
    await repository.saveTasks(const [
      PlanoTask(id: 'same-id', title: 'Une seule tâche'),
    ]);
    await service.start();
    await service.syncNow();

    expect(remote.tasks, hasLength(1));
    expect(remote.upsertCount, 1);
  });

  test('récupère chaque tâche distante à travers plusieurs pages', () async {
    service.dispose();
    service = TaskSyncService(
      repository: repository,
      remote: remote,
      network: network,
      authRepository: _FakeAuthRepository(),
      pageSize: 2,
    );
    final now = DateTime.now().toUtc();
    for (var index = 0; index < 5; index++) {
      remote.seed(
        PlanoTask(
          id: 'page-$index',
          title: 'Tâche $index',
          createdAt: now,
          updatedAt: now.add(Duration(milliseconds: index)),
        ),
      );
    }
    await service.start();

    expect(await repository.loadTasks(), hasLength(5));
  });

  test(
    'une version distante plus récente remplace la version locale',
    () async {
      await repository.saveTasks(const [
        PlanoTask(id: 'conflict', title: 'Ancienne version locale'),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      remote.seed(
        PlanoTask(
          id: 'conflict',
          title: 'Version distante récente',
          createdAt: DateTime.utc(2026),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      await service.start();

      expect(
        (await repository.loadTasks()).single.title,
        'Version distante récente',
      );
      expect(await repository.countPendingSyncOperations(), 0);
      expect(service.remoteChangesVersion, 1);
    },
  );

  test('la suppression synchronisée reste un tombstone', () async {
    const task = PlanoTask(id: 'deleted-task', title: 'À supprimer');
    await repository.saveTasks([task]);
    await service.start();
    await repository.softDeleteTask(task.id);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    remote.seed(
      task.copyWith(
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.now().toUtc(),
      ),
    );
    await service.syncNow();

    expect(await repository.loadTasks(), isEmpty);
    expect(remote.tasks[task.id]?['deleted_at'], isNotNull);
    expect(await repository.countPendingSyncOperations(), 0);
  });

  test(
    'une perte réseau pendant un envoi conserve la reprise en attente',
    () async {
      await repository.saveTasks(const [
        PlanoTask(id: 'retry-task', title: 'À reprendre'),
      ]);
      remote.failNextUpsert = true;
      await service.start();

      final queue = await repository.loadSyncQueue();
      expect(queue, hasLength(1));
      expect(queue.single.attempts, 1);
      expect(queue.single.nextAttemptAt, isNotNull);
      expect(remote.tasks, isEmpty);
    },
  );
}

class _FakeNetwork implements SyncNetworkMonitor {
  final StreamController<bool> _controller = StreamController<bool>.broadcast(
    sync: true,
  );
  bool online = true;

  @override
  Future<bool> get isOnline async => online;

  @override
  Stream<bool> get connectivityChanges => _controller.stream;

  void setOnline(bool value) {
    online = value;
    _controller.add(value);
  }

  Future<void> close() => _controller.close();
}

class _FakeAuthRepository implements AuthRepository {
  @override
  User? get currentUser => User.fromJson({
    'id': '00000000-0000-4000-8000-000000000001',
    'aud': 'authenticated',
    'created_at': DateTime.utc(2026).toIso8601String(),
    'app_metadata': <String, dynamic>{},
    'user_metadata': <String, dynamic>{},
  });

  @override
  Stream<AuthState> get authStateChanges => const Stream<AuthState>.empty();

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}
}

class _FakeRemote implements TaskSyncRemote {
  final Map<String, Map<String, Object?>> tasks = {};
  int upsertCount = 0;
  bool failNextUpsert = false;

  void seed(PlanoTask task) {
    tasks[task.id] = _taskToMap(task);
  }

  @override
  Future<void> upsertTask(Map<String, Object?> task) async {
    upsertCount += 1;
    if (failNextUpsert) {
      failNextUpsert = false;
      throw const SocketException('temporary network failure');
    }
    final id = task['id']! as String;
    final existing = tasks[id];
    if (existing == null || _shouldReplace(existing, task)) {
      tasks[id] = Map<String, Object?>.from(task);
    }
  }

  bool _shouldReplace(
    Map<String, Object?> existing,
    Map<String, Object?> incoming,
  ) {
    final existingDeleted = existing['deleted_at'] != null;
    final incomingDeleted = incoming['deleted_at'] != null;
    if (existingDeleted && !incomingDeleted) return false;
    if (incomingDeleted && !existingDeleted) return true;
    return DateTime.parse(incoming['updated_at']! as String)
        .isAfter(DateTime.parse(existing['updated_at']! as String));
  }

  @override
  Future<List<PlanoTask>> fetchTasks({
    required DateTime updatedAfter,
    required DateTime updatedThrough,
    required DateTime? afterUpdatedAt,
    required String? afterId,
    required int pageSize,
  }) async {
    final rows =
        tasks.values.where((row) {
          final updated = DateTime.parse(row['updated_at']! as String);
          final isAfterPageCursor =
              afterUpdatedAt == null ||
              afterId == null ||
              updated.isAfter(afterUpdatedAt) ||
              (updated.isAtSameMomentAs(afterUpdatedAt) &&
                  (row['id']! as String).compareTo(afterId) > 0);
          return updated.isAfter(updatedAfter) &&
              !updated.isAfter(updatedThrough) &&
              isAfterPageCursor;
        }).toList()..sort((first, second) {
          final byUpdatedAt = DateTime.parse(first['updated_at']! as String)
              .compareTo(DateTime.parse(second['updated_at']! as String));
          return byUpdatedAt != 0
              ? byUpdatedAt
              : (first['id']! as String).compareTo(second['id']! as String);
        });
    return rows.take(pageSize).map(_taskFromMap).toList(growable: false);
  }

  Map<String, Object?> _taskToMap(PlanoTask task) => {
    'id': task.id,
    'title': task.title,
    'notes': task.notes,
    'duration_minutes': task.durationMinutes,
    'priority': task.priority.name,
    'due_date': task.dueDate?.toUtc().toIso8601String(),
    'status': task.status.name,
    'scheduled_start': task.scheduledStart?.toUtc().toIso8601String(),
    'planned_end': task.plannedEnd?.toUtc().toIso8601String(),
    'project': task.project,
    'is_locked': task.isLocked,
    'is_ai_proposed': task.isAiProposed,
    'is_duration_estimated': task.isDurationEstimated,
    'reminder_enabled': task.reminderEnabled,
    'created_at': task.createdAt?.toUtc().toIso8601String(),
    'updated_at': task.updatedAt?.toUtc().toIso8601String(),
    'deleted_at': task.deletedAt?.toUtc().toIso8601String(),
  };

  PlanoTask _taskFromMap(Map<String, Object?> row) => PlanoTask(
    id: row['id']! as String,
    title: row['title']! as String,
    notes: row['notes']! as String,
    durationMinutes: row['duration_minutes'] as int?,
    priority: TaskPriority.values.byName(row['priority']! as String),
    dueDate: _dateTime(row['due_date']),
    status: TaskStatus.values.byName(row['status']! as String),
    scheduledStart: _dateTime(row['scheduled_start']),
    plannedEnd: _dateTime(row['planned_end']),
    project: row['project']! as String,
    isLocked: row['is_locked']! as bool,
    isAiProposed: row['is_ai_proposed']! as bool,
    isDurationEstimated: row['is_duration_estimated']! as bool,
    reminderEnabled: row['reminder_enabled']! as bool,
    createdAt: _dateTime(row['created_at']),
    updatedAt: _dateTime(row['updated_at']),
    deletedAt: _dateTime(row['deleted_at']),
  );

  DateTime? _dateTime(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}
