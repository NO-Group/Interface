import 'dart:io' show Platform, Process;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../core/ui.dart';
import '../services/file_manager.dart';
import '../state/browser_provider.dart';
import '../state/files_provider.dart';
import '../widgets/icons.dart';
import '../widgets/ui_kit.dart';

/// Files — browse the device, make folders, move things around.
///
/// Embeds in the desktop side panel and opens full-screen from the menu.
class FilesPage extends StatelessWidget {
  const FilesPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final files = context.watch<FilesProvider>();
    return Column(
      children: [
        _FilesBar(files: files, embedded: embedded),
        if (files.hasClip || files.places.isNotEmpty || files.favourites.isNotEmpty)
          _PlacesBar(files: files),
        if (files.selecting) _SelectionBar(files: files),
        Expanded(child: _FilesBody(files: files)),
      ],
    );
  }
}

// ---------------------------------------------------------------------- bar
class _FilesBar extends StatefulWidget {
  const _FilesBar({required this.files, this.embedded = false});

  final FilesProvider files;
  final bool embedded;

  @override
  State<_FilesBar> createState() => _FilesBarState();
}

class _FilesBarState extends State<_FilesBar> {
  late final TextEditingController _query =
      TextEditingController(text: widget.files.query);
  bool _searching = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final files = widget.files;
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: p.chromeFill,
        border: Border(bottom: BorderSide(color: p.hairline)),
      ),
      child: Row(
        children: [
          UiIconButton(
            icon: 'back',
            tooltip: 'Back',
            iconSize: 16,
            onTap: files.canBack ? () => files.back() : null,
          ),
          UiIconButton(
            icon: 'forward',
            tooltip: 'Forward',
            iconSize: 16,
            onTap: files.canForward ? () => files.forward() : null,
          ),
          UiIconButton(
            icon: 'up',
            tooltip: 'One folder up',
            iconSize: 16,
            onTap: files.canUp ? () => files.up() : null,
          ),
          UiIconButton(
            icon: 'reload',
            tooltip: 'Show again',
            iconSize: 16,
            onTap: files.refresh,
          ),
          Ui.gap(4),
          Expanded(child: _searching ? _field(p, files) : _crumbs(p, files)),
          UiIconButton(
            icon: 'search',
            tooltip: 'Find in this folder',
            iconSize: 17,
            selected: _searching,
            onTap: () {
              setState(() => _searching = !_searching);
              if (!_searching) files.setQuery('');
            },
          ),
          UiIconButton(
            icon: 'grid',
            tooltip: files.grid ? 'As a list' : 'As tiles',
            iconSize: 17,
            selected: files.grid,
            onTap: files.toggleGrid,
          ),
          UiIconButton(
            icon: 'sort',
            tooltip: 'Sorting',
            iconSize: 17,
            onTap: () => _sortMenu(context, files),
          ),
          UiIconButton(
            icon: 'menu',
            tooltip: 'More',
            iconSize: 17,
            onTap: () => _moreMenu(context, files, embedded: widget.embedded),
          ),
        ],
      ),
    );
  }

  Widget _crumbs(BrowserPalette p, FilesProvider files) {
    final steps = stepsOf(files.dir, s: files.s);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Ico('chevron-right', size: 12, color: p.textFaint, opacity: 0.7),
            UiChip(
              label: steps[i].label.isEmpty ? 'This folder' : steps[i].label,
              onTap: () => files.goTo(steps[i].path),
            ),
          ],
          if (steps.isEmpty)
            Text('Files', style: Ui.text(p, size: Ui.sizeSmall)),
        ],
      ),
    );
  }

  Widget _field(BrowserPalette p, FilesProvider files) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: TextField(
        controller: _query,
        autofocus: true,
        style: Ui.text(p, size: Ui.sizeSmall),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Find in this folder',
          hintStyle: Ui.caption(p, color: p.textFaint),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 8, right: 6),
            child: Ico('search', size: 15, color: p.textDim),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          suffixIcon: _query.text.isEmpty
              ? null
              : IconButton(
                  icon: Ico('close', size: 14, color: p.textDim),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _query.clear();
                    files.setQuery('');
                    setState(() {});
                  },
                ),
          suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          filled: true,
          fillColor: p.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: Ui.radius(Ui.rField),
            borderSide: BorderSide(color: p.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: Ui.radius(Ui.rField),
            borderSide: BorderSide(color: p.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: Ui.radius(Ui.rField),
            borderSide: BorderSide(color: p.accent, width: 1.4),
          ),
        ),
        onChanged: (v) {
          files.setQuery(v);
          setState(() {});
        },
      ),
    );
  }

  Future<void> _sortMenu(BuildContext context, FilesProvider files) async {
    await showFilesSheet(
      context,
      title: 'Show folders and files',
      rows: [
        for (final s in FileSort.values)
          FilesSheetRow(
            label: switch (s) {
              FileSort.name => 'By name',
              FileSort.newest => 'Newest first',
              FileSort.largest => 'Largest first',
              FileSort.type => 'By kind',
            },
            icon: 'sort',
            checked: files.sort == s,
            onTap: () => files.setSort(s),
          ),
        FilesSheetRow(
          label: files.ascending ? 'Reverse the order' : 'Put it back',
          icon: 'arrow-up',
          onTap: files.toggleDirection,
        ),
        FilesSheetRow(
          label: files.showHidden ? 'Hide the hidden ones' : 'Show hidden files',
          icon: 'eye',
          onTap: files.toggleHidden,
        ),
      ],
    );
  }

  Future<void> _moreMenu(
      BuildContext context, FilesProvider files, {required bool embedded}) async {
    await showFilesSheet(
      context,
      title: files.folderName,
      rows: [
        FilesSheetRow(
          label: 'New folder',
          icon: 'folder-plus',
          onTap: () async {
            final name = await askName(
              context,
              title: 'Name this folder',
              initial: 'New folder',
            );
            if (name != null) await files.newFolder(name);
          },
        ),
        FilesSheetRow(
          label: 'New file',
          icon: 'file',
          onTap: () async {
            final name = await askName(
              context,
              title: 'Name this file',
              initial: 'Untitled.txt',
            );
            if (name != null) await files.newFile(name);
          },
        ),
        FilesSheetRow(
          label: files.favourites.contains(files.dir)
              ? 'Remove from your places'
              : 'Keep this folder',
          icon: 'pin',
          onTap: files.toggleFavourite,
        ),
        FilesSheetRow(
          label: 'Open a folder by name',
          icon: 'folder-open',
          onTap: () async {
            final path = await askName(
              context,
              title: 'Which folder?',
              initial: files.dir,
              message: 'Type a folder address, or paste one you copied.',
            );
            if (path != null) await files.openPath(path);
          },
        ),
        if (files.hasClip)
          FilesSheetRow(
            label: 'Put the copied things here',
            icon: 'paste',
            onTap: files.paste,
          ),
        FilesSheetRow(
          label: 'This device',
          icon: 'drive',
          onTap: () async {
            final roots = await files.fs.driveRoots();
            if (!context.mounted) return;
            await showFilesSheet(
              context,
              title: 'This device',
              rows: [
                for (final r in roots)
                  FilesSheetRow(
                    label: r == '/' ? 'This computer' : r,
                    icon: 'drive',
                    onTap: () => files.goTo(r),
                  ),
              ],
            );
          },
        ),
        if (!embedded)
          FilesSheetRow(label: 'Close', icon: 'close', onTap: () => Navigator.pop(context)),
      ],
    );
  }
}

