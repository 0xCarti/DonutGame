# Golden Hour

## Idea #4: On the Circuit demo

The separate portrait company simulator is in [idea4-circuit](idea4-circuit/README-mobile.txt).
Open **idea4-circuit/project.godot** with Godot 4.7.2. It follows a full fairground
season through venue bookings, staff, recipes, pricing, equipment upkeep and
choice-driven stories. It has its own app identity and save; the first-person
game below remains preserved. Android, Windows and Web packaging scripts and an
iOS source/build handoff are included in that directory. Generated packages live
under `builds/circuit/0.1.0/rN/`; consult the matching build manifest for validation.

## First-person mini-donut game

**Godot is the active development project again:** open `project.godot` with
Godot **4.7.2 stable**. The active expansion is **Godot 1.2.0**, with Android and iPhone as the primary targets. The separate **Unity Windows 1.1.0** edition remains
a preserved checkpoint; its project, packaged release, and saves are retained.

## iPhone demo — start here, Hashim

The iOS handoff uses this **Godot project at the repository root**. Follow
[the iPhone build and signing guide](docs/IOS_HANDOFF.md) to export an Xcode
project on a Mac, install it on your iPhone, or distribute through TestFlight.
The shared mobile controls and an iOS export preset are included. The **1.2.0
unsigned ARM64 iPhone build** uses Godot 4.7.2 and Xcode 26.6 (iPhoneOS SDK 26.5).
The guide identifies the verified package and its exact source manifest. The IPA
still needs signing; the user chose FlareStore. Real iPhone installation/runtime
testing and TestFlight remain pending. Apple credentials are not part of this repository.

## Android and iPhone - 1.2.0

Mobile is the primary target. The 1.2.0 package paths are:

- Android: `builds/android/1.2.0/GoldenHour-1.2.0-Android.apk`
- iPhone: `builds/ios/1.2.0/r3/GoldenHour-1.2.0-iOS-unsigned.ipa`

Both contain the full expansion and touch interface. The APK uses the existing
release signing key so it can update the earlier demo without removing saves.
The IPA must be signed with the tester's own provisioning through FlareStore or
another signing workflow. Build manifests accompany generated packages; local
build artifacts are excluded from the source repository.

Tap counter objects to work; drag to look. Tools has larger controls for the
feeder speed, heat, repair, refill and extinguisher. Start on Balanced graphics.
Practice > Pause > Explore Venues & Machines previews all three locations.
Backgrounding pauses play and saves the run. The interface respects safe areas
and keeps text at native resolution when 3D resolution is reduced.

See the [Android install guide](docs/ANDROID.md) and
[iPhone build/signing handoff](docs/IOS_HANDOFF.md), with
[1.2.0 validation evidence](docs/RELEASE_1_2_VALIDATION.md). Physical-phone installation,
performance, thermals and sustained lifecycle behavior still require testing.
The signed 1.0.7 APK and earlier unsigned IPA remain preserved checkpoints.

## The Godot game

A first-person mini-donut stand game. Work a warm fairground booth:
scoop fresh donuts, fill bags and buckets, add cinnamon or powdered sugar, and
hand each order to its customer while keeping the fryer running.

Version 1.2.0 adds an **eighteen-shift tour** through the fairground, concert and stadium, earned Compact/Twin-Lane/Festival Pro machines, stand appeal, partial orders, and independent feed speed. Nineteen run upgrades, Standard/Relaxed, Practice and Endless remain. The Ticket Booth adds earnable cosmetics and five one-shift supplies; sixteen career badges include new physical secrets. **Real-money checkout is unavailable until a store is configured.** See [the expansion guide](docs/EXPANSION_1_2.md).

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

## Windows companion and preserved Web release

The secondary Windows 1.2.0 build contains the same expansion. Extract its ZIP
from `builds/releases/` and launch `GoldenHour.exe`. The unpacked build also lives
at `builds/windows/1.2.0/GoldenHour.exe`; the earlier 1.0.6 release is preserved.
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
WebGL 2 and WebAssembly. These existing desktop/browser releases remain available
as historical checkpoints. Gamepad controls and Steam billing/services remain future work.

## Preserved Unity Windows checkpoint — 1.1.0

`unity/GoldenHour` uses Unity **6000.3.28f1** and URP. Its separate scope is one
timed **Opening Day**, **Practice**, and earned **After Hours**. It includes
authored FBX props, skinned characters, physical donuts, independent fryer dials,
articulated tool handling, warm fairground lighting, and booth gags. The Godot
campaign counts above do not describe this edition.

Launch `builds/unity/windows/GoldenHour.exe`; **Tab** shows the whole counter,
**F1** opens the field guide, **Esc** pauses, and **F11** toggles fullscreen.
Its build command remains `pwsh -File tools/unity/build_windows.ps1`.
The [Unity handoff](unity/UNITY_MORNING_STATUS.txt) records the preserved package,
native verification, and remaining scope. Android development uses Godot and
does not replace or migrate Unity saves.

## Build and maintain

Godot **4.7.2 stable**, GDScript, Compatibility renderer. Open `project.godot`;
the active scene is `scenes/stand_main.tscn`. For Android:

```powershell
python tools/setup_android_toolchain.py
python tools/build_android.py
```

The Android builder uses a private signing key stored outside the repository.
Back up that key and its local credentials for future updates. Setup, output
verification, and phone testing are described in [ANDROID.md](docs/ANDROID.md).
For the existing Windows/Web build pipeline:

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
| `scripts/mobile_controls.gd` | Mobile toolbar, contextual action, optional Tools drawer and cancellable holds |
| `scripts/mobile_input.gd` | Touch tap/drag/hold recognition and safe-area canvas mapping |
| `scripts/mobile_quality.gd` | Low/Balanced/High rendering profiles and device diagnostics |
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
