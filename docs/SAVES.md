# Local Progress Saves

## Player Behavior

The highest **completed run** is saved when traffic ends the run. A tie or lower
score leaves it unchanged. Restart clears run points and note counts while keeping
the best. Closing the app before a crash does not save the unfinished run.
The HUD shows `Best`; game over shows `New best!` for an improvement.
First play also saves whether the driving hint has been shown. The hint lasts
six seconds of active play and is not repeated after restart or app relaunch.
Language, sound, and vibration choices are saved from the start/pause menus.
New installs use Uzbek Latin with sound and vibration enabled. Russian and English
are available immediately; saved choices take effect before starting a drive.

Saves are local to the installation. No account, cloud sync, or automatic-backup
integration has been added by this feature. Android update/restore behavior still
needs device validation. These local scores are not trusted leaderboard results.

## Format and Location

`user://progress.json` is writable player storage outside the repository and
exported game assets. Git commits and pulls do not transfer or replace it.
On this Mac the default directory is
`~/Library/Application Support/Godot/app_userdata/Mahalla Cruise/`.

```json
{
  "version": 1,
  "stats": {
    "best_score": 125
  },
  "onboarding": {
    "driving_hint_seen": true
  },
  "preferences": {
    "language": "uz",
    "sound_enabled": true,
    "haptics_enabled": true
  },
  "garage": {
    "wallet": 340,
    "owned": ["damas", "matiz"],
    "selected": "matiz",
    "owned_paints": ["sky"],
    "paints": {"matiz": "sky"},
    "upgrades": {"damas": {"handling": 2, "tank": 1}},
    "plates": ["01A482DM", "30B121KM"],
    "plate": "30B121KM",
    "conditions": {"matiz": 65},
    "routes": ["tashkent", "samarkand"],
    "route": "samarkand"
  },
  "daily": {
    "day": "2026-10-07",
    "tasks": ["notes_15", "distance_400", "runs_3"],
    "progress": {"notes_15": 15, "distance_400": 260, "runs_3": 2},
    "done": ["notes_15"]
  },
  "achievements": {
    "stats": {"metres": 5240, "notes": 131, "runs": 12, "best_metres": 1320},
    "done": ["distance_5km", "notes_100", "runs_10", "run_1000"]
  }
}
```

`onboarding` is an optional extension to version 1. Existing v1 files without it
load with the hint unseen and retain their best score. The flag must be boolean.

`preferences` is also optional in v1. Language accepts `uz`, `ru`, or `en`;
feedback flags must be booleans. Invalid or absent preference values fall back
individually to defaults without losing a valid best score or onboarding flag.
Unknown fields in a valid preferences object are retained when choices change.

`garage` is optional in v1. Every completed run adds its points to `wallet`
(capped at the score maximum); buying a car spends them and selects that car.
`owned` always includes `damas`; unknown car ids are kept for future builds.
`selected` must be owned, otherwise Damas is used. Invalid fields fall back
individually without losing the record, and unknown garage fields survive writes.
A selected car that this build cannot show (no artwork) drives as Damas without
rewriting the saved choice.

Garage `owned_paints` and per-car `paints` are optional; invalid entries fall back
to each car's free factory paint. `preferences.music_enabled` (default true) is
saved separately from `sound_enabled`.

Garage `plates`, `plate`, `conditions`, `routes`, and `route` are optional. Plates are
eight-character codes (two digits, a letter, three digits other than `000`, two
letters); invalid entries are dropped and `01A482DM` is always owned. `plate` and
`route` must be owned, otherwise the default is used. `conditions` holds whole percents
1–99 for used cars; anything else counts as 100. `routes` always includes `tashkent`;
unknown route ids are kept for future builds.

Garage `upgrades` is optional: levels per car id and upgrade id, whole numbers from
1 to 10. Invalid cars or levels are dropped individually; the wallet and record stay.

`achievements` is optional in v1. `stats` holds lifetime totals (`metres`, `notes`,
`close_calls`, `runs`, `refuels`) and single-drive bests (`best_metres`,
`best_score`); `done` lists unlocked ids. Negative or non-numeric stats and unknown
ids are dropped; unknown fields survive writes. A finished run stages achievements
with the daily state, so the run is still one write.

`daily` is optional in v1. A state for another day, unknown task ids, a wrong task
count, or negative progress is replaced by today's fresh draw without touching the
record or wallet. Unknown fields inside `daily` survive writes. Every completed run
now writes once (daily progress counts drives), still never during play.

Scores must be whole numbers from 0 to 2,147,483,647. Unknown fields in a supported
document are retained. Missing or malformed data falls back to a valid `.bak`
file, or zero if neither file is usable. Loading does not overwrite either file. The first Play action may write the
onboarding flag even if no run has yet finished.

## Writes and Recovery

The store writes and flushes `.tmp`, preserves a valid primary through `.bak.tmp`
and `.bak`, then renames the completed temporary file over the primary. A damaged
primary cannot replace a valid backup. Uncommitted temporary files are ignored on
load. Recovery may restore the previous record rather than the latest one; this
is not a guarantee against every storage or power failure.

On write failure the best remains in memory, results say `(unsaved)`, and the next
completed run retries the pending save. Unreadable files and newer schema versions
block writes for that session, preserving data the current build cannot handle.
Menu preferences show a localized save warning on failure and remain usable for
the session. Choosing an option again or finishing a run retries unsaved data.
An unchanged choice with no pending failure does not rewrite the document.

## Extending the Feature

- `ProgressData` owns schema defaults and validation. Add explicit migration
  steps and fixtures when changing the version; never reset an unknown version.
- `LocalProgressStore` owns file I/O and recovery. Keep file paths out of gameplay
  and UI. Future cloud coordination can use this storage boundary; it will still
  need account identity, offline behavior, and conflict handling.
- `CruiseGame` coordinates loading and completed-run submission. The HUD only
  receives display values and never opens files.
- Tests set the store path before the scene enters the tree. Empty paths are
  memory-only; persistence tests create and clean unique `user://` files.

Run `./scripts/check.sh` after changes. Save tests cover round trips, invalid
documents, recovery, write retries, forward-version protection, and real gameplay
connections. Release verification should also update an installed Android build
without clearing its data and confirm the existing record is retained.
