import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/urls.dart';
import '../services/blocklist.dart';
import '../services/web_engine.dart';
import 'profile_provider.dart';
import 'settings_provider.dart';

/// A single browser tab and everything the UI needs to know about it.
class BrowserTab {
  BrowserTab({
    required this.id,
    this.incognito = false,
    String? initialUrl,
    String initialTitle = '',
  })  : _initialUrl = initialUrl,
        title = initialTitle;

  final String id;
  final bool incognito;

  /// URL to load the first time the web view is created for this tab.
  String? _initialUrl;

  String? get initialUrl => _initialUrl;
  set initialUrl(String? url) {
    _initialUrl = url;
    if (url != null && url.isNotEmpty) hasWebView = true;
  }

  bool hasWebView = false;

  /// True while the tab sits on its home / speed-dial page.
  bool onSpeedDial = true;

  String url = '';
  String title = '';
  String? faviconUrl;

  bool loading = false;
  int progress = 0;

  /// Non-null while the last navigation failed (main frame only).
  String? error;

  bool canBack = false;
  bool canForward = false;

  InAppWebViewController? controller;

  String get displayTitle {
    if (onSpeedDial) return incognito ? 'Incognito' : 'New tab';
    if (title.trim().isNotEmpty) return title.trim();
    if (url.isNotEmpty) return hostOf(url);
    return 'New tab';
  }

  String get host => url.isEmpty ? '' : hostOf(url);
}

/// Which page the desktop Opera-style sidebar shows (null = collapsed).
enum SidePanel { none, bookmarks, history, downloads, settings }

/// Owns tabs, navigation, find-in-page, fullscreen and session restore.
class BrowserProvider extends ChangeNotifier {
  BrowserProvider({required this.settings, required this.profile})
      : super() {
    _newTab(incognito: false, silent: true);
  }

  final SettingsProvider settings;
  final ProfileProvider profile;

  final List<BrowserTab> _tabs = [];
  int index = 0;

  List<BrowserTab> get tabs => List.unmodifiable(_tabs);
  BrowserTab get current => _tabs.isEmpty ? _empty : _tabs[index.clamp(0, _tabs.length - 1)];
  int get tabCount => _tabs.length;
  bool get inIncognito => current.incognito;

  static final BrowserTab _empty = BrowserTab(id: 'none');

  // ---- UI state ----
  bool fullscreen = false;
  bool findOpen = false;
  String findQuery = '';
  int findMatchOrdinal = 0;
  int findMatchCount = 0;
  SidePanel sidePanel = SidePanel.none;

  /// Bumped to ask the omnibox to grab focus (Ctrl+L / Home).
  int omniboxFocusEpoch = 0;

  Timer? _sessionDebounce;
  bool _restoring = false;

  // ---- Tab lifecycle ----

  BrowserTab newTab({bool incognito = false, String? url}) {
    final t = _newTab(incognito: incognito, url: url);
    _scheduleSessionSave();
    return t;
  }

  BrowserTab _newTab({required bool incognito, String? url, bool silent = false}) {
    final home = url ??
        (incognito || settings.homePage.isEmpty ? null : settings.homePage);
    final t = BrowserTab(
      id: 'tab-${DateTime.now().microsecondsSinceEpoch}-$incognito',
      incognito: incognito,
      initialUrl: home,
    );
    t.onSpeedDial = t.initialUrl == null;
    _tabs.add(t);
    index = _tabs.length - 1;
    if (!silent) notifyListeners();
    return t;
  }

  void select(int i) {
    if (i < 0 || i >= _tabs.length || i == index) return;
    index = i;
    _scheduleSessionSave();
    notifyListeners();
  }

  void closeTab(BrowserTab tab) {
    final i = _tabs.indexOf(tab);
    if (i < 0) return;
    _tabs.removeAt(i);
    if (_tabs.isEmpty) {
      _newTab(incognito: false);
    } else {
      if (index >= _tabs.length) index = _tabs.length - 1;
      if (index > 0 && i < index) index--;
      if (_tabs.length == 1) index = 0;
    }
    _scheduleSessionSave();
    notifyListeners();
  }

  void closeCurrent() => closeTab(current);

  void closeOthers(BrowserTab keep) {
    _tabs.removeWhere((t) => t != keep);
    index = 0;
    _scheduleSessionSave();
    notifyListeners();
  }

  void closeToTheRight(BrowserTab leftmost) {
    final i = _tabs.indexOf(leftmost);
    if (i < 0) return;
    _tabs.removeRange(i + 1, _tabs.length);
    if (index > i) index = i;
    _scheduleSessionSave();
    notifyListeners();
  }

