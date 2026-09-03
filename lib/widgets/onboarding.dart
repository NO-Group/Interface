import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'icons.dart';

import '../core/pal.dart';
import '../core/ui.dart';
import 'logo.dart';
import '../state/settings_provider.dart';

/// First-run welcome: brand + theme preview + privacy promise.
class OnboardingOverlay extends StatefulWidget {
  const OnboardingOverlay({super.key});

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  final _page = PageController();
  int _index = 0;
  int? _pickedTheme;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    final settings = context.watch<SettingsProvider>();
    final size = MediaQuery.sizeOf(context);

    final slides = <Widget>[
      _Slide(
        palette: palette,
        logo: true,
        icon: 'globe',
        title: 'Welcome to Interface',
        body:
            'One row of controls, tabs that stay out of the way,\nand a browser that doesn’t pretend to be someone else’s.',
      ),
      _Slide(
        palette: palette,
        icon: 'palette',
        title: 'Make it yours',
        body:
            'Pick a look now, change it later in Settings.\nYou can also put your own picture behind the app.',
        extra: _ThemePicker(
          palette: palette,
          picked: _pickedTheme,
          onPicked: (i) => setState(() => _pickedTheme = i),
        ),
      ),
      _Slide(
        palette: palette,
        icon: 'shield-on',
        title: 'Private by default',
        body:
            'Ads and trackers are blocked from the first page load.\nTap the shield any time to see what happened on a page.',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: palette.background.withValues(alpha: 0.98),
        gradient: RadialGradient(
          center: const Alignment(0, -0.9),
          radius: 1.3,
          colors: <Color>[
            palette.accent.withValues(alpha: 0.12),
            palette.accent.withValues(alpha: 0),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _page,
                onPageChanged: (i) => setState(() => _index = i),
                children: slides,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < slides.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _index == i ? 26 : 10,
                          height: 4,
                          decoration: BoxDecoration(
                            color:
                                _index == i ? palette.accent : palette.border,
                            borderRadius: BorderRadius.circular(3),
                            boxShadow: _index == i
                                ? <BoxShadow>[
                                    BoxShadow(
                                      color: palette.accent
                                          .withValues(alpha: 0.6),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: palette.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: Ui.petal(Ui.rField),
                        ),
                      ),
                      onPressed: () {
                        if (_index < slides.length - 1) {
                          _page.nextPage(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                          );
                        } else {
                          if (_pickedTheme != null) {
                            settings.setThemeChoice(
                                ThemeChoice.values[_pickedTheme!]);
                          }
                          settings.setOnboardingSeen();
                        }
                      },
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _index < slides.length - 1
                              ? 'Next'
                              : 'Start browsing',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      if (_pickedTheme != null) {
                        settings.setThemeChoice(ThemeChoice.values[_pickedTheme!]);
                      }
                      settings.setOnboardingSeen();
                    },
                    child: Text(
                      'Skip',
                      style: TextStyle(color: palette.textDim, fontSize: 13),
                    ),
                  ),
                  if (size.width >= 840) const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.palette,
    required this.icon,
    required this.title,
    required this.body,
    this.extra,
    this.logo = false,
  });

  final BrowserPalette palette;
  final Object icon;
  final String title;
  final String body;
  final Widget? extra;
  final bool logo;

  @override
  Widget build(BuildContext context) {
    // Centred when the window is tall enough, scrollable when it is not, so
    // the slide can never spill out of the page and be painted with overflow
    // stripes.
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 18),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: (box.maxHeight - 36).clamp(0.0, double.infinity)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          // The app's own artwork for the welcome slide; the other slides get
          // an icon, drawn on nothing.
          if (logo)
            const LogoMark(size: 66)
          else
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: Ui.tint(palette, palette.accent, radius: 20),
              child: uiGlyph(icon, size: 30, color: palette.accent),
            ),
          const SizedBox(height: 30),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Ui.text(
              palette,
              size: Ui.sizeHero,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: Ui.text(
              palette,
              size: 14,
              color: palette.textDim,
              height: 1.6,
            ),
          ),
          if (extra != null) ...[
            const SizedBox(height: 26),
            extra!,
          ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({
    required this.palette,
    required this.picked,
    required this.onPicked,
  });

  final BrowserPalette palette;
  final int? picked;
  final void Function(int) onPicked;

  static const _labels = ['Light', 'Dark', 'Red', 'Green', 'B&W'];

  @override
  Widget build(BuildContext context) {
    final choices = [
      ThemeChoice.light,
      ThemeChoice.dark,
      ThemeChoice.red,
      ThemeChoice.green,
      ThemeChoice.mono,
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < choices.length; i++)
          _chip(BrowserPalette.resolve(choices[i], Brightness.dark),
              _labels[i], i),
      ],
    );
  }

  Widget _chip(BrowserPalette p, String label, int i) {
    final active = picked == i;
    return InkWell(
      onTap: () => onPicked(i),
      borderRadius: Ui.petal(12, at: UiCorner.topLeft),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? palette.activeFill : p.background,
          borderRadius: Ui.petal(Ui.rField, at: UiCorner.topLeft),
          border: Border.all(
            color: active ? palette.accent : palette.border,
            width: active ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 13,
              height: 13,
              decoration:
                  BoxDecoration(color: p.accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: p.text,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
