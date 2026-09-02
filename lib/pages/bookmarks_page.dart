import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../core/urls.dart';
import '../models.dart';
import '../state/browser_provider.dart';
import '../state/profile_provider.dart';
import '../widgets/favicon.dart';

/// Bookmark manager — embeddable in the side panel.
class BookmarksList extends StatelessWidget {
  const BookmarksList({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final palette = pal(context);

    if (profile.bookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_border_rounded, size: 52, color: palette.textDim),
            const SizedBox(height: 12),
            Text('Use the star in the toolbar to keep pages here',
                style: TextStyle(color: palette.text, fontSize: 15)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: profile.bookmarks.length,
      itemBuilder: (_, i) {
        final b = profile.bookmarks[i];
        return _BookmarkTile(bookmark: b, embedded: embedded);
      },
    );
  }
}

class _BookmarkTile extends StatelessWidget {
  const _BookmarkTile({required this.bookmark, required this.embedded});

  final Bookmark bookmark;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    final browser = context.read<BrowserProvider>();
    final profile = context.read<ProfileProvider>();

    return ListTile(
      dense: true,
      leading: Favicon(host: hostOf(bookmark.url)),
      title: Text(
        bookmark.title.isEmpty ? displayUrl(bookmark.url) : bookmark.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: palette.text, fontSize: 13.5),
      ),
      subtitle: Text(
        displayUrl(bookmark.url),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: palette.textDim, fontSize: 11.5),
      ),
      trailing: embedded
          ? null
          : PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  size: 19, color: palette.textDim),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'open', height: 40, child: Text('Open')),
                PopupMenuItem(
                    value: 'newtab', height: 40, child: Text('Open in new tab')),
                PopupMenuItem(value: 'edit', height: 40, child: Text('Edit')),
                PopupMenuItem(
                    value: 'delete', height: 40, child: Text('Delete')),
              ],
              onSelected: (v) {
                switch (v) {
                  case 'open':
                    browser.navigate(bookmark.url);
                  case 'newtab':
                    browser.newTab(url: bookmark.url);
                  case 'edit':
                    _edit(context, profile, bookmark);
                  case 'delete':
                    profile.removeBookmark(bookmark);
                }
              },
            ),
      onTap: () => browser.navigate(bookmark.url),
    );
  }

  static Future<void> _edit(
    BuildContext context,
    ProfileProvider profile,
    Bookmark b,
  ) async {
    final palette = pal(context);
    final title = TextEditingController(text: b.title);
    final url = TextEditingController(text: b.url);
    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Edit bookmark'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Name', isDense: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: url,
              decoration:
                  const InputDecoration(labelText: 'Address', isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = urlFromInput(url.text) ??
                  Uri.tryParse('https://${url.text.trim()}');
              if (parsed == null || parsed.host.isEmpty) return;
              profile.updateBookmark(
                b,
                title: title.text.trim(),
                url: parsed.toString(),
              );
              Navigator.of(d).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: palette.accent),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    title.dispose();
    url.dispose();
  }
}

/// Full-page route.
class BookmarksRoute extends StatelessWidget {
  const BookmarksRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      backgroundColor: palette.background,
      body: const BookmarksList(),
    );
  }
}
