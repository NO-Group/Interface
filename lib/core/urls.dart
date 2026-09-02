/// URL detection + search engines.

class SearchEngine {
  const SearchEngine(this.id, this.name, this.homepage, this.queryTemplate);

  final String id;
  final String name;
  final String homepage;
  /// `%s` is replaced by the URL-encoded query.
  final String queryTemplate;

  String queryUrl(String q) =>
      queryTemplate.replaceAll('%s', Uri.encodeComponent(q));

  static const google = SearchEngine(
    'google',
    'Google',
    'https://www.google.com',
    'https://www.google.com/search?q=%s',
  );

  static const duckduckgo = SearchEngine(
    'duckduckgo',
    'DuckDuckGo',
    'https://duckduckgo.com',
    'https://duckduckgo.com/?q=%s',
  );

  static const bing = SearchEngine(
    'bing',
    'Bing',
    'https://www.bing.com',
    'https://www.bing.com/search?q=%s',
  );

  static const brave = SearchEngine(
    'brave',
    'Brave Search',
    'https://search.brave.com',
    'https://search.brave.com/search?q=%s',
  );

  static const ecosia = SearchEngine(
    'ecosia',
    'Ecosia',
    'https://www.ecosia.org',
    'https://www.ecosia.org/search?q=%s',
  );

  static const yahoo = SearchEngine(
    'yahoo',
    'Yahoo',
    'https://search.yahoo.com',
    'https://search.yahoo.com/search?p=%s',
  );

  static const all = <SearchEngine>[
    google,
    duckduckgo,
    bing,
    brave,
    ecosia,
    yahoo,
  ];

  static SearchEngine byId(String? id) =>
      all.firstWhere((e) => e.id == id, orElse: () => google);
}

/// Schemes we consider "web content" — anything the web view can show.
const kWebSchemes = <String>{
  'http',
  'https',
  'about',
  'data',
  'blob',
  'file',
  'view-source',
};

/// Schemes handed to the OS instead of the web view.
const kExternalSchemes = <String>{
  'tel',
  'mailto',
  'sms',
  'geo',
  'market',
  'intent',
  'bitcoin',
  'magnet',
};

bool isWebScheme(Uri uri) => kWebSchemes.contains(uri.scheme.toLowerCase());
bool isExternalScheme(Uri uri) =>
    kExternalSchemes.contains(uri.scheme.toLowerCase());

/// Turns whatever the user typed in the omnibox into a URL.
///
/// * Real URLs (with a known scheme) pass through untouched.
/// * Host-ish inputs (`example.com`, `localhost:8080`, `192.168.0.1/x`)
///   get `https://` prefixed.
/// * Everything else returns `null` — the caller should run a web search.
Uri? urlFromInput(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;

  final u = Uri.tryParse(s);
  if (u == null) return null;

  final scheme = u.scheme.toLowerCase();
  if (u.hasScheme && scheme.isNotEmpty) {
    // `localhost:8080` parses with scheme `localhost` — treat unknown
    // single-word schemes as hosts, everything else as a real scheme.
    final looksLikePort =
        scheme.length > 1 &&
        RegExp(r'^[a-z0-9.-]+$').hasMatch(scheme) &&
        !kWebSchemes.contains(scheme) &&
        !kExternalSchemes.contains(scheme);
    if (!looksLikePort) return u;
  }

  final isHost = _hostLike(s);
  if (!isHost) return null;

  final prefixed = Uri.tryParse('https://$s');
  if (prefixed == null || prefixed.host.isEmpty) return null;
  return prefixed;
}

bool _hostLike(String s) {
  if (s.contains(' ') || s.isEmpty) return false;
  if (s.startsWith('localhost')) return true;
  if (RegExp(r'^\d{1,3}(\.\d{1,3}){3}(:\d+)?(/.*)?$').hasMatch(s)) return true;
  if (s.startsWith('.') || s.startsWith('/')) return false;
  return s.contains('.') && !s.endsWith('.');
}

/// Host (or short label) for favicons / tab tiles.
String hostOf(String url) {
  final u = Uri.tryParse(url);
  if (u == null) return '';
  if (u.host.isNotEmpty) return u.host;
  return u.authority;
}

/// `https://m.example.com/a?b` → `m.example.com/a?b` for the omnibox.
String displayUrl(String url) {
  if (url.isEmpty) return '';
  final u = Uri.tryParse(url);
  if (u == null) return url;
  if (u.hasScheme) {
    final rest = url.substring(u.scheme.length + 3); // strip '://'
    return rest;
  }
  return url;
}

/// Google's public favicon service — reliable fallback everywhere.
String faviconUrlForHost(String host, {int size = 64}) =>
    'https://www.google.com/s2/favicons?sz=$size&domain=${Uri.encodeComponent(host)}';
