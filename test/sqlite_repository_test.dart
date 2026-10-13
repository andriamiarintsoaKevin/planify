import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:planify/data/sqlite_planify_repository.dart';
import 'package:planify/domain/planner.dart';
import 'package:sqflite/sqflite.dart' show OpenDatabaseOptions, databaseFactory;
import 'package:sqflite_common_ffi/sqflite_ffi.dart'
    show databaseFactoryFfi, sqfliteFfiInit;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory temporaryDirectory;
  late String databasePath;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'planify_sqlite_test_',
    );
    databasePath = path.join(temporaryDirectory.path, 'planify.db');
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test('persiste toutes les tâches et préférences après réouverture', () async {
    final repository = SqlitePlanifyRepository(databasePath: databasePath);
    final task = PlanoTask(
      id: 'task-1',
      title: 'Préparer la présentation',
      notes: 'Relire les diapositives',
      durationMinutes: 45,
      priority: TaskPriority.high,
      deadline: DateTime(2026, 10, 20, 16),
      status: TaskStatus.scheduled,
      scheduledStart: DateTime(2026, 10, 20, 10),
      scheduledEnd: DateTime(2026, 10, 20, 10, 45),
      project: 'Projet client',
      isLocked: true,
      isAiProposed: true,
      isDurationEstimated: false,
      reminderEnabled: true,
    );

    await repository.saveTasks([task]);
    await repository.saveDarkMode(true);
    await repository.saveCalendarId('google-calendar-id');
    await repository.close();

    final reopenedRepository = SqlitePlanifyRepository(
      databasePath: databasePath,
    );
    final storedTask = (await reopenedRepository.loadTasks()).single;

    expect(storedTask.id, task.id);
    expect(storedTask.title, task.title);
    expect(storedTask.notes, task.notes);
    expect(storedTask.durationMinutes, task.durationMinutes);
    expect(storedTask.priority, task.priority);
    expect(storedTask.deadline, task.deadline);
    expect(storedTask.status, task.status);
    expect(storedTask.scheduledStart, task.scheduledStart);
    expect(storedTask.scheduledEnd, task.scheduledEnd);
    expect(storedTask.project, task.project);
    expect(storedTask.isLocked, task.isLocked);
    expect(storedTask.isAiProposed, task.isAiProposed);
    expect(storedTask.isDurationEstimated, task.isDurationEstimated);
    expect(storedTask.reminderEnabled, isTrue);
    expect(await reopenedRepository.loadDarkMode(), isTrue);
    expect(await reopenedRepository.loadCalendarId(), 'google-calendar-id');

    await reopenedRepository.saveTasks([]);
    await reopenedRepository.close();

    final repositoryAfterDeletion = SqlitePlanifyRepository(
      databasePath: databasePath,
    );
    expect(await repositoryAfterDeletion.loadTasks(), isEmpty);
    await repositoryAfterDeletion.close();
  });

  test('migre depuis la version précédente sans perdre les tâches', () async {
    final previousDatabase = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
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
            id INTEGER PRIMARY KEY,
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
      ),
    );
    await previousDatabase.insert('tasks', {
      'id': 'legacy-task',
      'title': 'Tâche à conserver',
      'notes': '',
      'duration_minutes': null,
      'priority': TaskPriority.medium.name,
      'deadline': null,
      'status': TaskStatus.inbox.name,
      'scheduled_start': null,
      'scheduled_end': null,
      'project': '',
      'is_locked': 0,
      'is_ai_proposed': 0,
      'is_duration_estimated': 0,
    });
    await previousDatabase.close();

    final repository = SqlitePlanifyRepository(databasePath: databasePath);
    expect((await repository.loadTasks()).single.title, 'Tâche à conserver');
    expect(await repository.loadDarkMode(), isFalse);
    await repository.close();

    final upgradedDatabase = await databaseFactory.openDatabase(databasePath);
    final versionRows = await upgradedDatabase.rawQuery('PRAGMA user_version');
    expect(versionRows.single.values.single, 3);
    final tables = await upgradedDatabase.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    expect(
      tables.map((row) => row['name']),
      containsAll(['tasks', 'preferences', 'calendar_settings']),
    );
    expect(tables.map((row) => row['name']), isNot(contains('work_schedule')));
    await upgradedDatabase.close();
  });
}
