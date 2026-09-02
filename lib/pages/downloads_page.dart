import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../core/ui.dart';
import '../models.dart';
import '../services/downloader.dart';

/// Downloads list — embeddable in the desktop side panel.
class DownloadsList extends StatelessWidget {
  const DownloadsList({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadService>();
    final palette = pal(context);

    if (downloads.downloads.isEmpty) {
      return _Empty(
        icon: Icons.download_rounded,
        title: 'No downloads yet',
        subtitle:
            Platform.isWindows ? 'Files land in your Downloads folder.' : 'Files land in the app Downloads folder.',
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
            borderRadius: BorderRadius.circular(Ui.rCard),
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
                    icon: Icon(Icons.close_rounded, color: palette.textDim),
                    onPressed: () => downloads.cancel(item.id),
                  )
                : (item.status == DownloadStatus.done && !Platform.isAndroid)
                    ? IconButton(
                        tooltip: 'Show in folder',
                        icon: Icon(Icons.folder_open_rounded,
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
    IconData icon = Icons.insert_drive_file_outlined;
    if (n.endsWith('.pdf')) icon = Icons.picture_as_pdf_outlined;
    if (n.endsWith('.zip') || n.endsWith('.rar') || n.endsWith('.7z')) {
      icon = Icons.folder_zip_outlined;
    }
    if (n.endsWith('.mp3') || n.endsWith('.wav') || n.endsWith('.m4a')) {
      icon = Icons.music_note_outlined;
    }
    if (n.endsWith('.mp4') || n.endsWith('.mkv') || n.endsWith('.webm')) {
      icon = Icons.movie_outlined;
    }
    if (n.endsWith('.jpg') || n.endsWith('.png') || n.endsWith('.webp') ||
        n.endsWith('.gif')) {
      icon = Icons.image_outlined;
    }
    if (n.endsWith('.apk')) icon = Icons.android_rounded;
    if (n.endsWith('.exe')) icon = Icons.apps_rounded;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: palette.accent),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 52, color: palette.textDim),
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
            tooltip: 'Clear finished',
            icon: Icon(Icons.clear_all_rounded, color: palette.text),
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
