"""Bounded native Android QA commands; never clears emulator or application data."""
from __future__ import annotations
import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
ADB = Path.home() / ".cache/donutsgame/android/sdk/platform-tools/adb.exe"
PACKAGE = "com.goldenhourgame.minidonuts"


def adb(*args: str, binary: bool = False) -> bytes | str:
    result = subprocess.run([str(ADB), "-s", "emulator-5554", *args],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60, check=True)
    return result.stdout if binary else result.stdout.decode("utf-8", errors="replace")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["screenshot", "tap", "swipe", "key", "launch", "logs", "info"])
    parser.add_argument("arguments", nargs="*")
    args = parser.parse_args()
    values = args.arguments
    if args.command == "screenshot":
        name = values[0]
        if not name.startswith("1.2.0-") or Path(name).name != name:
            parser.error("Use one basename beginning 1.2.0-")
        target = ROOT / "playtest-reports/android" / (name + ".png")
        target.parent.mkdir(parents=True, exist_ok=True)
        image = adb("exec-out", "screencap", "-p", binary=True)
        if not image.startswith(b"\x89PNG\r\n\x1a\n"):
            raise RuntimeError("Android screencap did not return PNG bytes")
        target.write_bytes(image)
        print(target)
    elif args.command == "tap":
        print(adb("shell", "input", "tap", str(int(values[0])), str(int(values[1]))))
    elif args.command == "swipe":
        print(adb("shell", "input", "swipe", *[str(int(value)) for value in values]))
    elif args.command == "key":
        print(adb("shell", "input", "keyevent", values[0]))
    elif args.command == "launch":
        print(adb("shell", "am", "start", "-n", PACKAGE + "/com.godot.game.GodotAppLauncher"))
    elif args.command == "logs":
        pid = adb("shell", "pidof", PACKAGE).strip()
        if not pid:
            raise RuntimeError("Game process is not running")
        target = ROOT / "playtest-reports/android/1.2.0-native-logcat.txt"
        target.write_text(adb("logcat", "-d", "--pid=" + pid), encoding="utf-8")
        print(target)
    elif args.command == "info":
        print(adb("shell", "dumpsys", "activity", "activities"))


if __name__ == "__main__":
    main()
