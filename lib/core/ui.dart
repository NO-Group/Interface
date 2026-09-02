import 'package:flutter/material.dart';

import 'palette.dart';

/// Interface's own visual language.
///
/// The idea in one line: flat navy-ink surfaces, one hairline weight, gentle
/// rounding, and colour used only where something is actually happening
/// (focus, loading, selected, blocked). No gradients, no glassmorphism, no
/// shadow on anything that is docked to an edge.
abstract final class Ui {
  // ---- metrics ----
  static const double barHeight = 52;
  static const double tabHeight = 34;
  static const double bookmarkBarHeight = 34;
  static const double progressHeight = 2;
  static const double mobileBarHeight = 52;
  static const double sidePanelWidth = 372;
  static const double sideRailWidth = 52;
  static const double menuRowHeight = 40;
  static const double listItemHeight = 52;

  static const double rControl = 8;
  static const double rField = 10;
  static const double rMenu = 12;
  static const double rCard = 14;
  static const double rSheet = 18;

  static const double gap = 8;
  static const double pad = 12;
  static const double padLg = 16;
  static const double hair = 1;
  static const double maxTextWidth = 680;

  // ---- motion ----
  static const Duration quick = Duration(milliseconds: 110);
  static const Duration normal = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 260);
  static const Curve curve = Curves.easeOutCubic;

  // ---- type ----
  static const double sizeCaption = 12;
  static const double sizeSmall = 13;
  static const double sizeBody = 13.5;
  static const double sizeTitle = 15.5;
  static const double sizeHeadline = 21;
  static const double sizeHero = 30;

  /// The one text builder every surface uses, so weight and size stay
  /// consistent between the bar, the panels and the library pages.
  static TextStyle text(
    BrowserPalette p, {
    double size = sizeBody,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double height = 1.35,
  }) {
    return TextStyle(
      color: color ?? p.text,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: 0,
    );
  }

  static TextStyle caption(BrowserPalette p, {Color? color}) => text(
        p,
        size: sizeCaption,
        color: color ?? p.textDim,
      );

  static TextStyle section(BrowserPalette p) => text(
        p,
        size: sizeBody,
        weight: FontWeight.w700,
      );

  /// Fills a number of `1284` as `1,284` without pulling in intl.
  static String count(num value) {
    final s = value.toString();
    final dot = s.indexOf('.');
    final head = dot < 0 ? s : s.substring(0, dot);
    final tail = dot < 0 ? '' : s.substring(dot);
    final neg = head.startsWith('-');
    final digits = neg ? head.substring(1) : head;
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
      out.write(digits[i]);
    }
    return '${neg ? '-' : ''}$out$tail';
  }

  /// Horizontal spacer (Rows) — `Ui.gap()` is the standard 8.
  static Widget gap([double w = 8]) => SizedBox(width: w);

  /// Vertical spacer (Columns) — `Ui.vgap()` is the standard 8.
  static Widget vgap([double h = 8]) => SizedBox(height: h);

  /// Hairline separator that respects the translucent-wallpaper theme.
  static Widget rule(BrowserPalette p, {double thickness = hair, EdgeInsets? margin}) {
    final line = ColoredBox(color: p.border);
    if (margin == null) {
      return SizedBox(height: thickness, child: line);
    }
    return Padding(
      padding: margin,
      child: SizedBox(height: thickness, child: line),
    );
  }

  /// Vertical hairline used between controls.
  static Widget vRule(BrowserPalette p, {double height = 18}) {
    return SizedBox(
      width: hair,
      height: height,
      child: ColoredBox(color: p.border),
    );
  }

  /// The address field / search field look: quiet fill, border appears on
  /// focus and turns accent.
  static BoxDecoration field({
    required BrowserPalette p,
    required bool focused,
    double radius = rField,
    Color? fill,
  }) {
    return BoxDecoration(
      color: focused ? p.surface : (fill ?? p.omniboxFill),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: focused ? p.accent : p.border.withValues(alpha: 0.0),
        width: focused ? 1.4 : hair,
      ),
    );
  }

  /// A raised, floating surface: menus, popovers, sheets, dialogs.
  static BoxDecoration floating(BrowserPalette p, {double radius = rMenu}) {
    return BoxDecoration(
      color: p.surface,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: p.border),
      boxShadow: float(p),
    );
  }

  /// Docked chrome (bars, panels): colour + hairline, never a shadow.
  static BoxDecoration docked(
    BrowserPalette p, {
    Color? color,
    Border? border,
  }) {
    return BoxDecoration(
      color: color ?? p.chromeFill,
      border: border ?? Border(bottom: BorderSide(color: p.border)),
    );
  }

  static BoxDecoration card(BrowserPalette p, {Color? color, bool outlined = true}) {
    return BoxDecoration(
      color: color ?? p.surface,
      borderRadius: BorderRadius.circular(rCard),
      border: outlined ? Border.all(color: p.border) : null,
    );
  }

  static BoxDecoration tint(BrowserPalette p, Color color, {double radius = rControl}) {
    return BoxDecoration(
      color: color.withValues(alpha: p.isDark ? 0.18 : 0.12),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: color.withValues(alpha: 0.45)),
    );
  }

  static List<BoxShadow> float(BrowserPalette p, {double y = 10, double blur = 26}) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: p.isDark ? 0.55 : 0.16),
        blurRadius: blur,
        offset: Offset(0, y),
      ),
    ];
  }

  /// Rounded clip that matches the radius we actually draw with.
  static Clip get clip => Clip.antiAlias;

  static BorderRadius radius(double v) => BorderRadius.circular(v);

}

/// Derived colours so no widget invents its own alpha values.
extension UiPalette on BrowserPalette {
  /// Thin separator between like surfaces.
  Color get hairline => border;

  /// Slightly softer separator (inside lists).
  Color get hairlineSoft => border.withValues(alpha: 0.55);

  /// Hover wash for rows, chips and icon buttons.
  Color get hoverFill => surfaceAlt.withValues(alpha: isDark ? 0.6 : 0.75);

  /// Pressed / current row wash.
  Color get activeFill => accent.withValues(alpha: isDark ? 0.16 : 0.11);

  /// The fill behind icon-button clusters in the bars.
  Color get clusterFill => surfaceAlt.withValues(alpha: isDark ? 0.5 : 0.6);

  /// Focus ring colour.
  Color get ring => accent.withValues(alpha: 0.6);

  Color get fieldFill => omniboxFill;
  Color get fieldBorder => border;

  /// Text that should recede (counts, host names).
  Color get textFaint => textDim.withValues(alpha: 0.8);

  Color get dangerSoft => danger.withValues(alpha: isDark ? 0.16 : 0.10);
  Color get successSoft => success.withValues(alpha: isDark ? 0.16 : 0.10);
  Color get accentSoft => activeFill;

  ShapeBorder get fieldShape =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ui.rField));
  ShapeBorder get controlShape =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ui.rControl));
  ShapeBorder get cardShape =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ui.rCard));
  ShapeBorder get menuShape =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ui.rMenu));
  ShapeBorder get pillShape =>
      const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(999)));

  /// Chrome that sits over the user's wallpaper.
  bool get blurredChrome => chromeTranslucent;
}
