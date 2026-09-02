import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/urls.dart';
import '../models.dart';

/// Bookmarks, browsing history and the speed dial. JSON in SharedPreferences.
class ProfileProvider extends ChangeNotifier {
  ProfileProvider({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  final List<Bookmark> bookmarks = [];
  final List<HistoryEntry> history = [];
  List<SpeedDialItem> speedDial = [];

  static const _maxHistory = 600;

  bool isBookmarked(String url) => bookmarks.any((b) => b.url == url);

  Bookmark? bookmarkFor(String url) {
    for (final b in bookmarks) {
      if (b.url == url) return b;
    }
    return null;
  }

  /// Returns true when the bookmark was added, false when removed.
  bool toggleBookmark({required String url, required String title}) {
    if (url.isEmpty) return false;
    if (isBookmarked(url)) {
      bookmarks.removeWhere((b) => b.url == url);
      _saveBookmarks();
      return false;
    }
    bookmarks.insert(
      0,
      Bookmark(url: url, title: title.isEmpty ? url : title),
    );
    _saveBookmarks();
    return true;
  }

  void addBookmark({required String url, required String title}) {
    if (url.isEmpty || isBookmarked(url)) return;
    bookmarks.insert(0, Bookmark(url: url, title: title));
    _saveBookmarks();
  }

  void updateBookmark(Bookmark old, {String? url, String? title}) {
    final i = bookmarks.indexOf(old);
    if (i < 0) return;
    bookmarks[i] = old.copyWith(url: url, title: title);
    _saveBookmarks();
  }

  void removeBookmark(Bookmark b) {
    bookmarks.remove(b);
    _saveBookmarks();
  }

  void addHistory({required String url, required String title}) {
    if (url.isEmpty || url.startsWith('about:')) return;
    history.removeWhere((h) => h.url == url);
    history.insert(
      0,
      HistoryEntry(
        url: url,
        title: title.isEmpty ? url : title,
        visitedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (history.length > _maxHistory) {
      history.removeRange(_maxHistory, history.length);
    }
    _saveHistory();
  }

  void removeHistory(HistoryEntry e) {
    history.remove(e);
    _saveHistory();
  }

  void clearHistory() {
    history.clear();
    _saveHistory();
  }

  List<HistoryEntry> historyMatches(String q, {int limit = 5}) {
    if (q.trim().isEmpty) {
      return history.take(limit).toList();
    }
    final lower = q.toLowerCase();
    return history
        .where(
          (h) =>
              h.url.toLowerCase().contains(lower) ||
              h.title.toLowerCase().contains(lower),
        )
        .take(limit)
        .toList();
  }

  List<Bookmark> bookmarkMatches(String q, {int limit = 4}) {
    if (q.trim().isEmpty) return const [];
    final lower = q.toLowerCase();
    return bookmarks
        .where(
          (b) =>
              b.url.toLowerCase().contains(lower) ||
              b.title.toLowerCase().contains(lower),
        )
        .take(limit)
        .toList();
  }

  // ---- Speed dial ----

  bool _dialCustomized = false;

  void addSpeedDial({required String title, required String url}) {
    if (url.isEmpty) return;
    final item = SpeedDialItem(
      id: 'sd-${DateTime.now().millisecondsSinceEpoch}',
      title: title.isEmpty ? hostOf(url) : title,
      url: url,
    );
    speedDial.add(item);
    _dialCustomized = true;
    _saveDial();
  }

  void updateSpeedDial(SpeedDialItem item, {String? title, String? url}) {
    final i = speedDial.indexOf(item);
    if (i < 0) return;
    speedDial[i] = item.copyWith(title: title, url: url);
    _saveDial();
  }

  void removeSpeedDial(SpeedDialItem item) {
    speedDial.remove(item);
    _dialCustomized = true;
    _saveDial();
  }

  void resetSpeedDial() {
    speedDial = List.of(kDefaultSpeedDial);
    _dialCustomized = false;
    _saveDial();
  }

  bool isOnSpeedDial(String url) => speedDial.any((s) => s.url == url);

  /// Adds or removes the page from the speed dial. True = added.
  bool toggleSpeedDial({required String url, required String title}) {
    final existing = speedDial.where((s) => s.url == url).toList();
    if (existing.isNotEmpty) {
      speedDial.removeWhere((s) => s.url == url);
      _dialCustomized = true;
      _saveDial();
      return false;
    }
    addSpeedDial(url: url, title: title);
    return true;
  }

  // ---- Persistence ----

  Future<void> load() async {
    final p = _prefs ??= await SharedPreferences.getInstance();

    final bm = p.getString('data.bookmarks');
    if (bm != null) {
      try {
        bookmarks
          ..clear()
          ..addAll(
            (jsonDecode(bm) as List)
                .map((e) => Bookmark.fromJson(e as Map<String, dynamic>)),
          );
      } catch (e) {
        debugPrint('bookmarks decode: $e');
      }
    }

    final hs = p.getString('data.history');
    if (hs != null) {
      try {
        history
          ..clear()
          ..addAll(
            (jsonDecode(hs) as List)
                .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>)),
          );
      } catch (e) {
        debugPrint('history decode: $e');
      }
    }

    final sd = p.getString('data.speeddial');
    _dialCustomized = p.getBool('data.dialCustomized') ?? false;
    if (sd != null) {
      try {
        speedDial = (jsonDecode(sd) as List)
            .map((e) => SpeedDialItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('speeddial decode: $e');
      }
    }
    if (!_dialCustomized && speedDial.isEmpty) {
      speedDial = List.of(kDefaultSpeedDial);
    }
    notifyListeners();
  }

  Future<void> _saveBookmarks() async {
    notifyListeners();
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.setString(
      'data.bookmarks',
      jsonEncode(bookmarks.map((b) => b.toJson()).toList()),
    );
  }

  Future<void> _saveHistory() async {
    notifyListeners();
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.setString(
      'data.history',
      jsonEncode(history.map((h) => h.toJson()).toList()),
    );
  }

  Future<void> _saveDial() async {
    notifyListeners();
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.setString(
      'data.speeddial',
      jsonEncode(speedDial.map((s) => s.toJson()).toList()),
    );
    await p.setBool('data.dialCustomized', _dialCustomized);
  }
}

const kDefaultSpeedDial = <SpeedDialItem>[
  SpeedDialItem(id: 'sd-google', title: 'Google', url: 'https://www.google.com'),
  SpeedDialItem(id: 'sd-youtube', title: 'YouTube', url: 'https://www.youtube.com'),
  SpeedDialItem(id: 'sd-wikipedia', title: 'Wikipedia', url: 'https://www.wikipedia.org'),
  SpeedDialItem(id: 'sd-github', title: 'GitHub', url: 'https://github.com'),
  SpeedDialItem(id: 'sd-reddit', title: 'Reddit', url: 'https://www.reddit.com'),
  SpeedDialItem(id: 'sd-x', title: 'X', url: 'https://x.com'),
  SpeedDialItem(id: 'sd-amazon', title: 'Amazon', url: 'https://www.amazon.com'),
  SpeedDialItem(id: 'sd-news', title: 'BBC News', url: 'https://www.bbc.com/news'),
  SpeedDialItem(id: 'sd-gmail', title: 'Gmail', url: 'https://mail.google.com'),
  SpeedDialItem(id: 'sd-maps', title: 'Maps', url: 'https://maps.google.com'),
  SpeedDialItem(id: 'sd-ddg', title: 'DuckDuckGo', url: 'https://duckduckgo.com'),
  SpeedDialItem(id: 'sd-weather', title: 'Weather', url: 'https://www.wunderground.com'),
];
