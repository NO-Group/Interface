import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/file_manager.dart';

/// What the clipboard is holding inside the file manager.
enum FileClip { copy, move }

/// Browse-and-manage state for the files page: the current folder, history,
/// selection, the copy/move clipboard and the places worth returning to.
class FilesProvider extends ChangeNotifier {
  FilesProvider({SharedPreferences? prefs, this.fs = const FileManager()});

  final FileManager fs;
  SharedPreferences? _prefs;
  bool loaded = false;

  String dir = '';
  List<FileNode> nodes = const [];
  bool loading = false;
  String? error;

  FileSort sort = FileSort.name;
  bool ascending = true;
  bool showHidden = false;
  bool grid = false;
  String query = '';

  final Set<String> selected = <String>{};
  FileClip? clip;
  List<String> clipPaths = const [];

  List<PathStep> places = const [];
  List<String> favourites = const [];

  final List<String> _back = [];
  final List<String> _fwd = [];

  String get s => fs.separator;

  bool get canBack => _back.isNotEmpty;
  bool get canForward => _fwd.isNotEmpty;
  bool get canUp => dir.isNotEmpty && !isRoot(dir, s: s);
  bool get hasClip => clipPaths.isNotEmpty;
  bool get selecting => selected.isNotEmpty;
  int get shownCount => nodes.length;

  String get folderName {
    if (dir.isEmpty) return 'Files';
    final n = baseName(dir, s: s);
    return n.isEmpty ? dir : n;
  }

  Future<void> load() async {
    loading = true;
    notifyListeners();
    _prefs ??= await SharedPreferences.getInstance();
    favourites = _prefs!.getStringList('files.favourites') ?? const [];
    sort = FileSort.values.asNameMap()[_prefs!.getString('files.sort')] ??
        FileSort.name;
    ascending = _prefs!.getBool('files.asc') ?? true;
    showHidden = _prefs!.getBool('files.hidden') ?? false;
    grid = _prefs!.getBool('files.grid') ?? false;
    places = await fs.quickPlaces();
    final last = _prefs!.getString('files.dir') ?? '';
    dir = last.isNotEmpty && await Directory(last).exists()
        ? last
        : (places.isNotEmpty ? places.first.path : fs.startPath());
    loaded = true;
    await refresh();
    if (!loaded) return;
  }

