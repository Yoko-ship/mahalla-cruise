#!/usr/bin/env python3
"""Install the local Android debug toolchain on an Apple Silicon Mac.

SDK licenses are presented interactively unless --accept-sdk-licenses is passed.
Downloads come from Google, Adoptium, and Godot; base archives are checksum-verified.
"""
import argparse
import concurrent.futures
import hashlib
import os
import pathlib
import platform
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from emulator_config import avd_config_path, configure_gpu
user_root = pathlib.Path.home()

def download(url, destination, algorithm, expected):
    digest = hashlib.new(algorithm)
    with urllib.request.urlopen(url, timeout=60) as response, destination.open('wb') as out:
        while True:
            chunk = response.read(1024 * 1024)
            if not chunk:
                break
            digest.update(chunk)
            out.write(chunk)
    if digest.hexdigest() != expected:
        raise RuntimeError('Checksum mismatch: ' + destination.name)
    print('Verified ' + destination.name, flush=True)

def java():
    base = 'https://github.com/adoptium/temurin17-binaries/releases/download/jdk-17.0.20.1%2B1/'
    name = 'OpenJDK17U-jdk_aarch64_mac_hotspot_17.0.20.1_1.tar.gz'
    target = user_root / 'Library/Java/JavaVirtualMachines/mahalla-temurin-17.jdk'
    if target.exists():
        print('Java already installed', flush=True); return
    expected = urllib.request.urlopen(base + name + '.sha256.txt', timeout=30).read().decode().split()[0]
    with tempfile.TemporaryDirectory(prefix='mahalla-java-') as tmp:
        archive = pathlib.Path(tmp) / name
        download(base + name, archive, 'sha256', expected)
        unpack = pathlib.Path(tmp) / 'unpacked'; unpack.mkdir()
        subprocess.run(['tar', '-xzf', str(archive), '-C', str(unpack)], check=True)
        bundle = next(p for p in unpack.iterdir() if (p / 'Contents/Home/bin/java').exists())
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(bundle), str(target))
    print('Installed Java 17', flush=True)

def sdk():
    target = user_root / 'Library/Android/sdk/cmdline-tools/19.0'
    if target.exists():
        print('SDK command-line tools already installed', flush=True); return
    with tempfile.TemporaryDirectory(prefix='mahalla-sdk-') as tmp:
        archive = pathlib.Path(tmp) / 'commandlinetools.zip'
        download('https://dl.google.com/android/repository/commandlinetools-mac-13114758_latest.zip', archive, 'sha1', 'c3e06a1959762e89167d1cbaa988605f6f7c1d24')
        subprocess.run(['ditto', '-x', '-k', str(archive), tmp], check=True)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(pathlib.Path(tmp) / 'cmdline-tools'), str(target))
    print('Installed SDK command-line tools 19.0', flush=True)

def templates():
    base = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/'
    name = 'Godot_v4.7.2-stable_export_templates.tpz'
    target = user_root / 'Library/Application Support/Godot/export_templates/4.7.2.stable'
    if (target / 'android_debug.apk').exists() and (target / 'android_release.apk').exists():
        print('Android templates already installed', flush=True); return
    sums = urllib.request.urlopen(base + 'SHA512-SUMS.txt', timeout=30).read().decode()
    expected = next(line.split()[0] for line in sums.splitlines() if line.split()[-1].lstrip('*') == name)
    with tempfile.TemporaryDirectory(prefix='mahalla-templates-') as tmp:
        archive = pathlib.Path(tmp) / name
        download(base + name, archive, 'sha512', expected)
        target.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive) as source:
            for filename in ('android_debug.apk', 'android_release.apk', 'version.txt'):
                with source.open('templates/' + filename) as inp, (target / filename).open('wb') as out:
                    shutil.copyfileobj(inp, out)
    print('Installed Godot Android export templates', flush=True)


def install_sdk_packages(accept_licenses):
    sdk_root = user_root / 'Library/Android/sdk'
    java_root = user_root / 'Library/Java/JavaVirtualMachines/mahalla-temurin-17.jdk/Contents/Home'
    env = {**os.environ, 'JAVA_HOME': str(java_root), 'ANDROID_HOME': str(sdk_root), 'ANDROID_SDK_ROOT': str(sdk_root)}
    manager = sdk_root / 'cmdline-tools/19.0/bin/sdkmanager'
    arguments = [str(manager), '--sdk_root=' + str(sdk_root)]
    license_input = {'input': 'y\n' * 100} if accept_licenses else {}
    subprocess.run(arguments + ['--licenses'], env=env, text=True, check=True, **license_input)
    subprocess.run(arguments + [
        'platform-tools', 'build-tools;35.0.1', 'platforms;android-35',
        'emulator', 'system-images;android-35;google_apis;arm64-v8a',
    ], env=env, text=True, check=True, **license_input)
    avd_config = avd_config_path('Mahalla_API_35')
    if not avd_config.exists():
        subprocess.run([
            str(sdk_root / 'cmdline-tools/19.0/bin/avdmanager'), 'create', 'avd',
            '--name', 'Mahalla_API_35', '--package', 'system-images;android-35;google_apis;arm64-v8a',
            '--device', 'pixel_4',
        ], env=env, input='no\n', text=True, check=True)
        config = avd_config.read_text()
        for key, value in {'hw.ramSize': '2048', 'hw.keyboard': 'yes', 'showDeviceFrame': 'no'}.items():
            pattern = re.compile(r'^' + re.escape(key) + r'=.*$', re.MULTILINE)
            line = key + '=' + value
            config = pattern.sub(line, config) if pattern.search(config) else config.rstrip() + '\n' + line + '\n'
        avd_config.write_text(config)
    configure_gpu(avd_config)
    print('Android toolchain and Mahalla_API_35 emulator are ready.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--accept-sdk-licenses', action='store_true')
    args = parser.parse_args()
    if sys.platform == 'win32':
        from setup_android_windows import setup
        setup(args.accept_sdk_licenses)
        return
    if sys.platform != 'darwin' or platform.machine() != 'arm64':
        raise SystemExit('This installer targets Apple Silicon macOS; see docs/ANDROID.md.')
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        jobs = [pool.submit(task) for task in (java, sdk, templates)]
        for job in jobs:
            job.result()
    install_sdk_packages(args.accept_sdk_licenses)


if __name__ == '__main__':
    main()
