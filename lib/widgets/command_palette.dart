import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../core/palette.dart';
import '../core/ui.dart';
import '../pages/bookmarks_page.dart';
import '../pages/downloads_page.dart';
import '../pages/history_page.dart';
import '../pages/privacy_page.dart';
import '../pages/reader_page.dart';
import '../pages/reading_list_page.dart';
import '../pages/settings_page.dart';
import '../state/browser_provider.dart';
import '../state/profile_provider.dart';
import '../state/settings_provider.dart';

class _Command {
  const _Command(this.label, this.hint, this.icon, this.run);
  final String label;
  final String hint;
  final IconData icon;
  final void Function(BuildContext) run;
}

/// Quick actions (Ctrl+K): type to find a browser action.
class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key});

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final _controller = TextEditingController();
  String _query = '';
  int _sel = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Command> _commandsFor(BuildContext context) {
    final browser = context.read<BrowserProvider>();
    final settings = context.read<SettingsProvider>();
    final profile = context.read<ProfileProvider>();
    final tab = browser.current;
    final desktop = MediaQuery.sizeOf(context).width >= 840;

    void openPanelOrRoute(SidePanel p, Widget route) {
      if (desktop) {
        browser.setSidePanel(p);
      } else {
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => route));
      }
    }

    return [
      _Command('New tab', 'Ctrl+T', Icons.add_rounded, (_) => browser.newTab()),
      _Command('New private tab', 'Ctrl+Shift+N', Icons.shield_outlined,
          (_) => browser.newTab(incognito: true)),
      _Command('Close current tab', 'Ctrl+W', Icons.close_rounded,
          (_) => browser.closeCurrent()),
      _Command('Find in page', 'Ctrl+F', Icons.find_in_page_rounded,
          (_) => browser.openFind()),
      _Command('Reader view', '', Icons.menu_book_rounded, (_) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ReaderPage()),
        );
      }),
      _Command(
          'Add to speed dial', '', Icons.grid_view_rounded, (_) => profile
              .toggleSpeedDial(
                  url: tab.url,
                  title: tab.title.isEmpty ? tab.host : tab.title)),
      _Command('Save to reading list', '', Icons.auto_stories_outlined,
          (_) => profile.addReading(url: tab.url, title: tab.title)),
      _Command('Bookmark this page', 'Ctrl+D', Icons.star_rounded,
          (_) => profile.toggleBookmark(url: tab.url, title: tab.title)),
      _Command('Downloads', 'Ctrl+J', Icons.download_rounded,
          (_) => openPanelOrRoute(
              SidePanel.downloads, const DownloadsRoute())),
      _Command('History', 'Ctrl+H', Icons.history_rounded,
          (_) => openPanelOrRoute(SidePanel.history, const HistoryRoute())),
      _Command('Bookmarks', '', Icons.bookmarks_outlined,
          (_) => openPanelOrRoute(
              SidePanel.bookmarks, const BookmarksRoute())),
      _Command('Reading list', '', Icons.auto_stories_outlined,
          (_) => openPanelOrRoute(
              SidePanel.reading, const ReadingRoute())),
      _Command('Privacy dashboard', '', Icons.shield_rounded,
          (_) => openPanelOrRoute(
              SidePanel.privacy, const PrivacyRoute())),
      _Command('Settings', '', Icons.settings_outlined,
          (_) => openPanelOrRoute(
              SidePanel.settings, const SettingsRoute())),
      _Command('Theme: System', '', Icons.brightness_auto,
          (_) => settings.setThemeChoice(ThemeChoice.system)),
      _Command('Theme: Light', '', Icons.light_mode_outlined,
          (_) => settings.setThemeChoice(ThemeChoice.light)),
      _Command('Theme: Dark', '', Icons.dark_mode_outlined,
          (_) => settings.setThemeChoice(ThemeChoice.dark)),
      _Command('Theme: Red', '', Icons.local_fire_department_outlined,
          (_) => settings.setThemeChoice(ThemeChoice.red)),
      _Command('Theme: Green', '', Icons.eco_outlined,
          (_) => settings.setThemeChoice(ThemeChoice.green)),
      _Command('Theme: Black & White', '', Icons.contrast,
          (_) => settings.setThemeChoice(ThemeChoice.mono)),
      _Command('Theme: Custom picture', '', Icons.wallpaper,
          (_) => settings.setThemeChoice(ThemeChoice.custom)),
      _Command('Toggle ad blocking', '', Icons.block_rounded,
          (_) => settings.setBlockAds(!settings.blockAds)),
      _Command('Reload page', 'Ctrl+R', Icons.refresh_rounded,
          (_) => browser.reload()),
      _Command('New tab page', '', Icons.home_outlined, (_) => browser.goHome()),
      if (desktop) ...[
        _Command('Toggle split view', '', Icons.vertical_split_rounded,
            (_) => browser.splitActive
                ? browser.closeSplit()
                : browser.openSplit()),
        _Command('Toggle vertical tabs', '', Icons.view_agenda_outlined,
            (_) => settings.setVerticalTabs(!settings.verticalTabs)),
        _Command(
            'Toggle bookmarks bar', '', Icons.bookmark_border_rounded, (_) {
          settings.setShowBookmarksBar(!settings.showBookmarksBar);
        }),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    final browser = context.watch<BrowserProvider>();
    final all = _commandsFor(context);
    final results = _query.isEmpty
        ? all.take(10).toList()
        : all.where((c) => _fuzzy(c.label, _query)).toList();
    if (_sel >= results.length) _sel = results.isEmpty ? 0 : results.length - 1;

    return GestureDetector(
      onTap: browser.closePalette,
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        alignment: Alignment.topCenter,
        padding: EdgeInsets.only(top: MediaQuery.sizeOf(context).height * 0.12),
        child: GestureDetector(
          onTap: () {},
          child: Container(
            width: 540,
            constraints: const BoxConstraints(maxHeight: 440),
            decoration: Ui.floating(palette, radius: Ui.rCard),
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.escape):
                    browser.closePalette,
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                    child: Row(
                      children: [
                        Icon(Icons.search_rounded, size: 19, color: palette.textDim),
                        const SizedBox(width: 11),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            autofocus: true,
                            style: Ui.text(palette, size: 14.5, color: palette.text),
                            cursorColor: palette.accent,
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Search actions',
                              hintStyle: Ui.text(palette, size: 14.5, color: palette.textDim),
                            ),
                            onChanged: (v) =>
                                setState(() { _query = v; _sel = 0; }),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 19, color: palette.textDim),
                          onPressed: browser.closePalette,
                        ),
                      ],
                    ),
                  ),
                  Ui.rule(palette),
                  Flexible(
                    child: results.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Nothing matches that',
                              style: Ui.text(palette, color: palette.textDim),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            itemCount: results.length,
                            itemBuilder: (_, i) {
                              final cmd = results[i];
                              final selected = i == _sel;
                              return InkWell(
                                onTap: () => cmd.run(context),
                                onHover: (h) {
                                  if (h) setState(() => _sel = i);
                                },
                                child: AnimatedContainer(
                                  duration: Ui.quick,
                                  curve: Ui.curve,
                                  height: 42,
                                  margin: const EdgeInsets.symmetric(horizontal: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? palette.activeFill
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(Ui.rControl),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(cmd.icon,
                                          size: 17,
                                          color: selected
                                              ? palette.accent
                                              : palette.textDim),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          cmd.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Ui.text(
                                            palette,
                                            weight: selected
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                      if (cmd.hint.isNotEmpty)
                                        Text(
                                          cmd.hint,
                                          style: Ui.text(
                                            palette,
                                            size: Ui.sizeCaption,
                                            color: palette.textFaint,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _fuzzy(String label, String query) {
    final l = label.toLowerCase();
    final q = query.toLowerCase();
    if (l.contains(q)) return true;
    var i = 0;
    for (final ch in l.split('')) {
      if (i < q.length && ch == q[i]) i++;
    }
    return i == q.length;
  }
}
