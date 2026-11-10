"""Small, dependency-free release helpers shared by Windows and Mac builds."""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import subprocess
import tarfile

VERSION = "0.1.1"
BUILD = "101"
PACKAGE = "com.goldenhourgame.circuit"
NAME = "GoldenHourCircuit"
LICENSES = ("docs/licenses/Godot-LICENSE.txt", "docs/licenses/Godot-COPYRIGHT.txt", "docs/licenses/ASSET-PROVENANCE.txt", "docs/licenses/ART-VISUAL-UPDATE.txt", "assets/fonts/OFL.txt")
PRIVATE = {".p12", ".p8", ".pfx", ".pem", ".key", ".keystore", ".mobileprovision"}
FLAGS = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0


def digest(path):
    result = hashlib.sha256()
    with Path(path).open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def write_json(path, value):
    Path(path).write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def checked(command, log, *, cwd=None, env=None, timeout=900):
    log = Path(log)
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("w", encoding="utf-8") as output:
        result = subprocess.run([str(arg) for arg in command], cwd=cwd, env=env,
                                stdout=output, stderr=subprocess.STDOUT,
                                timeout=timeout, creationflags=FLAGS)
    content = log.read_text(encoding="utf-8", errors="replace")
    if result.returncode or re.search(r"(?m)^\s*(SCRIPT ERROR:|ERROR:|FAIL:)", content):
        raise RuntimeError(f"Failed {log.name} (exit {result.returncode}); inspect {log}")
    print("Passed: " + log.name, flush=True)
    return content


def new_revision(base):
    base = Path(base).resolve()
    base.mkdir(parents=True, exist_ok=True)
    for number in range(1, 10000):
        path = base / ("r" + str(number))
        try:
            path.mkdir()
            return path
        except FileExistsError:
            continue
    raise RuntimeError("Too many release revisions")


def source_files(root):
    files = [root / "project.godot", root / "export_presets.cfg", root / "README-mobile.txt"]
    for name in ("assets", "scenes", "scripts", "docs/licenses", "tests", "tools"):
        folder = root / name
        for path in sorted(folder.rglob("*")):
            if path.is_symlink():
                raise RuntimeError("Source links are unsupported: " + str(path))
            if not path.is_file() or any(p.startswith(".") or p == "__pycache__" for p in path.relative_to(root).parts):
                continue
            if path.suffix in PRIVATE:
                raise RuntimeError("Private material must remain outside source: " + str(path))
            files.append(path)
    return sorted(set(files))


def validate_source(root):
    project = (root / "project.godot").read_text(encoding="utf-8-sig")
    for required in [f'config/version="{VERSION}"', 'config/use_custom_user_dir=true',
                     'config/custom_user_dir_name="GoldenHourCircuit"', 'window/handheld/orientation=1']:
        if required not in project.replace(" = ", "="):
            raise RuntimeError("Missing required isolated mobile setting: " + required)
    for path in LICENSES:
        if not (root / path).is_file():
            raise RuntimeError("Missing license notice: " + path)
    preset = (root / "export_presets.cfg").read_text(encoding="utf-8")
    for required in ['variant/thread_support=false', 'package/unique_name="' + PACKAGE + '"',
                     f'version/code={BUILD}', f'version/name="{VERSION}"',
                     f'application/file_version="{VERSION}.0"', f'application/product_version="{VERSION}.0"',
                     f'application/short_version="{VERSION}"', f'application/version="{BUILD}"',
                     'application/bundle_identifier="' + PACKAGE + '"']:
        if required not in preset:
            raise RuntimeError("Unexpected platform identity or configuration: " + required)
    if "stand_main" in project or "minidonuts" in preset:
        raise RuntimeError("The original game's identity leaked into Circuit")


def stage_source(root, stage):
    stage.mkdir()
    for path in source_files(root):
        relative = path.relative_to(root)
        target = stage / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, target)


def snapshot(stage, output):
    paths = source_files(stage)
    manifest = {"game": "Golden Hour Circuit", "version": VERSION,
                "files": {path.relative_to(stage).as_posix(): digest(path) for path in paths}}
    write_json(output / "source-manifest.json", manifest)
    archive = output / (NAME + "-" + VERSION + "-source.tar.gz")
    with tarfile.open(archive, "x:gz") as bundle:
        for path in paths:
            bundle.add(path, arcname=path.relative_to(stage).as_posix(), recursive=False)
        bundle.add(output / "source-manifest.json", arcname="source-manifest.json", recursive=False)
    return {"file": archive.name, "sha256": digest(archive), "files": len(paths)}


def artifact(path):
    return {"file": path.name, "bytes": path.stat().st_size, "sha256": digest(path)}
