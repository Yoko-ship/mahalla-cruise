#!/bin/sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
if [ -x .venv/Scripts/python.exe ]; then
    exec .venv/Scripts/python.exe scripts/android.py "$@"
fi
# The quality gate needs the pinned tools installed in .venv by setup_tools.sh.
if [ -x .venv/bin/python ]; then
    exec .venv/bin/python scripts/android.py "$@"
fi
exec python3 scripts/android.py "$@"
