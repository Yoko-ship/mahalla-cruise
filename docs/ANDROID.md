# Android Development

The Android preset builds a local ARM64 debug APK for Mahalla Cruise. Development
uses Godot 4.7.2 Standard and an Android 15 virtual phone on an Apple Silicon Mac.

## Install the Toolchain

Godot itself and Python 3.9 or newer must already be installed. From the repository root:

```sh
python3 scripts/setup_android.py
```

The installer downloads Java 17, Android command-line tools 19.0, and the Android
export templates matching Godot 4.7.2. It checks the base archives against their
publishers' checksums. Android's SDK manager installs Platform 35, Build Tools
35.0.1, Platform Tools, the emulator, and the Google APIs ARM64 Android 35 image.
SDK licenses are shown interactively; `--accept-sdk-licenses` accepts them without
prompts when that is intended. No shell profile changes are required.

The installer creates `Mahalla_API_35`, a Pixel 4 virtual device. Existing
toolchain directories and an existing AVD are reused. Packages come from
[Google's SDK tools](https://developer.android.com/tools/sdkmanager),
[Adoptium](https://github.com/adoptium/temurin17-binaries), and the
[matching Godot release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable).

| Component | Default local location |
| --- | --- |
| Android SDK | `~/Library/Android/sdk` |
| Java 17 | `~/Library/Java/JavaVirtualMachines/mahalla-temurin-17.jdk/Contents/Home` |
| Android export templates | `~/Library/Application Support/Godot/export_templates/4.7.2.stable` |
| Virtual device | `~/.android/avd/Mahalla_API_35.avd` |
| Debug signing key | `~/Library/Application Support/Godot/keystores/debug.keystore` |

The APK uses Godot's prebuilt native template, so this workflow does not compile
native code or require Gradle, NDK, or CMake. See Godot's
[Android export guide](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html)
when adding native plugins or changing the export method.

## Build and Run

```sh
./scripts/android.sh run
```

This runs the full quality gate, builds and verifies the signed debug APK, starts
the project emulator, installs the APK, and opens the game. The emulator uses the Mac GPU (`-gpu host`) with Guest ANGLE for Android
OpenGL ES compatibility. It starts with a fresh boot each time; startup can take
around 20 seconds. Close the emulator window when finished.

Audio output is enabled for pickup chimes. If an older emulator session was
started with `-no-audio`, close it and start it through this launcher again.

Individual steps are also available:

```sh
./scripts/android.sh build
./scripts/android.sh emulator
./scripts/android.sh install
./scripts/android.sh devices
```

`install` installs and launches the existing APK; run `build` first after edits.
`run` always builds current code. The launcher targets only `Mahalla_API_35` on
`emulator-5554` and refuses to install into a different emulator. If another AVD
occupies port 5554, close it before starting this one.

`ANDROID_HOME` and `JAVA_HOME` can override the default build-tool locations.
Building updates only the Java and Android SDK paths in Godot's local editor
settings. The debug key is created on first build and stays outside the repository.

## Outputs and Diagnostics

- APK: `build/android/mahalla-cruise-debug.apk`.
- Godot export output: `build/android/export.log`.
- Emulator output: `build/android/emulator.log`.
- Verification screenshots: `build/android/screenshots/` when captured.

`build/` and Godot's `.godot/` import cache are ignored by Git. The preset exports
all game resources, including scenes spawned from scripts, while excluding
development scripts and tests. The prebuilt Godot template targets Android API 36
and supports API 24 or newer; our emulator runs API 35.
`com.example.mahallacruise` is the provisional debug application ID. Production
signing, a final application ID, and Play Store publishing are separate work.

## Emulator Checks

Check that the game opens in portrait, dragging steers the car, a collision shows
Game over and the final distance, and Drive again resets the run. Check both the
playing scene and overlay for clipping on the virtual phone's taller screen.
Review app logs for script errors or Android crashes.

Initial validation on 2026-10-06 with Pixel 4 / API 35 / ARM64 at 1080 × 2280:

- The 28.1 MiB APK at that stage included the Damas and three mahalla scenery textures.
- Left and right touch drags moved the car.
- Collision showed Game over at 91 m; screenshots two seconds apart were identical.
- Tapping Drive again cleared traffic, centered the car, and restarted distance.
- HUD and overlay fit the portrait canvas, with letterboxing on the taller display.
- All 66 local checks at that stage passed; app logs showed no script errors or fatal exceptions.

Screenshots and `app.log` are saved under `build/android/` on this machine.
Emulator validation covers the Android build and simulated touchscreen input.
A physical Android phone is still needed to evaluate real touch feel, frame rate,
battery use, and thermal behavior.

Latest feedback build: 31.8 MiB, with 154 passing local checks. Android's
vibrator history recorded both 16 ms and 26 ms app pulses at amplitude 0.25.
The APK declares VIBRATE. Both HUD toggles responded to Android touch input.
The emulator disconnected before a second vibration-history sample could verify
the disabled state; automated tests cover toggle routing. The emulator checks
the request path; testing actual vibration feel requires a phone.
Evidence is in `build/android/feedback-*.log` and
`build/android/screenshots/feedback-*.png`.

## Graphics Performance

Use the checked-in launcher to enable `-gpu host -feature GuestAngle` together.
It also persists `hw.gpu.enabled=yes` and `hw.gpu.mode=host` in the project AVD.
Setup updates these keys for existing AVDs too; it retains all emulator user data.
The previous saved AVD configuration had GPU disabled even though the launcher
correctly overrode it. Always launch through the script for the GuestAngle flag.
See the official [graphics acceleration guide](https://developer.android.com/studio/run/emulator-acceleration).

Daily development now uses a **720 × 1520** Android display override at 293 dpi.
This keeps the Pixel 4 aspect ratio and approximately the same logical Android
UI size while reducing rendered pixels by 56%. Resizing the Mac window alone
does not reduce Android's rendering resolution. The exported game is unchanged.

```sh
./scripts/android.sh emulator                     # lighter development display
./scripts/android.sh run                          # build/install with that display
./scripts/android.sh emulator --native-resolution # clear size and density overrides
./scripts/android.sh run --native-resolution      # native 1080 × 2280 validation
```

2026-10-06 lag follow-up: fresh visible-emulator gameplay samples at both
1080 × 2280 and 720 × 1520 presented 359 game frames over approximately six
seconds (about 60 FPS), with no dropped frames reported by the layer counters.
The presentation histograms were centered at 16–17 ms. Severe stutter was not
reproduced in those samples, so this is a reduction in emulator workload and a
configuration fix, not proof that every reported hitch is resolved. Emulator
host CPU snapshots were 74% and 66%, respectively; short snapshots are not a
controlled performance benchmark. Window presentation/input latency and physical
phone performance are not established by these counters.

Evidence: `build/android/lag-1080-frames.txt`, `lag-720-frames.txt`, matching
`*-host.txt` files, and screenshots under `build/android/screenshots/lag-*.png`.

## Known Launch Issue

On some fresh emulator boots the first app launch returned to the Android home
screen without a crash-buffer report. Running `./scripts/android.sh install`
again successfully launched the same APK. This was observed before and after the
Damas art change; the cause has not been established.

## Session-flow validation (2026-10-06)

The 32.3 MiB debug build passed 307 local behavior checks. On the Pixel 4 API 35
AVD, touch Play opened gameplay; Home followed by returning showed Pause at the
same run position. Screenshots two seconds apart were identical. Touch Resume
continued progress, and the Pause button froze it again. The first-drive hint
was present initially, its saved v1 onboarding flag was verified, and a fresh
app launch did not repeat it. Start/pause text and controls fit the portrait view.

Evidence: `build/android/screenshots/session-*.png` and `session-app.log` in
`build/android/`. App logs contained no script errors or fatal exceptions.
The first visible emulator disconnected; validation completed with the same AVD
running without a window. This verifies emulator lifecycle behavior, not physical
phone performance. An OS-killed process starts a fresh run from the start screen.
