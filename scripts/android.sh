#!/bin/sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
if [ -x .venv/Scripts/python.exe ]; then
    exec .venv/Scripts/python.exe scripts/android.py "$@"
fi
exec python3 scripts/android.py "$@"
