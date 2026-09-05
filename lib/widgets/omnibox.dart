import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'icons.dart';

import '../core/calc.dart';
import '../core/pal.dart';
import '../core/ui.dart';
import '../core/urls.dart';
import '../services/suggestions.dart';
import 'ui_kit.dart';
import 'favicon.dart';
import 'site_info_sheet.dart';
import '../state/browser_provider.dart';
import '../state/profile_provider.dart';
import '../state/settings_provider.dart';
import '../state/privacy_provider.dart';

enum _Kind { history, bookmark, search, url }

class _Suggestion {
  const _Suggestion(
    this.kind,
    this.primary,
    this.secondary,
    this.value,
  );

  final _Kind kind;
  final String primary;
  final String? secondary;
  final String value;

  Object get icon {
    switch (kind) {
      case _Kind.history:
        return 'clock';
      case _Kind.bookmark:
        return 'star-on';
      case _Kind.search:
        return 'search';
      case _Kind.url:
        return 'globe';
    }
  }
}

/// The address field: one box for addresses and searches.
///
/// Suggests from history, bookmarks and the search engine while you type,
/// and walks with the keyboard (up, down, Enter, Esc).
class Omnibox extends StatefulWidget {
  const Omnibox({super.key, this.compact = false});

  /// True → the borderless field inside the phone's bottom dock.
  final bool compact;

  @override
  State<Omnibox> createState() => _OmniboxState();
}

