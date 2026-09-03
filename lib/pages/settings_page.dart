import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../widgets/icons.dart';

import '../core/pal.dart';
import '../core/ui.dart';
import '../core/urls.dart';
import '../state/browser_provider.dart';
import '../state/profile_provider.dart';
import '../pages/privacy_page.dart';
import '../state/settings_provider.dart';
import '../widgets/logo.dart';

/// All settings — embeddable in the desktop side panel.
class SettingsBody extends StatelessWidget {
  const SettingsBody({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final palette = pal(context);
    final desktop = MediaQuery.sizeOf(context).width >= 840;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      children: [
        _Section(title: 'Appearance'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _ThemeGrid(settings: settings, palette: palette),
        ),
        if (settings.themeChoice == ThemeChoice.custom)
          _WallpaperCard(settings: settings, palette: palette),
        if (settings.themeChoice == ThemeChoice.mono)
          SwitchListTile(
            title: const Text('Desaturate web content'),
            subtitle: const Text(
                'Show web pages without colour'),
            value: settings.grayscaleInMono,
            onChanged: settings.setGrayscaleInMono,
          ),
        if (desktop) ...[
          SwitchListTile(
            title: const Text('Show bookmarks bar'),
            value: settings.showBookmarksBar,
            onChanged: settings.setShowBookmarksBar,
          ),
          SwitchListTile(
            title: const Text('Vertical tabs'),
            subtitle: const Text('Show tabs in a side rail instead of on top'),
            value: settings.verticalTabs,
            onChanged: settings.setVerticalTabs,
          ),
        ],
        ListTile(
          leading: uiGlyph('text', color: palette.textDim),
          title: Text('Text size',
              style: TextStyle(color: palette.text, fontSize: 14)),
          subtitle: Slider(
            value: settings.fontScale,
            min: 0.85,
            max: 1.3,
            divisions: 9,
            label: '${(settings.fontScale * 100).round()}%',
            activeColor: palette.accent,
            onChanged: settings.setFontScale,
          ),
          trailing: Text(
            '${(settings.fontScale * 100).round()}%',
            style: TextStyle(color: palette.textDim, fontSize: 12.5),
          ),
        ),
        _Section(title: 'Reading'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              for (final t in ReaderTheme.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(switch (t) {
                      ReaderTheme.paper => 'Paper',
                      ReaderTheme.sepia => 'Sepia',
                      ReaderTheme.night => 'Night',
                    }),
                    selected: settings.readerTheme == t,
                    onSelected: (_) => settings.setReaderTheme(t),
                  ),
                ),
            ],
          ),
        ),
        ListTile(
          leading:
              uiGlyph('text', color: palette.textDim),
          title: Text('Reader text size',
              style: TextStyle(color: palette.text, fontSize: 14)),
          subtitle: Slider(
            value: settings.readerFontSize,
            min: 14,
            max: 26,
            divisions: 12,
            label: '${settings.readerFontSize.round()}',
            activeColor: palette.accent,
            onChanged: settings.setReaderFontSize,
          ),
          trailing: Text(
            '${settings.readerFontSize.round()}',
            style: TextStyle(color: palette.textDim, fontSize: 12.5),
          ),
        ),
        _Section(title: 'Search & startup'),
        RadioGroup<String>(
          groupValue: settings.searchEngineId,
          onChanged: (v) => settings.setSearchEngine(v ?? settings.searchEngineId),
          child: Column(
            children: [
              for (final engine in SearchEngine.all)
                RadioListTile<String>(
                  dense: true,
                  title: Text(engine.name),
                  subtitle: Text(displayUrl(engine.homepage)),
                  value: engine.id,
                ),
            ],
          ),
        ),
        const Divider(indent: 16, endIndent: 16),
        const _HomepagePicker(),
        SwitchListTile(
          title: const Text('Restore tabs on startup'),
          subtitle: const Text('Reopen the tabs from your last session'),
          value: settings.restoreSession,
          onChanged: settings.setRestoreSession,
        ),
        _Section(title: 'Privacy & content'),
        SwitchListTile(
          title: const Text('Block ads & pop-ups'),
          subtitle: const Text(
              'Blocks common ads and trackers before they load'),
          value: settings.blockAds,
          onChanged: settings.setBlockAds,
        ),
        if (!Platform.isWindows)
          SwitchListTile(
            title: const Text('Desktop site'),
            subtitle:
                const Text('Ask sites for their desktop layout'),
            value: settings.desktopMode,
            onChanged: (v) async {
              settings.setDesktopMode(v);
              await context
                  .read<BrowserProvider>()
                  .refreshWebViews();
            },
          ),
        ListTile(
          leading: uiGlyph('shield-on', color: palette.accent),
          title: const Text('Privacy dashboard'),
          subtitle:
              const Text('See what was blocked and set rules per site'),
          onTap: () => _openPrivacy(context),
        ),
        const Divider(indent: 16, endIndent: 16),
        ListTile(
          leading: uiGlyph('sparkle',
              color: palette.danger),
          title: const Text('Clear browsing data'),
          subtitle: const Text('History, cookies and cache'),
          onTap: () => _clearBrowsingData(context),
        ),
        _Section(title: 'About'),
        const ListTile(
          leading: LogoMark(size: 34),
          title: Text('Interface Browser'),
          subtitle: Text('Version 2.0.0'),
        ),
        ListTile(
          leading: uiGlyph('sparkle', color: palette.textDim),
          title: const Text('Replay welcome tour'),
          onTap: () => settings.setOnboardingSeen(false),
        ),
        ListTile(
          leading: uiGlyph('file-text', color: palette.textDim),
          title: const Text('Open-source licenses'),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'Interface Browser',
            applicationIcon: const LogoMark(size: 44),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _openPrivacy(BuildContext context) {
    final browser = context.read<BrowserProvider>();
    if (MediaQuery.sizeOf(context).width >= 840) {
      browser.setSidePanel(SidePanel.privacy);
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const PrivacyRoute()));
    }
  }

  Future<void> _clearBrowsingData(BuildContext context) async {
    final palette = pal(context);
    final profile = context.read<ProfileProvider>();
    var clearHistory = true;
    var clearCookies = true;
    var clearCache = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d2, setState) => AlertDialog(
          title: const Text('Clear browsing data'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                value: clearHistory,
                onChanged: (v) => setState(() => clearHistory = v ?? false),
                title: const Text('Browsing history'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: clearCookies,
                onChanged: (v) => setState(() => clearCookies = v ?? false),
                title: const Text('Cookies & site data'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                value: clearCache,
                onChanged: (v) => setState(() => clearCache = v ?? false),
                title: const Text('Cached files'),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(d2).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: palette.accent),
              onPressed: () => Navigator.of(d2).pop(true),
              child: const Text('Clear now'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !(context.mounted)) return;

    if (clearHistory) profile.clearHistory();
    if (clearCookies) {
      try {
        await CookieManager.instance().deleteAllCookies();
      } catch (e) {
        debugPrint('cookie clear: $e');
      }
    }
    if (clearCache) {
      try {
        await InAppWebViewController.clearAllCache();
      } catch (_) {}
    }
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Browsing data cleared')),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: Ui.text(palette, size: 14, weight: FontWeight.w700),
      ),
    );
  }
}

