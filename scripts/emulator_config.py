"""Keep the project AVD's saved GPU setting aligned with its launcher."""

import os
from pathlib import Path
import re


def avd_config_path(name):
    avd_root = Path(os.environ.get("ANDROID_AVD_HOME", Path.home() / ".android/avd"))
    return avd_root / (name + ".avd") / "config.ini"


def configure_gpu(path):
    """Update graphics keys only; retain the virtual device and its user data."""
    path = Path(path)
    text = path.read_text()
    for key, value in {"hw.gpu.enabled": "yes", "hw.gpu.mode": "host"}.items():
        pattern = re.compile(r"^" + re.escape(key) + r"\s*=.*$", re.MULTILINE)
        line = key + " = " + value
        text = pattern.sub(line, text) if pattern.search(text) else text.rstrip() + "\n" + line + "\n"
    if text != path.read_text():
        path.write_text(text)
