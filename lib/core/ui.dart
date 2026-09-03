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

  static const double rControl = 9;
  static const double rField = 11;
  static const double rMenu = 13;
  static const double rCard = 15;
  static const double rSheet = 19;

  /// How much tighter the one chamfered corner of a surface is. Every surface
  /// in the app keeps three soft corners and one tight one, which points at
  /// whatever the surface belongs to.
  static const double tight = 0.3;

  /// The accent keyline drawn on the inside of a selected or active surface.
  static const double keyline = 2.5;

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
      letterSpacing: size <= sizeCaption ? 0.15 : (size < sizeTitle ? 0.08 : 0),
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
      borderRadius: petal(radius, at: UiCorner.bottomRight),
      border: Border.all(
        color: focused ? p.accent : p.border,
        width: focused ? 1.4 : hair,
      ),
      boxShadow: focused
          ? [
              BoxShadow(
                color: p.accent.withValues(alpha: p.isDark ? 0.26 : 0.18),
                blurRadius: 16,
                spreadRadius: 0.5,
              ),
            ]
          : null,
    );
  }

  /// A raised, floating surface: menus, popovers, sheets, dialogs.
  static BoxDecoration floating(BrowserPalette p,
      {double radius = rMenu, UiCorner at = UiCorner.topLeft}) {
    return BoxDecoration(
      borderRadius: petal(radius, at: at),
      gradient: lift(p, p.surface),
      border: Border.all(color: p.border),
      boxShadow: float(p),
    );
  }

  /// The lit top edge every raised surface carries: the first sliver of the
  /// fill is brightened, which is what makes navy plate read as milled metal
  /// rather than a coloured rectangle. A gradient does this because a
  /// chamfered surface must keep a uniform border.
  static LinearGradient lift(BrowserPalette p, Color base) {
    final lit = Color.alphaBlend(
        Colors.white.withValues(alpha: p.isDark ? 0.10 : 0.55), base);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: const <double>[0, 0.035, 1],
      colors: <Color>[lit, base, base],
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
      border: border ??
          Border(
            top: BorderSide(
                color: Colors.white.withValues(alpha: p.isDark ? 0.06 : 0.7)),
            bottom: BorderSide(color: p.border),
          ),
    );
  }

  static BoxDecoration card(BrowserPalette p, {Color? color, bool outlined = true}) {
    final base = color ?? p.surface;
    return BoxDecoration(
      borderRadius: petal(rCard),
      gradient: lift(p, base),
      border: outlined ? Border.all(color: p.border) : null,
    );
  }

  static BoxDecoration tint(BrowserPalette p, Color color, {double radius = rControl}) {
    return BoxDecoration(
      color: color.withValues(alpha: p.isDark ? 0.18 : 0.12),
      borderRadius: petal(radius, at: UiCorner.topRight),
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

  /// Three soft corners, one tight one. `at` names the corner that faces the
  /// content the surface belongs to.
  static BorderRadius petal(double v, {UiCorner at = UiCorner.bottomRight}) {
    final t = v * tight;
    return switch (at) {
      UiCorner.topLeft => BorderRadius.fromLTRB(t, v, v, v),
      UiCorner.topRight => BorderRadius.fromLTRB(v, t, v, v),
      UiCorner.bottomRight => BorderRadius.fromLTRB(v, v, t, v),
      UiCorner.bottomLeft => BorderRadius.fromLTRB(v, v, v, t),
    };
  }

  /// A petal that matches `Ui.radius`, for call sites that only know a number.
  static BorderRadius shape(double v,
          {UiCorner at = UiCorner.bottomRight}) =>
      petal(v, at: at);
}

/// Which corner of a surface carries the tight radius.
enum UiCorner { topLeft, topRight, bottomRight, bottomLeft }

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

  ShapeBorder get fieldShape => RoundedRectangleBorder(
        borderRadius: Ui.petal(Ui.rField, at: UiCorner.bottomRight),
      );
  ShapeBorder get controlShape => RoundedRectangleBorder(
        borderRadius: Ui.petal(Ui.rControl, at: UiCorner.bottomRight),
      );
  ShapeBorder get cardShape => RoundedRectangleBorder(
        borderRadius: Ui.petal(Ui.rCard),
      );
  ShapeBorder get menuShape => RoundedRectangleBorder(
        borderRadius: Ui.petal(Ui.rMenu, at: UiCorner.topLeft),
      );

  /// Tab pills: the tight corners sit on the side that faces the page.
  ShapeBorder get tabShape => RoundedRectangleBorder(
        borderRadius: Ui.petal(Ui.tabHeight / 2, at: UiCorner.bottomRight),
      );
  ShapeBorder get pillShape =>
      const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(999)));

  /// Chrome that sits over the user's wallpaper.
  bool get blurredChrome => chromeTranslucent;
}
