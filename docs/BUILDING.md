# Rebuild the playtest

Use PowerShell 7 on Windows and Godot **4.7.2 stable** with its matching Windows
x64 and Web export templates. From the repository root:

```powershell
pwsh -File tools/build_playtest.ps1
```

The script finds `godot` or `godot4` on PATH, falling back to the verified local
cache at `C:/Users/bryce/.cache/donutsgame/godot/`. You can select an exact editor:

```powershell
pwsh -File tools/build_playtest.ps1 -GodotPath 'C:/path/to/Godot_v4.7.2-stable_win64_console.exe'
```

It imports assets, runs the core regression suite (at least 134 checks), runs
any `tests/*controller*.gd` checks present, and checks the audio module. It then
exports Windows and Web sequentially, packages their required files and full
license notices, and writes separate ZIPs plus SHA256 hashes under
`builds/releases/`. Native engine helper processes run without visible windows;
the script does not launch an interactive game.

Build logs are under `builds/logs/`. Each packaging operation uses a fresh staging
directory; existing builds, release archives, and saves are never deleted. All
output paths are resolved and checked to stay within this workspace. A
`builds/.gdignore` file keeps generated artifacts out of Godot's import scan.

The script stops on failed checks, missing files, an engine version mismatch,
or export errors. Passing automated checks does not replace visual and browser
playtesting. Native iOS/Android builds and store submissions are not part of it.

## Asset reproduction and notices

`python tools/generate_audio.py` recreates the original WAV assets with Python's
standard library. `python tools/download_godot_licenses.py` refreshes vendored
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

## Export configuration

The Web preset uses single-threaded WebAssembly. Mobile VRAM compression is off
because this procedural-art build does not enable ETC2/ASTC texture importing.
Godot 4.7.2 rejects a Web export with an empty configuration-error message if the
mobile compression preset is enabled while that project import setting is off.
Enable both settings together when adding mobile VRAM-compressed textures.
