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
  }
}
```

`onboarding` is an optional extension to version 1. Existing v1 files without it
load with the hint unseen and retain their best score. The flag must be boolean.

`preferences` is also optional in v1. Language accepts `uz`, `ru`, or `en`;
feedback flags must be booleans. Invalid or absent preference values fall back
individually to defaults without losing a valid best score or onboarding flag.
Unknown fields in a valid preferences object are retained when choices change.

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
