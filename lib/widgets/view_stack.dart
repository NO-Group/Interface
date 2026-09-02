import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/browser_provider.dart';
import 'tab_web_view.dart';

/// Keeps every tab's web view alive in an IndexedStack — switching tabs
/// never reloads pages, exactly like Chrome and Opera.
class ViewStack extends StatelessWidget {
  const ViewStack({super.key});

  @override
  Widget build(BuildContext context) {
    final browser = context.watch<BrowserProvider>();
    return IndexedStack(
      index: browser.index.clamp(0, browser.tabs.length - 1),
      children: [
        for (final tab in browser.tabs) TabWebView(key: ValueKey(tab.id), tab: tab),
      ],
    );
  }
}
