import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../core/ui.dart';
import '../core/urls.dart';
import '../pages/reader_page.dart';
import '../services/downloader.dart';
import '../state/browser_provider.dart';
import '../state/privacy_provider.dart';
import '../state/profile_provider.dart';
import '../state/settings_provider.dart';
import 'tab_switcher.dart';
import 'app_menu.dart';
import 'favicon.dart';
import 'glass.dart';
import 'logo.dart';
import 'omnibox.dart';
import 'site_info_sheet.dart';
import 'tab_strip.dart';
import 'ui_kit.dart';

/// The whole desktop chrome in one row: navigation, tabs, address, actions.
///
/// Nothing here is stacked into a second toolbar — the tabs sit beside the
/// address field the way a paper log sits beside a pen.
class TopBar extends StatelessWidget {
  const TopBar({super.key, this.showTabs = true});

  /// False when the vertical tab rail is showing tabs instead.
  final bool showTabs;

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final profile = context.watch<ProfileProvider>();
    final privacy = context.watch<PrivacyProvider>();
    final settings = context.watch<SettingsProvider>();
    final downloads = context.watch<DownloadService>();
    final p = pal(context);
    final tab = browser.current;

    final bookmarked = !tab.onSpeedDial && profile.isBookmarked(tab.url);
    final blocked = tab.onSpeedDial ? 0 : privacy.blockedFor(tab.host);
    final runningDownloads =
        downloads.downloads.where((d) => d.isRunning).length;

    return GlassBox(
      enabled: p.blurredChrome,
      color: p.chromeFill,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth;
              final roomForPills = showTabs && width >= 960;
              final roomy = width >= 1320;
              final medium = width >= 1120;

              return SizedBox(
                height: Ui.barHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      LogoMark(size: 22),
                      Ui.gap(12),
                      UiCluster(
                        children: [
                          UiIconButton(
                            icon: 'back',
                            iconSize: 16,
                            tooltip: 'Back (Alt+Left)',
                            onTap: tab.canBack ? browser.goBack : null,
                          ),
                          UiIconButton(
                            icon: 'forward',
                            iconSize: 16,
                            tooltip: 'Forward (Alt+Right)',
                            onTap: tab.canForward ? browser.goForward : null,
                          ),
                          UiIconButton(
                            icon: tab.loading
                                ? 'close'
                                : 'reload',
                            tooltip:
                                tab.loading ? 'Stop loading (Esc)' : 'Reload (Ctrl+R)',
                            onTap: tab.loading ? browser.stopLoading : browser.reload,
                          ),
                          if (medium)
                            UiIconButton(
                              icon: 'home',
                              tooltip: 'New tab page',
                              onTap: browser.goHome,
                            ),
                        ],
                      ),
                      Ui.gap(10),
                      if (roomForPills)
                        Expanded(flex: 5, child: const TabStrip())
                      else if (showTabs)
                        TabCountButton(
                          count: browser.tabCount,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              fullscreenDialog: true,
                              builder: (_) => const TabSwitcherPage(),
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      Ui.gap(12),
                      Ui.vRule(p, height: 22),
                      Ui.gap(12),
                      Expanded(
                        flex: roomForPills ? 6 : 1,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 660),
                            child: const Omnibox(),
                          ),
                        ),
                      ),
                      Ui.gap(10),
                      _Shield(
                        blocked: blocked,
                        enabled: privacy.effectiveBlockAds(
                          tab.siteUrl,
                          settings.blockAds,
                        ),
                      ),
                      UiIconButton(
                        icon: bookmarked
                            ? 'star-on'
                            : 'star',
                        color: bookmarked ? p.accent : null,
                        tooltip: bookmarked
                            ? 'Remove bookmark (Ctrl+D)'
                            : 'Bookmark this page (Ctrl+D)',
                        onTap: tab.onSpeedDial
                            ? null
                            : () => _toggleBookmark(context, bookmarked),
                      ),
                      if (roomy)
                        UiIconButton(
                          icon: 'reading-list',
                          tooltip: 'Reader view',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ReaderPage(),
                            ),
                          ),
                        ),
                      if (medium)
                        UiIconButton(
                          icon: 'download',
                          tooltip: runningDownloads > 0
                              ? '$runningDownloads downloads in progress'
                              : 'Downloads (Ctrl+J)',
                          badge: runningDownloads,
                          onTap: () => browser.setSidePanel(SidePanel.downloads),
                        ),
                      if (roomy)
                        UiIconButton(
                          icon: 'split',
                          tooltip: browser.splitActive
                              ? 'Close split view'
                              : 'Split view — two tabs side by side',
                          selected: browser.splitActive,
                          onTap: () => browser.splitActive
                              ? browser.closeSplit()
                              : browser.openSplit(),
                        ),
                      if (roomy)
                        UiIconButton(
                          icon: 'bolt',
                          tooltip: 'Quick actions (Ctrl+K)',
                          onTap: browser.openPalette,
                        ),
                      UiIconButton(
                        icon: browser.sidePanel == SidePanel.none
                            ? 'sidebar'
                            : 'sidebar',
                        tooltip: browser.sidePanel == SidePanel.none
                            ? 'Show sidebar'
                            : 'Hide sidebar',
                        selected: browser.sidePanel != SidePanel.none,
                        onTap: () => browser.toggleSidePanel(
                          browser.sidePanel == SidePanel.none
                              ? SidePanel.bookmarks
                              : SidePanel.none,
                        ),
                      ),
                      UiIconButton(
                        icon: 'shield',
                        tooltip: 'New private tab (Ctrl+Shift+N)',
                        onTap: () => browser.newTab(incognito: true),
                      ),
                      Ui.gap(2),
                      const AppMenuButton(desktop: true),
                    ],
                  ),
                ),
              );
            },
          ),
          UiProgressLine(active: tab.loading, progress: tab.progress),
          Container(height: Ui.hair, color: p.border),
        ],
      ),
    );
  }

  void _toggleBookmark(BuildContext context, bool wasBookmarked) {
    final browser = context.read<BrowserProvider>();
    final profile = context.read<ProfileProvider>();
    final tab = browser.current;
    final added = profile.toggleBookmark(url: tab.url, title: tab.title);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(added ? 'Saved to bookmarks' : 'Removed from bookmarks'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => profile.toggleBookmark(url: tab.url, title: tab.title),
        ),
      ),
    );
  }
}

