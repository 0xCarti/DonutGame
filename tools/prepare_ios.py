#!/usr/bin/env python3
"""Validate Golden Hour's iOS source handoff or export an unsigned Xcode project.

Requires Python 3.9+ (standard library only). --check works on every platform.
Actual export requires macOS, Xcode, Godot 4.7.2 stable and its export templates.
The tracked project is never imported or modified. Signing stays in Xcode; this
tool does not build, sign, install, archive or upload an app.

Verified against Godot 4.7.2-stable:
https://github.com/godotengine/godot/blob/4.7.2-stable/editor/export/editor_export_platform_apple_embedded.cpp
https://github.com/godotengine/godot/blob/4.7.2-stable/editor/export/editor_export_platform_apple_embedded.h
https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html
"""

import argparse
import configparser
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import struct
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
ENGINE_VERSION = "4.7.2.stable"
PRESET_NAME = "iOS"
PROJECT_NAME = "GoldenHour"
SOURCE_DIRS = ("assets", "scenes", "scripts", "docs/licenses")
LICENSES = ("docs/licenses/Godot-LICENSE.txt", "docs/licenses/Godot-COPYRIGHT.txt",
            "assets/fonts/OFL.txt")
MOBILE_SCRIPTS = ("scripts/mobile_input.gd", "scripts/mobile_controls.gd",
                  "scripts/mobile_quality.gd")
PRIVATE_SUFFIXES = {".p12", ".p8", ".pfx", ".pem", ".key", ".keystore",
                    ".mobileprovision", ".provisionprofile"}
PROVISION_KEYS = tuple("application/" + name + "_" + mode
                       for name in ("provisioning_profile_uuid", "provisioning_profile_specifier")
                       for mode in ("debug", "release"))


class HandoffError(Exception):
    """An actionable validation/export error, without an incidental traceback."""


def config_text(text):
    parser = configparser.ConfigParser(interpolation=None, strict=True)
    parser.optionxform = str
    try:
        parser.read_string(text)
    except configparser.Error as exc:
        raise HandoffError("Invalid Godot configuration: " + str(exc)) from exc
    return parser


def quoted(value):
    try:
        result = json.loads(value)
    except (ValueError, TypeError) as exc:
        raise HandoffError("Expected a quoted Godot string: " + str(value)) from exc
    if not isinstance(result, str):
        raise HandoffError("Expected a quoted Godot string: " + str(value))
    return result


def packed_strings(value):
    if not value.startswith("PackedStringArray(") or not value.endswith(")"):
        raise HandoffError("Expected PackedStringArray export_files")
    try:
        result = json.loads("[" + value[len("PackedStringArray("):-1] + "]")
    except ValueError as exc:
        raise HandoffError("Invalid export_files list") from exc
    if any(not isinstance(item, str) for item in result):
        raise HandoffError("export_files must contain only resource paths")
    return result


def preset_section(config, name):
    matches = [section for section in config.sections()
               if re.fullmatch(r"preset\.\d+", section)
               and quoted(config[section].get("name", '""')) == name]
    if len(matches) != 1:
        raise HandoffError("Expected exactly one export preset named " + name)
    section = matches[0]
    if section + ".options" not in config:
        raise HandoffError("Missing export options for " + name)
    return section


def is_inside(path, parent):
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def source_path(root, resource):
    relative = resource[6:] if resource.startswith("res://") else resource
    pure = PurePosixPath(relative)
    if (not relative or "\\" in relative or pure.is_absolute()
            or any(part in ("..", ".") for part in relative.split("/"))):
        raise HandoffError("Unsafe resource path: " + resource)
    path = root.joinpath(*pure.parts)
    if not is_inside(path.resolve(), root.resolve()):
        raise HandoffError("Resource escapes the project: " + resource)
    if not any(relative.startswith(folder + "/") for folder in SOURCE_DIRS):
        raise HandoffError("Resource is outside the handoff source folders: " + resource)
    if not path.is_file() or path.stat().st_size == 0:
        raise HandoffError("Missing or empty source resource: " + resource)
    return path


