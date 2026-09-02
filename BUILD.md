# Building Interface Browser

You do **not** need Flutter, Android Studio, or Windows tooling installed —
GitHub Actions builds both apps for you in the cloud.

## Run a build yourself (browser only)

1. Open the repo on GitHub → **Actions** tab → **Build** workflow
   (left sidebar).
2. Click the **Run workflow** ▾ button on the right.
3. Pick the branch to build (usually `main`), tick/untick
   *Build the Android APK* and *Build the Windows EXE*, then click
   **Run workflow**.
4. Wait ~6–10 minutes for the green tick, open the finished run and
   scroll to the **Artifacts** section at the bottom:
   - `Interface-Browser-Android-apk` → contains `Interface-Browser-Android.apk`
   - `Interface-Browser-Windows-x64-exe` → contains the portable app folder
     (unzip anywhere and run `interface_browser.exe`)

The same workflow also runs automatically on every push to `main`
or `arena/**` branches.

### Command-line alternative (gh CLI)

```bash
gh workflow run Build --ref main            # start a build
gh run watch                                # follow it live
gh run download <run-id> -n Interface-Browser-Android-apk -D out/apk
gh run download <run-id> -n Interface-Browser-Windows-x64-exe -D out/exe
```

## Releases (permanent download page)

Pushing a tag that starts with `v` builds both apps and attaches them to a
GitHub **Release** automatically:

```bash
git tag v1.1.1
git push origin v1.1.1
```

Then find the binaries under **Releases** on the repo home page — no
Actions navigation needed.

## Building locally (optional)

Requires Flutter stable + platform toolchains:

```bash
flutter pub get
flutter build apk --release        # Android  → build/app/outputs/flutter-apk/
flutter build windows --release    # Windows  → build/windows/x64/runner/Release/
```

Windows needs Visual Studio with C++ workload; the browser uses the
WebView2 runtime (preinstalled on Windows 11, otherwise install it from
Microsoft).
