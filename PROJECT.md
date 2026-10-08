# Mahalla Cruise Project Tracker

Last updated: 2026-10-08

Mahalla Cruise is a planned 2D Android game for people in Uzbekistan. The goal is a simple, relaxing time killer: open the game, steer with one finger, and enjoy a familiar neighborhood without puzzles or complicated decisions. Development should stay manageable for a first version.

## Current Status

**Stage: localized Android build, full-screen phone layouts, and varied gentle traffic.**

The game now defaults to Uzbek Latin, with Russian and English selectable before
play or while paused. Menus, instructions, run values, pickups, and results are
translated. Language, sound, and vibration choices persist across relaunch without
resetting old records. Feedback controls now sit in the menus with 48-pixel touch
targets; the road HUD is clearer. Android Back pauses active play. Large result
values wrap, unsaved records use a separate status line, and HUD values fit their
badges. The existing game rules and feature ownership remain intact.

On this Windows checkout, Godot 4.7.2 is installed under `.tools/godot/` and pinned
development tools under `.venv/`. The same full quality gate works through Git Bash
or `scripts/check.ps1`. Installation verifies the official engine archive checksum.
Java, Android SDK, emulator, matching export templates, editor settings, and debug
signing also live under ignored `.tools/`. Windows builds both an ARM64 phone APK
and an x86_64 emulator APK. Full-screen scenery replaces tall-phone letterboxing;
road geometry and relative steering remain anchored to the original playfield.
Current validation results are recorded in the latest work-log entry below.

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
vibration pulses at 0.25 strength; sound and vibration have separate menu toggles.
Traffic ramps from its initial spacing at 150 m to 72% spacing at 900 m, with
the same three-car cap, minimum gap, and vehicle speed. Restart resets difficulty
and retains saved feedback preferences across app sessions.
Traffic positions vary up to 12 pixels inward within the existing alternating
lanes. Each vehicle holds that path once visible; staying in the center is no
longer permanently safe. Reaction time and passing gaps remain generous.

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

**Next task:** playtest on Windows (city routes, number plates, the car market, METAN
queues, GAI posts, plus the brake, cameras, taxi, and earlier features) and tune by
feel: route prices and bonuses, plate prices, used-car discount and repair cost, queue
wait time, police frequency, reward, and fine, and earlier values. Painted street art
for Samarkand, Bukhara, and Khiva would replace the code-drawn landmarks.
Check whether holding the brake all the time makes drives too easy (it costs nothing
today). The two-finger pedal plus steering needs a real phone to judge.
Replace the temporary car and sheep art with final artwork
([docs/art-direction/CAR_ROSTER_ART.md](docs/art-direction/CAR_ROSTER_ART.md)). Car-name
trademark review remains open before a public release. No Android device is
currently available, so phone testing is paused.

**Paused until a phone is available:** test the complete Uzbek/Russian flow on a physical Android phone,
including Back, touch targets, readability, audio/vibration feel, and difficulty.
Verify record and preference retention across an update on that phone; emulator
APK replacement and relaunch already preserve the earned record and preferences.
Gather short native-speaker playtests using [docs/PLAYTEST.md](docs/PLAYTEST.md)
before deciding further gameplay scope.
Cloud saving is not implemented.
The intermittent initial emulator launch exit remains outstanding.

## Agreed Direction

- Target Android phones; support Windows development alongside the existing Mac tooling.
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
  fixed 10/100 rule. Score belongs to the run; finished runs also pay into the
  garage wallet (see the garage decision below).
- Persist the best completed score locally, keeping save format and storage modular
  for later expansion. Cloud sync and additional saved progression remain future work.
- Add a start screen, pause/resume when interrupted, and a brief first-drive hint.
- Default to Uzbek Latin, offer Russian and English, and save language and feedback
  preferences locally. Keep instructions available in start/pause menus.
- Add a car garage (2026-10-07): Damas, Matiz, Cobalt, and black Gentra with
  different speed, control, and size. Run points go into a saved wallet used to
  buy cars; stats are fixed per car (no upgrades yet). Cars appear only once real
  artwork exists. This replaces the earlier "no saved wallet" decision. Later the
  same day the user asked for temporary art so all cars can be tested now.
  Per-car upgrades were added on 2026-10-08 (see below), so base stats are no
  longer the only difference.
