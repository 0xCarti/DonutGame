# Golden Hour for Android — 1.0.7

Godot is the active development project. Android 1.0.7 brings the existing Godot
campaign to a landscape, touch-first interface. The Unity Windows 1.1.0 edition
is a separate preserved checkpoint.

The release target is `builds/android/1.0.7/GoldenHour-1.0.7-Android.apk`, with
package ID `com.goldenhourgame.minidonuts`. One APK includes ARMv7, ARM64, and x86_64
libraries. The minimum is Android API 24 (Android 7.0); the prebuilt export
template targets API 36. These settings do not prove that every eligible phone
can run the game well.

**Current validation:** signing, package contents, and 569 automated checks pass.
The Android 15 / API 35 emulator runs the native x86_64 build with host GPU
rendering. Touch interaction, campaign/order and settings persistence, Android
Back, and background/resume passed. The earlier ARM64 candidate completed a
touch-only sale under CPU translation, but that translated configuration failed
a background/resume check. Native emulator checks are not physical-phone tests.
Installation and gameplay on a physical Android device have not been verified.
Desktop mobile-preview tests do not establish phone compatibility, frame rate,
battery use, temperature, or reliable resume behavior on a particular handset.

## Build on Windows

Use Python 3.11 or newer, the project's portable Godot **4.7.2 stable** editor,
and its matching export-template archive. The existing cache is under
`%USERPROFILE%\.cache\donutsgame\godot\`; setup expects the matching
`Godot_v4.7.2-stable_export_templates.tpz` archive there.

From the repository root:

```powershell
python tools/setup_android_toolchain.py
python tools/build_android.py
```

Setup obtains the portable JDK 17 and Android SDK tools, verifies their published
checksums, and installs the Android templates from the cached archive. It keeps
the toolchain under `%USERPROFILE%\.cache\donutsgame\android\`, without replacing
an existing system SDK or changing the system PATH. The resolved paths are
recorded in `playtest-reports/android/toolchain.json`.

The Android builder reads those paths, backs up Godot's editor settings before
configuring its Java/Android SDK paths, imports the project, runs the Android
regression checks, and exports a signed release APK. Its package checks use
`apksigner` and `aapt`, including the package identity and all three architectures.
On success, the output folder also contains `build-manifest.json`,
`GoldenHour-1.0.7-Android.apk.sha256`, and `INSTALL-ANDROID.md`. The manifest
records the package checks separately from pending physical-device validation.
Review the build result and logs under `playtest-reports/android/`; a file at
the target path alone is not a successful-build report. Keep Godot import/export
jobs sequential for this shared project.

For a repeat export after the current source has already passed its checks:

```powershell
python tools/build_android.py --skip-tests
```

This option does not replace the initial regression run or physical-device QA.
The Android path is separate from `tools/build_stand_playtest.ps1`, which builds
the Godot Windows/Web editions.

## Keep the signing identity

The first Android build creates a persistent signing key and local credentials
under `%USERPROFILE%\.cache\donutsgame\android\signing\`, outside the repository.
Back up **both** privately. Do not place them in the APK, source repository, or
friend's download folder. A store account is not needed for this direct APK
distribution.

Keep the package ID and signing identity when publishing updates. Android checks
the signing certificate and version code when accepting an update; uninstalling
an existing app to work around a mismatch erases its local app data. See
[Android's update rules](https://developer.android.com/google/play/app-updates).
Golden Hour's saves and career progress stay on the device; there is no cloud
save transfer between Android, Godot desktop, and the Unity edition.

## Send it to a friend

After the build's signing/package checks succeed, share the exact
`GoldenHour-1.0.7-Android.apk` and identify it as a test build until phone QA is
complete. Include `Read Me - Android.txt` for the player; the `.apk.sha256` checksum and
`INSTALL-ANDROID.md` provide additional build and installation details. Do not
rename an archive to `.apk` or send the private signing files.

1. Download the APK onto the Android phone and open it from Downloads or the
   phone's file app.
2. If Android requests permission, open the settings offered for that browser
   or file app and allow installation from that source. Return to the APK and
   choose **Install**. Menu wording varies by device; Google's
   [installation instructions](https://support.google.com/pixelphone/answer/7391672?hl=en)
   describe this source-specific permission.
3. Open **Golden Hour**, hold the phone in landscape, and choose **Practice**.
   Start with **Balanced** graphics in Settings.
4. The source-install permission can be turned off again after installation.

Some Android versions or regions may show additional developer-verification
steps; follow the phone's supported flow. If installation is blocked, send the
exact message, phone model, and Android version to the maintainer. See Google's
[developer-verification guidance](https://support.google.com/android/answer/17065026?hl=en).
For an existing installation, request a matching signed update before considering
uninstallation, since local progress would be removed.

## Touch controls and settings

- **Tap objects** on the counter to choose packaging, pick up the scoop, collect
  donuts, pour, add sugar, lift the order, and serve the customer.
- **Drag to look**; a drag does not also activate the object underneath it.
  **Center** restores the camera.
- **Hold** the repair lever or batter hopper to repair/refill. Release or drag
  away to stop. The optional **Tools** tray provides larger Order/Fryer controls.
- The large contextual button follows the next task and exposes urgent recovery
  actions. The ticket, heat, batter, tray stock, and package contents remain visible.
- **Pause**, **Help**, and **Settings** are touch buttons. Android Back opens or
  backs out through menus instead of requiring a keyboard shortcut.

Backgrounding cancels input, saves the active run/settings, and pauses play.
Returning to the app keeps a paused game for deliberate resumption. Safe-area
mapping keeps the logical HUD within the device's reported usable display area;
cutouts and gesture/navigation bars still need checking on real hardware.

Settings include audio levels, Reduced Motion, look sensitivity, graphics, and
device diagnostics. Device details are for troubleshooting and do not use a
unique device identifier. **Credits & Licenses** opens the bundled Godot engine,
engine third-party, and Fredoka font notices offline. Their source files are
`docs/licenses/Godot-LICENSE.txt`, `docs/licenses/Godot-COPYRIGHT.txt`, and
`assets/fonts/OFL.txt`; retain them in Android exports.

| Profile | 3D render scale | Frame cap | Antialiasing | Shadows |
| --- | --- | --- | --- | --- |
| Low | 65% | 30 FPS | Off | Sun and detail shadows off |
| Balanced | 80% | 60 FPS | Off | Sun shadows on; detail shadows reduced |
| High | 100% | 60 FPS | 2× MSAA | Sun and detail shadows on |

These are rendering settings and frame caps, **not benchmark results**. HUD
resolution and touch coordinates are independent of 3D render scale. Use Low
if play stutters or the phone gets hot; try High only if play stays smooth.

## Desktop preview and phone acceptance

The mobile layout can be exercised without changing desktop save files:

```powershell
$androidGodot = Join-Path $env:USERPROFILE '.cache\donutsgame\godot\Godot_v4.7.2-stable_win64_console.exe'
& $androidGodot --path . -- --mobile-test --test-mode
```

Regression coverage lives in `tests/test_mobile_input.gd`,
`tests/test_mobile_ui.gd`, `tests/test_mobile_quality.gd`, and
`tests/test_mobile_controller.gd`. Those checks cover gesture separation, UI
actions and hold cancellation, quality settings, safe-area mapping, and lifecycle
integration. They are not a substitute for the following pending phone checks:

1. Record the exact APK hash, phone model, Android version, display dimensions,
   renderer, and selected graphics profile. Verify installation and first launch.
2. Complete bag and bucket orders using touch alone. Test drag/tap separation,
   repair/refill holds, cancellation, camera recenter, settings, and readable text.
3. Check both landscape orientations, cutouts, and navigation/gesture areas.
   Exercise Pause and Android Back from gameplay, help, settings, and title.
4. Background and resume during a hold and during normal play. Relaunch and
   verify saved campaign progress and settings without unintended production.
5. Play long enough to assess stable frame pacing, heat, battery impact, audio,
   and crowded/fire scenes. Compare profiles rather than assuming a 60 FPS cap
   means the device achieves 60 FPS.
6. Open the bundled notices offline and verify a later, correctly signed APK
   updates the app while retaining local progress.

Record results before calling the Android build device-validated or broadly
compatible. App-store publication, payments, and iOS builds are separate work.

## Emulator troubleshooting

Use a matching native ABI and `-gpu host` for this project. On this machine,
SwiftShader and swangle failed Godot shader linking with a uniform-limit error;
this is an upstream-reported emulator issue, not evidence of real-phone GPU
compatibility. See [Godot issue 109550](https://github.com/godotengine/godot/issues/109550).
ARM64-to-x86 translation launched and served an order but later returned a black
screen after backgrounding; native x86_64 resumed successfully at both Low and
Balanced settings. Keep these limitations distinct from physical ARM phone QA.
No speculative framebuffer-reset workaround has been added to the game.

`--trace-input` enables optional local development input diagnostics. It is off
in the shipped APK. Mouse-based mobile preview requires `--mobile-test` on a
desktop; actual Android world interactions use native touch events.
