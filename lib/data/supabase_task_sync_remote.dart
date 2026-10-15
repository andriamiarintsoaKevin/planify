import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/planner.dart';
import 'task_sync_service.dart';

class SupabaseTaskSyncRemote implements TaskSyncRemote {
  SupabaseTaskSyncRemote(this._client);

  final SupabaseClient _client;

  @override
  Future<void> upsertTask(Map<String, Object?> task) async {
    await _client.from('tasks').upsert(task, onConflict: 'id');
  }

  @override
  Future<List<PlanoTask>> fetchTasks({
    required DateTime updatedAfter,
    required DateTime updatedThrough,
    required DateTime? afterUpdatedAt,
    required String? afterId,
    required int pageSize,
  }) async {
    final baseQuery = _client
        .from('tasks')
        .select()
        .gt('updated_at', updatedAfter.toUtc().toIso8601String())
        .lte('updated_at', updatedThrough.toUtc().toIso8601String());
    final pageQuery = afterUpdatedAt == null || afterId == null
        ? baseQuery
        : baseQuery.or(
            'updated_at.gt.${afterUpdatedAt.toUtc().toIso8601String()},'
            'and(updated_at.eq.${afterUpdatedAt.toUtc().toIso8601String()},'
            'id.gt.$afterId)',
          );
    final rows = await pageQuery
        .order('updated_at', ascending: true)
        .order('id', ascending: true)
        .range(0, pageSize - 1);
    return rows.map(_taskFromRemoteRow).toList(growable: false);
  }

  PlanoTask _taskFromRemoteRow(Map<String, dynamic> row) => PlanoTask(
    id: row['id'] as String,
    title: row['title'] as String,
    notes: row['notes'] as String,
    durationMinutes: row['duration_minutes'] as int?,
    priority: TaskPriority.values.byName(row['priority'] as String),
    dueDate: _dateTime(row['due_date']),
    status: TaskStatus.values.byName(row['status'] as String),
    scheduledStart: _dateTime(row['scheduled_start']),
    plannedEnd: _dateTime(row['planned_end']),
    project: row['project'] as String,
    isLocked: row['is_locked'] as bool,
    isAiProposed: row['is_ai_proposed'] as bool,
    isDurationEstimated: row['is_duration_estimated'] as bool,
    reminderEnabled: row['reminder_enabled'] as bool,
    createdAt: _dateTime(row['created_at']),
    updatedAt: _dateTime(row['updated_at']),
    deletedAt: _dateTime(row['deleted_at']),
  );

  DateTime? _dateTime(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}

class ConnectivitySyncNetworkMonitor implements SyncNetworkMonitor {
  ConnectivitySyncNetworkMonitor([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> get isOnline async => (await _connectivity.checkConnectivity())
      .any((result) => result != ConnectivityResult.none);

  @override
  Stream<bool> get connectivityChanges =>
      _connectivity.onConnectivityChanged.map(
        (results) => results.any((result) => result != ConnectivityResult.none),
      );
}
