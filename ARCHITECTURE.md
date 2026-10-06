# Mahalla Cruise Architecture

Mahalla Cruise uses small Godot feature scenes with typed GDScript. The main
scene connects the features and owns shared progress. This structure supports
adding cars and scenery while keeping the first Android game manageable.

## Engine and Entry Point

Use **Godot 4.7.2 Standard**, GDScript, and the Compatibility renderer.
`project.godot` starts `src/main.tscn`. The current portrait canvas is 432 × 768;
Godot scales it to the window. Artwork and HUD layout are authored for that canvas.

## Feature Ownership

| Location | Responsibility |
| --- | --- |
| `src/main.gd` and `main.tscn` | Compose features, own run state, advance shared travel, and coordinate restart. |
| `src/driving/player_car.gd` | Own the player's position, steering target, road limits, and lean. |
| `src/driving/steering_input.gd` | Translate mouse, single-finger touch, and keyboard input. Cancel gestures on focus loss. |
| `src/driving/car_visual.gd` | Own the Damas sprite child and draw its shadow; leave steering and collision logic on the player. |
| `src/driving/car_settings.gd` and `default_car.tres` | Define and store car handling values. |
| `src/road/` | Store route settings and render scrolling lane markings above the street. |
| `src/scenery/` | Render the connected street surface, buildings, trees, and native bakery sign. |
| `src/traffic/` | Spawn and remove traffic, track contacts, and render sedan sprites using traffic settings. |
| `src/pickups/` | Spawn money, detect collection, render banknotes, and own a separate feedback scene for audio/haptics. |
| `src/progress/` | Own the versioned save document, local files, recovery, and best-score persistence. |
| `src/ui/` | Present start/pause menus, first-run instructions, HUD values, and run results. |
| `tests/` and `scripts/` | Verify behavior and run development tools. |

Keep each feature's scenes, scripts, and default resources together. Imported
artwork and audio go under `assets/`, with source records. The Damas and sedan
share `assets/cars/vehicles_aligned.png`, using a centered elevated rear camera
with no diagonal heading. Player uses an AtlasTexture; traffic selects its region
when drawing. Both visuals draw soft ground shadows separately. Keep full source
dimensions for atlas coordinates, mipmaps, and linear filtering.

Scenery owns the connected `assets/scenery/mahalla_street.png` environment.
Its first 1540 source rows repeat every 720 game pixels, ending at the repeated
courtyard wall. Left sidewalk, asphalt, and right sidewalk are separate draw
regions mapped to RoadSettings edges, so art follows steering/collision bounds.
Scenery receives travel/reset commands from main and owns only its scroll offset.
Road draws lane markings above scenery at z=1; cars render at z=2; HUD uses a
CanvasLayer. Assets, original prompts and source records are in `assets/ANGLED_ART.md`.

## Connections and State

```mermaid
flowchart TD
    Main[Main scene and travel state] --> Player[Player car]
    Main --> Road[Road view]
    Main --> Scenery[Scenery view]
    Main --> Traffic[Traffic controller]
    Traffic -->|contacted signal| Main
    Main --> Pickups[Pickup controller]
    Pickups -->|collected points and denomination| Main
    Main --> Feedback[Pickup sounds and haptics]
    Main --> Progress[Local progress storage]
    Main --> HUD[HUD]
    HUD -->|play, pause, resume, restart signals| Main
    Input[Steering input] -->|steering_delta signal| Player
    Player --> Visual[Car visual child]
    CarData[Car settings resource] --> Player
    RouteData[Road settings resource] --> Main
    TrafficData[Traffic settings resource] --> Main
    PickupData[Pickup settings resource] --> Main
```

Parents call typed methods on their children. Children signal events upward.
The main scene routes communication between features. A feature must not reach
into a sibling, walk to a parent for hidden dependencies, or use `/root` lookups.
Do not add a global event bus, service locator, or autoload without approval.

`CruiseGame` owns travelled distance, run score, and currency counts. It distributes
the same pixel movement to road, scenery, and pickups each frame. `PlayerCar` owns its movement and uses the physics
clock. Renderers keep only their scrolling offsets; the HUD receives distance
through `set_distance()`. Views do not modify gameplay state.

