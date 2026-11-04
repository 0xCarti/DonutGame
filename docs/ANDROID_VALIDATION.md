# Android 1.0.7 validation — 2026-11-04

Artifact: `builds/android/1.0.7/GoldenHour-1.0.7-Android.apk`.
Package: `com.goldenhourgame.minidonuts`, version code 107.
SHA256: `04c395fa2bdeaa770d2aaa956c56f37ca3aa93810c22092d07c2e87a3774e21e`.
Size: 118,412,176 bytes. The installed emulator APK hash matches this artifact.

## Automated and packaging checks

Godot 4.7.2 native headless checks passed with zero failures:

| Suite | Checks |
| --- | ---: |
| Touch gestures | 27 |
| Mobile controller and menus | 69 |
| Mobile HUD and hold cancellation | 37 |
| Graphics profiles and unchanged food physics | 159 |
| Desktop controller regression | 277 |
| Total | 569 |

APK v2 signing verified using Android apksigner. Package inspection confirms
API 24 minimum / API 36 target, ARMv7 + ARM64 + x86_64 libraries, and no Android
permissions. Engine/font notices are bundled; Unity, tests, and build tools are
excluded. The final text-only diagnostic adjustment was imported and exported
after these tests; it removes a stale frame-rate snapshot from Settings.

## Android runtime evidence

Used a dedicated Android 15 / API 35 Google APIs emulator with a Pixel 6 display
profile (2400×1080 in landscape), native x86_64, host OpenGL rendering on an
RTX 3060, and Godot Compatibility. This is not a real Pixel 6 benchmark.

Observed native touch interaction with packaging, the scoop, tray, pouring,
coating, heat controls, menu buttons, and Android Back. A half-filled bag (3/6),
heat setting 2, campaign timer, and selected Low graphics profile survived a
force-stop and relaunch. Background/resume returned to a paused screen at Low
and after switching to Balanced. Screenshots are in `playtest-reports/android/`,
including `android-final-restored-order.png`, `android-final-persisted-settings.png`,
and `android-final-balanced-resume.png`.

The exact shipping APK subsequently completed a full cinnamon bag order using
only the large touch action control, with the sale increasing practice revenue
to $22 and advancing to the powdered bag customer. Evidence:
`playtest-reports/android/android-shipping-sale.png`.

An earlier ARM64 candidate completed a touch-only powdered bag sale and a repair
hold under emulator CPU translation. That configuration later returned a black
screen after backgrounding. SwiftShader/swangle also failed shader linking with
an upstream-reported uniform-limit issue. Native x86_64 with host rendering did
not reproduce those failures. See [Android setup notes](ANDROID.md).

## Remaining acceptance

No physical Android phone was connected. Real ARM GPU compatibility, screen
cutouts/navigation gestures, touch ergonomics, audio output, sustained frame
pacing, temperature, battery use, and OS-specific lifecycle behavior require a
friend's phone test. Emulator results and frame caps do not prove those outcomes.
No Play Store submission, purchase system, or claim of universal compatibility
is included in this release.
