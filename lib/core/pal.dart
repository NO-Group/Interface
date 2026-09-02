import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/browser_provider.dart';
import '../state/settings_provider.dart';
import 'palette.dart';

export 'palette.dart';

/// Reads the palette that is currently in effect (theme + incognito aware).
///
/// Call inside `build` — it watches both providers and rebuilds on change.
BrowserPalette pal(BuildContext context) {
  final settings = context.watch<SettingsProvider>();
  final browser = context.watch<BrowserProvider>();
  return settings.palette(
    MediaQuery.platformBrightnessOf(context),
    incognitoActive: browser.current.incognito,
  );
}
