# Golden Hour — Behind the Counter

A first-person mini-donut stand playtest based on **Game Idea #2**. The machine makes plain donuts while you scoop, package, season, and hand over customers' orders. Queues, heat, jams, and batter compete for your attention in a warm fairground booth.

The previous Idea #1 tray-builder prototype remains in the repository and its 0.2.0 release folders for comparison. Version **0.3.0** is the active direction.

## Play

After export, launch `builds/windows/0.3.0-playtest/GoldenHour.exe`. Choose **Step behind the counter** and follow the short tutorial. The Windows build runs without an account or internet connection.

The browser build is in `builds/web/0.3.0-playtest/`. Serve that directory over HTTP; opening `index.html` directly from disk will not work. It requires WebGL 2 and WebAssembly. Windows is the primary playtest target; Steam integration and native iOS/Android releases are future work.

## Work the stand

1. Read the first customer's ticket and take a bag (6 donuts) or bucket (12).
2. Pick up the scoop, click the fresh donut tray, and click your container to pour. Repeat until full. The scoop stays in your hand between loads.
3. Click the requested cinnamon or powdered sugar to season the order.
4. Click the completed package to lift it, then click the customer to hand it over.
5. Hold the repair lever to free jams, adjust the heat, and hold the hopper to refill batter. Partly completed maintenance can be interrupted and resumed.
6. Meet each shift's sales quota. Buy improvements between three increasingly busy shifts.

Customers lose patience; mismatched orders cost time. If you make a mistake, the scrap bin clears the package. Plain donuts can be recovered, while coated donuts are discarded. Successful service earns tips, and consecutive correct orders increase rewards and celebration.

Click the actual objects in the 3D scene. Right-drag to look around; **Home** recentres. Keyboard shortcuts are optional:

| Action | Key |
| --- | --- |
| Take bag / bucket | B / V |
| Pick up scoop / scoop fresh donuts | S / F |
| Pour, lift, or set down package | Space |
| Cinnamon / powdered sugar | C / P |
| Hand over order | E |
| Lower / raise heat | - / = |
| Hold to repair / refill | R / T |
| Clear package | X |
| Pause / help / fullscreen | Escape / H / F11 |

Active shifts and shop decisions save locally. Losing focus pauses the native game. **Save & return to title** preserves the run. Idea 2 uses separate save and settings files from Idea 1. Sound, music, and reduced motion can be set independently.

## Development

Engine: Godot **4.7.2 stable**, GDScript, Compatibility renderer. Open `project.godot`; the active scene is `scenes/stand_main.tscn`.

```powershell
pwsh -File tools/build_stand_playtest.ps1
```

The script imports, tests simulation and controller behavior, checks audio, exports Windows and Web, and packages shareable ZIPs with license notices and SHA256 checksums under `builds/releases/`. Matching export templates must be installed. See [BUILDING.md](docs/BUILDING.md) and the [playtest guide](docs/IDEA2_PLAYTEST.md).

- `scripts/stand_model.gd`: orders, portions, heat, production, maintenance, upgrades, and save validation.
- `scripts/stand_world.gd`: first-person booth, raycast interactions, customers, visible tools, animations, and reward effects.
- `scripts/stand_main.gd`: interaction flow, HUD, tutorial, pause, shop, results, and persistence.
- `scripts/stand_audio.gd`: service sounds using the existing original audio library.
- `tests/test_stand_model.gd`: simulation, balance, recovery, and persistence checks.
- `tests/test_stand_controller.gd`: physical station selection, input, UI transitions, and manual serving flow.
- `docs/ASSET_LICENSES.md`: asset provenance and license notices.

The earlier `main.gd`, `run_model.gd`, `donut_world.gd`, and `build_playtest.ps1` retain the Idea 1 prototype. To rebuild that historical release, use its committed source rather than the current active export configuration.

## Playtest scope

This build tests whether manual service and queue pressure make a more engaging foundation. Automated checks establish functional behavior; human playtesting must establish enjoyment and difficulty. Art is an original procedural prototype, with further modeling, animation, and polish still needed for a commercial release.

The first venue is the fairground. Concerts, sports venues, persistent venue unlocks, controller support, Steam features, and mobile packaging remain future work. The [product direction](docs/PRODUCT_DIRECTION.md) records these plans and the open purchase-design decision. There are no payments or purchase prompts in this playtest.

The results screen can copy a local playtest report. Share it with feedback about the serving rhythm, unclear interactions, difficulty, performance, and bugs. No analytics or personal data is sent anywhere.

Version 0.3.0 passed **442 automated checks**, extracted Windows package startup, and a browser order-serving and save/reload check. See the [validation record](docs/PLAYTEST_0_3_VALIDATION.md) for evidence and limits.
