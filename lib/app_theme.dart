part of 'main.dart';

extension _PlanoTheme on _PlanoAppState {
  ThemeData get _theme {
    final brightness = _darkMode ? Brightness.dark : Brightness.light;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: brightness,
      surface: _darkMode ? const Color(0xFF1A1D24) : Colors.white,
    );
    final foreground = _darkMode ? const Color(0xFFF3F4F6) : _ink;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          _darkMode ? const Color(0xFF0F1115) : _canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: _darkMode ? const Color(0xFF0F1115) : _canvas,
        foregroundColor: _darkMode ? Colors.white : _ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: _darkMode ? const Color(0xFF2A2D35) : _border,
          ),
        ),
      ),
      textTheme: ThemeData(
        brightness: brightness,
        useMaterial3: true,
      ).textTheme.apply(
        bodyColor: foreground,
        displayColor: foreground,
      ),
    );
  }
}
