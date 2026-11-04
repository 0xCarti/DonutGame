# Golden Hour — Mini Donut Club

A real-time 3D mini-donut roguelite based on **Game Idea #1**. One physical fryer, six escalating shifts, and twenty upgrades that combine into different builds. The first venue is a warm fairground at dusk.

## Playtest

The current Windows build lives in `builds/windows/0.2.0-playtest/GoldenHour.exe` after export. Run the executable, choose **Open the stand**, and follow the first-run instructions. No account or internet connection is needed for the Windows build.

The browser export is in `builds/web/`. Serve that directory over HTTP; opening `index.html` directly from disk will not work. Web play requires WebGL 2 and WebAssembly. Modern desktop Chromium or Firefox is the preferred first browser test target.

This is a playtest, not a Steam or mobile-store release. Native iOS/Android packaging, store integration, controller support, and further venues are future work.

## The loop

1. Select cinnamon, powdered sugar, or cocoa and a destination tray.
2. Drop six donuts into the hopper. Watch them travel, fry, flip, and land.
3. Sell partial trays if you need to, or hold six matching donuts for a 2× payout. Full mixed trays start at 1.6×.
4. Meet the gross sales target before closing. Full trays block incoming donuts until sold.
5. Buy upgrades with separate shop coins, then tackle the next rush. Unspent coins carry over.

Six successful shifts win the run. You may finish a shift early after meeting its target, or keep selling for more shop coins.

## Controls

Everything is playable with a mouse or a single touch pointer. Keyboard shortcuts are optional:

| Action | Key |
| --- | --- |
| Cinnamon / powdered / cocoa | A / S / D |
| Select destination tray | 1 / 2 / 3 |
| Drop six donuts | Space |
| Sell tray 1 / 2 / 3 | Q / W / E |
| Pause / close popup | Escape |
| How to play | H |
| Mute | M |
| Fullscreen | F11 |

The game saves active runs and shop decisions locally. Losing focus pauses a native game. **Save & return to title** preserves your run. Starting a fresh run asks before replacing a saved run.

## Development

Engine: Godot **4.7.2**, GDScript, Compatibility renderer. Open `project.godot` with Godot. The project has no third-party runtime plugins.

```powershell
godot --headless --path . --import
godot --headless --path . --script tests/test_run_model.gd
godot --headless --path . --export-release "Windows Desktop" builds/windows/0.2.0-playtest/GoldenHour.exe
godot --headless --path . --export-release "Web" builds/web/index.html
```

The export directories must exist and matching Godot export templates must be installed. `tools/install_godot_templates.py` installs the relevant templates from an official template archive.

For a complete rebuild with tests, exports, licenses, and shareable ZIP files, run `pwsh -File tools/build_playtest.ps1`. See [BUILDING.md](docs/BUILDING.md). Timestamped Windows and Web archives and their SHA256 checksums are written to `builds/releases/`.

## Verified playtest 0.2.0

- 134 simulation/save checks, 102 controller/UI checks, 78 score-feedback checks, and 167 audio checks passed.
- Sales now use four escalating presentation tiers: payout count-up, flying coins, light chases, physical bursts, capped camera shake, and layered original sounds. Rapid full-tray sales intensify the presentation without changing earnings. Reduced motion keeps the score readable while removing camera shake and UI coin flights.
- The world now uses original generated material maps, bevelled machine parts, service-panel hardware, cables, work lamps, more dimensional donuts, and stronger separation between warm light and cool shadows.
- The Windows release ZIP was extracted into a separate folder and its executable rendered and completed the production smoke sequence: two six-donut batches reached their trays, with no engine errors.
- The browser build was played through its first shift. Upgrade purchases, next-shift progression, pause, sound controls, and save/resume through reload were verified in a Chromium browser; no browser runtime errors were reported.
- Native title, gameplay, settings, jackpot, reduced-motion, and stress-test score screens were rendered and visually inspected at 1280 by 800. The browser interface was also checked in a narrower, taller window. Large score text and effects leave the HUD and bottom controls accessible.

These are functional checks, not a substitute for human balance and enjoyment feedback. The six-shift campaign and upgrades are complete for this first playtest. Additional venues and their unlock progression, Steam features, controller input, and native iOS/Android packages remain future work. The Windows executable is an unsigned playtest build.

## Structure

- `scripts/run_model.gd`: deterministic run simulation, scoring, shop economy and save validation.
- `scripts/upgrades.gd`: upgrade catalogue.
- `scripts/donut_world.gd`: original procedural 3D machine, donuts, stand, lighting and fairground.
- `scripts/main.gd`: controls, tutorial, HUD, shop, pause, results and local persistence.
- `scripts/game_audio.gd`: music and polyphonic sound events.
- `scripts/score_feedback.gd`: presentation tiers and rapid-sale chains, independent of the economy.
- `scripts/score_effects.gd`: score count-up, coin flights, celebration badges and reduced motion.
- `tools/generate_audio.py`: reproduces the original sound assets.
- `tests/test_run_model.gd`: gameplay regression and simulation tests.
- `docs/ASSET_LICENSES.md`: asset provenance and licenses.

Venue scenery is separate from gameplay. Future concert and sports venues can reuse the fryer, run model, and interface while changing scenery, presentation, targets, and demand rules. Those venues are not included in this playtest.

[Product direction](docs/PRODUCT_DIRECTION.md) records the visual goals and the open purchase-design decision. The playtest contains no real-money store or payment system.

## Playtest feedback

The result screen includes **Copy playtest report** with the seed, build, score, platform and current FPS. Paste it with feedback about clarity, controls, balance, upgrades, frame rate, and any bugs. No analytics or personal data is sent anywhere.
