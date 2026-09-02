import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../core/urls.dart';
import '../pages/reader_page.dart';
import '../services/downloader.dart';
import '../state/browser_provider.dart';
import '../state/privacy_provider.dart';
import '../state/profile_provider.dart';
import '../state/settings_provider.dart';
import 'app_menu.dart';
import 'favicon.dart';
import 'glass.dart';
import 'omnibox.dart';
import 'site_info_sheet.dart';

/// Chrome-style desktop navigation row under the tab strip,
/// with Opera-style extras: sidebar, split view, privacy shield.
class DesktopToolbar extends StatelessWidget {
  const DesktopToolbar({super.key});

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final profile = context.watch<ProfileProvider>();
    final privacy = context.watch<PrivacyProvider>();
    final settings = context.watch<SettingsProvider>();
    final downloads = context.watch<DownloadService>();
    final palette = pal(context);
    final tab = browser.current;

    final bookmarked = !tab.onSpeedDial && profile.isBookmarked(tab.url);
    final blocked = tab.onSpeedDial ? 0 : privacy.blockedFor(tab.host);
    final activeDownloads =
        downloads.downloads.where((d) => d.isRunning).length;

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
                tab.loading ? Icons.close_rounded : Icons.refresh_rounded,
                size: 19,
              ),
              color: palette.text,
              onPressed:
                  tab.loading ? browser.stopLoading : () => browser.reload(),
            ),
            IconButton(
              tooltip: 'Home / Speed dial',
              icon: const Icon(Icons.home_outlined, size: 20),
              color: palette.text,
              onPressed: () => browser.goHome(),
            ),
            const SizedBox(width: 6),
            Expanded(child: Omnibox()),
            const SizedBox(width: 6),
            _ToolbarIconButton(
              tooltip: 'Command palette (Ctrl+K)',
              icon: Icons.bolt_rounded,
              color: palette.text,
              onTap: browser.openPalette,
            ),
            _ShieldBadge(
              blocked: blocked,
              enabled: privacy.effectiveBlockAds(
                  tab.siteUrl, settings.blockAds),
            ),
            _ToolbarIconButton(
              tooltip: 'Reader mode',
              icon: Icons.menu_book_rounded,
              color: tab.onSpeedDial ? palette.textDim : palette.text,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const ReaderPage()),
              ),
            ),
            IconButton(
              tooltip: browser.splitActive
                  ? 'Close split view'
                  : 'Split view — two tabs side by side',
              isSelected: browser.splitActive,
              icon: const Icon(Icons.vertical_split_outlined, size: 19),
              selectedIcon: Icon(Icons.vertical_split_rounded,
                  size: 19, color: palette.accent),
              color: palette.text,
              onPressed: () => browser.splitActive
                  ? browser.closeSplit()
                  : browser.openSplit(),
            ),
            if (activeDownloads > 0)
              Badge.count(
                count: activeDownloads,
                backgroundColor: palette.accent,
                textColor: palette.onAccent,
                child: _ToolbarIconButton(
                  tooltip: 'Downloads in progress',
                  icon: Icons.download_rounded,
                  color: palette.accent,
                  onTap: () => browser.setSidePanel(SidePanel.downloads),
                ),
              ),
            IconButton(
              tooltip: bookmarked ? 'Remove bookmark (Ctrl+D)' : 'Bookmark (Ctrl+D)',
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
                          content:
                              Text(added ? 'Bookmark added' : 'Bookmark removed'),
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

/// Small stateless toolbar icon button.
class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: IconButton(
        icon: Icon(icon, size: 19),
        color: color,
        onPressed: onTap,
      ),
    );
  }
}

/// Privacy shield with live per-site blocked counter.
class _ShieldBadge extends StatelessWidget {
  const _ShieldBadge({required this.blocked, required this.enabled});

  final int blocked;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    final active = enabled && blocked > 0;
    return Tooltip(
      message: blocked > 0
          ? '$blocked trackers & ads blocked on this site'
          : 'Site information',
      waitDuration: const Duration(milliseconds: 600),
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: Icon(
              Icons.shield_outlined,
              size: 20,
              color: active ? palette.accent : palette.text,
            ),
            onPressed: () => showSiteInfoSheet(context),
          ),
          if (blocked > 0)
            Positioned(
              top: 5,
              right: 3,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 1),
                constraints:
                    const BoxConstraints(minWidth: 14, minHeight: 13),
                decoration: BoxDecoration(
                  color: palette.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  blocked > 99 ? '99+' : '$blocked',
                  style: TextStyle(
                    color: palette.onAccent,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
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
