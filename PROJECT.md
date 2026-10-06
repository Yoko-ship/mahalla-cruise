# Mahalla Cruise Project Tracker

Last updated: 2026-10-06

Mahalla Cruise is a planned 2D Android game for people in Uzbekistan. The goal is a simple, relaxing time killer: open the game, steer with one finger, and enjoy a familiar neighborhood without puzzles or complicated decisions. Development should stay manageable for a first version.

## Current Status

**Stage: start screen, pause/resume, and first-run guidance implemented.**

The game opens on a Damas start screen with the saved best and Play. Pause and
Resume preserve the active run; app switching pauses automatically and requires
explicit Resume on return. The first drive shows a six-second steering/collection/
traffic hint, timed only while driving. A compatible optional v1 save field
remembers onboarding without resetting an existing best score.

The best completed score loads on startup, appears in the HUD, and survives run
restart and app relaunch. A higher score on collision saves it and shows
“New best!” in the results. Storage is a separate module with a versioned JSON
schema, backup recovery, and protection for saves from newer game versions.
Player saves live outside the repository in `user://`; tests use isolated paths.

Soʻm and dollars now play distinct short chimes. Android requests 16 ms/26 ms
vibration pulses at 0.25 strength; sound and vibration have separate HUD toggles.
Traffic ramps from its initial spacing at 150 m to 72% spacing at 900 m, with
the same three-car cap, minimum gap, and vehicle speed. Restart resets difficulty
and retains feedback preferences for the current app session.

Collect official banknote images: 1,000/5,000/10,000/50,000/100,000 soʻm award
1/5/10/50/100 points, with weights 50/28/16/5/1 within soʻm spawns. $1 awards 10.
Each pickup displays its denomination; collection feedback includes earned points.
The HUD shows points and brief collection feedback. Game over shows distance,
final score, and counts of each note; Drive again resets all run totals and notes.
Dollar chance is currently 12% per spawn. These are game-point values.

After the user rejected the disconnected artwork and diagonal Damas, they asked
to implement the [angled gameplay reference](docs/art-direction/angled-gameplay-v1.png).
The playable scene now uses aligned rear-view Damas and sedan sprites, a connected
painted mahalla street, soft shadows, and a compact HUD. Parallel curbs map to
the same resource bounds used by steering and traffic. See
[runtime artwork notes](assets/ANGLED_ART.md) for assets, exact prompts, and sources.

Godot 4.7.2 Standard is installed at `~/Applications/Godot.app`. The project has a portrait scene, a scrolling road, illustrated courtyard gates, non shops, choyxonas, a white Damas sprite, and mouse, touch, and keyboard steering. Light traffic alternates lanes with generous gaps. A collision ends the run, freezes driving and distance, and shows a game-over screen. The Drive again button starts a clean run. Java 17, the Android SDK, matching Godot export templates, and an ARM64 Android 15 emulator are configured. A signed debug APK is available under `build/android/`.

Driving, input, car drawing, road, scenery, traffic, pickups, and HUD have separate
owners. Gameplay tuning lives in typed Godot resources. `ARCHITECTURE.md`
describes the boundaries, `AGENTS.md` defines the AI workflow, and
`./scripts/check.sh` runs the local quality gate. Development tooling uses
gdtoolkit 4.5.0 in `.venv`.

**Next task:** test pickup audio volume, vibration feel, and the difficulty ramp
on a physical Android phone. Verify best-score retention across an Android app
update and relaunch. Cloud saving is not implemented.
The intermittent initial emulator launch exit remains outstanding.

## Agreed Direction

- Target Android phones; development takes place on a Mac.
- Build Mahalla Cruise in 2D.
- Use an angled 2D view showing the Damas body and sides, with matching road, buildings, and traffic. Review one complete gameplay concept before rebuilding individual assets.
- Use Godot 4 with GDScript. The starter is configured and tested with Godot 4.7.2 Standard and the Compatibility renderer.
- Focus on easy, repetitive play that feels as effortless to start as scrolling.
- Include recognizable local cars and places from Uzbekistan.
- Keep both the gameplay and initial implementation simple.
- Start building with changeable defaults; discuss detailed design choices during the work instead of requiring an upfront questionnaire.
- Use a small modular architecture with feature scenes and resource-based tuning.
- AI may handle routine implementation independently. Ask before architecture changes, new or upgraded dependencies, or added gameplay scope unless the action is already explicitly authorized.
- Enforce formatting, lint, and behavior tests through one local check command. CI is not part of the current setup.
- A crash with another car ends the run. Show final distance and provide a restart button. Traffic tuning remains provisional.
- Score soʻm by denomination: 1 point per 1,000 soʻm, with larger notes rarer.
  Use real banknote images and $1 = 10 game points. This replaces the initial
  fixed 10/100 rule. Score belongs to the run; no saved wallet is implemented.
