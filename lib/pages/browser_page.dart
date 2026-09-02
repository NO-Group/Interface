import 'dart:io' show File, Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../services/web_engine.dart';
import '../state/browser_provider.dart';
import '../state/settings_provider.dart';
import '../widgets/app_menu.dart';
import '../widgets/find_bar.dart';
import '../widgets/omnibox.dart';
import '../widgets/tab_strip.dart';
import '../widgets/tab_switcher.dart';
import '../widgets/toolbar.dart';
import '../widgets/view_stack.dart';
import 'bookmarks_page.dart';
import 'downloads_page.dart';
import 'history_page.dart';
import 'settings_page.dart';

/// Root of the browser UI. Picks the desktop or mobile shell, paints the
/// custom wallpaper layer, handles fullscreen video.
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
      color: const Color(0xFF7A1F1F),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.warning_amber_rounded, color: Colors.white),
        title: const Text(
          'WebView2 runtime missing — install it from Microsoft to browse.',
          style: TextStyle(color: Colors.white, fontSize: 12.5),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop (Chrome tabs + Opera sidebar)
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
        const SingleActivator(LogicalKeyboardKey.keyD, control: true):
            browser.requestOmniboxFocus,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            browser.openFind,
        const SingleActivator(LogicalKeyboardKey.keyR, control: true):
            () => browser.reload(),
        const SingleActivator(LogicalKeyboardKey.f5): () => browser.reload(),
        const SingleActivator(LogicalKeyboardKey.keyH, control: true): () =>
            browser.toggleSidePanel(SidePanel.history),
        const SingleActivator(LogicalKeyboardKey.keyJ, control: true): () =>
            browser.toggleSidePanel(SidePanel.downloads),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true):
            () => browser.goBack(),
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
            () => browser.goForward(),
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (browser.findOpen) browser.closeFind();
        },
        for (var i = 1; i <= 8; i++)
          SingleActivator(
            LogicalKeyboardKey digitCode(i),
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
                const TabStrip(),
                const DesktopToolbar(),
                if (settings.showBookmarksBar) const BookmarksBar(),
                Container(height: 1, color: palette.border),
                Expanded(
                  child: Row(
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.centerLeft,
                        clipBehavior: Clip.hardEdge,
                        child: browser.sidePanel == SidePanel.none
                            ? const SizedBox.shrink()
                            : const SizedBox(
                                width: 356, child: _SidePanel()),
                      ),
                      const Expanded(child: ViewStack()),
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
          ],
        ),
      ),
    );
  }

  static LogicalKeyboardKey digitCode(int n) {
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

/// Opera-style sidebar with the library pages.
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
                height: 44,
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: Text(
                        title,
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.chevron_left_rounded,
                          color: palette.textDim),
                      onPressed: () => browser.setSidePanel(SidePanel.none),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: palette.border),
              Expanded(
                child: switch (page) {
                  SidePanel.bookmarks => const BookmarksList(embedded: true),
                  SidePanel.history => const HistoryList(embedded: true),
                  SidePanel.downloads => const DownloadsList(embedded: true),
                  SidePanel.settings => const SettingsBody(),
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
    final palette = pal(context);

    Widget railButton(SidePanel target, IconData icon, String tip) {
      final active = page == target;
      return Tooltip(
        message: tip,
        waitDuration: const Duration(milliseconds: 500),
        child: InkWell(
          onTap: () => browser.toggleSidePanel(target),
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 130),
            margin: const EdgeInsets.all(6),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: active ? palette.accent.withValues(alpha: 0.16) : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 20,
              color: active ? palette.accent : palette.textDim,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: 46,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          railButton(SidePanel.bookmarks, Icons.star_border_rounded, 'Bookmarks (Ctrl+Shift+B)'),
          railButton(SidePanel.history, Icons.history_rounded, 'History (Ctrl+H)'),
          railButton(SidePanel.downloads, Icons.download_rounded, 'Downloads (Ctrl+J)'),
          const Spacer(),
          railButton(SidePanel.settings, Icons.settings_outlined, 'Settings'),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mobile (Opera bottom bar + Chrome grid)
// ---------------------------------------------------------------------------

class MobileShell extends StatelessWidget {
  const MobileShell({super.key});

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final palette = pal(context);
    final tab = browser.current;

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
            if (tab.incognito)
              Container(
                width: double.infinity,
                color: const Color(0xFF171B21),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                child: Row(
                  children: [
                    const Icon(Icons.shield_rounded,
                        size: 15, color: Color(0xFF8AB4F8)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Incognito — history is not saved',
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => browser.newTab(),
                      child: Text(
                        'New tab',
                        style: TextStyle(
                          color: palette.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: tab.loading ? 3 : 0,
              child: LinearProgressIndicator(
                value: tab.progress / 100,
                minHeight: 3,
                backgroundColor: Colors.transparent,
                color: palette.accent,
              ),
            ),
            const Expanded(child: ViewStack()),
            if (browser.findOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                child: FindBar(compact: true),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Omnibox(compact: true),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: Row(
                children: [
                  _NavButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    enabled: tab.canBack,
                    onTap: () => browser.goBack(),
                  ),
                  _NavButton(
                    icon: Icons.arrow_forward_ios_rounded,
                    enabled: tab.canForward,
                    onTap: () => browser.goForward(),
                  ),
                  _NavButton(
                    icon: Icons.home_outlined,
                    onTap: () => browser.goHome(),
                  ),
                  _NavButton(
                    icon: Icons.bookmark_border_rounded,
                    onTap: () => _bookmark(context),
                  ),
                  _TabsButton(
                    count: browser.tabCount,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        fullscreenDialog: true,
                        builder: (_) => const TabSwitcherPage(),
                      ),
                    ),
                  ),
                  _NavButton(
                    icon: Icons.more_vert_rounded,
                    onTap: () => showMobileMenu(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _bookmark(BuildContext context) {
    final browser = context.read<BrowserProvider>();
    final profile = context.read<ProfileProvider>();
    final tab = browser.current;
    if (tab.onSpeedDial || tab.url.isEmpty) return;
    final added = profile.toggleBookmark(url: tab.url, title: tab.title);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(added ? 'Bookmark added' : 'Bookmark removed'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return Expanded(
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: palette.text,
        disabledColor: palette.textDim.withValues(alpha: 0.35),
        onPressed: enabled ? onTap : null,
      ),
    );
  }
}

class _TabsButton extends StatelessWidget {
  const _TabsButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return Expanded(
      child: Center(
        child: IconButton(
          onPressed: onTap,
          icon: Badge.count(
            count: count,
            backgroundColor: palette.accent,
            textColor: palette.onAccent,
            child: Icon(Icons.tabs_rounded, size: 21, color: palette.text),
          ),
        ),
      ),
    );
  }
}
