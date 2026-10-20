part of '../../main.dart';

enum AppearanceTheme { classic, ocean, forest }

enum AppearanceAccent { indigo, teal, amber, rose }

enum AppearanceDensity { spacious, compact }

enum PlannerDisplay { simplified, detailed }

class AppearanceSettings {
  const AppearanceSettings({
    this.darkMode = false,
    this.theme = AppearanceTheme.classic,
    this.accent = AppearanceAccent.indigo,
    this.density = AppearanceDensity.spacious,
    this.plannerDisplay = PlannerDisplay.simplified,
  });

  final bool darkMode;
  final AppearanceTheme theme;
  final AppearanceAccent accent;
  final AppearanceDensity density;
  final PlannerDisplay plannerDisplay;

  AppearanceSettings copyWith({
    bool? darkMode,
    AppearanceTheme? theme,
    AppearanceAccent? accent,
    AppearanceDensity? density,
    PlannerDisplay? plannerDisplay,
  }) => AppearanceSettings(
    darkMode: darkMode ?? this.darkMode,
    theme: theme ?? this.theme,
    accent: accent ?? this.accent,
    density: density ?? this.density,
    plannerDisplay: plannerDisplay ?? this.plannerDisplay,
  );

  Map<String, Object?> toJson() => {
    'darkMode': darkMode,
    'theme': theme.name,
    'accent': accent.name,
    'density': density.name,
    'plannerDisplay': plannerDisplay.name,
  };

  factory AppearanceSettings.fromJson(Map<String, dynamic> json) {
    return AppearanceSettings(
      darkMode: json['darkMode'] as bool? ?? false,
      theme: AppearanceTheme.values.byName(
        json['theme'] as String? ?? AppearanceTheme.classic.name,
      ),
      accent: AppearanceAccent.values.byName(
        json['accent'] as String? ?? AppearanceAccent.indigo.name,
      ),
      density: AppearanceDensity.values.byName(
        json['density'] as String? ?? AppearanceDensity.spacious.name,
      ),
      plannerDisplay: PlannerDisplay.values.byName(
        json['plannerDisplay'] as String? ?? PlannerDisplay.simplified.name,
      ),
    );
  }

  AppearanceSettings effective({required bool proAccess}) => proAccess
      ? this
      : copyWith(
          theme: AppearanceTheme.classic,
          accent: AppearanceAccent.indigo,
          density: AppearanceDensity.spacious,
          plannerDisplay: PlannerDisplay.simplified,
        );
}

const Map<AppearanceAccent, Color> _appearanceAccents = {
  AppearanceAccent.indigo: Color(0xFF4F46E5),
  AppearanceAccent.teal: Color(0xFF0F766E),
  AppearanceAccent.amber: Color(0xFFB45309),
  AppearanceAccent.rose: Color(0xFFBE123C),
};

const Map<AppearanceTheme, Color> _appearanceThemeSeeds = {
  AppearanceTheme.classic: Color(0xFF4F46E5),
  AppearanceTheme.ocean: Color(0xFF0369A1),
  AppearanceTheme.forest: Color(0xFF4D7C0F),
};

ThemeData buildPlanifyTheme(
  AppearanceSettings settings, {
  required bool proAccess,
}) {
  final effectiveSettings = settings.effective(proAccess: proAccess);
  final isDark = effectiveSettings.darkMode;
  final brightness = isDark ? Brightness.dark : Brightness.light;
  final themeSeed = _appearanceThemeSeeds[effectiveSettings.theme]!;
  final selectedAccent = _appearanceAccents[effectiveSettings.accent]!;
  final accent =
      effectiveSettings.theme != AppearanceTheme.classic &&
          effectiveSettings.accent == AppearanceAccent.indigo
      ? themeSeed
      : selectedAccent;
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: brightness,
        surface: isDark ? const Color(0xFF171A21) : Colors.white,
        surfaceContainer: isDark
            ? const Color(0xFF1D212A)
            : const Color(0xFFF0F1F6),
      ).copyWith(
        onSurface: isDark ? const Color(0xFFF4F5F7) : _ink,
        onSurfaceVariant: isDark
            ? const Color(0xFFC0C6D2)
            : const Color(0xFF626B7A),
        outlineVariant: isDark
            ? const Color(0xFF454B58)
            : const Color(0xFFD9DCE5),
        secondary: effectiveSettings.theme == AppearanceTheme.classic
            ? null
            : themeSeed,
      );
  final foreground = isDark ? const Color(0xFFF3F4F6) : _ink;
  final outline = isDark ? const Color(0xFF3B414D) : const Color(0xFFD9DCE5);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    visualDensity: effectiveSettings.density == AppearanceDensity.compact
        ? VisualDensity.compact
        : VisualDensity.standard,
    scaffoldBackgroundColor: isDark ? const Color(0xFF101218) : _canvas,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? const Color(0xFF101218) : _canvas,
      foregroundColor: isDark ? Colors.white : _ink,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: outline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF1D212A) : const Color(0xFFF9FAFC),
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
      backgroundColor: colorScheme.primary,
      contentTextStyle: TextStyle(color: colorScheme.onPrimary),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isDark ? const Color(0xFF171A21) : colorScheme.surface,
      modalBackgroundColor: isDark
          ? const Color(0xFF171A21)
          : colorScheme.surface,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? const Color(0xFF171A21) : colorScheme.surface,
      indicatorColor: colorScheme.primaryContainer,
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
    ).textTheme.apply(bodyColor: foreground, displayColor: foreground),
    iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
    listTileTheme: ListTileThemeData(
      dense: effectiveSettings.density == AppearanceDensity.compact,
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

extension _PlanoTheme on _PlanoAppState {
  ThemeData get _theme =>
      buildPlanifyTheme(_appearanceSettings, proAccess: _hasProAppearance);
}