- Persist the best completed score locally, keeping save format and storage modular
  for later expansion. Cloud sync and additional saved progression remain future work.
- Add a start screen, pause/resume when interrupted, and a brief first-drive hint.
- Add pickup sounds/light vibration and gradual traffic difficulty, as requested
  by the user. Keep the traffic increase capped and maintain generous gaps.

## Proposed First Playable Version

The following details are the working proposal from our discussion; they can change as the prototype develops.

The current starter uses a consistent elevated rear view, aligned Damas and sedan
sprites, a painted neighborhood loop, and relative dragging. Road edges remain
parallel for consistent driving geometry. Final feel and art polish remain open
to playtest feedback.

- Portrait screen with a fixed, slightly angled view from above.
- One Damas as the player's vehicle and one mahalla setting.
- The car stays near the bottom while the road and scenery scroll downward.
- Drag left or right with one finger to steer through gentle traffic.
- Reusable road sections form an endless route.
- Small steering tilts, shadows, dust, and sound provide movement and feedback.

The initial milestone is enjoyable steering through a recognizable neighborhood.
A collision ends the run, and Drive again resets the world, player, and score.
Money collection provides the score. Traffic spacing now decreases gradually
between 150 m and 900 m, then remains capped.
Avoid adding complex progression before the basic driving feels good.

## Cars and Local Scenery

Start with one consistent illustration style and camera angle. Use photos as drawing references; they are not finished game assets.

- First player car: white Damas, now centered in an elevated rear view and aligned with traffic and the road.
- Later car candidates: Matiz, Nexia, and Cobalt.
- Implemented scenery: connected courtyard walls, gates, bakery, choyxona, paving and painted trees in a repeating street. Local landmarks can be considered later.
- Represent locations through recognizable details and reusable street sections. An accurate reconstruction of a whole city is outside the proposed first version.

Track asset sources and applicable usage terms when assets are added. Keep source artwork and exported game assets organized under `assets/`.

## Open Decisions

- Exact art style and first neighborhood or city reference.
- Final steering feel; current input is relative one-finger dragging.
- Final traffic, collision, collectible, audio, and vibration tuning.
- Offline behavior, saving, and language options. Uzbek Latin and optional Russian were suggested earlier, but are not finalized.
- Monetization and release plans.

## Progress Checklist

- [x] Define the audience and low-effort gameplay goal.
- [x] Select Mahalla Cruise as the concept.
- [x] Choose a 2D direction.
- [x] Record the project direction and next steps.
- [x] Select Godot 4 with GDScript.
- [x] Configure the project and document setup commands.
- [x] Implement scrolling road and one-finger steering with placeholders.
- [x] Refactor the starter into feature modules and typed settings resources.
- [x] Document architecture and mandatory AI working rules.
- [x] Add a local formatting, lint, import, parsing, and behavior-test gate.
- [x] Add gentle traffic.
- [x] End the run on a crash and provide a clean restart.
- [x] Add the first local player car artwork: Damas.
- [x] Add all three initial mahalla scenery assets: gates, non shop, and choyxona.
- [x] Produce an Android build and test it on the Mac emulator.
- [x] Select an angled 2D visual direction and produce one complete concept for review.
- [x] Implement the angled direction at the user's request: aligned vehicles, connected environment, shadows, and compact HUD.
- [x] Add collectible soʻm/dollars, run score, collection feedback, and game-over totals.
- [x] Add real banknote images, denomination-based points, and weighted rarity.
- [x] Add distinct pickup chimes, light Android vibration, and independent feedback toggles.
- [x] Add gentle distance-based traffic progression with a maximum difficulty.
- [x] Add versioned local best-score saving, recovery, and HUD/game-over display.
- [x] Add a start screen with Damas, saved best, and Play.
- [x] Add manual and app-background pause with explicit Resume.
- [x] Add a timed first-drive hint with compatible local persistence.
- [ ] Test touch controls and performance on a physical Android phone.
- [ ] Have a few players try it without instructions and record feedback.

