# Golden Hour 1.0.0 release validation

Validated 2026-11-04 UTC. Release build: **20261104-030827-525**.

## Delivered scope

Windows-first, offline first-person fairground game with a complete six-shift
campaign, nineteen earned upgrades, Standard/Relaxed difficulty, practice fault
lessons, unlockable Endless Rush, career records/badges and three earned stand
palettes. The serving loop includes physical container selection, scooping,
pouring, coating, lifting and handoff; production, heat, feed wear and batter
continue to require attention.

The finished presentation includes textured 3D machinery/food/packaging, original
title/sign/seal illustrations, animated service and maintenance, persistent fault
instructions and pointers, exact receipt breakdowns, escalating streak effects,
original synthesized music/ambience/service sounds, and reduced-motion controls.

Payments, temporary paid boosts, cosmetic purchases and Steam account integration
are explicitly deferred to V2. V1 exposes no checkout, advertising or paid store.

## Automated gates

All **852 checks passed**, zero failures:

| Suite | Checks |
| --- | ---: |
| Stand simulation and progression | 251 |
| Actual controller/UI/save integration | 206 |
| Shared reward audio mixer | 167 |
| Persistent career profile | 28 |
| Receipt presentation and bounded effects | 24 |
| Stand audio, warnings, ambience and volume controls | 148 |
| 3D world, all 13 station rays and effects | 28 |

The build script ran import, gates, Windows/Web export, isolated pack-resource
checks and ZIP/license checks. Logs are in
`builds/logs/20261104-030827-525/`. Both packs contain required dynamic assets and
all 28 runtime WAVs. Historical gameplay scenes/scripts and test resources are
excluded from the game exports.

The integration checks cover campaign completion, loss, upgrades, difficulty,
Endless, actual physical pointer selection, full bag/bucket orders, wrong-order
recovery, interrupted holds, pause, save/reload and settings. Save regressions
include practice-to-title-to-quit isolation, unsupported/corrupt data, backup
recovery, failed career writes retaining the checkpoint, and idempotent retries.
Testing preserved the actual player's save/settings/career files.

Tool-paced balance simulations won 64/64 Normal seeds at 0.65 seconds per action,
10/12 at 0.9 seconds per action, and 12/12 Relaxed seeds at 1.2 seconds per action.
They include individual service actions and maintenance holds. These are pacing
and feasibility evidence, not measurements of human enjoyment or novice skill.

## Packaged Windows verification

The final Windows ZIP was extracted to a fresh directory. Its executable matches
the exported executable SHA256:

```text
0e45377bbc70bd8cd230cff8251e4f0a30642dce72c669be5d821e78d0adb940
```

The extracted executable ran with `-- --smoke`, used NVIDIA RTX 3060/OpenGL,
printed `STAND_SMOKE_PASS`, and exited 0 without engine errors. Before/after
hashes of ten known run/settings/career primary and backup paths match.
Evidence: `builds/logs/20261104-030827-525/12-packaged-native-result.json`, its
stdout/stderr logs and companion save-fingerprint files.

The native rendered QA harness `tools/capture_release.gd` additionally inspected
title, gameplay, real handoff, all four sale tiers, jam, overheating, settings,
shop and collection. It served ten actual practice orders using controller
actions to exercise every celebration tier without skipping campaign quotas.
Final output: `RELEASE_RENDER_QA_COMPLETE served=10`; stderr empty. Captures and
logs are under `playtest-reports/release-*`.

World stress sustained the 60 Hz presentation cap at 1280x800 on this RTX 3060,
including rapid tier-3 effects, and returned from 1551 nodes to 1551 with zero
remaining transient effects. See [art validation](ART_VALIDATION_1_0.md) for the
full measurement method, reproduction and hardware limits.

## Browser verification

The exported files were served on loopback HTTP and exercised through the real
canvas UI in Codex's Chromium browser. Observed:

- New-player instructions, campaign start and a complete cinnamon bag sold by
  clicking the actual container/scoop/tray/package/coating/customer objects.
- Earned sales visible in the HUD; pause and save-to-title followed by reload
  restored the same shift, sales and remaining time.
- Practice lessons, persistent jam/overheat/empty-hopper notices and pointers;
  physical hold-to-repair and hold-to-refill completed and cleared their faults.
- Readable proportional layout at 1280x720 and 906x920 with letterboxing.
- Final rebuild verified on a separate clean origin: Practice uses OPEN / NO
  CLOCK and CALM, and a concurrent refill leaves the overheating instructions
  intact while showing hold percentage in the bottom guide.
- Final browser console warning/error query returned an empty list.

Initial browser inspection caught an unsupported infinity glyph and incorrect
fault text during simultaneous maintenance. Both were fixed before this final
package. The final clean preview is left at its title screen with no campaign
save or earned career progress from QA.

## Artifacts and practical limits

- `builds/releases/GoldenHour-1.0.0-windows-20261104-030827-525.zip`
- `builds/releases/GoldenHour-1.0.0-web-20261104-030827-525.zip`
- `builds/releases/GoldenHour-1.0.0-20261104-030827-525-SHA256.txt`

Previous archives and player saves were preserved. This is a locally packaged
V1 delivery for the user's acceptance testing; nothing has been submitted to a
store or published publicly. The checks establish the observed behavior on the
tested Windows hardware and browser, not every possible GPU, driver or device.
Native mobile builds, gamepad support, additional venues and platform purchases
are outside the agreed V1 scope.
