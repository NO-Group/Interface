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
import 'tab_strip.dart';
import 'ui_kit.dart';

/// The whole desktop chrome in one row: a brand plate, navigation, the tabs
/// themselves, the address plate, then what you can do to this page.
///
/// Three rules hold it together. Groups are separated by a 1px tick, never by
/// a plate behind them. A control that is on is marked with a keel, and
/// nothing idle has one. Colour only appears where something is happening —
/// the brand plate lights while the page loads or when trackers are blocked,
/// and the address plate lights when it has focus.
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
    final shielding =
        privacy.effectiveBlockAds(tab.siteUrl, settings.blockAds) && blocked > 0;
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
                  padding: const EdgeInsets.only(
                      left: Ui.dockInset, right: 10, top: 0, bottom: 0),
                  child: Row(
                    children: [
                      _BrandPlate(lit: tab.loading || shielding),
                      Ui.gap(12),
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
                        icon: tab.loading ? 'stop' : 'reload',
                        tooltip: tab.loading
                            ? 'Stop loading (Esc)'
                            : 'Reload (Ctrl+R)',
                        onTap:
                            tab.loading ? browser.stopLoading : browser.reload,
                      ),
                      if (medium) ...[
                        Ui.gap(2),
                        Ui.vRule(p, height: 20),
                        Ui.gap(2),
                        UiIconButton(
                          icon: 'home',
                          tooltip: 'New tab page',
                          onTap: browser.goHome,
                        ),
                      ],
                      Ui.gap(12),
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
                      if (roomForPills) ...[
                        Ui.gap(12),
                        Ui.vRule(p, height: 20),
                        Ui.gap(12),
                      ],
                      Expanded(
                        flex: roomForPills ? 6 : 1,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 700),
                            child: const Omnibox(),
                          ),
                        ),
                      ),
                      Ui.gap(12),
                      Ui.vRule(p, height: 20),
                      Ui.gap(6),
                      UiIconButton(
                        icon: bookmarked ? 'star-on' : 'star',
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
                          icon: 'reader',
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
                          onTap: () =>
                              browser.setSidePanel(SidePanel.downloads),
                        ),
                      if (roomy) ...[
                        Ui.gap(4),
                        Ui.vRule(p, height: 20),
                        Ui.gap(4),
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
                        UiIconButton(
                          icon: 'bolt',
                          tooltip: 'Quick actions (Ctrl+K)',
                          onTap: browser.openPalette,
                        ),
                      ],
                      UiIconButton(
                        icon: 'sidebar',
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
                      Ui.gap(4),
                      Ui.vRule(p, height: 20),
                      Ui.gap(4),
                      UiIconButton(
                        icon: 'private',
                        tooltip: 'New private tab (Ctrl+Shift+N)',
                        onTap: () => browser.newTab(incognito: true),
                      ),
                      const AppMenuButton(desktop: true),
                    ],
                  ),
                ),
              );
            },
          ),
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
          onPressed: () =>
              profile.toggleBookmark(url: tab.url, title: tab.title),
        ),
      ),
    );
  }
}

/// The name of the app, cut into the left end of the bar. It is the only part
/// of the chrome that is allowed to be navy on a navy day, and it lights with
/// the page: accent while it loads, or while the shield is doing something.
class _BrandPlate extends StatelessWidget {
  const _BrandPlate({required this.lit});

  final bool lit;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Tooltip(
      message: 'Interface',
      waitDuration: const Duration(milliseconds: 600),
      child: AnimatedContainer(
        duration: Ui.normal,
        curve: Ui.curve,
        height: Ui.barHeight,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: lit
              ? p.accent.withValues(alpha: p.isDark ? 0.16 : 0.12)
              : p.primary.withValues(alpha: p.isDark ? 0.55 : 1),
          borderRadius: Ui.petal(Ui.rField, at: UiCorner.bottomRight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LogoMark(size: 22),
            const SizedBox(width: 9),
            // The wordmark only fits on a wide window; the mark is enough when
            // the bar is crowded, so it is dropped rather than ellipsised.
            if (MediaQuery.sizeOf(context).width >= 1120)
              Text(
                'Interface',
                style: Ui.text(
                  p,
                  size: Ui.sizeSmall + 0.5,
                  weight: FontWeight.w700,
                  color: lit ? p.text : p.onPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The row of saved pages under the bar: ticks between the names, no plates.
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
      padding: const EdgeInsets.only(left: Ui.dockInset + 4, right: 10, top: 3, bottom: 3),
      child: SizedBox(
        height: Ui.bookmarkBarHeight,
        child: Row(
          children: [
            Ui.keel(p, color: p.idleKeel),
            const SizedBox(width: 10),
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