## Decision and Work Log

| Date | Update |
| --- | --- |
| 2026-10-06 | Created `AGENTS.md` with initial contributor guidance. |
| 2026-10-06 | Discussed Android emulator and physical-device testing from a Mac. No setup performed. |
| 2026-10-06 | Explored simple game concepts and focused on Mahalla Cruise. |
| 2026-10-06 | Chose 2D after discussing local cars, places, and asset complexity. |
| 2026-10-06 | Created this tracker; game implementation remains the next phase. |
| 2026-10-06 | Confirmed Godot 4 with GDScript as the engine and language. Setup has not started. |
| 2026-10-06 | User requested starting development and making detailed design choices during the process. Earlier design questions are deferred. |
| 2026-10-06 | Installed official Godot 4.7.2 Standard in the user Applications folder after verifying its SHA-512 checksum. |
| 2026-10-06 | Created the portrait driving sandbox, local launcher, README, and input tests. Headless project import passed, all 10 input and scrolling checks passed, and a rendered Mac preview was visually inspected. Touch events were simulated; Android device testing remains outstanding. |
| 2026-10-06 | User selected a small modular architecture, independent routine AI work with approval for broader changes, local formatting/lint/tests, and immediate implementation. |
| 2026-10-06 | Separated the main coordinator, driving input, movement, car visual, road, scenery, and HUD. Added car and road settings resources while preserving current gameplay. Updated `AGENTS.md`, added `ARCHITECTURE.md`, and documented the setup in `README.md`. |
| 2026-10-06 | Installed gdtoolkit 4.5.0 in an isolated `.venv`. `./scripts/check.sh` passed formatting, lint, shell syntax, Godot import, all script parsing, and 22 behavior checks. Verified rejection of engine errors, incomplete tests, and nonzero exits. Inspected the rendered Mac scene after the refactor; Android remains untested. |
| 2026-10-06 | User approved adding gentle traffic with a brief slowdown on contact and continued driving. Added `src/traffic/`, distance-based spawning with alternating lanes and open gaps, swept contact detection, cleanup of passed cars, and HUD feedback. Tuning lives in `default_traffic.tres`. |
| 2026-10-06 | Full quality gate passed, including 44 behavior checks across driving and traffic. Verified normal and contact visuals in rendered Mac previews. Tests cover responsive steering during contact, automatic speed recovery, spacing, bounded traffic, and cleanup. Android remains untested. |
| 2026-10-06 | User changed the collision rule to game over. Replaced slowdown with a frozen run, final-distance overlay, and Drive again button. Restart clears traffic, progress, player position, and gestures. Removed obsolete slowdown settings. |
| 2026-10-06 | Full quality gate passed with 62 behavior checks across driving, traffic, and game over. Verified frozen state, repeated runs, mouse and simulated touch restart, and prevention of duplicate touch steering. Visually inspected game-over and restarted Mac scenes. Android remains untested. |
| 2026-10-06 | Configured Java 17, Android SDK, Godot Android templates, Pixel 4 API 35 ARM64 emulator, debug signing, and Android export. Added setup/build/run scripts, `docs/ANDROID.md`, a temporary original van launcher icon, and an Android-only steering hint. Corrected the export to include dynamically spawned traffic scenes. |
| 2026-10-06 | Built and verified a 27 MiB debug APK. All 62 local behavior checks passed. On the Android emulator, verified left/right dragging, crash game over at 91 m, unchanged screenshots while frozen, touch restart with cleared traffic and reset position/distance, and unclipped portrait layout. App logs contained no script errors or fatal exceptions. Screenshots are in `build/android/screenshots/`. Physical-device performance remains untested. |
| 2026-10-06 | Investigated reported emulator lag. The launcher forced SwiftShader CPU rendering at 1080 × 2280. Changed it to host GPU plus Guest ANGLE; runtime logs confirmed Apple M4 graphics. A five-second background emulator SurfaceFlinger sample recorded 300 game frames (about 60 FPS), and the rendered game was inspected. All 62 local checks passed. Physical-phone performance remains untested. |
| 2026-10-06 | Added the first Damas player sprite using the built-in image generation tool. Stored original transparent artwork and the full prompt/source record under `assets/cars/`. Imported at a maximum edge of 512 pixels with mipmaps; the car visual owns the sprite and separate shadow. Handling and collision settings remain the same. |
| 2026-10-06 | All 62 checks passed and the updated Android APK built at 27.1 MiB. Inspected Mac driving/steering and Android driving, crash, and restart screenshots. Android app logs were clear on the successful run. The first launch immediately after emulator boot exited without a crash-buffer report; relaunch succeeded. Track cold-boot launch reliability separately. Mahalla scenery artwork is next. |
| 2026-10-06 | User requested all three scenery assets. Generated and integrated mahalla gates, a non shop with tandir, and a choyxona with tapchan. Original transparent PNGs and full prompts are in `assets/scenery/`. Native NON/CHOYXONA signs remain readable; textures import at 512 pixels with mipmaps. Three distinct blocks repeat every 720 travel pixels. |
| 2026-10-06 | Full gate passed with 66 behavior checks, including new wrap/restart scenery regressions. A rendered Mac comparison matched exactly after a complete scenery cycle. Built a 28.0 MiB Android APK, verified all three texture payloads, and inspected Android driving, crash, and touch restart. Runtime logs contained no script errors or fatal exceptions. This emulator launch succeeded without retry. Screenshots: `build/mahalla_mac*.png` and `build/android/screenshots/mahalla-*.png`. |
| 2026-10-06 | User reported that the car did not look like a Damas. Replaced the roof-heavy first draft with a compact elevated rear-view illustration using official Chevrolet front/side and rear/side photos as references. The new `damas_white_rear.png` reveals the tall cabin, upright rear hatch, stacked tail lamps, small wheels, and side stripe. Adjusted sprite scale and shadow only; retained previous artwork and documented references/prompt in `assets/cars/DAMAS_REVISION.md`. |
| 2026-10-06 | All 66 checks passed. Rebuilt the 28.1 MiB APK, installed and launched it in the existing emulator, and inspected Mac and Android renders. Android logs contained no script errors or fatal exceptions. The revised appearance awaits user feedback; physical-phone testing remains outstanding. |

