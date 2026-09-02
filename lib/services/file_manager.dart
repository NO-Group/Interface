import 'dart:io';

/// One entry in a folder.
class FileNode {
  const FileNode({
    required this.name,
    required this.path,
    required this.isDir,
    required this.size,
    required this.modified,
    this.canRead = true,
    this.isLink = false,
  });

  final String name;
  final String path;
  final bool isDir;
  final int size;
  final DateTime modified;
  final bool canRead;
  final bool isLink;

  bool get isHidden => name.startsWith('.');
  String get extension {
    final dot = name.lastIndexOf('.');
    return dot <= 0 || dot == name.length - 1 ? '' : name.substring(dot + 1);
  }

}

/// What went wrong, in words a person can act on.
class FileOpException implements Exception {
  FileOpException(this.message, [this.detail]);

  final String message;
  final String? detail;

  @override
  String toString() => detail == null ? message : '$message ($detail)';
}

// ---------------------------------------------------------------- paths
// Everything below is pure so it can be unit-tested without a device.

String get sep => Platform.pathSeparator;

String normalise(String path, {String s = '/'}) {
  if (path.isEmpty) return path;
  var p = path.replaceAll('\\', s);
  final isRootish = RegExp(r'^[A-Za-z]:$').hasMatch(p) || p == s;
  final drivePrefix = RegExp(r'^[A-Za-z]:' + s).hasMatch(p) ? p.substring(0, 2) : '';
  if (drivePrefix.isNotEmpty) p = p.substring(2);
  final absolute = p.startsWith(s);
  final out = <String>[];
  for (final part in p.split(RegExp(RegExp.escape(s)))) {
    if (part.isEmpty || part == '.') continue;
    if (part == '..') {
      if (out.isNotEmpty && out.last != '..') {
        out.removeLast();
        continue;
      }
      if (absolute) continue;
    }
    out.add(part);
  }
  var joined = out.join(s);
  if (absolute) joined = s + joined;
  if (drivePrefix.isNotEmpty) joined = drivePrefix + (joined.startsWith(s) ? joined : s + joined);
  if (joined.isEmpty) joined = absolute ? s : '.';
  return isRootish ? (RegExp(r'^[A-Za-z]:$').hasMatch(path) ? path + s : s) : joined;
}

String baseName(String path, {String s = '/'}) {
  final p = normalise(path, s: s);
  if (p == s || RegExp(r'^[A-Za-z]:' + RegExp.escape(s) + r'$').hasMatch(p)) return '';
  final i = p.lastIndexOf(s);
  return i < 0 ? p : p.substring(i + 1);
}

String parentOf(String path, {String s = '/'}) {
  final p = normalise(path, s: s);
  if (p == s || RegExp(r'^[A-Za-z]:' + RegExp.escape(s) + r'$').hasMatch(p)) return p;
  final i = p.lastIndexOf(s);
  if (i < 0) return '.';
  var up = p.substring(0, i);
  if (RegExp(r'^[A-Za-z]:$').hasMatch(up)) up = up + s;
  if (up.isEmpty) up = s;
  return up;
}

String joinPath(String a, String b, {String s = '/'}) {
  if (b.startsWith(s) || RegExp(r'^[A-Za-z]:').hasMatch(b)) return normalise(b, s: s);
  final trimmed = a.endsWith(s) ? a.substring(0, a.length - 1) : a;
  return normalise('$trimmed$s$b', s: s);
}

/// Breadcrumb steps from the root down to [path].
List<PathStep> stepsOf(String path, {String s = '/'}) {
  final p = normalise(path, s: s);
  final out = <PathStep>[];
  final drive = RegExp(r'^[A-Za-z]:').hasMatch(p) ? p.substring(0, 2) : '';
  final rest = drive.isNotEmpty ? p.substring(2) : p;
  if (drive.isNotEmpty) out.add(PathStep(drive + s, drive));
  if (rest.startsWith(s)) out.add(PathStep(s, drive.isEmpty ? 'Root' : drive));
  var running = drive.isNotEmpty ? drive + s : '';
  for (final part in rest.split(RegExp(RegExp.escape(s)))) {
    if (part.isEmpty || part == '.') continue;
    running = running.isEmpty ? s + part : (running.endsWith(s) ? running + part : running + s + part);
    out.add(PathStep(running, part));
  }
  return out;
}

class PathStep {
  const PathStep(this.path, this.label);
  final String path;
  final String label;
}

bool isRoot(String path, {String s = '/'}) {
  final p = normalise(path, s: s);
  return p == s || RegExp(r'^[A-Za-z]:' + RegExp.escape(s) + r'$').hasMatch(p);
}

