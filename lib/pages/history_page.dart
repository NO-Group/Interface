import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/icons.dart';

import '../core/pal.dart';
import '../core/ui.dart';
import '../core/urls.dart';
import '../models.dart';
import '../state/browser_provider.dart';
import '../state/profile_provider.dart';
import '../widgets/favicon.dart';

/// Browsing history grouped by day — embeddable in the side panel.
class HistoryList extends StatelessWidget {
  const HistoryList({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final palette = pal(context);

    if (profile.history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            uiGlyph('clock', size: 52, color: palette.textDim),
            const SizedBox(height: 12),
            Text('Pages you visit show up here',
                style: TextStyle(color: palette.text, fontSize: 15)),
          ],
        ),
      );
    }

    String? lastDay;
    final children = <Widget>[];
    for (final entry in profile.history) {
      final day = _dayLabel(entry.visitedAt);
      if (day != lastDay) {
        lastDay = day;
        children.add(_SectionHeader(label: day));
      }
      children.add(_HistoryTile(entry: entry, embedded: embedded));
    }

    return ListView(children: children);
  }

  static String _dayLabel(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(
        label,
        style: Ui.text(palette, size: 14, weight: FontWeight.w700),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.embedded});

  final HistoryEntry entry;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    final browser = context.read<BrowserProvider>();
    final profile = context.read<ProfileProvider>();
    final d = DateTime.fromMillisecondsSinceEpoch(entry.visitedAt);
    final time =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    return ListTile(
      dense: true,
      leading: Favicon(host: hostOf(entry.url)),
      title: Text(
        entry.title.isEmpty ? displayUrl(entry.url) : entry.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: palette.text, fontSize: 13.5),
      ),
      subtitle: Text(
        displayUrl(entry.url),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: palette.textDim, fontSize: 11.5),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(time, style: TextStyle(color: palette.textDim, fontSize: 11)),
          ),
          if (!embedded)
            IconButton(
              icon: uiGlyph('close', size: 17, color: palette.textDim),
              onPressed: () => profile.removeHistory(entry),
            ),
        ],
      ),
      onTap: () {
        browser.navigate(entry.url);
      },
    );
  }
}

/// Full-page route.
class HistoryRoute extends StatelessWidget {
  const HistoryRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    final profile = context.read<ProfileProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: 'Clear browsing history',
            icon: uiGlyph('clear', color: palette.text),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (d) => AlertDialog(
                  title: const Text('Clear history?'),
                  content: const Text(
                    'Removes all visited pages from this device. '
                    'Cookies and cache can be cleared in Settings.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(d).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.danger,
                      ),
                      onPressed: () => Navigator.of(d).pop(true),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                profile.clearHistory();
                if (!context.mounted) return;
                final messenger = ScaffoldMessenger.of(context);
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  const SnackBar(content: Text('History cleared')),
                );
              }
            },
          ),
        ],
      ),
      backgroundColor: palette.background,
      body: const HistoryList(),
    );
  }
}
