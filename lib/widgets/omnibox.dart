import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../core/urls.dart';
import '../services/suggestions.dart';
import '../state/browser_provider.dart';
import '../state/profile_provider.dart';
import '../state/settings_provider.dart';

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

  IconData get icon {
    switch (kind) {
      case _Kind.history:
        return Icons.history_rounded;
      case _Kind.bookmark:
        return Icons.star_rounded;
      case _Kind.search:
        return Icons.search_rounded;
      case _Kind.url:
        return Icons.language_rounded;
    }
  }
}

/// The omnibox — Chrome's combined address & search bar.
///
/// Shows suggestions from history, bookmarks and a live web suggest API,
/// with full keyboard navigation (↑ ↓ Enter Esc).
class Omnibox extends StatefulWidget {
  const Omnibox({super.key, this.compact = false});

  /// True → mobile pill sitting at the bottom of the screen.
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
    final height = widget.compact ? 46.0 : 34.0;

    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: () {
          if (!_focus.hasFocus) _focus.requestFocus();
        },
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: palette.omniboxFill,
            borderRadius: BorderRadius.circular(height / 2),
            border: Border.all(
              color: focused ? palette.accent : Colors.transparent,
              width: focused ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              _leadingIcon(palette, tab),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: widget.compact ? 15 : 14,
                  ),
                  cursorColor: palette.accent,
                  textInputAction: TextInputAction.go,
                  onSubmitted: (v) => _submitText(v),
                  onChanged: _refresh,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: 'Search or enter address',
                    hintStyle: TextStyle(color: palette.textDim),
                  ),
                ),
              ),
              if (widget.compact) ...[
                _trailingButton(palette, tab),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _leadingIcon(BrowserPalette palette, BrowserTab tab) {
    if (tab.onSpeedDial || tab.url.isEmpty) {
      return Icon(Icons.search_rounded, size: 18, color: palette.textDim);
    }
    if (tab.url.startsWith('https://')) {
      return Icon(Icons.lock_rounded, size: 15, color: palette.success);
    }
    return Icon(Icons.info_outline_rounded, size: 17, color: palette.textDim);
  }

  Widget _trailingButton(BrowserPalette palette, BrowserTab tab) {
    final browser = context.read<BrowserProvider>();
    final icon = tab.loading ? Icons.close_rounded : Icons.refresh_rounded;
    return IconButton(
      visualDensity: VisualDensity.compact,
      splashRadius: 16,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      padding: EdgeInsets.zero,
      icon: Icon(icon, size: 19, color: palette.textDim),
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
    context.read<BrowserProvider>().navigate(s.value);
  }
}

class _PanelCard extends StatelessWidget {
  const _PanelCard({
    required this.width,
    required this.items,
    required this.selected,
    required this.onHover,
    required this.onSelected,
  });

  final double width;
  final List<_Suggestion> items;
  final int selected;
  final ValueChanged<int> onHover;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      width: width,
      constraints: const BoxConstraints(maxHeight: 5 * 50 + 12),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isDark ? 0.5 : 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: items.length,
        itemBuilder: (_, i) {
          final s = items[i];
          final isSel = i == selected;
          return InkWell(
            onTap: () => onSelected(i),
            onHover: (_) => onHover(i),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              color: isSel ? palette.surfaceAlt : Colors.transparent,
              child: Row(
                children: [
                  Icon(s.icon, size: 19, color: palette.textDim),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.primary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: palette.text,
                          ),
                        ),
                        if (s.secondary != null &&
                            s.secondary!.isNotEmpty &&
                            s.secondary != s.primary)
                          Text(
                            s.secondary!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: palette.textDim,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