  void duplicateTab(BrowserTab tab) {
    final t = newTab(incognito: tab.incognito);
    if (tab.url.isNotEmpty && !tab.onSpeedDial) {
      _load(t, tab.url);
    }
  }

  void closeAllIncognito() {
    _tabs.removeWhere((t) => t.incognito);
    if (_tabs.isEmpty) {
      _newTab(incognito: false);
    } else if (current.incognito) {
      index = 0;
    }
    _scheduleSessionSave();
    notifyListeners();
  }

  void selectNext() => select((index + 1) % _tabs.length);

  void selectPrevious() => select((index - 1 + _tabs.length) % _tabs.length);

  void moveCurrentToIndex(int target) {
    final t = _tabs.removeAt(index);
    _tabs.insert(target.clamp(0, _tabs.length), t);
    index = _tabs.indexOf(t);
    _scheduleSessionSave();
    notifyListeners();
  }

  // ---- Navigation ----

  /// Entry point for the omnibox, speed dial and search box.
  Future<void> navigate(String input) async {
    final value = input.trim();
    if (value.isEmpty) return;
    final uri = urlFromInput(value);

    if (uri == null) {
      _load(current, settings.searchEngine.queryUrl(value));
      return;
    }
    if (isExternalScheme(uri)) {
      await _launchExternal(uri);
      return;
    }
    if (!isWebScheme(uri)) {
      // Unknown scheme — let the OS try, otherwise search for the text.
      final ok = await _launchExternal(uri);
      if (!ok) _load(current, settings.searchEngine.queryUrl(value));
      return;
    }
    _load(current, uri.toString());
  }

  Future<bool> launchExternal(Uri uri) => _launchExternal(uri);

  Future<bool> _launchExternal(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  void _load(BrowserTab tab, String url) {
    tab.onSpeedDial = false;
    tab.error = null;
    tab.url = url;
    final c = tab.controller;
    if (c != null) {
      unawaited(
        c.loadUrl(URLRequest(url: WebUri(url))).catchError((_) {}),
      );
    } else {
      tab.initialUrl = url;
    }
    notifyListeners();
    _scheduleSessionSave();
  }

  void goHome() {
    final t = current;
    final home = settings.homePage.trim();
    if (home.isEmpty) {
      t.onSpeedDial = true;
      t.error = null;
      try {
        t.controller?.stopLoading();
      } catch (_) {}
      notifyListeners();
    } else {
      _load(t, home);
    }
  }

  Future<void> goBack() async {
    final c = current.controller;
    if (c == null) return;
    if (await c.canGoBack()) {
      current.error = null;
      await c.goBack();
    }
    await syncNavState(current);
  }

  Future<void> goForward() async {
    final c = current.controller;
    if (c == null) return;
    if (await c.canGoForward()) await c.goForward();
    await syncNavState(current);
  }

  Future<void> reload() async {
    final t = current;
    final c = t.controller;
    if (c == null) {
      if (t.initialUrl != null) _load(t, t.initialUrl!);
      return;
    }
    t.error = null;
    notifyListeners();
    try {
      await c.reload();
    } on MissingPluginException {
      _load(t, t.url);
    }
  }

  void stopLoading() {
    try {
      current.controller?.stopLoading();
    } catch (_) {}
  }

  /// Should the navigation be blocked (ads / pop-ups)?
  NavigationActionPolicy? filterNavigation(NavigationAction action) {
    if (!settings.blockAds) return null;
    final uri = action.request.url;
    if (uri == null) return null;
    if (!uri.scheme.startsWith('http')) return null;
    if (isBlockedHost(uri.host)) return NavigationActionPolicy.CANCEL;
    return null;
  }

  Future<void> syncNavState(BrowserTab tab) async {
    final c = tab.controller;
    if (c == null) {
      tab.canBack = false;
      tab.canForward = false;
    } else {
      try {
        tab.canBack = await c.canGoBack();
      } catch (_) {
        tab.canBack = false;
      }
      try {
        tab.canForward = await c.canGoForward();
      } catch (_) {
        tab.canForward = false;
      }
    }
    notifyListeners();
  }

  /// Called by TabWebView whenever something visual changed.
  void tabChanged(BrowserTab tab, {bool structural = true}) {
    notifyListeners();
    if (structural) _scheduleSessionSave();
  }

  // ---- Fullscreen ----

  void setFullscreen(bool v) {
    if (fullscreen == v) return;
    fullscreen = v;
    notifyListeners();
  }

  // ---- Find in page ----

  void openFind() {
    findOpen = true;
    notifyListeners();
  }

  void closeFind() {
    findOpen = false;
    findQuery = '';
    findMatchCount = 0;
    findMatchOrdinal = 0;
    notifyListeners();
    for (final t in _tabs) {
      try {
        t.controller?.clearMatches();
      } catch (_) {}
    }
  }

  void updateFindResults(int ordinal, int count, bool done) {
    findMatchOrdinal = ordinal;
    findMatchCount = count;
    notifyListeners();
  }

  // ---- Desktop side panel ----

  void toggleSidePanel(SidePanel page) {
    sidePanel = sidePanel == page ? SidePanel.none : page;
    notifyListeners();
  }

  void setSidePanel(SidePanel page) {
    sidePanel = page;
    notifyListeners();
  }

  // ---- Omnibox focus requests ----

  void requestOmniboxFocus() {
    omniboxFocusEpoch++;
    notifyListeners();
  }

  // ---- Session restore ----

  Future<void> restoreSession() async {
    if (!settings.restoreSession) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('session.tabs');
      if (raw == null || raw.isEmpty) return;
      final list = (const JsonCodec().decode(raw) as List)
          .map((e) => e as Map<String, dynamic>)
          .toList(growable: false);
      if (list.isEmpty) return;
      _restoring = true;
      _tabs.clear();
      for (final e in list) {
        final url = e['url'] as String? ?? '';
        final title = e['title'] as String? ?? '';
        final incog = e['incognito'] as bool? ?? false;
        if (url.isEmpty) continue;
        final t = BrowserTab(
          id:
              'tab-r${DateTime.now().microsecondsSinceEpoch}-${_tabs.length}',
          incognito: incog,
          initialUrl: url,
          initialTitle: title,
        );
        t.onSpeedDial = false;
        _tabs.add(t);
      }
      if (_tabs.isEmpty) {
        _newTab(incognito: false);
      } else {
        final saved = prefs.getInt('session.index') ?? 0;
        index = saved.clamp(0, _tabs.length - 1);
      }
      _restoring = false;
      notifyListeners();
    } catch (e) {
      debugPrint('restoreSession: $e');
      if (_tabs.isEmpty) _newTab(incognito: false);
    }
  }

