"""Check launcher configuration without touching the real SDK or player data."""

import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import sys

SCRIPTS = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS))
from emulator_config import configure_gpu

SPEC = importlib.util.spec_from_file_location("mahalla_android", SCRIPTS / "android.py")
ANDROID = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ANDROID)


class EmulatorConfigTests(unittest.TestCase):
    def test_existing_settings_and_data_are_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "config.ini"
            data = Path(directory) / "userdata.img"
            data.write_bytes(b"existing player data")
            config.write_text("hw.gpu.enabled = no\nhw.gpu.mode=auto\nhw.ramSize = 2048\n")
            configure_gpu(config)
            self.assertEqual(config.read_text(),
                             "hw.gpu.enabled = yes\nhw.gpu.mode = host\nhw.ramSize = 2048\n")
            self.assertEqual(data.read_bytes(), b"existing player data")
            unchanged_time = config.stat().st_mtime_ns
            configure_gpu(config)
            self.assertEqual(config.stat().st_mtime_ns, unchanged_time)

    def test_missing_keys_are_added(self):
        with tempfile.TemporaryDirectory() as directory:
            config = Path(directory) / "config.ini"
            config.write_text("hw.ramSize=2048\n")
            configure_gpu(config)
            self.assertIn("hw.gpu.enabled = yes\n", config.read_text())
            self.assertIn("hw.gpu.mode = host\n", config.read_text())

    def test_native_resolution_clears_both_overrides(self):
        with patch.object(ANDROID, "run") as run:
            ANDROID.configure_display(True)
        self.assertEqual([call.args[0][-3:] for call in run.call_args_list],
                         [["wm", "size", "reset"], ["wm", "density", "reset"]])

    def test_development_profile_sets_size_and_density(self):
        with patch.object(ANDROID, "run") as run:
            ANDROID.configure_display()
        self.assertEqual([call.args[0][-3:] for call in run.call_args_list],
                         [["wm", "size", "720x1520"], ["wm", "density", "293"]])


if __name__ == "__main__":
    unittest.main()
