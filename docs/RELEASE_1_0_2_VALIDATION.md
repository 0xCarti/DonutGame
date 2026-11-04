# Golden Hour 1.0.2 menu and motion validation

Validated 2026-11-04 UTC. Build **20261104-042703-849**.

## Changes

- The title screen uses perforated admission tickets, a pace wristband and a
  career stamp over the warm evening artwork. Continue, practice, onboarding,
  recovery notices, collection, settings and credits remain accessible.
- A hinged stainless chute sweeps over the catch tray. Its visible trough and
  carried donuts use the same physics-clock position. Jams and pause freeze both.
  Restored batches enter with spacing instead of overlapping at the feeder.
- Clicking the tray with empty hands makes the hands grasp its rim, then gently
  shakes the tray and its collision surfaces. Small impulses loosen the pile;
  a cooldown prevents repeated clicks from launching the contents.
- Only the selected heat dial turns. The separate heat indicator still follows
  machine temperature.
- Pickups reach and grip before props leave the counter; eased paths settle at
  each endpoint. The scoop tilts its lip down before releasing donuts. Fingers
  close around handles, and the close-camera arm rig uses fixed-length segments.
  Distant interactions use short, softly faded cuffs to avoid stretched sleeves.
- Orders move to the reachable service ledge before the customer collects them.
  The late campaign shifts now last 150 and 155 seconds to accommodate the
  longer interaction timings; quotas and rewards are unchanged.

## Automated gates

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
| Title menu, headless | 35 |
| Hand motion | 38 |
| Actual-action pacing | 28 |

All **1,206 gate checks passed**, with zero failures. The build stops if any gate
fails. Logs are under
`builds/logs/20261104-042703-849/`.

Chute tests cover normal and maximum cadence: all 24 and all 35 donuts remain
in a partly filled tray without premature waste. Full 36- and 60-donut trays
produce the expected physical overflow. A six-donut restored batch has at least
0.340 m between release centers and 0.367 seconds between releases; donut
diameter is about 0.315 m. Shake checks retain 24/24 and 60/60 stock and verify
pause, cooldown, callbacks and inventory conservation.

Pacing simulation uses the actual action durations, 0.10 seconds of reaction
time per action and seven seconds of food transit. Twelve normal and twelve
relaxed seeded campaigns complete. This catches impossible timing budgets; it
does not establish that every player will find the difficulty appropriate.
Actual controller sequences also complete a nine-action bag in 9.40 seconds
and a thirteen-action bucket in 13.77 seconds at 60 fps.

A separate 30-second native stress run passes eight invariants, including
physical stock conservation, unique callbacks, four scene resets, no orphan
nodes and unchanged player files. At 1280x800 on this RTX 3060 it measures
58.47 FPS over 1,463 post-warmup samples, with a peak of 73 food bodies. Only
150 sampled frames report focus, so this is a mixed-focus workload rather than
a controlled performance comparison. Evidence is in
`playtest-reports/food-stress-1.0.2.json` and its stdout/stderr logs.

## Rendered evidence

Native menu inspection covers 1280x800 and 1280x720, fresh and saved campaigns,
recovery notices and navigation. The native harness passes 39 checks and leaves
the tracked player-file fingerprints unchanged. Captures are in
`playtest-reports/title-1.0.2/`.
Keyboard regressions verify that dialogs suspend background title navigation
and receive keyboard focus. The pace selector explicitly applies to new runs;
Continue displays the checkpoint's saved pace.

The final chute recording contains 737 frames at 30 simulation frames per
second (24.57 seconds). It shows both sweep extremes, distribution, full-tray
overflow and the player's view. The support arch clears the entire swept path,
the visual outlet matches physics exactly, and ten actual waste events occur.
Native stderr is empty. Evidence:
`playtest-reports/chute-sweep/chute-sweep-review.webm` and
`playtest-reports/chute-sweep/capture-report.json`.

Hand captures use the actual controller and wait for its animation gates. Poses
cover grabbing, filling, pouring, coating, handoff, tray shake, the independent
dial and batter refill. Captures and their action timings are under
`playtest-reports/hand-motion/`.
The final `hand-motion-review.webm` contains 404 frames at 30 simulation frames
per second (13.47 seconds), including a successfully served order. Capture
stderr is empty; encoding and full video decoding both exit successfully.

## Exported builds

The final pipeline imported assets, passed every gate, exported both platforms,
mounted each resource pack in an isolated project to check its scope, verified
required notices and created versioned archives and a SHA256 manifest.

The Windows ZIP was extracted into a fresh validation directory. Packaged and
exported executables have identical SHA256 hashes:

```text
bc19f1069bb0a7348bcd5d8b8baf16790aac7739091c92cfd8986553a18fbe85
```

The extracted game reports version 1.0.2, passes its native smoke run, exits 0
and produces empty stderr. All ten current/legacy run, settings and career
primary/backup paths have unchanged fingerprints. Evidence:
`builds/logs/20261104-042703-849/12-packaged-native-result.json`.

The actual browser export was loaded on a new loopback origin. Canvas controls
verified settings navigation and keyboard focus, practice entry, the empty-hand
tray shake, heat-down feedback, bag/scoop handling and pouring. A completed $22
practice order and the next customer were observed. The sweep, pile and overflow
were visible during play. Browser warnings/errors were empty. The new browser
tab remains available at `http://127.0.0.1:8771/`.

Artifacts:

- `builds/releases/GoldenHour-1.0.2-windows-20261104-042703-849.zip`
- `builds/releases/GoldenHour-1.0.2-web-20261104-042703-849.zip`
- `builds/releases/GoldenHour-1.0.2-20261104-042703-849-SHA256.txt`

Windows ZIP SHA256:

```text
16d63d536ce20499d103a0b927ebb7445caef947c61ca6cdb967bdbdc60dba2e
```

## Scope

This is an interaction and presentation update to the offline fairground game.
Automated checks and captured sequences do not establish final artistic quality
or replace player feedback. Purchases, platform services and additional venues
remain outside this update. Existing release archives and player saves are
preserved.