Latest art-direction update (2026-10-06): the user rejected the mixed-perspective
scene and selected a unified angled 2D view. Generated and visually inspected one
complete reference; saved it with the exact prompt and official Damas reference
sources under `docs/art-direction/`. Review is pending. Only documentation and
nonimported concept material changed; no runtime changes or new build/test claims.

Implementation update (2026-10-06): replaced the diagonal player sprite and
placeholder traffic with a shared aligned vehicle atlas; replaced isolated
buildings and circular trees with a connected painted street. Added mipmaps,
soft shadows, a native NON sign, and compact distance/controls overlays.
Road bounds are now 124–308 canvas pixels to match the scene; steering lean is
limited to 0.045 radians and returns to zero at rest. Existing collision settings
and crash/restart rules are retained.

Validation: all 68 quality-gate checks passed, including two new steering-lean
checks. Inspected Mac renders at different scroll phases and verified identical
rendering after a full scenery cycle. Built and installed a 31.8 MiB APK.
On Android, inspected the running scene, steered by touch into traffic, verified
game over at 241 m and identical frozen screenshots, then tapped Drive again.
Screenshots are in `build/android/screenshots/angled-*.png`; app logs contained
no script errors or fatal exceptions. Physical-device testing remains outstanding.

Scoring update (2026-10-06): the user selected common soʻm worth 10 points and
rare dollars worth 100. Added `src/pickups/`, native banknote visuals, resource
tuning, traffic-aware spawning, swept collection, and immediate node cleanup.
Main owns the score and note counts; siblings communicate through main.
Crash has priority over collection in the same frame. Restart clears all money
and totals; there is no persistent wallet.

Validation: all 117 checks passed, including 49 pickup checks for both values,
duplicate prevention, misses, safe spawning, active limits, cleanup, crash
priority, frozen notes, and restart. Inspected Mac previews of both note types,
collection feedback, game over, and restart. Built a 31.8 MiB debug APK and
checked Android play: 17 soʻm notes plus one dollar produced 270 points at game
over (405 m). Automated tests verified frozen notes and score reset; the emulator
disconnected before a separate Android freeze/restart check could run. Runtime
logs contained no script errors or fatal exceptions. Screenshots are
`build/android/screenshots/scoring-*.png`; physical-phone testing is pending.

