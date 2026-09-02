import 'package:flutter/material.dart';

/// Which visual theme the user picked.
enum ThemeChoice { system, light, dark, red, green, mono, custom }

extension ThemeChoiceX on ThemeChoice {
  String get id => name;

  static ThemeChoice fromId(String? id) {
    return ThemeChoice.values.firstWhere(
      (t) => t.id == id,
      orElse: () => ThemeChoice.system,
    );
  }

  String get label {
    switch (this) {
      case ThemeChoice.system:
        return 'System default';
      case ThemeChoice.light:
        return 'Light';
      case ThemeChoice.dark:
        return 'Dark';
      case ThemeChoice.red:
        return 'Red';
      case ThemeChoice.green:
        return 'Green';
      case ThemeChoice.mono:
        return 'Black & White';
      case ThemeChoice.custom:
        return 'Custom picture';
    }
  }

  IconData get icon {
    switch (this) {
      case ThemeChoice.system:
        return Icons.brightness_auto_outlined;
      case ThemeChoice.light:
        return Icons.light_mode_outlined;
      case ThemeChoice.dark:
        return Icons.dark_mode_outlined;
      case ThemeChoice.red:
        return Icons.local_fire_department_outlined;
      case ThemeChoice.green:
        return Icons.eco_outlined;
      case ThemeChoice.mono:
        return Icons.contrast_outlined;
      case ThemeChoice.custom:
        return Icons.wallpaper_outlined;
    }
  }
}

/// One full color specification for the browser chrome.
///
/// The brand: navy blue primary + cyan accent. Every theme is a variation.
class BrowserPalette {
  const BrowserPalette({
    required this.id,
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.omniboxFill,
    required this.chromeFill,
    required this.text,
    required this.textDim,
    required this.primary,
    required this.onPrimary,
    required this.accent,
    required this.onAccent,
    required this.border,
    required this.danger,
    required this.success,
    this.chromeTranslucent = false,
    this.wallpaperScrim = const Color(0x00000000),
  });

  final String id;

  final Brightness brightness;

  /// Scaffold / new-tab-page background.
  final Color background;

  /// Cards, dialogs, menus, active tab.
  final Color surface;

  /// Chips, hovers, secondary containers.
  final Color surfaceAlt;

  /// The address bar fill.
  final Color omniboxFill;

  /// Tab strip / toolbar fill.
  final Color chromeFill;

  final Color text;
  final Color textDim;

  /// Primary buttons — the navy brand color (or theme equivalent).
  final Color primary;
  final Color onPrimary;

  /// Cyan accent (or theme equivalent).
  final Color accent;
  final Color onAccent;

  final Color border;
  final Color danger;
  final Color success;

  /// When true (custom wallpaper theme) chrome becomes frosted glass.
  final bool chromeTranslucent;

  /// Dark veil over the wallpaper so text stays readable.
  final Color wallpaperScrim;

  bool get isDark => brightness == Brightness.dark;

  /// ---- Brand constants ----
  static const Color navy = Color(0xFF0A1F44);
  static const Color navyDeep = Color(0xFF071838);
  static const Color cyan = Color(0xFF22D3EE);
  static const Color cyanDeep = Color(0xFF00A9CE);