def validate_icon(path):
    """Inspect PNG chunks without an imaging dependency; require no alpha channel."""
    data = path.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise HandoffError("The iOS base icon must be a PNG: " + str(path))
    offset = 8
    header = None
    ended = False
    while offset + 12 <= len(data):
        size = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        if offset + size + 12 > len(data):
            raise HandoffError("Truncated iOS icon PNG")
        if kind == b"IHDR":
            if size != 13:
                raise HandoffError("Invalid iOS icon PNG header")
            header = struct.unpack(">IIBBBBB", data[offset + 8:offset + 21])
        if kind == b"tRNS":
            raise HandoffError("The iOS icon must not contain transparency")
        if kind == b"IEND":
            ended = True
            break
        offset += size + 12
    if not header or not ended:
        raise HandoffError("Incomplete iOS icon PNG")
    if header[:2] != (1024, 1024) or header[3] not in (0, 2):
        raise HandoffError("The iOS icon must be 1024x1024 RGB/grayscale PNG without alpha")


def source_files(root):
    """Only stage the game's source roots, never a whole developer checkout."""
    result = [Path("project.godot")]
    for folder in SOURCE_DIRS:
        directory = root / folder
        if not directory.is_dir() or directory.is_symlink():
            raise HandoffError("Missing or linked source directory: " + folder)
        for path in sorted(directory.rglob("*")):
            if path.is_symlink():
                raise HandoffError("Symlinks are not supported in source handoffs: " + str(path))
            if not path.is_file():
                continue
            relative = path.relative_to(root)
            if any(part.startswith(".") or part == "__pycache__" for part in relative.parts):
                continue
            if path.suffix.lower() in PRIVATE_SUFFIXES:
                raise HandoffError("Remove signing/private files from game source: " + str(relative))
            result.append(relative)
    return result


def validate_source(root):
    root = Path(root).resolve()
    project = config_text("[godot_header]\n" + (root / "project.godot").read_text(encoding="utf-8-sig"))
    version = quoted(project["application"]["config/version"])
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise HandoffError("Expected a three-part numeric application version")
    if quoted(project["rendering"].get("renderer/rendering_method.mobile", '""')) != "gl_compatibility":
        raise HandoffError("Handoff currently validates the Compatibility mobile renderer only")
    if project["display"].get("window/handheld/orientation") != "0":
        raise HandoffError("Handoff requires the authored landscape orientation")
    config = config_text((root / "export_presets.cfg").read_text(encoding="utf-8-sig"))
    ios_section = preset_section(config, PRESET_NAME)
    android_section = preset_section(config, "Android")
    preset = config[ios_section]
    options = config[ios_section + ".options"]
    if quoted(preset.get("platform", '""')) != "iOS":
        raise HandoffError("The iOS preset must target the iOS platform")
    if quoted(preset.get("export_filter", '""')) != "resources":
        raise HandoffError("The iOS preset must retain the explicit resource filter")
    resources = packed_strings(preset.get("export_files", ""))
    android_resources = packed_strings(config[android_section].get("export_files", ""))
    if set(resources) != set(android_resources):
        raise HandoffError("iOS export_files must mirror the Android game resource roots")
    if not set("res://" + path for path in MOBILE_SCRIPTS).issubset(resources):
        raise HandoffError("iOS export is missing mobile controller/UI/quality scripts")
    includes = {value.strip() for value in quoted(preset.get("include_filter", '""')).split(",")}
    if not set(LICENSES).issubset(includes):
        raise HandoffError("iOS include_filter must include all engine/font license notices")
    for resource in resources + list(LICENSES):
        source_path(root, resource)
    if options.get("application/export_project_only") != "true":
        raise HandoffError("iOS must use application/export_project_only=true")
    if options.get("architectures/arm64") != "true":
        raise HandoffError("iOS must enable the arm64 architecture")
    for key in ("application/app_store_team_id",) + PROVISION_KEYS:
        if quoted(options.get(key, '""')):
            raise HandoffError("Keep " + key + " blank in the shared preset; configure locally")
    for key, default in (("application/code_sign_identity_debug", "Apple Development"),
                         ("application/code_sign_identity_release", "Apple Distribution")):
        if quoted(options.get(key, '""')) not in ("", default):
            raise HandoffError("Do not commit a personal signing identity: " + key)
    for key in ("custom_template/debug", "custom_template/release"):
        if quoted(options.get(key, '""')):
            raise HandoffError("Use the matching official export templates, not a local template path")
    for key in ("icons/icon_1024x1024", "icons/app_store_1024x1024"):
        resource = quoted(options.get(key, '""'))
        if resource:
            validate_icon(source_path(root, resource))
        elif key == "icons/icon_1024x1024":
            raise HandoffError("Set icons/icon_1024x1024 to the opaque iOS PNG")
    files = source_files(root)
    return {"version": version, "engine_version": ENGINE_VERSION, "resources": len(resources),
            "source_files": len(files), "static_checks_passed": True,
            "native_export_verified": False, "device_test_verified": False}


