import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Live omnibox suggestions (DuckDuckGo autocomplete endpoint).
class SuggestionService {
  SuggestionService._();

  static const _timeout = Duration(seconds: 4);

  static Future<List<String>> forQuery(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    try {
      final res = await http
          .get(
            Uri.parse(
              'https://duckduckgo.com/ac/?q=${Uri.encodeComponent(q)}&type=list',
            ),
            headers: const {
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Accept': 'application/json',
            },
          )
          .timeout(_timeout);
      if (res.statusCode != 200) return const [];
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is List && data.length >= 2 && data[1] is List) {
        return (data[1] as List)
            .map((e) => e is Map
                ? (e['phrase'] ?? '').toString()
                : e.toString())
            .where((s) => s.isNotEmpty && s.toLowerCase() != q.toLowerCase())
            .take(6)
            .toList();
      }
      if (data is List) {
        return data
            .map((e) => e is Map ? (e['phrase'] ?? '').toString() : '')
            .where((s) => s.isNotEmpty && s.toLowerCase() != q.toLowerCase())
            .take(6)
            .toList();
      }
    } catch (_) {}
    return const [];
  }
}
