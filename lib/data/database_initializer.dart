import 'database_initializer_stub.dart'
    if (dart.library.io) 'database_initializer_io.dart' as platform;

Future<void> initializePlanifyDatabase() =>
    platform.initializePlanifyDatabase();

Future<String> getPlanifyDatabasePath() => platform.getPlanifyDatabasePath();
