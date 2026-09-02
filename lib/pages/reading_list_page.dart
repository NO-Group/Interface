import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../core/urls.dart';
import '../state/browser_provider.dart';
import '../state/profile_provider.dart';
import '../widgets/favicon.dart';

/// "Read later" list — embeddable in the desktop side panel.
class ReadingListPage extends StatelessWidget {
  const ReadingListPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final palette = pal(context);

    if (profile.readingList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_stories_rounded, size: 52, color: palette.textDim),
            const SizedBox(height: 12),
            Text(
              'Save articles with "Read later" in the menu',
              style: TextStyle(color: palette.text, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: profile.readingList.length,
      itemBuilder: (_, i) {
        final e = profile.readingList[i];
        return Dismissible(
          key: ValueKey(e.id),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: palette.danger.withValues(alpha: 0.15),
            child: Icon(Icons.delete_outline_rounded, color: palette.danger),
          ),
          direction: embedded ? DismissDirection.none : DismissDirection.endToStart,
          onDismissed: (_) => profile.removeReading(e),
          child: ListTile(
            dense: true,
            leading: Stack(
              children: [
                Favicon(host: hostOf(e.url), size: 22),
                if (!e.read)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: palette.accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: palette.surface, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(
              e.title.isEmpty ? displayUrl(e.url) : e.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.text,
                fontSize: 13.5,
                fontWeight: e.read ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
            subtitle: Text(
              hostOf(e.url),
              style: TextStyle(color: palette.textDim, fontSize: 11.5),
            ),
            trailing: IconButton(
              icon: Icon(
                e.read
                    ? Icons.radio_button_unchecked_rounded
                    : Icons.check_circle_outline_rounded,
                size: 19,
                color: e.read ? palette.textDim : palette.accent,
              ),
              onPressed: () =>
                  profile.markReadingRead(e, read: !e.read),
            ),
            onTap: () {
              profile.markReadingRead(e, read: true);
              context.read<BrowserProvider>().navigate(e.url);
            },
          ),
        );
      },
    );
  }
}

/// Full-page route.
class ReadingRoute extends StatelessWidget {
  const ReadingRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Reading list')),
      backgroundColor: palette.background,
      body: const ReadingListPage(),
    );
  }
}
