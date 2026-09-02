import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../models.dart';
import '../state/browser_provider.dart';
import 'favicon.dart';
import 'glass.dart';

/// Chrome-style desktop tab strip: favicon tabs, tab groups, close buttons,
/// middle-click close, right-click context menu.
class TabStrip extends StatelessWidget {
  const TabStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final palette = pal(context);

    final visible = <_StripEntry>[
      for (final tab in browser.tabs)
        if (!browser.collapsedGroups.contains(tab.groupId ?? '') ||
            tab.id == browser.current.id ||
            tab.id == browser.splitTabId)
          _StripEntry(tab),
    ];

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
                    for (final entry in visible)
                      _ChromeTab(
                        key: ValueKey(entry.tab.id),
                        tab: entry.tab,
                        group: browser.groupOf(entry.tab),
                        selected: entry.tab.id == browser.current.id,
                        isSplit: entry.tab.id == browser.splitTabId,
                        onSelect: () => browser.selectTab(entry.tab),
                        onClose: () => browser.closeTab(entry.tab),
                        onSecondaryTap: (offset) =>
                            _showMenu(context, entry.tab, offset),
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
        (overlay?.size.width ?? 800) - globalPosition.dx,
        0,
      ),
      items: [
        const PopupMenuItem(
            value: 'new',
            height: 40,
            child: _Row(icon: Icons.add_rounded, label: 'New tab to the right')),
        const PopupMenuItem(
            value: 'duplicate',
            height: 40,
            child: _Row(icon: Icons.copy_rounded, label: 'Duplicate')),
        const PopupMenuItem(
            value: 'split',
            height: 40,
            child: _Row(
                icon: Icons.vertical_split_outlined,
                label: 'Open in split view')),
        const PopupMenuDivider(),
        const PopupMenuItem(
            value: 'group',
            height: 40,
            child: _Row(icon: Icons.folder_outlined, label: 'Add to group…')),
        if (tab.groupId != null)
          const PopupMenuItem(
              value: 'ungroup',
              height: 40,
              child: _Row(icon: Icons.folder_off_outlined, label: 'Remove from group')),
        const PopupMenuDivider(),
        const PopupMenuItem(
            value: 'close',
            height: 40,
            child: _Row(icon: Icons.close_rounded, label: 'Close tab')),
        const PopupMenuItem(
            value: 'others',
            height: 40,
            child: _Row(icon: Icons.tab_rounded, label: 'Close other tabs')),
        const PopupMenuItem(
            value: 'right',
            height: 40,
            child: _Row(
                icon: Icons.keyboard_tab_rounded, label: 'Close tabs to the right')),
      ],
    );
    if (!context.mounted) return;
    switch (action) {
      case 'new':
        browser.newTab();
      case 'duplicate':
        browser.duplicateTab(tab);
      case 'split':
        browser.openSplit(tab: tab);
      case 'group':
        await _pickGroup(context, browser, tab);
      case 'ungroup':
        browser.setTabGroup(tab, null);
      case 'close':
        browser.closeTab(tab);
      case 'others':
        browser.closeOthers(tab);
      case 'right':
        browser.closeToTheRight(tab);
    }
  }

  Future<void> _pickGroup(
    BuildContext context,
    BrowserProvider browser,
    BrowserTab tab,
  ) async {
    final palette = pal(context);
    final name = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d2, setD) => SimpleDialog(
          title: const Text('Add tab to group'),
          backgroundColor: palette.surface,
          children: [
            for (final g in browser.groups)
              SimpleDialogOption(
                onPressed: () {
                  browser.setTabGroup(tab, g.id);
                  Navigator.of(d2).pop();
                },
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Color(g.colorValue),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${g.name} (${browser.tabsInGroup(g.id).length})',
                        style: TextStyle(color: palette.text),
                      ),
                    ),
                    if (tab.groupId == g.id)
                      Icon(Icons.check_rounded, size: 16, color: palette.accent),
                  ],
                ),
              ),
            if (browser.groups.isNotEmpty) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        isDense: true,
                        hintText: 'New group name',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    icon: const Icon(Icons.add_rounded, size: 19),
                    onPressed: () {
                      final g = browser.newGroup(
                        name.text.trim().isEmpty ? 'Group' : name.text.trim(),
        browser.groups.length % TabGroup.colors.length,
                      );
                      browser.setTabGroup(tab, g.id);
                      Navigator.of(d2).pop();
                    },
                  ),
                ],
              ),
            ),
            if (tab.groupId != null)
              SimpleDialogOption(
                onPressed: () {
                  browser.setTabGroup(tab, null);
                  Navigator.of(d2).pop();
                },
                child: Row(
                  children: [
                    Icon(Icons.folder_off_outlined,
                        size: 17, color: palette.textDim),
                    const SizedBox(width: 10),
                    Text('No group',
                        style: TextStyle(color: palette.textDim)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    name.dispose();
  }
}

class _StripEntry {
  const _StripEntry(this.tab);
  final BrowserTab tab;
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.textDim),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: palette.text)),
      ],
    );
  }
}

class _ChromeTab extends StatefulWidget {
  const _ChromeTab({
    super.key,
    required this.tab,
    required this.group,
    required this.selected,
    required this.isSplit,
    required this.onSelect,
    required this.onClose,
    required this.onSecondaryTap,
  });

  final BrowserTab tab;
  final TabGroup? group;
  final bool selected;
  final bool isSplit;
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
    final browser = context.watch<BrowserProvider>();
    final w = widget.selected;
    final group = widget.group;
    final groupColor = group == null ? null : Color(group.colorValue);

    Widget tabWidget = GestureDetector(
      onTertiaryTapUp: (_) => widget.onClose(),
      child: InkWell(
        onTap: widget.onSelect,
        onSecondaryTapUp: (d) => widget.onSecondaryTap(d.globalPosition),
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
            border: Border(
              top: BorderSide(
                color: groupColor ?? Colors.transparent,
                width: group == null ? 0 : 2.5,
              ),
            ),
          ),
          child: Row(
            children: [
              if (widget.tab.incognito)
                Icon(Icons.shield_rounded, size: 14, color: palette.accent)
              else if (widget.tab.onSpeedDial)
                Icon(Icons.add_rounded, size: 14, color: palette.textDim)
              else
                Favicon(
                    host: widget.tab.host,
                    url: widget.tab.faviconUrl,
                    size: 15),
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
              if (widget.isSplit)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(Icons.vertical_split_rounded,
                      size: 13, color: palette.accent),
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
                    color:
                        _hovering || w ? palette.textDim : Colors.transparent,
                  ),
                  onPressed: widget.onClose,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (group == null) return tabWidget;

    final count = browser.tabsInGroup(group.id).length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        tabWidget,
        InkWell(
          onTap: () => browser.toggleGroupCollapse(group.id),
          onSecondaryTapUp: (d) => widget.onSecondaryTap(d.globalPosition),
          child: Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: groupColor?.withValues(alpha: 0.18) ??
                  Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: groupColor ?? Colors.transparent),
            ),
            child: Row(
              children: [
                Icon(
                  browser.collapsedGroups.contains(group.id)
                      ? Icons.keyboard_arrow_right_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 15,
                  color: groupColor,
                ),
                const SizedBox(width: 3),
                Text(
                  '${group.name} · $count',
                  style: TextStyle(
                    color: groupColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
