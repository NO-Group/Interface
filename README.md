# Interface Browser

A real, themeable web browser for **phones (Android)** and **laptops (Windows)**, built with Flutter + native WebViews (`flutter_inappwebview` — Android System WebView / Windows WebView2).

**Brand:** navy blue chrome with cyan accents. **UX:** Chrome tabs & omnibox meets Opera speed dial, bottom address bar & sidebar.

## Features

- 🌐 **Real web browsing** — native WebView engine on every platform, tabs stay alive when you switch them
- 🎨 **7 themes** — System · Light · Dark (navy/cyan) · Red · Green · Black & White (can render pages fully desaturated) · **Custom picture background** (frosted-glass chrome over your wallpaper)
- ⚡ **Speed dial** — Opera-style new tab with clock, big search box and an editable grid of favorite sites
- 🔍 **Smart omnibox** — combined address/search with live suggestions (DuckDuckGo autocomplete), history & bookmark matches, full keyboard navigation
- 🗂 **Tabs** — Chrome desktop tab strip (context menus, middle-click close) + Chrome mobile tab grid; incognito tabs with private chrome
- ⭐ **Bookmarks** — toolbar star, Chrome-style bookmarks bar, manager, edit/delete
- 🕘 **History** — grouped by day, per-item delete, clear-browsing-data dialog (history/cookies/cache)
- ⬇️ **Real downloads** — streamed with progress and cancel, saved to your Downloads folder (Windows) / app Downloads (Android)
- 🔎 **Find in page** (Ctrl+F) with match counter
- 🛡 **Block ads & pop-ups** — built-in host blocklist, one-tap toggle
- 🖥 **Desktop-site mode** for phones, per-window layout that adapts ≥840 px
- ⌨️ **Keyboard shortcuts** — Ctrl+T / Ctrl+W / Ctrl+Tab / Ctrl+L / Ctrl+F / Ctrl+D / Ctrl+R / Alt+←→ / Ctrl+1…9
- 🎬 Fullscreen video, permission requests (camera/mic/geo) granted with a Chromium-style prompt flow
- 🔄 **Session restore** — reopen your tabs on startup

## Get the app

Every push builds installers with GitHub Actions → [**Actions tab → Build**](../../actions/workflows/build.yml) → pick a run → **Artifacts**:

| Artifact | What it is |
|---|---|
| `Interface-Browser-Android-apk` | `Interface-Browser-Android.apk` — sideload on any Android 5+ phone |
| `Interface-Browser-Windows-x64-exe` | `Interface-Browser-Windows-x64.zip` — unzip, run `interface_browser.exe` (portable, no install) |

Pushing a `v*` tag also creates a GitHub Release with both files attached.

### Build it yourself

```bash
flutter pub get
flutter run                  # attached device / Windows
flutter build apk --release  # Android
flutter build windows --release  # Windows (run in build/windows/x64/runner/Release)
```

Requirements: Flutter stable + Android SDK (APK) or Visual Studio 2022 with "Desktop development with C++" (Windows). On Windows the browser uses WebView2, preinstalled on Windows 10/11.

## Notes

- The release APK is debug-signed (fine for sideloading); configure your own keystore for Play Store distribution.
- Incognito tabs are fully private on Android/iOS; on Windows they share the WebView2 profile (engine limitation).
- Launcher icons are generated deterministically: `python3 tool/gen_icons.py`.

## Project layout

```
lib/
  core/       palette (all 7 themes), URL parsing, search engines
  models.dart bookmarks / history / speed dial / downloads
  services/   web engine bootstrap, suggestions, downloads, blocklist
  state/      settings, profile, tabs (browser engine)
  widgets/    omnibox, tab strip, toolbar, speed dial, find bar, …
  pages/      browser shells (desktop/mobile), settings, history, …
```
