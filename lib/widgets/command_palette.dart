import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'icons.dart';

import '../core/pal.dart';
import '../core/palette.dart';
import '../core/ui.dart';
import '../pages/bookmarks_page.dart';
import '../pages/downloads_page.dart';
import '../pages/history_page.dart';
import '../pages/privacy_page.dart';
import '../pages/files_page.dart';
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
  final Object icon;
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
      _Command('New tab', 'Ctrl+T', 'plus', (_) => browser.newTab()),
      _Command('New private tab', 'Ctrl+Shift+N', 'shield',
          (_) => browser.newTab(incognito: true)),
      _Command('Close current tab', 'Ctrl+W', 'close',
          (_) => browser.closeCurrent()),
      _Command('Find in page', 'Ctrl+F', 'find',
          (_) => browser.openFind()),
      _Command('Open files', '', 'folder', (_) => openPanelOrRoute(
            SidePanel.files, const FilesRoute())),
      _Command('Reader view', '', 'reading-list', (_) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ReaderPage()),
        );
      }),
      _Command(
          'Add to speed dial', '', 'grid', (_) => profile
              .toggleSpeedDial(
                  url: tab.url,
                  title: tab.title.isEmpty ? tab.host : tab.title)),
      _Command('Save to reading list', '', 'reader',
          (_) => profile.addReading(url: tab.url, title: tab.title)),
      _Command('Bookmark this page', 'Ctrl+D', 'star-on',
          (_) => profile.toggleBookmark(url: tab.url, title: tab.title)),
      _Command('Downloads', 'Ctrl+J', 'download',
          (_) => openPanelOrRoute(
              SidePanel.downloads, const DownloadsRoute())),
      _Command('History', 'Ctrl+H', 'clock',
          (_) => openPanelOrRoute(SidePanel.history, const HistoryRoute())),
      _Command('Bookmarks', '', 'bookmarks',
          (_) => openPanelOrRoute(
              SidePanel.bookmarks, const BookmarksRoute())),
      _Command('Reading list', '', 'reader',
          (_) => openPanelOrRoute(
              SidePanel.reading, const ReadingRoute())),
      _Command('Privacy dashboard', '', 'shield-on',
          (_) => openPanelOrRoute(
              SidePanel.privacy, const PrivacyRoute())),
      _Command('Settings', '', 'sliders',
          (_) => openPanelOrRoute(
              SidePanel.settings, const SettingsRoute())),
      _Command('Theme: System', '', 'auto',
          (_) => settings.setThemeChoice(ThemeChoice.system)),
      _Command('Theme: Light', '', 'sun',
          (_) => settings.setThemeChoice(ThemeChoice.light)),
      _Command('Theme: Dark', '', 'moon',
          (_) => settings.setThemeChoice(ThemeChoice.dark)),
      _Command('Theme: Red', '', 'flame',
          (_) => settings.setThemeChoice(ThemeChoice.red)),
      _Command('Theme: Green', '', 'leaf',
          (_) => settings.setThemeChoice(ThemeChoice.green)),
      _Command('Theme: Black & White', '', 'contrast',
          (_) => settings.setThemeChoice(ThemeChoice.mono)),
      _Command('Theme: Custom picture', '', 'image',
          (_) => settings.setThemeChoice(ThemeChoice.custom)),
      _Command('Toggle ad blocking', '', 'block',
          (_) => settings.setBlockAds(!settings.blockAds)),
      _Command('Reload page', 'Ctrl+R', 'reload',
          (_) => browser.reload()),
      _Command('New tab page', '', 'home', (_) => browser.goHome()),
      if (desktop) ...[
        _Command('Toggle split view', '', 'split',
            (_) => browser.splitActive
                ? browser.closeSplit()
                : browser.openSplit()),
        _Command('Toggle vertical tabs', '', 'list',
            (_) => settings.setVerticalTabs(!settings.verticalTabs)),
        _Command(
            'Toggle bookmarks bar', '', 'bookmark', (_) {
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
                        uiGlyph('search', size: 19, color: palette.textDim),
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
                          icon: uiGlyph('close',
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
                                      uiGlyph(cmd.icon,
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
