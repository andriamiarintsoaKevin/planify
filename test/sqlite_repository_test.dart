import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:planify/data/sqlite_planify_repository.dart';
import 'package:planify/data/plano_repository.dart';
import 'package:planify/domain/planner.dart';
import 'package:sqflite/sqflite.dart' show databaseFactory;
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
    );
    const schedule = WorkSchedule(startMinute: 8 * 60, endMinute: 17 * 60);

    await repository.saveTasks([task]);
    await repository.saveWorkSchedule(schedule);
    await repository.saveDarkMode(true);
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
    final storedSchedule = await reopenedRepository.loadWorkSchedule();
    expect(storedSchedule.startMinute, schedule.startMinute);
    expect(storedSchedule.endMinute, schedule.endMinute);
    expect(await reopenedRepository.loadDarkMode(), isTrue);

    await reopenedRepository.saveTasks([]);
    await reopenedRepository.close();

    final repositoryAfterDeletion = SqlitePlanifyRepository(
      databasePath: databasePath,
    );
    expect(await repositoryAfterDeletion.loadTasks(), isEmpty);
    await repositoryAfterDeletion.close();
  });

  test(
    'utilise les réglages par défaut tant qu’ils ne sont pas enregistrés',
    () async {
    final repository = SqlitePlanifyRepository(databasePath: databasePath);

      final schedule = await repository.loadWorkSchedule();
      expect(schedule.startMinute, 9 * 60);
      expect(schedule.endMinute, 18 * 60);
    expect(await repository.loadDarkMode(), isFalse);
    await repository.close();
    },
  );
}