// ------------------------------------------------------------- places strip
class _PlacesBar extends StatelessWidget {
  const _PlacesBar({required this.files});

  final FilesProvider files;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final pinned = <PathStep>[
      for (final f in files.favourites) PathStep(f, baseName(f, s: files.s)),
    ];
    final places = [...pinned, ...files.places];
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.hairline))),
      child: Row(
        children: [
          if (files.hasClip) ...[
            UiChip(
              label: files.clip == FileClip.move
                  ? '${files.clipPaths.length} to move'
                  : '${files.clipPaths.length} to copy',
              leading: Ico(files.clip == FileClip.move ? 'move' : 'copy',
                  size: 14, color: p.accent),
              onTap: files.paste,
              onClose: () => files.take(FileClip.copy, const []),
            ),
            Ui.gap(8),
          ],
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: places.length,
              itemBuilder: (_, i) {
                final s = places[i];
                final fav = files.favourites.contains(s.path);
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: UiChip(
                    label: s.label.isEmpty ? s.path : s.label,
                    selected: s.path == files.dir,
                    leading: Ico(fav ? 'pin' : 'folder',
                        size: 13, color: fav ? p.accent : p.textDim),
                    onTap: () => files.goTo(s.path),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- selection bar
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.files});

  final FilesProvider files;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final paths = files.selected.toList(growable: false);
    final single = paths.length == 1
        ? files.nodes.where((n) => n.path == paths.first).toList()
        : const <FileNode>[];
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: p.accentSoft,
        border: Border(bottom: BorderSide(color: p.hairline)),
      ),
      child: Row(
        children: [
          Ico('check-circle', size: 16, color: p.accent),
          Ui.gap(8),
          Flexible(
            child: Text('${Ui.count(paths.length)} selected',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Ui.text(p,
                    size: Ui.sizeSmall, weight: FontWeight.w600)),
          ),
          const Spacer(),
          if (single.isNotEmpty)
            UiIconButton(
              icon: 'pencil',
              tooltip: 'Rename',
              size: 32,
              iconSize: 16,
              onTap: () async {
                final name = await askName(context,
                    title: 'Name this ${single.first.isDir ? 'folder' : 'file'}',
                    initial: single.first.name);
                if (name != null) await files.rename(single.first, name);
              },
            ),
          UiIconButton(
            icon: 'copy',
            tooltip: 'Copy these',
            size: 32,
            iconSize: 16,
            onTap: () => files.take(FileClip.copy, paths),
          ),
          UiIconButton(
            icon: 'move',
            tooltip: 'Move these to…',
            size: 32,
            iconSize: 16,
            onTap: () async {
              final dest = await pickFolder(context, files);
              if (dest != null) await files.moveTo(dest);
            },
          ),
          UiIconButton(
            icon: 'trash',
            tooltip: 'Delete these',
            size: 32,
            iconSize: 16,
            onTap: () async {
              final ok = await confirmDelete(context, paths.length);
              if (ok == true) await files.remove(paths);
            },
          ),
          UiIconButton(
            icon: 'close',
            tooltip: 'Stop selecting',
            size: 32,
            iconSize: 15,
            onTap: files.clearSelection,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------- body
class _FilesBody extends StatelessWidget {
  const _FilesBody({required this.files});

  final FilesProvider files;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    if ((files.loading || !files.loaded) && files.nodes.isEmpty) {
      return const UiProgressLine(active: true);
    }
    final err = files.error;
    if (err != null && files.nodes.isEmpty) {
      return UiEmpty(
        icon: 'alert',
        title: 'This folder cannot be opened',
        message: err,
        actionLabel: 'Try again',
        onAction: files.refresh,
      );
    }
    if (files.nodes.isEmpty) {
      return UiEmpty(
        icon: 'folder',
        title: 'Nothing in here yet',
        message: files.query.isEmpty
            ? 'Put files in this folder, or make something new.'
            : 'No name in this folder matches “${files.query}”.',
        actionLabel: files.query.isEmpty ? 'New folder' : null,
        onAction: files.query.isEmpty
            ? () async {
                final name = await askName(context,
                    title: 'Name this folder', initial: 'New folder');
                if (name != null) await files.newFolder(name);
              }
            : null,
      );
    }

    if (files.grid) {
      return GridView.builder(
        padding: const EdgeInsets.all(10),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 132,
          childAspectRatio: 0.92,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: files.nodes.length,
        itemBuilder: (_, i) => _FileTile(node: files.nodes[i], files: files),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: files.nodes.length,
      itemBuilder: (_, i) {
        final n = files.nodes[i];
        final picking = files.selected.isNotEmpty;
        final isOn = files.selected.contains(n.path);
        return UiRow(
          dense: true,
          height: 44,
          selected: isOn,
          title: n.name,
          subtitle: _subtitle(n),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (picking)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Ico(isOn ? 'check-circle' : 'circle',
                      size: 17, color: isOn ? p.accent : p.textFaint),
                ),
              Ico(fileIconName(n.name, isDir: n.isDir),
                  size: 19,
                  color: n.canRead ? (n.isDir ? p.text : p.textDim) : p.textFaint),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!n.canRead) ...[
                Ico('lock', size: 14, color: p.textFaint),
                Ui.gap(8),
              ],
              if (n.isDir)
                Ico('chevron-right', size: 15, color: p.textFaint, opacity: .8)
              else
                Text(formatBytes(n.size), style: Ui.caption(p, color: p.textFaint)),
            ],
          ),
          onTap: () => picking
              ? files.toggleSelect(n.path)
              : openNode(context, files, n),
          onSecondaryTap: () => pick(context, files, n),
          onLongPress: () => pick(context, files, n),
        );
      },
    );
  }

  String _subtitle(FileNode n) {
    final when = formatWhen(n.modified);
    if (n.isDir) return n.canRead ? '$when · folder' : 'No access';
    final ext = n.extension.isEmpty ? 'file' : '${n.extension} file';
    return '$when · $ext';
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.node, required this.files});

  final FileNode node;
  final FilesProvider files;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final isOn = files.selected.contains(node.path);
    return UiHoverable(
      onTap: files.selected.isEmpty
          ? () => openNode(context, files, node)
          : () => files.toggleSelect(node.path),
      onSecondaryTap: () => pick(context, files, node),
      onLongPress: () => pick(context, files, node),
      builder: (context, hovering, pressed) => AnimatedContainer(
        duration: Ui.quick,
        curve: Ui.curve,
        decoration: BoxDecoration(
          color: isOn
              ? p.activeFill
              : (pressed
                  ? p.activeFill
                  : (hovering ? p.hoverFill : Colors.transparent)),
          borderRadius: Ui.radius(Ui.rCard),
          border: Border.all(color: isOn ? p.ring : p.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Ico(fileIconName(node.name, isDir: node.isDir),
                size: 30, color: node.isDir ? p.text : p.textDim),
            Ui.vgap(8),
            Text(
              node.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Ui.text(p, size: Ui.sizeCaption + 0.5),
            ),
            Ui.vgap(3),
            Text(
              node.isDir ? 'Folder' : formatBytes(node.size),
              style: Ui.caption(p, color: p.textFaint),
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- behaviour
Future<void> openNode(
    BuildContext context, FilesProvider files, FileNode node) async {
  if (node.isDir) {
    await files.goTo(node.path);
    return;
  }
  if (!context.mounted) return;
  await browserOpen(context, node.path);
}

/// Reading a file is done in a browser tab, so the tab is opened and the
/// sidebar steps aside to show it.
Future<void> browserOpen(BuildContext context, String path) async {
  final url = Uri.file(path).toString();
  final browser = context.read<BrowserProvider>();
  browser.newTab(url: url);
  browser.setSidePanel(SidePanel.none);
  if (context.mounted) Navigator.of(context).maybePop();
}

Future<void> pick(BuildContext context, FilesProvider files, FileNode node) async {
  final p = files;
  await showFilesSheet(
    context,
    title: node.name,
    caption: node.isDir
        ? 'Folder · ${formatWhen(node.modified)}'
        : '${formatBytes(node.size)} · ${formatWhen(node.modified)}',
    rows: [
      FilesSheetRow(
        label: node.isDir ? 'Open' : 'Read it in a tab',
        icon: node.isDir ? 'folder-open' : 'external',
        onTap: () => node.isDir
            ? files.goTo(node.path)
            : browserOpen(context, node.path),
      ),
      if (Platform.isLinux || Platform.isMacOS || Platform.isWindows)
        FilesSheetRow(
          label: 'Open with its usual app',
          icon: 'external',
          onTap: () => openWithSystem(node.path),
        ),
      FilesSheetRow(
        label: 'Rename',
        icon: 'pencil',
        onTap: () async {
          final name = await askName(context,
              title: 'Name this ${node.isDir ? 'folder' : 'file'}',
              initial: node.name);
          if (name != null) await p.rename(node, name);
        },
      ),
      FilesSheetRow(
        label: 'Copy',
        icon: 'copy',
        onTap: () => p.take(FileClip.copy, [node.path]),
      ),
      FilesSheetRow(
        label: 'Move this to…',
        icon: 'move',
        onTap: () async {
          final dest = await pickFolder(context, p);
          if (dest != null) await p.moveTo(dest);
        },
      ),
      FilesSheetRow(
        label: 'Copy this to…',
        icon: 'copy',
        onTap: () async {
          final dest = await pickFolder(context, p);
          if (dest != null) await p.copyTo(dest);
        },
      ),
      FilesSheetRow(
        label: 'Copy its address',
        icon: 'code',
        onTap: () => Clipboard.setData(ClipboardData(text: node.path)),
      ),
      FilesSheetRow(
        label: 'Delete',
        icon: 'trash',
        danger: true,
        onTap: () async {
          final ok = await confirmDelete(context, 1);
          if (ok == true) await p.remove([node.path]);
        },
      ),
    ],
  );
}

Future<void> openWithSystem(String path) async {
  final url = Uri.file(path).toString();
  try {
    if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', path]);
    } else if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    } else if (Platform.isAndroid) {
      await Process.run('am', ['start', '-a', 'android.intent.action.VIEW', url]);
    }
  } catch (_) {
    // Nothing to do here: the folder simply has no default app.
  }
}

/// Ask where to put the selection; returns the chosen folder.
Future<String?> pickFolder(BuildContext context, FilesProvider files) {
  return showDialog<String>(
    context: context,
    builder: (_) => _FolderPicker(files: files),
  );
}

Future<String?> askName(BuildContext context,
    {required String title, String initial = '', String? message}) async {
  final controller = TextEditingController(text: initial);
  final p = pal(context);
  final out = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: p.border),
        borderRadius: Ui.radius(Ui.rSheet),
      ),
      title: Text(title, style: Ui.text(p, size: Ui.sizeTitle, weight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message != null) ...[
            Text(message, style: Ui.caption(p, color: p.textDim)),
            Ui.vgap(10),
          ],
          TextField(
            controller: controller,
            autofocus: true,
            style: Ui.text(p, size: Ui.sizeBody),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: p.fieldFill,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: Ui.radius(Ui.rField),
                borderSide: BorderSide(color: p.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: Ui.radius(Ui.rField),
                borderSide: BorderSide(color: p.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: Ui.radius(Ui.rField),
                borderSide: BorderSide(color: p.accent, width: 1.4),
              ),
            ),
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: Ui.text(p, size: Ui.sizeSmall)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Name it'),
        ),
      ],
    ),
  );
  controller.dispose();
  return out == null || out.trim().isEmpty ? null : out.trim();
}

