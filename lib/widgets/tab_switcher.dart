import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../core/ui.dart';
import '../state/browser_provider.dart';
import 'favicon.dart';

/// Chrome-mobile-style tab switcher: grid of live tab cards,
/// plus one-tap new tab & incognito.
class TabSwitcherPage extends StatelessWidget {
  const TabSwitcherPage({super.key});

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final palette = pal(context);
    final incognitoCount =
        browser.tabs.where((t) => t.incognito).length;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        title: Text(
          browser.tabCount == 1 ? '1 tab' : '${browser.tabCount} tabs',
          style: Ui.text(palette, size: 16, weight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: palette.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (incognitoCount > 0)
            TextButton(
              onPressed: () => browser.closeAllIncognito(),
              child: const Text('Close incognito'),
            ),
          IconButton(
            tooltip: 'New incognito tab',
            icon: Icon(Icons.shield_outlined, color: palette.text),
            onPressed: () {
              browser.newTab(incognito: true);
              Navigator.of(context).pop();
            },
          ),
          IconButton(
            tooltip: 'New tab',
            icon: Icon(Icons.add_rounded, color: palette.text),
            onPressed: () {
              browser.newTab();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final columns =
              constraints.maxWidth >= 700 ? 4 : (constraints.maxWidth >= 480 ? 3 : 2);
          return GridView.builder(
            padding: const EdgeInsets.all(14),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.05,
            ),
            itemCount: browser.tabs.length + 1,
            itemBuilder: (_, i) {
              if (i == browser.tabs.length) {
                return _NewTabCard(onTap: () {
                  browser.newTab();
                  Navigator.of(context).pop();
                });
              }
              final tab = browser.tabs[i];
              final selected = i == browser.index;
              return _TabCard(
                tab: tab,
                selected: selected,
                onTap: () {
                  browser.select(i);
                  Navigator.of(context).pop();
                },
                onClose: () => browser.closeTab(tab),
              );
            },
          );
        },
      ),
    );
  }
}

class _TabCard extends StatelessWidget {
  const _TabCard({
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.onClose,
  });

  final BrowserTab tab;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected ? Ui.float(palette, y: 4, blur: 14) : null,
          border: Border.all(
            color: selected ? palette.accent : palette.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (tab.incognito)
                  Icon(Icons.shield_rounded, size: 15, color: palette.accent)
                else if (tab.onSpeedDial)
                  Icon(Icons.add_rounded, size: 15, color: palette.textDim)
                else
                  Favicon(host: tab.host, url: tab.faviconUrl, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    tab.displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Ui.text(
                      palette,
                      size: Ui.sizeSmall,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onClose,
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(Icons.close_rounded,
                        size: 15, color: palette.textDim),
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (tab.host.isNotEmpty)
              Text(
                tab.host,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Ui.caption(palette),
              ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                minHeight: 2.5,
                value: tab.loading ? (tab.progress / 100) : 1,
                backgroundColor: palette.surfaceAlt,
                color: tab.loading ? palette.accent : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewTabCard extends StatelessWidget {
  const _NewTabCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: Icon(Icons.add_rounded, size: 34, color: palette.textDim),
      ),
    );
  }
}
