# Ledge

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
- **Clipboard** — recent copied-text history; click an entry to copy it back.
- **Bluetooth** — battery levels for AirPods, Magic Mouse/Keyboard/Trackpad.
- **Pomodoro** — 25/5 focus timer with a progress ring.
- **Stopwatch** — with laps.

Toggle modules, **drag to reorder**, pick an accent color and panel size, and set
startup behavior from the menu-bar icon → **Settings…**.

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

## Architecture

- `Notch/` — the overlay: `NotchPanel` (borderless non-activating `NSPanel`),
  `NotchController` (positioning + hover-driven collapse/expand animation),
  `NotchGeometry` (physical notch detection), `NotchShape` (the silhouette).
- `Model/` — `AppState` (observable singleton, persisted settings) plus one
  model per live module.
- `Views/` — `NotchView` root → `CollapsedView` / `ExpandedView`, and the
  per-module cards under `Views/Modules/`.

## Self-test

```sh
LEDGE_SELFTEST=1 .build/release/Ledge
```

Renders the expanded dashboard to `~/Desktop/ledge-selftest.png` and prints a
summary — a headless check of the full view tree and the system sampler.
