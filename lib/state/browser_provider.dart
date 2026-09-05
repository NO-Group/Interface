import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/urls.dart';
import '../models.dart';
import '../services/blocklist.dart';
import '../services/web_engine.dart';
import 'privacy_provider.dart';
import 'profile_provider.dart';
import 'settings_provider.dart';

/// A single browser tab and everything the UI needs to know about it.
class BrowserTab {
  BrowserTab({
    required this.id,
    this.incognito = false,
    String? initialUrl,
    String initialTitle = '',
    this.groupId,
  })  : _initialUrl = initialUrl,
        title = initialTitle;

  final String id;
  final bool incognito;
  String? groupId;

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

  /// The URL that per-site rules apply to.
  String get siteUrl => url.isNotEmpty ? url : (initialUrl ?? '');

  String get displayTitle {
    if (onSpeedDial) return incognito ? 'Incognito' : 'New tab';
    if (title.trim().isNotEmpty) return title.trim();
    if (url.isNotEmpty) return hostOf(url);
    return 'New tab';
  }

  String get host => url.isEmpty ? '' : hostOf(url);
}

/// Which page the desktop Opera-style sidebar shows (null = collapsed).
enum SidePanel { none, bookmarks, history, downloads, settings, reading, privacy, files }

/// A pending site permission prompt (camera / mic / location…).
class PermissionAsk {
  PermissionAsk({
    required this.host,
    required this.labels,
    required this.completer,
  });

  final String host;
  final List<String> labels;
  final Completer<bool> completer;
}

/// Owns tabs, groups, split view, navigation, find-in-page, fullscreen,
/// permission prompts and session restore.
class BrowserProvider extends ChangeNotifier {
  BrowserProvider({
    required this.settings,
    required this.profile,
    required this.privacy,
  }) : super() {
    _newTab(incognito: false, silent: true);
  }

  final SettingsProvider settings;
  final ProfileProvider profile;
  final PrivacyProvider privacy;

  final List<BrowserTab> _tabs = [];
  final List<TabGroup> groups = [];
  final Set<String> collapsedGroups = {};
  int index = 0;

  List<BrowserTab> get tabs => List.unmodifiable(_tabs);
  BrowserTab get current =>
      _tabs.isEmpty ? _empty : _tabs[index.clamp(0, _tabs.length - 1)];
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

  /// Split view (Opera-style side-by-side tabs).
  String? splitTabId;
  double splitFraction = 0.5;
  static const minSplitFraction = 0.25;
  static const maxSplitFraction = 0.75;

  /// Reader-mode overlay.
  bool readerOpen = false;

  /// Command palette overlay (desktop, Ctrl+K).
  bool paletteOpen = false;

  /// Pending permission prompt, shown as a top banner.
  PermissionAsk? pendingPermission;

  /// Bumped to ask the omnibox to grab focus (Ctrl+L).
  int omniboxFocusEpoch = 0;

  Timer? _sessionDebounce;
  bool _restoring = false;

  // ---- Tab lifecycle ----

  BrowserTab newTab({bool incognito = false, String? url, String? groupId}) {
    final t = _newTab(
      incognito: incognito,
      url: url,
      groupId: groupId ?? (incognito ? current.groupId : current.groupId),
    );
    _scheduleSessionSave();
    return t;
  }

