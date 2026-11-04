"""Source/helper regression tests; no Godot, Xcode, account or network required.

Run: python3 -m unittest discover -s tests -p test_ios_handoff.py -v
These tests do not prove that an iOS project compiles or runs on an iPhone.
"""

import argparse
import contextlib
import hashlib
import importlib.util
import io
import json
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import zlib


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("prepare_ios", ROOT / "tools/prepare_ios.py")
handoff = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(handoff)


def png(width=1024, height=1024, color=2):
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    channels = 4 if color == 6 else 3
    pixels = (b"\0" + b"\xff" * width * channels) * height
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, color, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(pixels)) + chunk(b"IEND", b""))


class HandoffTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="gh-ios-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "source"
        self.root.mkdir()
        resources = ["res://scenes/stand_main.tscn"] + ["res://" + path for path in handoff.MOBILE_SCRIPTS]
        for resource in resources + list(handoff.LICENSES):
            path = self.root / resource.removeprefix("res://")
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("fixture source\n", encoding="utf-8")
        self.icon = self.root / "assets/ios/app_icon.png"
        self.icon.parent.mkdir(parents=True, exist_ok=True)
        self.icon.write_bytes(png())
        (self.root / "project.godot").write_text(
            'config_version=5\n[application]\nconfig/version="1.0.7"\n'
            '[display]\nwindow/handheld/orientation=0\n'
            '[rendering]\nrenderer/rendering_method.mobile="gl_compatibility"\n', encoding="utf-8")
        common = ('export_filter="resources"\nexport_files=PackedStringArray(' +
                  ", ".join(json.dumps(item) for item in resources) + ')\ninclude_filter=' +
                  json.dumps(",".join(handoff.LICENSES)) + '\nexport_path=""\n')
        self.preset = self.root / "export_presets.cfg"
        self.preset.write_text(
            '[preset.0]\nname="Android"\nplatform="Android"\n' + common +
            '\n[preset.0.options]\nversion/code=107\n\n'
            '[preset.1]\nname="iOS"\nplatform="iOS"\n' + common +
            '\n[preset.1.options]\napplication/export_project_only=true\n'
            'application/app_store_team_id=""\napplication/bundle_identifier="com.example.goldenhourdemo"\n'
            'architectures/arm64=true\nicons/icon_1024x1024="res://assets/ios/app_icon.png"\n'
            'icons/app_store_1024x1024="res://assets/ios/app_icon.png"\n', encoding="utf-8")

    def replace(self, old, new):
        self.preset.write_text(self.preset.read_text(encoding="utf-8").replace(old, new), encoding="utf-8")

    def test_static_check_needs_no_tools_and_writes_nothing(self):
        before = {str(path.relative_to(self.root)): hashlib.sha256(path.read_bytes()).hexdigest()
                  for path in self.root.rglob("*") if path.is_file()}
        with mock.patch.object(subprocess, "run", side_effect=AssertionError("must not launch tools")):
            with contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(handoff.main(["--check"], self.root), 0)
        self.assertIn('"native_export_verified": false', output.getvalue())
        after = {str(path.relative_to(self.root)): hashlib.sha256(path.read_bytes()).hexdigest()
                 for path in self.root.rglob("*") if path.is_file()}
        self.assertEqual(before, after)

    def test_resource_root_drift_fails(self):
        text = self.preset.read_text(encoding="utf-8")
        marker = 'export_files=PackedStringArray("res://scenes/stand_main.tscn", '
        self.preset.write_text(text.replace(marker, 'export_files=PackedStringArray(', 1), encoding="utf-8")
        with self.assertRaisesRegex(handoff.HandoffError, "mirror"):
            handoff.validate_source(self.root)

    def test_missing_mobile_root_fails_even_if_presets_match(self):
        self.replace(', "res://scripts/mobile_input.gd"', "")
        with self.assertRaisesRegex(handoff.HandoffError, "missing mobile"):
            handoff.validate_source(self.root)

    def test_missing_resource_fails_before_export(self):
        (self.root / "scenes/stand_main.tscn").unlink()
        with self.assertRaisesRegex(handoff.HandoffError, "Missing or empty"):
            handoff.validate_source(self.root)

    def test_missing_license_filter_fails(self):
        self.replace("docs/licenses/Godot-COPYRIGHT.txt,", "")
        with self.assertRaisesRegex(handoff.HandoffError, "license notices"):
            handoff.validate_source(self.root)

    def test_project_only_is_mandatory(self):
        self.replace("application/export_project_only=true", "application/export_project_only=false")
        with self.assertRaisesRegex(handoff.HandoffError, "export_project_only"):
            handoff.validate_source(self.root)

    def test_committed_signing_data_rejected(self):
        for key in ("application/app_store_team_id",) + handoff.PROVISION_KEYS:
            with self.subTest(key=key):
                original = self.preset.read_text(encoding="utf-8")
                text = original.replace('application/app_store_team_id=""\n', "") if key.endswith("team_id") else original
                self.preset.write_text(text + key + '="PRIVATE1234"\n', encoding="utf-8")
                with self.assertRaisesRegex(handoff.HandoffError, "blank"):
                    handoff.validate_source(self.root)
                self.preset.write_text(original, encoding="utf-8")

    def test_invalid_icons_rejected(self):
        for content in (png(512, 512), png(color=6), b"not PNG", png()[:26]):
            with self.subTest(length=len(content)):
                self.icon.write_bytes(content)
                with self.assertRaises(handoff.HandoffError):
                    handoff.validate_source(self.root)

    def test_path_traversal_and_outside_source_are_rejected(self):
        for path in ("res://../secret", "res:///etc/passwd", "res://assets/../../secret",
                     "res://assets\\secret", "res://tools/something.py"):
            with self.subTest(path=path), self.assertRaises(handoff.HandoffError):
                handoff.source_path(self.root, path)

    def test_team_and_bundle_validation_reject_injection(self):
        self.assertEqual(handoff.validate_team_id("AB12CD34EF"), "AB12CD34EF")
        self.assertEqual(handoff.validate_bundle_id("com.example.golden-hour"), "com.example.golden-hour")
        for team in ("", "Hashim", "abc1234567", "AB12CD34EF\n", 'AB12CD34E"'):
            with self.subTest(team=team), self.assertRaises(handoff.HandoffError):
                handoff.validate_team_id(team)
        for bundle in ("", "com..demo", "com.demo.*", "com.demo_app", "com.example\n", 'com.example"'):
            with self.subTest(bundle=bundle), self.assertRaises(handoff.HandoffError):
                handoff.validate_bundle_id(bundle)

    def test_staging_does_not_copy_checkout_builds_or_credentials(self):
        for name in ("builds/old.ipa", "unity/secret.p12", ".godot/cache", ".git/config",
                     "tests/test.gd", "tools/secret.key", "credentials.p8"):
            path = self.root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("not part of source", encoding="utf-8")
        before = self.preset.read_bytes()
        stage = Path(self.temp.name) / "stage"
        stage.mkdir()
        handoff.stage_source(self.root, stage, "AB12CD34EF", "com.example.hashim")
        self.assertEqual(before, self.preset.read_bytes())
        for name in ("builds", "unity", ".godot", ".git", "tests", "tools", "credentials.p8"):
            self.assertFalse((stage / name).exists())
        for name in handoff.LICENSES:
            self.assertTrue((stage / name).is_file())
        local = handoff.config_text((stage / "export_presets.cfg").read_text(encoding="utf-8"))
        self.assertEqual(local.sections(), ["preset.0", "preset.0.options"])
        self.assertEqual(local["preset.0.options"]["application/app_store_team_id"], '"AB12CD34EF"')
        self.assertEqual(local["preset.0.options"]["application/bundle_identifier"], '"com.example.hashim"')
        self.assertEqual(local["preset.0.options"]["application/export_project_only"], "true")

    def test_private_files_inside_source_fail_closed(self):
        (self.root / "assets/signing.p12").write_bytes(b"private fixture")
        with self.assertRaisesRegex(handoff.HandoffError, "private files"):
            handoff.validate_source(self.root)

    def test_inherited_provisioning_is_removed_from_child_environment(self):
        original = {"PATH": "/bin", "GODOT_IOS_PROVISIONING_PROFILE_UUID_DEBUG": "secret",
                    "GODOT_IOS_PROVISIONING_PROFILE_SPECIFIER_RELEASE": "secret"}
        self.assertEqual(handoff.clean_environment(original), {"PATH": "/bin"})
        self.assertIn("GODOT_IOS_PROVISIONING_PROFILE_UUID_DEBUG", original)

    def test_actual_export_fails_gracefully_on_windows_without_launching(self):
        with mock.patch.object(sys, "platform", "win32"), mock.patch.object(subprocess, "run") as run:
            with contextlib.redirect_stderr(io.StringIO()) as error:
                self.assertEqual(handoff.main(["--team-id", "AB12CD34EF"], self.root), 1)
        run.assert_not_called()
        self.assertIn("requires macOS", error.getvalue())
        self.assertFalse((self.root / "builds").exists())

    def test_wrong_engine_version_rejected(self):
        handoff.check_engine_version("4.7.2.stable.official.abc123")
        for version in ("4.7.1.stable.official", "4.7.2.rc1", "4.7.2.stablefake", "4.8.stable"):
            with self.subTest(version=version), self.assertRaises(handoff.HandoffError):
                handoff.check_engine_version(version)

    def test_godot_app_bundle_path(self):
        app = Path(self.temp.name) / "Godot.app"
        binary = app / "Contents/MacOS/Godot"
        binary.parent.mkdir(parents=True)
        binary.write_bytes(b"fixture")
        self.assertEqual(handoff.godot_executable(str(app)), binary.resolve())

    def test_output_preserves_existing_files_and_source(self):
        existing = self.root / "builds/ios/old"
        existing.mkdir(parents=True)
        artifact = existing / "GoldenHour.pck"
        artifact.write_bytes(b"existing")
        for output in (existing, self.root, self.root / "assets/new-export"):
            with self.subTest(output=output), self.assertRaises(handoff.HandoffError):
                handoff.prepare_output(self.root, output)
        self.assertEqual(artifact.read_bytes(), b"existing")

    def test_nonzero_and_godot_error_exit_zero_both_fail(self):
        log = Path(self.temp.name) / "process.log"
        for code, output in ((1, "failed"), (0, "SCRIPT ERROR: invalid script"), (0, "ERROR: missing template")):
            result = subprocess.CompletedProcess(["godot"], code, output)
            with self.subTest(code=code, output=output), mock.patch.object(subprocess, "run", return_value=result):
                with self.assertRaises(handoff.HandoffError):
                    handoff.checked_process(["godot"], log=log)
                self.assertEqual(log.read_text(encoding="utf-8"), output)

    def test_success_requires_both_project_and_pck(self):
        output = Path(self.temp.name) / "export"
        output.mkdir()
        with self.assertRaises(handoff.HandoffError):
            handoff.verify_export(output)
        project = output / "GoldenHour.xcodeproj"
        project.mkdir()
        (project / "project.pbxproj").write_text("fixture", encoding="utf-8")
        with self.assertRaises(handoff.HandoffError):
            handoff.verify_export(output)
        (output / "GoldenHour.pck").write_bytes(b"fixture")
        self.assertEqual(handoff.verify_export(output)[0], project)
        (output / "GoldenHour.ipa").write_bytes(b"unexpected")
        with self.assertRaisesRegex(handoff.HandoffError, "Unexpected"):
            handoff.verify_export(output)

    def test_mac_workflow_uses_temp_copy_and_only_godot_project_export(self):
        """Mock process boundary verifies orchestration, not real Apple compatibility."""
        output = Path(self.temp.name) / "xcode"
        sdk = Path(self.temp.name) / "iPhoneOS.sdk"
        sdk.mkdir()
        godot = Path(self.temp.name) / "Godot"
        godot.write_bytes(b"fixture")
        before = self.preset.read_bytes()
        calls = []
        staged = []

        def process(command, **kwargs):
            calls.append(command)
            if "--version" in command:
                return "4.7.2.stable.official.fixture"
            if command[0] == "xcrun":
                return str(sdk)
            stage = command[command.index("--path") + 1]
            staged.append(stage)
            self.assertNotEqual(stage, self.root)
            self.assertTrue((stage / "docs/licenses/Godot-LICENSE.txt").is_file())
            if "--export-debug" in command:
                self.assertEqual(command[-2:], ["iOS", output / "GoldenHour.ipa"])
                (output / "GoldenHour.xcodeproj").mkdir()
                (output / "GoldenHour.xcodeproj/project.pbxproj").write_text("fixture", encoding="utf-8")
                (output / "GoldenHour.pck").write_bytes(b"fixture game")
            return "OK"

        args = ["--godot", str(godot), "--team-id", "AB12CD34EF", "--output", str(output)]
        with mock.patch.object(sys, "platform", "darwin"), mock.patch.object(handoff, "checked_process", side_effect=process):
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(handoff.main(args, self.root), 0)
        self.assertEqual(before, self.preset.read_bytes())
        self.assertTrue(staged)
        self.assertTrue(all(not path.exists() for path in staged))
        self.assertEqual(len(calls), 4)
        self.assertFalse(any(command[0] in ("xcodebuild", "codesign", "xcrun altool") for command in calls))
        report = json.loads((output / "handoff-result.json").read_text(encoding="utf-8"))
        self.assertTrue(report["xcode_project_exported"])
        self.assertTrue(report["native_export_verified"])
        for key in ("signed", "built", "uploaded", "device_test_verified"):
            self.assertFalse(report[key])


class RepositoryHandoffTest(unittest.TestCase):
    def test_current_repository_static_handoff(self):
        report = handoff.validate_source(ROOT)
        self.assertTrue(report["static_checks_passed"])
        self.assertGreater(report["resources"], 3)
        self.assertFalse(report["device_test_verified"])


if __name__ == "__main__":
    unittest.main()
