import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../core/urls.dart';
import '../state/browser_provider.dart';
import '../state/profile_provider.dart';
import 'app_menu.dart';
import 'favicon.dart';
import 'glass.dart';
import 'omnibox.dart';

/// Chrome-style desktop navigation row under the tab strip,
/// with an Opera-style sidebar toggle.
class DesktopToolbar extends StatelessWidget {
  const DesktopToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final profile = context.watch<ProfileProvider>();
    final palette = pal(context);
    final tab = browser.current;

    final bookmarked = !tab.onSpeedDial && profile.isBookmarked(tab.url);

    return GlassBox(
      enabled: palette.chromeTranslucent,
      color: palette.chromeFill,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: SizedBox(
        height: 46,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Back (Alt+Left)',
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
              color: palette.text,
              onPressed: tab.canBack ? () => browser.goBack() : null,
            ),
            IconButton(
              tooltip: 'Forward (Alt+Right)',
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 17),
              color: palette.text,
              onPressed: tab.canForward ? () => browser.goForward() : null,
            ),
            IconButton(
              tooltip: tab.loading ? 'Stop (Esc)' : 'Reload (Ctrl+R)',
              icon: Icon(
                tab.loading
                    ? Icons.close_rounded
                    : Icons.refresh_rounded,
                size: 19,
              ),
              color: palette.text,
              onPressed:
                  tab.loading ? browser.stopLoading : () => browser.reload(),
            ),
            IconButton(
              tooltip: 'Home',
              icon: const Icon(Icons.home_outlined, size: 20),
              color: palette.text,
              onPressed: () => browser.goHome(),
            ),
            const SizedBox(width: 6),
            Expanded(child: Omnibox()),
            const SizedBox(width: 6),
            IconButton(
              tooltip: bookmarked ? 'Edit bookmark' : 'Bookmark (Ctrl+D)',
              icon: Icon(
                bookmarked ? Icons.star_rounded : Icons.star_border_rounded,
                size: 21,
                color: bookmarked ? palette.accent : palette.text,
              ),
              onPressed: tab.onSpeedDial
                  ? null
                  : () {
                      final added = profile.toggleBookmark(
                        url: tab.url,
                        title: tab.title,
                      );
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.hideCurrentSnackBar();
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            added ? 'Bookmark added' : 'Bookmark removed',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
            ),
            IconButton(
              tooltip: browser.sidePanel == SidePanel.none
                  ? 'Show sidebar'
                  : 'Hide sidebar',
              isSelected: browser.sidePanel != SidePanel.none,
              icon: const Icon(Icons.view_sidebar_outlined, size: 19),
              selectedIcon: const Icon(Icons.view_sidebar_rounded, size: 19),
              color: palette.text,
              onPressed: () => browser.toggleSidePanel(
                browser.sidePanel == SidePanel.none
                    ? SidePanel.bookmarks
                    : SidePanel.none,
              ),
            ),
            IconButton(
              tooltip: 'New incognito tab',
              icon: Icon(Icons.shield_outlined, size: 20, color: palette.text),
              onPressed: () => browser.newTab(incognito: true),
            ),
            AppMenuButton(desktop: true),
            const SizedBox(width: 2),
          ],
        ),
      ),
    );
  }
}

/// Chrome's bookmarks bar (desktop), also opens bookmarks.
class BookmarksBar extends StatelessWidget {
  const BookmarksBar({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final palette = pal(context);
    final browser = context.read<BrowserProvider>();

    if (profile.bookmarks.isEmpty) {
      return GlassBox(
        enabled: palette.chromeTranslucent,
        color: palette.chromeFill,
        child: SizedBox(
          height: 32,
          child: Center(
            child: Text(
              'Bookmark pages with the ☆ to see them here',
              style: TextStyle(color: palette.textDim, fontSize: 11.5),
            ),
          ),
        ),
      );
    }

    return GlassBox(
      enabled: palette.chromeTranslucent,
      color: palette.chromeFill,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 32,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: profile.bookmarks.length,
          itemBuilder: (_, i) {
            final b = profile.bookmarks[i];
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: ActionChip(
                visualDensity: VisualDensity.compact,
                avatar: Favicon(host: hostOf(b.url), size: 14),
                label: Text(
                  b.title.isEmpty ? hostOf(b.url) : b.title,
                  style: TextStyle(fontSize: 11.5, color: palette.text),
                ),
                backgroundColor: Colors.transparent,
                side: BorderSide(color: palette.border),
                onPressed: () => browser.navigate(b.url),
              ),
            );
          },
        ),
      ),
    );
  }
}
