# Build Golden Hour 1.0

Use PowerShell 7 on Windows and Godot **4.7.2 stable** with its matching Windows
x64 and Web export templates. From the repository root:

```powershell
pwsh -File tools/build_stand_playtest.ps1
```

The script finds `godot` or `godot4` on PATH, falling back to the verified local
cache at `C:/Users/bryce/.cache/donutsgame/godot/`. You can select an exact editor:

```powershell
pwsh -File tools/build_stand_playtest.ps1 -GodotPath 'C:/path/to/Godot_v4.7.2-stable_win64_console.exe'
```

The active script accepts version 1.0.x and requires the first-person stand scene.
It imports assets, runs simulation, controller, career, presentation, world,
rigid-body food, physical inventory, chute distribution, hand motion, title-menu,
actual-action pacing and audio verification, exports Windows and Web sequentially, packages their required files and full
license notices, and writes separate ZIPs plus SHA256 hashes under
`builds/releases/`. Native engine helper processes run without visible windows;
the script does not launch an interactive game.

Build logs are under `builds/logs/`. Each packaging operation uses a fresh staging
directory; existing builds, release archives, and saves are never deleted. All
output paths are resolved and checked to stay within this workspace. Windows exports live under `builds/windows/<version>/` and browser exports under `builds/web/<version>/` so a new release can be built while an earlier version is open. A
`builds/.gdignore` file keeps generated artifacts out of Godot's import scan.

The script stops on failed checks, missing files, an engine version mismatch,
or export errors. Passing automated checks does not replace visual and browser
playtesting. Native iOS/Android builds and store submissions are not part of it.

The original `build_playtest.ps1` belongs to the historical Idea 1 prototype.
Use the source from that release when rebuilding it; the current project and
export configuration select Idea 2.

## Asset reproduction and notices

The 1.0.3 authored surface maps are baked with:

```powershell
godot --headless --path . --script res://tools/bake_material_maps.gd
python tools/generate_shaker_labels.py
godot --headless --path . --script res://tools/bake_customer_geometry.gd
```

The original wood and paper base-color images are retained as generated source
art; their complete prompts are in `ART_PROMPTS.json`. Regenerate/import the
normal and roughness maps after changing either base image. Customer mesh
resources must be rebaked after editing their procedural anatomy helpers.
Counter, customer and art integration suites are also mandatory build gates.

`python tools/generate_audio.py` recreates the shared reward WAV assets with Python's
standard library. `python tools/generate_stand_audio.py` recreates the service,
warning, ambience and 32-bar evening theme assets. `python tools/download_godot_licenses.py` refreshes vendored
notices from the exact official **4.7.2-stable** source tag and checks their Git
blob hashes against the official repository API. Normal builds use those local
notices and do not need network access.

The fixed Fredoka font used by the game is generated from the supplied variable
font with fontTools, pinning weight to **550** and width to **100**:

```powershell
python -m fontTools.varLib.instancer assets/fonts/Fredoka.ttf wght=550 wdth=100 -o assets/fonts/Fredoka-Medium.ttf
```

Both the variable source and fixed instance remain under SIL OFL 1.1. Their
complete notice is `assets/fonts/OFL.txt`. See `ASSET_LICENSES.md` for provenance.

The three generated PNG illustrations are source assets and are not regenerated
by a build. Their creation prompts are in `ART_PROMPTS.json`. Sign and packaging
textures use mipmaps for stable rendering in the 3D scene.

## Export configuration

Both presets explicitly select runtime resources, including all 28 required WAV
files. Godot's selected-resource export did not discover the WAV dependencies of
selected GDScript files in this project, so add new runtime audio to both preset
root lists. The build mounts each exported pack from an isolated empty project
and verifies required resources exist and historical game/test resources do not.

The Web preset uses single-threaded WebAssembly. Mobile VRAM compression is off
because this procedural-art build does not enable ETC2/ASTC texture importing.
Godot 4.7.2 rejects a Web export with an empty configuration-error message if the
mobile compression preset is enabled while that project import setting is off.
Enable both settings together when adding mobile VRAM-compressed textures.
