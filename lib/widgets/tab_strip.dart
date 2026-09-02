import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'icons.dart';

import '../core/pal.dart';
import '../core/ui.dart';
import '../models.dart';
import '../state/browser_provider.dart';
import 'favicon.dart';
import 'ui_kit.dart';

/// Tabs live in the bar as compact pills: icon, title, close.
/// Selected = lifted surface with a 2px accent underline, groups = a colour
/// dot you can click to collapse the rest of the group.
class TabStrip extends StatelessWidget {
  const TabStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();

    final visible = <BrowserTab>[
      for (final tab in browser.tabs)
        if (!browser.collapsedGroups.contains(tab.groupId ?? '') ||
            tab.id == browser.current.id ||
            tab.id == browser.splitTabId)
          tab,
    ];

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: false,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                for (final tab in visible)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _TabPill(
                      key: ValueKey(tab.id),
                      tab: tab,
                      group: browser.groupOf(tab),
                      selected: tab.id == browser.current.id,
                      isSplit: tab.id == browser.splitTabId,
                      onSelect: () => browser.selectTab(tab),
                      onClose: () => browser.closeTab(tab),
                      onMenu: (offset) => _showMenu(context, tab, offset),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Ui.gap(2),
        UiIconButton(
          icon: 'plus',
          tooltip: 'New tab (Ctrl+T)',
          onTap: () => browser.newTab(),
        ),
      ],
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
          height: Ui.menuRowHeight,
          child: _MenuRow(icon: 'plus', label: 'New tab to the right'),
        ),
        const PopupMenuItem(
          value: 'duplicate',
          height: Ui.menuRowHeight,
          child: _MenuRow(icon: 'copy', label: 'Duplicate'),
        ),
        const PopupMenuItem(
          value: 'split',
          height: Ui.menuRowHeight,
          child: _MenuRow(
            icon: 'split',
            label: 'Open in split view',
          ),
        ),
        const PopupMenuItem(
          value: 'pin',
          height: Ui.menuRowHeight,
          child: _MenuRow(icon: 'pin', label: 'Keep this tab'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'group',
          height: Ui.menuRowHeight,
          child: const _MenuRow(
            icon: 'folder',
            label: 'Add to group…',
          ),
        ),
        if (tab.groupId != null)
          const PopupMenuItem(
            value: 'ungroup',
            height: Ui.menuRowHeight,
            child: _MenuRow(
              icon: 'folder-block',
              label: 'Remove from group',
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'close',
          height: Ui.menuRowHeight,
          child: _MenuRow(icon: 'close', label: 'Close tab'),
        ),
        const PopupMenuItem(
          value: 'others',
          height: Ui.menuRowHeight,
          child: _MenuRow(icon: 'tab', label: 'Close other tabs'),
        ),
        const PopupMenuItem(
          value: 'right',
          height: Ui.menuRowHeight,
          child: _MenuRow(
            icon: 'keyboard',
            label: 'Close tabs to the right',
          ),
        ),
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
          backgroundColor: palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Ui.rSheet),
            side: BorderSide(color: palette.border),
          ),
          title: Text(
            'Add tab to a group',
            style: Ui.text(palette, size: Ui.sizeTitle, weight: FontWeight.w700),
          ),
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
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: Color(g.colorValue),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${g.name}  (${browser.tabsInGroup(g.id).length})',
                        style: Ui.text(palette),
                      ),
                    ),
                    if (tab.groupId == g.id)
                      uiGlyph('check',
                          size: 16, color: palette.accent),
                  ],
                ),
              ),
            if (browser.groups.isNotEmpty) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: name,
                      style: Ui.text(palette),
                      decoration: InputDecoration(
                        isDense: true,
                        isCollapsed: false,
                        hintText: 'New group name',
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  UiButton(
                    label: 'Create',
                    filled: true,
                    onTap: () {
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
                    uiGlyph('folder-block',
                        size: 16, color: palette.textDim),
                    const SizedBox(width: 10),
                    Text('No group', style: Ui.text(palette, color: palette.textDim)),
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

/// Narrow-bar fallback: one pill that says how many tabs are open and opens
/// the grid switcher.
class TabCountButton extends StatelessWidget {
  const TabCountButton({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Tooltip(
      message: 'All tabs',
      child: UiHoverable(
        onTap: onTap,
        builder: (context, hovering, pressed) => AnimatedContainer(
          duration: Ui.quick,
          curve: Ui.curve,
          height: Ui.tabHeight,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: hovering || pressed ? p.hoverFill : Colors.transparent,
            borderRadius: BorderRadius.circular(Ui.rField),
            border: Border.all(color: p.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              uiGlyph('grid', size: 15, color: p.textDim),
              Ui.gap(7),
              Text('$count', style: Ui.text(p, weight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final Object icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return Row(
      children: [
        uiGlyph(icon, size: 17, color: palette.textDim),
        const SizedBox(width: 11),
        Text(label, style: Ui.text(palette)),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    super.key,
    required this.tab,
    required this.group,
    required this.selected,
    required this.isSplit,
    required this.onSelect,
    required this.onClose,
    required this.onMenu,
  });

  final BrowserTab tab;
  final TabGroup? group;
  final bool selected;
  final bool isSplit;
  final VoidCallback onSelect;
  final VoidCallback onClose;
  final void Function(Offset globalPosition) onMenu;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final browser = context.read<BrowserProvider>();
    final groupColor = group == null ? null : Color(group!.colorValue);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 96, maxWidth: 208),
      child: UiHoverable(
        onTap: () {
          // Keep the tab you picked in view.
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: Ui.normal,
            curve: Ui.curve,
          );
          onSelect();
        },
        builder: (context, hovering, pressed) {
          return GestureDetector(
            onTertiaryTapUp: (_) => onClose(),
            onSecondaryTapUp: (d) => onMenu(d.globalPosition),
            child: AnimatedContainer(
              duration: Ui.quick,
              curve: Ui.curve,
              height: Ui.tabHeight,
              padding: const EdgeInsets.only(left: 9, right: 4),
              decoration: BoxDecoration(
                color: selected
                    ? p.surface
                    : (pressed
                        ? p.activeFill
                        : (hovering ? p.hoverFill : Colors.transparent)),
                borderRadius: BorderRadius.circular(Ui.rField),
                border: Border.all(
                  color: groupColor?.withValues(alpha: 0.5) ??
                      (selected ? p.border : Colors.transparent),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (groupColor != null)
                    Tooltip(
                      message: '${group!.name} — click to '
                          '${browser.collapsedGroups.contains(group!.id) ? 'expand' : 'collapse'}',
                      child: GestureDetector(
                        onTap: () =>
                            browser.toggleGroupCollapse(group!.id),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 7, left: 1),
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: groupColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (tab.loading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: p.accent,
                        value: tab.progress > 0 ? tab.progress / 100 : null,
                      ),
                    )
                  else if (tab.incognito)
                    uiGlyph('shield-on', size: 14, color: p.accent)
                  else if (tab.onSpeedDial)
                    uiGlyph('plus', size: 14, color: p.textDim)
                  else
                    Favicon(host: tab.host, url: tab.faviconUrl, size: 15),
                  const SizedBox(width: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 132),
                    child: Text(
                      tab.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ui.text(
                        p,
                        size: 12.5,
                        weight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected ? p.text : p.textDim,
                      ),
                    ),
                  ),
                  if (isSplit)
                    Padding(
                      padding: const EdgeInsets.only(right: 2),
                      child: uiGlyph('split',
                          size: 13, color: p.accent),
                    ),
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      splashRadius: 11,
                      tooltip: 'Close tab (Ctrl+W)',
                      icon: uiGlyph(
                        'close',
                        size: 13,
                        color: hovering || selected ? p.textDim : Colors.transparent,
                      ),
                      onPressed: onClose,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