Future<bool?> confirmDelete(BuildContext context, int count) async {
  final p = pal(context);
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: p.border),
        borderRadius: Ui.radius(Ui.rSheet),
      ),
      title: Text(
        count == 1 ? 'Delete this?' : 'Delete $count things?',
        style: Ui.text(p, size: Ui.sizeTitle, weight: FontWeight.w700),
      ),
      content: Text(
        'They go away for good — this does not go through a trash folder.',
        style: Ui.text(p, size: Ui.sizeSmall, color: p.textDim),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Keep them', style: Ui.text(p, size: Ui.sizeSmall)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: p.danger),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

/// A short list of actions, as a sheet on phones and a small panel elsewhere.
class FilesSheetRow {
  const FilesSheetRow({
    required this.label,
    required this.icon,
    this.onTap,
    this.checked = false,
    this.danger = false,
  });

  final String label;
  final String icon;
  final VoidCallback? onTap;
  final bool checked;
  final bool danger;
}

Future<void> showFilesSheet(BuildContext context,
    {required String title,
    String? caption,
    required List<FilesSheetRow> rows}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: pal(context).surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(Ui.rSheet)),
    ),
    builder: (sheetContext) => _SheetBody(
      title: title,
      caption: caption,
      rows: rows,
      onClose: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.title,
    required this.rows,
    required this.onClose,
    this.caption,
  });

  final String title;
  final String? caption;
  final List<FilesSheetRow> rows;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Ui.text(p,
                              size: Ui.sizeTitle, weight: FontWeight.w700),
                        ),
                        if (caption != null)
                          Text(caption!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Ui.caption(p, color: p.textDim)),
                      ],
                    ),
                  ),
                  UiIconButton(
                    icon: 'close',
                    size: 30,
                    iconSize: 15,
                    onTap: onClose,
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 10),
                children: [
                  for (final r in rows)
                    UiRow(
                      dense: true,
                      height: Ui.menuRowHeight + 4,
                      title: r.label,
                      leading: Ico(r.danger
                          ? 'trash'
                          : (r.checked ? 'check' : r.icon),
                          size: 17,
                          color: r.danger ? p.danger : p.textDim),
                      onTap: () {
                        onClose();
                        r.onTap?.call();
                      },
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

/// Choose a destination folder by walking into it.
class _FolderPicker extends StatefulWidget {
  const _FolderPicker({required this.files});

  final FilesProvider files;

  @override
  State<_FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends State<_FolderPicker> {
  late String _dir = widget.files.dir;
  late List<FileNode> _kids = const [];
  String? _error;
  bool _busy = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final all = await widget.files.fs.list(_dir, showHidden: false);
      _kids = all.where((n) => n.isDir).toList();
      _error = null;
    } on FileOpException catch (e) {
      _error = e.message;
      _kids = const [];
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    final steps = stepsOf(_dir, s: widget.files.s);
    return AlertDialog(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: p.border),
        borderRadius: Ui.radius(Ui.rSheet),
      ),
      title: Text('Where should it go?',
          style: Ui.text(p, size: Ui.sizeTitle, weight: FontWeight.w700)),
      content: SizedBox(
        width: 420,
        height: 340,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 26,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final s in steps)
                    UiChip(
                      label: s.label.isEmpty ? _dir : s.label,
                      selected: s.path == _dir,
                      onTap: () {
                        setState(() => _dir = s.path);
                        _load();
                      },
                    ),
                ],
              ),
            ),
            Ui.vgap(8),
            Expanded(
              child: _busy
                  ? const UiProgressLine(active: true)
                  : (_error != null
                      ? UiEmpty(
                          icon: 'alert',
                          title: 'Cannot open that folder',
                          message: _error!,
                        )
                      : ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            for (final k in _kids)
                              UiRow(
                                dense: true,
                                height: 42,
                                title: k.name,
                                leading: Ico('folder', size: 18, color: p.textDim),
                                trailing:
                                    Ico('chevron-right', size: 14, color: p.textFaint),
                                onTap: () {
                                  setState(() => _dir = k.path);
                                  _load();
                                },
                              ),
                            if (_kids.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Text('No folders inside this one.',
                                    style: Ui.caption(p, color: p.textDim)),
                              ),
                          ],
                        )),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: Ui.text(p, size: Ui.sizeSmall)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_dir),
          child: const Text('Put them here'),
        ),
      ],
    );
  }
}

/// Full-screen entry used on phones and from the menu.
class FilesRoute extends StatelessWidget {
  const FilesRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(bottom: false, child: const FilesPage()),
    );
  }
}