bool isInside(String child, String parent, {String s = '/'}) {
  final c = normalise(child, s: s);
  final p = normalise(parent, s: s);
  if (p == s) return c != s;
  return c == p || c.startsWith(p.endsWith(s) ? p : p + s);
}

// ---------------------------------------------------------------- names
String uniqueName(List<String> taken, String wanted, {String s = '/'}) {
  if (!taken.contains(wanted)) return wanted;
  final dot = wanted.lastIndexOf('.');
  final stem = dot <= 0 ? wanted : wanted.substring(0, dot);
  final ext = dot <= 0 ? '' : wanted.substring(dot);
  for (var i = 2; i < 1000; i++) {
    final candidate = '$stem ($i)$ext';
    if (!taken.contains(candidate)) return candidate;
  }
  return '$stem-${DateTime.now().millisecondsSinceEpoch}$ext';
}

bool isValidName(String name, {String s = '/'}) {
  if (name.trim().isEmpty) return false;
  if (name == '.' || name == '..') return false;
  if (name.contains(s) || name.contains('/') || name.contains(':')) return false;
  if (name.contains('*') || name.contains('?') || name.contains('"')) return false;
  if (name.contains('<') || name.contains('>') || name.contains('|')) return false;
  return true;
}

// ---------------------------------------------------------------- display
String formatBytes(int bytes) {
  if (bytes < 0) return '—';
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB'];
  var value = bytes / 1024.0;
  var u = 0;
  while (value >= 1024 && u < units.length - 1) {
    value /= 1024;
    u++;
  }
  final text = value >= 100 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
  return '${text.endsWith('.0') ? text.substring(0, text.length - 2) : text} ${units[u]}';
}

String formatWhen(DateTime time, {DateTime? now, String s = '/'}) {
  final t = now ?? DateTime.now();
  final sameDay = (a, b) => a.year == b.year && a.month == b.month && a.day == b.day;
  if (sameDay(t, time)) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return 'Today $hh:$mm';
  }
  final yesterday = t.subtract(const Duration(days: 1));
  if (sameDay(yesterday, time)) return 'Yesterday';
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final day = '${time.day} ${months[time.month - 1]}';
  return time.year == t.year ? day : '$day ${time.year}';
}

// ---------------------------------------------------------------- sorting
enum FileSort { name, newest, largest, type }

int compareNodes(FileNode a, FileNode b, FileSort sort, {bool ascending = true}) {
  if (a.isDir != b.isDir) return a.isDir ? -1 : 1;
  int r;
  switch (sort) {
    case FileSort.name:
      r = _foldy(a.name).compareTo(_foldy(b.name));
    case FileSort.newest:
      r = -a.modified.compareTo(b.modified);
    case FileSort.largest:
      r = -a.size.compareTo(b.size);
    case FileSort.type:
      r = _foldy(a.extension).compareTo(_foldy(b.extension));
      if (r == 0) r = _foldy(a.name).compareTo(_foldy(b.name));
  }
  if (r == 0) r = _foldy(a.name).compareTo(_foldy(b.name));
  return ascending ? r : -r;
}

String _foldy(String s) => s.toLowerCase();

List<FileNode> sortNodes(List<FileNode> nodes, FileSort sort, {bool ascending = true}) {
  final out = [...nodes]..sort((a, b) => compareNodes(a, b, sort, ascending: ascending));
  return out;
}

List<FileNode> filterNodes(List<FileNode> nodes, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return nodes;
  return nodes.where((n) => n.name.toLowerCase().contains(q)).toList();
}

// ---------------------------------------------------------------- the work
/// Real filesystem access, with plain-language failures.
class FileManager {
  const FileManager();

  String get separator => sep;

  /// Places worth jumping to straight away.
  Future<List<PathStep>> quickPlaces() async {
    final out = <PathStep>[];
    Future<void> add(String? path, String label) async {
      if (path == null || path.isEmpty) return;
      final clean = normalise(path, s: sep);
      if (await Directory(clean).exists() && !out.any((p) => p.path == clean)) {
        out.add(PathStep(clean, label));
      }
    }

    await add(homePath(), 'Home');
    await add(_env('USERPROFILE') ?? _env('HOME'), 'Home');
    try {
      final dir = await Directory.systemTemp.createTemp('x');
      await add(parentOf(dir.path, s: sep), 'Temporary');
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    } catch (_) {}
    if (Platform.isWindows) {
      await add('${_env('USERPROFILE')}\\Downloads', 'Downloads');
      await add('${_env('USERPROFILE')}\\Documents', 'Documents');
      await add('${_env('USERPROFILE')}\\Desktop', 'Desktop');
      await add(r'C:\Program Files', 'Program Files');
    } else {
      await add('${_env('HOME')}/Downloads', 'Downloads');
      await add('${_env('HOME')}/Documents', 'Documents');
      await add('${_env('HOME')}/Desktop', 'Desktop');
      await add('/storage/emulated/0', 'Storage');
      await add('/sdcard', 'Storage');
      await add('/document', 'Documents');
    }
    for (final root in await driveRoots()) {
      await add(root, root);
    }
    return out;
  }

