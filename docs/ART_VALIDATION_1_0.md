# Golden Hour 1.0 — native art validation

Recorded 2026-11-03. This report covers the first-person 3D stand scene, its art resources, physical targets, and transient effects. It does not replace the controller, audio, save, or release-package gates.

## Results

| Check | Observed result |
| --- | --- |
| Persistent world regression suite | **28 checks, 0 failures**, exit 0 |
| Physical target rays | All **13** target centers resolve to their expected station ID |
| Native captures | Gameplay, held cinnamon bag, jam, and held powdered bucket inspected |
| Native capture stderr | Empty for final gameplay, service, jam, and performance runs |
| Normal scene timing | **16.67 ms/frame**, 180 measured frames |
| Rapid reward/coating timing | **16.67 ms/frame**, 180 measured frames |
| Retained scene nodes after stress settles | **1551 before → 1551 after** |
| Remaining transient effects | **0** |
| Measured rendering draw calls | **4959** for the populated normal scene |

The native timing sample used **Godot 4.7.2 stable**, the **Compatibility/OpenGL 3.3 renderer**, an **NVIDIA GeForce RTX 3060**, NVIDIA driver **621.01**, and a **1280 × 800** viewport. Presentation was capped at **60 Hz**. The 16.67 ms measurements demonstrate that this sample sustained the cap; they do not measure uncapped headroom or guarantee performance on other GPUs.

The populated timing scene contained three customers, 30 tray donuts, a held bucket with 12 powdered donuts, the full fairground, machine, lights, and hands. After 60 warm-up frames it measured 180 normal frames, then 180 stress frames with a tier-3 reward and coating action every six frames (**30 repeated bursts/actions**), followed by 180 settling frames.

## Reproducible regression gate

The committed test source is `tests/test_stand_world.gd`. Run from the repository root in PowerShell:

```powershell
& 'C:/Users/bryce/.cache/donutsgame/godot/Godot_v4.7.2-stable_win64_console.exe' `
  --headless --path 'C:/Users/bryce/Documents/ChatGPT/DonutsGame' `
  --script res://tests/test_stand_world.gd
```

Expected final line:

```text
WORLD QA: 28 checks, 0 failures
```

The 28 assertions cover 13 actual physics raycasts; persistent jam highlighting/status; normalized repair progress; a visible refill pitcher; production stopping during refill; paused world time; the 64-effect cap under rapid actions; capped camera recoil; reduced motion clearing recoil and suppressing celebration particles; effect and seasoning-prop cleanup; and cosmetic changes preserving safety colors. This suite returns a nonzero exit code if any assertion fails.

The latest independent rerun after source freeze also returned 28 checks and zero failures. The real controller integration suite was separately observed at 156 checks and zero failures earlier in this art pass; its owner maintains the current controller count.

## Native performance evidence and reproduction

Evidence files:

- `playtest-reports/art-performance.stdout.log`
- `playtest-reports/art-performance.stderr.log` (empty)

The recorded result is:

```text
Godot Engine v4.7.2.stable.official.ed1daf0bf
OpenGL API 3.3.0 NVIDIA 621.01 - Compatibility - Using Device: NVIDIA - NVIDIA GeForce RTX 3060
WORLD_PERF normal_ms=16.67 stress_ms=16.67 draws=4959 baseline_nodes=1551 after_nodes=1551 effects=0
```

The temporary native timing harness used for this measurement is at `C:/Users/bryce/AppData/Local/Temp/golden_world_perf.gd`. Its source is reproduced below so the result does not depend on retaining a temporary file. Save the fenced code to that path, or another `.gd` path and adjust the command. This harness is observational; the persistent regression suite above supplies assertions.

```gdscript
extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 800)
	var world = load("res://scripts/stand_world.gd").new()
	root.add_child(world)
	var state = {
		"phase":"playing", "temperature":180, "batter":40,
		"supply":30, "supply_capacity":36, "package_type":"bucket",
		"package_count":12, "package_flavor":"powdered",
		"held_tool":"package", "scoop_count":0,
		"orders":[
			{"id":4,"package":"bucket","flavor":"powdered","patience":30,"max_patience":60},
			{"id":5,"package":"bag","flavor":"cinnamon","patience":30,"max_patience":60},
			{"id":6,"package":"bag","flavor":"powdered","patience":30,"max_patience":60}
		]
	}
	world.sync_state(state)
	for i in range(60): await process_frame
	var baseline: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var start: int = Time.get_ticks_usec()
	for i in range(180): await process_frame
	var normal_ms: float = float(Time.get_ticks_usec() - start) / 180000.0
	var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	start = Time.get_ticks_usec()
	for i in range(180):
		if i % 6 == 0:
			world.burst_reward(40.5, 3)
			world.animate_action("powdered")
		await process_frame
	var stress_ms: float = float(Time.get_ticks_usec() - start) / 180000.0
	for i in range(180): await process_frame
	var after: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	print("WORLD_PERF normal_ms=%.2f stress_ms=%.2f draws=%d baseline_nodes=%d after_nodes=%d effects=%d" % [normal_ms,stress_ms,draw_calls,baseline,after,world._effects.size()])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://playtest-reports/art-final-powdered.png"))
	world.queue_free()
	await process_frame
	await process_frame
	quit(0)
```

