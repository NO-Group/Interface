import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../core/pal.dart';
import '../core/urls.dart';
import '../pages/downloads_page.dart';
import '../services/downloader.dart';
import '../state/browser_provider.dart';
import '../state/privacy_provider.dart';
import '../state/profile_provider.dart';
import '../state/settings_provider.dart';
import 'new_tab_page.dart';

/// The actual web view for one tab, wired to the providers.
///
/// Also hosts the speed-dial overlay and the error page for its tab.
class TabWebView extends StatefulWidget {
  const TabWebView({super.key, required this.tab});

  final BrowserTab tab;

  @override
  State<TabWebView> createState() => _TabWebViewState();
}

class _TabWebViewState extends State<TabWebView> {
  PullToRefreshController? _ptr;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid || Platform.isIOS) {
      _ptr = PullToRefreshController(
        settings: PullToRefreshSettings(
          enabled: true,
          color: const Color(0xFF22D3EE),
          backgroundColor: const Color(0xFF0A1424),
        ),
        onRefresh: () async {
          try {
            await widget.tab.controller?.reload();
          } catch (_) {}
          _ptr?.endRefreshing();
        },
      );
    }
  }

  @override
  void dispose() {
    widget.tab.controller = null;
    try {
      _ptr?.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watches: rebuild when theme / settings change (e.g. grayscale content).
    final settings = context.watch<SettingsProvider>();
    final palette = pal(context);
    final tab = widget.tab;

    Widget view = InAppWebView(
      webViewEnvironment: webViewEnvironment,
      pullToRefreshController: _ptr,
      initialUrlRequest: URLRequest(
        url: WebUri(tab.initialUrl ?? 'about:blank'),
      ),
      initialSettings: buildSettingsFor(
        tab: tab,
        settings: settings,
        privacy: context.read<PrivacyProvider>(),
      ),
      onWebViewCreated: _onCreated,
      onLoadStart: (c, url) => _onLoadStart(url?.toString() ?? ''),
      onLoadStop: _onLoadStop,
      onProgressChanged: (c, p) {
        final browser = context.read<BrowserProvider>();
        tab.progress = p;
        tab.loading = p < 100;
        browser.tabChanged(tab, structural: false);
      },
      onUpdateVisitedHistory: (c, url, isReload) {
        if (url != null && url.toString().isNotEmpty) {
          tab.url = url.toString();
          if (tab.url != 'about:blank') tab.onSpeedDial = false;
        }
        context.read<BrowserProvider>().syncNavState(tab);
      },
      onTitleChanged: (c, title) {
        tab.title = title ?? tab.title;
        context.read<BrowserProvider>().tabChanged(tab);
      },
      shouldOverrideUrlLoading: _shouldOverrideUrlLoading,
      onDownloadStartRequest: (c, request) {
        Provider.of<DownloadService>(context, listen: false)
            .addFromRequest(request);
        _snackDownload(request.suggestedFilename ?? 'file');
      },
      onReceivedError: _onReceivedError,
      onFindResultReceived: (c, ordinal, count, done) {
        context
            .read<BrowserProvider>()
            .updateFindResults(ordinal, count, done);
      },
      onEnterFullscreen: (c) =>
          context.read<BrowserProvider>().setFullscreen(true),
      onExitFullscreen: (c) =>
          context.read<BrowserProvider>().setFullscreen(false),
      onPermissionRequest: _onPermissionRequest,
    );

    if (settings.grayscaleContent) {
      view = ColorFiltered(
        colorFilter: ColorFilter.saturation(0),
        child: view,
      );
    }

    final browser = context.read<BrowserProvider>();

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: palette.background, child: view),
        if (tab.onSpeedDial)
          NewTabPage(key: ValueKey('nt-${tab.id}'), tab: tab),
        if (tab.error != null && !tab.onSpeedDial)
          _ErrorPage(
            message: tab.error!,
            url: tab.url,
            onRetry: () {
              tab.error = null;
              browser.tabChanged(tab, structural: false);
              browser.reload();
            },
            onHome: () => browser.goHome(),
          ),
      ],
    );
  }

  void _onCreated(InAppWebViewController c) {
    widget.tab.controller = c;
    // If a navigation arrived before the view existed, run it now.
    final tab = widget.tab;
    final pending = tab.initialUrl;
    if (pending != null &&
        pending.isNotEmpty &&
        pending != 'about:blank' &&
        tab.onSpeedDial == false) {
      c.loadUrl(urlRequest: URLRequest(url: WebUri(pending)));
    }
  }

  void _onLoadStart(String url) {
    final tab = widget.tab;
    final browser = context.read<BrowserProvider>();
    if (url.isEmpty || url == 'about:blank') return;
    tab.url = url;
    tab.onSpeedDial = false;
    tab.loading = true;
    tab.progress = 0;
    tab.error = null;
    browser.tabChanged(tab);
    browser.syncNavState(tab);
  }

  Future<void> _onLoadStop(InAppWebViewController c, WebUri? url) async {
    final tab = widget.tab;
    final browser = context.read<BrowserProvider>();
    final profile = context.read<ProfileProvider>();
    final privacy = context.read<PrivacyProvider>();
    final settings = context.read<SettingsProvider>();
    if (url != null && url.toString().isNotEmpty) {
      tab.url = url.toString();
      if (tab.url != 'about:blank') tab.onSpeedDial = false;
    }
    tab.loading = false;
    tab.progress = 100;
    try {
      final t = await c.getTitle();
      if (t != null && t.trim().isNotEmpty) tab.title = t.trim();
    } catch (_) {}
    try {
      final favicons = await c.getFavicons();
      if (favicons != null && favicons.isNotEmpty) {
        favicons.sort((a, b) => (b.height ?? 0).compareTo(a.height ?? 0));
        tab.faviconUrl = favicons.first.url?.toString();
      }
    } catch (_) {}
    if (!tab.incognito && tab.url.startsWith('http')) {
      profile.addHistory(url: tab.url, title: tab.title);
    }
    // Cosmetic ad-element hiding.
    if (settings.cosmeticFiltering &&
        privacy.effectiveBlockAds(tab.url, settings.blockAds) &&
        tab.url.startsWith('http')) {
      try {
        await c.injectCSSCode(source: kCosmeticAdCSS);
      } catch (_) {}
    }
    browser.tabChanged(tab);
    browser.syncNavState(tab);
  }

  Future<NavigationActionPolicy> _shouldOverrideUrlLoading(
    InAppWebViewController c,
    NavigationAction action,
  ) async {
    final uri = action.request.url;
    if (uri == null) return NavigationActionPolicy.ALLOW;
    final browser = context.read<BrowserProvider>();

    if (isExternalScheme(uri)) {
      await browser.launchExternal(uri);
      return NavigationActionPolicy.CANCEL;
    }

    final blockedHost = browser.filterNavigation(action, widget.tab);
    if (blockedHost != null) return NavigationActionPolicy.CANCEL;

    return NavigationActionPolicy.ALLOW;
  }

  Future<PermissionResponse?> _onPermissionRequest(
    InAppWebViewController controller,
    PermissionRequest request,
  ) async {
    final browser = context.read<BrowserProvider>();
    final privacy = context.read<PrivacyProvider>();
    final host = request.origin.host;

    // Site rule already answers?
    final preset = privacy.effectiveMedia('https://$host/');
    if (preset != null) {
      return PermissionResponse(
        resources: request.resources,
        action: preset
            ? PermissionResponseAction.GRANT
            : PermissionResponseAction.DENY,
      );
    }

    final labels =
        request.resources.map(permissionLabel).toSet().toList();
    final allowed = await browser.askPermission(host, labels);
    return PermissionResponse(
      resources: request.resources,
      action: allowed
          ? PermissionResponseAction.GRANT
          : PermissionResponseAction.DENY,
    );
  }

  void _onReceivedError(
    InAppWebViewController c,
    WebResourceRequest request,
    WebResourceError error,
  ) {
    final desc = error.description;
    final type = error.type.toString();
    final cancelled = desc.contains('ERR_ABORTED') ||
        desc.contains('Canceled') ||
        desc.contains('cancelled') ||
        type.contains('cancel');
    if (cancelled) return;
    if (request.isForMainFrame == false) return;
    final tab = widget.tab;
    tab.loading = false;
    tab.error = desc.isEmpty ? 'This page could not be loaded.' : desc;
    context.read<BrowserProvider>().tabChanged(tab, structural: false);
  }

  void _snackDownload(String name) {
    final ctx = context;
    final messenger = ScaffoldMessenger.maybeOf(ctx);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text('Downloading $name'),
        action: SnackBarAction(
          label: 'VIEW',
          onPressed: () => Navigator.of(ctx).push(
            MaterialPageRoute<void>(builder: (_) => const DownloadsRoute()),
          ),
        ),
      ),
    );
  }
}

