import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'icons.dart';

import '../core/pal.dart';
import '../core/ui.dart';
import '../pages/bookmarks_page.dart';
import '../pages/downloads_page.dart';
import '../pages/files_page.dart';
import '../pages/history_page.dart';
import '../pages/privacy_page.dart';
import '../pages/reader_page.dart';
import '../pages/reading_list_page.dart';
import '../pages/settings_page.dart';
import '../state/browser_provider.dart';
import '../state/profile_provider.dart';
import '../state/settings_provider.dart';
import 'logo.dart';

class _Entry {
  const _Entry(this.id, this.icon, this.label, {this.checkable = false});
  final String id;
  final Object icon;
  final String label;
  final bool checkable;
}

/// Everything the ⋯ / ⋮ menu can do — shared by desktop & mobile.
List<_Entry> _entriesFor(BuildContext context) {
  final browser = context.read<BrowserProvider>();
  final settings = context.read<SettingsProvider>();
  final profile = context.read<ProfileProvider>();
  final tab = browser.current;
  final wide = MediaQuery.sizeOf(context).width >= 840;
  final onDial = tab.onSpeedDial;

  final dialAdded = !onDial && profile.isOnSpeedDial(tab.url);
  final bookmarked = !onDial && profile.isBookmarked(tab.url);
  final onReadingList = !onDial && profile.onReadingList(tab.url);

  return [
    _Entry('new_tab', 'plus', 'New tab'),
    _Entry('new_incognito', 'shield', 'New private tab'),
    const _Entry('div1', 'rule', ''),
    _Entry('bookmark', 'star-on',
        bookmarked ? 'Remove bookmark' : 'Bookmark this page'),
    _Entry('speed_dial', 'grid',
        dialAdded ? 'Remove from speed dial' : 'Add to speed dial'),
    _Entry(
        'reading_list',
        'reader',
        onReadingList
            ? 'Saved — open reading list'
            : 'Read later'),
    if (!onDial) const _Entry('reader', 'reading-list', 'Reader view'),
    const _Entry('div2', 'rule', ''),
    const _Entry('bookmarks', 'bookmarks', 'Bookmarks'),
    const _Entry('history', 'clock', 'History'),
    const _Entry('downloads', 'download', 'Downloads'),
    const _Entry('files', 'folder', 'Files'),
    const _Entry('privacy', 'shield-on', 'Privacy dashboard'),
    const _Entry('div3', 'rule', ''),
    const _Entry('find', 'find', 'Find in page'),
    if (wide) ...[
      const _Entry('split', 'split', 'Split view'),
      const _Entry('palette', 'bolt', 'Quick actions  (Ctrl+K)'),
      const _Entry('print', 'print', 'Print page'),
    ],
    _Entry('block_ads', 'block', 'Block ads & pop-ups',
        checkable: settings.blockAds),
    if (!Platform.isWindows)
      _Entry('desktop_site', 'monitor', 'Desktop site',
          checkable: settings.desktopMode),
    if (wide)
      _Entry('bookmarks_bar', 'bookmark', 'Bookmarks bar',
          checkable: settings.showBookmarksBar),
    if (wide)
      _Entry('vertical_tabs', 'list', 'Vertical tabs',
          checkable: settings.verticalTabs),
    const _Entry('div4', 'rule', ''),
    const _Entry('settings', 'sliders', 'Settings'),
    const _Entry('about', 'info', 'About'),
  ];
}

