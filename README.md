# Mahalla Cruise

A small 2D Android driving game inspired by neighborhoods in Uzbekistan.
Built with **Godot 4.7.2 Standard and GDScript** using the Compatibility renderer.

## Current prototype

Tap **Play** on the start screen to drive a white Damas past mahalla gates, non
shops, and choyxonas. The start screen shows your locally saved best score.
The interface opens in **Uzbek Latin** (**Boshlash** starts a drive). Choose
**Русский** or **English** from the start or pause menu. Menus, scoring, hints,
pickup feedback, and results use the selected language, which survives relaunch.
Drag with a mouse or one
finger to steer; the left and right arrow keys also work on a computer. The car
stays inside the road. Light traffic alternates between two lanes with small
placement variations, so occasional steering is needed even from the center.
Cars hold their line once visible. Collect real
banknote images: **1,000/5,000/10,000/50,000/100,000 soʻm** earn **1/5/10/50/100
points**. Larger notes appear less often. **$1 earns 10 points**; dollars appear
in 12% of spawns. These are game values. [Artwork sources](assets/money/README.md).
Crashing ends the run and shows your score, currency counts, and distance.
Click or tap **Drive again** to reset the score and start over
with a clear road. **Best** shows the highest completed run and persists locally
across app launches. Beating it shows **New best!** on game over. Artwork,
controls, and tuning remain provisional.

**Close calls:** passing a car within a few pixels without touching earns 3
points. Chaining close calls quickly builds a combo (×2 … ×5). Results show how
many close calls the run had (when there was at least one).

Close calls also play a rising whoosh (higher with each combo step) and, on
Android, a 12 ms pulse; both follow the Sound/Vibration toggles.

**Sheep crossing:** from 250 m, every 600–1,000 m a flock of two or three sheep
walks across the road. One road edge always stays open; hitting a sheep ends the
run ("The sheep had right of way!"). The sheep are simple drawn placeholders.

**Daily tasks:** open **Tasks** on the start screen. Each day draws three tasks of
different kinds (collect notes, close calls, distance or score in one run, number
of drives) from a pool of ten. Progress updates when a run ends; finished tasks pay
40–120 points into the wallet and are listed on the results screen.

**Paint:** the garage shows six colors for the selected car. Each car's factory
color is free; other colors cost 150 points once and then work on every car. A
shader repaints only the body, keeping lamps, glass, and stripes.

**Horn and music:** tap **Beep!** while driving for the Damas horn. A generated
dutar-and-doira style loop plays during drives (paused in menus) and has its own
**Music on/off** toggle, saved separately from sound effects.

**Garage:** every finished run adds its points to a saved wallet. Open **Garage**
from the start screen or results to buy and select cars. Each car has its own
speed, control, and size: Damas (free), Matiz (300), Cobalt (1,000), and Gentra
(2,500). Matiz, Cobalt, and Gentra currently use **temporary test art**: the
traffic sedan resized to each car's size, colored by its factory paint.
Car stats and prices are in `src/garage/`.

Use **Pause** (or **Escape** on desktop) to freeze the run, then **Resume** to
continue. Switching apps also pauses; returning never resumes automatically.
The first drive shows a six-second “Drag to steer / Collect money · Avoid cars”
hint. Its timer stops while paused, and the local save remembers that it was shown.
An OS-killed app opens at the start screen; unfinished runs are not restored.

Pickups play short chimes: soʻm and dollars have different sounds. Android also
uses a light vibration pulse. Use **Sound on/off** and **Vibration on/off** to
toggle feedback in the start/pause menu; choices persist across app launches.
Vibration controls appear on Android. Android Back pauses an active drive.
Scenery fills taller phone screens without black bands. The road keeps its authored
width, menus remain centered, and resizing pauses the drive safely.
Traffic gradually becomes
busier from 150 m to 900 m, then stops increasing. Its speed, minimum gap, and
three-car limit stay fixed.

## Get the project

```sh
git clone https://github.com/Yoko-ship/mahalla-cruise.git
cd mahalla-cruise
```

Source, assets, tests, and documentation are included. Install the development
tools locally; builds, engine caches, signing keys, and player saves are excluded.

## Run on Windows

With Python 3 and Git for Windows installed, run from PowerShell in the project:

```powershell
.\scripts\setup_tools.ps1
.\.venv\Scripts\python.exe scripts/godot.py --path .
```

Setup installs the pinned formatter/linter in `.venv/` and the official Godot
4.7.2 Windows engine in `.tools/godot/`, verifying its SHA-512 checksum. No engine
upgrade or game runtime dependency is introduced. Add `--editor` to open Godot.
Run the complete checks with `.\scripts\check.ps1`, or `./scripts/check.sh` in
Git Bash. Format with `.\.venv\Scripts\gdformat.exe src tests`.

Install Android tooling inside the project, then build and play in its emulator:

```powershell
.\.venv\Scripts\python.exe scripts/setup_android.py
.\.venv\Scripts\python.exe scripts/android.py run
```

Java, SDK, export templates, emulator data, editor settings, and the debug key stay
under ignored `.tools/`. SDK setup presents Google's licenses. Windows emulation
requires working hardware virtualization and Windows Hypervisor Platform.
Use `scripts/android.py build` for the ARM64 phone APK, or `build --emulator` for
the x86_64 emulator APK. See [Android setup and checks](docs/ANDROID.md).

## Run on Mac

