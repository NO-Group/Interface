import 'package:flutter/material.dart';

import 'palette.dart';

/// Interface's visual language — "Keel".
///
/// One motif at every scale: a short bar of accent, laid along the edge that
/// carries the meaning. The window's keel runs down its left side and reports
/// what the page is doing. A tab's keel says this is the page you are on. A
/// header's keel says this panel belongs to that title. A row's keel says this
/// row is the one the window is showing. Everything else is navy plate, one
/// hairline weight, one cut corner, and no colour where nothing is happening.
///
/// There are no gradients on idle surfaces, no shadow on anything docked to an
/// edge, and nothing in the chrome that is not a control or a state.
abstract final class Ui {
  // ---- metrics ----
  static const double barHeight = 56;
  static const double tabHeight = 42;
  static const double bookmarkBarHeight = 32;
  static const double progressHeight = 2;

  /// The keel: 3px of accent, used everywhere at the same weight.
  static const double keelWidth = 3;

  /// The security stub is the address plate's own left corner.
  static const double stubWidth = 32;

  /// Chrome is measured from the window keel, so content never starts flush.
  static const double dockInset = 12;

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

  /// A moored tab is a hair rounder than a field, and never a pill.
  static const double rTab = 11;

  /// Every surface keeps three soft corners and one cut corner; this is how
  /// much tighter the cut one is.
  static const double tight = 0.28;

  static const double pad = 12;
  static const double padLg = 16;
  static const double hair = 1;
  static const double maxTextWidth = 680;