  void _scheduleSessionSave() {
    if (_restoring) return;
    _sessionDebounce?.cancel();
    _sessionDebounce = Timer(const Duration(milliseconds: 900), _saveSession);
  }

  Future<void> _saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final open = _tabs
          .where((t) => !t.incognito && t.url.isNotEmpty && !t.onSpeedDial)
          .map(
            (t) => {
              'url': t.url,
              'title': t.title,
              'incognito': false,
            },
          )
          .toList();
      await prefs.setString('session.tabs', jsonEncode(open));
      await prefs.setInt(
        'session.index',
        open.isEmpty ? 0 : index.clamp(0, open.length - 1),
      );
    } catch (e) {
      debugPrint('saveSession: $e');
    }
  }

  /// Applies changed global settings (e.g. desktop UA) to live web views.
  Future<void> refreshWebViews() async {
    for (final t in _tabs) {
      final c = t.controller;
      if (c == null) continue;
      try {
        // Best effort — dynamic call keeps us safe across plugin versions.
        final dynamic cc = c;
        await cc.setSettings(
          settings: buildSettingsFor(
            tab: t,
            desktopMode: settings.desktopMode,
            blockAds: settings.blockAds,
          ),
        );
        await c.reload();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _sessionDebounce?.cancel();
    super.dispose();
  }
}

/// Shared web-view settings builder (used by TabWebView + refreshWebViews).
InAppWebViewSettings buildSettingsFor({
  required BrowserTab tab,
  required bool desktopMode,
  required bool blockAds,
}) {
  return InAppWebViewSettings(
    javaScriptEnabled: true,
    useShouldOverrideUrlLoading: true,
    useOnDownloadStartRequest: true,
    transparentBackground: true,
    supportZoom: true,
    mediaPlaybackRequiresUserGesture: false,
    incognito:
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) &&
        tab.incognito,
    userAgent: desktopMode &&
            (defaultTargetPlatform == TargetPlatform.android ||
                defaultTargetPlatform == TargetPlatform.iOS)
        ? kDesktopUserAgent
        : null,
  );
}

/// The shared WebView environment (Windows) for every tab.
WebViewEnvironment? get webViewEnvironment => WebEngine.instance.environment;