  Future<void> refresh() async {
    if (dir.isEmpty) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      nodes = await fs.list(dir,
          sort: sort, ascending: ascending, showHidden: showHidden, query: query);
    } on FileOpException catch (e) {
      error = e.message;
      nodes = const [];
    } catch (_) {
      error = 'This folder cannot be opened right now.';
      nodes = const [];
    }
    loading = false;
    notifyListeners();
  }

  Future<void> goTo(String path, {bool keepHistory = true}) async {
    final clean = normalise(path, s: s);
    if (clean == dir && keepHistory) {
      await refresh();
      return;
    }
    if (keepHistory && dir.isNotEmpty) {
      _back.add(dir);
      _fwd.clear();
      if (_back.length > 60) _back.removeAt(0);
    }
    dir = clean;
    selected.clear();
    query = '';
    _prefs?.setString('files.dir', clean);
    await refresh();
  }

  Future<void> openNode(FileNode node) async {
    if (node.isDir) await goTo(node.path);
  }

  Future<void> back() async {
    if (_back.isEmpty) return;
    _fwd.add(dir);
    dir = _back.removeLast();
    selected.clear();
    await refresh();
  }

  Future<void> forward() async {
    if (_fwd.isEmpty) return;
    _back.add(dir);
    dir = _fwd.removeLast();
    selected.clear();
    await refresh();
  }

  Future<void> up() async {
    if (!canUp) return;
    await goTo(parentOf(dir, s: s));
  }

  /// Enter a folder from a path the person typed or pasted.
  Future<bool> openPath(String path) async {
    final clean = normalise(path.trim(), s: s);
    if (clean.isEmpty) return false;
    if (await Directory(clean).exists()) {
      await goTo(clean);
      return true;
    }
    final parent = parentOf(clean, s: s);
    if (await Directory(parent).exists()) {
      await goTo(parent);
      query = baseName(clean, s: s);
      await refresh();
      return true;
    }
    error = 'Nothing is there.';
    notifyListeners();
    return false;
  }

  // ------------------------------------------------------------- selection
  void toggleSelect(String path) {
    if (!selected.remove(path)) selected.add(path);
    notifyListeners();
  }

  void selectOnly(String path) {
    selected
      ..clear()
      ..add(path);
    notifyListeners();
  }

  void selectAll() {
    selected
      ..clear()
      ..addAll(nodes.map((n) => n.path));
    notifyListeners();
  }

  void clearSelection() {
    if (selected.isEmpty) return;
    selected.clear();
    notifyListeners();
  }

  List<String> get _targets =>
      selected.isEmpty ? const [] : selected.toList(growable: false);

  // -------------------------------------------------------------- mutators
  Future<String?> newFolder([String name = 'New folder']) async {
    try {
      final taken = nodes.map((n) => n.name).toList();
      final wanted = uniqueName(taken, name, s: s);
      await fs.mkdir(dir, wanted);
      await refresh();
      return wanted;
    } on FileOpException catch (e) {
      error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<String?> newFile([String name = 'New file.txt']) async {
    try {
      final taken = nodes.map((n) => n.name).toList();
      final wanted = uniqueName(taken, name, s: s);
      await fs.touch(dir, wanted);
      await refresh();
      return wanted;
    } on FileOpException catch (e) {
      error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<void> rename(FileNode node, String to) async {
    try {
      await fs.rename(node.path, to);
      selected.remove(node.path);
      await refresh();
    } on FileOpException catch (e) {
      error = e.message;
      notifyListeners();
    }
  }

  Future<void> remove(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await fs.delete(paths);
      selected.removeAll(paths);
      await refresh();
    } on FileOpException catch (e) {
      error = e.message;
      notifyListeners();
    }
  }

  Future<void> removeSelected() => remove(_targets);

  void take(FileClip mode, List<String> paths) {
    clip = mode;
    clipPaths = paths;
    notifyListeners();
  }

  Future<void> paste() async {
    final mode = clip;
    final paths = clipPaths;
    if (mode == null || paths.isEmpty) return;
    try {
      if (mode == FileClip.move) {
        await fs.move(paths, dir);
        clip = null;
        clipPaths = const [];
      } else {
        await fs.copy(paths, dir);
      }
      selected.clear();
      await refresh();
    } on FileOpException catch (e) {
      error = e.message;
      notifyListeners();
    }
  }

  Future<void> copyTo(String dest) => _sendTo(dest, copy: true);
  Future<void> moveTo(String dest) => _sendTo(dest, copy: false);

  Future<void> _sendTo(String dest, {required bool copy}) async {
    final paths = _targets;
    if (paths.isEmpty) return;
    try {
      if (copy) {
        await fs.copy(paths, dest);
      } else {
        await fs.move(paths, dest);
        selected.clear();
      }
      await refresh();
    } on FileOpException catch (e) {
      error = e.message;
      notifyListeners();
    }
  }

  // ------------------------------------------------------------- sorting
  Future<void> setSort(FileSort value) async {
    sort = value;
    _prefs?.setString('files.sort', value.name);
    await refresh();
  }

  Future<void> toggleDirection() async {
    ascending = !ascending;
    _prefs?.setBool('files.asc', ascending);
    await refresh();
  }

  Future<void> toggleHidden() async {
    showHidden = !showHidden;
    _prefs?.setBool('files.hidden', showHidden);
    await refresh();
  }

  Future<void> toggleGrid() async {
    grid = !grid;
    _prefs?.setBool('files.grid', grid);
    notifyListeners();
  }

  void setQuery(String value) {
    query = value;
    refresh();
  }

  Future<void> toggleFavourite() async {
    if (dir.isEmpty) return;
    if (favourites.contains(dir)) {
      favourites = favourites.where((f) => f != dir).toList();
    } else {
      favourites = [dir, ...favourites];
    }
    await _prefs?.setStringList('files.favourites', favourites);
    notifyListeners();
  }

  Future<void> removeFavourite(String path) async {
    favourites = favourites.where((f) => f != path).toList();
    await _prefs?.setStringList('files.favourites', favourites);
    notifyListeners();
  }

  /// Free space of the disk this folder sits on, when it can be read.
  Future<int?> freeSpace() async {
    try {
      return await Directory(dir).stat().then((_) => null);
    } catch (_) {
      return null;
    }
  }
}
