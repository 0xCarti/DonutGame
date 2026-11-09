#!/usr/bin/env python3
"""Build an unsigned ARM64 Circuit IPA on a Mac; no Apple account is contacted.

--check validates the source on any host. The output must be a fresh directory.
The project is copied before import/export; personal signing settings are never
written to the source and no previous app or release directory is replaced.
"""
from pathlib import Path
import argparse
import json
import os
import plistlib
import re
import shutil
import stat
import struct
import subprocess
import sys
import zipfile
from release_common import (VERSION, BUILD, PACKAGE, NAME, artifact, checked,
                            digest, new_revision, snapshot, stage_source,
                            validate_source, write_json)

ROOT = Path(__file__).resolve().parents[1]


def validate_icon(path):
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise RuntimeError("iOS icon is not PNG")
    offset, header, ended = 8, None, False
    while offset + 12 <= len(data):
        size = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        if offset + size + 12 > len(data):
            raise RuntimeError("Truncated iOS icon")
        if kind == b"IHDR":
            header = struct.unpack(">IIBBBBB", data[offset + 8:offset + 21])
        if kind == b"tRNS":
            raise RuntimeError("iOS icon contains transparency")
        if kind == b"IEND":
            ended = True
            break
        offset += size + 12
    if not ended or not header or header[:2] != (1024, 1024) or header[3] not in (0, 2):
        raise RuntimeError("iOS icon must be an opaque 1024x1024 RGB PNG")


