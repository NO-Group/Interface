import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'services/downloader.dart';
import 'services/web_engine.dart';
import 'state/browser_provider.dart';
import 'state/privacy_provider.dart';
import 'state/profile_provider.dart';
import 'state/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // WebView2 environment (Windows) / nothing to do elsewhere.
  await WebEngine.instance.init();

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsProvider(prefs: prefs);
  final profile = ProfileProvider(prefs: prefs);
  final privacy = PrivacyProvider(prefs: prefs);
  await settings.load();
  await profile.load();
  await privacy.load();

  final browser = BrowserProvider(
    settings: settings,
    profile: profile,
    privacy: privacy,
  );
  await browser.restoreSession();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: profile),
        ChangeNotifierProvider.value(value: privacy),
        ChangeNotifierProvider.value(value: browser),
        ChangeNotifierProvider.value(value: DownloadService()),
      ],
      child: const InterfaceApp(),
    ),
  );
}