class _ThemeGrid extends StatelessWidget {
  const _ThemeGrid({required this.settings, required this.palette});

  final SettingsProvider settings;
  final BrowserPalette palette;

  BrowserPalette _preview(ThemeChoice choice) =>
      BrowserPalette.resolve(choice, Brightness.dark);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 560 ? 4 : 2;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.35,
          children: [
            for (final choice in ThemeChoice.values)
              _ThemeCard(
                choice: choice,
                selected: settings.themeChoice == choice,
                preview: _preview(choice),
                onTap: () => settings.setThemeChoice(choice),
              ),
          ],
        );
      },
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.choice,
    required this.selected,
    required this.preview,
    required this.onTap,
  });

  final ThemeChoice choice;
  final bool selected;
  final BrowserPalette preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Ui.rCard),
      child: AnimatedContainer(
        duration: Ui.quick,
        curve: Ui.curve,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? palette.activeFill : palette.surface,
          borderRadius: BorderRadius.circular(Ui.rCard),
          border: Border.all(
            color: selected ? palette.accent : palette.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                uiGlyph(choice.icon,
                    size: 16,
                    color: selected ? palette.accent : palette.textDim),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    choice.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                      color: palette.text,
                    ),
                  ),
                ),
                if (selected)
                  uiGlyph('check-circle',
                      size: 16, color: palette.accent),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                _swatch(preview.background),
                const SizedBox(width: 5),
                _swatch(preview.surface),
                const SizedBox(width: 5),
                _swatch(preview.primary),
                const SizedBox(width: 5),
                _swatch(preview.accent),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _swatch(Color c) => Container(
        width: 17,
        height: 17,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 0.5),
        ),
      );
}

