# Mahalla Cruise

A small 2D Android driving game inspired by neighborhoods in Uzbekistan.
Built with **Godot 4.7.2 Standard and GDScript** using the Compatibility renderer.

## Current prototype

Tap **Play** on the start screen to drive a white Damas past mahalla gates, non
shops, and choyxonas. The start screen shows your locally saved best score.
Drag with a mouse or one
finger to steer; the left and right arrow keys also work on a computer. The car
stays inside the road. Light traffic alternates between two lanes. Collect real
banknote images: **1,000/5,000/10,000/50,000/100,000 soʻm** earn **1/5/10/50/100
points**. Larger notes appear less often. **$1 earns 10 points**; dollars appear
in 12% of spawns. These are game values. [Artwork sources](assets/money/README.md).
Crashing ends the run and shows your score, currency counts, and distance.
Click or tap **Drive again** to reset the score and start over
with a clear road. **Best** shows the highest completed run and persists locally
across app launches. Beating it shows **New best!** on game over. Artwork,
controls, and tuning remain provisional.

Use **Pause** (or **Escape** on desktop) to freeze the run, then **Resume** to
continue. Switching apps also pauses; returning never resumes automatically.
The first drive shows a six-second “Drag to steer / Collect money · Avoid cars”
hint. Its timer stops while paused, and the local save remembers that it was shown.
An OS-killed app opens at the start screen; unfinished runs are not restored.

Pickups play short chimes: soʻm and dollars have different sounds. Android also
uses a light vibration pulse. Use **Sound on/off** and **Vibration on/off** to
toggle feedback; choices last until the app closes. Traffic gradually becomes
busier from 150 m to 900 m, then stops increasing. Its speed, minimum gap, and
three-car limit stay fixed.

## Get the project

```sh
git clone https://github.com/Yoko-ship/mahalla-cruise.git
cd mahalla-cruise
```

Source, assets, tests, and documentation are included. Install the development
tools locally; builds, engine caches, signing keys, and player saves are excluded.

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
freeze the run and that mouse and simulated touch restart it cleanly. A rendered Mac preview must
also be inspected for visual changes. Physical Android input and performance
have not been tested yet. Pickup tests cover denomination values, single collection,
misses, traffic avoidance, bounded cleanup, crash priority, and score reset.
Feedback tests cover audio selection, mute toggles, burst limits, focus loss,
crash/restart cleanup, the distance curve, and safe traffic at both ends of it.
Session tests cover mouse/touch Play, pause, background/foreground notifications,
frozen traffic and pickups, stale gesture prevention, and first-run persistence.
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
| `src/progress/` | Versioned save data, local persistence, and recovery. |
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

The Android toolchain is configured on this Mac. To build, start the virtual
phone, install, and launch the game:

```sh
./scripts/android.sh run
```

The emulator launcher uses GPU acceleration and a lighter 720 × 1520 display.
Use `./scripts/android.sh run --native-resolution` for native Pixel 4 resolution
checks (1080 × 2280). These settings affect the emulator, not the exported game.
The debug APK is written to `build/android/mahalla-cruise-debug.apk`.
See [docs/ANDROID.md](docs/ANDROID.md) for installation on a new Mac, individual
commands, toolchain locations, and troubleshooting. This is a local debug build;
production signing and store publishing are not configured.
