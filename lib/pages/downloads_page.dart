import 'dart:io' show Directory, Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/icons.dart';
import '../widgets/ui_kit.dart';

import '../core/pal.dart';
import '../core/ui.dart';
import '../models.dart';
import '../services/downloader.dart';
import '../state/files_provider.dart';
import 'files_page.dart';

/// Downloads list — embeddable in the desktop side panel.
class DownloadsList extends StatelessWidget {
  const DownloadsList({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadService>();
    final palette = pal(context);

    if (downloads.downloads.isEmpty) {
      return Column(
        children: [
          Expanded(
            child: _Empty(
              icon: 'download',
              title: 'No downloads yet',
              subtitle: 'Files land in your Downloads folder.',
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: UiButton(
              label: 'Open that folder',
              icon: 'folder',
              compact: true,
              onTap: () => openDownloadsFolder(context, null),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 8,
      ).add(
        EdgeInsets.only(bottom: embedded ? 0 : 16),
      ),
      itemCount: downloads.downloads.length,
      itemBuilder: (_, i) {
        final item = downloads.downloads[i];
        final progress = item.total > 0
            ? (item.received / item.total).clamp(0.0, 1.0)
            : null;
        return Card(
          elevation: 0,
          color: palette.surface,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          shape: RoundedRectangleBorder(
            borderRadius: Ui.petal(Ui.rCard),
            side: BorderSide(color: palette.border),
          ),
          child: ListTile(
            leading: _fileIcon(item, palette),
            title: Text(
              item.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  item.statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: item.status == DownloadStatus.done
                        ? palette.success
                        : item.status == DownloadStatus.failed
                            ? palette.danger
                            : palette.textDim,
                  ),
                ),
                if (item.isRunning)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      value: progress,
                      backgroundColor: palette.surfaceAlt,
                      color: palette.accent,
                    ),
                  ),
              ],
            ),
            isThreeLine: item.isRunning,
            trailing: item.isRunning
                ? IconButton(
                    tooltip: 'Cancel',
                    icon: uiGlyph('close', color: palette.textDim),
                    onPressed: () => downloads.cancel(item.id),
                  )
                : (item.status == DownloadStatus.done && !Platform.isAndroid)
                    ? IconButton(
                        tooltip: 'Show in folder',
                        icon: uiGlyph('folder-open',
                            color: palette.textDim),
                        onPressed: () => downloads.reveal(item),
                      )
                    : null,
          ),
        );
      },
    );
  }

  Widget _fileIcon(DownloadItem item, BrowserPalette palette) {
    final n = item.fileName.toLowerCase();
    Object icon = 'file';
    if (n.endsWith('.pdf')) icon = 'file-pdf';
    if (n.endsWith('.zip') || n.endsWith('.rar') || n.endsWith('.7z')) {
      icon = 'archive';
    }
    if (n.endsWith('.mp3') || n.endsWith('.wav') || n.endsWith('.m4a')) {
      icon = 'music';
    }
    if (n.endsWith('.mp4') || n.endsWith('.mkv') || n.endsWith('.webm')) {
      icon = 'video';
    }
    if (n.endsWith('.jpg') || n.endsWith('.png') || n.endsWith('.webp') ||
        n.endsWith('.gif')) {
      icon = 'image';
    }
    if (n.endsWith('.apk')) icon = 'device';
    if (n.endsWith('.exe')) icon = 'grid';
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: Ui.petal(10),
      ),
      child: uiGlyph(icon, size: 20, color: palette.accent),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, this.subtitle});

  final Object icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          uiGlyph(icon, size: 52, color: palette.textDim),
          const SizedBox(height: 12),
          Text(title, style: TextStyle(color: palette.text, fontSize: 15)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.textDim, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}

/// Full-page route (mobile & snackbars).
class DownloadsRoute extends StatelessWidget {
  const DownloadsRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    final downloads = context.watch<DownloadService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            tooltip: 'Open the folder',
            icon: uiGlyph('folder', color: palette.text),
            onPressed: () => openDownloadsFolder(context, null),
          ),
          IconButton(
            tooltip: 'Clear finished',
            icon: uiGlyph('clear', color: palette.text),
            onPressed: downloads.downloads.isEmpty
                ? null
                : () => downloads.clearFinished(),
          ),
        ],
      ),
      backgroundColor: palette.background,
      body: const DownloadsList(),
    );
  }
}

/// Open the file manager where downloads live.
Future<void> openDownloadsFolder(BuildContext context, String? dir) async {
  final files = context.read<FilesProvider>();
  final wanted = dir == null || dir.isEmpty ? files.fs.startPath() : dir;
  final exists = await Directory(wanted).exists();
  await files.goTo(exists ? wanted : files.fs.startPath());
  if (!context.mounted) return;
  Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => const FilesRoute()));
}