def validate_team_id(value):
    if not re.fullmatch(r"[A-Z0-9]{10}", value or ""):
        raise HandoffError("--team-id must be your 10-character uppercase Apple Team ID")
    return value


def validate_bundle_id(value):
    if (len(value) > 255 or not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", value)):
        raise HandoffError("--bundle-id must be a reverse-DNS identifier using letters, digits, dots and hyphens")
    return value


def local_preset(root, team_id, bundle_id):
    """Emit only the selected iOS preset; never write back to the checkout."""
    config = config_text((root / "export_presets.cfg").read_text(encoding="utf-8-sig"))
    section = preset_section(config, PRESET_NAME)
    general = dict(config[section])
    options = dict(config[section + ".options"])
    general["export_path"] = '""'
    options["application/app_store_team_id"] = json.dumps(validate_team_id(team_id))
    options["application/bundle_identifier"] = json.dumps(validate_bundle_id(bundle_id))
    options["application/export_project_only"] = "true"
    options["application/delete_old_export_files_unconditionally"] = "false"
    for key in PROVISION_KEYS + ("application/code_sign_identity_debug", "application/code_sign_identity_release"):
        options[key] = '""'
    sections = (("preset.0", general), ("preset.0.options", options))
    return "\n\n".join("[" + name + "]\n" + "\n".join(key + "=" + value for key, value in values.items())
                          for name, values in sections) + "\n"


def stage_source(root, destination, team_id, bundle_id):
    files = source_files(root)
    for relative in files:
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / relative, target)
    (destination / "export_presets.cfg").write_text(local_preset(root, team_id, bundle_id), encoding="utf-8")
    return len(files)


def clean_environment(environ):
    # Exporter accepts these outside the preset; prevent accidental manual signing.
    return {key: value for key, value in environ.items()
            if not key.startswith("GODOT_IOS_PROVISIONING_PROFILE_")}


def checked_process(command, *, cwd=None, env=None, log=None, timeout=60):
    try:
        result = subprocess.run([str(item) for item in command], cwd=cwd, env=env,
                                text=True, encoding="utf-8", errors="replace",
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                timeout=timeout, check=False)
    except (OSError, subprocess.TimeoutExpired) as exc:
        raise HandoffError("Could not complete " + str(command[0]) + ": " + str(exc)) from exc
    output = result.stdout or ""
    if log:
        log.write_text(output, encoding="utf-8")
    if result.returncode or re.search(r"(?m)^\s*(?:SCRIPT ERROR:|ERROR:)", output):
        detail = " See " + str(log) if log else ": " + output.strip()[-1200:]
        raise HandoffError(str(command[0]) + " failed (exit " + str(result.returncode) + ")." + detail)
    return output.strip()


def godot_executable(requested):
    candidate = requested or shutil.which("godot") or "/Applications/Godot.app/Contents/MacOS/Godot"
    path = Path(candidate).expanduser()
    if path.suffix.lower() == ".app":
        path = path / "Contents/MacOS/Godot"
    if not path.is_file():
        resolved = shutil.which(str(candidate))
        if resolved:
            path = Path(resolved)
        else:
            raise HandoffError("Godot was not found; pass --godot /Applications/Godot.app/Contents/MacOS/Godot")
    return path.resolve()


def check_engine_version(value):
    if not re.match(r"^4\.7\.2\.stable(?:\.|$)", value.strip()):
        raise HandoffError("Use Godot 4.7.2 stable and matching export templates; found: " + value.strip())


def prepare_output(root, output):
    output = output.expanduser().resolve()
    if output == root or any(is_inside(output, (root / folder).resolve()) for folder in SOURCE_DIRS):
        raise HandoffError("Choose an output outside the game source folders, such as builds/ios")
    if output.exists() and (not output.is_dir() or any(output.iterdir())):
        raise HandoffError("Output must be a new or empty folder; existing exports are never overwritten: " + str(output))
    output.mkdir(parents=True, exist_ok=True)
    return output


