import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/urls.dart';
import '../models.dart';

/// Bookmarks, history, reading list and the speed dial.
/// JSON in SharedPreferences.
class ProfileProvider extends ChangeNotifier {
  ProfileProvider({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  final List<Bookmark> bookmarks = [];
  final List<HistoryEntry> history = [];
  final List<ReadingEntry> readingList = [];
  List<SpeedDialItem> speedDial = [];
  List<SpeedDialFolder> dialFolders = [];

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

  // ---- Reading list ----

  bool onReadingList(String url) => readingList.any((r) => r.url == url);

  void addReading({required String url, required String title}) {
    if (url.isEmpty || onReadingList(url)) return;
    readingList.insert(
      0,
      ReadingEntry(
        id: 'rl-${DateTime.now().millisecondsSinceEpoch}',
        url: url,
        title: title.isEmpty ? url : title,
        addedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    _saveReading();
  }

  void removeReading(ReadingEntry e) {
    readingList.remove(e);
    _saveReading();
  }

  void markReadingRead(ReadingEntry e, {bool read = true}) {
    final i = readingList.indexOf(e);
    if (i < 0) return;
    readingList[i] = e.copyWith(read: read);
    _saveReading();
  }

  int get unreadReadingCount =>
      readingList.where((r) => !r.read).length;

  // ---- Speed dial ----

  bool _dialCustomized = false;

  List<SpeedDialItem> dialItemsIn(String? folderId) => speedDial
      .where((s) => (s.folderId ?? '') == (folderId ?? ''))
      .toList(growable: false);

  void addSpeedDial({required String title, required String url, String? folderId}) {
    if (url.isEmpty) return;
    final item = SpeedDialItem(
      id: 'sd-${DateTime.now().millisecondsSinceEpoch}',
      title: title.isEmpty ? hostOf(url) : title,
      url: url,
      folderId: folderId,
    );
    speedDial.add(item);
    _dialCustomized = true;
    _saveDial();
  }

  void updateSpeedDial(SpeedDialItem item,
      {String? title, String? url, String? folderId, bool clearFolder = false}) {
    final i = speedDial.indexOf(item);
    if (i < 0) return;
    speedDial[i] = SpeedDialItem(
      id: item.id,
      title: title ?? item.title,
      url: url ?? item.url,
      folderId: clearFolder ? null : (folderId ?? item.folderId),
    );
    _saveDial();
  }

  void removeSpeedDial(SpeedDialItem item) {
    speedDial.remove(item);
    _dialCustomized = true;
    _saveDial();
  }

  /// Drag-and-drop reorder inside the current folder view.
  void reorderDial(int oldIndex, int newIndex, String? folderId) {
    final items = speedDial
        .asMap()
        .entries
        .where((e) => (e.value.folderId ?? '') == (folderId ?? ''))
        .map((e) => e.key)
        .toList(growable: false);
    if (oldIndex < 0 || oldIndex >= items.length) return;
    if (newIndex > oldIndex) newIndex--;
    final globalOld = items[oldIndex];
    if (newIndex < 0 || newIndex >= items.length) return;
    final globalNew = items[newIndex];
    final moved = speedDial.removeAt(globalOld);
    speedDial.insert(globalNew, moved);
    _dialCustomized = true;
    _saveDial();
  }

  SpeedDialFolder addDialFolder(String name) {
    final f = SpeedDialFolder(
      id: 'fld-${DateTime.now().millisecondsSinceEpoch}',
      name: name.isEmpty ? 'Folder' : name,
    );
    dialFolders.add(f);
    _dialCustomized = true;
    _saveDial();
    return f;
  }

  void renameDialFolder(SpeedDialFolder f, String name) {
    f.name = name;
    _saveDial();
  }

  void deleteDialFolder(SpeedDialFolder f) {
    dialFolders.remove(f);
    // Folder contents move back to the dial root.
    speedDial = speedDial
        .map((s) => s.folderId == f.id
            ? SpeedDialItem(id: s.id, title: s.title, url: s.url)
            : s)
        .toList();
    _dialCustomized = true;
    _saveDial();
  }

  void resetSpeedDial() {
    speedDial = List.of(kDefaultSpeedDial);
    dialFolders = const [];
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
        final decoded = jsonDecode(sd) as List;
        speedDial = decoded
            .map((e) => SpeedDialItem.fromJson(e as Map<String, dynamic>))
            .toList();
        final folders =
            p.getStringList('data.dialFolders') ?? const <String>[];
        dialFolders = folders
            .map((s) => SpeedDialFolder(
                  id: s.split('|').first,
                  name: s.split('|').length > 1 ? s.split('|')[1] : 'Folder',
                ))
            .toList();
      } catch (e) {
        debugPrint('speeddial decode: $e');
      }
    }
    if (!_dialCustomized && speedDial.isEmpty) {
      speedDial = List.of(kDefaultSpeedDial);
    }

    final rl = p.getString('data.reading');
    if (rl != null) {
      try {
        readingList
          ..clear()
          ..addAll(
            (jsonDecode(rl) as List)
                .map((e) => ReadingEntry.fromJson(e as Map<String, dynamic>)),
          );
      } catch (e) {
        debugPrint('reading list decode: $e');
      }
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
    await p.setStringList(
      'data.dialFolders',
      dialFolders.map((f) => '${f.id}|${f.name}').toList(),
    );
    await p.setBool('data.dialCustomized', _dialCustomized);
  }

  Future<void> _saveReading() async {
    notifyListeners();
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.setString(
      'data.reading',
      jsonEncode(readingList.map((r) => r.toJson()).toList()),
    );
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
