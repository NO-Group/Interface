import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart' hide Favicon;
import 'package:provider/provider.dart';
import 'icons.dart';

import '../core/pal.dart';
import '../core/ui.dart';
import '../models.dart';
import '../state/browser_provider.dart';
import '../state/privacy_provider.dart';
import '../state/settings_provider.dart';
import 'favicon.dart';

/// Site information: connection, what was blocked, and per-site settings
/// (ads, JavaScript, desktop site, camera and microphone).
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

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: palette.surface,
    builder: (sheetContext) => SafeArea(
      child: StatefulBuilder(
        builder: (sheetContext, setSheet) {
          SiteRule current = privacy.ruleFor(host) ?? SiteRule(host: host);

          Widget siteToggle(
            String title,
            String subtitle,
            Object icon,
            bool globalDefault,
            bool? siteValue, {
            String? settingsKey,
          }) {
            final choice = siteValue;
            final value = choice ?? globalDefault;
            final isOverride = choice != null;
            return SwitchListTile(
              secondary: uiGlyph(icon,
                  color: value ? palette.accent : palette.textDim),
              title: Text(title, style: Ui.text(palette, weight: FontWeight.w500)),
              subtitle: Text(
                isOverride ? 'Only for this site' : subtitle,
                style: Ui.caption(palette),
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
                const SizedBox(height: 6),
                ListTile(
                  leading: Favicon(host: host, size: 34),
                  title: Text(
                    host,
                    style: Ui.text(palette, size: 15.5, weight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    secure
                        ? 'Connection is secure (HTTPS)'
                        : 'Not secure — data can be read in transit',
                    style: Ui.text(
                      palette,
                      size: Ui.sizeSmall,
                      weight: FontWeight.w500,
                      color: secure ? palette.success : palette.danger,
                    ),
                  ),
                  trailing: uiGlyph(
                    secure ? 'lock' : 'alert',
                    color: secure ? palette.success : palette.danger,
                  ),
                ),
                Divider(color: palette.border, height: 1),
                Container(
                  margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                  decoration: BoxDecoration(
                    color: blocked > 0 ? palette.accentSoft : palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(Ui.rField),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      uiGlyph('shield-on',
                          size: 17, color: palette.accent),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          blocked > 0
                              ? '$blocked ads and trackers blocked on this site'
                              : 'Nothing blocked on this site yet',
                          style: Ui.text(palette, size: Ui.sizeBody),
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
                            m.showSnackBar(
                              SnackBar(content: Text('Ads allowed on $host')),
                            );
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
                  'block',
                  settings.blockAds,
                  current.blockAds,
                  settingsKey: 'ads',
                ),
                siteToggle(
                  'JavaScript',
                  'Reload applies the change',
                  'code',
                  true,
                  current.javaScript,
                  settingsKey: 'js',
                ),
                if (!Platform.isWindows)
                  siteToggle(
                    'Desktop site',
                    'Request the desktop version',
                    'monitor',
                    settings.desktopMode,
                    current.desktopSite,
                    settingsKey: 'desktop',
                  ),
                siteToggle(
                  'Camera, mic & location',
                  'Ask / allow access from this site',
                  'video',
                  true,
                  current.media,
                  settingsKey: 'media',
                ),
                Divider(color: palette.border, height: 1),
                ListTile(
                  leading: uiGlyph('cookie', color: palette.textDim),
                  title: Text('Cookies & site data',
                      style: Ui.text(palette, weight: FontWeight.w500)),
                  subtitle: Text('Clear cookies set by $host',
                      style: Ui.caption(palette)),
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
