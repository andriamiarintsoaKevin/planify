part of '../../main.dart';

extension _PlanoTheme on _PlanoAppState {
  ThemeData get _theme {
    final brightness = _darkMode ? Brightness.dark : Brightness.light;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: brightness,
      surface: _darkMode ? const Color(0xFF171A21) : Colors.white,
      surfaceContainer: _darkMode
          ? const Color(0xFF1D212A)
          : const Color(0xFFF0F1F6),
    ).copyWith(
      onSurface: _darkMode ? const Color(0xFFF4F5F7) : _ink,
      onSurfaceVariant: _darkMode
          ? const Color(0xFFC0C6D2)
          : const Color(0xFF626B7A),
      outlineVariant: _darkMode
          ? const Color(0xFF454B58)
          : const Color(0xFFD9DCE5),
    );
    final foreground = _darkMode ? const Color(0xFFF3F4F6) : _ink;
    final outline = _darkMode
        ? const Color(0xFF3B414D)
        : const Color(0xFFD9DCE5);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor:
          _darkMode ? const Color(0xFF101218) : _canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: _darkMode ? const Color(0xFF101218) : _canvas,
        foregroundColor: _darkMode ? Colors.white : _ink,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: outline,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _darkMode
            ? const Color(0xFF1D212A)
            : const Color(0xFFF9FAFC),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        prefixIconColor: colorScheme.onSurfaceVariant,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      dividerColor: outline,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _darkMode
            ? const Color(0xFF292E38)
            : const Color(0xFF252936),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _darkMode
            ? const Color(0xFF171A21)
            : colorScheme.surface,
        modalBackgroundColor: _darkMode
            ? const Color(0xFF171A21)
            : colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _darkMode
            ? const Color(0xFF171A21)
            : colorScheme.surface,
        indicatorColor: _darkMode
            ? const Color(0xFF34304F)
            : _primarySoft,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : colorScheme.outline,
        ),
      ),
      textTheme: ThemeData(
        brightness: brightness,
        useMaterial3: true,
      ).textTheme.apply(
        bodyColor: foreground,
        displayColor: foreground,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      listTileTheme: ListTileThemeData(
        iconColor: colorScheme.onSurfaceVariant,
        textColor: foreground,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(colorScheme.onSurface),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colorScheme.secondaryContainer
                : colorScheme.surface,
          ),
          side: WidgetStatePropertyAll(BorderSide(color: outline)),
        ),
      ),
    );
  }
}
