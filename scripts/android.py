#!/usr/bin/env python3
"""Build and run the debug APK on the project's ARM64 Android emulator."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

from emulator_config import avd_config_path, configure_gpu

ROOT = Path(__file__).resolve().parent.parent
SDK = Path(os.environ.get("ANDROID_HOME", Path.home() / "Library/Android/sdk"))
JAVA = Path(os.environ.get("JAVA_HOME", Path.home() / "Library/Java/JavaVirtualMachines/mahalla-temurin-17.jdk/Contents/Home"))
ENV = {**os.environ, "JAVA_HOME": str(JAVA), "ANDROID_HOME": str(SDK), "ANDROID_SDK_ROOT": str(SDK)}
BUILD = ROOT / "build/android"
APK = BUILD / "mahalla-cruise-debug.apk"
AVD = "Mahalla_API_35"
SERIAL = "emulator-5554"
PACKAGE = "com.example.mahallacruise"
ADB = SDK / "platform-tools/adb"


def run(arguments, **kwargs):
    check = kwargs.pop("check", True)
    return subprocess.run([str(arg) for arg in arguments], cwd=ROOT, env=ENV, check=check, **kwargs)


def require_tools():
    for path in (JAVA / "bin/java", ADB, SDK / "build-tools/35.0.1/apksigner"):
        if not path.is_file():
            raise RuntimeError(f"Missing {path}. Follow docs/ANDROID.md to set up the toolchain.")


def configure_editor():
    path = Path.home() / "Library/Application Support/Godot/editor_settings-4.7.tres"
    if not path.is_file():
        run([ROOT / "scripts/godot.sh", "--headless", "--editor", "--path", ".", "--quit"])
    contents = path.read_text()
    for name, value in (("java_sdk_path", JAVA), ("android_sdk_path", SDK)):
        key = "export/android/" + name
        replacement = key + " = " + json.dumps(str(value))
        pattern = re.compile(r"^" + re.escape(key) + r"\s*=.*$", re.MULTILINE)
        if pattern.search(contents):
            contents = pattern.sub(lambda match: replacement, contents)
        else:
            contents = contents.rstrip() + "\n" + replacement + "\n"
    path.write_text(contents)


def build():
    require_tools()
    run([ROOT / "scripts/check.sh"])
    configure_editor()
    key = Path.home() / "Library/Application Support/Godot/keystores/debug.keystore"
    if not key.exists():
        key.parent.mkdir(parents=True, exist_ok=True)
        run([
            JAVA / "bin/keytool", "-genkeypair", "-keystore", key,
            "-storepass", "android", "-keypass", "android", "-alias", "androiddebugkey",
            "-dname", "CN=Android Debug,O=Android,C=US", "-keyalg", "RSA", "-validity", "10000",
        ], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    ENV.update({
        "GODOT_ANDROID_KEYSTORE_DEBUG_PATH": str(key),
        "GODOT_ANDROID_KEYSTORE_DEBUG_USER": "androiddebugkey",
        "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD": "android",
    })
    BUILD.mkdir(parents=True, exist_ok=True)
    # Export to a temporary APK so a failed export cannot leave a stale success artifact.
    pending = BUILD / "mahalla-cruise-pending.apk"
    pending.unlink(missing_ok=True)
    result = run([
        ROOT / "scripts/godot.sh", "--headless", "--path", ".",
        "--export-debug", "Android", pending,
    ], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=False)
    (BUILD / "export.log").write_text(result.stdout)
    if result.returncode or re.search(r"(?:SCRIPT ERROR:|ERROR:|Parse Error:)", result.stdout) or not pending.is_file():
        raise RuntimeError("Android export failed; see build/android/export.log")
    run([SDK / "build-tools/35.0.1/apksigner", "verify", pending])
    pending.replace(APK)
    print(f"Built {APK} ({APK.stat().st_size / 1048576:.1f} MiB)")


def device_is_ours():
    result = subprocess.run(
        [str(ADB), "-s", SERIAL, "emu", "avd", "name"], env=ENV,
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=10,
    )
    return result.returncode == 0 and AVD in result.stdout.splitlines()


def start_emulator(native_resolution=False):
    require_tools()
    process = None
    run([ADB, "start-server"], stdout=subprocess.DEVNULL)
    if not device_is_ours():
        devices = run([ADB, "devices"], stdout=subprocess.PIPE, text=True).stdout
        if SERIAL in devices:
            raise RuntimeError("Port 5554 belongs to another device; close that emulator first.")
        configure_gpu(avd_config_path(AVD))
        BUILD.mkdir(parents=True, exist_ok=True)
        with (BUILD / "emulator.log").open("w") as log:
            process = subprocess.Popen([
                str(SDK / "emulator/emulator"), "-avd", AVD, "-port", "5554",
                "-memory", "2048", "-cores", "2", "-gpu", "host",
                "-feature", "GuestAngle", "-no-snapshot", "-no-boot-anim",
            ], env=ENV, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
    print("Waiting for Android to boot...", flush=True)
    deadline = time.monotonic() + 180
    while time.monotonic() < deadline:
        if process is not None and process.poll() is not None:
            raise RuntimeError("Emulator closed before booting; see build/android/emulator.log")
        boot = subprocess.run(
            [str(ADB), "-s", SERIAL, "shell", "getprop", "sys.boot_completed"], env=ENV,
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=10,
        )
        if boot.returncode == 0 and boot.stdout.strip() == "1":
            if not device_is_ours():
                raise RuntimeError("The connected emulator is not the project AVD")
            configure_display(native_resolution)
            print("Android emulator ready.")
            return
        time.sleep(2)
    raise RuntimeError("Emulator did not boot; see build/android/emulator.log")


def configure_display(native_resolution=False):
    # Keep the Pixel 4 aspect ratio and dp sizes, with 56% fewer rendered pixels.
    size, density = ("reset", "reset") if native_resolution else ("720x1520", "293")
    run([ADB, "-s", SERIAL, "shell", "wm", "size", size])
    run([ADB, "-s", SERIAL, "shell", "wm", "density", density])
    label = "native 1080x2280" if native_resolution else "720x1520 development profile"
    print("Emulator display: " + label, flush=True)


def install():
    require_tools()
    if not device_is_ours():
        raise RuntimeError("Start the project emulator with ./scripts/android.sh emulator")
    if not APK.exists():
        raise RuntimeError("Build the APK first with ./scripts/android.sh build")
    run([ADB, "-s", SERIAL, "install", "-r", APK])
    run([ADB, "-s", SERIAL, "shell", "am", "force-stop", PACKAGE])
    run([
        ADB, "-s", SERIAL, "shell", "am", "start", "-W",
        "-a", "android.intent.action.MAIN", "-c", "android.intent.category.LAUNCHER",
        "-p", PACKAGE,
    ])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("build", "emulator", "install", "run", "devices"))
    parser.add_argument("--native-resolution", action="store_true",
                        help="Use the native Pixel 4 display with emulator/run; default is lighter 720p")
    args = parser.parse_args()
    command = args.command
    if command == "build":
        build()
    elif command == "emulator":
        start_emulator(args.native_resolution)
    elif command == "install":
        install()
    elif command == "run":
        build()
        start_emulator(args.native_resolution)
        install()
    else:
        require_tools()
        run([ADB, "devices"])


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, subprocess.SubprocessError) as error:
        print(f"ANDROID FAILED: {error}", file=sys.stderr)
        sys.exit(1)
