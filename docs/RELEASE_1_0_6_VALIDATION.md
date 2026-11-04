# Golden Hour 1.0.6 — fire, punch and HD presentation

The fryer now uses layered procedural flame sheets with turbulent, soft edges,
a bright connected core, rising smoke and small embers. Solid tapered flame
meshes are removed. A simulation-owned shader clock stops on pause; reduced
motion slows turbulence and limits sparks. The effect reuses two meshes and a
fixed budget of 25 visuals. Foam, fire warning, extinguishing and recovery keep
the existing gameplay and accounting rules.

Empty-hand customer clicks remain immediate skips. Contact now happens at
0.12 seconds (previously 0.31), and the hand is free by 0.36 seconds (previously
0.68). Customers squash/stretch, hop backward, flail, wobble and see five-point
stars. The reaction can finish while the player resumes work. Arm bone lengths,
queue ownership, reset/eviction cleanup and reduced-motion behavior are checked.

Fullscreen uses the entire display area with native pixel density, 4x MSAA and
16x anisotropic filtering. Baseline inspection found that 1.0.5 already used
native pixels inside its letterboxed 16:10 area; it was not rendering the entire
scene at 1280x800 and enlarging it. The improvements address full-window coverage,
small glyph rasters, coarse material detail and grazing-angle texture sampling.
Narrow windows expand the vertical camera field of view to keep both ends of
the counter accessible; widescreen keeps its 70-degree framing.
World glyphs have three times the resolution with unchanged physical dimensions;
shaker vectors are rasterized at 1024x1152. Fifteen new original 1024x1024 maps
provide steel, dough, cloth, paper and ground color/normal/roughness. Wood and
kraft-paper relief maps are recomputed at 1254x1254 from the untouched source
color images, replacing the earlier 512x512 relief. Existing bitmaps are not
simply enlarged. Saves and purchase behavior are unchanged.

## Release verification

Build **20261104-060708-558** passed **2,114 checks across 20 suites**, with zero
failures. Both exported packs passed isolated asset-scope verification, including
the fire shader and all new material maps. Logs:
`builds/logs/20261104-060708-558/`.

The final native capture exercised fire warning, active fire, foam, loaded scoop
return, held package return, punch/recoil, tray launch, gull, bells, sneeze and
menus at 1920x1080. The actual controller reports `valid=true`; stderr is empty.
Evidence: `playtest-reports/slapstick-1.0.6/report.json`, its 18 PNG snapshots,
and `playtest-reports/capture-1.0.6.*.log`. This staged capture is an integration
check; it does not save player progress.

The final display probe verified actual render buffers at 906x920, 1280x800,
1920x1080, 2560x1440 and F11 fullscreen on the 1920x1080 monitor. All fifteen
physical stations were both inside the visible viewport and correctly raycast
at each size. The narrow-window regression is covered explicitly. No renderer
errors or leaks. Evidence: `playtest-reports/display-quality-responsive/report.json`
and screenshots.

A separate real-time native sample on the RTX 3060 at 1920x1080, with fire active
and VSync enabled, measured 181 frames in 3.016 seconds after two seconds of
warmup: 60.0 FPS average, 16.67 ms median, 17.21 ms 95th percentile, 19.97 ms worst.
Capture readback was excluded from the timed interval; fire animation advanced
normally. Evidence: `playtest-reports/fire-performance/report.json`. This is a
short current-machine sample, not a minimum-spec benchmark. 4K and mobile
hardware were not tested.

The release ZIP was freshly extracted by `tools/verify_windows_package.ps1`.
Archive paths, manifest hash, executable equality, PE and runtime version 1.0.6,
and required notices passed. The extracted native executable passed its smoke
check in 8.029 seconds, exited 0 and produced empty stderr. All ten save/settings/
career paths were unchanged. Evidence:
`builds/logs/20261104-060708-558/12-packaged-native-result.json`.

The final Web build was tested in an isolated local browser origin: title,
practice, immediate punch/skip and cartoon recoil, active procedural fire, Q
extinguishing and recovery. Canvas backing pixels matched CSS dimensions at
1280x720 and 906x920; the narrow view retained the full counter. Console warnings
and errors were empty. Temporary viewport overrides and the QA tab were cleared;
the existing player session was preserved. Evidence:
`playtest-reports/browser-1.0.6-final.json` and the recorded browser observations.

## Packaged outputs

- `builds/windows/1.0.6/GoldenHour.exe`
- `builds/releases/GoldenHour-1.0.6-windows-20261104-060708-558.zip`
- `builds/releases/GoldenHour-1.0.6-web-20261104-060708-558.zip`

SHA256:

```text
Windows ZIP  38c329f9739693c1602ac1944ebbbc0306e4271be4d237d85865d1c102ed0d01
Windows EXE  066fabd248f3902cbf5f63693b5706c1b16ff28bba970e383fad41d12cf9069d
Web ZIP      8cf58021c1daf50c137f8c763dbd56a11ebe6f4beedc1638bdd325cc751e2046
```

Previous versioned exports and release archives remain available. This release
adds no external accounts, purchases or save migrations.