- Add methane fuel with METAN stations, potholes and road works, a night drive,
  per-car upgrades, and lifetime achievements (user's choice, 2026-10-08). An empty
  tank ends the drive; hazards only cost points. The user approved the world/HUD
  overlay split by asking for these features after it was named as a prerequisite.
- Add a brake with speed cameras and taxi orders (user's choice, 2026-10-08). The
  user asked how the camera would look and how slowing down would work: an
  overhead gantry with a painted limit, a hold-to-brake pedal, and a speedometer.
  Fines cost points only; a missed taxi drop-off loses the fare.
- Add city routes, number plates, a used-car market, METAN queues, and GAI posts for the
  Uzbek market (user's choice, 2026-10-08). City landmarks are code-drawn temporary art
  until painted streets exist. Police are light-hearted and polite: stopping earns a
  reward, not stopping a fine. Plates are cosmetic plus a small taxi tip.
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
- Any future cloud save behavior; the current game and preferences work locally.
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
- [x] Add Uzbek Latin, Russian, and English UI with menu language selection.
- [x] Persist language, sound, and vibration without invalidating older records.
- [x] Improve menu touch targets, instructions, long-value layouts, and Android Back handling.
- [x] Install pinned tools inside this Windows project and port the full validation gate.
- [x] Install project-local Windows Android tools and build separate phone/emulator APKs.
- [x] Fill tall/wide portrait screens and keep spawning, menus, and resize pause coherent.
- [x] Verify Windows Android touch, Back/Home pause, localized saves, and APK replacement.
- [x] Remove the permanently safe center path with bounded within-lane traffic variation.
- [x] Add a saved wallet and a four-car garage (Damas, Matiz, Cobalt, Gentra) with per-car stats.
- [x] Add temporary test sprites so all four cars can be driven.
- [x] Add a near-miss bonus with a capped combo.
- [x] Add close-call sound/vibration, sheep crossings, and daily tasks.
- [x] Add paint colors, horn, music, and keep money away from sheep.
- [x] Add road power-ups: magnet, double points, and shield.
- [x] Add marshrutka bus-stop passengers and a daily streak bonus.
- [x] Split the drive world and HUD overlay out of main and the HUD.
- [x] Add methane fuel and METAN stations, potholes and road works, and a night drive.
- [x] Add per-car upgrades (handling, tank, suspension) and lifetime achievements.
- [x] Add a brake pedal and speedometer, speed cameras with fines, and taxi orders.
- [x] Add city routes, number plates, a used-car market and workshop, METAN queues, and GAI posts.
- [ ] Add painted street artwork for Samarkand, Bukhara, and Khiva.
- [ ] Replace the Matiz, Cobalt, and black Gentra test sprites with final artwork.
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

Uzbekistan usability and Windows update (2026-10-06): read the architecture,
tracker, feature implementations, and existing behavior suites before choosing
improvements to the current driving loop. Added Uzbek Latin (default), Russian,
and English through native translation resources. Start/pause menus expose
language, sound, vibration, and persistent instructions with larger touch targets.
Main routes choices to the existing progress and feedback modules. Added optional
v1 preferences with per-field fallback, unknown-field preservation, backup recovery,
and visible save-failure feedback. Older records and onboarding remain compatible.
Android Back now pauses play. Removed feedback buttons from the road HUD, hid
duplicate HUD values behind results, and handled long scores/unsaved records.

Installed the pinned Godot 4.7.2 Windows engine under `.tools/godot/` after checking
its official SHA-512, and gdtoolkit 4.5.0 under `.venv/`. Added Windows setup/check
entry points and shared engine discovery; all full-gate error/timeout/completion
checks remain active. Downloads and installations are ignored by Git. No engine
upgrade, game dependency, new feature boundary, or gameplay economy was added.

Validation: the original 307 game checks passed before runtime edits. The updated
full gate passes **496 game checks and 11 Python tooling tests**, including 189
new localization/preferences checks and seven new tooling tests. Real mouse and
simulated touch dispatch exercise language selection; tests cover relaunch,
malformed preferences, protected newer saves, failed writes/retries, Android Back
notifications, frozen pause, full translation catalogues, and long-value layouts.
All pre-existing assertions remain. A fresh copy without `.godot/` imports without
engine errors. PowerShell entry points passed syntax checks. Reviewed Windows
Compatibility-renderer screenshots of all three menus and results, gameplay, and
maximum/unsaved records under `build/previews/`; the Android haptics row was made
visible for layout inspection only. `build/final-check.log` records the final gate.

No new Android APK was built or run during this Windows pass. Phone performance,
physical vibration, Android app-update retention, and native-speaker playtests
remain pending. Next: validate those on a real phone and use observed player
feedback to choose the next gameplay improvement; market leadership is not an
outcome established by local automated tests.

Windows Android and viewport update (2026-10-06): installed checksum-verified Java
17, Android CLI 19.0, SDK/build tools, x86_64 API 35 emulator, and matching Godot
Android templates under ignored `.tools/`. The user authorized project-local
installation. Added host-specific tool locations and a Windows installer without
global environment changes. Windows uses its own AVD/serial and private Godot
editor settings. Added an x86_64 export preset; ARM64 remains the phone build.
Exports require the full gate and valid signing before replacing the previous APK.
Installation verifies the project emulator and uses package replacement without
clearing data. Disabled Godot's ADB shutdown only in the private Windows editor
after observing connection loss immediately after builds.

The emulator exposed black bands on tall phones. Enabled canvas expansion and
centered the original driving playfield. Road/scenery cover the visible bounds;
traffic and money spawn/despawn beyond the extended edges. Pickup traffic
prediction uses the actual spawn position. Menu/results use the full viewport,
HUD follows the road, and resize pauses safely and clears an old drag. Resources,
lane widths, collision coordinates, and steering values remain unchanged. Tall
screens reveal additional road; physical-device difficulty comparison is pending.

Validation: the full gate passes **559 game checks and 19 Python tooling tests**,
including 63 new viewport checks and eight new Android tooling tests. No existing
assertion was removed. Localization layout tests explicitly use the original
432 × 768 viewport; expanded sizes have separate regression coverage.
Reviewed tall and wide portrait Windows renders. On the dedicated Windows API 35
emulator, verified touch language/feedback selection, Play, left/right drags,
collection, collision at 61 m with a saved 5-point record, and touch restart.
Home/app return and Android Back both paused, with identical screenshots two
seconds apart. Replacing the APK retained the earned record, onboarding, language,
sound, and vibration choices. Reviewed 720 × 1520 and native 1080 × 2280 output.
Runtime logs contain no script errors or fatal exceptions. Evidence is in
`build/android/screenshots/windows-*.png` and `windows-responsive-app.log`.
Signed outputs: 32.3 MiB ARM64 phone APK and 34.9 MiB x86_64 emulator APK. Verified
their ABI separation, VIBRATE-only declared permission, and exclusion of source
tests/tooling. SHA-256 checksums are in `build/android/build-manifest.json`; the
final gate is recorded in `build/android-final-check.log`. Android commands
remained connected after the gate with the private ADB shutdown option disabled.

Phone hardware, audible/haptic feel, battery/thermal behavior, release signing,
store readiness, and native-speaker playtests remain unverified. This is an
improved testable prototype; market leadership is not established. Next: run the
ARM64 debug build on a physical phone and gather short Uzbek/Russian playtests
before expanding the gameplay loop.

Traffic play-quality update (2026-10-06): a five-minute simulation on both the
original and tall-phone viewports showed that a motionless center car could travel
3,300 m and earn 1,425/1,415 points without encountering traffic. The two fixed lane
centers left a permanently safe gap. Added typed `lane_inset_pixels` tuning (12 px)
and a bounded placement sampler. Cars still alternate the same two lanes, remain
inside their lane, and keep a straight path. Spawn rate, speed, collision boxes,
vehicle cap, and minimum spacing stay the same. New sample center runs encountered
traffic after 8.1/8.8 seconds; those are observed samples, not guaranteed timers.

Validation: the full gate passes **583 game checks and 19 tooling tests**. The 24
new checks cover both placement extremes, passing room, stationary-path coverage,
resource immutability, actual lane alternation, straight trajectories, and two-minute
steered runs through maximum difficulty at 60 and 15 simulation updates per second.
Existing alternation assertions now compare lane sides rather than unequal x
coordinates. No failing assertion was removed. The low-rate simulation establishes
control feasibility, not physical-phone FPS or subjective fairness.

Rebuilt both signed APKs. On the Windows API 35 emulator, two opposite touch drags
passed visible traffic and collected 23 points by 111 m. Android Back froze the run;
screenshots two seconds apart were identical. Inspected the 720 × 1520 gameplay
render, and runtime logs show no script errors or fatal exceptions. An initial tap
soon after cold launch did not start play; a repeated tap worked. Startup input
readiness remains a phone-playtest observation rather than a diagnosed game defect.
Evidence: `build/play-quality-baseline.json`, `play-quality-varied.json`,
`build/traffic-final-check.log`, `build/android/screenshots/traffic-*.png`, and
`build/android/traffic-app.log`. Updated APKs remain under `build/android/`.

For market context, the current developer listings for
[Uzbek Driver](https://play.google.com/store/apps/details?id=com.theabdullayev.uzbekgamings)
and [SNG Traffic Racing](https://play.google.com/store/apps/details?id=com.tisoft.uztrafficracing2)
emphasize car tuning and multiple driving modes. These listings describe competitors;
they do not prove which features our audience wants. The working product hypothesis
remains a quick offline mahalla drive with one-finger controls and local languages.
Added a ten-minute phone playtest guide with observation prompts and a results table.
No player feedback, market demand, or retention result is claimed. Next: use real
phone and native-speaker evidence to tune reaction time, collision clarity, and feel.

Growth proposal (2026-10-07): pulled commit `70ad13b` (Windows tooling, localization,
expanded viewports, traffic variation, boot splash). On Mac, `./scripts/check.sh`
passed 589 game checks and 19 tooling tests; Windows-only scripts were reviewed but
not run. No Android device is available, so phone testing is paused. At the user's
request, wrote [docs/PROPOSAL_CARS_AND_GROWTH.md](docs/PROPOSAL_CARS_AND_GROWTH.md):
a car roster with Speed/Control/Size trade-offs mapped to existing settings, plus
ranked growth ideas. This is a proposal only; no gameplay code changed. Open
decisions: saved wallet, fixed stats vs upgrades, and car trademark/naming.

Garage update (2026-10-07): the user chose Damas, Matiz, Cobalt, and a black
Gentra, a saved wallet with purchases, and to show new cars only after real
artwork exists. Added `src/garage/` with typed `CarDefinition` and
`GarageCatalogue` resources, a garage screen with Speed/Control/Size bars, and
Garage buttons on the start and results screens. `CarSettings` gained
`travel_speed_scale`; main applies the selected car's speed, steering, collision
size, and sprite. Prices: 0/300/1,000/2,500 points. No car is strictly better
than another. The optional v1 `garage` save object stores wallet, owned cars, and
selection; older saves load unchanged. A finished run updates wallet and record in
one write. Only Damas has artwork, so the others stay hidden for now.

Validation: `./scripts/check.sh` passed **787 game checks and 19 tooling tests**.
New suites: `garage_store_test.gd` (69 checks: roster, trade-offs, wallet,
purchases, relaunch, old/damaged/future saves, overflow, failed writes) and
`garage_test.gd` (85 checks: real-click purchase, applied stats and speed, no
changes mid-drive, results-to-garage reset, hidden-car fallback, and layouts in
all three languages). Localization grew from 138 to 182 checks with the new keys.
`driving_test.gd` now injects its handling variant through the garage, which owns
car settings; all its assertions remain. Reviewed Mac renders of the start screen,
garage (Damas-only and with stand-in art for all four cars), and results. No
Android build was made.

Test-art update (2026-10-07): this session has no image-generation tool, and the
user asked for default art to test handling. Added `scripts/render_placeholder_cars.gd`,
which repaints the existing painted traffic sedan red (Matiz), pearl white
(Cobalt), and black (Gentra), keeping lamps, glass, tyres, and plate. It resizes each
to its collision box at `sprite_scale` 0.1, in the same proportion as the Damas, and
writes `assets/cars/placeholder_roster.png` (mipmaps on). All four cars now appear in
the garage. They are not real model shapes, and Cobalt/Gentra share the traffic
sedan's outline. The hidden-without-artwork rule remains and is now tested with a
catalogue copy missing one car's texture. Added an art brief with a generation prompt
in `docs/art-direction/CAR_ROSTER_ART.md`.
Validation: `./scripts/check.sh` passed **792 game checks and 19 tooling tests**.
Reviewed Mac renders of the garage and each car on the road beside traffic.

Near-miss update (2026-10-07): the user asked to continue implementation, with
testing later on Windows. Built the top-ranked growth idea. Passing a traffic car
with a side gap of 10 px or less, without contact, earns 3 points. Consecutive
close calls within 1,600 px (80 m) of travel multiply it by up to ×5. Traffic
detects and scores passes; main adds points to the run (and the wallet) and counts
close calls; HUD shows "Close call ×N! +P" and, when nonzero, a results count, in
uz/ru/en. Crash frames pay nothing, pause freezes it, long frames cannot skip it,
and restart resets it. Tuning is in `default_traffic.tres`. Faster cars meet more
traffic and earn more close calls. Close calls have no sound or vibration yet.
`hud.gd` is now 293 lines; split it before adding more HUD behavior.
Validation: the first full gate failed in `pickups_test.gd`, whose exact results
line now included "Close calls × 0". Results now list close calls only when there
was at least one; the assertion is unchanged. `./scripts/check.sh` then passed **829
game checks and 19 tooling tests**, including the new `near_miss_test.gd` (25 checks:
close vs wide passes, level-only gaps, combo growth/cap/window, crash-frame priority,
wallet credit, restart, pause, and long frames). Reviewed Mac renders of the Russian
combo popup and results.

Three-feature update (2026-10-07): the user approved all three suggested next steps.
1. Split the HUD: results card → `ResultsPanel`, popup animation → `FeedbackPopup`
   (`hud.gd` 293 → 252 lines; test references moved to `hud.game_over_panel.*`).
   Close calls now play a generated 0.28 s whoosh whose pitch rises 6% per combo
   step, plus a 12 ms Android pulse; existing chimes regenerate byte-identically.
2. Sheep crossing: from 250 m, every 600–1,000 m, two or three drawn placeholder
   sheep cross the road in step with travel. Car spawns pause until the flock can
   start without catching any car; one road edge always stays open. Hitting a sheep
   ends the run with its own message. The long steered-run bot now also avoids sheep.
3. Daily tasks: three per day (seeded by date) from a pool of ten, progress applied
   at run end, rewards 30–120 into the wallet in the same single write, a Tasks
   button and screen, and results lines for finished tasks, in uz/ru/en.
Validation: `./scripts/check.sh` passed **960 game checks and 19 tooling tests**,
including new `sheep_test.gd` (22), `daily_test.gd` (56), and 5 close-call sound
checks. The passability test was confirmed to fail on a deliberately too-wide flock.
Two traffic child-count assertions now count only cars, since traffic also owns the
sheep node. Reviewed Mac renders of sheep on the road, the start menu, and the tasks
screen in Uzbek and Russian. Money can occasionally sit level with a flock.

Follow-up update (2026-10-07): the user approved items 1–5 and asked about real
street images. Items 1–4 are done; item 5 (more places) waits for artwork.
1. `main.gd` 288 → 276 lines while gaining paint, horn, and music, via static
   `GarageRules` and `PreferenceRules` helpers (explicit arguments, no lookups),
   `DailyTasks.summary()`, and a shared points helper.
2. Paint: six colors with free factory paints and 150-point shared purchases,
   saved per car; a body-only recolor shader on the road car, start screen, and
   garage previews; neutral test sprites so factory paints give their color.
3. Horn (Beep! button, cooldown, follows Sound) and a generated 19.2 s seamless music
   loop that plays only during drives, with a saved Music toggle.
4. Money vs sheep: a flock waits until no note is near the top, and money treats each
   sheep as a full road row. A first fix still failed the new test; tracing showed a
   note spawning beside a flock still on the sidewalk, which the row rule fixed.
   Verified the test fails without the fix; a 60,000 m trace had no overlaps.
Real street photos: usable only with rights (own or freely licensed photos, never
Street View/Yandex/satellite captures), and eye-level photos cannot form the
top-down looping road; good uses are menu backdrops or references for painted
streets. Four suites now wait 0.4 s before quitting so the music stream is released.
Validation: `./scripts/check.sh` passed **1,043 game checks and 19 tooling tests**,
including new `paint_test.gd` (41) and `audio_test.gd` (24). Reviewed Mac renders of
six paints on the road, the Russian garage with swatches, and the horn button.

Power-up update (2026-10-07): the user chose power-ups. Magnet (90 m, 130 px pull),
×2 points (110 m, money and close calls), and Shield (one crash plus 15 m grace,
works on cars and sheep) spawn from 120 m, one every 300–500 m, in money lanes away
from traffic, sheep rows, and notes. Durations are metres, so pause freezes them.
Drawn badges and HUD chips with countdown rings; uz/ru/en popups; collection uses the
dollar chime. Buying power-ups before a run is not implemented yet. To stay within
lint limits, the HUD's per-frame hint timer merged into `set_distance(metres, delta)`
and the wallet line into `show_game_over(...)`. `main.gd` is 286 lines and `hud.gd`
280: the next feature should start with an approved structural split.
Validation: `./scripts/check.sh` passed **1,090 game checks and 19 tooling tests**,
including new `power_up_test.gd` (31). One pickups cleanup assertion now counts note
and power-up children separately, since both live under the controller. Reviewed a
Mac render of all three badges, the chips, and the Uzbek popup.

Two new features (2026-10-07): the user asked for two features not listed before.
1. Marshrutka passengers: drawn bus stops (BEKAT) with 1–3 passengers on the right
   sidewalk from 200 m, every 450–750 m. Hugging the right curb boards everyone; each
   pays a 5,000 soʻm fare through the existing money signal (×2 applies; daily note
   tasks count fares). Every car can reach the boarding zone; centre driving cannot.
2. Daily streak: consecutive days pay 20 × streak day (cap 140) on the first finished
   drive, shown as a Tasks row and on results; a missed day resets to day one.
Neither touched `main.gd` or `hud.gd`. Existing wallet assertions in garage, near-miss,
and power-up tests now mark today's streak as paid so they keep testing run points;
one daily rollover assertion now expects the extra streak reward. Fares are skipped,
not asserted, when a test catalogue lacks the 5,000 note.
Validation: `./scripts/check.sh` passed **1,135 game checks and 19 tooling tests**,
including new `passenger_test.gd` (21) and `streak_test.gd` (20). Reviewed a Mac render
of a stop with three passengers beside the curb.

Five features and a structural split (2026-10-08): the user chose methane fuel,
potholes/road works, night drive, car upgrades, and achievements.
- Split: `DriveWorld` (`src/world/`) now owns road, scenery, hazards, fuel, traffic,
  pickups, player, and night; main keeps run state, score, progress, and routing.
  The HUD's road-time controls moved to `DriveOverlay`. `ProgressFile` took file I/O
  from the store. `main.gd` is 293 lines (from 286 before adding five features).
- Fuel: 1,500 m tank; METAN stations on the left curb from 550 m, every 500–700 m;
  hug the curb bay to refill; an empty tank ends the drive ("Out of methane!").
- Hazards: potholes (−10) and road works (−20) near the centre line from 250 m,
  every 120–260 m; score never below zero; bump sound and vibration.
- Night: dusk from 1,200 m over 250 m; headlights and lamps via a shader; money and
  close calls +50% once dark.
- Upgrades: handling (+10%/level), tank (+25%/level), suspension (−25% penalty/level),
  three levels each, per car, in the garage.
- Achievements: 16 lifetime goals across seven kinds; Tasks screen switch; results.
Existing suites changed only where the new rules apply: test paths now go through
`game.world` and `game.hud.drive`; three long-drive suites (driving, power-up, passenger)
give their never-steering car an unlimited tank, since an empty tank now ends a run.
Validation: `./scripts/check.sh` passed **1,449 game checks and 19 tooling tests**,
including new `fuel_test.gd` (45), `hazard_test.gd` (28), `night_test.gd` (15),
`upgrade_test.gd` (62), and `achievement_test.gd` (76). Reviewed Mac renders of a
station, pothole, and road works by day; the night shade with headlights and lamps;
the garage with upgrades (uz/ru/en); the achievements screen; and the fuel results.
Android and Windows were not run in this session.

Brake, speed cameras, and taxi orders (2026-10-08): the user chose speed cameras
(asking how the camera looks and how slowing down works) and taxi orders.
- Brake: hold the bottom-left pedal (or Down) to ease to 50% speed in ~0.6 s; release
  recovers in ~1 s. Braking scales the whole frame's travel, so spawning and path
  checks stay valid. The pedal owns its own finger, so another finger can steer.
  A speedometer (Damas 60 km/h, braked 30) shows above the pedal.
- Speed cameras (`src/cameras/`): an overhead gantry with two cameras, a blinking
  light, and a blue camera sign; the limit (40/50) is painted on the asphalt ahead
  and shown beside the speedometer. From 400 m, every 450–800 m. Too fast under the
  gantry: white flash, shutter sound, −(15 + 1 per km/h over) points.
- Taxi orders (`src/taxi/`): a waving passenger with a TAKSI bubble on the right
  curb from 350 m; pull in to board, a 250–450 m ride counts down in a HUD chip, and
  a green drop-off bay with a pin arrives exactly at the end. Fare: one 10,000 soʻm
  note per started 100 m. Bus stops wait during an order.
- Also: `hud.set_fuel` became `set_dashboard` (fuel, speed, limit, ride); the English
  fuel gauge label no longer cuts "Methane" to "Metha"; the first-drive hint mentions
  the brake. `main.gd` stays at 294 lines (world computes travel now).
Existing suites changed only where the new rules apply: night and passenger tests turn
off cameras/taxi orders that would add popups or hold bus stops.
Validation: `./scripts/check.sh` passed **1,761 game checks** plus the Python tooling
tests, including new `brake_test.gd` (31), `speed_camera_test.gd` (191), and
`taxi_test.gd` (43). A deliberate break of the pedal's input handling made the pedal
checks fail, confirming they test finger isolation. Reviewed Mac renders (uz/ru/en)
of the camera approach, braking, the fine flash, a taxi hail, the ride chip with the
drop-off bay, and a camera at night. Android and Windows were not run.

Uzbek-market features (2026-10-08): the user chose number plates, METAN queues, a
used-car market, city routes, and GAI posts.
- Structure first: every shop action now goes through one `garage_action(action, id)`
  and `GarageRules.apply()`; purchases use `LocalProgressStore.spend()`;
  `RunRecords.finish()` books a finished drive; road penalties and rewards arrive as
  `road_points`. `main.gd` went from 294 to 279 lines.
- Routes: Tashkent, Samarkand (1,500, +15%), Bukhara (3,000, +30%), Khiva (5,000,
  +50%), chosen with arrows on the start card; tint and code-drawn landmarks.
- Plates: `01 A 777 AA` format, four rarity tiers, three auction plates a day in the
  city's region, a plate on the car and the start card, taxi tip = tier.
- Market: three used cars a day at 70% × condition (50–85%); condition lowers steering
  and tank; workshop repairs 10% at a time. Opened from the garage.
- METAN queues: 1–3 waiting cars; 0.45 s in the bay per car (brake to wait), else a
  partial fill.
- GAI posts: YHXB booth and officer on the left curb from 600 m; a waving officer
  wants a stop at ≤40 km/h (+20) or fines 30 with a whistle. Never beside a station.
Existing suites changed only where needed: calls to `choose_car/paint/upgrade` became
`garage_action`, and the fuel suite turns off queues and police posts so its station
timing and full refuels stay deterministic.
Validation: `./scripts/check.sh` passed **3,000 game checks** plus the Python tooling
tests, including new `plate_test.gd` (585), `market_test.gd` (414), `route_test.gd`
(77), `police_test.gd` (37), and `fuel_queue_test.gd` (14). Reviewed Mac renders of the
start card with route picker and plate (uz/ru/en, owned and locked), the garage with a
65% used car, the market (uz/ru/en), a METAN queue, a waving GAI officer, and the
Samarkand, Bukhara, and Khiva landmarks. Android and Windows were not run.

## Running and Checking the Starter

From the repository root, run `./scripts/godot.sh --path .` to play or `./scripts/godot.sh --editor --path .` to edit. Drag with the mouse or use the left and right arrow keys on Mac. Run `./scripts/android.sh run` to build and play on the Android emulator. See `README.md` and `docs/ANDROID.md` for setup, structure, and validation commands.

Run `./scripts/setup_tools.sh` once on a new checkout, then `./scripts/check.sh` after code, scene, resource, or tooling changes. Use `.venv/bin/gdformat src tests` to fix formatting. Tune the prototype through `src/driving/default_car.tres`, `src/road/default_road.tres`, `src/traffic/default_traffic.tres`, and `src/pickups/default_pickups.tres`.

## Keeping This Tracker Current

Read this file before continuing project work. After meaningful progress, update the date, current status, checklist, and next task, then append a short work-log entry. Record decisions when they are made and move them out of Open Decisions. Mark work complete only after it is implemented and checked; record testing results or blockers with the relevant update.
