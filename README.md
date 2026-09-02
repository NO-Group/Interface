# Interface Browser

A fast, themeable web browser for **phones (Android)** and **laptops (Windows)**, built with
Flutter and the platform's own web engine (`flutter_inappwebview` — System WebView on Android,
WebView2 on Windows).

## How it looks

Interface keeps the parts you already know — tabs, an address field, a menu — but arranges them
as one quiet row:

```
+------------------------------------------------------------------------------+
| logo | back fwd reload home | ( o GitHub  x )( HN  x )( + ) | address field |
|                                                       shield star dl side menu|
|  loading line ...............................................................|
+------------------------------------------------------------------------------+
|  the page                                                                     |
+------------------------------------------------------------------------------+
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

- **Real web browsing** — the platform's own engine (System WebView / WebView2); tabs stay alive
  when you switch them.
- **Files** — a full file manager: open any folder on the device, make folders and files, rename,
  copy, move, delete, search inside a folder, list or tiles, kept places, open a file in a tab or
  in the app that usually takes it. Reached from the sidebar, the menu and quick actions.
- **7 themes** — System, Light, Dark (navy and cyan), Red, Green, Black & White (can also show web
  pages without colour), and a picture background of your own with frosted chrome.
- **Shortcuts on the new tab page** — a greeting, one search field, and an editable grid of
  favourite sites with folders and drag-to reorder.
- **One address field for search and addresses** — live suggestions, history and bookmark matches,
  a built-in calculator, full keyboard navigation.
- **Tabs** — pill tabs with context menus, groups, middle-click close and split view; a grid
  switcher on phones; private tabs get their own look.
- **Bookmarks** — the star in the bar, an optional bookmarks row, and a manager with edit and delete.
- **History** — grouped by day, delete one item, or clear everything from settings.
- **Downloads** — streamed with progress and cancel, saved into your Downloads folder, and the file
  manager opens on that folder in one tap.
- **Find in page** with a match count.
- **Ad and tracker blocking** with a per-site switch, a privacy dashboard and "hide leftover ad spaces".
- **Desktop-site request** for phones; the layout adapts from 840 px up.
- **Keyboard shortcuts** — Ctrl+T, Ctrl+W, Ctrl+Tab, Ctrl+L, Ctrl+F, Ctrl+D, Ctrl+R, Ctrl+K,
  Alt+Left / Alt+Right, Ctrl+1 to 9.
- **Fullscreen video**, and camera / microphone / location prompts with allow once, allow, block.
- **Session restore** — your tabs come back on startup.
- **Its own icon set** — 115 line icons drawn as SVG in `assets/icons/`, recoloured to match the
  text around them. No emoji, no icon font.

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
- Private tabs keep history and cookies out of the profile on Android and iOS; on Windows they
  share the WebView2 profile (an engine limitation).
- Launcher icons are generated deterministically: `python3 tool/gen_icons.py`.

## Project layout

```
lib/
  core/       palette (all 7 themes), design tokens, URL parsing, search engines
  models.dart bookmarks / history / speed dial / downloads
  services/   web engine bootstrap, suggestions, downloads, blocklist
  state/      settings, profile, tabs (browser engine)
  widgets/    the one-row bar, pill tabs, address field, speed dial, find bar, icons, …
  pages/      browser shells (desktop/mobile), settings, history, files, …
```

## Building the apps

See **[BUILD.md](BUILD.md)** — both the Android APK and Windows EXE build
on GitHub Actions; you can trigger a build yourself from the
**Actions → Build → Run workflow** button, no toolchain required.
