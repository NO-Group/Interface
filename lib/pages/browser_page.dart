import 'dart:io' show File;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode, launchUrl;
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../core/ui.dart';
import '../services/web_engine.dart';
import '../state/browser_provider.dart';
import '../state/privacy_provider.dart';
import '../state/profile_provider.dart';
import '../state/settings_provider.dart';
import '../widgets/app_menu.dart';
import '../widgets/command_palette.dart';
import '../widgets/find_bar.dart';
import '../widgets/omnibox.dart';
import '../widgets/onboarding.dart';
import '../widgets/permission_banner.dart';
import '../widgets/site_info_sheet.dart';
import '../widgets/tab_switcher.dart';
import '../widgets/toolbar.dart';
import '../widgets/ui_kit.dart';
import '../widgets/vertical_tab_rail.dart';
import '../widgets/tab_web_view.dart';
import '../widgets/view_stack.dart';
import 'bookmarks_page.dart';
import 'downloads_page.dart';
import 'history_page.dart';
import 'privacy_page.dart';
import 'reading_list_page.dart';
import 'settings_page.dart';

/// Root of the browser UI. Picks the desktop or mobile shell, paints the
/// wallpaper theme, and handles fullscreen video, split view, quick
/// actions and the welcome screen.
class BrowserPage extends StatelessWidget {
  const BrowserPage({super.key});

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final settings = context.watch<SettingsProvider>();
    final palette = pal(context);
    final wide = MediaQuery.sizeOf(context).width >= 840;

    // Keep Android status bar icons readable in every theme.
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            palette.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: palette.isDark ? Brightness.dark : Brightness.light,
      ),
    );

    final wallpaper = settings.hasCustomBackground
        ? Image.file(File(settings.customBgPath!), fit: BoxFit.cover)
        : null;

    Widget chrome = wide ? const DesktopShell() : const MobileShell();

    if (browser.fullscreen) {
      chrome = Stack(
        fit: StackFit.expand,
        children: [
          const ViewStack(),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton.filledTonal(
              tooltip: 'Exit fullscreen',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.fullscreen_rounded),
              onPressed: () => browser.setFullscreen(false),
            ),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (wallpaper != null) ...[
          Positioned.fill(child: wallpaper),
          Positioned.fill(child: ColoredBox(color: palette.wallpaperScrim)),
        ],
        Column(
          children: [
            if (WebEngine.instance.requiresWebView2)
              _WebView2Banner(palette: palette),
            Expanded(child: chrome),
          ],
        ),
        if (!settings.onboardingSeen && !browser.fullscreen)
          const Positioned.fill(child: OnboardingOverlay()),
      ],
    );
  }
}

class _WebView2Banner extends StatelessWidget {
  const _WebView2Banner({required this.palette});

