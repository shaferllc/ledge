# Ledge

[![CI](https://github.com/shaferllc/ledge/actions/workflows/ci.yml/badge.svg)](https://github.com/shaferllc/ledge/actions/workflows/ci.yml)

A native macOS clone of [MacNotch](https://macnotch.io) — turns the MacBook
notch into an interactive, modular dashboard. Hover the notch and it expands
into a hub of live modules; move away and it melts back into the notch.

Works on notched MacBooks (hugs the physical notch) and on flat-top / external
displays (a small pill at the top-center).

## Notch behaviors

- **Hover to expand** into the dashboard; move away and it collapses.
- **Volume / mute HUD** — changing the system volume flashes a bar *in the notch*
  (via a CoreAudio listener), instead of only the default macOS HUD.
- **Drag-to-expand** — drag a file toward the notch and it opens as a drop target
  for the Shelf.
- **Live activity** — while music plays the collapsed bar widens to show album art
  and an equalizer beside the notch.
- **⌘⌥N** toggles the dashboard from anywhere; optional expand-on-click.

## Modules

- **Now Playing** — art, title/artist, a **draggable scrubber**, spectrum bars,
  and play·pause·skip for Spotify or Apple Music, with a blurred album-art
  backdrop. Driven over AppleScript.
- **File Shelf** — drop files onto the notch to stash them, then drag them back
  out, AirDrop, Zip (to Desktop), or Reveal in Finder.
- **Calendar** — live clock, current-week strip, today's next events, and a
  one-click **Join** button for Zoom/Meet/Teams/Webex meetings (EventKit).
- **Weather** — current conditions + high/low for your location (Open-Meteo).
- **System** — live CPU, memory, and battery meters.
- **Network** — Wi-Fi network + live up/down throughput.
- **Storage** — free / used disk space.
- **Clipboard** — recent copied-text history; click an entry to copy it back.
- **Bluetooth** — battery levels for AirPods, Magic Mouse/Keyboard/Trackpad.
- **World Clock** — a few time zones at a glance.
- **Quick Notes** — a persistent scratchpad.
- **Pomodoro** / **Stopwatch** / **Countdown** — focus timer, stopwatch w/ laps,
  quick countdown with presets.
- **Caffeine** — keep your Mac awake (also in the menu bar).
- **Shortcuts** — pin favorite apps and launch them from the notch.
- **Mirror** — a live front-camera preview.

Also in the menu bar: a **Sound Output** switcher and the **Caffeine** toggle.

Toggle modules, **drag to reorder**, pick an accent color and dashboard size, and
set startup behavior from the menu-bar icon → **Settings…** (a custom sidebar UI).

## Build & run

```sh
./make-app.sh            # builds release, assembles ~/Desktop/Ledge.app
./make-app.sh --install  # …and moves it to /Applications + launches it
```

Requires macOS 14+ and a Swift 6 toolchain. The app is ad-hoc codesigned so the
Automation (Spotify/Music) and Calendar permission grants bind to a stable
identity across launches.

Ledge runs as a menu-bar utility (no Dock icon). It lives above the menu bar so
it can draw into the notch region.

## Distribution

`make-dmg.sh` builds a distributable `build/Ledge.dmg` (the app plus an
*Applications* drop link):

```sh
./make-dmg.sh            # ad-hoc DMG — fine for yourself; other Macs get a
                         # Gatekeeper prompt (right-click → Open to bypass)
```

For a DMG that launches cleanly on any Mac, sign with a Developer ID and
notarize:

```sh
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARIZE=1 AC_APPLE_ID=you@example.com AC_TEAM_ID=TEAMID \
AC_PASSWORD=app-specific-pw \
./make-dmg.sh
```

This signs with the hardened runtime (`Ledge.entitlements` grants the Apple
Events entitlement the AppleScript-driven Now Playing module needs), notarizes +
staples the app, packages it, then notarizes + staples the DMG.

### Releasing via CI

Pushing a `v*` tag runs `.github/workflows/release.yml`, which builds the
notarized DMG and attaches it to a GitHub Release:

```sh
git tag v0.4 && git push origin v0.4
```

It reads these repository secrets (without them it still builds an ad-hoc DMG):

| Secret | What |
| --- | --- |
| `MACOS_CERTIFICATE` | base64 of your Developer ID Application `.p12` |
| `MACOS_CERTIFICATE_PWD` | password for that `.p12` |
| `MACOS_SIGN_IDENTITY` | e.g. `Developer ID Application: Tom Shafer (TEAMID)` |
| `KEYCHAIN_PASSWORD` | any string; for the throwaway CI keychain |
| `AC_APPLE_ID` / `AC_TEAM_ID` / `AC_PASSWORD` | Apple ID + app-specific password for notarization |

Export the `.p12` from Keychain Access (your Developer ID Application cert +
private key) and base64 it with `base64 -i cert.p12 | pbcopy`.

## Architecture

- `Notch/` — the overlay: `NotchPanel` (borderless non-activating `NSPanel`),
  `NotchController` (positioning + hover-driven collapse/expand animation),
  `NotchGeometry` (physical notch detection), `NotchShape` (the silhouette).
- `Model/` — `AppState` (observable singleton, persisted settings) plus one
  model per live module.
- `Views/` — `NotchView` root → `CollapsedView` / `ExpandedView`, and the
  per-module cards under `Views/Modules/`.

## Tests

```sh
swift test
```

Unit tests (`Tests/LedgeTests/`) cover the pure model logic — clipboard
classification and hex parsing, weather-code mapping, module metadata, timer
formatting, shelf de-duplication, and now-playing progress. They import the
executable target with `@testable import Ledge`.

## Self-test

```sh
LEDGE_SELFTEST=1 .build/release/Ledge
```

Renders the expanded dashboard to `~/Desktop/ledge-selftest.png` and prints a
summary — a headless check of the full view tree and the system sampler.
