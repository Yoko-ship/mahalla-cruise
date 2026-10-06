#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
if [ -x "$project_root/.venv/Scripts/python.exe" ]; then
    exec "$project_root/.venv/Scripts/python.exe" "$project_root/scripts/godot.py" "$@"
fi

if [ -n "${GODOT_BIN:-}" ]; then
    exec "$GODOT_BIN" "$@"
fi
for godot_name in godot godot4; do
    if command -v "$godot_name" >/dev/null 2>&1; then
        exec "$godot_name" "$@"
    fi
done
for godot_app in "$HOME/Applications/Godot.app" /Applications/Godot.app; do
    if [ -x "$godot_app/Contents/MacOS/Godot" ]; then
        exec "$godot_app/Contents/MacOS/Godot" "$@"
    fi
done
printf '%s\n' 'Godot not found. Install Godot 4.7.2, or set GODOT_BIN to its executable.' >&2
exit 1