Feedback/difficulty update (2026-10-06): implemented the user's selected items:
pickup sounds/light vibration and gradual traffic progression. Added original
0.20/0.30-second chimes with a reproducible standard-library generator, bounded
audio playback, an 80 ms feedback burst limit, and separate runtime toggles.
Crash, restart, and focus loss stop sounds. Vibration pulses last 16/26 ms at
0.25 requested strength; Android export declares VIBRATE and the emulator
launcher now allows audio output. Traffic spawn spacing ramps from 100% at
150 m to 72% at 900 m, capped afterward; speed, alternating lanes, minimum gap,
and the three-car limit remain intact.

Validation: full gate passed all 154 checks, including 37 new feedback and
difficulty checks. Existing audio-triggering suites wait for the mixer to drain
before engine shutdown; no checks were removed. Verified generated WAV duration,
headroom, and fade-out samples. Inspected early/late Mac renders and a real mute
click, including capped traffic at 991 m. Built a 31.8 MiB APK and checked
Android collection feedback and both touch toggles. Android vibrator history
recorded both requested pulse durations at amplitude 0.25; actual vibration feel
is untested without a phone. The emulator disconnected before a post-mute
vibration-history comparison. Initial app launch needed the known relaunch.
Evidence: `build/feedback-*.png`, `build/android/screenshots/feedback-*.png`,
and `build/android/feedback-*.log`. Best-score saving is still a proposal.

Denomination update (2026-10-06): replaced fixed currency scores with the approved
1 point per 1,000 soʻm rule and $1 = 10 game points. Added five soʻm denominations
(1,000, 5,000, 10,000, 50,000, 100,000) with descending spawn weights
50/28/16/5/1, retaining the 12% dollar chance. Imported official CBU and U.S.
Currency Education Program fronts with their source markings; source links and
usage records are in `assets/money/README.md`. Typed denomination resources pair
face value, artwork, and rarity. Rendered notes preserve aspect ratio and use
mipmaps, a soft shadow, and a readable value badge. Collection feedback shows
face value plus awarded points; final currency counts still count notes.

Validation: full gate passed all 204 checks, including 50 new checks for exact
values, weighted selection boundaries, disabled weights, imported textures,
mixed actual collections totalling 176 points, labels, and immutable shared
resources. Existing collision priority, cleanup, restart, audio, and traffic
checks passed. Inspected rendered Mac variants and the longest feedback label
in `build/denominations-*.png`. Built a signed 32.2 MiB Android debug APK.
This revision has not been run on Android; physical-device checks remain pending.
Next: check denomination readability, audio/haptic feel, and traffic progression
on an Android phone; best-score saving remains a proposal.

Local persistence update (2026-10-06): implemented the requested scalable local
best-score saving. Main composes a `LocalProgressStore` child; `ProgressData`
separately owns schema v1 and validation. Saves use `user://progress.json`,
completed temporary-file replacement, and the previous valid primary as backup.
Malformed data recovers safely; unknown supported fields survive updates; newer
schemas are preserved without writes. Failed writes keep the record in memory,
show `(unsaved)`, and retry after later completed runs. Only collision submits a
run, so no disk I/O occurs during collection. Restart keeps the best and clears
the celebration. Added HUD Best and game-over New best displays.

Validation: all 260 checks passed (56 new persistence/integration checks). Existing
scene suites now explicitly use memory-only storage, while save suites create
and clean unique paths without touching the player's data. Verified a 125-point
record across two separate Godot processes on Mac and inspected record, restart,
reopened, and maximum-length/unsaved result screenshots in `build/best-*.png`.
Rebuilt the signed 32.2 MiB Android APK; this revision has not been run on Android.
Documented schema, recovery limits, and extension points in `docs/SAVES.md`.
Next: validate Android relaunch and installation over an existing build, then
check readability, controls, audio, vibration, and difficulty on a physical phone.