  /// Drive letters on Windows, `/` elsewhere.
  Future<List<String>> driveRoots() async {
    if (!Platform.isWindows) return ['/'];
    final found = <String>[];
    for (final letter in 'CDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
      final dir = Directory('$letter:\\');
      try {
        if (await dir.exists()) found.add('$letter:\\');
      } catch (_) {}
    }
    return found.isEmpty ? ['C:\\'] : found;
  }

  String startPath() {
    final home = homePath();
    if (home.isNotEmpty && Directory(home).existsSync()) return normalise(home, s: sep);
    return normalise(Directory.current.path, s: sep);
  }

  String homePath() {
    if (Platform.isWindows) return _env('USERPROFILE') ?? _env('HOME') ?? '';
    return _env('HOME') ?? '';
  }

  String? _env(String k) => Platform.environment[k];

  /// List a folder. Folders first, then files, in [sort] order.
  Future<List<FileNode>> list(String path,
      {FileSort sort = FileSort.name,
      bool ascending = true,
      bool showHidden = false,
      String query = ''}) async {
    final dir = Directory(normalise(path, s: sep));
    List<FileSystemEntity> entries;
    try {
      entries = dir.listSync(followLinks: false);
    } on FileSystemException catch (e) {
      throw FileOpException(_explain(e), e.osError?.message);
    }
    final nodes = <FileNode>[];
    for (final e in entries) {
      final name = baseName(e.path, s: sep);
      if (name.isEmpty) continue;
      if (!showHidden && name.startsWith('.')) continue;
      if (query.trim().isNotEmpty && !name.toLowerCase().contains(query.trim().toLowerCase())) {
        continue;
      }
      nodes.add(_stat(e));
    }
    return sortNodes(nodes, sort, ascending: ascending);
  }

  FileNode _stat(FileSystemEntity e) {
    var isDir = false;
    var size = 0;
    var modified = DateTime.fromMillisecondsSinceEpoch(0);
    var readable = true;
    try {
      final type = FileSystemEntity.typeSync(e.path, followLinks: false);
      isDir = type == FileSystemEntityType.directory;
      if (type == FileSystemEntityType.notFound) {
        readable = false;
      } else if (isDir) {
        modified = e.statSync().modified;
      } else {
        final st = e.statSync();
        size = st.size;
        modified = st.modified;
      }
    } catch (_) {
      readable = false;
    }
    return FileNode(
      name: baseName(e.path, s: sep),
      path: normalise(e.path, s: sep),
      isDir: isDir,
      size: size,
      modified: modified,
      canRead: readable,
      isLink: _isLink(e.path),
    );
  }

  bool _isLink(String path) {
    try {
      return FileSystemEntity.typeSync(path, followLinks: false) ==
          FileSystemEntityType.link;
    } catch (_) {
      return false;
    }
  }

  Future<void> mkdir(String parent, String name) async {
    _needName(name);
    final target = joinPath(parent, name, s: sep);
    if (await Directory(target).exists()) {
      throw FileOpException('There is already a folder called $name');
    }
    try {
      await Directory(target).create(recursive: true);
    } on FileSystemException catch (e) {
      throw FileOpException('That folder could not be created', _explain(e));
    }
  }

  Future<void> touch(String parent, String name) async {
    _needName(name);
    final target = joinPath(parent, name, s: sep);
    try {
      final f = File(target);
      if (!await f.exists()) await f.create(recursive: true);
    } on FileSystemException catch (e) {
      throw FileOpException('That file could not be created', _explain(e));
    }
  }

  Future<String> rename(String path, String newName) async {
    _needName(newName);
    final from = normalise(path, s: sep);
    final to = joinPath(parentOf(from, s: sep), newName, s: sep);
    if (from == to) return to;
    if (await FileSystemEntity.type(to).then((t) => t != FileSystemEntityType.notFound)) {
      throw FileOpException('There is already something called $newName');
    }
    try {
      await _entity(from).rename(to);
    } on FileSystemException catch (e) {
      throw FileOpException('That could not be renamed', _explain(e));
    }
    return normalise(to, s: sep);
  }

  Future<void> move(List<String> paths, String destDir) =>
      _transfer(paths, destDir, copy: false);

  Future<void> copy(List<String> paths, String destDir) =>
      _transfer(paths, destDir, copy: true);

