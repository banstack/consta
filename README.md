# Consta

A macOS menu bar app for tracking focus sessions by label, with goals, XP, levels and badges to make productivity a bit of a game. The successor to [insession](https://github.com/banstack/insession), rebuilt as a native SwiftUI app with Apple's Liquid Glass design.

## Features

- **Sessions from the menu bar.** Pick a label, press Start, and the live timer shows next to the menu bar icon. Pause, resume, stop.
- **Labels.** Tags for what you're working on (Deep Work, Reading, …), each with a color from a ten-swatch palette. The four you used most recently are one click away.
- **History.** Every past session by day, with its note and XP, and the last seven days at a glance.
- **Goals.** Daily or weekly time targets per label, with streaks.
- **XP and levels.** 1 XP per focused minute, +50 XP for a daily goal, +200 XP for a weekly goal. Level 1 → 2 takes 300 XP and each level takes 250 XP more than the last.
- **Badges.** Nine achievements, from First Step to a 30-day Marathon streak.
- **Private.** Everything is stored locally with SwiftData. No account, no server.
- **Settings.** Manage labels, hide the menu bar timer, open at login, and see the version and build number.

Mockups and screenshots of every screen live in the [Consta Screens gallery](https://claude.ai/artifact/1cqrPNBm5Tqvim7gr6Sojm).

## Requirements

- macOS 27 or later
- Xcode with the macOS 27 SDK

## Run it

```bash
swift run Consta
```

Or open `Package.swift` in Xcode and run the `Consta` scheme. The app has no Dock icon; look for the constellation icon in the menu bar.

## Package a DMG

```bash
scripts/make-dmg.sh
```

This builds a release `Consta.app` (bundle id `com.banstack.consta`, menu bar only, with an app icon drawn by `scripts/make-icon.swift`) and wraps it in `dist/Consta-<version>.dmg` with a shortcut to Applications. `scripts/build-app.sh` builds just the app.

Without signing credentials, the app is ad-hoc signed. It runs, but on someone else's Mac the first launch is blocked: they open **System Settings › Privacy & Security** and click **Open Anyway** once. To get a DMG that opens without a warning, sign with a Developer ID and notarize it (both need the Apple Developer Program):

```bash
xcrun notarytool store-credentials consta   # once: Apple ID, team ID, app-specific password
CONSTA_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
CONSTA_NOTARY_PROFILE=consta \
scripts/make-dmg.sh
```

### Releases

Pushing a tag like `v0.1.0` runs `.github/workflows/release.yml`, which tests, builds the DMG and attaches it to a GitHub release. It signs and notarizes when these repository secrets are set and builds an unsigned DMG otherwise:

| Secret | What it is |
| --- | --- |
| `MACOS_CERTIFICATE` | Your Developer ID Application certificate exported as .p12, base64-encoded (`base64 -i cert.p12 \| pbcopy`) |
| `MACOS_CERTIFICATE_PASSWORD` | The .p12 export password |
| `MACOS_SIGN_IDENTITY` | The identity name, e.g. `Developer ID Application: Your Name (TEAMID)` |
| `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD` | The Apple ID, team ID and app-specific password used for notarization |

## Tests

```bash
swift test
```

### Scripted UI runs

Debug builds include a small driver for exercising the UI and taking screenshots without Accessibility or Screen Recording permission. It uses an in-memory store, so your data isn't touched. Commands are read from stdin, one per line (`open`, `click X Y`, `type TEXT`, `key return`, `sleep SECONDS`, `shot PATH`, `dump`, `quit`; see `Sources/Consta/Support/DebugDriver.swift`):

```bash
printf 'open\nsleep 1\nshot /tmp/idle.png\nquit\n' | CONSTA_DRIVER=1 swift run Consta
```

## Layout

| Path | What's there |
| --- | --- |
| `Sources/ConstaKit` | Pure game logic: level curve, XP rules, goal progress and streaks, badges, and the `Progression` evaluator that works out what a session earns. No UI or persistence, fully unit-tested. |
| `Sources/Consta` | The SwiftUI menu bar app. `Models/` holds the SwiftData models, `Support/` the session stopwatch and persistence helpers, `Views/` one file per screen. |
| `Tests/ConstaKitTests` | Swift Testing tests for `ConstaKit`. |
| `Packaging`, `scripts` | The app bundle's Info.plist and the app, icon and DMG build scripts. |
