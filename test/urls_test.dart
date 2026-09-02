import 'package:flutter_test/flutter_test.dart';
import 'package:interface_browser/core/urls.dart';

void main() {
  group('urlFromInput', () {
    test('passes real URLs through', () {
      expect(
        urlFromInput('https://example.com/a?b=c')?.toString(),
        'https://example.com/a?b=c',
      );
      expect(
        urlFromInput('http://localhost:8123/x').toString(),
        'http://localhost:8123/x',
      );
    });

    test('prefixes host-like input with https', () {
      expect(
        urlFromInput('example.com')?.toString(),
        'https://example.com',
      );
      expect(
        urlFromInput('news.ycombinator.com/item?id=1')?.host,
        'news.ycombinator.com',
      );
      expect(
        urlFromInput('192.168.0.1/admin')?.toString(),
        'https://192.168.0.1/admin',
      );
      expect(
        urlFromInput('localhost:8080')?.port,
        8080,
      );
    });

    test('returns null for plain searches', () {
      expect(urlFromInput('how to train your dragon'), isNull);
      expect(urlFromInput('weather tomorrow'), isNull);
      expect(urlFromInput('  '), isNull);
      expect(urlFromInput('hello.world news'), isNull);
    });

    test('keeps external schemes', () {
      expect(urlFromInput('mailto:hi@example.com')?.scheme, 'mailto');
      expect(urlFromInput('tel:+15551234567')?.scheme, 'tel');
    });
  });

  group('displayUrl', () {
    test('strips the scheme', () {
      expect(displayUrl('https://example.com/x'), 'example.com/x');
      expect(displayUrl('http://a.b'), 'a.b');
      expect(displayUrl(''), '');
    });
  });

  group('hostOf', () {
    test('extracts the host', () {
      expect(hostOf('https://m.example.com/a'), 'm.example.com');
      expect(hostOf('about:blank'), '');
    });
  });

  group('SearchEngine', () {
    test('builds query urls', () {
      expect(
        SearchEngine.google.queryUrl('hello world'),
        'https://www.google.com/search?q=hello%20world',
      );
    });

    test('byId falls back to Google', () {
      expect(SearchEngine.byId('nope').id, 'google');
      expect(SearchEngine.byId('bing').name, 'Bing');
    });
  });

  group('faviconUrlForHost', () {
    test('targets the s2 service', () {
      expect(
        faviconUrlForHost('example.com'),
        contains('domain=example.com'),
      );
    });
  });
}