  BrowserTab _newTab({
    required bool incognito,
    String? url,
    bool silent = false,
    String? groupId,
  }) {
    final home = url ??
        (incognito || settings.homePage.isEmpty ? null : settings.homePage);
    final t = BrowserTab(
      id: 'tab-${DateTime.now().microsecondsSinceEpoch}-$incognito',
      incognito: incognito,
      initialUrl: home,
      groupId: groupId,
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

  void selectTab(BrowserTab tab) {
    final i = _tabs.indexOf(tab);
    if (i >= 0) select(i);
  }

  void closeTab(BrowserTab tab) {
    final i = _tabs.indexOf(tab);
    if (i < 0) return;
    if (splitTabId == tab.id) splitTabId = null;
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
    _tabs.removeWhere((t) => t != keep && t.id != splitTabId);
    index = _tabs.indexOf(keep);
    _scheduleSessionSave();
    notifyListeners();
  }

  void closeToTheRight(BrowserTab leftmost) {
    final i = _tabs.indexOf(leftmost);
    if (i < 0) return;
    final splitId = splitTabId;
    _tabs.removeWhere(
      (t) => _tabs.indexOf(t) > i && t.id != splitId,
    );
    if (index >= _tabs.length) index = _tabs.length - 1;
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

  // ---- Tab groups ----

  TabGroup? groupOf(BrowserTab tab) {
    for (final g in groups) {
      if (g.id == tab.groupId) return g;
    }
    return null;
  }

  List<BrowserTab> tabsInGroup(String groupId) =>
      _tabs.where((t) => t.groupId == groupId).toList();

  TabGroup newGroup(String name, int colorIndex) {
    final g = TabGroup(
      id: 'grp-${DateTime.now().millisecondsSinceEpoch}',
      name: name.isEmpty ? 'New group' : name,
      colorIndex: colorIndex,
    );
    groups.add(g);
    _scheduleSessionSave();
    notifyListeners();
    return g;
  }

  void renameGroup(TabGroup g, String name) {
    g.name = name;
    _scheduleSessionSave();
    notifyListeners();
  }

  void deleteGroup(TabGroup g) {
    groups.remove(g);
    collapsedGroups.remove(g.id);
    for (final t in _tabs) {
      if (t.groupId == g.id) t.groupId = null;
    }
    _scheduleSessionSave();
    notifyListeners();
  }

  void setTabGroup(BrowserTab tab, String? groupId) {
    tab.groupId = groupId;
    _scheduleSessionSave();
    notifyListeners();
  }

  void toggleGroupCollapse(String groupId) {
    if (!collapsedGroups.remove(groupId)) collapsedGroups.add(groupId);
    notifyListeners();
  }

  void ungroupAll() {
    for (final t in _tabs) {
      t.groupId = null;
    }
    _scheduleSessionSave();
    notifyListeners();
  }

  // ---- Split view ----

  bool get splitActive => splitTabId != null;

  BrowserTab? get splitTab {
    final id = splitTabId;
    if (id == null) return null;
    for (final t in _tabs) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Moves [tab] into the split pane (or creates one from a fresh tab).
  void openSplit({BrowserTab? tab}) {
    BrowserTab? target = tab;
    if (target == null || target.id == splitTabId) {
      target = newTab(incognito: current.incognito);
    }
    if (target.id == current.id && _tabs.length > 1) {
      // Keep a sensible tab in the main pane.
      select(_tabs.indexOf(target) == 0 ? 1 : _tabs.indexOf(target) - 1);
    }
    splitTabId = target.id;
    _scheduleSessionSave();
    notifyListeners();
  }

  void closeSplit() {
    splitTabId = null;
    _scheduleSessionSave();
    notifyListeners();
  }

  void setSplitFraction(double f) {
    splitFraction = f.clamp(minSplitFraction, maxSplitFraction);
    notifyListeners();
  }

  // ---- Navigation ----

  /// Entry point for the omnibox, speed dial and search box.
  Future<void> navigate(String input) async {
    final value = input.trim();
    if (value.isEmpty) return;
    final aliased = _applySearchAliases(value);
    final uri = urlFromInput(aliased);

    if (uri == null) {
      _load(current, settings.searchEngine.queryUrl(aliased));
      return;
    }
    if (isExternalScheme(uri)) {
      await _launchExternal(uri);
      return;
    }
    if (!isWebScheme(uri)) {
      final ok = await _launchExternal(uri);
      if (!ok) _load(current, settings.searchEngine.queryUrl(aliased));
      return;
    }
    _load(current, uri.toString());
  }

  /// Omnibox search aliases: `g cats`, `w paris`, `yt lofi` …
  String _applySearchAliases(String value) {
    final space = value.indexOf(' ');
    if (space <= 0 || space == value.length - 1) return value;
    final bang = value.substring(0, space).toLowerCase();
    final rest = value.substring(space + 1);
    const map = <String, String>{
      'g': 'https://www.google.com/search?q=%s',
      'd': 'https://duckduckgo.com/?q=%s',
      'b': 'https://www.bing.com/search?q=%s',
      'w': 'https://en.wikipedia.org/wiki/Special:Search?search=%s',
      'yt': 'https://www.youtube.com/results?search_query=%s',
      'gh': 'https://github.com/search?q=%s',
      'a': 'https://www.amazon.com/s?k=%s',
      'm': 'https://maps.google.com/maps?q=%s',
    };
    final tpl = map[bang];
    if (tpl == null) return value;
    return tpl.replaceAll('%s', Uri.encodeComponent(rest));
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
        c
            .loadUrl(urlRequest: URLRequest(url: WebUri(url)))
            .catchError((_) {}),
      );
    } else {
      tab.initialUrl = url;
    }
    if (readerOpen) readerOpen = false;
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
  /// Returns the blocked host, or null when allowed.
  String? filterNavigation(NavigationAction action, BrowserTab tab) {
    final uri = action.request.url;
    if (uri == null) return null;
    if (!uri.scheme.startsWith('http')) return null;
    if (!privacy.effectiveBlockAds(tab.siteUrl, settings.blockAds)) {
      return null;
    }
    if (isBlockedHost(uri.host)) {
      privacy.countBlocked(uri.host);
      return uri.host;
    }
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

  // ---- Overlays ----

  void openReader() {
    if (!current.onSpeedDial) {
      readerOpen = true;
      notifyListeners();
    }
  }

  void closeReader() {
    readerOpen = false;
    notifyListeners();
  }

  void openPalette() {
    paletteOpen = true;
    notifyListeners();
  }

  void closePalette() {
    paletteOpen = false;
    notifyListeners();
  }

  void requestOmniboxFocus() {
    omniboxFocusEpoch++;
    notifyListeners();
  }

  // ---- Permission prompts ----

  Future<bool> askPermission(String host, List<String> labels) {
    final ask = PermissionAsk(
      host: host,
      labels: labels,
      completer: Completer<bool>(),
    );
    pendingPermission = ask;
    notifyListeners();
    return ask.completer.future;
  }

  void resolvePermission(bool allow, {bool always = false}) {
    final ask = pendingPermission;
    if (ask == null) return;
    if (always) {
      final existing = privacy.ruleFor(ask.host);
      privacy.updateRule(
        ask.host,
        (existing ?? SiteRule(host: ask.host)).copyWith(media: allow),
      );
    }
    ask.completer.complete(allow);
    pendingPermission = null;
    notifyListeners();
  }

  // ---- Session restore ----

  Future<void> restoreSession() async {
    if (!settings.restoreSession) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('session.tabs');
      if (raw == null || raw.isEmpty) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final list = (data['tabs'] as List? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList(growable: false);
      if (list.isEmpty) return;
      _restoring = true;
      _tabs.clear();
      groups.clear();
      for (final g in (data['groups'] as List? ?? [])) {
        groups.add(TabGroup.fromJson(g as Map<String, dynamic>));
      }
      for (final e in list) {
        final url = e['url'] as String? ?? '';
        final title = e['title'] as String? ?? '';
        final groupId = e['group'] as String?;
        final incog = e['incognito'] as bool? ?? false;
        if (url.isEmpty) continue;
        final t = BrowserTab(
          id: 'tab-r${DateTime.now().microsecondsSinceEpoch}-${_tabs.length}',
          incognito: incog,
          initialUrl: url,
          initialTitle: title,
          groupId: groups.any((g) => g.id == groupId) ? groupId : null,
        );
        t.onSpeedDial = false;
        _tabs.add(t);
      }
      if (_tabs.isEmpty) {
        _newTab(incognito: false);
      } else {
        final saved = (data['index'] as int? ?? 0).clamp(0, _tabs.length - 1);
        index = saved;
        final splitId = data['split'] as String?;
        if (splitId != null && _tabs.any((t) => t.id != splitId && t.id == splitId)) {
          splitTabId = splitId;
        } else if (splitId != null && _tabs.any((t) => t.id == splitId)) {
          splitTabId = splitId;
        }
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
              'group': t.groupId,
              'incognito': false,
            },
          )
          .toList();
      final data = {
        'tabs': open,
        'groups': groups.map((g) => g.toJson()).toList(),
        'index': open.isEmpty ? 0 : index.clamp(0, open.length - 1),
        'split': splitTabId,
      };
      await prefs.setString('session.tabs', jsonEncode(data));
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
        final dynamic cc = c;
        await cc.setSettings(
          settings: buildSettingsFor(
            tab: t,
            settings: settings,
            privacy: privacy,
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

/// Friendly labels for permission resource types.
String permissionLabel(PermissionResourceType t) {
  final key = t
      .toString()
      .replaceAll('PermissionResourceType.', '')
      .toUpperCase();
  switch (key) {
    case 'CAMERA':
      return 'camera';
    case 'MICROPHONE':
      return 'microphone';
    case 'CAMERA_AND_MICROPHONE':
      return 'camera and microphone';
    case 'GEOLOCATION':
      return 'location';
    case 'NOTIFICATIONS':
      return 'notifications';
    case 'CLIPBOARD_READ':
      return 'clipboard';
    case 'MIDI':
    case 'MIDI_SYSEX':
      return 'MIDI devices';
    case 'PROTECTED_MEDIA_ID':
      return 'protected media';
    case 'AUTOPLAY':
      return 'autoplay';
    default:
      return 'device access';
  }
}

/// Shared web-view settings builder (used by TabWebView + refreshWebViews).
InAppWebViewSettings buildSettingsFor({
  required BrowserTab tab,
  required SettingsProvider settings,
  required PrivacyProvider privacy,
}) {
  final mobile = defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  final siteUrl = tab.siteUrl;
  return InAppWebViewSettings(
    javaScriptEnabled: privacy.effectiveJavaScript(siteUrl, true),
    useShouldOverrideUrlLoading: true,
    useOnDownloadStart: true,
    transparentBackground: true,
    supportZoom: true,
    mediaPlaybackRequiresUserGesture: false,
    incognito: mobile && tab.incognito,
    userAgent: mobile && privacy.effectiveDesktopSite(siteUrl, settings.desktopMode)
        ? kDesktopUserAgent
        : null,
  );
}

/// The shared WebView environment (Windows) for every tab.
WebViewEnvironment? get webViewEnvironment => WebEngine.instance.environment;
