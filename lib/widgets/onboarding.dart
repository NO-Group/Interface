import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../core/palette.dart';
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
        icon: Icons.public_rounded,
        title: 'Welcome to Interface',
        body:
            'A real browser for your phone and laptop.\nNavy steel, cyan speed — built to get out of your way.',
      ),
      _Slide(
        palette: palette,
        icon: Icons.palette_outlined,
        title: 'Make it yours',
        body:
            'Light, Dark, Red, Green, Black & White,\nor your own picture behind frosted glass.',
        extra: _ThemePicker(
          palette: palette,
          picked: _pickedTheme,
          onPicked: (i) => setState(() => _pickedTheme = i),
        ),
      ),
      _Slide(
        palette: palette,
        icon: Icons.shield_rounded,
        title: 'Private by default',
        body:
            'Ads and trackers are blocked from the first page load.\nWatch the count climb in your Privacy dashboard.',
      ),
    ];

    return Container(
      color: palette.background.withValues(alpha: 0.98),
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
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _index == i ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color:
                                _index == i ? palette.accent : palette.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.primary,
                        foregroundColor: palette.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                      child: Text(
                        _index < slides.length - 1
                            ? 'Next'
                            : 'Start browsing',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
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
  final IconData icon;
  final String title;
  final String body;
  final Widget? extra;
  final bool logo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 34),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 86,
            height: 86,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [palette.primary, palette.background],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: palette.accent.withValues(alpha: 0.5)),
            ),
            child: Image.asset(
              'assets/brand/app_logo.png',
              errorBuilder: (_, __, ___) => Icon(icon, size: 44, color: palette.accent),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.text,
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.textDim,
              fontSize: 14.5,
              height: 1.6,
            ),
          ),
          if (extra != null) ...[
            const SizedBox(height: 26),
            extra!,
          ],
        ],
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
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? palette.accent : palette.border,
            width: active ? 2 : 1,
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
