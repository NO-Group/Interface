import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../core/ui.dart';
import '../state/privacy_provider.dart';
import '../state/settings_provider.dart';
import '../widgets/favicon.dart';

/// Privacy dashboard — lifetime tracker blocking stats and controls.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key, this.embedded = false});

  final bool embedded;

  String _since(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final privacy = context.watch<PrivacyProvider>();
    final settings = context.watch<SettingsProvider>();
    final palette = pal(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 10),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(Ui.rCard),
                  border: Border.all(color: palette.border),
                ),
                child: Icon(Icons.shield_rounded,
                    size: 24, color: palette.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${privacy.totalBlocked}',
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'trackers & ads blocked since ${_since(privacy.sinceMs)}',
                      style:
                          TextStyle(color: palette.textDim, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _Stat(
                icon: Icons.data_usage_rounded,
                label:
                    '${(privacy.kbSaved / 1024).toStringAsFixed(privacy.kbSaved > 10240 ? 0 : 1)} MB',
                sub: 'data saved (est.)',
                palette: palette,
              ),
              const SizedBox(width: 10),
              _Stat(
                icon: Icons.bolt_rounded,
                label: '${privacy.topBlockedHosts.length}',
                sub: 'worst offenders',
                palette: palette,
              ),
            ],
          ),
        ),
        SwitchListTile(
          secondary: Icon(Icons.block_rounded,
              color: settings.blockAds ? palette.accent : palette.textDim),
          title: const Text('Block ads & pop-ups'),
          subtitle:
              const Text('Blocks known ad and tracker addresses before they load'),
          value: settings.blockAds,
          onChanged: settings.setBlockAds,
        ),
        SwitchListTile(
          secondary: Icon(Icons.visibility_off_rounded,
              color: settings.cosmeticFiltering
                  ? palette.accent
                  : palette.textDim),
          title: const Text('Hide leftover ad spaces'),
          subtitle: const Text('Hide empty ad slots left behind'),
          value: settings.cosmeticFiltering,
          onChanged: settings.setCosmeticFiltering,
        ),
        if (privacy.topBlockedHosts.isEmpty)
          Padding(
            padding: const EdgeInsets.all(28),
            child: Center(
              child: Text(
                'Blocked ads and trackers will be listed here.',
                style: TextStyle(color: palette.textDim, fontSize: 12.5),
              ),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text(
              'Most blocked',
              style: Ui.text(palette, size: 14, weight: FontWeight.w700),
            ),
          ),
          for (final e in privacy.topBlockedHosts)
            ListTile(
              dense: true,
              leading: Favicon(host: e.key, size: 18),
              title: Text(
                e.key,
                style: TextStyle(color: palette.text, fontSize: 13),
              ),
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: Ui.tint(palette, palette.accent, radius: 7),
                child: Text(
                  '${e.value}',
                  style: TextStyle(
                    color: palette.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
          Center(
            child: TextButton.icon(
              onPressed: () => privacy.resetStats(),
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Reset statistics'),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.label,
    required this.sub,
    required this.palette,
  });

  final IconData icon;
  final String label;
  final String sub;
  final BrowserPalette palette;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surfaceAlt.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: palette.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(color: palette.textDim, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-page route.
class PrivacyRoute extends StatelessWidget {
  const PrivacyRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy dashboard')),
      backgroundColor: palette.background,
      body: const PrivacyPage(),
    );
  }
}
