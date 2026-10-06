"""Host-specific tool locations. Windows tooling stays inside the checkout."""

import os
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent.parent
WINDOWS = sys.platform == "win32"
TOOLS = ROOT / ".tools"


def tool_paths():
    if WINDOWS:
        return {
            "sdk": TOOLS / "android-sdk",
            "java": TOOLS / "java/jdk-17.0.20.1+1",
            "editor": TOOLS / "godot/editor_data/editor_settings-4.7.tres",
            "key": TOOLS / "android-user/debug.keystore",
            "avd": "Mahalla_Windows_API_35",
            "serial": "emulator-5580",
        }
    return {
        "sdk": Path(os.environ.get("ANDROID_HOME", Path.home() / "Library/Android/sdk")),
        "java": Path(os.environ.get(
            "JAVA_HOME", Path.home() / "Library/Java/JavaVirtualMachines/mahalla-temurin-17.jdk/Contents/Home"
        )),
        "editor": Path.home() / "Library/Application Support/Godot/editor_settings-4.7.tres",
        "key": Path.home() / "Library/Application Support/Godot/keystores/debug.keystore",
        "avd": "Mahalla_API_35",
        "serial": "emulator-5554",
    }


def environment():
    paths = tool_paths()
    env = {**os.environ, "JAVA_HOME": str(paths["java"]),
           "ANDROID_HOME": str(paths["sdk"]), "ANDROID_SDK_ROOT": str(paths["sdk"])}
    if WINDOWS:
        env.update({
            "ANDROID_USER_HOME": str(TOOLS / "android-user"),
            "ANDROID_AVD_HOME": str(TOOLS / "android-avd"),
            "TEMP": str(TOOLS / "tmp"), "TMP": str(TOOLS / "tmp"),
        })
    return env


def executable(path, batch=False):
    suffix = (".bat" if batch else ".exe") if WINDOWS else ""
    return Path(str(path) + suffix)