def package_app(output, app, exported_pck, logs):
    plist = plistlib.loads((app / "Info.plist").read_bytes())
    for field, expected in (("CFBundleShortVersionString", VERSION), ("CFBundleVersion", BUILD),
                            ("CFBundleIdentifier", PACKAGE), ("MinimumOSVersion", "15.0")):
        if plist.get(field) != expected:
            raise RuntimeError("Unexpected iOS metadata: " + field)
    orientations = plist.get("UISupportedInterfaceOrientations", [])
    if "UIInterfaceOrientationPortrait" not in orientations:
        raise RuntimeError("Circuit IPA does not declare portrait orientation")
    executable = app / plist["CFBundleExecutable"]
    if not executable.is_file() or not executable.stat().st_mode & stat.S_IXUSR:
        raise RuntimeError("iOS executable is absent or lacks executable permissions")
    architecture = checked(["lipo", "-archs", executable], logs / "ios-architecture.log", timeout=60).strip()
    if architecture != "arm64":
        raise RuntimeError("Unexpected iOS architecture: " + architecture)
    if (app / "embedded.mobileprovision").exists() or (app / "_CodeSignature").exists():
        raise RuntimeError("Unexpected signing artifacts in unsigned app")
    signature = subprocess.run(["codesign", "-dv", str(app)], capture_output=True, text=True, timeout=60)
    (logs / "ios-unsigned.log").write_text(signature.stderr, encoding="utf-8")
    if signature.returncode == 0 or "not signed" not in signature.stderr:
        raise RuntimeError("iOS app was not confirmed unsigned")
    pck = app / (NAME + ".pck")
    if digest(pck) != digest(exported_pck):
        raise RuntimeError("Built app and exported runtime pack differ")
    files = sorted(path for path in app.rglob("*") if path.is_file())
    if any(path.is_symlink() for path in app.rglob("*")):
        raise RuntimeError("Unexpected links in iOS app bundle")
    ipa = output / (NAME + "-" + VERSION + "-iOS-unsigned.ipa")
    prefix = "Payload/" + NAME + ".app/"
    with zipfile.ZipFile(ipa, "x", zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
        for path in files:
            bundle.write(path, prefix + path.relative_to(app).as_posix())
    with zipfile.ZipFile(ipa) as bundle:
        if bundle.testzip() is not None or len(bundle.namelist()) != len(files):
            raise RuntimeError("IPA archive integrity check failed")
        if not ((bundle.getinfo(prefix + plist["CFBundleExecutable"]).external_attr >> 16) & stat.S_IXUSR):
            raise RuntimeError("IPA lost executable permissions")
        import hashlib
        if hashlib.sha256(bundle.read(prefix + NAME + ".pck")).hexdigest() != digest(pck):
            raise RuntimeError("IPA runtime pack differs from the built app")
    return dict(artifact(ipa), bundle_identifier=PACKAGE, version=VERSION, build=BUILD,
                minimum_ios_version="15.0", architecture=architecture, portrait=True,
                signed=False, physical_device_validation="pending", archive_integrity_verified=True,
                executable_permissions_preserved=True, game_pck_sha256=digest(pck))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--godot", default="/Applications/Godot.app/Contents/MacOS/Godot")
    parser.add_argument("--output", help="Fresh/empty output directory; existing exports are never replaced")
    args = parser.parse_args()
    validate_source(ROOT)
    if args.check:
        icon = ROOT / "assets/ios/app_icon.png"
        if icon.exists():
            validate_icon(icon)
        print(json.dumps({"source_checks_passed": True, "icon_present": icon.exists(),
                          "signed": False, "native_build_verified": False}, indent=2))
        return
    if sys.platform != "darwin":
        raise RuntimeError("An actual iPhoneOS build requires the Mac, Xcode, and matching Godot templates")
    godot = Path(args.godot).expanduser()
    if godot.suffix == ".app":
        godot = godot / "Contents/MacOS/Godot"
    if not godot.is_file():
        raise RuntimeError("Godot executable not found: " + str(godot))
    if args.output:
        output = Path(args.output).expanduser().resolve()
        if output == ROOT or ROOT in output.parents:
            raise RuntimeError("iOS output must remain outside the source project")
        if output.exists() and any(output.iterdir()):
            raise RuntimeError("Output is not empty; choose a new revision directory")
        output.mkdir(parents=True, exist_ok=True)
    else:
        output = new_revision(ROOT.parent / "builds/circuit" / VERSION) / "ios"
        output.mkdir()
    logs, stage = output / "logs", output / "source"
    logs.mkdir()
    stage_source(ROOT, stage)
    env = {key: value for key, value in os.environ.items() if not key.startswith("GODOT_IOS_")}
    version = checked([godot, "--headless", "--version"], logs / "engine.log", env=env, timeout=60).strip()
    if not re.match(r"^4\.7\.2\.stable(?:\.|$)", version):
        raise RuntimeError("Use Godot 4.7.2 stable and its exact matching templates")
    checked(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"], logs / "sdk.log", env=env, timeout=60)
    checked([godot, "--headless", "--path", stage, "--script", "res://tools/generate_ios_icon.gd"], logs / "icon.log", env=env)
    validate_icon(stage / "assets/ios/app_icon.png")
    source = snapshot(stage, output)
    # Godot requires a syntactically valid team value even for project-only export.
    # This local placeholder is not a real team and Xcode code signing is disabled.
    preset_path = stage / "export_presets.cfg"
    preset = preset_path.read_text(encoding="utf-8")
    preset = preset.replace('application/app_store_team_id=""', 'application/app_store_team_id="0000000000"')
    preset_path.write_text(preset, encoding="utf-8")
    checked([godot, "--headless", "--path", stage, "--editor", "--import"], logs / "import.log", env=env)
    native = output / "native"
    native.mkdir()
    checked([godot, "--headless", "--path", stage, "--export-release", "iOS", native / (NAME + ".ipa")], logs / "ios-export.log", env=env)
    project, pck = native / (NAME + ".xcodeproj"), native / (NAME + ".pck")
    if not project.is_dir() or not pck.is_file() or any(native.glob("*.ipa")):
        raise RuntimeError("Godot did not produce an isolated Xcode project export")
    pack_root = output / "pack-check"
    pack_root.mkdir()
    checked([godot, "--headless", "--path", pack_root, "--script", stage / "tools/verify_pack.gd", "--", pck], logs / "ios-pack.log", env=env)
    derived = native / "DerivedData"
    checked(["xcodebuild", "-project", project, "-scheme", NAME, "-configuration", "Release", "-sdk", "iphoneos",
             "-destination", "generic/platform=iOS", "-derivedDataPath", derived,
             "CODE_SIGNING_ALLOWED=NO", "CODE_SIGNING_REQUIRED=NO", "CODE_SIGN_IDENTITY=", "DEVELOPMENT_TEAM=", "build"],
            logs / "xcode-build.log", env=env, timeout=1800)
    app = derived / ("Build/Products/Release-iphoneos/" + NAME + ".app")
    report = package_app(output, app, pck, logs)
    report.update(source=source, godot_version=version,
                  xcode_version=checked(["xcodebuild", "-version"], logs / "xcode-version.log", timeout=60).strip(),
                  iphoneos_sdk=checked(["xcrun", "--sdk", "iphoneos", "--show-sdk-version"], logs / "sdk-version.log", timeout=60).strip())
    write_json(output / "build-verification.json", report)
    (output / "SHA256SUMS.txt").write_text(report["sha256"] + "  " + report["file"] + "\n", encoding="utf-8")
    shutil.copy2(ROOT / "README-mobile.txt", output / "README-mobile.txt")
    print(json.dumps(report, indent=2), flush=True)


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, KeyError) as exc:
        print("Circuit iOS build: " + str(exc), file=sys.stderr)
        sys.exit(1)
