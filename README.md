# Interface Browser

A fast, themeable web browser for **phones (Android)** and **laptops (Windows)**, built with
Flutter and the platform's own web engine (`flutter_inappwebview` — System WebView on Android,
WebView2 on Windows).

## How it looks

Interface keeps the parts you already know — tabs, an address field, a menu — but arranges them
as one quiet row:

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│ ◈  [◀ ▶ ⟳ ⌂]  (● GitHub  ✕)( HN  ✕)( + )   │  ⌌ github.com · Search or type     ☆  ⬇  ▤  ⋯ │
│ ▁▁▁▁▁▁▁ loading line ─────────────────────                                         │
├──────────────────────────────────────────────────────────────────────────────────┤
│  the page                                                                         │
└──────────────────────────────────────────────────────────────────────────────────┘
```

- **Tabs are pills in the bar**, not a strip of folders on top of the page. Each shows its icon,
  title, loading state and a colour dot when it belongs to a group. On narrow windows they collapse
  into one button that opens the tab grid.
- **The address field lives in the same row**, with a lock that opens site information, suggestions
  that bold what you typed, and history / bookmark / search matches in one list.
- **Flat surfaces, one hairline each.** No raised cards, no blur except the wallpaper theme.
  Rounding is consistent: 8 for controls, 10 for fields, 14 for cards, 18 for sheets.
- **Colour means something.** Cyan only appears where something is happening: focus, loading,
  the selected tab, blocked requests. Everything else is navy ink on cool paper.
- **Plain words.** "Bookmarks", "History", "Downloads", "Reader view", "New private tab" — no
  counters, codes or status readouts stacked on top of the page.
- On phones the controls sit in one rounded dock at the bottom (address, back / forward / reload,
  shield, tab count, menu) with a 2px progress line at the top of the screen.

Design tokens and the shared widgets that enforce all of this are in `lib/core/ui.dart` and
`lib/widgets/ui_kit.dart`.

## Features

- 🌐 **Real web browsing** — native WebView engine on every platform, tabs stay alive when you switch them
- 🎨 **7 themes** — System · Light · Dark (navy/cyan) · Red · Green · Black & White (can render pages fully desaturated) · **Custom picture background** (frosted-glass chrome over your wallpaper)
- ⚡ **Shortcuts on the new tab page** — a greeting, one search field, and an editable grid of favorite sites with folders and drag-to-reorder
- 🔍 **Smart address field** — search and address in one box, with live suggestions, history and bookmark matches, a built-in calculator and full keyboard navigation
- 🗂 **Tabs** — pill tabs with context menus, groups, middle-click close and split view; a grid switcher on phones; private tabs get their own chrome
- ⭐ **Bookmarks** — the star in the bar, an optional bookmarks row, and a full manager with edit/delete
- 🕘 **History** — grouped by day, per-item delete, clear-browsing-data dialog (history/cookies/cache)
- ⬇️ **Real downloads** — streamed with progress and cancel, saved to your Downloads folder (Windows) / app Downloads (Android)
- 🔎 **Find in page** (Ctrl+F) with match counter
- 🛡 **Block ads & pop-ups** — built-in host blocklist, one-tap toggle
- 🖥 **Desktop-site mode** for phones, per-window layout that adapts ≥840 px
- ⌨️ **Keyboard shortcuts** — Ctrl+T / Ctrl+W / Ctrl+Tab / Ctrl+L / Ctrl+F / Ctrl+D / Ctrl+R / Alt+←→ / Ctrl+1…9
- 🎬 Fullscreen video, and camera / microphone / location requests handled with a clear allow-once / allow / block prompt
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
  core/       palette (all 7 themes), design tokens, URL parsing, search engines
  models.dart bookmarks / history / speed dial / downloads
  services/   web engine bootstrap, suggestions, downloads, blocklist
  state/      settings, profile, tabs (browser engine)
  widgets/    the one-row bar, pill tabs, address field, speed dial, find bar, …
  pages/      browser shells (desktop/mobile), settings, history, …
```

## Building the apps

See **[BUILD.md](BUILD.md)** — both the Android APK and Windows EXE build
on GitHub Actions; you can trigger a build yourself from the
**Actions → Build → Run workflow** button, no toolchain required.