Launch the native measurement in a hidden window:

```powershell
$artPerf = Start-Process `
  -FilePath 'C:/Users/bryce/.cache/donutsgame/godot/Godot_v4.7.2-stable_win64_console.exe' `
  -ArgumentList '--path','C:/Users/bryce/Documents/ChatGPT/DonutsGame',`
    '--script','C:/Users/bryce/AppData/Local/Temp/golden_world_perf.gd' `
  -WindowStyle Hidden -PassThru -Wait `
  -RedirectStandardOutput 'C:/Users/bryce/Documents/ChatGPT/DonutsGame/playtest-reports/art-performance.stdout.log' `
  -RedirectStandardError 'C:/Users/bryce/Documents/ChatGPT/DonutsGame/playtest-reports/art-performance.stderr.log'
$artPerf.ExitCode
```

## Inspected native screenshots

- `playtest-reports/art-final-gameplay.png`: final sign aspect ratio, booth framing, physical targets, readable rings and machine.
- `playtest-reports/art-final-service.png`: folded branded bag, visible cinnamon rings, warm articulated gloves, handoff state.
- `playtest-reports/art-final-jam.png`: persistent fault card, line to the brass lever, red physical station frame, beacon, and machine status plaque.
- `playtest-reports/art-final-powdered.png`: populated three-customer scene, hollow bucket/rolled rim, powdered coating, near-camera fill, and packaging print.
- `playtest-reports/rc-art-before.png`: retained 0.3 baseline for comparison.

Gameplay, service and jam captures use `-- --capture-view=gameplay`, `service`, and `jam` respectively, through the normal controller. Their corresponding `art-final-*.stdout.log` and `art-final-*.stderr.log` files record the native run. The powdered scene comes from the timing harness and deliberately excludes the HUD.

The last powder timing image was captured before the final reduced-motion-only adjustment. Normal rendering is unchanged by that adjustment; the persistent 28-check suite verifies the final reduced-motion behavior.

## Export-resource review

Read-only inspection of both Windows and Web presets confirmed their explicit resource lists include:

- `scripts/stand_world.gd` and the final stand scene/controller dependencies.
- `assets/art/title_keyart.png`, `brand_seal.png`, and `counter_sign.png`.
- `assets/shaders/oil.gdshader`, `donut_crust.gdshader`, `powder_sugar.gdshader`, and `fairground_sky.gdshader`.
- `assets/fonts/Fredoka-Medium.ttf` and the application icon.

The new shaders are original code assets. The brand seal and counter sign imports both set `mipmaps/generate=true`, and their world materials use linear mipmap anisotropic filtering. The mounted sign uses a 3.3 × 1.1 quad, preserving its 3:1 artwork ratio. The imported resources compiled and rendered in the native captures without shader errors.

The export filters exclude `tests`, `docs`, tools, build outputs, and validation captures. This review verifies source configuration and imported native resources. At report time the final 1.0 release artifacts were still being packaged; this report does not claim to have inspected their embedded PCK contents or completed their final packaged-executable smoke test.

## Limits

- **Browser/Web runtime validation was not performed in this art pass.** A Compatibility renderer and Web preset are present, but browser shader/runtime behavior and performance require the separate release check.
- iOS and Android device validation was not performed.
- The native timing fixture isolates the populated 3D world. It does not measure the entire controller/HUD/audio application or an uncapped GPU benchmark.
- The timing run is a short, repeatable stress sample, not a multi-hour soak. Equal scene-node counts and empty transient arrays show no retained scene-node growth in this sample; they do not prove the absence of every GPU, driver, or process-memory leak.
- Station ray tests use the default 1280 × 800 camera framing. Other aspect ratios and pointer/touch ergonomics remain part of broader release validation.