  final BrowserPalette palette;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.danger,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 18, color: Colors.white),
            const SizedBox(width: 11),
            const Expanded(
              child: Text(
                'Pages need Microsoft’s WebView2 to display on this PC.',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(
                  'https://developer.microsoft.com/microsoft-edge/webview2/',
                ),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text('Get it'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop
// ---------------------------------------------------------------------------

class DesktopShell extends StatelessWidget {
  const DesktopShell({super.key});

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final settings = context.watch<SettingsProvider>();
    final palette = pal(context);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyT, control: true):
            () => browser.newTab(),
        const SingleActivator(
          LogicalKeyboardKey.keyN,
          control: true,
          shift: true,
        ): () => browser.newTab(incognito: true),
        const SingleActivator(LogicalKeyboardKey.keyW, control: true):
            browser.closeCurrent,
        const SingleActivator(LogicalKeyboardKey.tab, control: true):
            browser.selectNext,
        const SingleActivator(
          LogicalKeyboardKey.tab,
          control: true,
          shift: true,
        ): browser.selectPrevious,
        const SingleActivator(LogicalKeyboardKey.keyL, control: true):
            browser.requestOmniboxFocus,
        const SingleActivator(LogicalKeyboardKey.keyD, alt: true):
            browser.requestOmniboxFocus,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            browser.openPalette,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            browser.openFind,
        const SingleActivator(LogicalKeyboardKey.keyR, control: true):
            () => browser.reload(),
        const SingleActivator(LogicalKeyboardKey.f5): () => browser.reload(),
        const SingleActivator(LogicalKeyboardKey.keyH, control: true): () =>
            browser.toggleSidePanel(SidePanel.history),
        const SingleActivator(LogicalKeyboardKey.keyJ, control: true): () =>
            browser.toggleSidePanel(SidePanel.downloads),
        const SingleActivator(
          LogicalKeyboardKey.keyB,
          control: true,
          shift: true,
        ): () => settings.setShowBookmarksBar(!settings.showBookmarksBar),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
            () => browser.goBack(),
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
            () => browser.goForward(),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (browser.findOpen) browser.closeFind();
        },
        for (var i = 1; i <= 8; i++)
          SingleActivator(
            desktopDigit(i),
            control: true,
          ): () => browser.select(i - 1),
        const SingleActivator(LogicalKeyboardKey.digit9, control: true):
            () => browser.select(browser.tabCount - 1),
      },
      child: Focus(
        autofocus: true,
        child: Stack(
          children: [
            Column(
              children: [
                TopBar(showTabs: !settings.verticalTabs),
                if (!settings.verticalTabs && settings.showBookmarksBar)
                  const BookmarksBar(),
                Expanded(
                  child: Row(
                    children: [
                      if (settings.verticalTabs)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: palette.chromeFill,
                            border: Border(
                              right: BorderSide(color: palette.border),
                            ),
                          ),
                          child: const VerticalTabRail(),
                        ),
                      if (browser.splitActive)
                        _SplitView(
                          fraction: browser.splitFraction,
                          onFraction: browser.setSplitFraction,
                        )
                      else
                        const Expanded(child: ViewStack()),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.centerLeft,
                        clipBehavior: Clip.hardEdge,
                        child: browser.sidePanel == SidePanel.none
                            ? const SizedBox.shrink()
                            : const SizedBox(
                                width: 372, child: _SidePanel()),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (browser.findOpen)
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: Center(child: const FindBar()),
              ),
            if (browser.paletteOpen)
              const Positioned.fill(child: CommandPalette()),
          ],
        ),
      ),
    );
  }

  static LogicalKeyboardKey desktopDigit(int n) {
    const map = {
      1: LogicalKeyboardKey.digit1,
      2: LogicalKeyboardKey.digit2,
      3: LogicalKeyboardKey.digit3,
      4: LogicalKeyboardKey.digit4,
      5: LogicalKeyboardKey.digit5,
      6: LogicalKeyboardKey.digit6,
      7: LogicalKeyboardKey.digit7,
      8: LogicalKeyboardKey.digit8,
    };
    return map[n] ?? LogicalKeyboardKey.digit1;
  }
}

/// Two tabs side by side with a draggable divider.
class _SplitView extends StatelessWidget {
  const _SplitView({
    required this.fraction,
    required this.onFraction,
  });

  final double fraction;
  final void Function(double) onFraction;

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final palette = pal(context);
    final split = browser.splitTab;

    if (split == null) return const Expanded(child: ViewStack());

