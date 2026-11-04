"""Verify and install the Windows x64 and Web templates from an official archive.

Usage: python tools/install_godot_templates.py [path/to/export_templates.tpz]
The archive stays in the user's cache; it is never copied into the game repo.
"""

from hashlib import file_digest, sha256
import os
from pathlib import Path
import sys
from zipfile import ZipFile


VERSION = "4.7.2.stable"
# Official GitHub release asset digest, verified on 2026-11-04.
EXPECTED_SHA256 = "f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011"
ARCHIVE = (Path(sys.argv[1]) if len(sys.argv) > 1 else
           Path.home() / ".cache/donutsgame/godot/Godot_v4.7.2-stable_export_templates.tpz")
DESTINATION = Path(os.environ["APPDATA"]) / "Godot/export_templates" / VERSION


def main():
    with ARCHIVE.open("rb") as source:
        digest = file_digest(source, "sha256").hexdigest()
    if digest != EXPECTED_SHA256:
        raise RuntimeError(f"Official archive checksum mismatch: {digest}")
    print(f"Archive SHA256 verified: {digest}")
    with ZipFile(ARCHIVE) as archive:
        version = archive.read("templates/version.txt").decode().strip()
        if version != VERSION:
            raise RuntimeError(f"Unexpected template version: {version}")
        DESTINATION.mkdir(parents=True, exist_ok=True)
        for member in archive.namelist():
            filename = Path(member).name
            wanted = (filename == "version.txt" or filename.startswith("web_") or
                      (filename.startswith("windows_") and "x86_64" in filename))
            if not wanted or not member.startswith("templates/"):
                continue
            content = archive.read(member)
            destination = DESTINATION / filename
            if destination.exists() and sha256(destination.read_bytes()).digest() != sha256(content).digest():
                raise RuntimeError(f"Refusing to overwrite a different existing template: {destination}")
            destination.write_bytes(content)
            print(f"Installed {filename} ({len(content):,} bytes)")
    print(f"Template directory: {DESTINATION}")


if __name__ == "__main__":
    main()
