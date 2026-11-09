"""Build isolated Circuit Android/Windows/Web releases using the cached toolchain.

Every invocation allocates a fresh rN directory. Private signing credentials are
read only from the existing external cache and passed through the environment.
"""
from pathlib import Path
import argparse
import json
import os
import re
import shutil
import sys
import zipfile
from release_common import (VERSION, BUILD, PACKAGE, NAME, LICENSES, artifact,
                            checked, new_revision, snapshot, stage_source,
                            validate_source, write_json)

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = ROOT.parent
CACHE = Path.home() / ".cache/donutsgame"
GODOT = CACHE / "godot/Godot_v4.7.2-stable_win64_console.exe"


def android_environment():
    setup = json.loads((REPOSITORY / "playtest-reports/android/toolchain.json").read_text(encoding="utf-8"))
    java, sdk = Path(setup["java_home"]), Path(setup["android_sdk"])
    signing = CACHE / "android/signing"
    key = signing / "golden-hour-release.keystore"
    credentials = json.loads((signing / "credentials.json").read_text(encoding="utf-8"))
    if not key.is_file():
        raise RuntimeError("Restore the existing private release key; this tool never replaces it")
    settings = (Path(os.environ["APPDATA"]) / "Godot/editor_settings-4.7.tres").read_text(encoding="utf-8")
    for field, path in (("java_sdk_path", java), ("android_sdk_path", sdk)):
        expected = f'export/android/{field} = "{path.as_posix()}"'
        if expected not in settings:
            raise RuntimeError("Godot's cached Android toolchain settings differ; configure them explicitly first")
    env = dict(os.environ, JAVA_HOME=str(java), ANDROID_HOME=str(sdk), ANDROID_SDK_ROOT=str(sdk))
    env["PATH"] = str(java / "bin") + os.pathsep + env.get("PATH", "")
    env["GODOT_ANDROID_KEYSTORE_RELEASE_PATH"] = str(key)
    env["GODOT_ANDROID_KEYSTORE_RELEASE_USER"] = credentials["alias"]
    env["GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD"] = credentials["password"]
    return env, java, sdk


def verify_android(apk, logs, env, java, sdk):
    build = sdk / "build-tools/35.0.1"
    signature = checked([java / "bin/java.exe", "-jar", build / "lib/apksigner.jar", "verify",
                         "--verbose", "--print-certs", apk], logs / "android-signature.log", env=env)
    if "Verified using v2 scheme (APK Signature Scheme v2): true" not in signature:
        raise RuntimeError("Release APK v2 signature verification failed")
    badging = checked([build / "aapt.exe", "dump", "badging", apk], logs / "android-package.log", env=env)
    for expected in (f"package: name='{PACKAGE}'", f"versionCode='{BUILD}'", f"versionName='{VERSION}'",
                     "sdkVersion:'24'", "targetSdkVersion:'36'", "armeabi-v7a", "arm64-v8a", "x86_64"):
        if expected not in badging:
            raise RuntimeError("Unexpected APK metadata; missing " + expected)
    if "uses-permission:" in badging:
        raise RuntimeError("Offline Circuit APK unexpectedly requests an Android permission")
    manifest = checked([build / "aapt.exe", "dump", "xmltree", apk, "AndroidManifest.xml"],
                       logs / "android-manifest.log", env=env)
    if not re.search(r"android:screenOrientation[^\n]*=\(type 0x10\)0x1(?:\s|$)", manifest):
        raise RuntimeError("The packaged Android activity does not declare portrait orientation")
    with zipfile.ZipFile(apk) as archive:
        if archive.testzip() is not None:
            raise RuntimeError("APK archive integrity failed")
        names = archive.namelist()
        for notice in LICENSES:
            if not any(name.endswith(notice) for name in names):
                raise RuntimeError("APK license missing: " + notice)
        if any(any(part in name.split("/") for part in ("tests", "tools", "unity")) for name in names):
            raise RuntimeError("APK contains development files")
        if any("stand_main" in name for name in names):
            raise RuntimeError("APK contains the original game's entry point")
    return dict(artifact(apk), package=PACKAGE, version_code=100, signed=True,
                signature_verified=True, minimum_android_api=24, target_android_api=36,
                architectures=["armeabi-v7a", "arm64-v8a", "x86_64"], permissions=[], portrait=True,
                physical_device_validation="pending", emulator_validation="pending")


