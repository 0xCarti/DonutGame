# Golden Hour 1.2.0 validation

Android and iPhone are the primary packages for this expansion. The source uses
Godot 4.7.2 stable and the Compatibility renderer. Previous Godot, Unity, and
mobile builds have been preserved.

## Gameplay and persistence

The mobile build regression pass ran 17 suites with **2,393 checks and no
failures**. Coverage includes the eighteen-shift campaign, appeal and imperfect
sales, production speed, consumables, cosmetic ownership, save migration and
retry, physical food, hand motion, gags, mobile input, safe areas, and menus.
The final operator-preview fix additionally passed **1,123 focused checks**
across expansion integration, mobile and desktop controllers, hand motion and
world gags. Native renders passed **513 checks**, including unobstructed previews
at 2400×1080 and 2532×1170, exact pose restoration, and unchanged held-tool and
simulation state. These follow-up counts overlap the regression suites rather
than representing that many additional distinct cases. Logs are retained with
the package verification evidence.

Campaign pacing was also exercised using actual interaction durations, a
0.1-second reaction allowance and conservative seven-second machine transit.
Twelve Normal and twelve Relaxed runs completed all eighteen shifts without
consumable buffs. This is a simulation check, not a claim about player difficulty.

The save-failure regression verifies that a completed shift cannot be advanced
until its career reward is safely recorded. Retrying credits the shift and badge
once. Consumable consumption uses a saved shift transaction ID so interrupted
starts cannot charge the same supply twice. Existing run and career saves migrate.

## Android

The signed APK is at
`builds/android/1.2.0/GoldenHour-1.2.0-Android.apk`. Package verification checks the
existing release signature, package identity, version 1.2.0/build 120, ARMv7,
ARM64 and x86_64 libraries, offline permissions, and bundled license notices.
The adjacent manifest and SHA256 file identify the delivered APK.

Native Android QA uses an API 35 x86_64 emulator, a 2400×1080 landscape display,
and host GPU rendering. It exercises actual Android touch input rather than
desktop mouse emulation. Evidence is in
`playtest-reports/android/1.2.0-native-verification.json` and its screenshots.

The installed final APK's SHA256 was verified on the emulator. Native touch checks
passed for a completed order, maintenance, all three venues, every catalogue
category, badge pages, operator previews, both Back routes, and background/resume.
Preview exit restored the ordinary hand pose and scoop interaction. App logcat
contained no script error, crash or ANR matches.

Cold launches showed a **17–18 second initial render stall** on this emulator,
with a cached-shader recompilation warning; the interface responded afterward.
This is a measured limitation of this test environment, not a physical-phone
benchmark or a confirmed diagnosis of its cause. Check startup time on real
devices before release. Purchased-supply HUD labels were checked in automated
and rendered tests but not naturally exercised with the emulator's preserved
zero-Ticket career.

## iPhone

The unsigned ARM64 Release package, source manifest, export logs and Xcode build
verification are identified in [IOS_HANDOFF.md](IOS_HANDOFF.md). The build uses
Xcode 26.6, iPhoneOS SDK 26.5, and an iOS 15.0 minimum. Pack validation verifies
90 runtime resource roots and three license notices; the export helper has
21 passing regression tests. IPA archive integrity and executable permissions
are checked. The package requires the tester's signing workflow before install.

## Remaining validation boundaries

The secondary Windows 1.2.0 ZIP was exported after the mobile packages. A fresh
extraction passed archive/checksum checks and a native smoke launch, confirmed
runtime and executable version 1.2.0, and left all ten existing player-save paths
unchanged. Its evidence is in
`builds/logs/20261105-003843-230/12-packaged-native-result.json`.

Neither mobile package has been tested on a physical phone in this work. Device-specific
touch comfort, cutouts, performance, thermals, battery use and prolonged resume
behavior still require real Android/iPhone testing. No App Store, TestFlight or
Google Play submission has been performed.

The Ticket Booth uses earned local Tickets. Real-money billing, purchase receipts,
purchase restoration, platform accounts and backend verification are not connected.
The game does not simulate successful real-money purchases.
