import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';

/// Owns the process-wide WebView environment.
///
/// On Windows, `flutter_inappwebview` requires a `WebViewEnvironment`
/// (WebView2) instance — created once here and passed to every web view.
class WebEngine {
  WebEngine._();

  static final WebEngine instance = WebEngine._();

  WebViewEnvironment? environment;
  String? initError;

  bool get requiresWebView2 => Platform.isWindows && environment == null;

  Future<void> init() async {
    if (!Platform.isWindows) return;
    try {
      final support = await getApplicationSupportDirectory();
      environment = await WebViewEnvironment.create(
        settings: WebViewEnvironmentSettings(
          userDataFolder:
              '${support.path}${Platform.pathSeparator}WebView2-Profile',
        ),
      );
    } catch (e) {
      initError = e.toString();
      debugPrint('WebViewEnvironment.create failed: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await environment?.dispose();
    } catch (_) {}
    environment = null;
  }
}

/// A believable desktop Chrome UA used by the "Desktop site" toggle on phones.
const kDesktopUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';
