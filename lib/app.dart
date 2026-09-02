import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/pal.dart';
import 'pages/browser_page.dart';
import 'state/browser_provider.dart';
import 'state/settings_provider.dart';

class InterfaceApp extends StatelessWidget {
  const InterfaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final browser = context.watch<BrowserProvider>();
    final palette = settings.palette(
      MediaQuery.platformBrightnessOf(context),
      incognitoActive: browser.current.incognito,
    );

    return MaterialApp(
      title: 'Interface Browser',
      debugShowCheckedModeBanner: false,
      theme: buildMaterialTheme(palette),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(settings.fontScale),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const BrowserPage(),
    );
  }
}
