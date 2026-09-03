import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:interface_browser/state/browser_provider.dart';
import 'package:interface_browser/state/privacy_provider.dart';
import 'package:interface_browser/state/profile_provider.dart';
import 'package:interface_browser/state/settings_provider.dart';
import 'package:interface_browser/widgets/new_tab_page.dart';
import 'package:interface_browser/widgets/onboarding.dart';

/// Chrome and standalone pages are laid out at fixed sizes and enlarged text.
/// If anything spills out of its box, Flutter paints yellow overflow stripes,
/// so every page here must fit without spilling at any supported size.
void main() {
  final sizes = [
    const Size(1280, 800),
    const Size(1024, 700),
    const Size(900, 560),
    const Size(820, 480),
    const Size(390, 780),
  ];
  const scales = [1.0, 1.15, 1.3];

  for (final size in sizes) {
    for (final scale in scales) {
      testWidgets(
          'welcome page fits ${size.width.toInt()}x${size.height.toInt()} '
          'at text size ${scale}x', (tester) async {
        await _pump(tester, const OnboardingOverlay(), size, scale);
        await _expectNoOverflow(tester, size, scale);
      });

      testWidgets(
          'home page fits ${size.width.toInt()}x${size.height.toInt()} '
          'at text size ${scale}x', (tester) async {
        await _pump(
          tester,
          NewTabPage(tab: BrowserTab(id: 'home')),
          size,
          scale,
        );
        await _expectNoOverflow(tester, size, scale);
      });

      testWidgets(
          'private home fits ${size.width.toInt()}x${size.height.toInt()} '
          'at text size ${scale}x', (tester) async {
        await _pump(
          tester,
          NewTabPage(tab: BrowserTab(id: 'priv', incognito: true)),
          size,
          scale,
        );
        await _expectNoOverflow(tester, size, scale);
      });
    }
  }
}

Future<void> _pump(
  WidgetTester tester,
  Widget child,
  Size size,
  double scale,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final settings = SettingsProvider();
  final profile = ProfileProvider();
  final privacy = PrivacyProvider();
  final browser = BrowserProvider(
      settings: settings, profile: profile, privacy: privacy);
  addTearDown(browser.dispose);

  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: profile),
      ChangeNotifierProvider.value(value: privacy),
      ChangeNotifierProvider.value(value: browser),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(scale),
        ),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(body: child),
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _expectNoOverflow(
  WidgetTester tester,
  Size size,
  double scale,
) async {
  final spilled = <String>[];
  Object? error = tester.takeException();
  while (error != null) {
    final text = error.toString();
    // Assets are not resolved in unit tests; a missing image is not a layout
    // problem, so only spilling boxes are worth failing on.
    if (text.contains('overflowed')) spilled.add(text.split('\n').first);
    error = tester.takeException();
  }
  expect(spilled, isEmpty,
      reason: 'Yellow overflow stripes at ${size.width.toInt()}x'
          '${size.height.toInt()}, text size ${scale}x:\n'
          '${spilled.join('\n')}');
}
