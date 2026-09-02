import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:interface_browser/core/palette.dart';
import 'package:interface_browser/models.dart';
import 'package:interface_browser/services/blocklist.dart';

void main() {
  group('BrowserPalette.resolve', () {
    test('system follows platform brightness', () {
      expect(
        BrowserPalette.resolve(ThemeChoice.system, Brightness.dark).id,
        'dark',
      );
      expect(
        BrowserPalette.resolve(ThemeChoice.system, Brightness.light).id,
        'light',
      );
    });

    test('every named theme resolves to itself', () {
      expect(BrowserPalette.resolve(ThemeChoice.red, Brightness.light).id,
          'red');
      expect(BrowserPalette.resolve(ThemeChoice.green, Brightness.light).id,
          'green');
      expect(BrowserPalette.resolve(ThemeChoice.mono, Brightness.light).id,
          'mono');
      expect(BrowserPalette.resolve(ThemeChoice.custom, Brightness.light).id,
          'custom');
    });

    test('incognito always wins', () {
      final p = BrowserPalette.resolve(
        ThemeChoice.light,
        Brightness.light,
        incognitoActive: true,
      );
      expect(p.id, 'incognito');
      expect(p.isDark, isTrue);
    });

    test('the brand is navy + cyan in the default themes', () {
      // Light theme chrome wears the exact brand navy.
      expect(BrowserPalette.light.primary, BrowserPalette.navy);
      // Dark theme keeps the navy family + cyan accent.
      expect(BrowserPalette.dark.primary, const Color(0xFF14336B));
      expect(BrowserPalette.dark.accent, BrowserPalette.cyan);
      expect(BrowserPalette.light.accent, BrowserPalette.cyanDeep);
    });

    test('mono theme is pure grayscale', () {
      final p = BrowserPalette.mono;
      for (final c in [p.background, p.surface, p.accent, p.primary]) {
        expect(c.red == c.green && c.green == c.blue, isTrue,
            reason: '$c is not grayscale');
      }
    });

    test('custom theme is frosted glass', () {
      expect(BrowserPalette.glass.chromeTranslucent, isTrue);
      expect(BrowserPalette.glass.surface.alpha, lessThan(255));
    });
  });

  group('ThemeChoiceX', () {
    test('id round-trips', () {
      for (final t in ThemeChoice.values) {
        expect(ThemeChoiceX.fromId(t.id), t);
      }
      expect(ThemeChoiceX.fromId('bogus'), ThemeChoice.system);
      expect(ThemeChoiceX.fromId(null), ThemeChoice.system);
    });
  });

  group('blocklist', () {
    test('blocks exact and nested hosts', () {
      expect(isBlockedHost('doubleclick.net'), isTrue);
      expect(isBlockedHost('ad.doubleclick.net'), isTrue);
      expect(isBlockedHost('analytics.google.com'), isFalse,
          reason: 'parent google.com is not blocked');
      expect(isBlockedHost('example.com'), isFalse);
      expect(isBlockedHost('notdoubleclick.net'), isFalse,
          reason: 'suffix match must respect domain boundaries');
      expect(isBlockedHost(''), isFalse);
    });
  });

  group('models', () {
    test('Bookmark json round-trip', () {
      const b = Bookmark(url: 'https://a.b', title: 'A');
      final b2 = Bookmark.fromJson(b.toJson());
      expect(b2.url, b.url);
      expect(b2.title, b.title);
    });

    test('HistoryEntry json round-trip', () {
      const h = HistoryEntry(url: 'https://a.b', title: 'A', visitedAt: 42);
      final h2 = HistoryEntry.fromJson(h.toJson());
      expect(h2.visitedAt, 42);
    });

    test('SpeedDialItem json round-trip + copyWith', () {
      const s = SpeedDialItem(id: 'x', title: 'T', url: 'https://a.b');
      final s2 = SpeedDialItem.fromJson(s.toJson());
      expect(s2.id, 'x');
      expect(s.copyWith(title: 'Z').title, 'Z');
      expect(s.copyWith(title: 'Z').url, s.url);
    });

    test('DownloadItem progress formatting', () {
      final d = DownloadItem(id: 'i', url: 'https://a.b/f.zip',
          fileName: 'f.zip', savedDir: '/tmp')
        ..total = 2 * 1024 * 1024
        ..received = 1024 * 1024
        ..status = DownloadStatus.done;
      expect(d.statusLabel, contains('MB'));
    });
  });
}
