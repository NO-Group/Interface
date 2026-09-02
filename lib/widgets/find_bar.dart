import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../core/ui.dart';
import '../state/browser_provider.dart';
import 'ui_kit.dart';

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
      width: widget.compact ? double.infinity : 460,
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: Ui.floating(palette, radius: Ui.rCard),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 17, color: palette.textDim),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              autofocus: true,
              style: Ui.text(palette, color: palette.text),
              cursorColor: palette.accent,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _next(true),
              onChanged: _search,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Find in page',
                hintStyle: Ui.text(palette, color: palette.textDim),
              ),
            ),
          ),
          if (label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                style: Ui.text(
                  palette,
                  size: Ui.sizeSmall,
                  weight: FontWeight.w600,
                  color: count == 0 ? palette.danger : palette.textDim,
                ),
              ),
            ),
          UiIconButton(
            icon: Icons.arrow_upward_rounded,
            iconSize: 16,
            size: 32,
            tooltip: 'Previous match',
            onTap: () => _next(false),
          ),
          UiIconButton(
            icon: Icons.arrow_downward_rounded,
            iconSize: 16,
            size: 32,
            tooltip: 'Next match',
            onTap: () => _next(true),
          ),
          UiIconButton(
            icon: Icons.close_rounded,
            iconSize: 16,
            size: 32,
            tooltip: 'Close',
            onTap: () => context.read<BrowserProvider>().closeFind(),
          ),
        ],
      ),
    );
  }
}
