# Golden Hour 1.0.5 — fairground slapstick

This update adds optional physical comedy to the existing first-person service
loop. A normal tray shake still distributes stock safely. Rapid clicks build
momentum and launch actual donuts; each lost item is counted once as waste.
One seagull can take an actual launched donut, with a cooldown and a persistent
secret career badge.

An empty-hand click on the front customer immediately punches and skips that
customer. The animation includes a short jab, impact, recoil and departure.
There is no hold gesture. Skipping grants no sale and ends the service streak;
the prepared package, loaded scoop and remaining queue stay intact. Clicking
with a finished package still serves normally. The serving mat remains a
separate order-delivery target.

Neglected hot oil progresses through a smoke warning to a visible fire. The
physical extinguisher (Q) clears it, briefly stops production and leaves foam
that fades. Food and orders survive; held tools return to the counter. Players
can then set the heat and continue. Repeated bell rings (G), excess powdered
sugar and a rare donut hat have discoverable reactions. Eight original
synthesized cues share the existing bounded audio mixer.

Run saves use schema 4 with explicit migrations from schemas 1–3. Career
schema 1 remains compatible; the new badge is an allowed optional entry.
No real purchases, external services or account requirements are introduced.

## Verification

The release gate runs the existing model, controller, audio, career, UI,
world, physical inventory, chute, hand motion, campaign pacing and art suites,
plus new controller and world gag integration suites. Both exported packs
are mounted in an empty project to verify assets without workspace fallback.

All **1,950 checks across 18 suites passed**, with zero failures. Build logs:
`builds/logs/20261104-054106-616/`. Both exported resource scope checks passed.
The effect-cap regressions include inserting effects during a jab and evicting
the jab early; neither may double-advance the animation or strand a customer.

Native staged capture of the actual controller produced **879 frames at 30 fps**
with `valid=true` and empty stderr. Reviewed smoke, fire, foam, both loaded-tool
returns, punch/recoil, hat objection, customer sneeze, bell/reply, launched food,
gull theft, settings and six collection cards. Stage snapshots check model stock
against physical availability. The final launch goes from 24 stock to 0 stock
and 24 waste, including the exact visual carried by the gull. Evidence:
`playtest-reports/slapstick-1.0.5/report.json`, its PNGs/frame sequence, and
`playtest-reports/slapstick-capture.err`. The helper uses test mode and staged
conditions; it is a visual integration check, not a performance benchmark.

Build **20261104-054106-616** produces:

- `builds/windows/1.0.5/GoldenHour.exe`
- `builds/releases/GoldenHour-1.0.5-windows-20261104-054106-616.zip`
- `builds/releases/GoldenHour-1.0.5-web-20261104-054106-616.zip`

SHA256:

```text
Windows ZIP  8c9338c12e3c03c60038c6105f0b1c3ed102b2574e13a8349ccb94b098ee94c0
Web ZIP      f29e92ea15839c48ebed9bbf864ca7533822cc79ea89872388037736c54cde3f
```

Freshly extracted Windows package smoke passed: PE file/product version 1.0.5.0,
runtime `STAND_READY version=1.0.5`, `STAND_SMOKE_PASS`, exit 0 in 7.441 seconds,
and empty stderr. Its executable SHA256 matches the exported executable:
`1bc5fcdfd898052a0c853790be08b2ebbb3e4b4edeaebc39b61d5183831d30c5`.
All ten protected save/settings/career primary and backup paths were unchanged
(seven existing files, three absent paths). Report:
`builds/logs/20261104-054106-616/12-packaged-native-result.json`.

The exported WebGL build loaded at `http://127.0.0.1:8773/` and displayed 1.0.5.
Interactive browser practice checks confirmed an empty-hand customer click
advances the queue, unattended heat produces the fire warning/flames, Q clears
the fire, and five rapid tray clicks change 36 ready/17 waste to 0 ready/53 waste.
The browser console reported no warnings or errors. Practice was exited to the
title; this is an isolated localhost origin and does not touch native save files.

These checks validate this update's packaged behavior. Store submission,
purchases, native mobile support and large-scale hardware/player testing remain
outside this release's scope.
