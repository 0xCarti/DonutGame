# Build Golden Hour

Godot is the active development project. Android **1.0.7** uses the separate
setup and release pipeline documented in [ANDROID.md](ANDROID.md):

```powershell
python tools/setup_android_toolchain.py
python tools/build_android.py
```

That path produces a signed ARMv7 + ARM64 + x86_64 APK using a private signing key outside
the repository. APK/package checks and physical-phone validation are separate;
phone installation, touch usability, performance, and lifecycle validation are
still pending. The Unity Windows **1.1.0** project and package remain preserved;
their independent build entry point is `tools/unity/build_windows.ps1`.

For an iPhone demo, use [IOS_HANDOFF.md](IOS_HANDOFF.md). The iOS helper exports
an Xcode project on macOS using signing identifiers supplied locally. Xcode
builds, signs, and installs it; TestFlight upload remains a separate manual step.
Run `python3 tools/prepare_ios.py --check` for source checks on any platform.

## Godot Windows and Web

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
actual-action pacing, controller/world gag integration, fire lifecycle, display quality and audio verification, exports Windows and Web sequentially, packages their required files and full
license notices, and writes separate ZIPs plus SHA256 hashes under
`builds/releases/`. Native engine helper processes run without visible windows;
the script does not launch an interactive game.

Build logs are under `builds/logs/`. Each packaging operation uses a fresh staging
directory; existing builds, release archives, and saves are never deleted. All
output paths are resolved and checked to stay within this workspace. Windows exports live under `builds/windows/<version>/` and browser exports under `builds/web/<version>/` so a new release can be built while an earlier version is open. A
`builds/.gdignore` file keeps generated artifacts out of Godot's import scan.

The script stops on failed checks, missing files, an engine version mismatch,
or export errors. Passing automated checks does not replace visual and browser
playtesting. Android is handled by `tools/build_android.py`, not this PowerShell
pipeline. iOS project export uses `tools/prepare_ios.py`; no pipeline submits to
an app store or performs Apple signing automatically.

The original `build_playtest.ps1` belongs to the historical Idea 1 prototype.
Use the source from that release when rebuilding it; the current project and
export configuration select Idea 2.

## Asset reproduction and notices

The current HD surface maps and authored art are reproduced with:

```powershell
python tools/generate_surface_detail.py
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
warning, ambience and 32-bar evening theme assets. `python tools/generate_gag_audio.py` recreates eight original slapstick cues. `python tools/download_godot_licenses.py` refreshes vendored
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

The Windows and Web presets explicitly select runtime resources, including all
28 required WAV files. Godot's selected-resource export did not discover the WAV
dependencies of selected GDScript files in this project, so add new runtime audio
to the relevant preset root lists, including Android and iOS when shared. The Windows/Web
build mounts each exported pack from an isolated empty project
and verifies required resources exist and historical game/test resources do not.

The Web preset uses single-threaded WebAssembly and retains desktop texture
compression. The project now enables ETC2/ASTC importing for native mobile
exports. See the Android and iOS guides for those presets, bundled notices,
and signing requirements; native mobile support does not imply browser testing
on phones.

## Native package verification

After packaging, select the exact Windows ZIP for a fresh extraction, hash and
version verification, isolated native smoke run, and save-fingerprint comparison:

```powershell
pwsh -File tools/verify_windows_package.ps1 -ZipPath 'builds/releases/<exact-Windows-release.zip>'
```

The verifier preserves previous extraction and evidence directories. Rendering
probes are `tools/probe_display_quality.gd` and `tools/probe_fire_performance.gd`;
they use test mode and never save player progress. The original HD material
generator requires NumPy and Pillow.