def verify_export(output):
    project = output / (PROJECT_NAME + ".xcodeproj")
    project_file = project / "project.pbxproj"
    pck = output / (PROJECT_NAME + ".pck")
    if not project_file.is_file() or project_file.stat().st_size == 0:
        raise HandoffError("Godot did not produce the expected Xcode project: " + str(project_file))
    if not pck.is_file() or pck.stat().st_size == 0:
        raise HandoffError("Godot did not produce the game PCK: " + str(pck))
    if any(output.glob("*.ipa")) or any(output.glob("*.xcarchive")):
        raise HandoffError("Unexpected signed/archive output; this helper exports project files only")
    return project, pck


def export_project(root, args, report):
    if sys.platform != "darwin":
        raise HandoffError("Xcode export requires macOS with Xcode. Use --check on this computer; run the export command on Hashim's Mac.")
    team_id = validate_team_id(args.team_id)
    config = config_text((root / "export_presets.cfg").read_text(encoding="utf-8-sig"))
    section = preset_section(config, PRESET_NAME)
    bundle_id = validate_bundle_id(args.bundle_id or quoted(config[section + ".options"]["application/bundle_identifier"]))
    godot = godot_executable(args.godot)
    env = clean_environment(os.environ)
    engine_version = checked_process([godot, "--headless", "--version"], env=env)
    check_engine_version(engine_version)
    sdk_path = checked_process(["xcrun", "--sdk", "iphoneos", "--show-sdk-path"], env=env)
    if not Path(sdk_path).is_dir():
        raise HandoffError("The active Xcode installation has no iPhoneOS SDK. Open Xcode and install iOS platform support first.")
    default_output = root / "builds/ios" / report["version"] / (datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + args.configuration)
    output = prepare_output(root, Path(args.output) if args.output else default_output)
    print("Exporting project files into " + str(output), flush=True)
    # No private settings, .godot cache, or generated imports survive in the checkout.
    with tempfile.TemporaryDirectory(prefix="golden-hour-ios-") as directory:
        stage = Path(directory) / "source"
        stage.mkdir()
        stage_source(root, stage, team_id, bundle_id)
        print("Importing the temporary source copy...", flush=True)
        checked_process([godot, "--headless", "--path", stage, "--editor", "--import"],
                        cwd=stage, env=env, log=output / "import.log", timeout=900)
        print("Exporting the Xcode project (no build/sign/upload)...", flush=True)
        checked_process([godot, "--headless", "--path", stage, "--export-" + args.configuration,
                         PRESET_NAME, output / (PROJECT_NAME + ".ipa")],
                        cwd=stage, env=env, log=output / "export.log", timeout=900)
    project, pck = verify_export(output)
    report = dict(report, xcode_project_exported=True, native_export_verified=True, bundle_identifier=bundle_id,
                  export_configuration=args.configuration, godot_version=engine_version,
                  pck_sha256=hashlib.sha256(pck.read_bytes()).hexdigest(),
                  signed=False, built=False, uploaded=False)
    (output / "handoff-result.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("Xcode project exported: " + str(project))
    print("Open it in Xcode, select your team and iPhone, then build/run. For TestFlight, use your paid Apple team and Xcode Archive/Distribute. No iOS build or device test has been performed by this helper.")
    return 0


def main(argv=None, root=ROOT):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="Validate source/preset/icon only; no engine, Mac, signing or output needed.")
    parser.add_argument("--godot", help="Godot 4.7.2 stable executable or .app bundle on macOS.")
    parser.add_argument("--team-id", help="Your 10-character Apple Team ID; required for export, never written to the source preset.")
    parser.add_argument("--bundle-id", help="Your unique reverse-DNS bundle ID; defaults to the iOS preset.")
    parser.add_argument("--configuration", choices=("debug", "release"), default="debug", help="Godot export configuration; both export Xcode project files only (default: debug).")
    parser.add_argument("--output", help="New/empty output folder; defaults to builds/ios/<version>/<timestamp>-<configuration>.")
    args = parser.parse_args(argv)
    try:
        root = Path(root).resolve()
        report = validate_source(root)
        if args.team_id:
            validate_team_id(args.team_id)
        if args.bundle_id:
            validate_bundle_id(args.bundle_id)
        if args.check:
            print(json.dumps(report, indent=2))
            print("Static handoff checks passed. Xcode export, signing, iPhone performance and TestFlight remain unverified.")
            return 0
        return export_project(root, args, report)
    except (HandoffError, OSError, KeyError) as exc:
        print("iOS handoff: " + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
