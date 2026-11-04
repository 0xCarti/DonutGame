# Golden Hour 1.0.3 art and geometry validation

Validated 2026-11-04 UTC. Build **20261104-045522-847**.

## Changes

- Mini donuts have an approximately 11.4% smaller outer diameter and a small,
  irregular central opening. A flatter cake profile uses eight radially oriented
  capsule colliders. The same scale is used in the fryer, tray, scoop and package.
- The discard opening is a real aperture in the counter geometry and collision
  surface, with a flush steel rim and a deep dark well. Discarded packages drop
  below the counter; the existing plain-food recovery rules are preserved.
- Kraft bags have thin curved walls, inset side folds, a creased bottom and an
  uneven open rim. Flat bags are folded paper sheets. The printed seal follows
  the front surface instead of floating on a rectangular box.
- Original cream, cinnamon-red and teal shaker labels wrap around brushed metal
  bodies, with outlined lettering, borders and a small mini-donut emblem.
- Six customer variants use sculpted faces, inset eyes and eyelids, shaped hair,
  ears, lips, individual fingers and tailored clothing. Blink and breathing
  animation respects pause and reduced-motion settings. They remain stylized
  characters, with no claim of photorealism.
- Player gloves have shaped palms and wrists, opposing thumbs, articulated
  fingers, rounded fingertips, cuff details and creases. Existing action timing,
  grip placement and fixed-length close-camera arms are preserved.
- Authored wood and kraft-paper color maps have matching normal and roughness
  maps. Mipmaps are enabled; brushed steel has a stronger surface response.

The geometry is original project work. Wood and paper color textures were made
with the built-in image-generation tool; exact prompts are in `ART_PROMPTS.json`.
Label artwork, model baking and associated surface-map generation are
reproducible with the tools listed in `BUILDING.md`.

## Performance and native inspection

Bag construction was measured at about 90.1 ms before caching. The final
prewarmed package scene averages 0.208 ms per instance, with a 1.6 ms first
pickup in the profiling harness. Meshes and materials are shared while nodes,
transforms and hover overlays remain independent.

Customer geometry is baked into a 3.85 MB library of 212 original meshes.
Construction dropped from approximately 650 ms to 10-12 ms after the initial
load; the first measured customer took 40.8 ms. The bake tool is included so
future shape changes can regenerate this runtime resource.

A separate 30-second native stress run passes eight invariants: stock
conservation, unique callbacks, repeated take/return cycles, four scene resets,
no orphan nodes and unchanged player files. At 1280x800 on this RTX 3060 it
measures 56.32 FPS over 1,409 post-warmup samples, with a 23.94 ms 95th-percentile
frame time and a peak of 73 food bodies. Of these frames, 1,099 report focus.
This is a mixed-focus workload, not a controlled 60 FPS certification.
Evidence: `playtest-reports/food-stress-1.0.3.json` and its stdout/stderr logs.

Native rendered captures were inspected for front/back face orientation,
texture mapping, bag fill clearance, label readability and player-view scale.
Capture stderr is empty. Evidence:

- `playtest-reports/stand-art-1.0.3/`: player view, shaker labels, mini-donut tray.
- `playtest-reports/counter-1.0.3/`: counter aperture, deep well and filled bag.
- `playtest-reports/customer-art/`: six variants and close-up portraits.
- `playtest-reports/hand-detail/`: matched before/after glove and action views.

## Release verification

All **1,440 automated gate checks passed**, with zero failures:

| Suite | Checks |
| --- | ---: |
| Simulation and progression | 294 |
| Controller, UI and saves | 221 |
| Shared reward audio mixer | 167 |
| Career profile | 28 |
| Receipt presentation | 24 |
| Stand audio | 148 |
| World and animation | 64 |
| Food physics | 41 |
| Food/controller integration | 46 |
| Chute distribution and tray shake | 72 |
| Title menu | 35 |
| Hand motion | 55 |
| Actual-action pacing | 28 |
| Counter, discard and paper bags | 69 |
| Customer art and runtime geometry | 75 |
| Mini-donut geometry, labels and materials | 73 |

The pipeline imported assets, exported Windows and Web, mounted each resource
pack in an isolated project to verify runtime assets and exclude historical
prototypes/tests, and packaged versioned ZIPs with notices and SHA256 checksums.
Logs: `builds/logs/20261104-045522-847/`.

The Windows ZIP was extracted into a fresh validation directory. The packaged
executable matches the export hash and reports file/product version 1.0.3.0.
Its hidden native smoke run exits 0 in 7.557 seconds, reports `STAND_READY
version=1.0.3` and `STAND_SMOKE_PASS`, and produces empty stderr. All ten
current/legacy run, settings and career primary/backup paths retain their
fingerprints. Evidence: `12-packaged-native-result.json` in the build log folder.

The actual browser export was inspected on a fresh loopback origin at
`http://127.0.0.1:8772/`, preserving the earlier 8771 game. Visible practice
checks cover new materials/models, bag pickup, two scoops and pours, cinnamon
coating, package lift and a completed $22 handoff to the next customer. An
empty-bag discard also clears the package through the recessed opening. Browser
warning/error logs are empty. The title screen reports 1.0.3.

Artifacts:

- `builds/releases/GoldenHour-1.0.3-windows-20261104-045522-847.zip`
- `builds/releases/GoldenHour-1.0.3-web-20261104-045522-847.zip`
- `builds/releases/GoldenHour-1.0.3-20261104-045522-847-SHA256.txt`

Windows ZIP SHA256:

```text
656d3857d12bd5414ad5348e519ed7fc695a9ec8e9c262eedc34f796d2cff22f
```

## Scope

This is an art and geometry update to the offline fairground game. It preserves
the existing campaign and interaction timing. Automated checks and captured
sequences verify implementation and regressions; artistic quality still benefits
from player feedback. Purchases, platform services and additional venues remain
outside this update. Existing release archives and player saves are preserved.
