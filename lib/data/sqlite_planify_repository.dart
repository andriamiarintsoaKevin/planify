import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/planner.dart';
import 'ai_task_service.dart';
import 'database_initializer.dart';
import 'plano_repository.dart';
import 'task_id.dart';
import 'task_repository.dart';

class SqlitePlanifyRepository implements PlanoRepository, SyncTaskRepository {
  static const _taskContentColumns = [
    'title',
    'notes',
    'duration_minutes',
    'priority',
    'due_date',
    'status',
    'scheduled_start',
    'planned_end',
    'project',
    'is_locked',
    'is_ai_proposed',
    'is_duration_estimated',
    'reminder_enabled',
    'deleted_at',
  ];

  SqlitePlanifyRepository({this.databasePath});

  final String? databasePath;
  Database? _database;
  Future<Database>? _openingDatabase;

  @override
  Future<List<PlanoTask>> loadTasks() async {
    final rows = await (await _db).query(
      'tasks',
      where: 'deleted_at IS NULL',
      orderBy: 'rowid ASC',
    );
    return List.unmodifiable(rows.map(_taskFromRow));
  }

  @override
  Future<void> saveTasks(List<PlanoTask> tasks) async {
    final database = await _db;
    await database.transaction((transaction) async {
      final now = DateTime.now().toUtc().toIso8601String();
      for (final task in tasks) {
        final existingRows = await transaction.query(
          'tasks',
          where: 'id = ?',
          whereArgs: [task.id],
          limit: 1,
        );
        final existing = existingRows.isEmpty ? null : existingRows.single;
        if (existing?['deleted_at'] != null) continue;
        final createdAt =
            existing?['created_at'] as String? ??
            task.createdAt?.toUtc().toIso8601String() ??
            now;
        final row = _taskToRow(
          task.copyWith(createdAt: DateTime.parse(createdAt)),
          now,
        );
        final hasChanged =
            existing == null ||
            _taskContentColumns.any(
              (column) => existing[column] != row[column],
            );
        if (!hasChanged) continue;
        await transaction.insert(
          'tasks',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _enqueue(
          transaction,
          task.copyWith(
            createdAt: DateTime.parse(createdAt),
            updatedAt: DateTime.parse(now),
            deletedAt: null,
          ),
          existing == null
              ? SyncOperationType.create
              : SyncOperationType.update,
        );
      }
    });
  }

  @override
  Future<void> softDeleteTask(String id) async {
    final database = await _db;
    await database.transaction((transaction) async {
      final rows = await transaction.query(
        'tasks',
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final now = DateTime.now().toUtc();
      final nowIso = now.toIso8601String();
      await transaction.update(
        'tasks',
        {'deleted_at': nowIso, 'updated_at': nowIso},
        where: 'id = ?',
        whereArgs: [id],
      );
      final deleted = _taskFromRow({
        ...rows.single,
        'deleted_at': nowIso,
        'updated_at': nowIso,
      });
      await _enqueue(transaction, deleted, SyncOperationType.delete);
    });
  }

  @override
  Future<void> clearLocalAccountData({required bool deleteTasks}) async {
    final database = await _db;
    await database.transaction((transaction) async {
      await transaction.delete('sync_queue');
      await transaction.delete('sync_metadata');
      if (deleteTasks) {
        await transaction.delete('tasks');
        await transaction.delete('preferences');
        await transaction.delete('calendar_settings');
      }
    });
  }

  @override
  Future<List<SyncQueueOperation>> loadSyncQueue() async {
    final rows = await (await _db).query(
      'sync_queue',
      where: 'state = ?',
      whereArgs: ['pending'],
      orderBy: 'id ASC',
    );
    return [
      for (final row in rows)
        SyncQueueOperation(
          id: row['id']! as int,
          entity: row['entity']! as String,
          entityId: row['entity_id']! as String,
          type: SyncOperationType.values.byName(row['type']! as String),
          payload: Map<String, Object?>.from(
            jsonDecode(row['payload']! as String) as Map,
          ),
          attempts: row['attempts']! as int,
          nextAttemptAt: _dateTimeFromStorage(
            row['next_attempt_at'] as String?,
          ),
        ),
    ];
  }

  @override
  Future<int> countPendingSyncOperations() async =>
      Sqflite.firstIntValue(
        await (await _db).rawQuery(
          "SELECT COUNT(*) FROM sync_queue WHERE state = 'pending'",
        ),
      ) ??
      0;

  @override
  Future<int> countFailedSyncOperations() async =>
      Sqflite.firstIntValue(
        await (await _db).rawQuery(
          "SELECT COUNT(*) FROM sync_queue WHERE state = 'error'",
        ),
      ) ??
      0;

  @override
  Future<void> completeSyncOperation(int id) async {
    await (await _db).delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> failSyncOperation(
    int id, {
    required String error,
    required int maxAttempts,
    required DateTime retryAt,
  }) async {
    final database = await _db;
    await database.transaction((transaction) async {
      final rows = await transaction.query(
        'sync_queue',
        columns: ['attempts'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final attempts = (rows.single['attempts']! as int) + 1;
      await transaction.update(
        'sync_queue',
        {
          'attempts': attempts,
          'last_error': error,
          'state': attempts >= maxAttempts ? 'error' : 'pending',
          'next_attempt_at': retryAt.toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  @override
  Future<void> retryFailedSyncOperations() async {
    await (await _db).update('sync_queue', {
      'attempts': 0,
      'last_error': null,
      'state': 'pending',
      'next_attempt_at': null,
    }, where: "state = 'error'");
  }

  @override
  Future<DateTime?> loadSyncCursor() async {
    final rows = await (await _db).query(
      'sync_metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['task_sync_cursor'],
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : _dateTimeFromStorage(rows.single['value'] as String?);
  }

  @override
  Future<void> saveSyncCursor(DateTime cursor) async {
    await (await _db).insert('sync_metadata', {
      'key': 'task_sync_cursor',
      'value': cursor.toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<RemoteMergeResult> mergeRemoteTask(PlanoTask remoteTask) async {
    final database = await _db;
    return database.transaction((transaction) async {
      final rows = await transaction.query(
        'tasks',
        where: 'id = ?',
        whereArgs: [remoteTask.id],
        limit: 1,
      );
      if (rows.isNotEmpty) {
        final localTask = _taskFromRow(rows.single);
        final localDeleted = localTask.deletedAt != null;
        final remoteDeleted = remoteTask.deletedAt != null;
        if ((localDeleted && !remoteDeleted) ||
            (localDeleted == remoteDeleted &&
                !_isRemoteNewer(remoteTask, localTask))) {
          return RemoteMergeResult.localKept;
        }
      }
      await transaction.insert(
        'tasks',
        _taskToRemoteRow(remoteTask),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await transaction.delete(
        'sync_queue',
        where: 'entity = ? AND entity_id = ?',
        whereArgs: ['task', remoteTask.id],
      );
      return RemoteMergeResult.remoteApplied;
    });
  }

  @override
  Future<List<FixedEvent>> loadEvents(DateTime date) async =>
      const <FixedEvent>[];

  @override
  Future<bool> loadDarkMode() async {
    final rows = await (await _db).query(
      'preferences',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['dark_mode'],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    return rows.single['value']! as int == 1;
  }

  @override
  Future<void> saveDarkMode(bool enabled) async {
    await (await _db).insert('preferences', {
      'key': 'dark_mode',
      'value': enabled ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> loadAiConsent() async {
    final rows = await (await _db).query(
      'preferences',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['ai_gemini_consent'],
      limit: 1,
    );
    return rows.isNotEmpty && rows.single['value']! as int == 1;
  }

  Future<void> saveAiConsent(bool granted) async {
    await (await _db).insert('preferences', {
      'key': 'ai_gemini_consent',
      'value': granted ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<PlanoTask>> parseAiTasks({
    required SupabaseClient client,
    required String text,
  }) async {
    return AiTaskService(client).analyze(text);
  }

  @override
  Future<String?> loadCalendarId() async {
    final rows = await (await _db).query(
      'calendar_settings',
      columns: ['calendar_id'],
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single['calendar_id'] as String?;
  }

  @override
  Future<void> saveCalendarId(String? calendarId) async {
    final database = await _db;
    if (calendarId == null) {
      await database.delete(
        'calendar_settings',
        where: 'id = ?',
        whereArgs: [1],
      );
      return;
    }
    await database.insert('calendar_settings', {
      'id': 1,
      'calendar_id': calendarId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> close() async {
    final database = _database ?? await _openingDatabase;
    if (database == null) return;
    await database.close();
    _database = null;
    _openingDatabase = null;
  }

  Future<Database> get _db async {
    final database = _database;
    if (database != null) return database;
    final opening = _openingDatabase ??= _openDatabase();
    try {
      final openedDatabase = await opening;
      _database = openedDatabase;
      return openedDatabase;
    } on Object {
      _openingDatabase = null;
      rethrow;
    }
  }

  Future<Database> _openDatabase() async {
    final location = databasePath ?? await getPlanifyDatabasePath();
    return openDatabase(
      location,
      version: 6,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            notes TEXT NOT NULL,
            duration_minutes INTEGER,
            priority TEXT NOT NULL,
            due_date TEXT,
            status TEXT NOT NULL,
            scheduled_start TEXT,
            planned_end TEXT,
            project TEXT NOT NULL,
            is_locked INTEGER NOT NULL,
            is_ai_proposed INTEGER NOT NULL,
            is_duration_estimated INTEGER NOT NULL,
            reminder_enabled INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            deleted_at TEXT
          )
        ''');
        await database.execute('''
          CREATE TABLE preferences (
            key TEXT PRIMARY KEY,
            value INTEGER NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE calendar_settings (
            id INTEGER PRIMARY KEY,
            calendar_id TEXT NOT NULL
          )
        ''');
        await _createSyncTables(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute('DROP TABLE IF EXISTS work_schedule');
        }
        if (oldVersion < 3) {
          await database.execute(
            'ALTER TABLE tasks ADD COLUMN reminder_enabled INTEGER NOT NULL DEFAULT 0',
          );
          await database.execute('''
            CREATE TABLE calendar_settings (
              id INTEGER PRIMARY KEY,
              calendar_id TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          await database.execute(
            'ALTER TABLE tasks ADD COLUMN created_at TEXT',
          );
          await database.execute(
            'ALTER TABLE tasks ADD COLUMN updated_at TEXT',
          );
          await database.execute(
            'ALTER TABLE tasks ADD COLUMN deleted_at TEXT',
          );
          final now = DateTime.now().toUtc().toIso8601String();
          final rows = await database.query('tasks', columns: ['id']);
          for (final row in rows) {
            await database.update(
              'tasks',
              {'id': generateTaskId(), 'created_at': now, 'updated_at': now},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        }
        if (oldVersion < 5) {
          await database.execute('ALTER TABLE tasks ADD COLUMN due_date TEXT');
          await database.execute(
            'ALTER TABLE tasks ADD COLUMN planned_end TEXT',
          );
          await database.execute(
            'UPDATE tasks SET planned_end = COALESCE(scheduled_end, deadline)',
          );
          await database.execute('UPDATE tasks SET due_date = deadline');
        }
        if (oldVersion < 6) {
          await _createSyncTables(database);
          final now = DateTime.now().toUtc().toIso8601String();
          final rows = await database.query('tasks');
          for (final row in rows) {
            final task = _taskFromRow(row);
            await database.insert('sync_queue', {
              'entity': 'task',
              'entity_id': task.id,
              'type': task.deletedAt == null ? 'create' : 'delete',
              'payload': jsonEncode(_taskToSyncPayload(task)),
              'attempts': 0,
              'state': 'pending',
              'created_at': now,
            });
          }
        }
      },
    );
  }

  Future<void> _createSyncTables(DatabaseExecutor database) async {
    await database.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        type TEXT NOT NULL CHECK (type IN ('create', 'update', 'delete')),
        payload TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        last_error TEXT,
        state TEXT NOT NULL DEFAULT 'pending'
          CHECK (state IN ('pending', 'error')),
        created_at TEXT NOT NULL,
        next_attempt_at TEXT
      )
    ''');
    await database.execute('''
      CREATE INDEX sync_queue_state_id_idx ON sync_queue (state, id)
    ''');
    await database.execute('''
      CREATE TABLE sync_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  Future<void> _enqueue(
    Transaction transaction,
    PlanoTask task,
    SyncOperationType type,
  ) async {
    await transaction.insert('sync_queue', {
      'entity': 'task',
      'entity_id': task.id,
      'type': type.name,
      'payload': jsonEncode(_taskToSyncPayload(task)),
      'attempts': 0,
      'state': 'pending',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Map<String, Object?> _taskToSyncPayload(PlanoTask task) => {
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

  Map<String, Object?> _taskToRemoteRow(PlanoTask task) => {
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
    'is_locked': task.isLocked ? 1 : 0,
    'is_ai_proposed': task.isAiProposed ? 1 : 0,
    'is_duration_estimated': task.isDurationEstimated ? 1 : 0,
    'reminder_enabled': task.reminderEnabled ? 1 : 0,
    'created_at': task.createdAt?.toUtc().toIso8601String(),
    'updated_at': task.updatedAt?.toUtc().toIso8601String(),
    'deleted_at': task.deletedAt?.toUtc().toIso8601String(),
  };

  bool _isRemoteNewer(PlanoTask remote, PlanoTask local) {
    final remoteUpdated = remote.updatedAt;
    final localUpdated = local.updatedAt;
    if (remoteUpdated == null) return false;
    if (localUpdated == null) return true;
    return remoteUpdated.isAfter(localUpdated);
  }

  Map<String, Object?> _taskToRow(PlanoTask task, String now) => {
    'id': task.id,
    'title': task.title,
    'notes': task.notes,
    'duration_minutes': task.durationMinutes,
    'priority': task.priority.name,
    'due_date': task.dueDate?.toIso8601String(),
    'status': task.status.name,
    'scheduled_start': task.scheduledStart?.toIso8601String(),
    'planned_end': task.plannedEnd?.toIso8601String(),
    'project': task.project,
    'is_locked': task.isLocked ? 1 : 0,
    'is_ai_proposed': task.isAiProposed ? 1 : 0,
    'is_duration_estimated': task.isDurationEstimated ? 1 : 0,
    'reminder_enabled': task.reminderEnabled ? 1 : 0,
    'created_at': (task.createdAt ?? DateTime.parse(now))
        .toUtc()
        .toIso8601String(),
    'updated_at': now,
    'deleted_at': task.deletedAt?.toUtc().toIso8601String(),
  };

  PlanoTask _taskFromRow(Map<String, Object?> row) => PlanoTask(
    id: row['id']! as String,
    title: row['title']! as String,
    notes: row['notes']! as String,
    durationMinutes: row['duration_minutes'] as int?,
    priority: TaskPriority.values.byName(row['priority']! as String),
    dueDate: _dateTimeFromStorage(row['due_date'] as String?),
    plannedEnd: _dateTimeFromStorage(row['planned_end'] as String?),
    status: TaskStatus.values.byName(row['status']! as String),
    scheduledStart: _dateTimeFromStorage(row['scheduled_start'] as String?),
    project: row['project']! as String,
    isLocked: row['is_locked']! as int == 1,
    isAiProposed: row['is_ai_proposed']! as int == 1,
    isDurationEstimated: row['is_duration_estimated']! as int == 1,
    reminderEnabled: row['reminder_enabled']! as int == 1,
    createdAt: DateTime.parse(row['created_at']! as String),
    updatedAt: DateTime.parse(row['updated_at']! as String),
    deletedAt: _dateTimeFromStorage(row['deleted_at'] as String?),
  );

  DateTime? _dateTimeFromStorage(String? value) =>
      value == null ? null : DateTime.parse(value);
}