  Future<void> _transfer(List<String> paths, String destDir,
      {required bool copy}) async {
    final into = normalise(destDir, s: sep);
    if (!await Directory(into).exists()) {
      throw FileOpException('That folder is gone. Pick another one.');
    }
    final taken = (Directory(into).listSync(followLinks: false))
        .map((e) => baseName(e.path, s: sep))
        .toList();
    for (final raw in paths) {
      final from = normalise(raw, s: sep);
      final name = baseName(from, s: sep);
      if (name.isEmpty) {
        throw FileOpException('The whole drive cannot be moved.');
      }
      if (isInside(into, from, s: sep)) {
        throw FileOpException('A folder cannot be moved inside itself.');
      }
      final wanted = copy ? uniqueName(taken, name, s: sep) : name;
      final to = joinPath(into, wanted, s: sep);
      if (!copy && await FileSystemEntity.type(to).then((t) => t != FileSystemEntityType.notFound)) {
        throw FileOpException('There is already something called $wanted here');
      }
      try {
        if (copy) {
          await _copyTree(from, to);
        } else {
          await _entity(from).rename(to);
        }
      } on FileSystemException catch (e) {
        throw FileOpException(
            copy ? 'Some of it could not be copied' : 'Some of it could not be moved',
            _explain(e));
      }
      taken.add(wanted);
    }
  }

  Future<void> _copyTree(String from, String to) async {
    final type = await FileSystemEntity.type(from, followLinks: false);
    if (type == FileSystemEntityType.directory) {
      await Directory(to).create(recursive: true);
      for (final child in Directory(from).listSync(followLinks: false)) {
        await _copyTree(child.path, joinPath(to, baseName(child.path, s: sep), s: sep));
      }
      return;
    }
    await File(from).copy(to);
  }

  Future<void> delete(List<String> paths) async {
    for (final raw in paths) {
      final path = normalise(raw, s: sep);
      if (!_deletable(path)) {
        throw FileOpException('That folder is protected and stays put.');
      }
      try {
        await _entity(path).delete(recursive: true);
      } on FileSystemException catch (e) {
        final os = e.osError?.message;
        if (os != null && os.toLowerCase().contains('not empty')) {
          throw FileOpException('Remove what is inside it first.');
        }
        throw FileOpException('That could not be deleted', _explain(e));
      }
    }
  }

  /// Never let a drive, the home folder or an absolute root be deleted.
  bool _deletable(String path) {
    final p = normalise(path, s: sep);
    if (isRoot(p, s: sep) || p.isEmpty || p == '.') return false;
    if (RegExp(r'^[A-Za-z]:\\?$').hasMatch(p)) return false;
    final home = homePath();
    if (home.isNotEmpty && normalise(home, s: sep) == p) return false;
    return true;
  }

  Future<FileNode?> node(String path) async {
    final p = normalise(path, s: sep);
    final type = await FileSystemEntity.type(p, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    return _stat(type == FileSystemEntityType.directory
        ? Directory(p)
        : File(p));
  }

  /// Total size of a folder, stopping early so huge trees stay quick.
  Future<int> folderSize(String path, {int cap = 40000}) async {
    var total = 0;
    var seen = 0;
    final stack = <String>[normalise(path, s: sep)];
    while (stack.isNotEmpty && seen < cap) {
      final dir = stack.removeLast();
      List<FileSystemEntity> kids;
      try {
        kids = Directory(dir).listSync(followLinks: false);
      } catch (_) {
        continue;
      }
      for (final k in kids) {
        seen++;
        try {
          final st = k.statSync();
          if (st.type == FileSystemEntityType.directory) {
            stack.add(k.path);
          } else {
            total += st.size;
          }
        } catch (_) {}
        if (seen >= cap) break;
      }
    }
    return total;
  }

  FileSystemEntity _entity(String path) =>
      FileSystemEntity.typeSync(path) == FileSystemEntityType.directory
          ? Directory(path)
          : File(path);

  String _explain(FileSystemException e) {
    final m = (e.osError?.message ?? '').toLowerCase();
    if (m.contains('denied') || m.contains('permission')) {
      return 'You do not have permission to change this.';
    }
    if (m.contains('in use') || m.contains('being used') || m.contains('locked')) {
      return 'Something else has this open right now.';
    }
    if (m.contains('too long') || m.contains('name invalid') || m.contains('invalid argument')) {
      return 'The name is too long or has characters the system does not allow.';
    }
    if (m.contains('not empty')) return 'The folder still has things in it.';
    if (m.contains('no such file') || m.contains('cannot find')) {
      return 'It is not there any more.';
    }
    if (m.contains('full') || m.contains('space')) return 'There is no room left on this disk.';
    return m.isEmpty ? 'It could not be done.' : m[0].toUpperCase() + m.substring(1);
  }

  void _needName(String name) {
    if (!isValidName(name, s: sep)) {
      throw FileOpException(
          'Pick a name without / \\\\ : * ? " < > | and that is not empty.');
    }
  }
}