class _OmniboxState extends State<Omnibox> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final LayerLink _link = LayerLink();

  OverlayEntry? _overlay;
  double _fieldWidth = 420;
  List<_Suggestion> _items = const [];
  int _sel = -1;
  Timer? _debounce;
  int _webToken = 0;
  int _lastFocusEpoch = -1;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChanged);
    _focus.onKeyEvent = _onKey;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    final palette = pal(context);
    final tab = browser.current;

    if (browser.omniboxFocusEpoch != _lastFocusEpoch) {
      _lastFocusEpoch = browser.omniboxFocusEpoch;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focus.requestFocus();
          _controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controller.text.length,
          );
        }
      });
    }

    if (!_focus.hasFocus) {
      final shown = tab.onSpeedDial ? '' : displayUrl(tab.url);
      if (_controller.text != shown) {
        _controller.text = shown;
      }
    }

    final focused = _focus.hasFocus;
    final compact = widget.compact;
    final blocked = _blockedFor(context, tab);
    final height = compact ? 46.0 : 36.0;

    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: () {
          if (!_focus.hasFocus) _focus.requestFocus();
        },
        child: Stack(
          children: [
        AnimatedContainer(
          duration: Ui.quick,
          curve: Ui.curve,
          height: height,
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 11),
          decoration: compact
              ? const BoxDecoration(color: Colors.transparent)
              : Ui.field(p: palette, focused: focused),
          child: Row(
            children: [
              // The security state is not a button beside the address: it is
              // the plate's own left corner, cut off by a rule and lit by a
              // keel when there is something to say.
              if (!compact)
                _Stub(
                  onTap: tab.onSpeedDial || tab.url.isEmpty
                      ? null
                      : () => showSiteInfoSheet(context),
                  child: _leadingIcon(palette, tab, blocked: blocked),
                  lit: blocked > 0,
                  count: blocked,
                  tip: blocked > 0
                      ? '$blocked ads and trackers blocked on this site'
                      : 'Site information',
                )
              else
                _SiteButton(
                  onTap: tab.onSpeedDial || tab.url.isEmpty
                      ? null
                      : () => showSiteInfoSheet(context),
                  child: _leadingIcon(palette, tab),
                ),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                child: TextField(
                  spellCheckConfiguration: const SpellCheckConfiguration.disabled(),
                  controller: _controller,
                  focusNode: _focus,
                  style: Ui.text(
                    palette,
                    size: widget.compact ? 15 : 13.5,
                    color: palette.text,
                  ),
                  cursorColor: palette.accent,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (v) => _submitText(v),
                  onChanged: _refresh,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Search or enter address',
                    hintStyle: Ui.text(palette, color: palette.textDim),
                  ),
                ),
              ),
              if (!compact && focused && _controller.text.isNotEmpty)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: uiGlyph('close',
                      size: 16, color: palette.textDim),
                  tooltip: 'Clear',
                  onPressed: () => _controller.clear(),
                ),
              if (widget.compact) ...[
                _trailingButton(palette, tab),
              ],
            ],
          ),
            // The plate's own keel lights while the field has the keyboard, so
            // the focus cue sits on the same edge as every other cue.
            if (!compact && focused)
              Positioned(
                left: 0,
                top: 5,
                bottom: 5,
                child: Ui.keel(palette),
              ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _leadingIcon(BrowserPalette palette, BrowserTab tab,
      {int blocked = 0}) {
    if (tab.onSpeedDial || tab.url.isEmpty) {
      return uiGlyph('search', size: 17, color: palette.textDim);
    }
    // The shield only replaces the lock when it has actually done something.
    if (blocked > 0) {
      return uiGlyph('shield-on', size: 15, color: palette.accent);
    }
    if (tab.url.startsWith('https://')) {
      return uiGlyph('lock', size: 14, color: palette.success);
    }
    if (tab.url.startsWith('http://')) {
      return uiGlyph('info', size: 16, color: palette.danger);
    }
    return uiGlyph('globe', size: 16, color: palette.textDim);
  }

  Widget _trailingButton(BrowserPalette palette, BrowserTab tab) {
    final browser = context.read<BrowserProvider>();
    final icon = tab.loading ? 'stop' : 'reload';
    return IconButton(
      visualDensity: VisualDensity.compact,
      splashRadius: 16,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      padding: EdgeInsets.zero,
      icon: uiGlyph(icon, size: 19, color: palette.textDim),
      onPressed: tab.loading ? browser.stopLoading : () => browser.reload(),
    );
  }

  // ---- Suggestions ----

  void _onFocusChanged() {
    if (_focus.hasFocus) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final box = context.findRenderObject() as RenderBox?;
        if (box != null && box.size.width > 0) {
          _fieldWidth = box.size.width;
        }
        _showOverlay();
        _refresh(_controller.text);
      });
    } else {
      _removeOverlay();
      setState(() => _sel = -1);
    }
  }

  void _refresh(String q) {
    if (!_focus.hasFocus) return;
    final local = _localSuggestions(q);
    setState(() {
      _items = local;
      if (_sel >= _items.length) _sel = _items.length - 1;
    });
    _debounce?.cancel();
    if (q.trim().isEmpty) return;
    final token = ++_webToken;
    _debounce = Timer(const Duration(milliseconds: 220), () async {
      final results = await SuggestionService.forQuery(q);
      if (!mounted || token != _webToken || !_focus.hasFocus) return;
      final urls = _items.map((s) => s.value).toSet();
      final extra = results
          .map(
            (s) => _Suggestion(_Kind.search, s, null, s),
          )
          .where((s) => !urls.contains(s.value))
          .take(5)
          .toList();
      setState(() => _items = [..._items, ...extra]);
    });
  }

  List<_Suggestion> _localSuggestions(String q) {
    final profile = context.read<ProfileProvider>();
    final settings = context.read<SettingsProvider>();
    final query = q.trim();

    if (query.isEmpty) {
      return profile
          .historyMatches('', limit: 6)
          .map(
            (h) => _Suggestion(
              _Kind.history,
              h.title.isEmpty ? displayUrl(h.url) : h.title,
              displayUrl(h.url),
              h.url,
            ),
          )
          .toList();
    }

    final items = <_Suggestion>[];
    final seen = <String>{};

    // Omnibox calculator.
    final calc = Calculator.tryEval(query);
    if (calc != null) {
      items.add(_Suggestion(
        _Kind.search,
        Calculator.pretty(calc),
        '$query = — tap to copy',
        'calc:${Calculator.pretty(calc)}',
      ));
    }

    // Direct URL or search intent — always first.
    final parsed = urlFromInput(query);
    if (parsed != null && isWebScheme(parsed)) {
      items.add(
        _Suggestion(_Kind.url, query, displayUrl(parsed.toString()), parsed.toString()),
      );
      seen.add(parsed.toString());
    } else {
      items.add(
        _Suggestion(
          _Kind.search,
          query,
          '${settings.searchEngine.name} search',
          query,
        ),
      );
    }

    for (final h in profile.historyMatches(query, limit: 5)) {
      if (seen.contains(h.url)) continue;
      seen.add(h.url);
      items.add(
        _Suggestion(
          _Kind.history,
          h.title.isEmpty ? displayUrl(h.url) : h.title,
          displayUrl(h.url),
          h.url,
        ),
      );
    }
    for (final b in profile.bookmarkMatches(query, limit: 4)) {
      if (seen.contains(b.url)) continue;
      seen.add(b.url);
      items.add(
        _Suggestion(
          _Kind.bookmark,
          b.title.isEmpty ? displayUrl(b.url) : b.title,
          displayUrl(b.url),
          b.url,
        ),
      );
    }
    return items;
  }

  // ---- Overlay panel ----

  void _showOverlay() {
    if (_overlay != null) return;
    _overlay = OverlayEntry(builder: (_) => _buildPanel());
    Overlay.maybeOf(context, rootOverlay: true)?.insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Widget _buildPanel() {
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => _focus.unfocus(),
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor:
              widget.compact ? Alignment.topLeft : Alignment.bottomLeft,
          followerAnchor:
              widget.compact ? Alignment.bottomLeft : Alignment.topLeft,
          offset: widget.compact ? const Offset(0, -8) : const Offset(0, 8),
          child: Material(
            elevation: 0,
            color: Colors.transparent,
            child: _PanelCard(
              width: _fieldWidth,
              items: _items,
              selected: _sel,
              query: _controller.text,
              onHover: (i) => _overlay?.markNeedsBuild(),
              onSelected: (i) => _submit(_items[i]),
            ),
          ),
        ),
      ],
    );
  }

  // ---- Keyboard ----

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (_items.isEmpty) return KeyEventResult.ignored;
      setState(() => _sel = (_sel + 1) % _items.length);
      _overlay?.markNeedsBuild();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      if (_items.isEmpty) return KeyEventResult.ignored;
      setState(() => _sel = _sel <= 0 ? _items.length - 1 : _sel - 1);
      _overlay?.markNeedsBuild();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _focus.unfocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _submitText(String text) {
    if (_sel >= 0 && _sel < _items.length) {
      _submit(_items[_sel]);
    } else {
      _submit(_Suggestion(_Kind.search, text, null, text));
    }
  }

  void _submit(_Suggestion s) {
    _focus.unfocus();
    if (s.value.startsWith('calc:')) {
      Clipboard.setData(ClipboardData(text: s.value.substring(5)));
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(
        const SnackBar(content: Text('Result copied')),
      );
      return;
    }
    context.read<BrowserProvider>().navigate(s.value);
  }
}

