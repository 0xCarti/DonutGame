# Golden Hour: iPhone handoff

Use the Godot project at the repository root. The preserved `unity/` project is
not the source of this iOS build.

## Verified 1.2.0 final revision 3 build

An unsigned **Release ARM64 iPhoneOS build** was compiled on November 4, 2026.
Final revision **r3** includes the corrected operator cosmetic preview, feed-dial
direction, reliable shift reward retry, and clearer mobile status text. It is version **1.2.0**, build **120**, bundle ID
`com.goldenhourgame.minidonuts`, with an **iOS 15.0** minimum. This is the expanded
18-shift game with mobile controls. **No physical iPhone installation, runtime,
performance, signing, or TestFlight test has been performed for this build.**

The unsigned IPA is available at:

- Windows workspace: `builds/ios/1.2.0/r3/GoldenHour-1.2.0-iOS-unsigned.ipa`
- Mac desktop: `~/Desktop/GoldenHour-iOS-1.2.0-r3/GoldenHour-1.2.0-iOS-unsigned.ipa`
- Mac build source: `~/Documents/DonutGame-iOS-1.2.0-r3/`

Use the IPA with your **FlareStore self-signing workflow**. The IPA has no Apple
signature or provisioning profile; it requires signing before installation.
Signing/account setup belongs in your signing tool. No Apple account,
certificate, private key, or password was used to produce this build.

The earlier `~/Documents/DonutGame-iOS` checkout and its 1.0.7 build were preserved,
as were the initial 1.2.0 and r2 builds, desktop folders, and verification evidence.

## Build evidence

Verified toolchain: macOS 26.6.2, Godot 4.7.2 stable with matching iOS templates,
Xcode 26.6 (17F113), and iPhoneOS SDK 26.5. The native build completed with
`BUILD SUCCEEDED` using signing explicitly disabled.

The package checks verified:

- Release ARM64 executable and version/build/bundle/deployment metadata.
- No code signature or embedded provisioning profile.
- ZIP integrity and preserved executable permissions.
- Embedded game pack matches the exported pack byte-for-byte.
- All **90 runtime resource roots and three license notices** exist in the pack;
  script roots load from the pack in an otherwise empty directory.
- Local Python source/export-handoff regression suite: **21 tests passed**.
- Dial/world regression suite: **95 checks passed**, including Slow-left,
  Normal-upright, and Fast-right positions.

The IPA contains 64,116,652 bytes. Its SHA256 is:

```text
a633d60435c5bc4c1112ea858c7fa3d24b0a2f23f1c08bb7f91bc7af20a710da
```

At build time this was a workspace snapshot containing the new runtime files,
based on Git HEAD `d9a664a1a97db15042d00d69f1a6f34b9ffabde1`. That base commit alone
does not contain the expansion; use the current 1.2.0 source or the exact snapshot
below. The 205-file snapshot has these SHA256s:

```text
source-1.2.0.tar.gz
9a4c2619998a1f3f3fd0655c8ab41360fc2f4e168042633012a3628a9c10d0e0
source-manifest.json
a0f32b92977da7210f655828759a210979fd4ec5f66e590b2f41ab1787358a6e
```

`source-manifest.json` records each source file's hash. `build-verification.json`,
`pack-verification.log`, `import.log`, `export.log`, and `xcode-build.log` are in
`builds/ios/1.2.0/r3/`. The desktop handoff includes the IPA, checksums, build report,
and this document.

Xcode reported template warnings for empty microphone, camera, and photo-library
usage-description strings. This game does not request those permissions. It also
reported the template's `#pragma once` note and skipped App Intents extraction
because there is no AppIntents dependency. These warnings did not fail the build;
App Store submission has not been validated.

## Reproduce an unsigned build on the Mac

The helper validates the exact Godot version and stages only the explicit game
source directories. It does not modify the tracked signing preset. Choose a
**new empty output folder** for every export; existing output is preserved.

```sh
python3 tools/prepare_ios.py --check
python3 tools/prepare_ios.py \
  --godot /Users/tridenteventgroup/.cache/donutsgame/godot/Godot-4.7.2/Godot.app/Contents/MacOS/Godot \
  --team-id 0000000000 \
  --configuration release \
  --output builds/ios/1.2.0/new-release

xcodebuild \
  -project builds/ios/1.2.0/new-release/GoldenHour.xcodeproj \
  -scheme GoldenHour -configuration Release -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath builds/ios/1.2.0/new-release/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= DEVELOPMENT_TEAM= build
```

`0000000000` is only a placeholder accepted for project export; it is not an Apple
team or signing identity. For a signed Xcode installation or TestFlight, configure
your actual team and provisioning separately. No upload or store submission is
part of these commands.

Package the built `GoldenHour.app` beneath `Payload/` in a ZIP named `.ipa`,
preserving Unix executable permissions. The build's `package_unsigned_ipa.py`
helper and verification output are retained in the isolated Mac stage and local
build folder. Re-export after changing game code or assets: the generated Xcode
project embeds a game pack, not a live link to the source checkout.

## First iPhone acceptance checks

Record the device model, iOS version, graphics preset, and version/build. Start
with Practice and Balanced graphics in landscape. Confirm:

- Title, tickets, prompts, shop, settings, and touch controls remain readable
  around the notch and home indicator. Try both supported landscape directions.
- Complete a cinnamon bag, powdered bag, and bucket using physical taps and the
  large touch controls. Camera dragging must not trigger an unintended action.
- Try the tutorial, campaign, appeal feedback, feed-speed controls, maintenance,
  imperfect service, and shop/equipped shift buff flow.
- Hold and release repair/refill. Background during a hold; returning should
  pause the game and stop the held action.
- Save a partly filled campaign order, close the app, and resume. Confirm the
  order, progression, profile unlocks, and settings survive.
- Play for at least ten minutes, including a busy tray, fire, and a later venue.
  Record stutters, heating, sound interruptions, and any graphics adjustments.
- Confirm Practice does not overwrite the campaign save, and check Help and
  license pages.

A successful build and self-sign do not establish device compatibility or
performance. Keep physical iPhone acceptance pending until these checks run.