  // ---- motion ----
  static const Duration quick = Duration(milliseconds: 110);
  static const Duration normal = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 260);
  static const Curve curve = Curves.easeOutCubic;

  /// State changes settle with the smallest overshoot Flutter ships; movement
  /// does not. Only shapes and colours ride this.
  static const Curve settle = Curves.easeOutBack;

  /// Rows and plates arrive in a 14ms cascade, capped so a long list does not
  /// feel slow. Six items, then it is one group.
  static const int staggerDepth = 6;
  static const Duration staggerStep = Duration(milliseconds: 14);
  static Duration enter(int index) =>
      staggerStep * (index < staggerDepth ? index : staggerDepth - 1);

  // ---- type ----
  static const double sizeCaption = 12;
  static const double sizeSmall = 13;
  static const double sizeBody = 13.5;
  static const double sizeTitle = 15.5;
  static const double sizeHeadline = 21;
  static const double sizeHero = 30;

  /// The masthead size on the pages that open a view — home and welcome.
  static const double sizeMasthead = 40;

  /// The one text builder every surface uses, so weight and size stay
  /// consistent between the bar, the panels and the library pages. Tracking
  /// tightens as type gets bigger, and digits are tabular so counts, sizes
  /// and times line up in a column without a monospace font.
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
      letterSpacing: size >= sizeHeadline + 8
          ? -0.8
          : size >= sizeHeadline
              ? -0.3
              : size <= sizeCaption
                  ? 0.2
                  : 0.08,
      fontFeatures: const [FontFeature.tabularFigures()],
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

  /// The big left-aligned opener for home and welcome.
  static TextStyle masthead(BrowserPalette p) => text(
        p,
        size: sizeMasthead,
        weight: FontWeight.w800,
        height: 1.02,
      );

  /// A short label that sits above a value in a slate header.
  static TextStyle eyebrow(BrowserPalette p) => text(
        p,
        size: sizeCaption,
        weight: FontWeight.w700,
        color: p.accent,
        height: 1.1,
      );

  /// Fills a number of `1284` as `1,284` without pulling in intl.
  static String count(num value) {
    final s = value.toString();
    final dot = s.indexOf('.');
    final head = dot < 0 ? s : s.substring(0, dot);
    final tail = dot < 0 ? '' : s.substring(dot + 1);
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

  // ---- the motif ----

  /// The keel: a bar of colour laid along the edge that carries the meaning.
  ///
  /// [along] picks the edge; [length] is only used for the horizontal case.
  static Widget keel(
    BrowserPalette p, {
    Color? color,
    double width = keelWidth,
    double? length,
    bool horizontal = false,
    bool glow = false,
  }) {
    final c = color ?? p.accent;
    final bar = Container(
      width: horizontal ? null : width,
      height: horizontal ? width : null,
      constraints: horizontal ? BoxConstraints.tightFor(height: width) : null,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(width),
        boxShadow: glow
            ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 7)]
            : null,
      ),
      child: horizontal && length != null ? SizedBox(width: length) : null,
    );
    return bar;
  }

  /// A 16px tick at the leading edge instead of a full-width rule: rows read
  /// as a list of plates, not a table.
  static Widget tick(BrowserPalette p, {double width = 16, Color? color}) {
    return SizedBox(
      width: width,
      height: hair,
      child: ColoredBox(color: color ?? p.border),
    );
  }

  /// Hairline separator that respects the translucent-wallpaper theme.
  static Widget rule(BrowserPalette p,
      {double thickness = hair, EdgeInsets? margin}) {
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

  // ---- shapes ----

  /// Rounded clip that matches the radius we actually draw with.
  static Clip get clip => Clip.antiAlias;

  static BorderRadius radius(double v) => BorderRadius.circular(v);

  /// Three soft corners, one cut one. `at` names the corner that faces the
  /// content the surface belongs to.
  static BorderRadius petal(double v, {UiCorner at = UiCorner.bottomRight}) {
    final soft = Radius.circular(v);
    final cut = Radius.circular(v * tight);
    return BorderRadius.only(
      topLeft: at == UiCorner.topLeft ? cut : soft,
      topRight: at == UiCorner.topRight ? cut : soft,
      bottomRight: at == UiCorner.bottomRight ? cut : soft,
      bottomLeft: at == UiCorner.bottomLeft ? cut : soft,
    );
  }

  /// Only the given corners are rounded. A moored tab uses this: it is round
  /// where it meets the bar and square where it meets the page.
  static BorderRadius hang({
    double v = rField,
    bool top = true,
    bool bottom = false,
    bool left = true,
    bool right = true,
  }) {
    final r = Radius.circular(v);
    return BorderRadius.only(
      topLeft: top && left ? r : Radius.zero,
      topRight: top && right ? r : Radius.zero,
      bottomLeft: bottom && left ? r : Radius.zero,
      bottomRight: bottom && right ? r : Radius.zero,
    );
  }

  /// The lit top edge every raised surface carries: the first two pixels of
  /// the fill are brightened, which is what makes navy plate read as milled
  /// rather than a coloured rectangle. A gradient does this because a cut
  /// corner must keep a uniform border.
  static LinearGradient lift(BrowserPalette p, Color base) {
    final lit = Color.alphaBlend(
        Colors.white.withValues(alpha: p.isDark ? 0.10 : 0.62), base);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[lit, base, base],
      stops: const <double>[0, 0.035, 1],
    );
  }

  /// The address field / search plate: its own fill, a hairline, and the
  /// accent keel plus a bloom when it has focus.
  static BoxDecoration field({
    required BrowserPalette p,
    required bool focused,
    double radius = rField,
    Color? fill,
  }) {
    return BoxDecoration(
      color: focused ? p.surface : (fill ?? p.omniboxFill),
      borderRadius: petal(radius),
      // Focus does not ring the plate on all four sides; the edge light and the
      // keel drawn by the field itself say it. The border only tightens.
      border: Border.all(
        color: focused ? p.accent : p.border,
        width: hair,
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

  /// A raised, floating surface: menus, popovers, sheets, dialogs. Its cut
  /// corner points back at whatever opened it.
  static BoxDecoration floating(BrowserPalette p,
      {double radius = rMenu, UiCorner at = UiCorner.topLeft}) {
    return BoxDecoration(
      borderRadius: petal(radius, at: at),
      gradient: lift(p, p.surface),
      border: Border.all(color: p.border),
      boxShadow: float(p),
    );
  }

  /// Docked chrome (bars, panels): colour + the lit edge + one hairline.
  static BoxDecoration docked(
    BrowserPalette p, {
    Color? color,
    Border? border,
  }) {
    return BoxDecoration(
      gradient: lift(p, color ?? p.chromeFill),
      border: border ?? Border(bottom: BorderSide(color: p.border)),
    );
  }

  /// A slate: the plate every panel, card and dialog is made of.
  static BoxDecoration slate(BrowserPalette p,
      {Color? color, bool outlined = true, double radius = rCard}) {
    return BoxDecoration(
      borderRadius: petal(radius),
      gradient: lift(p, color ?? p.surface),
      border: outlined ? Border.all(color: p.border) : null,
    );
  }

  static BoxDecoration card(BrowserPalette p,
          {Color? color, bool outlined = true}) =>
      slate(p, color: color, outlined: outlined);

  static BoxDecoration tint(BrowserPalette p, Color color,
      {double radius = rControl}) {
    return BoxDecoration(
      color: color.withValues(alpha: p.isDark ? 0.18 : 0.12),
      borderRadius: petal(radius, at: UiCorner.topRight),
      border: Border.all(color: color.withValues(alpha: 0.45)),
    );
  }

  static List<BoxShadow> float(BrowserPalette p,
      {double y = 10, double blur = 26}) {
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: p.isDark ? 0.55 : 0.16),
        blurRadius: blur,
        offset: Offset(0, y),
      ),
    ];
  }
}

