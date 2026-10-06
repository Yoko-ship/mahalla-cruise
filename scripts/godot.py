#!/usr/bin/env python3
"""Launch the pinned engine on Windows, macOS, or Linux without shell quoting."""

import os
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
VERSION = "4.7.2"


def find_engine():
    if os.environ.get("GODOT_BIN"):
        return os.environ["GODOT_BIN"]
    local = ROOT / ".tools" / "godot" / f"Godot_v{VERSION}-stable_win64.exe"
    candidates = [
        local,
        shutil.which("godot"),
        shutil.which("godot4"),
        Path.home() / "Applications/Godot.app/Contents/MacOS/Godot",
        Path("/Applications/Godot.app/Contents/MacOS/Godot"),
    ]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return str(candidate)
    raise FileNotFoundError(f"Install Godot {VERSION} or set GODOT_BIN to its executable.")


if __name__ == "__main__":
    try:
        sys.exit(subprocess.call([find_engine(), *sys.argv[1:]]))
    except OSError as error:
        print(error, file=sys.stderr)
        sys.exit(1)
