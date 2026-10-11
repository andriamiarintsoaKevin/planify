Future<void> initializePlanifyDatabase() async {
  // Database access reports the unsupported platform through the app UI.
}

Future<String> getPlanifyDatabasePath() async {
  throw UnsupportedError(
    'La base SQLite locale de Planify n’est pas disponible sur cette plateforme.',
  );
}
