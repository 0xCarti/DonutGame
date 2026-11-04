# Golden Hour

A first-person mini-donut stand game for Windows. Work a warm fairground booth:
scoop fresh donuts, fill bags and buckets, add cinnamon or powdered sugar, and
hand each order to its customer while keeping the fryer running.

Version **1.0.1** contains the complete fairground campaign: six named shifts,
nineteen earned equipment and service upgrades, Standard and Relaxed difficulty,
no-pressure practice, an unlockable Endless Rush, career badges and three earned
stand palettes. All play is local and offline. Purchases and platform services
are reserved for version 2.

The 1.0.1 interaction pass connects production to real food objects: donuts ride
up the exit ramp, drop into the tray, collide and settle. Full trays spill onto
the counter and waste batter. Objects highlight directly, and containers, tools
and their contents move continuously between the counter and your hands.

## Play

Extract the Windows ZIP from `builds/releases/` and launch `GoldenHour.exe`.
The unpacked build also lives at `builds/windows/1.0.1/GoldenHour.exe`.
Keep the included `LICENSES` folder and `Quick Start.txt` with the executable.

Choose **Open the Stand** for the campaign or **Practice** to learn without a
clock. Read the cream customer ticket, pick the matching container, scoop and
pour until full, coat it, lift the package and hand it over. Fault alerts point
to the control that needs attention. The dashboard always shows your next step.

Click the actual 3D objects. Right-drag looks around; Home recentres. Esc pauses;
F11 toggles fullscreen. Optional keyboard shortcuts are listed in the in-game
instructions and [player guide](docs/IDEA2_PLAYTEST.md).

Independent sliders control sound effects, music and ambience. Reduced Motion
removes shake and moving celebration particles while preserving outcomes. Active
runs and career progress save locally; practice preserves the campaign save.

The companion browser build is `builds/web/1.0.1/`. Serve it over HTTP; it needs
WebGL 2 and WebAssembly. Windows is the primary platform. Native mobile builds,
gamepad controls, Steam services and additional venues are future work.

## Build and maintain

Godot **4.7.2 stable**, GDScript, Compatibility renderer. Open `project.godot`;
the active scene is `scenes/stand_main.tscn`.

```powershell
pwsh -File tools/build_stand_playtest.ps1
```

The historical script filename is retained. It imports, runs simulation,
controller, profile, presentation, world, rigid-body food and audio checks, exports Windows and
Web, and packages ZIPs with notices and SHA256 checksums. See
[build instructions](docs/BUILDING.md) and [release validation](docs/RELEASE_1_0_1_VALIDATION.md).

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