Session-flow update (2026-10-06): built the approved start screen, pause/resume,
and first-run guidance. Main now owns explicit START/PLAYING/PAUSED/GAME_OVER
states. A shared native `RunMenu` presents Damas, local best, and Play at startup,
or current run totals and Resume while paused. Pause disables steering and sound
and stops world/scoring/difficulty advancement. App focus loss or suspension also
pauses; return requires explicit Resume. Old mouse/touch gestures are cleared.
The six-second hint advances only during active play; optional v1 onboarding data
persists before first play and preserves older saves without resetting best scores.

Validation: all 307 checks passed, including 41 session-flow checks and six new
save-compatibility checks. Existing suites explicitly start gameplay through the
new start action; no assertions were removed. Reviewed Mac start, hint, pause,
resume, game-over, and restart screens. Built a signed 32.3 MiB Android APK.
On the API 35 emulator, verified touch Play, Home/app-return pause, identical
screenshots across two paused seconds, touch Resume, manual Pause, and onboarding
persistence with no hint on the next launch. Runtime logs had no script errors or
fatal exceptions. The initial visible emulator disconnected mid-test; the complete
retry used the same AVD without a window. Evidence: `build/session-*.png`,
`build/android/screenshots/session-*.png`, and `build/android/session-app.log`.
Physical-phone performance and in-place production-update checks remain pending.
Next: try the complete flow on a real Android phone and gather a short playtest.

Emulator lag follow-up (2026-10-06): user reported recurring Android emulator/game
lag. No game/emulator was active initially; host memory had no swap I/O. Started
the visible AVD through the existing GPU/GuestAngle launcher and measured real
SurfaceFlinger game-layer presentation. Both native 1080 × 2280 and reduced
720 × 1520 samples presented 359 frames over approximately six seconds (~60 FPS),
with no layer-reported dropped frames. Severe stutter was not reproduced; these
samples do not establish host-window or input latency.

Found saved AVD GPU settings still disabled/auto while launch flags enabled the
Apple GPU. Setup and cold-launch now persist enabled/host consistently. Added a
720 × 1520 / 293 dpi development default (56% fewer pixels), with
`--native-resolution` to clear both overrides for full-resolution validation.
The active emulator uses the lighter profile; gameplay code/assets and APK are
unchanged. Inspected both rendered resolutions and preserved all emulator/player
data. Evidence: `build/android/lag-*-frames.txt`, `lag-*-host.txt`, and matching
screenshots. Added isolated tooling tests for existing/missing GPU settings,
idempotency, data preservation, and both display profiles. The full quality gate
passed 307 game checks and four tooling tests. User confirmation of
the reported lag remains pending; next investigate steering/window latency if it
persists despite stable frame presentation.

GitHub publication (2026-10-06): user requested a public repository and all
project changes. Created the public [Yoko-ship/mahalla-cruise](https://github.com/Yoko-ship/mahalla-cruise)
repository with `main` as the default
branch and repository-local GitHub no-reply commit identity. Included source,
scenes, typed resources, original/imported assets with source records, tests,
tooling, and project documentation. Existing ignore rules exclude build outputs,
Godot caches, the Python environment, signing keys, and environment secrets;
player saves are already outside the repository. File review found no credential
patterns. Latest validation passed 307 game checks and four tooling tests.
Published all 147 project files in initial commit `75f3a11`; verified public
visibility and `main` tracking `origin/main`. Next: continue physical Android
playtesting and push subsequent work to this repository.

## Running and Checking the Starter

From the repository root, run `./scripts/godot.sh --path .` to play or `./scripts/godot.sh --editor --path .` to edit. Drag with the mouse or use the left and right arrow keys on Mac. Run `./scripts/android.sh run` to build and play on the Android emulator. See `README.md` and `docs/ANDROID.md` for setup, structure, and validation commands.

Run `./scripts/setup_tools.sh` once on a new checkout, then `./scripts/check.sh` after code, scene, resource, or tooling changes. Use `.venv/bin/gdformat src tests` to fix formatting. Tune the prototype through `src/driving/default_car.tres`, `src/road/default_road.tres`, `src/traffic/default_traffic.tres`, and `src/pickups/default_pickups.tres`.

## Keeping This Tracker Current

Read this file before continuing project work. After meaningful progress, update the date, current status, checklist, and next task, then append a short work-log entry. Record decisions when they are made and move them out of Open Decisions. Mark work complete only after it is implemented and checked; record testing results or blockers with the relevant update.
