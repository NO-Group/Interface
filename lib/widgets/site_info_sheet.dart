import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' hide Favicon;
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../core/urls.dart';
import '../models.dart';
import '../state/browser_provider.dart';
import '../state/privacy_provider.dart';
import '../state/settings_provider.dart';
import 'favicon.dart';

/// Chrome-style site information sheet: security, blocked-tracker count
/// and per-site settings (ads, JavaScript, desktop site, device access).
Future<void> showSiteInfoSheet(BuildContext context) {
  final browser = context.read<BrowserProvider>();
  final tab = browser.current;
  final palette = pal(context);
  final privacy = context.read<PrivacyProvider>();
  final settings = context.read<SettingsProvider>();

  if (tab.onSpeedDial || tab.url.isEmpty) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Open a website to see site information')),
    );
    return Future.value();
  }

  final host = tab.host;
  final url = tab.url;
  final secure = url.startsWith('https://');
  final blocked = privacy.blockedFor(host);
  final rule = privacy.ruleFor(host) ?? SiteRule(host: host);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: StatefulBuilder(
        builder: (sheetContext, setSheet) {
          SiteRule current = privacy.ruleFor(host) ?? SiteRule(host: host);

          Widget siteToggle(
            String title,
            String subtitle,
            IconData icon,
            bool globalDefault,
            bool? siteValue, {
            String? settingsKey,
          }) {
            final choice = siteValue;
            final value = choice ?? globalDefault;
            final isOverride = choice != null;
            return SwitchListTile(
              secondary: Icon(icon,
                  color: value ? palette.accent : palette.textDim),
              title: Text(title,
                  style: TextStyle(color: palette.text, fontSize: 13.5)),
              subtitle: Text(
                isOverride
                    ? 'Site override — $subtitle'
                    : '$subtitle (default)',
                style: TextStyle(color: palette.textDim, fontSize: 11.5),
              ),
              value: value,
              onChanged: (v) {
                final updated =
                    _updatedRule(current, settingsKey!, v, host);
                current = updated;
                privacy.updateRule(host, updated);
                setSheet(() {});
                if (settingsKey == 'desktop') {
                  browser.refreshWebViews();
                }
              },
            );
          }

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  leading: Favicon(host: host, size: 34),
                  title: Text(
                    host,
                    style: TextStyle(
                      color: palette.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Text(
                    secure
                        ? 'Connection is secure (HTTPS)'
                        : 'Not secure — data can be read in transit',
                    style: TextStyle(
                      color: secure ? palette.success : palette.danger,
                      fontSize: 12,
                    ),
                  ),
                  trailing: Icon(
                    secure ? Icons.lock_rounded : Icons.warning_amber_rounded,
                    color: secure ? palette.success : palette.danger,
                  ),
                ),
                Divider(color: palette.border, height: 1),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: palette.surfaceAlt.withValues(alpha: 0.4),
                  child: Row(
                    children: [
                      Icon(Icons.shield_rounded,
                          size: 18, color: palette.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          blocked > 0
                              ? '$blocked trackers & ads blocked on this site'
                              : 'No trackers blocked on this site yet',
                          style: TextStyle(
                              color: palette.text, fontSize: 13),
                        ),
                      ),
                      if (blocked > 0)
                        TextButton(
                          onPressed: () {
                            privacy.updateRule(
                              host,
                              current.copyWith(
                                blockAds: false,
                              ),
                            );
                            Navigator.of(sheetContext).pop();
                            browser.refreshWebViews();
                            final m = ScaffoldMessenger.of(context);
                            m.showSnackBar(SnackBar(
                                content:
                                    Text('Ads allowed on $host')));
                          },
                          child: const Text('Allow ads'),
                        ),
                    ],
                  ),
                ),
                Divider(color: palette.border, height: 1),
                siteToggle(
                  'Block ads & trackers',
                  'Applies to this site only',
                  Icons.block_rounded,
                  settings.blockAds,
                  current.blockAds,
                  settingsKey: 'ads',
                ),
                siteToggle(
                  'JavaScript',
                  'Reload applies the change',
                  Icons.javascript_rounded,
                  true,
                  current.javaScript,
                  settingsKey: 'js',
                ),
                if (!Platform.isWindows)
                  siteToggle(
                    'Desktop site',
                    'Request the desktop version',
                    Icons.desktop_windows_rounded,
                    settings.desktopMode,
                    current.desktopSite,
                    settingsKey: 'desktop',
                  ),
                siteToggle(
                  'Camera, mic & location',
                  'Ask / allow access from this site',
                  Icons.videocam_outlined,
                  true,
                  current.media,
                  settingsKey: 'media',
                ),
                Divider(color: palette.border, height: 1),
                ListTile(
                  leading: Icon(Icons.cookie_outlined, color: palette.textDim),
                  title: Text('Cookies & site data',
                      style: TextStyle(color: palette.text, fontSize: 13.5)),
                  subtitle: Text('Clear cookies set by $host',
                      style:
                          TextStyle(color: palette.textDim, fontSize: 11.5)),
                  trailing: FilledButton.tonal(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      var ok = false;
                      try {
                        ok = await CookieManager.instance().deleteCookies(
                          url: WebUri('https://$host/'),
                          domain: host,
                        );
                      } catch (_) {}
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(SnackBar(
                        content: Text(ok == false
                            ? 'Could not clear cookies for $host'
                            : 'Cookies cleared for $host'),
                      ));
                      await browser.reload();
                    },
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    ),
  );
}

SiteRule _updatedRule(SiteRule rule, String key, bool value, String host) {
  switch (key) {
    case 'ads':
      return rule.copyWith(blockAds: value);
    case 'js':
      return rule.copyWith(javaScript: value);
    case 'desktop':
      return rule.copyWith(desktopSite: value);
    case 'media':
      return rule.copyWith(media: value);
  }
  return SiteRule(host: host);
}