/// The lock / info / search glyph, tappable, with the same hover language as
/// everything else in the bar.
/// How much the shield is holding back on this page, for the stub's keel.
int _blockedFor(BuildContext context, BrowserTab tab) {
  if (tab.onSpeedDial || tab.host.isEmpty) return 0;
  final privacy = context.watch<PrivacyProvider>();
  final settings = context.watch<SettingsProvider>();
  final on =
      privacy.effectiveBlockAds(tab.siteUrl, settings.blockAds);
  return on ? privacy.blockedFor(tab.host) : 0;
}

/// The address plate's own left corner: the site's state, in the plate, with
/// a keel when there is something to look at.
class _Stub extends StatelessWidget {
  const _Stub({
    required this.child,
    required this.lit,
    this.count = 0,
    this.tip = '',
    this.onTap,
  });

  final Widget child;
  final bool lit;
  final int count;
  final String tip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = pal(context);
    return UiHoverable(
      onTap: onTap,
      builder: (context, hovering, pressed) => AnimatedContainer(
        duration: Ui.quick,
        curve: Ui.curve,
        width: Ui.stubWidth,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pressed
              ? p.activeFill
              : (hovering
                  ? p.hoverFill
                  : (lit ? p.accentSoft : Colors.transparent)),
          borderRadius: Ui.hang(v: Ui.rField, bottom: true, top: true, right: false),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Tooltip(
              message: tip,
              waitDuration: const Duration(milliseconds: 700),
              child: count > 0
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        child,
                        Text(
                          Ui.count(count),
                          style: Ui.text(
                            p,
                            size: 9.5,
                            weight: FontWeight.w700,
                            color: p.accent,
                            height: 1,
                          ),
                        ),
                      ],
                    )
                  : child,
            ),
            if (lit)
              Positioned(
                left: 0,
                top: 6,
                bottom: 6,
                child: Ui.keel(p),
              ),
          ],
        ),
      ),
    );
  }
}

