import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../core/urls.dart';
import '../models.dart';
import '../pages/bookmarks_page.dart';
import '../pages/history_page.dart';
import '../state/browser_provider.dart';
import '../state/profile_provider.dart';
import '../state/settings_provider.dart';
import 'favicon.dart';
import 'logo.dart';

/// Opera-style new tab: clock, big search box and the speed dial grid.
class NewTabPage extends StatefulWidget {
  const NewTabPage({super.key, required this.tab});

  final BrowserTab tab;

  @override
  State<NewTabPage> createState() => _NewTabPageState();
}

class _NewTabPageState extends State<NewTabPage> {
  final _search = TextEditingController();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _go(String value) {
    if (value.trim().isEmpty) return;
    context.read<BrowserProvider>().navigate(value);
  }

  void _openLibrary(
    BuildContext context,
    SidePanel panel,
    Widget route,
  ) {
    final browser = context.read<BrowserProvider>();
    final desktop = MediaQuery.sizeOf(context).width >= 840;
    if (desktop) {
      browser.setSidePanel(panel);
    } else {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => route));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    final settings = context.watch<SettingsProvider>();
    final profile = context.watch<ProfileProvider>();
    final wallpaper = settings.hasCustomBackground;

    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    final date = DateFormatE.format(now);

    return Container(
      color: wallpaper ? Colors.transparent : palette.background,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 640;
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      if (widget.tab.incognito)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: palette.surface.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: palette.border),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.shield_rounded,
                                  size: 16, color: palette.accent),
                              const SizedBox(width: 8),
                              Text(
                                'Incognito — history is not saved',
                                style: TextStyle(
                                    color: palette.text, fontSize: 12.5),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const LogoMark(size: 30),
                            const SizedBox(width: 10),
                            Text(
                              'Interface',
                              style: TextStyle(
                                color: palette.text,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '$hh:$mm',
                          style: TextStyle(
                            color: palette.text.withValues(alpha: 0.94),
                            fontSize: 42,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          date,
                          style: TextStyle(
                              color: palette.textDim, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: TextField(
                          controller: _search,
                          textInputAction: TextInputAction.search,
                          onSubmitted: _go,
                          style: TextStyle(color: palette.text, fontSize: 15),
                          cursorColor: palette.accent,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor:
                                palette.omniboxFill.withValues(alpha: 0.92),
                            hintText:
                                'Search with ${settings.searchEngine.name} or enter address',
                            hintStyle: TextStyle(
                                color: palette.textDim, fontSize: 13.5),
                            prefixIcon: Icon(Icons.search_rounded,
                                color: palette.accent),
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(26),
                              borderSide: BorderSide(color: palette.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(26),
                              borderSide: BorderSide(color: palette.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(26),
                              borderSide: BorderSide(
                                  color: palette.accent, width: 1.6),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Speed dial',
                          style: TextStyle(
                            color: palette.textDim,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 14,
                        runSpacing: 16,
                        alignment: wide
                            ? WrapAlignment.center
                            : WrapAlignment.center,
                        children: [
                          for (final item in profile.speedDial)
                            _DialTile(
                              item: item,
                              onTap: () => _go(item.url),
                              onLongPress: () => _tileActions(item),
                            ),
                          _AddDialTile(onTap: () => _editItem(null)),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _QuickLink(
                            icon: Icons.star_rounded,
                            label: 'Bookmarks',
                            onTap: () => _openLibrary(
                                context, SidePanel.bookmarks,
                                const BookmarksRoute()),
                          ),
                          const SizedBox(width: 22),
                          _QuickLink(
                            icon: Icons.history_rounded,
                            label: 'History',
                            onTap: () => _openLibrary(
                                context, SidePanel.history,
                                const HistoryRoute()),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _tileActions(SpeedDialItem item) {
    final palette = pal(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.of(sheet).pop();
                _editItem(item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Remove'),
              onTap: () {
                context.read<ProfileProvider>().removeSpeedDial(item);
                Navigator.of(sheet).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editItem(SpeedDialItem? item) async {
    final profile = context.read<ProfileProvider>();
    final title = TextEditingController(text: item?.title ?? '');
    final url = TextEditingController(
      text: item?.url ?? 'https://',
    );
    final palette = pal(context);

    await showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(item == null ? 'Add to speed dial' : 'Edit tile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: title,
              autofocus: item == null,
              decoration: const InputDecoration(
                labelText: 'Name',
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: url,
              decoration: const InputDecoration(
                labelText: 'Address',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: palette.accent),
            onPressed: () {
              final u = urlFromInput(url.text);
              if (u == null) return;
              final nice = u.toString();
              if (item == null) {
                profile.addSpeedDial(
                  title: title.text.trim().isEmpty
                      ? hostOf(nice)
                      : title.text.trim(),
                  url: nice,
                );
              } else {
                profile.updateSpeedDial(
                  item,
                  title: title.text.trim(),
                  url: nice,
                );
              }
              Navigator.of(d).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    title.dispose();
    url.dispose();
  }
}

class _DialTile extends StatelessWidget {
  const _DialTile({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  final SpeedDialItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: palette.isDark ? 0.28 : 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Favicon(host: hostOf(item.url), size: 30),
            ),
            const SizedBox(height: 7),
            Text(
              item.title.isEmpty ? hostOf(item.url) : item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.text, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddDialTile extends StatelessWidget {
  const _AddDialTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 88,
        child: Column(
          children: [
            Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: palette.surfaceAlt.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: palette.border,
                  style: BorderStyle.solid,
                ),
              ),
              child: Icon(Icons.add_rounded,
                  size: 26, color: palette.textDim),
            ),
            const SizedBox(height: 7),
            Text(
              'Add site',
              style: TextStyle(color: palette.textDim, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 21, color: palette.accent),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: palette.textDim, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Weekday, Month day — kept here to avoid extra intl dependency.
class DateFormatE {
  static const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String format(DateTime d) =>
      '${weekdays[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
}
