# Idea 2 playtest verification — 0.3.0

Validated on Windows with Godot 4.7.2 Compatibility rendering, and in the Codex Chromium browser on 2026-11-03 local time.

## Automated behavior

- 141 stand-model checks: portions, orders, tips, patience, mistakes, stock recovery, production, heat, maintenance holds, shift progression, upgrades, deterministic save restoration, and malformed saves.
- 134 controller checks: all 13 scene targets ray-pick correctly, mouse input completes a physical serving sequence, bag/bucket preparation, mistakes, repair/refill holds, pause, help/settings, continuation, shop, results, replay, and preservation of existing save bytes.
- 167 audio checks: tier selection, shared voice budget, peak headroom, independent music, mute, aliases, and loop. The test drains asynchronous audio commands before teardown; five additional focused runs confirmed clean shutdown after an intermittent test-lifecycle leak was fixed.

The strict packaging script rejects engine errors, failed assertions, missing artifacts, and missing license notices.

Release `20261104-022051-559` completed both exports and packaging. Its Windows ZIP was extracted into a separate folder, and the extracted executable ran with NVIDIA OpenGL rendering, reached the active shift, produced donuts, and exited with `STAND_SMOKE_PASS` and no stderr. Its SHA256 matched the exported executable: `485678d08e5248eb2c45d744855bf870fcf471a230c840068334bef4be2b9761`.

## Pacing evidence

Tool-aware simulations include separate scoop selection and finished-order pickup. Across 12 seeds, an operator taking 0.9 seconds per action cleared all three shifts. At 1.2 seconds per action, all tested runs cleared the introductory shift but did not finish the campaign. These are synthetic behavior checks, not claims that a person will find the difficulty enjoyable or fair.

## Browser interaction

At a narrow 907 by 920 viewport, the 16:10 play area fits the whole counter with letterboxing. An actual pointer sequence selected a bag, picked up the scoop, loaded and poured two scoops, added cinnamon, lifted the package, and clicked the customer's body. It awarded $20, cleared the package, and advanced the queue. Save, reload, and Continue restored $20, one served customer, and approximately 1:30 remaining. Browser warning/error logs were empty.

The native title, normal service, held-order view, tutorial, settings, and shop were rendered and visually inspected. Automated physical-target checks verify that the heat controls and handoff target remain accessible after collider adjustments.

## Limits

This is a first-person service prototype with procedural art. Human tests are needed to assess repetition, fun, queue pressure, and animation quality. Steam, native mobile packages, controller support, other venues, venue unlock progression, and purchases are not included. Windows executables are unsigned playtest builds. Browser audio and clipboard features remain subject to browser permissions.
