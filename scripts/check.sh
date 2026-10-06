#!/bin/sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
if [ -x .venv/Scripts/python.exe ]; then
    exec .venv/Scripts/python.exe scripts/check.py
fi
if [ ! -x .venv/bin/python ]; then
    printf '%s\n' 'Run ./scripts/setup_tools.sh before running checks.' >&2
    exit 1
fi
exec .venv/bin/python scripts/check.py
