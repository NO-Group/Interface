import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../state/browser_provider.dart';
import 'favicon.dart';

/// Edge/Opera-style vertical tab rail (desktop).
class VerticalTabRail extends StatelessWidget {
  const VerticalTabRail({super.key});

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final palette = pal(context);

    return SizedBox(
      width: 226,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
            child: Row(
              children: [
                Icon(Icons.tab_rounded, size: 15, color: palette.textDim),
                const SizedBox(width: 8),
                Text(
                  '${browser.tabCount} tabs',
                  style: TextStyle(
                    color: palette.textDim,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon:
                      Icon(Icons.add_rounded, size: 19, color: palette.accent),
                  onPressed: () => browser.newTab(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.border),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: browser.tabs.length,
              itemBuilder: (_, i) {
                final tab = browser.tabs[i];
                final selected = i == browser.index;
                final isSplit = tab.id == browser.splitTabId;
                final group = browser.groupOf(tab);
                final groupColor =
                    group == null ? null : Color(group.colorValue);

                return InkWell(
                  onTap: () => browser.select(i),
                  onSecondaryTapUp: (d) => _menu(context, tab, d.globalPosition),
                  onTertiaryTapUp: (_) => browser.closeTab(tab),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    margin:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: selected
                          ? palette.surfaceAlt.withValues(alpha: 0.9)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: Border(
                        left: BorderSide(
                          color: selected
                              ? (groupColor ?? palette.accent)
                              : (groupColor ?? Colors.transparent),
                          width: 3,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (tab.incognito)
                          Icon(Icons.shield_rounded,
                              size: 15, color: palette.accent)
                        else if (tab.onSpeedDial)
                          Icon(Icons.add_rounded,
                              size: 15, color: palette.textDim)
                        else
                          Favicon(host: tab.host, url: tab.faviconUrl, size: 16),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            tab.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: selected ? palette.text : palette.textDim,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (isSplit)
                          Icon(Icons.vertical_split_rounded,
                              size: 14, color: palette.accent),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => browser.closeTab(tab),
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Icon(Icons.close_rounded,
                                size: 13, color: palette.textDim),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _menu(
      BuildContext context, BrowserTab tab, Offset globalPosition) async {
    final browser = context.read<BrowserProvider>();
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        (overlay?.size.width ?? 800) - globalPosition.dx,
        0,
      ),
      items: const [
        PopupMenuItem(value: 'split', child: Text('Open in split view')),
        PopupMenuItem(value: 'close', child: Text('Close tab')),
      ],
    );
    if (action == 'split') browser.openSplit(tab: tab);
    if (action == 'close') browser.closeTab(tab);
  }
}
