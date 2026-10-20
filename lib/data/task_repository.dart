import '../domain/planner.dart';

abstract interface class TaskRepository {
  Future<List<PlanoTask>> loadTasks();

  Future<void> saveTasks(List<PlanoTask> tasks);

  Future<void> softDeleteTask(String id);

  Future<void> clearLocalAccountData({required bool deleteTasks});
}

enum SyncOperationType { create, update, delete }

class SyncQueueOperation {
  const SyncQueueOperation({
    required this.id,
    required this.entity,
    required this.entityId,
    required this.type,
    required this.payload,
    required this.attempts,
    required this.nextAttemptAt,
  });

  final int id;
  final String entity;
  final String entityId;
  final SyncOperationType type;
  final Map<String, Object?> payload;
  final int attempts;
  final DateTime? nextAttemptAt;
}

enum RemoteMergeResult { remoteApplied, localKept }

abstract interface class SyncTaskRepository implements TaskRepository {
  Future<List<SyncQueueOperation>> loadSyncQueue();

  Future<int> countPendingSyncOperations();

  Future<int> countFailedSyncOperations();

  Future<void> completeSyncOperation(int id);

  Future<void> failSyncOperation(
    int id, {
    required String error,
    required int maxAttempts,
    required DateTime retryAt,
  });

  Future<void> retryFailedSyncOperations();

  Future<DateTime?> loadSyncCursor();

  Future<void> saveSyncCursor(DateTime cursor);

  Future<RemoteMergeResult> mergeRemoteTask(PlanoTask task);
}
