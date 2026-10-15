import 'package:sqflite/sqflite.dart';

import '../domain/planner.dart';
import 'database_initializer.dart';
import 'plano_repository.dart';
import 'task_id.dart';
import 'task_repository.dart';

class SqlitePlanifyRepository implements PlanoRepository, TaskRepository {
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
        final row = _taskToRow(task, now);
        await transaction.rawInsert(
          '''
          INSERT INTO tasks (
            id, title, notes, duration_minutes, priority, due_date, status,
            scheduled_start, planned_end, project, is_locked, is_ai_proposed,
            is_duration_estimated, reminder_enabled, created_at, updated_at,
            deleted_at
          ) VALUES (
            ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
          )
          ON CONFLICT(id) DO UPDATE SET
            title = excluded.title,
            notes = excluded.notes,
            duration_minutes = excluded.duration_minutes,
            priority = excluded.priority,
            due_date = excluded.due_date,
            status = excluded.status,
            scheduled_start = excluded.scheduled_start,
            planned_end = excluded.planned_end,
            project = excluded.project,
            is_locked = excluded.is_locked,
            is_ai_proposed = excluded.is_ai_proposed,
            is_duration_estimated = excluded.is_duration_estimated,
            reminder_enabled = excluded.reminder_enabled,
            updated_at = excluded.updated_at
        ''',
          [
            row['id'],
            row['title'],
            row['notes'],
            row['duration_minutes'],
            row['priority'],
            row['due_date'],
            row['status'],
            row['scheduled_start'],
            row['planned_end'],
            row['project'],
            row['is_locked'],
            row['is_ai_proposed'],
            row['is_duration_estimated'],
            row['reminder_enabled'],
            row['created_at'],
            row['updated_at'],
            row['deleted_at'],
          ],
        );
      }
    });
  }

  @override
  Future<void> softDeleteTask(String id) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await (await _db).update(
      'tasks',
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
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
      version: 5,
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
      },
    );
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
