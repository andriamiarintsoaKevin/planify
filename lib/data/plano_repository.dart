import '../domain/planner.dart';

abstract interface class PlanoRepository {
  Future<List<FixedEvent>> loadEvents(DateTime date);

  Future<bool> loadDarkMode();

  Future<void> saveDarkMode(bool enabled);

  Future<String?> loadCalendarId();

  Future<void> saveCalendarId(String? calendarId);
}
