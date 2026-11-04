# Unity Windows 1.1.0 validation

Validated on 2026-11-04 with the user's activated Unity Personal license.
Unity 6000.3.28f1 (8f082d2fe476), URP 17.3, Windows x64, Direct3D 11.
This records the native Unity edition, not the preserved Godot 1.0.6 campaign.

## Verified results

| Check | Evidence |
| --- | --- |
| Native compilation and packaging | `GH_BUILD Succeeded`, 152,376,951 build bytes; `playtest-reports/unity/build.log` |
| Core simulation | 21 passing scenarios; 12,000 chaotic actions preserve food ownership; `playtest-reports/unity/source-validation.txt` |
| Full native shift | 276 passing assertions; 6 served, $162.50 against $110, 0 missed and 0 wasted in the timed shift |
| Runtime | No exception/error or failed assertion in `playtest-reports/unity/player-approved.log` |
| Rendering performance | 1920 × 1080, average 59.84 FPS, 95th-percentile frame 16.71 ms, vsync enabled; NVIDIA RTX 3060, driver 32.0.16.2101 |
| Menu/UI | 36 checks at 1920 × 1080 and another 36 at 1280 × 720 |
| Imported assets | Native bounds/pivot audit of 18 props; both hand sides, forward axis and arm lengths checked in the player |
| Mini-donut refinement | 65 × 25.754 × 65 mm, 4.88–5.12 mm centre hole; UVs/materials preserved, 17 other FBXs and 72 texture-folder files unchanged; FBX roundtrip dimensions match |

The completed native serving run is stored at
`%USERPROFILE%/AppData/LocalLow/Golden Hour Studio/Golden Hour/Acceptance/20261104-171250/`.
The 1080p UI run is `UIAcceptance/20261104-171245/`; the 720p UI run is
`UIAcceptance/20261104-171613/` under the same player-data folder.
Each contains `result.json` and native screenshots.

The serving harness operates the actual game controller, rendered scene and
physics at real time. It verifies newly produced donuts land before entering
stock; packaging, scooping, pouring, coating and handoff; exact food conservation;
natural arm reach and settled hand-to-grip contact within 3.5 cm; sustained arm
clearance from package interiors; independent heat/feed dials; pause/resume;
loaded-scoop pickup requirements; cancellation during handoff; fire recovery;
rapid tray-shake chaos; customer punch skipping; and the winning end card.
Opening Day lasts 105 seconds. The harness also runs a practice order and
interruption regression before the timed shift.

UI checks use live buttons, sliders, toggles and the EventSystem's pointer
raycasts at button centres. They verify heading bounds, slider fill bounds,
settings changes/restoration, field-guide flow, practice, pause, resume and
return to menu. They invoke button handlers after hit testing; they do not
simulate an entire human mouse session. Automated runs do not save test
preferences, progress or unlocks.

## Visual corrections verified in native captures

FBX facing and pivot corrections restore the fryer front, sugar labels, props
and upright Ferris wheel. Depth-tested signage no longer appears through the
customer. Neutral steel reflections, soft shadows, rough ground and dusk
lighting replace the flat preliminary lighting.

The camera moves with an upright operator body between work positions. Tool
paths stay within arm reach, elbows have stable guides, and moving the packing
mat right clears the larger bucket during shaker pickup and return. The idle
hands rest below the workstation. Hand contact survives pausing and restarting.

The mini donuts have a smoother fried-dough silhouette and small centre hole.
Fire uses animated transparent flame layers anchored to the oil pan. Menu,
settings, guide and end-card headings fit their bounds; slider fills stay inside
their tracks. Native captures of these changes were inspected after testing.

## Distribution and scope

The verified archive is
`builds/unity/releases/20261104-171636-092-bbaceec6-GoldenHour-1.1.0-windows-x64/GoldenHour-1.1.0-windows-x64.zip`
(67,910,345 bytes, 185 verified files). SHA256:
`bcd6ed6266f4e80c78710db0a0f3157c0034e1e45db204fcf3e6385f6c6d4f2d`.
It was extracted into a fresh directory and its player passed the 36 UI checks
at 1600 × 900. See `playtest-reports/unity/player-from-zip.log`.

Run `tools/unity/package_windows.ps1` with passing scene and menu result files.
It stages a new timestamped release under `builds/unity/releases`, includes
runtime files, Quick Start, font and Unity package notices, asset provenance,
validation results and a per-file SHA256 manifest. Burst debug folders are
excluded. It verifies every ZIP file against the staged hashes and writes
`VERIFIED.json` plus the archive checksum; existing releases are not overwritten.

This edition contains one fairground level, Practice and unlockable After Hours.
It has one original stylized customer model. Settings, best streak and the
unlock persist; interrupted shifts restart from the beginning. The Godot
campaign and saves remain separate and untouched.

These checks establish a working native Windows build on this machine. They
do not establish broad hardware compatibility, human balance/accessibility
approval or commercial store certification. Steam, iOS, Android, purchases,
cosmetics and additional venues remain deferred as agreed.
