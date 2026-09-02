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

  Object get icon {
    switch (this) {
      case ThemeChoice.system:
        return 'auto';
      case ThemeChoice.light:
        return 'sun';
      case ThemeChoice.dark:
        return 'moon';
      case ThemeChoice.red:
        return 'flame';
      case ThemeChoice.green:
        return 'leaf';
      case ThemeChoice.mono:
        return 'contrast';
      case ThemeChoice.custom:
        return 'image';
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
    background: Color(0xFFF1F4FA),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE8EEF8),
    omniboxFill: Color(0xFFEDF2FA),
    chromeFill: Color(0xFFE6ECF7),
    text: Color(0xFF0D1A2B),
    textDim: Color(0xFF566583),
    primary: navy,
    onPrimary: Colors.white,
    accent: cyanDeep,
    onAccent: Colors.white,
    border: Color(0xFFD5DFEE),
    danger: Color(0xFFC62828),
    success: Color(0xFF1B7F3B),
  );

  static const dark = BrowserPalette(
    id: 'dark',
    brightness: Brightness.dark,
    background: Color(0xFF070F1D),
    surface: Color(0xFF0E1A2C),
    surfaceAlt: Color(0xFF16263C),
    omniboxFill: Color(0xFF0B1626),
    chromeFill: Color(0xFF0A1523),
    text: Color(0xFFE7EEFA),
    textDim: Color(0xFF8FA2C0),
    primary: Color(0xFF14336B),
    onPrimary: Colors.white,
    accent: cyan,
    onAccent: Color(0xFF04222B),
    border: Color(0xFF1C2C45),
    danger: Color(0xFFFF6B6B),
    success: Color(0xFF4CD97B),
  );

  static const red = BrowserPalette(
    id: 'red',
    brightness: Brightness.dark,
    background: Color(0xFF12070A),
    surface: Color(0xFF1C0B0E),
    surfaceAlt: Color(0xFF261014),
    omniboxFill: Color(0xFF180809),
    chromeFill: Color(0xFF150709),
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
    background: Color(0xFF04120B),
    surface: Color(0xFF081B13),
    surfaceAlt: Color(0xFF0D2419),
    omniboxFill: Color(0xFF061610),
    chromeFill: Color(0xFF05140D),
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
    surface: Color(0xCC101C30),
    surfaceAlt: Color(0x9916243C),
    omniboxFill: Color(0x660B1626),
    chromeFill: Color(0x400A1523),
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
///
/// This is what makes the app read as one product rather than a stack of
/// default widgets: gentle, consistent rounding, hairline borders instead of
/// elevation, and shadows only where something actually floats.
///
/// The numbers below mirror `lib/core/ui.dart` on purpose — `Ui` cannot be
/// imported here without a cycle.
ThemeData buildMaterialTheme(BrowserPalette p) {
  const rControl = BorderRadius.all(Radius.circular(8));
  const rField = BorderRadius.all(Radius.circular(10));
  const rCard = BorderRadius.all(Radius.circular(14));
  const rMenu = BorderRadius.all(Radius.circular(12));
  const rSheet = BorderRadius.vertical(top: Radius.circular(18));

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
    outline: p.border,
    outlineVariant: p.border,
    surfaceContainerHighest: p.surfaceAlt,
  );
  final base = p.isDark ? ThemeData.dark() : ThemeData.light();
  final ui = TextStyle(color: p.text, fontSize: 13.5, height: 1.35);

  return base.copyWith(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.surface,
    splashColor: p.accent.withValues(alpha: 0.10),
    highlightColor: p.accent.withValues(alpha: 0.06),
    splashFactory: InkRipple.splashFactory,
    visualDensity: VisualDensity.compact,
    dividerColor: p.border,
    textTheme: base.textTheme.apply(bodyColor: p.text, displayColor: p.text),
    primaryTextTheme: base.primaryTextTheme.apply(bodyColor: p.text),
    appBarTheme: AppBarTheme(
      backgroundColor: p.background,
      foregroundColor: p.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 52,
      titleTextStyle: TextStyle(
        color: p.text,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      iconTheme: IconThemeData(color: p.text, size: 20),
      actionsIconTheme: IconThemeData(color: p.textDim, size: 20),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: rCard,
        side: BorderSide(color: p.border),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: p.border,
      thickness: 1,
      space: 1,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: p.surface,
      surfaceTintColor: p.surface,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: p.isDark ? 0.5 : 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: rMenu,
        side: BorderSide(color: p.border),
      ),
      textStyle: ui,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: p.surface,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: p.isDark ? 0.5 : 0.14),
      shape: RoundedRectangleBorder(
        borderRadius: rCard,
        side: BorderSide(color: p.border),
      ),
      titleTextStyle: TextStyle(
        color: p.text,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      contentTextStyle: ui,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: p.surface,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: rSheet),
      showDragHandle: true,
      dragHandleColor: p.border,
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: p.surface,
      shape: const RoundedRectangleBorder(borderRadius: rCard),
    ),
    tooltipTheme: TooltipThemeData(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: rControl,
        border: Border.all(color: p.border),
      ),
      textStyle: TextStyle(color: p.text, fontSize: 12, fontWeight: FontWeight.w500),
      waitDuration: const Duration(milliseconds: 450),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.omniboxFill,
      hintStyle: TextStyle(color: p.textDim, fontSize: 13.5),
      labelStyle: TextStyle(color: p.textDim, fontSize: 13.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      enabledBorder: OutlineInputBorder(
        borderRadius: rField,
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: rField,
        borderSide: BorderSide(color: p.accent, width: 1.4),
      ),
      border: OutlineInputBorder(
        borderRadius: rField,
        borderSide: BorderSide(color: p.border),
      ),
    ),
    listTileTheme: ListTileThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      style: ListTileStyle.list,
      iconColor: p.textDim,
      selectedColor: p.accent,
      selectedTileColor: p.accent.withValues(alpha: 0.10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      minVerticalPadding: 8,
      titleTextStyle: TextStyle(
        color: p.text,
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      subtitleTextStyle: TextStyle(color: p.textDim, fontSize: 12),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accent,
        shape: const RoundedRectangleBorder(borderRadius: rControl),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.text,
        side: BorderSide(color: p.border),
        shape: const RoundedRectangleBorder(borderRadius: rControl),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: rControl),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(34, 34),
        padding: const EdgeInsets.all(5),
        shape: const RoundedRectangleBorder(borderRadius: rControl),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surfaceAlt,
      selectedColor: p.accent.withValues(alpha: 0.18),
      disabledColor: p.surfaceAlt.withValues(alpha: 0.5),
      side: BorderSide(color: p.border),
      shape: const RoundedRectangleBorder(borderRadius: rControl),
      labelStyle: TextStyle(color: p.text, fontSize: 12.5),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.surface,
      contentTextStyle: TextStyle(color: p.text, fontSize: 13),
      actionTextColor: p.accent,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: rControl),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.accent,
      linearTrackColor: p.surfaceAlt,
      circularTrackColor: p.border,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: p.accent,
      inactiveTrackColor: p.surfaceAlt,
      thumbColor: p.accent,
      overlayColor: p.accent.withValues(alpha: 0.12),
      trackHeight: 3,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(9),
      radius: const Radius.circular(9),
      mainAxisMargin: 6,
      interactive: true,
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => p.textDim.withValues(
          alpha: s.contains(WidgetState.hovered) ? 0.55 : 0.28,
        ),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accent,
      selectionColor: p.accent.withValues(alpha: 0.26),
      selectionHandleColor: p.accent,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.onAccent : p.textDim,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.accent : p.surfaceAlt,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.accent : p.border,
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? p.accent : p.textDim,
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? p.accent : Colors.transparent,
      ),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      side: BorderSide(color: p.textDim, width: 1.3),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.text,
      unselectedLabelColor: p.textDim,
      indicatorColor: p.accent,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 13),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.chromeFill,
      indicatorColor: p.accent.withValues(alpha: 0.16),
      indicatorShape: const RoundedRectangleBorder(borderRadius: rControl),
      height: 58,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11.5, color: p.textDim)),
    ),
  );
}
