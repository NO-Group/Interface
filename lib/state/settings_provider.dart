import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/palette.dart';
import '../core/urls.dart';

/// Reader color schemes.
enum ReaderTheme { paper, sepia, night }

/// User settings + theme resolution. Persisted to SharedPreferences.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;
  bool loaded = false;

  ThemeChoice themeChoice = ThemeChoice.system;
  String searchEngineId = SearchEngine.google.id;

  /// Empty string → the Speed Dial new-tab page.
  String homePage = '';

  bool blockAds = true;
  bool cosmeticFiltering = true;
  bool desktopMode = false;
  bool showBookmarksBar = true;
  bool restoreSession = true;
  bool grayscaleInMono = true;

  /// Desktop: tabs in a vertical rail instead of the top strip.
  bool verticalTabs = false;

  /// UI text scale multiplier (0.85 – 1.30).
  double fontScale = 1.0;

  /// First-run onboarding finished.
  bool onboardingSeen = false;

  /// Reader-mode preferences.
  double readerFontSize = 18;
  ReaderTheme readerTheme = ReaderTheme.paper;

  /// Absolute path of the chosen wallpaper (custom theme).
  String? customBgPath;

  SearchEngine get searchEngine => SearchEngine.byId(searchEngineId);

  bool get hasCustomBackground =>
      themeChoice == ThemeChoice.custom &&
      customBgPath != null &&
      File(customBgPath!).existsSync();

  bool get grayscaleContent =>
      themeChoice == ThemeChoice.mono && grayscaleInMono;

  Future<void> load() async {
    _prefs ??= await SharedPreferences.getInstance();
    final p = _prefs!;
    themeChoice = ThemeChoiceX.fromId(p.getString('ui.theme'));
    searchEngineId = p.getString('ui.engine') ?? SearchEngine.google.id;
    homePage = p.getString('ui.home') ?? '';
    blockAds = p.getBool('ui.blockAds') ?? true;
    cosmeticFiltering = p.getBool('ui.cosmetic') ?? true;
    desktopMode = p.getBool('ui.desktopMode') ?? false;
    showBookmarksBar = p.getBool('ui.bookmarksBar') ?? true;
    restoreSession = p.getBool('ui.restoreSession') ?? true;
    grayscaleInMono = p.getBool('ui.grayscaleMono') ?? true;
    verticalTabs = p.getBool('ui.verticalTabs') ?? false;
    fontScale = p.getDouble('ui.fontScale') ?? 1.0;
    onboardingSeen = p.getBool('ui.onboarded') ?? false;
    readerFontSize = p.getDouble('ui.readerFont') ?? 18;
    final rt = p.getString('ui.readerTheme');
    readerTheme = ReaderTheme.values
        .where((t) => t.name == rt)
        .firstOrNull ?? ReaderTheme.paper;
    customBgPath = p.getString('ui.customBg');
    loaded = true;
    notifyListeners();
  }

  Future<void> _set(String key, Object? value) async {
    final p = _prefs ??= await SharedPreferences.getInstance();
    if (value == null) {
      await p.remove(key);
    } else if (value is bool) {
      await p.setBool(key, value);
    } else if (value is double) {
      await p.setDouble(key, value);
    } else if (value is String) {
      await p.setString(key, value);
    }
    notifyListeners();
  }

  void setThemeChoice(ThemeChoice choice) {
    themeChoice = choice;
    _set('ui.theme', choice.id);
  }

  void setSearchEngine(String id) {
    searchEngineId = id;
    _set('ui.engine', id);
  }

  void setHomePage(String url) {
    homePage = url.trim();
    _set('ui.home', homePage);
  }

  void setBlockAds(bool v) {
    blockAds = v;
    _set('ui.blockAds', v);
  }

  void setCosmeticFiltering(bool v) {
    cosmeticFiltering = v;
    _set('ui.cosmetic', v);
  }

  void setDesktopMode(bool v) {
    desktopMode = v;
    _set('ui.desktopMode', v);
  }

  void setShowBookmarksBar(bool v) {
    showBookmarksBar = v;
    _set('ui.bookmarksBar', v);
  }

  void setRestoreSession(bool v) {
    restoreSession = v;
    _set('ui.restoreSession', v);
  }

  void setGrayscaleInMono(bool v) {
    grayscaleInMono = v;
    _set('ui.grayscaleMono', v);
  }

  void setVerticalTabs(bool v) {
    verticalTabs = v;
    _set('ui.verticalTabs', v);
  }

  void setFontScale(double v) {
    fontScale = v.clamp(0.85, 1.3);
    _set('ui.fontScale', fontScale);
  }

  void setOnboardingSeen([bool v = true]) {
    onboardingSeen = v;
    _set('ui.onboarded', v);
  }

  void setReaderFontSize(double v) {
    readerFontSize = v.clamp(14.0, 26.0);
    _set('ui.readerFont', readerFontSize);
  }

  void setReaderTheme(ReaderTheme t) {
    readerTheme = t;
    _set('ui.readerTheme', t.name);
  }

  /// Copies the picked picture into the app-support dir so it survives
  /// even if the original is deleted, then activates the custom theme.
  Future<String?> setCustomBackground(String pickedPath) async {
    try {
      final support = await getApplicationSupportDirectory();
      final ext = (pickedPath.lastIndexOf('.') >= 0)
          ? pickedPath.substring(pickedPath.lastIndexOf('.')).toLowerCase()
          : '.img';
      const ok = ['.png', '.jpg', '.jpeg', '.webp', '.bmp'];
      final suffix = ok.contains(ext) ? ext : '.png';
      final target =
          '${support.path}${Platform.pathSeparator}wallpaper$suffix';
      await File(pickedPath).copy(target);
      customBgPath = target;
      themeChoice = ThemeChoice.custom;
      await _set('ui.customBg', target);
      await _set('ui.theme', ThemeChoice.custom.id);
      return target;
    } catch (e) {
      debugPrint('setCustomBackground failed: $e');
      return null;
    }
  }

  Future<void> clearCustomBackground() async {
    final old = customBgPath;
    customBgPath = null;
    await _set('ui.customBg', null);
    if (old != null) {
      try {
        await File(old).delete();
      } catch (_) {}
    }
    if (themeChoice == ThemeChoice.custom) {
      setThemeChoice(ThemeChoice.dark);
    }
  }

  BrowserPalette palette(
    Brightness platformBrightness, {
    bool incognitoActive = false,
  }) =>
      BrowserPalette.resolve(
        themeChoice,
        platformBrightness,
        incognitoActive: incognitoActive,
      );
}
