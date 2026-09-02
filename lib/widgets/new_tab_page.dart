import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'icons.dart';

import '../core/pal.dart';
import '../core/ui.dart';
import '../core/urls.dart';
import '../models.dart';
import '../pages/bookmarks_page.dart';
import '../pages/history_page.dart';
import '../state/browser_provider.dart';
import '../state/profile_provider.dart';
import '../state/settings_provider.dart';
import 'favicon.dart';
import 'logo.dart';

/// The page a fresh tab opens to: a greeting, one search field, and your
/// shortcuts (with folders and drag-to-reorder).
class NewTabPage extends StatefulWidget {
  const NewTabPage({super.key, required this.tab});

  final BrowserTab tab;

  @override
  State<NewTabPage> createState() => _NewTabPageState();
}

class _NewTabPageState extends State<NewTabPage> {
  final _search = TextEditingController();
  Timer? _clock;
  String? _openFolder;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _search.dispose();
    super.dispose();
  }

  String get _greetingWord {
    final h = DateTime.now().hour;
    if (h < 5) return 'Still up';
    if (h < 12) return 'Good morning';
    if (h < 18) return 'Good afternoon';
    return 'Good evening';
  }

  void _go(String value) {
    if (value.trim().isEmpty) return;
    context.read<BrowserProvider>().navigate(value);
  }

  void _openLibrary(BuildContext context, SidePanel panel, Widget route) {
    final browser = context.read<BrowserProvider>();
    if (MediaQuery.sizeOf(context).width >= 840) {
      browser.setSidePanel(panel);
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => route));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    final settings = context.watch<SettingsProvider>();
    final profile = context.watch<ProfileProvider>();
    final wallpaper = settings.hasCustomBackground;

    final date = DateFormatE.format(DateTime.now());

    final folder = _openFolder == null
        ? null
        : profile.dialFolders
            .where((f) => f.id == _openFolder)
            .firstOrNull;
    final items = profile.dialItemsIn(_openFolder);

    return Container(
      color: wallpaper ? Colors.transparent : palette.background,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 780),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      if (widget.tab.incognito)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: palette.surface.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: palette.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              uiGlyph('shield-on',
                                  size: 16, color: palette.accent),
                              const SizedBox(width: 8),
                              Text(
                                'Private tab — nothing is saved here',
                                style: TextStyle(
                                    color: palette.text, fontSize: 12.5),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const LogoMark(size: 28),
                            const SizedBox(width: 10),
                            Text(
                              'Interface',
                              style: Ui.text(
                                palette,
                                size: 16,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '$_greetingWord  ·  $date',
                          textAlign: TextAlign.center,
                          style: Ui.text(
                            palette,
                            size: Ui.sizeTitle,
                            color: palette.textDim,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: TextField(
                          controller: _search,
                          textInputAction: TextInputAction.search,
                          onSubmitted: _go,
                          style: Ui.text(palette, size: 15, color: palette.text),
                          cursorColor: palette.accent,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: wallpaper
                                ? palette.surface.withValues(alpha: 0.9)
                                : palette.omniboxFill,
                            hintText: 'Search or type an address',
                            hintStyle: Ui.text(
                                palette, size: 14.5, color: palette.textDim),
                            prefixIcon: uiGlyph('search',
                                color: palette.textDim),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 15),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(Ui.rCard),
                              borderSide: BorderSide(color: palette.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(Ui.rCard),
                              borderSide: BorderSide(color: palette.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(Ui.rCard),
                              borderSide: BorderSide(
                                  color: palette.accent, width: 1.4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          if (folder != null) ...[
                            InkWell(
                              onTap: () => setState(() => _openFolder = null),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Row(children: [
                                  uiGlyph('back',
                                      size: 13, color: palette.accent),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Shortcuts',
                                    style: Ui.text(palette,
                                        size: Ui.sizeSmall,
                                        color: palette.accent),
                                  ),
                                ]),
                              ),
                            ),
                            const SizedBox(width: 6),
                            uiGlyph('chevron-right',
                                size: 15, color: palette.textDim),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            folder?.name ?? 'Shortcuts',
                            style: Ui.text(
                              palette,
                              size: Ui.sizeTitle,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (items.isNotEmpty)
                            Text(
                              '${items.length}',
                              style: Ui.text(palette,
                                  size: Ui.sizeCaption, color: palette.textDim),
                            ),
                          const Spacer(),
                          if (folder != null)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: uiGlyph('pencil',
                                  size: 16, color: palette.textDim),
                              tooltip: 'Rename folder',
                              onPressed: () => _editFolder(context, folder),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _DialGrid(
                        items: items,
                        folders: _openFolder == null ? profile.dialFolders : const [],
                        onTapItem: (item) => _go(item.url),
                        onItemLongPress: _tileActions,
                        onAddTap: () => _editItem(null),
                        onAddFolder: _openFolder == null
                            ? () => _newFolder(context)
                            : null,
                        onFolderTap: (f) => setState(() => _openFolder = f.id),
                        onFolderLongPress: _folderActions,
                        onReorder: (oldIndex, newIndex) =>
                            profile.reorderDial(oldIndex, newIndex, _openFolder),
                      ),
                      const SizedBox(height: 26),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _QuickLink(
                            icon: 'star-on',
                            label: 'Bookmarks',
                            onTap: () => _openLibrary(context,
                                SidePanel.bookmarks, const BookmarksRoute()),
                          ),
                          const SizedBox(width: 22),
                          _QuickLink(
                            icon: 'clock',
                            label: 'History',
                            onTap: () => _openLibrary(context,
                                SidePanel.history, const HistoryRoute()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _editFolder(BuildContext context, SpeedDialFolder folder) {
    final profile = context.read<ProfileProvider>();
    final palette = pal(context);
    final name = TextEditingController(text: folder.name);
    showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Rename folder'),
        content: TextField(controller: name, autofocus: true),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: palette.accent),
            onPressed: () {
              profile.renameDialFolder(folder, name.text.trim());
              Navigator.of(d).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _newFolder(BuildContext context) async {
    final profile = context.read<ProfileProvider>();
    final palette = pal(context);
    final name = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('New folder'),
        content: TextField(
          controller: name,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Work, Social…'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(d).pop(),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: palette.accent),
            onPressed: () {
              profile.addDialFolder(name.text.trim());
              Navigator.of(d).pop();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    name.dispose();
  }

  void _folderActions(SpeedDialFolder folder) {
    final profile = context.read<ProfileProvider>();
    final palette = pal(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: uiGlyph('pencil'),
              title: const Text('Rename'),
              onTap: () {
                Navigator.of(sheet).pop();
                _editFolder(context, folder);
              },
            ),
            ListTile(
              leading: uiGlyph('trash'),
              title: Text(
                  'Delete folder'),
              onTap: () {
                profile.deleteDialFolder(folder);
                setState(() => _openFolder = null);
                Navigator.of(sheet).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _tileActions(SpeedDialItem item) {
    final profile = context.read<ProfileProvider>();
    final palette = pal(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: uiGlyph('external'),
              title: const Text('Open'),
              onTap: () {
                Navigator.of(sheet).pop();
                _go(item.url);
              },
            ),
            ListTile(
              leading: uiGlyph('pencil'),
              title: const Text('Edit'),
              onTap: () {
                Navigator.of(sheet).pop();
                _editItem(item);
              },
            ),
            ListTile(
              leading: uiGlyph('folder'),
              title: const Text('Move to folder…'),
              onTap: () {
                Navigator.of(sheet).pop();
                _moveToFolder(item);
              },
            ),
            ListTile(
              leading: uiGlyph('trash'),
              title: const Text('Remove'),
              onTap: () {
                profile.removeSpeedDial(item);
                Navigator.of(sheet).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _moveToFolder(SpeedDialItem item) {
    final profile = context.read<ProfileProvider>();
    final palette = pal(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const SizedBox(height: 6),
            ListTile(
              leading: uiGlyph('dial'),
              title: const Text('All shortcuts'),
              onTap: () {
                profile.updateSpeedDial(item, clearFolder: true);
                Navigator.of(sheet).pop();
              },
            ),
            for (final f in profile.dialFolders)
              ListTile(
                leading: uiGlyph('folder', color: palette.accent),
                title: Text(f.name),
                onTap: () {
                  profile.updateSpeedDial(item, folderId: f.id);
                  Navigator.of(sheet).pop();
                },
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Future<void> _editItem(SpeedDialItem? item) async {
    final profile = context.read<ProfileProvider>();
    final title = TextEditingController(text: item?.title ?? '');
    final url = TextEditingController(text: item?.url ?? 'https://');
    final palette = pal(context);

    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(item == null ? 'Add to speed dial' : 'Edit tile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              autofocus: item == null,
              decoration: const InputDecoration(
                labelText: 'Name',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: url,
              decoration: const InputDecoration(
                labelText: 'Address',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: palette.accent),
            onPressed: () {
              final u = urlFromInput(url.text);
              if (u == null) return;
              final nice = u.toString();
              if (item == null) {
                profile.addSpeedDial(
                  title: title.text.trim().isEmpty
                      ? hostOf(nice)
                      : title.text.trim(),
                  url: nice,
                  folderId: _openFolder,
                );
              } else {
                profile.updateSpeedDial(
                  item,
                  title: title.text.trim(),
                  url: nice,
                );
              }
              Navigator.of(d).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    title.dispose();
    url.dispose();
  }
}

/// Wrap grid with tiles + folders + drag-to-reorder.
class _DialGrid extends StatelessWidget {
  const _DialGrid({
    required this.items,
    required this.folders,
    required this.onTapItem,
    required this.onItemLongPress,
    required this.onAddTap,
    required this.onAddFolder,
    required this.onFolderTap,
    required this.onFolderLongPress,
    required this.onReorder,
  });

  final List<SpeedDialItem> items;
  final List<SpeedDialFolder> folders;
  final void Function(SpeedDialItem) onTapItem;
  final void Function(SpeedDialItem) onItemLongPress;
  final VoidCallback onAddTap;
  final VoidCallback? onAddFolder;
  final void Function(SpeedDialFolder) onFolderTap;
  final void Function(SpeedDialFolder) onFolderLongPress;
  final void Function(int, int) onReorder;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return ScopeInfo(
      items: items,
      child: Wrap(
      spacing: 14,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 0; i < items.length; i++)
          _DraggableTile(
            index: i,
            item: items[i],
            palette: palette,
            onReorder: onReorder,
            onTap: () => onTapItem(items[i]),
            onLongPress: () => onItemLongPress(items[i]),
          ),
        for (final f in folders)
          _FolderTile(
            folder: f,
            palette: palette,
            onTap: () => onFolderTap(f),
            onLongPress: () => onFolderLongPress(f),
          ),
        _AddDialTile(palette: palette, onTap: onAddTap),
        if (onAddFolder != null)
          _AddFolderTile(palette: palette, onTap: onAddFolder!),
      ],
      ),
    );
  }
}

class _DraggableTile extends StatelessWidget {
  const _DraggableTile({
    required this.index,
    required this.item,
    required this.palette,
    required this.onReorder,
    required this.onTap,
    required this.onLongPress,
  });

  final int index;
  final SpeedDialItem item;
  final BrowserPalette palette;
  final void Function(int, int) onReorder;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final tile = _DialTile(
      item: item,
      palette: palette,
      onTap: onTap,
      onLongPress: onLongPress,
    );
    return DragTarget<SpeedDialItem>(
      onWillAcceptWithDetails: (d) => d.data.id != item.id,
      onAccept: (dragged) {
        // Find indices in the current visible list.
        final scope = ScopeInfo.of(context);
        final items = scope.items;
        final from = items.indexWhere((e) => e.id == dragged.id);
        final to = items.indexWhere((e) => e.id == item.id);
        if (from >= 0 && to >= 0) onReorder(from, to);
      },
      builder: (context, accepted, rejected) {
        final hovering = accepted.isNotEmpty;
        return LongPressDraggable<SpeedDialItem>(
          data: item,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(opacity: 0.75, child: tile),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: tile),
          child: hovering
              ? Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.accent, width: 1.5),
                  ),
                  child: tile,
                )
              : tile,
        );
      },
    );
  }
}

/// Inherited widget exposing the visible item list to drag targets.
class ScopeInfo extends InheritedWidget {
  const ScopeInfo({
    super.key,
    required this.items,
    required super.child,
  });

  final List<SpeedDialItem> items;

  static ScopeInfo of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ScopeInfo>()!;

  @override
  bool updateShouldNotify(ScopeInfo old) => !identical(old.items, items);
}

class _DialTile extends StatelessWidget {
  const _DialTile({
    required this.item,
    required this.palette,
    required this.onTap,
    required this.onLongPress,
  });

  final SpeedDialItem item;
  final BrowserPalette palette;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(Ui.rCard),
                border: Border.all(color: palette.border),
              ),
              child: Favicon(host: hostOf(item.url), size: 30),
            ),
            const SizedBox(height: 7),
            Text(
              item.title.isEmpty ? hostOf(item.url) : item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Ui.text(palette, size: Ui.sizeCaption + 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.folder,
    required this.palette,
    required this.onTap,
    required this.onLongPress,
  });

  final SpeedDialFolder folder;
  final BrowserPalette palette;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final count = profile.dialItemsIn(folder.id).length;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    palette.primary.withValues(alpha: 0.9),
                    palette.primary.withValues(alpha: 0.55),
                  ],
                ),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: palette.border),
              ),
              child: uiGlyph('folder',
                  size: 28, color: palette.accent),
            ),
            const SizedBox(height: 7),
            Text(
              folder.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$count sites',
              style: TextStyle(color: palette.textDim, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddDialTile extends StatelessWidget {
  const _AddDialTile({required this.palette, required this.onTap});

  final BrowserPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.surfaceAlt.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: palette.border),
              ),
              child: uiGlyph('plus', size: 26, color: palette.textDim),
            ),
            const SizedBox(height: 7),
            Text(
              'Add site',
              style: TextStyle(color: palette.textDim, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddFolderTile extends StatelessWidget {
  const _AddFolderTile({required this.palette, required this.onTap});

  final BrowserPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.surfaceAlt.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: palette.border),
              ),
              child:
                  uiGlyph('folder-plus',
                      size: 24, color: palette.textDim),
            ),
            const SizedBox(height: 7),
            Text(
              'Folder',
              style: TextStyle(color: palette.textDim, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Object icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            uiGlyph(icon, size: 21, color: palette.accent),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: palette.textDim, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Weekday, Month day — kept here to avoid an intl dependency.
class DateFormatE {
  static const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String format(DateTime d) =>
      '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
}
