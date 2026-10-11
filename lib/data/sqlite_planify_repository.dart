import 'package:sqflite/sqflite.dart';

import '../domain/planner.dart';
import 'database_initializer.dart';
import 'plano_repository.dart';

class SqlitePlanifyRepository implements PlanoRepository {
  SqlitePlanifyRepository({this.databasePath});

  final String? databasePath;
  Database? _database;
  Future<Database>? _openingDatabase;

  @override
  Future<List<PlanoTask>> loadTasks() async {
    final rows = await (await _db).query('tasks', orderBy: 'rowid ASC');
    return List.unmodifiable(rows.map(_taskFromRow));
  }

  @override
  Future<void> saveTasks(List<PlanoTask> tasks) async {
    final database = await _db;
    await database.transaction((transaction) async {
      await transaction.delete('tasks');
      final batch = transaction.batch();
      for (final task in tasks) {
        batch.insert('tasks', _taskToRow(task));
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<List<FixedEvent>> loadEvents(DateTime date) async =>
      const <FixedEvent>[];

  @override
  Future<WorkSchedule> loadWorkSchedule() async {
    final rows = await (await _db).query(
      'work_schedule',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) {
      return const WorkSchedule(startMinute: 9 * 60, endMinute: 18 * 60);
    }
    return WorkSchedule(
      startMinute: rows.single['start_minute']! as int,
      endMinute: rows.single['end_minute']! as int,
    );
  }

  @override
  Future<void> saveWorkSchedule(WorkSchedule schedule) async {
    await (await _db).insert(
      'work_schedule',
      {
        'id': 1,
        'start_minute': schedule.startMinute,
        'end_minute': schedule.endMinute,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

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
    await (await _db).insert(
      'preferences',
      {'key': 'dark_mode', 'value': enabled ? 1 : 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            notes TEXT NOT NULL,
            duration_minutes INTEGER,
            priority TEXT NOT NULL,
            deadline TEXT,
            status TEXT NOT NULL,
            scheduled_start TEXT,
            scheduled_end TEXT,
            project TEXT NOT NULL,
            is_locked INTEGER NOT NULL,
            is_ai_proposed INTEGER NOT NULL,
            is_duration_estimated INTEGER NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE work_schedule (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            start_minute INTEGER NOT NULL,
            end_minute INTEGER NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE preferences (
            key TEXT PRIMARY KEY,
            value INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Map<String, Object?> _taskToRow(PlanoTask task) => {
    'id': task.id,
    'title': task.title,
    'notes': task.notes,
    'duration_minutes': task.durationMinutes,
    'priority': task.priority.name,
    'deadline': task.deadline?.toIso8601String(),
    'status': task.status.name,
    'scheduled_start': task.scheduledStart?.toIso8601String(),
    'scheduled_end': task.scheduledEnd?.toIso8601String(),
    'project': task.project,
    'is_locked': task.isLocked ? 1 : 0,
    'is_ai_proposed': task.isAiProposed ? 1 : 0,
    'is_duration_estimated': task.isDurationEstimated ? 1 : 0,
  };

  PlanoTask _taskFromRow(Map<String, Object?> row) => PlanoTask(
    id: row['id']! as String,
    title: row['title']! as String,
    notes: row['notes']! as String,
    durationMinutes: row['duration_minutes'] as int?,
    priority: TaskPriority.values.byName(row['priority']! as String),
    deadline: _dateTimeFromStorage(row['deadline'] as String?),
    status: TaskStatus.values.byName(row['status']! as String),
    scheduledStart: _dateTimeFromStorage(row['scheduled_start'] as String?),
    scheduledEnd: _dateTimeFromStorage(row['scheduled_end'] as String?),
    project: row['project']! as String,
    isLocked: row['is_locked']! as int == 1,
    isAiProposed: row['is_ai_proposed']! as int == 1,
    isDurationEstimated: row['is_duration_estimated']! as int == 1,
  );

  DateTime? _dateTimeFromStorage(String? value) =>
      value == null ? null : DateTime.parse(value);
}