/// The privacy shield in the bar: click for what happened on this site.
class _Shield extends StatelessWidget {
  const _Shield({required this.blocked, required this.enabled});

  final int blocked;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return UiIconButton(
      icon: 'shield',
      color: enabled && blocked > 0 ? p.accent : p.textDim,
      badge: blocked,
      tooltip: blocked > 0
          ? '$blocked ads and trackers blocked on this site'
          : 'Site information',
      onTap: () => showSiteInfoSheet(context),
    );
  }
}

/// Optional row of bookmarks under the bar.
class BookmarksBar extends StatelessWidget {
  const BookmarksBar({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final browser = context.read<BrowserProvider>();
    final p = pal(context);

    return GlassBox(
      enabled: p.blurredChrome,
      color: p.chromeFill,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: SizedBox(
        height: Ui.bookmarkBarHeight,
        child: Row(
          children: [
            if (profile.bookmarks.isEmpty)
              Expanded(
                child: Text(
                  'Press the star to keep a page here',
                  style: Ui.text(p, size: Ui.sizeSmall, color: p.textDim),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: profile.bookmarks.length,
                  itemBuilder: (_, i) {
                    final b = profile.bookmarks[i];
                    return Padding(
                      padding: const EdgeInsets.only(right: 5),
                      child: UiChip(
                        label: b.title.isEmpty ? hostOf(b.url) : b.title,
                        leading: Favicon(host: hostOf(b.url), size: 14),
                        onTap: () => browser.navigate(b.url),
                      ),
                    );
                  },
                ),
              ),
            Ui.gap(6),
            UiIconButton(
              icon: 'bookmarks',
              size: 28,
              iconSize: 16,
              tooltip: 'All bookmarks',
              onTap: () => browser.setSidePanel(SidePanel.bookmarks),
            ),
          ],
        ),
      ),
    );
  }
}
