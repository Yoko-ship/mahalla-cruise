#!/usr/bin/env python3
"""Read-only quality gate; a failed or incomplete step must return nonzero."""

import importlib.metadata
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
BIN = ROOT / ".venv" / "bin"
GODOT = str(ROOT / "scripts" / "godot.sh")
ENGINE_VERSION = "4.7.2"
TOOLKIT_VERSION = "4.5.0"
ENGINE_ERROR = re.compile(r"(?:SCRIPT ERROR:|ERROR:|Parse Error:)")
ANSI_ESCAPE = re.compile(r"\x1b\[[0-9;]*m")


def run(label, command, *, godot=False, test=False):
    print(f"[check] {label}", flush=True)
    result = subprocess.run(
        command,
        cwd=ROOT,
        env={**os.environ, "NO_COLOR": "1"},
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=60,
    )
    output = ANSI_ESCAPE.sub("", result.stdout)
    failed = result.returncode != 0 or (godot and ENGINE_ERROR.search(output))
    if test and not re.search(r"^PASS:", output, re.MULTILINE):
        failed = True
    if failed:
        print(output, file=sys.stderr)
        raise RuntimeError(f"{label} failed (exit {result.returncode})")
    if test:
        for line in output.splitlines():
            if line.startswith("PASS:"):
                print(line)
    return output.strip()


def main():
    if importlib.metadata.version("gdtoolkit") != TOOLKIT_VERSION:
        raise RuntimeError("Tool version mismatch. Run ./scripts/setup_tools.sh")
    version = run("Engine version", [GODOT, "--version"])
    if not version.startswith(ENGINE_VERSION + ".stable."):
        raise RuntimeError(f"Expected Godot {ENGINE_VERSION} stable, got {version}")
    files = sorted(str(path.relative_to(ROOT)) for path in (ROOT / "src").rglob("*.gd"))
    tests = sorted(str(path.relative_to(ROOT)) for path in (ROOT / "tests").rglob("*_test.gd"))
    test_scripts = sorted(str(path.relative_to(ROOT)) for path in (ROOT / "tests").rglob("*.gd"))
    if not files or not tests:
        raise RuntimeError("Source scripts and at least one *_test.gd suite are required")
    all_scripts = files + test_scripts
    run("GDScript formatting", [str(BIN / "gdformat"), "--check", *all_scripts])
    run("GDScript lint", [str(BIN / "gdlint"), *all_scripts])
    for script in sorted((ROOT / "scripts").glob("*.sh")):
        run(f"Shell syntax: {script.name}", ["sh", "-n", str(script)])
    run("Python tooling tests", [sys.executable, "-m", "unittest", "discover",
                                 "-s", "tests", "-p", "*_test.py"])
    run("Godot project import", [GODOT, "--headless", "--editor", "--path", ".", "--quit"], godot=True)
    for script in all_scripts:
        run(
            f"Godot parse: {script}",
            [GODOT, "--headless", "--path", ".", "--check-only", "--script", script],
            godot=True,
        )
    for test_path in tests:
        run(
            f"Behavior tests: {test_path}",
            [GODOT, "--headless", "--path", ".", "--script", test_path],
            godot=True,
            test=True,
        )
    print("All checks passed.")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.TimeoutExpired, importlib.metadata.PackageNotFoundError) as error:
        print(f"CHECK FAILED: {error}", file=sys.stderr)
        sys.exit(1)