  static const light = BrowserPalette(
    id: 'light',
    brightness: Brightness.light,
    background: Color(0xFFF5F7FC),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE9EEF8),
    omniboxFill: Color(0xFFECF1FA),
    chromeFill: Color(0xFFE3EAF6),
    text: Color(0xFF101B2E),
    textDim: Color(0xFF5A6B87),
    primary: navy,
    onPrimary: Colors.white,
    accent: cyanDeep,
    onAccent: Colors.white,
    border: Color(0xFFD8E0EF),
    danger: Color(0xFFD32F2F),
    success: Color(0xFF1E8E3E),
  );

  static const dark = BrowserPalette(
    id: 'dark',
    brightness: Brightness.dark,
    background: Color(0xFF0A1424),
    surface: Color(0xFF101E36),
    surfaceAlt: Color(0xFF17264A),
    omniboxFill: Color(0xFF0E1B31),
    chromeFill: Color(0xFF0C172A),
    text: Color(0xFFE9F0FB),
    textDim: Color(0xFF93A4C3),
    primary: Color(0xFF14336B),
    onPrimary: Colors.white,
    accent: cyan,
    onAccent: Color(0xFF04222B),
    border: Color(0xFF1E3054),
    danger: Color(0xFFFF6B6B),
    success: Color(0xFF4CD97B),
  );

  static const red = BrowserPalette(
    id: 'red',
    brightness: Brightness.dark,
    background: Color(0xFF150709),
    surface: Color(0xFF200C0F),
    surfaceAlt: Color(0xFF2B1114),
    omniboxFill: Color(0xFF1B090C),
    chromeFill: Color(0xFF180609),
    text: Color(0xFFF7E9EA),
    textDim: Color(0xFFC79DA1),
    primary: Color(0xFF8E1B24),
    onPrimary: Colors.white,
    accent: Color(0xFFFF5A66),
    onAccent: Color(0xFF3A0508),
    border: Color(0xFF3A181C),
    danger: Color(0xFFFF5A66),
    success: Color(0xFF4CD97B),
  );

  static const green = BrowserPalette(
    id: 'green',
    brightness: Brightness.dark,
    background: Color(0xFF04140C),
    surface: Color(0xFF0A2117),
    surfaceAlt: Color(0xFF0F2C1F),
    omniboxFill: Color(0xFF081B12),
    chromeFill: Color(0xFF061710),
    text: Color(0xFFE8F7EE),
    textDim: Color(0xFF9CC6AC),
    primary: Color(0xFF0B5E3B),
    onPrimary: Colors.white,
    accent: Color(0xFF00E589),
    onAccent: Color(0xFF01321F),
    border: Color(0xFF1B3D2C),
    danger: Color(0xFFFF6B6B),
    success: Color(0xFF00E589),
  );

  static const mono = BrowserPalette(
    id: 'mono',
    brightness: Brightness.dark,
    background: Color(0xFF000000),
    surface: Color(0xFF0C0C0C),
    surfaceAlt: Color(0xFF161616),
    omniboxFill: Color(0xFF101010),
    chromeFill: Color(0xFF070707),
    text: Color(0xFFFFFFFF),
    textDim: Color(0xFFA6A6A6),
    primary: Color(0xFFE8E8E8),
    onPrimary: Color(0xFF000000),
    accent: Color(0xFFFFFFFF),
    onAccent: Color(0xFF000000),
    border: Color(0xFF262626),
    danger: Color(0xFFFFFFFF),
    success: Color(0xFFBDBDBD),
  );

  /// Frosted-glass navy chrome used over a user wallpaper.
  static const glass = BrowserPalette(
    id: 'custom',
    brightness: Brightness.dark,
    background: Color(0xFF0A1424),
    surface: Color(0xC2182440),
    surfaceAlt: Color(0x991A2C52),
    omniboxFill: Color(0x660E1B31),
    chromeFill: Color(0x330C172A),
    text: Color(0xFFE9F0FB),
    textDim: Color(0xFF9FB0CE),
    primary: Color(0xFF14336B),
    onPrimary: Colors.white,
    accent: cyan,
    onAccent: Color(0xFF04222B),
    border: Color(0x334F6CA8),
    danger: Color(0xFFFF6B6B),
    success: Color(0xFF4CD97B),
    chromeTranslucent: true,
    wallpaperScrim: Color(0x73081224),
  );

  /// Chrome forced while an incognito tab is active.
  static const incognito = BrowserPalette(
    id: 'incognito',
    brightness: Brightness.dark,
    background: Color(0xFF101418),
    surface: Color(0xFF1B2129),
    surfaceAlt: Color(0xFF232B36),
    omniboxFill: Color(0xFF151A21),
    chromeFill: Color(0xFF12161C),
    text: Color(0xFFE8EDF5),
    textDim: Color(0xFF98A4B5),
    primary: Color(0xFF2A3648),
    onPrimary: Colors.white,
    accent: cyan,
    onAccent: Color(0xFF04222B),
    border: Color(0xFF2C3745),
    danger: Color(0xFFFF6B6B),
    success: Color(0xFF4CD97B),
  );

  /// Resolves the user's choice (incl. `system`) into a concrete palette.
  static BrowserPalette resolve(
    ThemeChoice choice,
    Brightness platformBrightness, {
    bool incognitoActive = false,
  }) {
    if (incognitoActive) return BrowserPalette.incognito;
    switch (choice) {
      case ThemeChoice.system:
        return platformBrightness == Brightness.dark ? dark : light;
      case ThemeChoice.light:
        return light;
      case ThemeChoice.dark:
        return dark;
      case ThemeChoice.red:
        return red;
      case ThemeChoice.green:
        return green;
      case ThemeChoice.mono:
        return mono;
      case ThemeChoice.custom:
        return glass;
    }
  }
}

/// Builds the Material [ThemeData] that follows the browser palette.
ThemeData buildMaterialTheme(BrowserPalette p) {
  final scheme = ColorScheme(
    brightness: p.brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    secondary: p.accent,
    onSecondary: p.onAccent,
    error: p.danger,
    onError: Colors.white,
    surface: p.surface,
    onSurface: p.text,
    onSurfaceVariant: p.textDim,
    surfaceContainerHighest: p.surfaceAlt,
  );
  final base = p.isDark ? ThemeData.dark() : ThemeData.light();
  return base.copyWith(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.surface,
    splashColor: p.accent.withValues(alpha: 0.10),
    highlightColor: p.accent.withValues(alpha: 0.06),
    dividerColor: p.border,
    appBarTheme: AppBarTheme(
      backgroundColor: p.chromeFill,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: p.text,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      surfaceTintColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.border),
      ),
      textStyle: TextStyle(color: p.text, fontSize: 14),
    ),
    tooltipTheme: TooltipThemeData(
      textStyle: TextStyle(color: p.text, fontSize: 12),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
      ),
    ),
    dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.chromeFill,
      indicatorColor: p.accent.withValues(alpha: 0.18),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.onAccent : p.textDim,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected)
            ? p.accent
            : p.surfaceAlt,
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.accent : p.textDim,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.accent : Colors.transparent,
      ),
      checkColor: WidgetStatePropertyAll(p.onAccent),
      side: BorderSide(color: p.textDim, width: 1.4),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.surfaceAlt,
      contentTextStyle: TextStyle(color: p.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: p.border),
      ),
      titleTextStyle: TextStyle(
        color: p.text,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    textTheme: base.textTheme.apply(
      bodyColor: p.text,
      displayColor: p.text,
    ),
  );
}
