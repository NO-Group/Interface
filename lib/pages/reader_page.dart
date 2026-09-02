import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../services/reader_extractor.dart';
import '../state/browser_provider.dart';
import '../state/settings_provider.dart';

/// Distraction-free Reader Mode over the current page.
class ReaderPage extends StatefulWidget {
  const ReaderPage({super.key});

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  Map<String, dynamic>? _article;
  String? _error;
  double _progress = 0;

  @override
  void initState() {
    super.initState();
    _extract();
  }

  Future<void> _extract() async {
    final browser = context.read<BrowserProvider>();
    final controller = browser.current.controller;
    if (controller == null) {
      setState(() => _error = 'Nothing to read on this tab.');
      return;
    }
    setState(() {
      _article = null;
      _error = null;
      _progress = 0.2;
    });
    try {
      final result = await controller.evaluateJavascript(source: kReaderJs);
      setState(() => _progress = 0.9);
      final raw = result?.toString();
      if (raw == null || raw.isEmpty || raw == 'null') {
        throw const FormatException('no article');
      }
      final decoded = jsonDecode(raw);
      final map = decoded is Map<String, dynamic>
          ? decoded
          : (decoded is String
              ? jsonDecode(decoded) as Map<String, dynamic>
              : throw const FormatException('bad'));
      final blocks = (map['blocks'] as List? ?? []);
      if (blocks.isEmpty) throw const FormatException('empty');
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (!mounted) return;
      setState(() {
        _article = map;
        _progress = 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error =
          'This page doesn’t look like an article.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final palette = pal(context);
    final scheme = _readerScheme(settings.readerTheme);

    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        backgroundColor: scheme.background,
        foregroundColor: scheme.foreground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Text(
          'Reader',
          style: TextStyle(
            color: scheme.foreground,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Smaller text',
            icon: const Icon(Icons.text_decrease_rounded, size: 20),
            onPressed: () =>
                settings.setReaderFontSize(settings.readerFontSize - 1),
          ),
          IconButton(
            tooltip: 'Larger text',
            icon: const Icon(Icons.text_increase_rounded, size: 20),
            onPressed: () =>
                settings.setReaderFontSize(settings.readerFontSize + 1),
          ),
          PopupMenuButton<ReaderTheme>(
            tooltip: 'Reader theme',
            icon: Icon(Icons.palette_outlined,
                size: 20, color: scheme.foreground),
            onSelected: settings.setReaderTheme,
            itemBuilder: (_) => const [
              PopupMenuItem(value: ReaderTheme.paper, child: Text('Paper')),
              PopupMenuItem(value: ReaderTheme.sepia, child: Text('Sepia')),
              PopupMenuItem(value: ReaderTheme.night, child: Text('Night')),
            ],
          ),
          IconButton(
            tooltip: 'Copy article text',
            icon: const Icon(Icons.copy_rounded, size: 19),
            onPressed: _article == null
                ? null
                : () {
                    final text = _plainText(_article!);
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Article copied')),
                    );
                  },
          ),
          IconButton(
            tooltip: 'Reload',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _extract,
          ),
        ],
      ),
      body: _error != null
          ? _EmptyReader(
              message: _error!,
              accent: palette.accent,
              foreground: scheme.foreground,
              onRetry: _extract,
            )
          : _article == null
              ? Center(
                  child: SizedBox(
                    width: 220,
                    child: LinearProgressIndicator(
                      value: _progress < 1 ? _progress : null,
                      color: palette.accent,
                      backgroundColor: scheme.foreground.withValues(alpha: 0.1),
                    ),
                  ),
                )
              : SelectionArea(
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 28),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: _ArticleBody(
                            article: _article!,
                            fontSize: settings.readerFontSize,
                            scheme: scheme,
                            accent: palette.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }

  String _plainText(Map<String, dynamic> article) {
    final buf = StringBuffer();
    buf.writeln(article['title'] ?? '');
    if ((article['by'] ?? '').toString().isNotEmpty) {
      buf.writeln(article['by']);
    }
    buf.writeln();
    for (final b in (article['blocks'] as List)) {
      final map = b as Map<String, dynamic>;
      if (map['t'] != 'img') buf.writeln(map['v']);
      buf.writeln();
    }
    return buf.toString();
  }
}

class _ReaderScheme {
  const _ReaderScheme(this.background, this.foreground, this.muted, this.serif);
  final Color background;
  final Color foreground;
  final Color muted;
  final bool serif;
}

_ReaderScheme _readerScheme(ReaderTheme t) {
  switch (t) {
    case ReaderTheme.paper:
      return const _ReaderScheme(
        Color(0xFFFDFBF7), Color(0xFF1A1D23), Color(0xFF5B6270), false);
    case ReaderTheme.sepia:
      return const _ReaderScheme(
        Color(0xFFF4E8D0), Color(0xFF43352A), Color(0xFF7A6A57), true);
    case ReaderTheme.night:
      return const _ReaderScheme(
        Color(0xFF0D1117), Color(0xFFD7DEE8), Color(0xFF8A94A3), false);
  }
}

class _ArticleBody extends StatelessWidget {
  const _ArticleBody({
    required this.article,
    required this.fontSize,
    required this.scheme,
    required this.accent,
  });

  final Map<String, dynamic> article;
  final double fontSize;
  final _ReaderScheme scheme;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final hero = (article['hero'] ?? '').toString();
    final by = (article['by'] ?? '').toString();
    final font = scheme.serif ? 'serif' : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (article['title'] ?? 'Untitled').toString(),
          style: TextStyle(
            color: scheme.foreground,
            fontSize: fontSize + 10,
            fontWeight: FontWeight.w700,
            height: 1.25,
            fontFamily: font,
          ),
        ),
        if (by.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            by,
            style: TextStyle(
              color: scheme.muted,
              fontSize: fontSize - 3,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        if (hero.isNotEmpty) ...[
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              hero,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
        const Divider(height: 36),
        for (final b in (article['blocks'] as List)) _block(b, font),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _block(dynamic b, String? font) {
    final map = b as Map<String, dynamic>;
    final kind = map['t'] as String? ?? 'p';
    final value = (map['v'] ?? '').toString();

    if (kind == 'img') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            value,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      );
    }
    if (kind == 'h2') {
      return Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(
          value,
          style: TextStyle(
            color: scheme.foreground,
            fontSize: fontSize + 4,
            fontWeight: FontWeight.w700,
            fontFamily: font,
          ),
        ),
      );
    }
    if (kind == 'h3') {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(
          value,
          style: TextStyle(
            color: scheme.foreground,
            fontSize: fontSize + 1,
            fontWeight: FontWeight.w600,
            fontFamily: font,
          ),
        ),
      );
    }
    if (kind == 'blockquote') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.only(left: 16),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: accent, width: 3)),
        ),
        child: Text(
          value,
          style: TextStyle(
            color: scheme.muted,
            fontSize: fontSize,
            fontStyle: FontStyle.italic,
            height: 1.7,
            fontFamily: font,
          ),
        ),
      );
    }
    if (kind == 'pre') {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.foreground.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          value,
          style: TextStyle(
            color: scheme.foreground,
            fontSize: fontSize - 3,
            fontFamily: 'monospace',
            height: 1.5,
          ),
        ),
      );
    }
    if (kind == 'li') {
      return Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: fontSize * 0.55),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: scheme.foreground,
                  fontSize: fontSize,
                  height: 1.75,
                  fontFamily: font,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Text(
        value,
        style: TextStyle(
          color: scheme.foreground,
          fontSize: fontSize,
          height: 1.8,
          fontFamily: font,
        ),
      ),
    );
  }
}

class _EmptyReader extends StatelessWidget {
  const _EmptyReader({
    required this.message,
    required this.accent,
    required this.foreground,
    required this.onRetry,
  });

  final String message;
  final Color accent;
  final Color foreground;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_rounded, size: 52, color: accent),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: foreground, fontSize: 14),
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
