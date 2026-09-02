import 'dart:io' show File, Platform;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../core/palette.dart';
import '../core/urls.dart';
import '../state/browser_provider.dart';
import '../state/profile_provider.dart';
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
                'Render pages in pure black & white in this theme'),
            value: settings.grayscaleInMono,
            onChanged: settings.setGrayscaleInMono,
          ),
        if (desktop)
          SwitchListTile(
            title: const Text('Show bookmarks bar'),
            value: settings.showBookmarksBar,
            onChanged: settings.setShowBookmarksBar,
          ),
        _Section(title: 'Search & startup'),
        for (final engine in SearchEngine.all)
          RadioListTile<String>(
            dense: true,
            title: Text(engine.name),
            subtitle: Text(displayUrl(engine.homepage)),
            value: engine.id,
            groupValue: settings.searchEngineId,
            onChanged: (v) => settings.setSearchEngine(v ?? engine.id),
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
              'Built-in blocklist of common ad, tracker and pop-under hosts'),
          value: settings.blockAds,
          onChanged: settings.setBlockAds,
        ),
        if (!Platform.isWindows)
          SwitchListTile(
            title: const Text('Desktop site'),
            subtitle:
                const Text('Request desktop versions of websites (phone)'),
            value: settings.desktopMode,
            onChanged: (v) async {
              settings.setDesktopMode(v);
              await context
                  .read<BrowserProvider>()
                  .refreshWebViews();
            },
          ),
        const Divider(indent: 16, endIndent: 16),
        ListTile(
          leading: Icon(Icons.cleaning_services_outlined,
              color: palette.danger),
          title: const Text('Clear browsing data'),
          subtitle: const Text('History, cookies and cache'),
          onTap: () => _clearBrowsingData(context),
        ),
        _Section(title: 'About'),
        const ListTile(
          leading: LogoMark(size: 34),
          title: Text('Interface Browser'),
          subtitle: Text('Version 1.0.0 · Flutter + WebView'),
        ),
        ListTile(
          leading: Icon(Icons.description_outlined, color: palette.textDim),
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

  Future<void> _clearBrowsingData(BuildContext context) async {
    final palette = pal(context);
    final profile = context.read<ProfileProvider>();
    final browser = context.read<BrowserProvider>();
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
      for (final tab in browser.tabs) {
        try {
          await tab.controller?.clearCache();
        } catch (_) {}
      }
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
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: palette.textDim,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.9,
        ),
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
      borderRadius: BorderRadius.circular(13),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? palette.accent : palette.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(choice.icon,
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
                  Icon(Icons.check_circle_rounded,
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
                  errorBuilder: (_, __, ___) => Container(
                    width: 74,
                    height: 48,
                    color: palette.surfaceAlt,
                    child: Icon(Icons.broken_image_outlined,
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
                child: Icon(Icons.image_outlined, color: palette.textDim),
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
                icon: const Icon(Icons.photo_library_outlined, size: 17),
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
        RadioListTile<bool>(
          dense: true,
          title: const Text('Homepage: Speed dial'),
          subtitle: const Text('Opera-style start page with your favorites'),
          value: true,
          groupValue: useDial,
          onChanged: (_) => settings.setHomePage(''),
        ),
        RadioListTile<bool>(
          dense: true,
          title: const Text('Homepage: custom page'),
          value: false,
          groupValue: useDial,
          onChanged: (_) {
            final parsed = urlFromInput(_controller.text);
            if (parsed != null && isWebScheme(parsed)) {
              settings.setHomePage(parsed.toString());
            } else {
              settings.setHomePage('');
            }
          },
        ),
        if (!useDial)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: TextField(
              controller: _controller,
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Address, e.g. example.com',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 19),
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