/// Which corner of a surface carries the cut radius.
enum UiCorner { topLeft, topRight, bottomRight, bottomLeft }

/// Derived colours so no widget invents its own alpha values.
extension UiPalette on BrowserPalette {
  /// Thin separator between like surfaces.
  Color get hairline => border;

  /// Slightly softer separator (inside lists).
  Color get hairlineSoft => border.withValues(alpha: 0.55);

  /// Hover wash for rows, chips and icon wells.
  Color get hoverFill => surfaceAlt.withValues(alpha: isDark ? 0.6 : 0.75);

  /// Pressed / current row wash.
  Color get activeFill => accent.withValues(alpha: isDark ? 0.16 : 0.11);

  /// The fill behind icon-button clusters in the bars.
  Color get clusterFill => surfaceAlt.withValues(alpha: isDark ? 0.5 : 0.6);

  /// Focus ring colour.
  Color get ring => accent.withValues(alpha: 0.6);

  Color get fieldFill => omniboxFill;
  Color get fieldBorder => border;

  /// What an idle keel looks like: present, unlit.
  Color get idleKeel => border;

  /// Whether the bar can afford a real blur — only in the wallpaper theme,
  /// where there is a picture behind it to look through.
  bool get blurredChrome => chromeTranslucent;

  /// Text that should recede (counts, host names).
  Color get textFaint => textDim.withValues(alpha: 0.8);

  Color get dangerSoft => danger.withValues(alpha: isDark ? 0.16 : 0.10);
  Color get successSoft => success.withValues(alpha: isDark ? 0.16 : 0.10);
  Color get accentSoft => activeFill;

  ShapeBorder get fieldShape => RoundedRectangleBorder(
        borderRadius: Ui.petal(Ui.rField),
      );
  ShapeBorder get controlShape => RoundedRectangleBorder(
        borderRadius: Ui.petal(Ui.rControl),
      );
  ShapeBorder get cardShape => RoundedRectangleBorder(
        borderRadius: Ui.petal(Ui.rCard),
      );
  ShapeBorder get slateShape => RoundedRectangleBorder(
        borderRadius: Ui.petal(Ui.rCard),
      );
  ShapeBorder get menuShape => RoundedRectangleBorder(
        borderRadius: Ui.petal(Ui.rMenu, at: UiCorner.topLeft),
      );
  ShapeBorder get pillShape => RoundedRectangleBorder(
        borderRadius: Ui.petal(Ui.rControl),
      );

  /// A moored tab: round where it meets the bar, square where it meets the
  /// page, so the tab reads as the page folded up into the chrome.
  ShapeBorder get tabShape => RoundedRectangleBorder(
        borderRadius: Ui.hang(v: Ui.rTab, bottom: false),
      );
}
