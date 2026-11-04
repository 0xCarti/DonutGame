# Golden Hour 1.0.1 interaction and physics validation

Validated 2026-11-04 UTC. Build **20261104-034843-075**.
This update addresses the player's report that food,
tools and controls lacked physical continuity. It is a specific animation and
physics improvement, not a claim that automated checks establish final artistic
quality or commercial readiness.

## Changes

- Production follows the machine's actual bath, flip and exit ramp before
  releasing rigid donuts into a collidable tray. Ring-shaped compound colliders
  let donuts tumble, collide, settle and spill onto the counter.
- Ready inventory increases on confirmed landing. Overflow consumes batter and
  counts as waste; previously landed donuts can also be knocked out. Waste stays
  visible briefly before fading and recycling. Pause freezes the physical state.
- Scooping takes existing donut objects out of the pile. Those same objects move
  through the scoop and package. Discarding an uncoated scoop returns its objects.
- Floating station frames are replaced by subtle highlights on the actual
  objects. Knobs rotate visibly. Bags, buckets, scoops, shakers and the batter
  pitcher move from their counter positions to the player's hands and back.
- Filled packages travel into the customer's hand; the customer walks away
  carrying them. One distinct next hand action can be buffered during a transfer.
- The HUD shows pending fryer output and wasted donuts, warns of tray overflow,
  and hides unused customer cards.
- Static venue geometry is grouped by material without removing triangles,
  labels, lights or walking visitors. Transparent highlight passes detach when
  inactive. Physics interpolation smooths rigid-body rendering.

## Automated coverage

All **1,016 checks passed**, with zero failures:

| Suite | Checks |
| --- | ---: |
| Simulation and progression | 294 |
| Controller, UI and saves | 216 |
| Shared reward audio mixer | 167 |
| Career profile | 28 |
| Receipt presentation | 24 |
| Stand audio | 148 |
| World and animation | 52 |
| Food physics | 41 |
| Food/controller integration | 46 |

The build runs simulation, controller/save, audio, profile, presentation, world,
food physics and food/controller integration suites before exporting either
platform. Real physics tests exercise ramp clearance, flat conveyor orientation,
ring collisions, landing callbacks, overflow, top-of-pile pickup, recovery, pause,
reset and resource cleanup.

Controller integration tests reconcile visible food against ready stock and
pending production, including a full 36-donut tray, delayed arrivals, checkpoint
reload and stale callbacks. Tests caught and fixed a timeout that could count a
donut as waste while it was still caught inside the tray. Waste now requires
actual counter contact outside the tray or falling below the table.

The final native stress workload used a full upgraded 60-stock tray, maximum
motor, repeated scoop/return, deliberate spills and four scene resets. All eight
invariants passed: no stock mismatches, duplicate callbacks, conservation failures
or leftover nodes; player saves were unchanged. Peak load was 73 bodies and 12
pending deliveries.

On the RTX 3060/OpenGL system at 1280x800, the final 30-second workload (five-second
warmup) averaged 59.84 FPS, with 16.71 ms mean frame time and 5.04 ms mean physics
time. This is one machine and workload, not a universal performance guarantee.
Although launched with a hidden window preference, Godot reported focus during
all 1,497 measured frames. Earlier unfocused runs are not a controlled comparison.
Evidence: `playtest-reports/food-stress-native.json` and its stdout/stderr logs.

## Visual evidence

`tools/capture_motion.gd` records the actual rendered scene, using isolated
practice state and fixed simulation steps. It performs a real service order,
then fills the tray to show production, discharge, collisions and counter waste.
Screenshots, frame samples and `motion-review.webm` are under
`playtest-reports/motion-1.0.1/`. This capture is visual evidence, not a frame-rate
benchmark. The close-up physics capture is reproduced with
`tools/capture_food_motion.gd`.

The final motion capture contains 579 frames at 30 simulation frames per second,
one successful order and three visible overflow losses. Ready inventory and
physical stock both ended at 36. Its completion assertion passed and stderr was
empty. The WebM is encoded from this final run, not an earlier capture.

## Exported builds

The build pipeline imported the project, passed every gate, exported both
platforms, checked runtime resource inclusion and verified ZIP notices/licenses.
Logs: `builds/logs/20261104-034843-075/`.

The Windows ZIP was extracted into a new validation directory. The extracted
and exported executables have identical SHA256 hashes:

```text
6a2fbb4682e207a01a3b75297dd83f502b70224a81ce553301171d53fc6c6f8d
```

The extracted executable ran natively on the RTX 3060 with `-- --smoke`, reported
version 1.0.1 and `STAND_SMOKE_PASS`, exited 0 and produced empty stderr. All ten
known player save/settings/career primary and backup paths matched their
pre-test fingerprints. See `12-packaged-native-result.json` in the build logs.

The actual browser export was served on a new loopback origin and tested through
canvas clicks and normal controls. Verified object highlighting, bag pickup,
scooping, two pours, cinnamon coating, lift, customer handoff and a $22 sale.
The jam lever completed a real hold-to-repair and cleared its warning. Donuts
were visible on the incline, in the tray and spilled on the counter; the waste
counter increased. Browser console warnings/errors were empty. Practice was
exited to the title without creating campaign or career progress.

Artifacts:

- `builds/releases/GoldenHour-1.0.1-windows-20261104-034843-075.zip`
- `builds/releases/GoldenHour-1.0.1-web-20261104-034843-075.zip`
- `builds/releases/GoldenHour-1.0.1-20261104-034843-075-SHA256.txt`

Windows ZIP SHA256:

```text
ec029c1f76d839598860f97421dd5523292f64c8078f5f0b0af3dc05bdfe2972
```

## Scope

Windows remains the primary platform; the browser export is a companion build.
The offline fairground campaign and existing progression remain in place. This
update adds no payments, paid boosts, cosmetic store or platform account system.
Those remain deferred to version 2. Previous release archives and player saves
are preserved.