class _SiteButton extends StatelessWidget {
  const _SiteButton({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return UiHoverable(
      onTap: onTap,
      builder: (context, hovering, pressed) => AnimatedContainer(
        duration: Ui.quick,
        curve: Ui.curve,
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pressed
              ? palette.activeFill
              : (hovering ? palette.hoverFill : Colors.transparent),
          borderRadius: Ui.petal(Ui.rControl),
        ),
        child: child,
      ),
    );
  }
}

String _hostOf(String url) {
  final m = RegExp(r'^[a-z]+://([^/]+)').firstMatch(url);
  return m?.group(1) ?? '';
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.width,
    required this.items,
    required this.selected,
    required this.query,
    required this.onHover,
    required this.onSelected,
  });

  final double width;
  final List<_Suggestion> items;
  final int selected;
  final String query;
  final ValueChanged<int> onHover;
  final ValueChanged<int> onSelected;

  /// Bolds the part the user actually typed, so the match is obvious.
  TextSpan _highlight(String text, BrowserPalette palette) {
    final q = query.trim();
    if (q.isEmpty) return TextSpan(text: text);
    final i = text.toLowerCase().indexOf(q.toLowerCase());
    if (i < 0) return TextSpan(text: text);
    return TextSpan(
      children: [
        TextSpan(text: text.substring(0, i)),
        TextSpan(
          text: text.substring(i, i + q.length),
          style: TextStyle(fontWeight: FontWeight.w700, color: palette.accent),
        ),
        TextSpan(text: text.substring(i + q.length)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      width: width,
      constraints: const BoxConstraints(maxHeight: 5 * 44 + 12),
      decoration: Ui.floating(palette),
      child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 5),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final s = items[i];
          final isSel = i == selected;
          return InkWell(
            onTap: () => onSelected(i),
            onHover: (_) => onHover(i),
            child: Column(
              children: [
            AnimatedContainer(
              duration: Ui.quick,
              curve: Ui.curve,
              // Grows instead of clipping when text size is turned up.
              constraints: const BoxConstraints(minHeight: 44),
              margin: const EdgeInsets.symmetric(horizontal: 5),
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: isSel ? palette.activeFill : Colors.transparent,
                borderRadius: Ui.petal(Ui.rControl),
              ),
              child: Stack(
                children: [
                  Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.surfaceAlt,
                      borderRadius: Ui.petal(7),
                      border: Border.all(color: palette.border),
                    ),
                    child: s.kind == _Kind.url
                        ? Favicon(host: _hostOf(s.value), size: 15)
                        : uiGlyph(s.icon, size: 15, color: palette.textDim),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text.rich(
                      _highlight(s.primary, palette),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ui.text(palette, size: Ui.sizeBody),
                    ),
                  ),
                  if (s.secondary != null &&
                      s.secondary!.isNotEmpty &&
                      s.secondary != s.primary) ...[
                    const SizedBox(width: 12),
                    Text(
                      s.secondary!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Ui.text(
                        palette,
                        size: Ui.sizeCaption,
                        color: palette.textFaint,
                      ),
                    ),
                  ],
                ],
              ),
                  // The row the arrow keys are on keeps a keel, so the
                  // keyboard can see where it is without a blue ring.
                  if (isSel)
                    Positioned(
                      left: 0,
                      top: 6,
                      bottom: 6,
                      child: Ui.keel(palette),
                    ),
                ],
              ),
            ),
            if (i != items.length - 1)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 5),
                child: Ui.tick(palette, width: double.infinity,
                    color: palette.hairlineSoft),
              ),
          ],
            ),
          );
        },
      ),
    );
  }
}
