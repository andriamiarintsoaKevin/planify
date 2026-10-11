import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> initializePlanifyDatabase() async {
  if (Platform.isLinux || Platform.isWindows) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

Future<String> getPlanifyDatabasePath() async {
  if (Platform.isLinux || Platform.isWindows) {
    final supportDirectory = await getApplicationSupportDirectory();
    final databaseDirectory = Directory(
      path.join(supportDirectory.path, 'databases'),
    );
    await databaseDirectory.create(recursive: true);
    return path.join(databaseDirectory.path, 'planify.db');
  }
  return path.join(await getDatabasesPath(), 'planify.db');
}