    return LayoutBuilder(
      builder: (context, constraints) {
        final total = constraints.maxWidth;
        final secondWidth =
            (total * (1 - fraction)).clamp(320.0, total - 320.0);
        final firstWidth = total - secondWidth;

        return Row(
          children: [
            SizedBox(
              width: firstWidth,
              child: const _PrimarySplitStack(),
            ),
            GestureDetector(
              onHorizontalDragUpdate: (d) =>
                  onFraction(1 - ((d.globalPosition.dx) / total)),
              onDoubleTap: () => onFraction(0.5),
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: Container(
                  width: 5,
                  color: palette.border,
                  child: Center(
                    child: Container(
                      width: 2,
                      height: 34,
                      decoration: BoxDecoration(
                        color: palette.accent.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: secondWidth,
              child: Column(
                children: [
                  InkWell(
                    onTap: () => browser.selectTab(split),
                    onSecondaryTap: () => browser.closeSplit(),
                    child: Container(
                      height: 30,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      color: palette.chromeFill,
                      child: Row(
                        children: [
                          Icon(Icons.vertical_split_rounded,
                              size: 14, color: palette.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              split.displayTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.text,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () => browser.closeTab(split),
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(Icons.close_rounded,
                                  size: 14, color: palette.textDim),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => browser.closeSplit(),
                            customBorder: const CircleBorder(),
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Icon(Icons.close_fullscreen_rounded,
                                  size: 14, color: palette.textDim),
                            ),
                          ),
                          const SizedBox(width: 2),
                        ],
                      ),
                    ),
                  ),
                  Container(height: 1, color: palette.border),
                  Expanded(
                    child: TabWebView(key: ValueKey(split.id), tab: split),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Main pane content while split view is active: every tab except the
/// one living in the split pane.
class _PrimarySplitStack extends StatelessWidget {
  const _PrimarySplitStack();

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final children = [
      for (final tab in browser.tabs)
        if (tab.id != browser.splitTabId) TabWebView(key: ValueKey(tab.id), tab: tab),
    ];
    var idx = browser.index;
    // Compensate for the split tab being filtered out of the stack.
    for (var i = 0; i <= browser.index && i < browser.tabs.length; i++) {
      if (browser.tabs[i].id == browser.splitTabId) idx--;
    }
    return IndexedStack(
      index: idx.clamp(0, children.length - 1),
      children: children,
    );
  }
}

/// Sidebar with the library pages.
class _SidePanel extends StatelessWidget {
  const _SidePanel();

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final palette = pal(context);
    final page = browser.sidePanel;

    final title = switch (page) {
      SidePanel.bookmarks => 'Bookmarks',
      SidePanel.history => 'History',
      SidePanel.downloads => 'Downloads',
      SidePanel.settings => 'Settings',
      SidePanel.reading => 'Reading list',
      SidePanel.privacy => 'Privacy',
      SidePanel.none => '',
    };

    return Row(
      children: [
        _SideRail(page: page),
        Container(width: 1, color: palette.border),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 46,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Ui.text(palette,
                              size: Ui.sizeTitle, weight: FontWeight.w700),
                        ),
                      ),
                      UiIconButton(
                        icon: Icons.chevron_right_rounded,
                        tooltip: 'Hide sidebar',
                        onTap: () => browser.setSidePanel(SidePanel.none),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: palette.hairline),
              Expanded(
                child: switch (page) {
                  SidePanel.bookmarks => const BookmarksList(embedded: true),
                  SidePanel.history => const HistoryList(embedded: true),
                  SidePanel.downloads => const DownloadsList(embedded: true),
                  SidePanel.settings => const SettingsBody(),
                  SidePanel.reading => const ReadingListPage(embedded: true),
                  SidePanel.privacy => const PrivacyPage(embedded: true),
                  SidePanel.none => const SizedBox.shrink(),
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.page});

  final SidePanel page;

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final profile = context.watch<ProfileProvider>();

    Widget railButton(SidePanel target, IconData icon, String tip,
        {int badge = 0}) {
      return UiIconButton(
        icon: icon,
        tooltip: tip,
        size: 40,
        iconSize: 20,
        badge: badge,
        selected: page == target,
        onTap: () => browser.toggleSidePanel(target),
      );
    }

    return SizedBox(
      width: 48,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          railButton(SidePanel.bookmarks, Icons.star_border_rounded,
              'Bookmarks'),
          railButton(SidePanel.history, Icons.history_rounded,
              'History (Ctrl+H)'),
          railButton(SidePanel.downloads, Icons.download_rounded,
              'Downloads (Ctrl+J)'),
          railButton(SidePanel.reading, Icons.auto_stories_outlined,
              'Reading list',
              badge: profile.unreadReadingCount),
          const Spacer(),
          railButton(SidePanel.privacy, Icons.shield_outlined,
              'Privacy dashboard'),
          railButton(SidePanel.settings, Icons.settings_outlined, 'Settings'),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile
// ---------------------------------------------------------------------------

class MobileShell extends StatelessWidget {
  const MobileShell({super.key});

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final palette = pal(context);
    final privacy = context.watch<PrivacyProvider>();
    final tab = browser.current;

    final blocked = tab.onSpeedDial
        ? 0
        : privacy.blockedFor(tab.host);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (tab.canBack) {
          browser.goBack();
        } else if (!tab.onSpeedDial) {
          browser.goHome();
        } else if (browser.tabCount > 1) {
          browser.closeCurrent();
        } else {
          SystemNavigator.pop();
        }
      },
      child: SafeArea(
        child: Column(
          children: [
            const PermissionBanner(),
            if (tab.incognito)
              Container(
                width: double.infinity,
                color: palette.surfaceAlt,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  children: [
                    Icon(Icons.shield_rounded, size: 14, color: palette.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Private tab — nothing is saved',
                        style: Ui.text(palette, size: Ui.sizeSmall),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => browser.newTab(incognito: true),
                      child: const Text('New private tab'),
                    ),
                  ],
                ),
              ),
            UiProgressLine(active: tab.loading, progress: tab.progress),
            const Expanded(child: ViewStack()),
            if (browser.findOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                child: FindBar(compact: true),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: _MobileDock(tab: tab, blocked: blocked),
            ),
          ],
        ),
      ),
    );
  }
}

/// The phone's whole control surface: address, then one row of actions, in a
/// single rounded dock so nothing floats over the page.
class _MobileDock extends StatelessWidget {
  const _MobileDock({required this.tab, required this.blocked});

  final BrowserTab tab;
  final int blocked;

  @override
  Widget build(BuildContext context) {
    final browser = context.read<BrowserProvider>();
    final p = pal(context);

    return Container(
      decoration: Ui.card(p),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: Omnibox(compact: true),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 4),
            child: Row(
              children: [
                _Key(
                  icon: Icons.arrow_back_ios_new_rounded,
                  enabled: tab.canBack,
                  onTap: browser.goBack,
                ),
                _Key(
                  icon: Icons.arrow_forward_ios_rounded,
                  enabled: tab.canForward,
                  onTap: browser.goForward,
                ),
                _Key(
                  icon: tab.loading ? Icons.close_rounded : Icons.refresh_rounded,
                  onTap: tab.loading ? browser.stopLoading : browser.reload,
                ),
                _Key(
                  icon: Icons.shield_outlined,
                  badge: blocked,
                  onTap: () => showSiteInfoSheet(context),
                ),
                _TabKey(
                  count: browser.tabCount,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      fullscreenDialog: true,
                      builder: (_) => const TabSwitcherPage(),
                    ),
                  ),
                ),
                _Key(
                  icon: Icons.more_horiz_rounded,
                  onTap: () => showMobileMenu(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.onTap,
    this.icon,
    this.enabled = true,
    this.badge = 0,
  });

  final VoidCallback onTap;
  final IconData? icon;
  final bool enabled;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: UiIconButton(
          icon: icon ?? Icons.close_rounded,
          size: 44,
          iconSize: 20,
          badge: badge,
          onTap: enabled ? onTap : null,
        ),
      ),
    );
  }
}

class _TabKey extends StatelessWidget {
  const _TabKey({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return Expanded(
      child: Center(
        child: UiHoverable(
          onTap: onTap,
          builder: (context, hovering, pressed) => AnimatedContainer(
            duration: Ui.quick,
            curve: Ui.curve,
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: hovering || pressed ? p.hoverFill : Colors.transparent,
              borderRadius: BorderRadius.circular(Ui.rControl),
              border: Border.all(color: p.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.grid_view_rounded, size: 16, color: p.textDim),
                Ui.gap(6),
                Text('$count',
                    style: Ui.text(p, size: Ui.sizeSmall, weight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


