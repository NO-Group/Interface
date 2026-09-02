import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../state/browser_provider.dart';

/// Chrome-style find-in-page bar (Ctrl+F).
class FindBar extends StatefulWidget {
  const FindBar({super.key, this.compact = false});

  final bool compact;

  @override
  State<FindBar> createState() => _FindBarState();
}

class _FindBarState extends State<FindBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _search(String q) {
    _debounce?.cancel();
    final browser = context.read<BrowserProvider>();
    browser.findQuery = q;
    if (q.isEmpty) {
      _clear();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 250), () {
      try {
        context
            .read<BrowserProvider>()
            .current
            .controller
            ?.findAllAsync(find: q);
      } catch (_) {}
    });
  }

  void _clear() {
    try {
      context.read<BrowserProvider>().current.controller?.clearMatches();
    } catch (_) {}
    context.read<BrowserProvider>().updateFindResults(0, 0, true);
  }

  void _next(bool forward) {
    try {
      context.read<BrowserProvider>().current.controller?.findNext(
            forward: forward,
          );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    final browser = context.watch<BrowserProvider>();
    final count = browser.findMatchCount;
    final ordinal = browser.findMatchOrdinal + (count > 0 ? 1 : 0);
    final label = browser.findQuery.isEmpty ? '' : '$ordinal/$count';

    return Container(
      width: widget.compact ? double.infinity : 480,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isDark ? 0.45 : 0.15),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: palette.textDim),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              style: TextStyle(color: palette.text, fontSize: 14),
              cursorColor: palette.accent,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _next(true),
              onChanged: _search,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Find in page',
                hintStyle: TextStyle(color: palette.textDim),
              ),
            ),
          ),
          if (label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                style: TextStyle(color: palette.textDim, fontSize: 12.5),
              ),
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.keyboard_arrow_up_rounded,
                color: palette.textDim),
            onPressed: () => _next(false),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon:
                Icon(Icons.keyboard_arrow_down_rounded, color: palette.textDim),
            onPressed: () => _next(true),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, color: palette.text),
            onPressed: () => context.read<BrowserProvider>().closeFind(),
          ),
        ],
      ),
    );
  }
}
