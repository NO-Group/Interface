import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:interface_browser/services/file_manager.dart';
import 'package:interface_browser/widgets/icons.dart';

void main() {
  group('paths', () {
    test('normalise collapses . and .. and extra separators', () {
      expect(normalise('/a/b/../c/'), '/a/c');
      expect(normalise('/a//b/./c'), '/a/b/c');
      expect(normalise('//'), '/');
      expect(normalise(r'C:\x\..\y', s: r'\'), r'C:\y');
      expect(normalise('a/b/..', s: '/'), 'a');
    });

    test('baseName and parentOf', () {
      expect(baseName('/a/b/c.txt'), 'c.txt');
      expect(baseName('/'), '');
      expect(baseName(r'C:\'), '');
      expect(baseName(r'C:\a\b.pdf', s: r'\'), 'b.pdf');
      expect(parentOf('/a/b/c.txt'), '/a/b');
      expect(parentOf('/a'), '/');
      expect(parentOf(r'C:\a', s: r'\'), r'C:\');
      expect(parentOf('/'), '/');
    });

    test('joinPath keeps absolute parts', () {
      expect(joinPath('/a', 'b'), '/a/b');
      expect(joinPath('/a/', 'b'), '/a/b');
      expect(joinPath('/a', '/x/y'), '/x/y');
      expect(joinPath(r'C:\a', r'b\c', s: r'\'), r'C:\a\b\c');
    });

    test('steps walk from the root down', () {
      final steps = stepsOf('/a/b/c');
      expect(steps.map((s) => s.path), ['/', '/a', '/a/b', '/a/b/c']);
      expect(steps.last.label, 'c');
      final root = stepsOf('/');
      expect(root.single.path, '/');
    });

    test('isRoot and isInside', () {
      expect(isRoot('/'), isTrue);
      expect(isRoot(r'C:\', s: r'\'), isTrue);
      expect(isRoot('/a'), isFalse);
      expect(isInside('/a/b/c', '/a'), isTrue);
      // Equal counts as inside, so "move a folder into itself" gets refused.
      expect(isInside('/a', '/a'), isTrue);
      expect(isInside('/other', '/a'), isFalse);
    });
  });

  group('names', () {
    test('uniqueName avoids collisions', () {
      expect(uniqueName(['a.txt'], 'a.txt'), 'a (2).txt');
      expect(uniqueName(['a.txt', 'a (2).txt'], 'a.txt'), 'a (3).txt');
      expect(uniqueName([], 'note'), 'note');
      expect(uniqueName(['Report'], 'Report'), 'Report (2)');
    });

    test('isValidName rejects what the filesystem will not take', () {
      expect(isValidName('notes.txt'), isTrue);
      expect(isValidName('  '), isFalse);
      expect(isValidName('.'), isFalse);
      expect(isValidName('..'), isFalse);
      expect(isValidName('a/b'), isFalse);
      expect(isValidName(r'a\b', s: r'\'), isFalse);
      expect(isValidName('a:b'), isFalse);
      expect(isValidName('bad*name'), isFalse);
    });
  });

  group('display', () {
    test('formatBytes stays short', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(999), '999 B');
      expect(formatBytes(1024), '1 KB');
      expect(formatBytes(1536), '1.5 KB');
      expect(formatBytes(5 * 1024 * 1024), '5 MB');
      expect(formatBytes(1234567890), '1.1 GB');
    });

    test('formatWhen is friendly for today and yesterday', () {
      final now = DateTime(2026, 9, 2, 14, 5);
      expect(formatWhen(DateTime(2026, 9, 2, 9, 4), now: now), 'Today 09:04');
      expect(formatWhen(DateTime(2026, 9, 1, 22, 0), now: now), 'Yesterday');
      expect(formatWhen(DateTime(2026, 6, 4, 8, 0), now: now), '4 Jun');
      expect(formatWhen(DateTime(2025, 6, 4, 8, 0), now: now), '4 Jun 2025');
    });
  });

  group('ordering', () {
    FileNode n(String name, {bool dir = false, int size = 1, int? day}) =>
        FileNode(
          name: name,
          path: '/x/$name',
          isDir: dir,
          size: size,
          modified: DateTime(2026, 8, day ?? 10),
        );

    test('folders come first, then the chosen order', () {
      final nodes = [n('zeta.txt', size: 5), n('Beta', dir: true), n('alpha.txt', size: 90)];
      final byName = sortNodes(nodes, FileSort.name).map((e) => e.name).toList();
      expect(byName, ['Beta', 'alpha.txt', 'zeta.txt']);
      final bySize = sortNodes(nodes, FileSort.largest).map((e) => e.name).toList();
      expect(bySize.first, 'Beta');
      expect(bySize[1], 'alpha.txt');
    });

    test('newest first and reversal', () {
      final nodes = [n('old', day: 1), n('new', day: 20), n('mid', day: 9)];
      expect(sortNodes(nodes, FileSort.newest).map((e) => e.name).toList(),
          ['new', 'mid', 'old']);
      expect(sortNodes(nodes, FileSort.newest, ascending: false).first.name, 'old');
    });

    test('filterNodes is a case-insensitive substring match', () {
      final nodes = [n('Invoice.pdf'), n('notes.txt'), n('Photos', dir: true)];
      expect(filterNodes(nodes, 'NOT').map((e) => e.name), ['notes.txt']);
      expect(filterNodes(nodes, '  '), hasLength(3));
    });
  });

  group('icon names', () {
    // A file list shows documents, so media files read as pages with a mark
    // rather than as bare media glyphs.
    test('file kinds pick the right mark', () {
      expect(fileIconName('holiday.MP4', isDir: false), 'file-video');
      expect(fileIconName('song.flac', isDir: false), 'file-audio');
      expect(fileIconName('backup.zip', isDir: false), 'file-zip');
      expect(fileIconName('report.pdf', isDir: false), 'file-pdf');
      expect(fileIconName('main.dart', isDir: false), 'file-code');
      expect(fileIconName('README.md', isDir: false), 'file-text');
      expect(fileIconName('setup.exe', isDir: false), 'device');
      expect(fileIconName('Inter.ttf', isDir: false), 'text');
      expect(fileIconName('LICENSE', isDir: false), 'file');
      expect(fileIconName('.hidden', isDir: false), 'file');
      expect(fileIconName('Pictures', isDir: true), 'folder');
    });

    test('every mark a row can ask for is on disk', () {
      final shipped = Directory('assets/icons')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last.replaceAll('.svg', ''))
          .toSet();
      expect(shipped, isNotEmpty, reason: 'assets/icons did not resolve');
      const asked = [
        'folder', 'file', 'file-text', 'file-code', 'file-image', 'file-video',
        'file-audio', 'file-zip', 'file-pdf', 'device', 'text', 'drive',
        'folder-on', 'folder-open', 'folder-plus', 'folder-block', 'image',
        'video', 'music', 'archive', 'code', 'pdf', 'zip',
      ];
      for (final name in asked) {
        expect(shipped, contains(name), reason: '$name.svg is missing');
      }
    });

    test('nothing in the app asks for a mark that was not shipped', () {
      final shipped = Directory('assets/icons')
          .listSync()
          .whereType<File>()
          .map((f) => f.uri.pathSegments.last.replaceAll('.svg', ''))
          .toSet();
      final wanted = <String>{};
      final rx = RegExp(
          r"(?:Ico\(\s*|uiGlyph\(\s*|icon:\s*)'([a-z0-9][a-z0-9-]*)'");
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        for (final m in rx.allMatches(f.readAsStringSync())) {
          wanted.add(m.group(1)!);
        }
      }
      expect(wanted, isNotEmpty);
      for (final name in wanted) {
        expect(shipped, contains(name), reason: '$name is used but not drawn');
      }
    });
  });

  group('real folder', () {
    late Directory tmp;
    const fs = FileManager();

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('ifc_files');
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('create, list, rename, copy, move, delete', () async {
      final s = tmp.path;
      await fs.mkdir(s, 'keepsakes');
      await fs.touch(s, 'note.txt');
      expect((await fs.list(s)).map((n) => n.name), containsAll(['keepsakes', 'note.txt']));

      await fs.rename('$s${fs.separator}note.txt', 'reminder.txt');
      expect(File('$s${fs.separator}reminder.txt').existsSync(), isTrue);

      await fs.copy(['$s${fs.separator}reminder.txt'], '$s${fs.separator}keepsakes');
      expect(File('$s${fs.separator}keepsakes${fs.separator}reminder.txt').existsSync(), isTrue);

      // Moving a folder into itself is refused instead of eating it.
      await expectLater(
        fs.move(['$s${fs.separator}keepsakes'], '$s${fs.separator}keepsakes'),
        throwsA(isA<FileOpException>()),
      );
      expect(Directory('$s${fs.separator}keepsakes').existsSync(), isTrue);

      await fs.delete(['$s${fs.separator}keepsakes']);
      expect(Directory('$s${fs.separator}keepsakes').existsSync(), isFalse);
    });

    test('a name already taken gets a suffix instead of overwriting', () async {
      await fs.touch(tmp.path, 'log.txt');
      final taken = (await fs.list(tmp.path)).map((n) => n.name).toList();
      expect(uniqueName(taken, 'log.txt', s: fs.separator), 'log (2).txt');
    });

    test('plain-language failure for a folder that is not there', () async {
      final missing = '${tmp.path}${fs.separator}gone';
      await expectLater(
        fs.list(missing),
        throwsA(isA<FileOpException>()
            .having((e) => e.message, 'message', isNotEmpty)),
      );
    });

    test('protected places cannot be deleted', () async {
      await expectLater(fs.delete([fs.homePath()]),
          throwsA(isA<FileOpException>()));
    });
  });
}