The main scene owns `RunState` (START, PLAYING, PAUSED, GAME_OVER).
`is_game_over` is a derived compatibility getter. Startup shows the start menu,
loads the best score, and disables steering. Only PLAYING advances the world.
It passes travel and the player's collision
rectangle to `TrafficController`. Traffic never reads the player or HUD directly.
The first contact signals upward and ends the run: the main scene stops advancing
the world, disables player driving, and shows the final distance and restart UI.
The scene tree stays active so buttons continue to receive input.

The HUD emits `restart_requested`; the main scene resets distance, score and counts,
road/scenery offsets, traffic, pickups, the player transform, and HUD state. The traffic controller
detaches old vehicles before freeing them. Disabling or re-enabling driving clears
active gestures, so a drag from the old run cannot carry over. Touch-to-mouse
emulation supports native UI buttons; steering ignores emulated events to avoid
counting a finger drag twice.

Money is composed through `src/pickups/pickups.tscn`. The main scene obtains
traffic rectangle snapshots through `blocking_bounds()` and passes them to the
pickup controller with the player's bounds and traffic speed ratio. Pickups never
read sibling nodes. Spawn candidates avoid traffic along the predicted route to
the player. Money travels with the road, uses swept collection detection, and is
detached before its value is signalled upward, preventing duplicate awards.

Traffic updates first. A crash skips pickup updates for that frame, so no points
can be awarded during or after the crash. Decorative bobbing advances only with
travel and freezes with the run. The HUD clears its transient pickup feedback on
game over and restart. Run scores reset; the best completed score persists locally.
No wallet is implemented.

`PickupFeedback` is a separate main-scene child under the pickups feature. Main
calls it after a successful collection and stops it on crash/restart. It owns two
bounded AudioStreamPlayers and brief Android vibration pulses. Focus loss also
stops audio. HUD toggle signals route through main; runtime sound/vibration
preferences survive a run restart but reset to resource defaults on app launch.
No sibling lookups, global audio service, or new dependency is used.

## Session and Menu Flow

`RunMenu` is a shared UI child used for start and pause, with a single primary
button. It emits upward to HUD, which emits play/resume requests to main.
The start screen shows the Damas atlas artwork, local best, and Play. The actual
road car becomes visible when the run starts. Pause shows the current score and
distance with Resume. Native buttons support keyboard and emulated touch input.

Main responds to focus loss and application suspension by entering PAUSED,
disabling player input, and stopping pickup feedback. Returning only restores
focus eligibility; the player must explicitly resume. Pause preserves distance,
score, world positions, difficulty, and note animation. Player input is cleared
on every disable/enable, preventing old gestures from continuing. The tree stays
active for menu input; this feature does not use `SceneTree.paused`.

HUD owns presentation and the first-run hint timer, using `default_hud.tres`
(six seconds). Main advances that timer only during PLAYING. HUD clears transient
pickup feedback on pause, preserves remaining hint time for Resume, and clears
the hint on restart. The onboarding flag is saved once before first play; no
file writes occur during normal frame or collection updates. A killed process
returns to START and does not restore an unfinished run.

## Persistent Progress

Main composes a `LocalProgressStore` child from `src/progress/progress.tscn`.
It calls `load_progress()` at startup, records first-play onboarding when needed,
and calls `record_score(score)` once on collision,
then sends best-score and save-status values to the HUD. Run restart never resets
persistent progress. Collection and frame updates perform no file I/O.

`ProgressData` owns the versioned JSON schema and validation; the store owns
file access, temporary replacement, and backup recovery. The default path is
`user://progress.json`, outside the repository. Tests inject a unique temporary
path or an empty path for memory-only behavior before scene initialization.
No autoload or sibling lookup is used.

A higher completed score updates the record; ties and lower scores leave it intact.
The optional v1 `onboarding.driving_hint_seen` field defaults to false when absent,
so pre-onboarding saves keep their existing best without a version migration.
Write failures retain the record in memory, mark the result unsaved, and retry on
the next completed run. Unknown fields in supported saves survive round trips.
Newer schema versions are preserved without writes. See [docs/SAVES.md](docs/SAVES.md)
for format, recovery limits, and how to extend storage or introduce migrations.

## Data and Tuning

`CarSettings` contains speed, drag sensitivity, road margin, and lean tuning.
`RoadSettings` contains road edges, scrolling speed, and distance conversion.
The main scene supplies road bounds to the player, so road geometry has one owner.
`TrafficSettings` contains spawning distances, spacing, vehicle limits, relative
movement, and collision size. Player collision size belongs to
`CarSettings`. Collision rectangles use main-scene coordinates and intentionally
ignore decorative car lean.

