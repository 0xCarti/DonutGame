# Golden Hour 1.0.4 counter flow validation

Validated 2026-11-04 UTC. Build **20261104-051533-509**.

## Changes

- Selecting a bag or bucket retains an already-held scoop, including its food.
  The left hand takes the container while the right keeps the scoop grip. The
  existing container transfer duration is unchanged. A queued tray click then
  scoops immediately after the container lands.
- Empty containers can be swapped directly; the guide now explains this instead
  of instructing the player to discard them. Replacing a filled container still
  requires finishing or clearing it, preserving all food and held-tool state.
- Tray shaking applies three controlled lateral pulses during the same gesture,
  with a larger tray movement and local spacing bias. Edge donuts are steered
  inward and deep piles use less force. The visible tray and its colliders remain
  synchronized; only the tray surfaces move, not the counter or discard well.

## Verification

Controller checks exercise scoop-first container selection, both container
types with empty and loaded scoops, preserved food-object identities, buffered
scooping, rejected occupied-container replacement and matching HUD guidance.
Hand checks sample each transfer frame, including pause and reduced motion,
checking the left-hand pickup and continuous right-hand scoop grip.

The fixed-step physical tray scenario moves donuts 8.33 cm on average after a
single shake, with 7.39 cm mean movement relative to the group and 17.84 cm peak
displacement. Twenty-one of 24 donuts move more than 3 cm. The previous scenario
measured only 2.37 cm maximum displacement. Five repeated shakes retain every
donut in full 30-, 36- and 60-donut trays without waste. Cooldown, pause midway,
reset, production delivery and overflow checks pass.

Native controller captures show scoop-first bag pickup, a loaded-scoop bucket
swap, switching back to a bag, pouring, clearing and stronger tray shaking.
The final capture contains 338 frames at 30 simulation frames per second.
The capture harness waits for the audio mixer to release stopped playback
before exiting; final stderr is empty and there are no leaked-instance warnings.
Capture evidence: `playtest-reports/counter-flow-cleanup-fixed/` and adjacent
stdout/stderr logs. Physics evidence:
`playtest-reports/chute-distribution-1.0.4.json`.

All **1,642 checks across 16 automated suites pass**, with zero failures.
Affected suites include controller (273), hand motion (151), food physics (41)
and chute/distribution (126). Both Windows and Web exports pass isolated
resource-pack scope verification. Logs:
`builds/logs/20261104-051533-509/`.

The Windows ZIP checksum matches its manifest. A fresh extraction matches the
exported executable hash and reports file/product version 1.0.4.0. The hidden
packaged smoke run exits 0 in 7.263 seconds with `STAND_READY version=1.0.4`,
`STAND_SMOKE_PASS` and empty stderr. All ten current/legacy run, settings and
career primary/backup paths retain their fingerprints. Evidence:
`12-packaged-native-result.json` and adjacent logs in the build log directory.

Artifacts:

- `builds/releases/GoldenHour-1.0.4-windows-20261104-051533-509.zip`
- `builds/releases/GoldenHour-1.0.4-web-20261104-051533-509.zip`
- `builds/releases/GoldenHour-1.0.4-20261104-051533-509-SHA256.txt`

Windows ZIP SHA256:

```text
8f1da29871f103f3ef9c15ecd1237573a22e3a79ba96d23800e4f420a9dd791e
```

## Scope

This update changes counter interactions and tray agitation. It preserves save
formats, campaign balance, existing art, the total shake gesture duration and
the container pickup duration. Existing release archives remain available.
