"""Bounded native Circuit QA. Never clears app/emulator data or uninstalls apps."""
from pathlib import Path
import argparse
import json
import re
import subprocess
import sys
import tempfile
from release_common import PACKAGE, VERSION, BUILD, digest

SDK = Path.home() / ".cache/donutsgame/android/sdk"
ADB = SDK / "platform-tools/adb.exe"
ROOT = Path(__file__).resolve().parents[1]


def command(args, *, binary=False, timeout=60):
    result = subprocess.run([str(arg) for arg in args], capture_output=True, timeout=timeout,
                            creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    if result.returncode:
        raise RuntimeError(result.stderr.decode("utf-8", errors="replace").strip())
    return result.stdout if binary else result.stdout.decode("utf-8", errors="replace")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--serial", default="emulator-5554")
    parser.add_argument("--output", type=Path, default=ROOT.parent / "playtest-reports/circuit/android")
    parser.add_argument("command", choices=("install", "verify", "launch", "screenshot", "tap", "swipe", "key", "logs", "info"))
    parser.add_argument("arguments", nargs="*")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    values = args.arguments
    adb = lambda *items, **kwargs: command([ADB, "-s", args.serial, *items], **kwargs)

    def fresh(name, suffix):
        if not re.fullmatch(r"[A-Za-z0-9_-]+", name):
            raise RuntimeError("Use an alphanumeric evidence basename")
        path = output / (name + suffix)
        if path.exists():
            raise RuntimeError("Evidence already exists; use a new name: " + str(path))
        return path

    if args.command in ("install", "verify"):
        apk = Path(values[0]).resolve()
        metadata = command([SDK / "build-tools/35.0.1/aapt.exe", "dump", "badging", apk])
        for token in (f"package: name='{PACKAGE}'", f"versionCode='{BUILD}'", f"versionName='{VERSION}'"):
            if token not in metadata:
                raise RuntimeError("APK does not match Circuit's isolated identity/version")
        if args.command == "install":
            print(adb("install", "-r", str(apk), timeout=180))
        remote = adb("shell", "pm", "path", PACKAGE).strip().splitlines()
        if len(remote) != 1 or not remote[0].startswith("package:"):
            raise RuntimeError("Expected one installed Circuit base APK")
        with tempfile.TemporaryDirectory(prefix="circuit-apk-check-") as folder:
            copy = Path(folder) / "installed.apk"
            adb("pull", remote[0][8:], str(copy), timeout=180)
            if digest(copy) != digest(apk):
                raise RuntimeError("Installed APK hash differs from the verified release artifact")
        print(json.dumps({"package": PACKAGE, "installed_sha256_matches": True,
                          "sha256": digest(apk), "serial": args.serial}, indent=2))
    elif args.command == "launch":
        print(adb("shell", "am", "start", "-n", PACKAGE + "/com.godot.game.GodotAppLauncher"))
    elif args.command == "screenshot":
        path = fresh(values[0], ".png")
        png = adb("exec-out", "screencap", "-p", binary=True)
        if not png.startswith(b"\x89PNG\r\n\x1a\n"):
            raise RuntimeError("Android screenshot returned no PNG data")
        path.write_bytes(png)
        print(path)
    elif args.command in ("tap", "swipe"):
        print(adb("shell", "input", args.command, *[str(int(value)) for value in values]))
    elif args.command == "key":
        if len(values) != 1 or not re.fullmatch(r"(?:[0-9]+|KEYCODE_[A-Z0-9_]+)", values[0]):
            raise RuntimeError("Provide one Android key code")
        print(adb("shell", "input", "keyevent", values[0]))
    elif args.command == "logs":
        pid = adb("shell", "pidof", PACKAGE).strip()
        if not pid or not pid.isdigit():
            raise RuntimeError("Circuit process is not running")
        path = fresh(values[0], ".log")
        path.write_text(adb("logcat", "-d", "--pid=" + pid), encoding="utf-8")
        print(path)
    else:
        print(adb("shell", "dumpsys", "package", PACKAGE))
        print(adb("shell", "dumpsys", "activity", "activities"))


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, IndexError) as exc:
        print("Circuit Android QA: " + str(exc), file=sys.stderr)
        sys.exit(1)
