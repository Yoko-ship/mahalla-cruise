"""Install the pinned Android debug toolchain entirely inside .tools on Windows."""

import concurrent.futures
import hashlib
from pathlib import Path
import shutil
import subprocess
import urllib.request
import zipfile

from android_paths import ROOT, TOOLS, environment, tool_paths
from emulator_config import configure_gpu

DOWNLOADS = TOOLS / "downloads"
PATHS = tool_paths()
SDK_ARCHIVE = "commandlinetools-win-13114758_latest.zip"
SDK_SHA1 = "54a582f3bf73e04253602f2d1c80bd5868aac115"


def read_url(url):
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read().decode("utf-8")


def digest(path, algorithm):
    value = hashlib.new(algorithm)
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            value.update(chunk)
    return value.hexdigest()


def download(url, name, algorithm, expected):
    DOWNLOADS.mkdir(parents=True, exist_ok=True)
    target = DOWNLOADS / name
    if target.is_file() and digest(target, algorithm) == expected:
        return target
    pending = target.with_suffix(target.suffix + ".part")
    print("Downloading " + name, flush=True)
    with urllib.request.urlopen(url, timeout=60) as response, pending.open("wb") as output:
        shutil.copyfileobj(response, output)
    if digest(pending, algorithm) != expected:
        raise RuntimeError("Checksum mismatch: " + name)
    pending.replace(target)
    print("Verified " + name, flush=True)
    return target


def unpack(archive, target):
    target.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as source:
        for member in source.infolist():
            resolved = (target / member.filename).resolve()
            if not resolved.is_relative_to(target.resolve()):
                raise RuntimeError("Archive entry escapes installation directory")
        source.extractall(target)


def install_java():
    if (PATHS["java"] / "bin/java.exe").is_file():
        return
    base = "https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.20.1%2B1/"
    name = "OpenJDK17U-jdk_x64_windows_hotspot_17.0.20.1_1.zip"
    expected = read_url(base + name + ".sha256.txt").split()[0]
    archive = download(base + name, name, "sha256", expected)
    unpack(archive, TOOLS / "java")
    if not (PATHS["java"] / "bin/java.exe").is_file():
        raise RuntimeError("Java archive did not contain the expected JDK")


def install_sdk():
    target = PATHS["sdk"] / "cmdline-tools/19.0"
    if (target / "bin/sdkmanager.bat").is_file():
        return
    archive = download(
        "https://dl.google.com/android/repository/" + SDK_ARCHIVE,
        SDK_ARCHIVE, "sha1", SDK_SHA1,
    )
    unpacked = TOOLS / "sdk-unpack"
    unpack(archive, unpacked)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(unpacked / "cmdline-tools"), target)


def install_templates():
    engine = TOOLS / "godot/Godot_v4.7.2-stable_win64.exe"
    if not engine.is_file():
        raise RuntimeError("Run scripts/setup_tools.ps1 first to install the pinned engine.")
    # This is the private project engine; leave other Godot installations unchanged.
    (engine.parent / "_sc_").touch(exist_ok=True)
    target = engine.parent / "editor_data/export_templates/4.7.2.stable"
    if all((target / name).is_file() for name in ("android_debug.apk", "android_release.apk")):
        return
    base = "https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/"
    name = "Godot_v4.7.2-stable_export_templates.tpz"
    sums = read_url(base + "SHA512-SUMS.txt")
    expected = next(line.split()[0] for line in sums.splitlines() if line.split()[-1].lstrip("*") == name)
    archive = download(base + name, name, "sha512", expected)
    target.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive) as source:
        for filename in ("android_debug.apk", "android_release.apk", "version.txt"):
            with source.open("templates/" + filename) as inp, (target / filename).open("wb") as out:
                shutil.copyfileobj(inp, out)


def install_packages(accept_licenses):
    env = environment()
    for name in ("ANDROID_USER_HOME", "ANDROID_AVD_HOME", "TEMP"):
        Path(env[name]).mkdir(parents=True, exist_ok=True)
    manager = PATHS["sdk"] / "cmdline-tools/19.0/bin/sdkmanager.bat"
    args = [str(manager), "--sdk_root=" + str(PATHS["sdk"])]
    license_input = {"input": "y\n" * 100} if accept_licenses else {}
    subprocess.run(args + ["--licenses"], env=env, text=True, check=True, **license_input)
    subprocess.run(args + [
        "platform-tools", "build-tools;35.0.1", "platforms;android-35",
        "emulator", "system-images;android-35;google_apis;x86_64",
    ], env=env, text=True, check=True, **license_input)
    config = Path(env["ANDROID_AVD_HOME"]) / (PATHS["avd"] + ".avd/config.ini")
    if not config.is_file():
        subprocess.run([
            str(PATHS["sdk"] / "cmdline-tools/19.0/bin/avdmanager.bat"), "create", "avd",
            "--name", PATHS["avd"], "--package", "system-images;android-35;google_apis;x86_64",
            "--device", "pixel_4",
        ], env=env, input="no\n", text=True, check=True)
    configure_gpu(config)
    print("Project-local Windows Android toolchain is ready.", flush=True)


def setup(accept_licenses):
    if not (ROOT / ".venv/Scripts/python.exe").is_file():
        raise RuntimeError("Run scripts/setup_tools.ps1 first.")
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        jobs = [pool.submit(task) for task in (install_java, install_sdk, install_templates)]
        for job in jobs:
            job.result()
    install_packages(accept_licenses)