Future<void> runMenuAction(BuildContext context, String id) async {
  final browser = context.read<BrowserProvider>();
  final settings = context.read<SettingsProvider>();
  final profile = context.read<ProfileProvider>();
  final tab = browser.current;
  final wide = MediaQuery.sizeOf(context).width >= 840;
  final navigator = Navigator.of(context);

  void openPanelOrRoute(Widget route, SidePanel panel) {
    if (wide) {
      browser.setSidePanel(panel);
    } else {
      navigator.push(MaterialPageRoute<void>(builder: (_) => route));
    }
  }

  switch (id) {
    case 'new_tab':
      browser.newTab();
    case 'new_incognito':
      browser.newTab(incognito: true);
    case 'bookmark':
      final added = profile.toggleBookmark(url: tab.url, title: tab.title);
      _snack(context, added ? 'Bookmark added' : 'Bookmark removed');
    case 'speed_dial':
      final added = profile.toggleSpeedDial(
        url: tab.url,
        title: tab.title.isEmpty ? tab.host : tab.title,
      );
      _snack(
        context,
        added ? 'Added to speed dial' : 'Removed from speed dial',
      );
    case 'reading_list':
      if (profile.onReadingList(tab.url)) {
        openPanelOrRoute(const ReadingRoute(), SidePanel.reading);
      } else {
        profile.addReading(url: tab.url, title: tab.title);
        _snack(context, 'Saved to reading list');
      }
    case 'reader':
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const ReaderPage()),
      );
    case 'bookmarks':
      openPanelOrRoute(const BookmarksRoute(), SidePanel.bookmarks);
    case 'history':
      openPanelOrRoute(const HistoryRoute(), SidePanel.history);
    case 'downloads':
      openPanelOrRoute(const DownloadsRoute(), SidePanel.downloads);
    case 'files':
      openPanelOrRoute(const FilesRoute(), SidePanel.files);
    case 'privacy':
      openPanelOrRoute(const PrivacyRoute(), SidePanel.privacy);
    case 'find':
      browser.openFind();
    case 'split':
      browser.splitActive ? browser.closeSplit() : browser.openSplit();
    case 'palette':
      browser.openPalette();
    case 'print':
      try {
        await tab.controller?.printCurrentPage();
      } catch (_) {
        if (!context.mounted) return;
        _snack(context, 'Printing is not available for this page');
      }
    case 'block_ads':
      settings.setBlockAds(!settings.blockAds);
    case 'desktop_site':
      settings.setDesktopMode(!settings.desktopMode);
      await browser.refreshWebViews();
    case 'bookmarks_bar':
      settings.setShowBookmarksBar(!settings.showBookmarksBar);
    case 'vertical_tabs':
      settings.setVerticalTabs(!settings.verticalTabs);
    case 'settings':
      openPanelOrRoute(const SettingsRoute(), SidePanel.settings);
    case 'about':
      showAboutDialog(
        context: context,
        applicationName: 'Interface Browser',
        applicationVersion: '2.0.0',
        applicationLegalese:
            'A fast, themeable browser for phones and laptops.',
        applicationIcon: const LogoMark(size: 44),
      );
  }
}

void _snack(BuildContext context, String msg) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
  );
}

/// The desktop ⋯ popup button.
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key, required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    final entries = _entriesFor(context);
    return PopupMenuButton<String>(
      tooltip: 'Menu',
      color: palette.surface,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: palette.isDark ? 0.5 : 0.14),
      constraints: const BoxConstraints(minWidth: 272),
      padding: const EdgeInsets.symmetric(vertical: 6),
      icon: uiGlyph('dots', color: palette.text, size: 22),
      shape: RoundedRectangleBorder(
        borderRadius: Ui.petal(Ui.rMenu, at: UiCorner.topLeft),
        side: BorderSide(color: palette.border),
      ),
      itemBuilder: (_) => [
        for (final e in entries)
          if (e.label.isEmpty)
            const PopupMenuDivider()
          else
            PopupMenuItem(
              value: e.id,
              height: Ui.menuRowHeight,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  uiGlyph(e.icon,
                      size: 17,
                      color: e.checkable ? palette.accent : palette.textDim),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      e.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ui.text(
                        palette,
                        color: palette.text,
                        weight: e.checkable ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (e.checkable)
                    uiGlyph('check',
                        size: 16, color: palette.accent),
                ],
              ),
            ),
      ],
      onSelected: (id) => runMenuAction(context, id),
    );
  }
}

/// The mobile ⋮ bottom sheet.
Future<void> showMobileMenu(BuildContext context) {
  final palette = pal(context);
  final entries = _entriesFor(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: palette.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            for (final e in entries)
              if (e.label.isEmpty)
                Divider(color: palette.border, height: 1)
              else
                ListTile(
                  dense: true,
                  leading: uiGlyph(
                    e.icon,
                    color: e.checkable ? palette.accent : palette.textDim,
                  ),
                  title: Text(
                    e.label,
                    style: TextStyle(color: palette.text, fontSize: 14.5),
                  ),
                  trailing: e.checkable
                      ? uiGlyph('check',
                          size: 18, color: palette.accent)
                      : null,
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    Future.microtask(() {
                      if (context.mounted) runMenuAction(context, e.id);
                    });
                  },
                ),
          ],
        ),
      );
    },
  );
}