class _WallpaperCard extends StatelessWidget {
  const _WallpaperCard({required this.settings, required this.palette});

  final SettingsProvider settings;
  final BrowserPalette palette;

  Future<void> _pick(BuildContext context) async {
    final res = await FilePicker.pickFiles(
      type: FileType.image,
      dialogTitle: 'Choose a background picture',
    );
    final path = res.isEmpty ? null : res.first.path;
    if (path == null || !context.mounted) return;
    final saved = await settings.setCustomBackground(path);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(saved != null
            ? 'Wallpaper applied'
            : 'Could not use that picture'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final has = settings.hasCustomBackground;
    return Card(
      elevation: 0,
      color: palette.surface,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(color: palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (has && settings.customBgPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(settings.customBgPath!),
                  width: 74,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 74,
                    height: 48,
                    color: palette.surfaceAlt,
                    child: uiGlyph('image',
                        color: palette.textDim),
                  ),
                ),
              )
            else
              Container(
                width: 74,
                height: 48,
                decoration: BoxDecoration(
                  color: palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: uiGlyph('image', color: palette.textDim),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom background',
                    style: TextStyle(
                      color: palette.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    has
                        ? 'Your picture sits behind frosted-glass chrome'
                        : 'Pick any picture from this device',
                    style: TextStyle(color: palette.textDim, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (has)
              TextButton(
                onPressed: () => settings.clearCustomBackground(),
                child: const Text('Remove'),
              )
            else
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: palette.onAccent,
                ),
                onPressed: () => _pick(context),
                icon: uiGlyph('images', size: 17),
                label: const Text('Choose'),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomepagePicker extends StatefulWidget {
  const _HomepagePicker();

  @override
  State<_HomepagePicker> createState() => _HomepagePickerState();
}

class _HomepagePickerState extends State<_HomepagePicker> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _controller = TextEditingController(
      text: settings.homePage.isEmpty ? '' : displayUrl(settings.homePage),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final useDial = settings.homePage.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RadioGroup<bool>(
          groupValue: useDial,
          onChanged: (v) {
            if (v != false) {
              settings.setHomePage('');
              return;
            }
            final parsed = urlFromInput(_controller.text);
            if (parsed != null && isWebScheme(parsed)) {
              settings.setHomePage(parsed.toString());
            } else {
              settings.setHomePage('');
            }
          },
          child: Column(
            children: [
              RadioListTile<bool>(
                dense: true,
                title: const Text('New tab page'),
                subtitle: const Text('Your shortcuts and a search box'),
                value: true,
              ),
              RadioListTile<bool>(
                dense: true,
                title: const Text('Custom page'),
                value: false,
              ),
            ],
          ),
        ),
        if (!useDial)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: TextField(
              spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
              controller: _controller,
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Address, e.g. example.com',
                suffixIcon: IconButton(
                  icon: uiGlyph('forward', size: 19),
                  onPressed: () {
                    final parsed = urlFromInput(_controller.text);
                    if (parsed != null) {
                      settings.setHomePage(parsed.toString());
                    }
                  },
                ),
              ),
              onSubmitted: (v) {
                final parsed = urlFromInput(v);
                if (parsed != null) settings.setHomePage(parsed.toString());
              },
            ),
          ),
      ],
    );
  }
}

/// Full-page route.
class SettingsRoute extends StatelessWidget {
  const SettingsRoute({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      backgroundColor: palette.background,
      body: const SettingsBody(),
    );
  }
}
