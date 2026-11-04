# Golden Hour

## Unity Windows edition — 1.1.0

The active project is now `unity/GoldenHour`, built with Unity **6000.3.28f1**
and URP. Launch `builds/unity/windows/GoldenHour.exe`. This edition has one
complete timed **Opening Day**, no-pressure **Practice**, and unlockable
**After Hours**. It uses authored FBX props and skinned characters, physical
mini donuts, independent fryer controls, articulated tool handling, a recessed
discard opening, warm fairground lighting, and the tray-shake/fire/punch gags.

Read the customer ticket. Choose a bag or bucket, scoop from the tray, pour into
the package, add the requested sugar, then serve. You can keep the scoop while
collecting packaging. Click highlighted objects; **Tab** shows the whole counter,
**F1** opens the field guide, **Esc** pauses, and **F11** toggles fullscreen.
The field guide explains the optional keyboard shortcuts and machine recovery.

Build from this directory with `pwsh -File tools/unity/build_windows.ps1`.
The builder runs the core acceptance suite, imports/audits the assets, creates
the scene, and compiles the native Windows player. See
[Unity handoff](unity/UNITY_MORNING_STATUS.txt) for validation and known scope.
The first licensed native build has been tested at 1920 × 1080; platform stores,
payments, mobile ports, additional venues, and wider hardware testing remain
outside this Windows edition. Existing Godot releases and saves are preserved.

## Preserved Godot edition — 1.0.6

The following documents the earlier Godot release, which is still available.
Its campaign and feature counts do not describe the separate Unity edition.

A first-person mini-donut stand game for Windows. Work a warm fairground booth:
scoop fresh donuts, fill bags and buckets, add cinnamon or powdered sugar, and
hand each order to its customer while keeping the fryer running.

Version **1.0.6** contains the complete fairground campaign: six named shifts,
nineteen earned equipment and service upgrades, Standard and Relaxed difficulty,
no-pressure practice, an unlockable Endless Rush, career badges and three earned
stand palettes. All play is local and offline. Purchases and platform services
are reserved for version 2.

The interaction system connects production to real food objects: donuts ride
up the exit ramp, drop into the tray, collide and settle. Full trays spill onto
the counter and waste batter. Objects highlight directly, and containers, tools
and their contents move continuously between the counter and your hands.

The booth surprises introduced in 1.0.5 include a service bell with an occasional
answer, powdered-sugar sneezes, a donut hat, a cartoon customer punch, and a
seagull that can catch a real spilled donut. A gentle tray shake spreads stock;
rapid repeated clicks build momentum and can throw it over the sides. Prolonged
overheating can start a fryer fire, with a working extinguisher and recovery.
These events have original animation and eight synthesized sound cues.

Version 1.0.6 replaces solid fire shapes with layered turbulent flames, wispy
smoke and rising embers. Punch contact takes 0.12 seconds and the hand returns
by 0.36 seconds, while customers squash, stagger and see stars. Native fullscreen
uses the full display area with 4x MSAA, 16x anisotropic filtering, higher-detail
materials, sharper vector labels and threefold world-lettering resolution.

Your free hand can grab a bag or bucket while you keep the scoop ready. The
small pinhole-center donuts, recessed discard opening, folded kraft bags,
curved shaker labels, detailed customers and gloves, authored wood/paper
surfaces, sweeping chute, independent dials and fairground ticket menu remain.

## Play

Extract the Windows ZIP from `builds/releases/` and launch `GoldenHour.exe`.
The unpacked build also lives at `builds/windows/1.0.6/GoldenHour.exe`.
Keep the included `LICENSES` folder and `Quick Start.txt` with the executable.

Choose **Open the Stand** for the campaign or **Practice** to learn without a
clock. Read the cream customer ticket, pick the matching container, scoop and
pour until full, coat it, lift the package and hand it over. Fault alerts point
to the control that needs attention. The dashboard always shows your next step.

Click the actual 3D objects. G rings the service bell; Q uses the extinguisher.
Right-drag looks around; Home recentres. Esc pauses; F11 toggles fullscreen.
Optional keyboard shortcuts are listed in the in-game
instructions and [player guide](docs/IDEA2_PLAYTEST.md).

Independent sliders control sound effects, music and ambience. Reduced Motion
reduces camera shake and moving effects while preserving gameplay outcomes. Active
runs and career progress save locally; practice preserves the campaign save.

The companion browser build is `builds/web/1.0.6/`. Serve it over HTTP; it needs
WebGL 2 and WebAssembly. Windows is the primary platform. Native mobile builds,
gamepad controls, Steam services and additional venues are future work.

## Build and maintain

Godot **4.7.2 stable**, GDScript, Compatibility renderer. Open `project.godot`;
the active scene is `scenes/stand_main.tscn`.

```powershell
pwsh -File tools/build_stand_playtest.ps1
```

The historical script filename is retained. It imports, runs simulation,
controller, profile, presentation, world, rigid-body food, hand motion, chute,
menu, campaign pacing, art, audio and booth gag checks, exports Windows and
Web, and packages ZIPs with notices and SHA256 checksums. See
[build instructions](docs/BUILDING.md) and [release validation](docs/RELEASE_1_0_6_VALIDATION.md).

| File | Responsibility |
| --- | --- |
| `scripts/stand_model.gd` | Seeded simulation, production, orders, faults, saves |
| `scripts/stand_content.gd` | Campaign shifts and earned upgrades |
| `scripts/stand_world.gd` | 3D booth, physical interaction, animation, effects |
| `scripts/stand_food_physics.gd` | Conveyor path, rigid donuts, tray collisions and waste |
| `scripts/stand_main.gd` | Input, menus, progression and persistence |
| `scripts/stand_hud.gd` | Tickets, gauges, contextual guidance and fault pointers |
| `scripts/stand_feedback.gd` | Exact receipt amounts and escalating celebrations |
| `scripts/stand_audio.gd` | Tactile service sounds and bounded audio mixer |
| `scripts/player_profile.gd` | Career records, badges and earned palettes |

Original generated artwork and synthesized audio are documented in
[asset provenance](docs/ASSET_LICENSES.md). Engine and font notices accompany
every package. There is no account system, telemetry, network purchase flow or
advertising in V1.

The earlier Idea 1 prototype and 0.3 first-person development build remain in
source history and existing release folders. They are excluded from the V1
export. The [product direction](docs/PRODUCT_DIRECTION.md) records the chosen
game and the separate V2 scope.
