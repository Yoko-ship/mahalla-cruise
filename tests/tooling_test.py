"""Regression coverage for the portable gate and engine discovery."""

from contextlib import redirect_stderr, redirect_stdout
import io
import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import check
import godot


class GateTests(unittest.TestCase):
    def call_gate(self, output, exit_code=0, **kwargs):
        result = subprocess.CompletedProcess([], exit_code, output)
        with patch.object(check.subprocess, "run", return_value=result):
            with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                return check.run("fixture", ["engine"], **kwargs)

    def test_engine_errors_fail_even_with_success_marker(self):
        for error in ["SCRIPT ERROR:", "ERROR:", "Parse Error:"]:
            with self.subTest(error=error), self.assertRaises(RuntimeError):
                self.call_gate(f"{error} broken\nPASS: fixture", godot=True, test=True)

    def test_missing_completion_and_bad_exit_fail(self):
        with self.assertRaises(RuntimeError):
            self.call_gate("Started", test=True)
        with self.assertRaises(RuntimeError):
            self.call_gate("PASS: fixture", exit_code=1, test=True)

    def test_ansi_and_unicode_output_survive(self):
        output = self.call_gate("\x1b[32mPASS: Ўзбекча Русский\x1b[0m", test=True)
        self.assertEqual(output, "PASS: Ўзбекча Русский")

    def test_timeout_is_not_a_pass(self):
        with patch.object(check.subprocess, "run", side_effect=subprocess.TimeoutExpired("engine", 60)):
            with redirect_stdout(io.StringIO()), self.assertRaises(subprocess.TimeoutExpired):
                check.run("fixture", ["engine"], test=True)


class EngineDiscoveryTests(unittest.TestCase):
    def test_explicit_executable_wins_and_preserves_spaces(self):
        with patch.dict(os.environ, {"GODOT_BIN": "D:/Game Tools/Godot.exe"}):
            self.assertEqual(godot.find_engine(), "D:/Game Tools/Godot.exe")

    def test_project_engine_wins_over_path(self):
        with patch.dict(os.environ, {"GODOT_BIN": ""}), patch.object(Path, "is_file", return_value=True):
            with patch.object(godot.shutil, "which", return_value="global-godot"):
                result = godot.find_engine()
        self.assertTrue(result.endswith(f"Godot_v{godot.VERSION}-stable_win64.exe"))

    def test_path_fallback_and_missing_engine(self):
        with patch.dict(os.environ, {"GODOT_BIN": ""}):
            with patch.object(godot.shutil, "which", return_value="/usr/bin/godot"):
                with patch.object(Path, "is_file", autospec=True, side_effect=lambda p: str(p) == str(Path("/usr/bin/godot"))):
                    self.assertEqual(godot.find_engine(), "/usr/bin/godot")
            with patch.object(godot.shutil, "which", return_value=None):
                with patch.object(Path, "is_file", return_value=False):
                    with self.assertRaises(FileNotFoundError):
                        godot.find_engine()
