#!/bin/sh
set -eu
project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_root"
python3 -m venv .venv
.venv/bin/python -m pip install --disable-pip-version-check -r requirements-dev.txt