Spawning follows distance travelled, alternates lanes, and requires an open
vertical gap. It adds at most one car per update, including after a long frame.
Traffic uses a swept vertical rectangle to catch contact between frames and
frees passed vehicles during play. On collision it places the struck car at the
contact point, marks it, and stops the update before any additional spawning.
Spawning and movement values remain provisional in `default_traffic.tres`.

Main passes run distance to traffic before each update. Spawn intervals gradually
shorten from 150 m to 900 m, reaching 72% of their baseline at the cap.
Traffic still alternates lanes, keeps its 180-pixel minimum gap and three-car
limit, and uses the same relative speed. Stable traffic speed preserves pickup
path predictions. Only future spawn intervals use the new scale; cars already
on screen do not jump or accelerate. Configure/restart resets the curve to zero.

`PickupSettings` and `src/pickups/default_pickups.tres` define a typed banknote
catalogue, scoring conversion, dollar chance (12%), spawn distance, active limit,
collection bounds, and traffic clearance. `BanknoteDefinition` pairs the currency,
face value, image, and relative spawn weight. Soʻm face values 1,000/5,000/10,000/
50,000/100,000 earn 1/5/10/50/100 points, with weights 50/28/16/5/1 within soʻm
spawns. $1 earns 10 game points, independent of exchange rates.

`MoneyVisual` scales official banknote textures without distortion and draws a
readable denomination badge; sources are in `assets/money/README.md`.
`MoneyPickup` owns the selected definition, points, position, and bounds. The
controller owns lifetime and signals points plus denomination upward. Main
supplies formatted face values to HUD feedback; game-over totals still count
notes by currency, not their monetary sum. Selection never mutates resources.

`PickupFeedbackSettings` in `default_feedback.tres` controls sound gain, the
80 ms burst limit, sound/haptic defaults, and short vibration durations. Sound
sources and regeneration instructions are in `assets/audio/README.md`.

Edit `.tres` values in Godot's Inspector to tune behavior. Resource scripts define
types and defaults. Treat loaded resources as immutable during a run: keep mutable
state on nodes, and duplicate a resource before making an in-memory variant.
Decorative colors and geometric drawing coordinates may remain in view scripts.

## Adding Features

1. Read `AGENTS.md` and the current task in `PROJECT.md`.
2. Add the smallest scene or script under the owning feature. Introduce a new
   feature directory only when the requested behavior needs one.
3. Connect it through the main scene or its owning feature; use typed methods
   and signals rather than hidden cross-feature access.
4. Add tests for the behavior or regression, run `./scripts/check.sh`, and inspect
   a rendered preview for visible changes.
5. Update the tracker with results and the next task. Update this document when
   an approved change alters ownership or connections.

Gentle traffic progression, collectible money, pickup feedback, run scoring, crash game over, and restart are implemented. Local best-score saving is implemented. Monetization
and online services are not implemented. Discuss their behavior when the user
requests that work. Do not prebuild a general framework for hypothetical modes.

## Android Packaging

`export_presets.cfg` builds an ARM64 debug APK using the prebuilt Godot template.
Export all game resources, including scenes loaded by scripts; exclude `tests/`,
`scripts/`, and development documents. `scripts/android.sh run` runs the quality
gate, builds the APK, and installs it on the project emulator. Machine-specific
SDK paths and signing keys stay outside the repository. See `docs/ANDROID.md`.

Android export enables the VIBRATE permission. The emulator launcher allows audio
output; physical vibration strength still needs a real phone check.

## Verification Boundaries

The local gate enforces GDScript formatting, lint rules, script parsing, project
import, and all discovered behavior suites. Tests exercise actual Godot input
dispatch and scene connections. Tests must return a nonzero exit code on failure
and print `PASS:` only on successful completion.

Architecture boundaries and task scope also require review against these rules;
the linter cannot establish them. Mac rendering and simulated touch checks do not
establish Android performance or physical-device compatibility.

The debug APK has been checked on the Pixel 4 API 35 ARM64 emulator for portrait
layout, touch dragging, collision game over, frozen state, and touch restart.
Emulated input and emulator rendering do not establish physical-phone performance.
