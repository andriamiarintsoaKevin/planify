import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import '../domain/planner.dart';

class LocalReminderService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool get isAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<void> initialize() async {
    if (!isAvailable) return;
    timezone_data.initializeTimeZones();
    await _notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }

  Future<bool> requestPermission() async {
    if (!isAvailable) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    }
    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  Future<bool> requestExactAlarmPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (await android?.canScheduleExactNotifications() ?? false) return true;
    return await android?.requestExactAlarmsPermission() ?? false;
  }

  Future<bool?> areNotificationsEnabled() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return android?.areNotificationsEnabled();
  }

  Future<bool> openNotificationSettings() async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.openAppNotificationSettings() ?? false;
  }

  Future<void> syncTask(PlanoTask task) async {
    if (!isAvailable) return;
    final id = _notificationId(task.id);
    await cancelTask(task);
    final start = task.scheduledStart;
    if (!task.reminderEnabled ||
        task.status != TaskStatus.scheduled ||
        start == null ||
        !start.isAfter(DateTime.now())) {
      return;
    }
    var exactAlarmsAllowed = true;
    if (defaultTargetPlatform == TargetPlatform.android) {
      exactAlarmsAllowed =
          await _notifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.canScheduleExactNotifications() ??
          false;
    }
    await _notifications.zonedSchedule(
      id: id,
      title: 'C’est l’heure de votre tâche',
      body: task.title,
      scheduledDate: timezone.TZDateTime.from(start, timezone.UTC),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'planify_task_reminders',
          'Rappels de tâches',
          channelDescription: 'Rappels pour les tâches planifiées dans Planify',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: exactAlarmsAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      payload: task.id,
    );
  }

  Future<void> cancelTask(PlanoTask task) async {
    if (!isAvailable) return;
    await _notifications.cancel(id: _notificationId(task.id));
  }

  int _notificationId(String taskId) => taskId.codeUnits.fold<int>(
    0,
    (value, unit) => (value * 31 + unit) & 0x7fffffff,
  );
}