/// Lightweight cosmetic filters — hide the most common ad slots after load.
const kCosmeticAdCSS = '''
[id*="google_ads"], [id*="googleAds"], [id*="div-gpt-ad"],
[id*="taboola"], [id*="outbrain"], [class*="taboola"],
[class*="OUTBRAIN"], [class*="ad-slot"], [class*="ad-slot__"],
[class*="adsbygoogle"], [class*="advertisement"],
[class*="dfp-ad"], [class*="pub_300x250"], [class*="text-ad"],
[class*="ad-container"], [class*="ad-wrapper--ad"],
iframe[src*="doubleclick.net"], iframe[src*="googlesyndication.com"],
iframe[src*="amazon-adsystem.com"], iframe[src*="adnxs.com"] {
  display: none !important;
  height: 0 !important;
  min-height: 0 !important;
}
''';

/// Friendly Chrome-style "can't reach this page" overlay.
class _ErrorPage extends StatelessWidget {
  const _ErrorPage({
    required this.message,
    required this.url,
    required this.onRetry,
    required this.onHome,
  });

  final String message;
  final String url;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final palette = pal(context);
    return Container(
      color: palette.background,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: palette.surfaceAlt,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.wifi_off_rounded, size: 44, color: palette.accent),
          ),
          const SizedBox(height: 20),
          Text(
            "Can't reach this page",
            style: TextStyle(
              color: palette.text,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textDim, fontSize: 13),
          ),
          if (url.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              displayUrl(url),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.textDim,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: onHome,
                icon: const Icon(Icons.home_outlined),
                label: const Text('Home'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
