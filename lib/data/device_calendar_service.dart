import 'package:device_calendar_plus/device_calendar_plus.dart';

import '../domain/planner.dart';

class DeviceCalendarService {
  final DeviceCalendar _plugin = DeviceCalendar.instance;

  Future<List<Calendar>> requestAccessAndLoadCalendars() async {
    final permission = await _plugin.requestPermissions(
      level: CalendarAccessLevel.full,
    );
    if (permission != CalendarPermissionStatus.granted) {
      throw StateError('L’accès en lecture aux calendriers a été refusé.');
    }
    return _plugin.listCalendars();
  }

  Future<List<FixedEvent>> loadEvents(String calendarId, DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final events = await _plugin.listEvents(
      start,
      start.add(const Duration(days: 1)),
      calendarIds: [calendarId],
    );
    return [
      for (final event in events)
        if (event.endDate.isAfter(event.startDate))
          FixedEvent(
            title: event.title.trim().isNotEmpty ? event.title.trim() : 'Événement',
            start: event.startDate,
            end: event.endDate,
          ),
    ];
  }
}
