import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../state/browser_provider.dart';
import 'favicon.dart';
import 'glass.dart';

/// Chrome-style desktop tab strip: favicon tabs, close buttons,
/// middle-click close, right-click context menu.
class TabStrip extends StatelessWidget {
  const TabStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final palette = pal(context);

    return GlassBox(
      enabled: palette.chromeTranslucent,
      color: palette.chromeFill,
      child: SizedBox(
        height: 38,
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < browser.tabs.length; i++)
                      _ChromeTab(
                        key: ValueKey(browser.tabs[i].id),
                        tab: browser.tabs[i],
                        selected: i == browser.index,
                        onSelect: () => browser.select(i),
                        onClose: () => browser.closeTab(browser.tabs[i]),
                        onSecondaryTap: (offset) =>
                            _showMenu(context, browser.tabs[i], offset),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'New tab (Ctrl+T)',
              icon: Icon(Icons.add_rounded, size: 20, color: palette.textDim),
              onPressed: () => browser.newTab(),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Future<void> _showMenu(
    BuildContext context,
    BrowserTab tab,
    Offset globalPosition,
  ) async {
    final browser = context.read<BrowserProvider>();
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        overlay?.size.width ?? 800 - globalPosition.dx,
        0,
      ),
      items: const [
        PopupMenuItem(
            value: 'new',
            height: 40,
            child: Row(children: [
              Icon(Icons.add_rounded, size: 18),
              SizedBox(width: 10),
              Text('New tab to the right'),
            ])),
        PopupMenuItem(
            value: 'duplicate',
            height: 40,
            child: Row(children: [
              Icon(Icons.copy_rounded, size: 18),
              SizedBox(width: 10),
              Text('Duplicate'),
            ])),
        PopupMenuDivider(),
        PopupMenuItem(
            value: 'close',
            height: 40,
            child: Row(children: [
              Icon(Icons.close_rounded, size: 18),
              SizedBox(width: 10),
              Text('Close tab'),
            ])),
        PopupMenuItem(
            value: 'others',
            height: 40,
            child: Row(children: [
              Icon(Icons.tab_rounded, size: 18),
              SizedBox(width: 10),
              Text('Close other tabs'),
            ])),
        PopupMenuItem(
            value: 'right',
            height: 40,
            child: Row(children: [
              Icon(Icons.keyboard_tab_rounded, size: 18),
              SizedBox(width: 10),
              Text('Close tabs to the right'),
            ])),
      ],
    );
    switch (action) {
      case 'new':
        browser.newTab();
      case 'duplicate':
        browser.duplicateTab(tab);
      case 'close':
        browser.closeTab(tab);
      case 'others':
        browser.closeOthers(tab);
      case 'right':
        browser.closeToTheRight(tab);
    }
  }
}

class _ChromeTab extends StatefulWidget {
  const _ChromeTab({
    super.key,
    required this.tab,
    required this.selected,
    required this.onSelect,
    required this.onClose,
    required this.onSecondaryTap,
  });

  final BrowserTab tab;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onClose;
  final void Function(Offset globalPosition) onSecondaryTap;

  @override
  State<_ChromeTab> createState() => _ChromeTabState();
}

class _ChromeTabState extends State<_ChromeTab> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    final w = widget.selected;

    return InkWell(
      onTap: widget.onSelect,
      onSecondaryTapUp: (d) => widget.onSecondaryTap(d.globalPosition),
      onTertiaryTapUp: (_) => widget.onClose(),
      onHover: (v) => setState(() => _hovering = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: widget.tab.displayTitle.length > 24 ? 220.0 : 168.0,
        margin: const EdgeInsets.fromLTRB(2, 6, 2, 0),
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(
          color: w
              ? palette.surface
              : (_hovering
                  ? palette.surfaceAlt.withValues(alpha: 0.55)
                  : Colors.transparent),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(10),
          ),
        ),
        child: Row(
          children: [
            if (widget.tab.incognito)
              Icon(Icons.shield_rounded, size: 14, color: palette.accent)
            else if (widget.tab.onSpeedDial)
              Icon(Icons.add_rounded, size: 14, color: palette.textDim)
            else
              Favicon(host: widget.tab.host, url: widget.tab.faviconUrl, size: 15),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                widget.tab.displayTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.3,
                  color: w ? palette.text : palette.textDim,
                  fontWeight: w ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ),
            const SizedBox(width: 2),
            SizedBox(
              width: 22,
              height: 22,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                splashRadius: 11,
                icon: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: _hovering || w ? palette.textDim : Colors.transparent,
                ),
                onPressed: widget.onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
