# Repository Guidelines

## Required Workflow

Before editing, read `ARCHITECTURE.md`, `PROJECT.md`, and the affected code. Follow
explicit user instructions and keep work within the assigned task. State the
intended change briefly, implement it, verify it, and update `PROJECT.md` with
results and the next task. Keep completed work distinct from proposals.

## Autonomy and Approval

Handle routine implementation, fixes, tests, and refactors within the agreed
architecture independently. Ask before changing architecture boundaries, adding
or upgrading dependencies or the engine, or expanding gameplay scope, unless
that action is already explicitly authorized. Decide detailed gameplay questions
when the work reaches them. Do not alter these rules or weaken checks just to
complete a task; rule changes require user direction.

## Project Structure and Boundaries

Use Godot 4.7.2 Standard, GDScript, and the Compatibility renderer. `src/main.tscn`
and `src/main.gd` compose feature scenes under `src/driving/`, `src/road/`,
`src/scenery/`, `src/traffic/`, and `src/ui/`. Keep scripts, scenes, and resources with their
feature. Put behavior tests in `tests/` and imported art/audio in `assets/`.

Parents call children; children signal upward. Route sibling communication
through their parent. No sibling internals, parent walking, `/root` lookups, or
unapproved autoloads. Keep input, movement, drawing, and UI responsibilities
separate. Store tunable gameplay values in typed resources; keep runtime state
on nodes and do not mutate shared settings resources.

## Style and Commands

Use typed GDScript, including parameters and return types; `:=` is allowed when
inference is unambiguous. Use tabs, `snake_case` files/functions, `PascalCase`
classes/nodes, and `UPPER_SNAKE_CASE` constants. The formatter and linter enforce
100-character lines and a 300-line script limit. Split responsibilities instead
of suppressing checks.

- `./scripts/setup_tools.sh`: install pinned development tooling in `.venv`.
- `./scripts/godot.sh --editor --path .`: open the editor; F5 runs the project.
- `./scripts/godot.sh --path .`: play locally.
- `.venv/bin/gdformat src tests`: format GDScript.
- `./scripts/check.sh`: check formatting, lint, import, parsing, and behavior tests.

## Completion and Review

For code, scene, resource, or tooling changes, the full check command must pass.
Add focused `*_test.gd` regression tests for changed behavior. Never remove a
failing assertion solely to get a pass. Inspect rendered output after visual or
scene changes. Report failures and untested platforms honestly; do not claim
Android validation from Mac tests.

Review the diff when Git is available. Preserve unrelated user work and keep
`.godot/`, `.venv/`, builds, and secrets out of version control; retain `.gd.uid`
files. Use imperative commit subjects, such as `Separate steering input`.
PRs should explain behavior, validation, relevant issues, and visible changes.
