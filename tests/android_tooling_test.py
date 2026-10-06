"""Android tooling must isolate devices, files, signing, and failed exports."""

import configparser
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import android
import android_paths


class AndroidPathsTests(unittest.TestCase):
    def test_windows_tools_are_project_local(self):
        with patch.object(android_paths, "WINDOWS", True):
            paths = android_paths.tool_paths()
            env = android_paths.environment()
        for key in ("sdk", "java", "editor", "key"):
            self.assertTrue(paths[key].is_relative_to(android_paths.TOOLS), key)
        for key in ("ANDROID_USER_HOME", "ANDROID_AVD_HOME", "TEMP", "TMP"):
            self.assertTrue(Path(env[key]).is_relative_to(android_paths.TOOLS), key)
        self.assertNotEqual(paths["serial"], "emulator-5554")

    def test_executable_suffixes(self):
        with patch.object(android_paths, "WINDOWS", True):
            self.assertEqual(android_paths.executable(Path("sdk/adb")), Path("sdk/adb.exe"))
            self.assertEqual(android_paths.executable(Path("sdk/apksigner"), True), Path("sdk/apksigner.bat"))
        with patch.object(android_paths, "WINDOWS", False):
            self.assertEqual(android_paths.executable(Path("sdk/adb")), Path("sdk/adb"))

    def test_phone_and_emulator_presets_have_separate_abis(self):
        presets = configparser.ConfigParser()
        presets.read(android.ROOT / "export_presets.cfg")
        self.assertEqual(presets["preset.0"]["name"], '"Android"')
        self.assertEqual(presets["preset.0.options"]["architectures/arm64-v8a"], "true")
        self.assertEqual(presets["preset.0.options"]["architectures/x86_64"], "false")
        self.assertEqual(presets["preset.1"]["name"], '"Android Emulator"')
        self.assertEqual(presets["preset.1.options"]["architectures/x86_64"], "true")
        self.assertEqual(presets["preset.1.options"]["architectures/arm64-v8a"], "false")
        self.assertNotEqual(presets["preset.0"]["export_path"], presets["preset.1"]["export_path"])


class AndroidDeviceTests(unittest.TestCase):
    def test_avd_name_must_match_exactly(self):
        for name, expected in ((android.AVD + "\nOK\n", True), (android.AVD + "_other\n", False)):
            result = subprocess.CompletedProcess([], 0, name)
            with patch.object(android.subprocess, "run", return_value=result):
                self.assertEqual(android.device_is_ours(), expected)

    def test_install_refuses_unknown_devices_before_writing(self):
        with patch.object(android, "require_tools"), patch.object(android, "device_is_ours", return_value=False):
            with patch.object(android, "run") as run, self.assertRaises(RuntimeError):
                android.install()
            run.assert_not_called()

    def test_install_targets_only_project_emulator_and_preserves_data(self):
        with tempfile.TemporaryDirectory() as directory:
            apk = Path(directory) / "emulator.apk"
            apk.write_bytes(b"fixture")
            with patch.object(android, "require_tools"), patch.object(android, "device_is_ours", return_value=True):
                with patch.object(android, "WINDOWS", True), patch.object(android, "EMULATOR_APK", apk):
                    with patch.object(android, "run") as run:
                        android.install()
            self.assertEqual(run.call_args_list[0].args[0], [android.ADB, "-s", android.SERIAL, "install", "-r", apk])
            for call in run.call_args_list:
                self.assertEqual(call.args[0][1:3], ["-s", android.SERIAL])
                self.assertNotIn("uninstall", call.args[0])
                self.assertNotIn("clear", call.args[0])


class AndroidBuildTests(unittest.TestCase):
    def test_private_editor_keeps_adb_alive_without_changing_other_settings(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "editor.tres"
            for windows in (True, False):
                with self.subTest(windows=windows):
                    path.write_text('[resource]\ninterface/editor/theme = "Custom"\n'
                                    'export/android/shutdown_adb_on_exit = true\n', encoding="utf-8")
                    with patch.object(android, "WINDOWS", windows), patch.dict(android.PATHS, {"editor": path}):
                        with patch.object(android, "find_engine", return_value=str(android.TOOLS / "godot/engine.exe")):
                            android.configure_editor()
                            first = path.read_text(encoding="utf-8")
                            android.configure_editor()
                    self.assertEqual(first, path.read_text(encoding="utf-8"))
                    self.assertIn('interface/editor/theme = "Custom"', first)
                    self.assertIn('export/android/java_sdk_path = ', first)
                    expected = "false" if windows else "true"
                    self.assertIn('export/android/shutdown_adb_on_exit = ' + expected, first)
                    self.assertEqual(first.count('export/android/shutdown_adb_on_exit'), 1)

    def test_failed_export_never_replaces_existing_apk(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            apk = root / "game.apk"
            key = root / "debug.keystore"
            apk.write_bytes(b"previous verified build")
            key.write_bytes(b"fixture debug key")

            def command(args, **kwargs):
                if "--export-debug" in args:
                    Path(args[-1]).write_bytes(b"partial export")
                    return subprocess.CompletedProcess(args, 0, "ERROR: export failed")
                return subprocess.CompletedProcess(args, 0, "")

            with patch.object(android, "require_tools"), patch.object(android, "configure_editor"):
                with patch.object(android, "find_engine", return_value="engine"):
                    with patch.object(android, "BUILD", root), patch.object(android, "APK", apk):
                        with patch.dict(android.PATHS, {"key": key}), patch.object(android, "run", side_effect=command) as run:
                            with self.assertRaises(RuntimeError):
                                android.build()
            self.assertEqual(apk.read_bytes(), b"previous verified build")
            self.assertIn("ERROR:", (root / "export.log").read_text())
            self.assertFalse(any("verify" in call.args[0] for call in run.call_args_list))
