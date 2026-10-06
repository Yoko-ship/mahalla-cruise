#!/usr/bin/env python3
"""Build and run signed debug APKs on the dedicated project Android emulator."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

from android_paths import ROOT, TOOLS, WINDOWS, environment, executable, tool_paths
from emulator_config import configure_gpu
from godot import find_engine

PATHS = tool_paths()
SDK = PATHS["sdk"]
JAVA = PATHS["java"]
ENV = environment()
BUILD = ROOT / "build/android"
APK = BUILD / "mahalla-cruise-debug.apk"
EMULATOR_APK = BUILD / "mahalla-cruise-emulator.apk"
AVD = PATHS["avd"]
SERIAL = PATHS["serial"]
PACKAGE = "com.example.mahallacruise"
ADB = executable(SDK / "platform-tools/adb")
SIGNER = executable(SDK / "build-tools/35.0.1/apksigner", batch=True)


def run(arguments, **kwargs):
    check = kwargs.pop("check", True)
    return subprocess.run([str(arg) for arg in arguments], cwd=ROOT, env=ENV, check=check, **kwargs)


def require_tools():
    for path in (executable(JAVA / "bin/java"), ADB, SIGNER):
        if not path.is_file():
            raise RuntimeError(f"Missing {path}. Follow docs/ANDROID.md to set up the toolchain.")


def configure_editor():
    path = PATHS["editor"]
    if WINDOWS and Path(find_engine()).parent != TOOLS / "godot":
        raise RuntimeError("Windows Android exports require the project-local Godot installation.")
    if not path.is_file():
        run([find_engine(), "--headless", "--editor", "--path", ".", "--quit"])
    contents = path.read_text(encoding="utf-8")
    settings = {
        "java_sdk_path": json.dumps(JAVA.as_posix()),
        "android_sdk_path": json.dumps(SDK.as_posix()),
    }
    if WINDOWS:
        # Only the private editor: exports must not disconnect the running AVD.
        settings["shutdown_adb_on_exit"] = "false"
    for name, value in settings.items():
        key = "export/android/" + name
        replacement = key + " = " + value
        pattern = re.compile(r"^" + re.escape(key) + r"\s*=.*$", re.MULTILINE)
        if pattern.search(contents):
            contents = pattern.sub(lambda match: replacement, contents)
        else:
            contents = contents.rstrip() + "\n" + replacement + "\n"
    path.write_text(contents, encoding="utf-8")


def build(for_emulator=False):
    require_tools()
    run([sys.executable, ROOT / "scripts/check.py"])
    configure_editor()
    key = PATHS["key"]
    if not key.exists():
        key.parent.mkdir(parents=True, exist_ok=True)
        run([
            executable(JAVA / "bin/keytool"), "-genkeypair", "-keystore", key,
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
    output = EMULATOR_APK if for_emulator else APK
    pending = output.with_name(output.stem + "-pending.apk")
    pending.unlink(missing_ok=True)
    result = run([
        find_engine(), "--headless", "--path", ".",
        "--export-debug", "Android Emulator" if for_emulator else "Android", pending,
    ], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", check=False)
    (BUILD / "export.log").write_text(result.stdout, encoding="utf-8")
    if result.returncode or re.search(r"(?:SCRIPT ERROR:|ERROR:|Parse Error:)", result.stdout) or not pending.is_file():
        raise RuntimeError("Android export failed; see build/android/export.log")
    run([SIGNER, "verify", pending])
    pending.replace(output)
    print(f"Built {output} ({output.stat().st_size / 1048576:.1f} MiB)")


def device_is_ours():
    result = subprocess.run(
        [str(ADB), "-s", SERIAL, "emu", "avd", "name"], env=ENV,
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, timeout=10,
    )
    return result.returncode == 0 and AVD in result.stdout.splitlines()


def start_emulator(native_resolution=False, headless=False):
    require_tools()
    process = None
    run([ADB, "start-server"], stdout=subprocess.DEVNULL)
    if not device_is_ours():
        devices = run([ADB, "devices"], stdout=subprocess.PIPE, text=True).stdout
        if SERIAL in devices:
            raise RuntimeError(f"{SERIAL} belongs to another device; close that emulator first.")
        avd_root = Path(ENV.get("ANDROID_AVD_HOME", Path.home() / ".android/avd"))
        configure_gpu(avd_root / (AVD + ".avd/config.ini"))
        BUILD.mkdir(parents=True, exist_ok=True)
        with (BUILD / "emulator.log").open("w") as log:
            arguments = [
                str(executable(SDK / "emulator/emulator")), "-avd", AVD, "-port", SERIAL.split("-")[1],
                "-memory", "2048", "-cores", "2", "-gpu", "host",
                "-no-snapshot", "-no-boot-anim",
            ]
            if not WINDOWS:
                arguments += ["-feature", "GuestAngle"]
            if headless:
                arguments += ["-no-window"]
            launch_options = {"creationflags": subprocess.CREATE_NO_WINDOW} if WINDOWS else {"start_new_session": True}
            process = subprocess.Popen(arguments, env=ENV, stdout=log, stderr=subprocess.STDOUT, **launch_options)
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
    apk = EMULATOR_APK if WINDOWS else APK
    if not apk.exists():
        raise RuntimeError("Build the APK first (use build --emulator for the Windows emulator)")
    run([ADB, "-s", SERIAL, "install", "-r", apk])
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
    parser.add_argument("--emulator", action="store_true", help="Build x86_64 APK for emulator testing")
    parser.add_argument("--headless", action="store_true", help="Start the emulator without a visible window")
    args = parser.parse_args()
    command = args.command
    if command == "build":
        build(args.emulator)
    elif command == "emulator":
        start_emulator(args.native_resolution, args.headless)
    elif command == "install":
        install()
    elif command == "run":
        build(WINDOWS)
        start_emulator(args.native_resolution, args.headless)
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