def zip_folder(folder, destination):
    with zipfile.ZipFile(destination, "x", zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(folder.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(folder).as_posix())
    with zipfile.ZipFile(destination) as archive:
        if archive.testzip() is not None:
            raise RuntimeError("ZIP integrity failed: " + str(destination))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=("all", "android", "windows", "web"), default="all")
    parser.add_argument("--skip-tests", action="store_true", help="Only for unchanged, already verified source")
    args = parser.parse_args()
    validate_source(ROOT)
    output = new_revision(REPOSITORY / "builds/circuit" / VERSION)
    logs, stage = output / "logs", output / "source"
    logs.mkdir()
    print("Release directory: " + str(output), flush=True)
    stage_source(ROOT, stage)
    platforms = ["android", "windows", "web"] if args.platform == "all" else [args.platform]
    env, java, sdk = android_environment() if "android" in platforms else (dict(os.environ), None, None)
    checked([GODOT, "--headless", "--path", stage, "--script", "res://tools/generate_ios_icon.gd"], logs / "icon.log", env=env)
    checked([GODOT, "--headless", "--path", stage, "--editor", "--import"], logs / "import.log", env=env)
    source = snapshot(stage, output)
    tests = []
    if not args.skip_tests:
        test_env = dict(env, APPDATA=str(output / "qa-user-data"), LOCALAPPDATA=str(output / "qa-local-data"))
        for test in sorted((stage / "tests").glob("test_*.gd")):
            checked([GODOT, "--headless", "--path", stage, "--script", str(test)], logs / (test.stem + ".log"), env=test_env)
            tests.append(test.name)
    report = {"game": "Golden Hour Circuit", "version": VERSION, "revision": output.name,
              "source": source, "tests": tests, "artifacts": {}, "physical_device_validation": "pending"}
    write_json(output / "build-manifest.json", report)
    if "android" in platforms:
        folder = output / "android"
        folder.mkdir()
        apk = folder / (NAME + "-" + VERSION + "-Android.apk")
        checked([GODOT, "--headless", "--path", stage, "--export-release", "Android", apk], logs / "android-export.log", env=env)
        report["artifacts"]["android"] = verify_android(apk, logs, env, java, sdk)
        write_json(output / "build-manifest.json", report)
    if "windows" in platforms:
        folder = output / "windows"
        folder.mkdir()
        exe = folder / (NAME + ".exe")
        checked([GODOT, "--headless", "--path", stage, "--export-release", "Windows Desktop", exe], logs / "windows-export.log", env=env)
        isolated_env = dict(env, APPDATA=str(output / "qa-user-data"), LOCALAPPDATA=str(output / "qa-local-data"))
        checked([exe, "--headless", "--quit-after", "90"], logs / "windows-smoke.log", cwd=folder, env=isolated_env, timeout=60)
        shutil.copy2(ROOT / "README-mobile.txt", folder / "Read Me.txt")
        archive = output / (NAME + "-" + VERSION + "-Windows.zip")
        zip_folder(folder, archive)
        report["artifacts"]["windows"] = dict(artifact(archive), executable=artifact(exe), native_smoke_passed=True)
        write_json(output / "build-manifest.json", report)
    if "web" in platforms:
        folder = output / "web"
        folder.mkdir()
        checked([GODOT, "--headless", "--path", stage, "--export-release", "Web", folder / "index.html"], logs / "web-export.log", env=env)
        for name in ("index.html", "index.js", "index.wasm", "index.pck"):
            if not (folder / name).is_file() or not (folder / name).stat().st_size:
                raise RuntimeError("Missing Web export: " + name)
        empty = output / "pack-check"
        empty.mkdir()
        checked([GODOT, "--headless", "--path", empty, "--script", stage / "tools/verify_pack.gd", "--", folder / "index.pck"], logs / "web-pack.log", env=env)
        archive = output / (NAME + "-" + VERSION + "-Web.zip")
        zip_folder(folder, archive)
        report["artifacts"]["web"] = dict(artifact(archive), single_threaded=True, browser_validation="pending")
    shutil.copy2(ROOT / "README-mobile.txt", output / "README-mobile.txt")
    write_json(output / "build-manifest.json", report)
    print(json.dumps(report, indent=2), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, KeyError) as exc:
        print("Circuit build: " + str(exc), file=sys.stderr)
        sys.exit(1)