Install Godot 4.7.2 Standard from the
[official archive](https://godotengine.org/download/archive/4.7.2-stable/).
On this development machine it is at `~/Applications/Godot.app`.
From the repository root:

```sh
./scripts/godot.sh --editor --path .
```

Press **F5** to run the project. To play directly:

```sh
./scripts/godot.sh --path .
```

The launcher accepts `GODOT_BIN` as an executable path or finds `godot` on PATH.

## Development setup and checks

Install the formatter and linter once using Python 3.9 or newer:

```sh
./scripts/setup_tools.sh
```

This creates an isolated `.venv` and installs `gdtoolkit==4.5.0` from PyPI. It
contains developer tools only; the game has no third-party runtime dependencies.

Run the complete local gate:

```sh
./scripts/check.sh
```

It checks the engine and toolkit versions, GDScript formatting and lint, shell
syntax, Godot import, every script's parsing, and all `tests/**/*_test.gd` suites.
A missing tool, failed assertion, engine error, timeout, or incomplete test run
fails the command. The gate does not install packages or rewrite source files.
Godot may regenerate its ignored import cache and script UID sidecars.

To fix formatting, run `.venv/bin/gdformat src tests`, then rerun the gate.
Do not disable rules to obtain a pass. `gdlintrc` sets a 100-character line limit
and a 300-line script limit; `.editorconfig` records whitespace conventions.

Tests cover pointer and keyboard steering, road boundaries, focus loss, settings
resources, synchronized scrolling, and HUD updates. Traffic tests check spawning,
spacing, node cleanup, and swept collisions. Game-over tests verify that crashes
freeze the run and that mouse and simulated touch restart it cleanly. Rendered output must
also be inspected for visual changes. Physical Android input and performance
have not been tested yet. Pickup tests cover denomination values, single collection,
misses, traffic avoidance, bounded cleanup, crash priority, and score reset.
Feedback tests cover audio selection, mute toggles, burst limits, focus loss,
crash/restart cleanup, the distance curve, and safe traffic at both ends of it.
Session tests cover mouse/touch Play, pause, background/foreground notifications,
frozen traffic and pickups, stale gesture prevention, and first-run persistence.
Preference tests cover mouse/touch language selection, relaunch, mute/haptics,
Android Back notifications, damaged settings, backup recovery, protected future
saves, and failed-write retries. Localization tests verify all three catalogues,
format placeholders, large scores, and start/pause/result layout bounds. Viewport
tests cover original/tall/wide portrait layouts, resize pause, gesture cleanup,
offscreen spawning/removal, safe pickup predictions, and restart placement.
Save tests cover fresh installs, round trips, backup recovery, invalid data,
newer-version protection, unknown fields, failed writes, and gameplay integration.
Tests use isolated paths and never modify the player save.
The public repository is [Yoko-ship/mahalla-cruise](https://github.com/Yoko-ship/mahalla-cruise).
CI is not configured; run the local quality gate before pushing.

## Architecture and tuning

| Path | Purpose |
| --- | --- |
| `src/main.tscn`, `src/main.gd` | Compose features and own shared travel progress. |
| `src/driving/` | Car scene, input, movement, visual, and car settings. |
| `src/road/` | Road renderer and shared route settings. |
| `src/scenery/` | Decorative buildings and trees. |
| `src/traffic/` | Spawning, contact detection, sedan sprites, and traffic settings. |
| `src/pickups/` | Money spawning, collection, banknote visuals, and point values. |
| `src/progress/` | Versioned save data, local persistence, wallet, and recovery. |
| `src/garage/` | Car roster, per-car stats and prices, and the garage screen. |
| `src/audio/` | Background music and horn playback. |
| `src/daily/` | Daily task pool, today's draw and progress, and the tasks screen. |
| `src/ui/` | HUD, shared start/pause menu, hint timing resource, and display logic. |
| `tests/`, `scripts/` | Behavior checks and development commands. |

Tune handling in `src/driving/default_car.tres` and road speed/geometry in
`src/road/default_road.tres`. Traffic spacing, speed, and collision bounds are in
`src/traffic/default_traffic.tres`. Each feature owns its scenes, scripts, and data.
Pickup points, rarity, spacing, bounds, and traffic clearance are in
`src/pickups/default_pickups.tres`. The best completed score is saved separately
in `user://progress.json`; run points and note counts reset on restart.
See [docs/SAVES.md](docs/SAVES.md) for the format and extension points.
The Damas and traffic share `assets/cars/vehicles_aligned.png`. The connected
street uses `assets/scenery/mahalla_street.png`. Both use mipmaps; artwork and
generation records are documented in `assets/ANGLED_ART.md`.
`assets/icon.svg` is the temporary launcher icon.

Tune pickup volume and vibration in `src/pickups/default_feedback.tres`.
Original chimes and their reproducible generator are documented in
`assets/audio/README.md`. Difficulty distances and the final spawn scale are
in `src/traffic/default_traffic.tres`.

Read [ARCHITECTURE.md](ARCHITECTURE.md) for module boundaries and data flow,
[AGENTS.md](AGENTS.md) for contributor and AI rules, and [PROJECT.md](PROJECT.md)
for decisions and progress.

## Run on the Android emulator

Android tooling supports Apple Silicon Mac and Windows. To build, start the virtual
phone, install, and launch the game:

```sh
./scripts/android.sh run
```

The emulator launcher uses GPU acceleration and a lighter 720 × 1520 display.
Use `./scripts/android.sh run --native-resolution` for native Pixel 4 resolution
checks (1080 × 2280). These settings affect the emulator, not the exported game.
The ARM64 phone APK is written to `build/android/mahalla-cruise-debug.apk`;
Windows `run` builds `build/android/mahalla-cruise-emulator.apk` for its x86_64 AVD.
See [docs/ANDROID.md](docs/ANDROID.md) for installation, individual
commands, toolchain locations, and troubleshooting. This is a local debug build;
production signing and store publishing are not configured.
