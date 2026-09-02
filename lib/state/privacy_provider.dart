import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/urls.dart' show hostOf;
import '../models.dart';

/// Per-site rules + lifetime ad/tracker statistics ("Privacy dashboard").
class PrivacyProvider extends ChangeNotifier {
  PrivacyProvider({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  final Map<String, SiteRule> _rules = {};
  final Map<String, int> _blockedByHost = {};

  int totalBlocked = 0;
  int kbSaved = 0;
  int sinceMs = DateTime.now().millisecondsSinceEpoch;

  Timer? _notifyDebounce;

  List<SiteRule> get rules =>
      List.unmodifiable(_rules.values.toList(growable: false));

  SiteRule? ruleFor(String host) => host.isEmpty ? null : _rules[host];

  List<MapEntry<String, int>> get topBlockedHosts {
    final entries = _blockedByHost.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(20).toList();
  }

  int blockedFor(String host) => _blockedByHost[host] ?? 0;

  /// ---- Effective settings (site override → global default) ----

  bool effectiveBlockAds(String url, bool globalDefault) {
    final rule = ruleFor(hostOf(url));
    return rule?.blockAds ?? globalDefault;
  }

  bool effectiveJavaScript(String url, bool globalDefault) {
    final rule = ruleFor(hostOf(url));
    return rule?.javaScript ?? globalDefault;
  }

  bool effectiveDesktopSite(String url, bool globalDefault) {
    final rule = ruleFor(hostOf(url));
    return rule?.desktopSite ?? globalDefault;
  }

  /// null → ask the user; true/false → answer immediately.
  bool? effectiveMedia(String url) => ruleFor(hostOf(url))?.media;

  // ---- Rule editing ----

  void updateRule(String host, SiteRule rule) {
    if (host.isEmpty) return;
    if (rule.isAllDefault) {
      _rules.remove(host);
    } else {
      _rules[host] = rule;
    }
    _saveRules();
  }

  void removeRule(String host) {
    _rules.remove(host);
    _saveRules();
  }

  void clearRules() {
    _rules.clear();
    _saveRules();
  }

  // ---- Statistics ----

  /// Called by the web view for every blocked request.
  void countBlocked(String host) {
    totalBlocked++;
    kbSaved += 24; // conservative average payload per ad/tracker request
    if (host.isNotEmpty) {
      _blockedByHost[host] = (_blockedByHost[host] ?? 0) + 1;
    }
    _notifyDebounce?.cancel();
    _notifyDebounce = Timer(const Duration(milliseconds: 250), () {
      _saveStats();
      notifyListeners();
    });
  }

  void resetStats() {
    totalBlocked = 0;
    kbSaved = 0;
    sinceMs = DateTime.now().millisecondsSinceEpoch;
    _blockedByHost.clear();
    _saveStats();
    notifyListeners();
  }

  // ---- Persistence ----

  Future<void> load() async {
    final p = _prefs ??= await SharedPreferences.getInstance();
    try {
      final raw = p.getString('privacy.rules');
      if (raw != null) {
        _rules
          ..clear()
          ..addEntries(
            (jsonDecode(raw) as List).map(
              (e) => MapEntry(
                (e as Map)['host'] as String,
                SiteRule.fromJson(e as Map<String, dynamic>),
              ),
            ),
          );
      }
    } catch (e) {
      debugPrint('privacy rules decode: $e');
    }
    totalBlocked = p.getInt('privacy.blocked') ?? 0;
    kbSaved = p.getInt('privacy.kbSaved') ?? 0;
    sinceMs = p.getInt('privacy.since') ?? sinceMs;
    try {
      final raw = p.getString('privacy.byHost');
      if (raw != null) {
        _blockedByHost
          ..clear()
          ..addAll(
            (jsonDecode(raw) as Map).map(
              (k, v) => MapEntry(k as String, (v as num).toInt()),
            ),
          );
      }
    } catch (e) {
      debugPrint('privacy stats decode: $e');
    }
    notifyListeners();
  }

  Future<void> _saveRules() async {
    notifyListeners();
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.setString(
      'privacy.rules',
      jsonEncode(_rules.values.map((r) => r.toJson()).toList()),
    );
  }

  Future<void> _saveStats() async {
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.setInt('privacy.blocked', totalBlocked);
    await p.setInt('privacy.kbSaved', kbSaved);
    await p.setInt('privacy.since', sinceMs);
    await p.setString('privacy.byHost', jsonEncode(_blockedByHost));
  }
}
