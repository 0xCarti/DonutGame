# Golden Hour: iPhone demo handoff

Hashim: use the **Godot project in the repository root**, not the preserved
`unity/` project. This is the same game as the Android 1.0.7 edition, with native
touch controls, a mobile HUD, landscape layout, local saves, and graphics options.

**Current status:** the first unsigned ARM64 iPhone build compiled successfully
from source commit `a3e89cd`, using Godot 4.7.2, Xcode 26.6, and iPhoneOS SDK 26.5.
It is version **1.0.7**, build **107**, bundle ID `com.goldenhourgame.minidonuts`,
with an iOS 15.0 minimum. The IPA needs signing before installation. Real iPhone
installation/runtime testing and TestFlight remain pending. Source downloads
cannot be installed by opening them on a phone.

## Install the unsigned IPA with Sideloadly

If you already have the unsigned IPA, you can sign and install it with
[Sideloadly](https://sideloadly.io/) instead of rebuilding in Xcode:

1. Connect and unlock your iPhone, trust the computer, and select the phone in
   Sideloadly.
2. Drag the unsigned IPA into Sideloadly and use its Apple ID signing option.
   Enter your own Apple account directly in the app; no credentials belong in
   this repository.
3. Start signing/installing and follow any device trust or Developer Mode
   prompts. Then complete the iPhone acceptance checks below.

A free Apple account can be used; its signed installation needs refreshing
after seven days. Sideloadly supports re-signing/refreshing. This route does not
upload to TestFlight, and a successful compile alone does not verify phone play.

## Get the project running on your iPhone

1. Clone or download this repository and open its root folder.
2. Install the **standard Godot 4.7.2 stable macOS editor**, not the .NET edition.
   Install its matching export templates through **Editor > Manage Export
   Templates**. The game uses GDScript and has no third-party native plugins.
3. Install Xcode, launch it once, finish its setup, and install iOS platform
   support. Add your Apple account in Xcode Settings. Full Xcode is required;
   the standalone Command Line Tools package is insufficient.
4. With Python 3.9 or later available, run the commands below from the repository
   root. Replace the team ID and bundle ID with your actual values. The team ID
   is the ten-character code, not your display name. Use an identifier your team
   can register; the example is not a registered app.

```sh
python3 tools/prepare_ios.py --check
python3 tools/prepare_ios.py \
  --godot /Applications/Godot.app/Contents/MacOS/Godot \
  --team-id YOURTEAMID \
  --bundle-id com.yourcompany.goldenhourdemo
```

The helper checks the exact editor version, exports a **debug Xcode project**
into a fresh output directory, and prints the project path. It stages the game
separately so your signing identifiers never modify the tracked export preset.
It does not sign, install, upload, or submit anything. Existing builds and saves
are preserved. Importing the textures on the first run can take a while.

5. Open the printed `.xcodeproj`. Select the game target and **Signing &
   Capabilities**, enable **Automatically manage signing**, and select your
   team. Confirm the bundle identifier matches the one supplied above.
6. Connect and unlock your iPhone, trust the Mac, and select the phone as the
   Xcode run destination. Enable Developer Mode on the phone if Xcode requests
   it. Press **Run**. This builds, signs, and installs the game directly on that
   phone; it does not require a public App Store release.

The initial deployment target is **iOS 15.0 or later**, with ARM64 and the
Compatibility renderer. This is a build target, not a claim that every iOS 15
device has acceptable performance. Start on Balanced graphics; try Low on an
older phone and record the model and iOS version.

If you only have a free Personal Team, Xcode allows personal-device testing with
limits. Its provisioning profiles expire after seven days, so you will need to
rebuild/reinstall. TestFlight requires a paid Apple Developer Program team.

## TestFlight instead of a cable install

Use your paid developer team and choose the final demo bundle identifier before
creating its App Store Connect app record. Keep using that identifier for updates.

1. Export a release project with the same command and
   `--configuration release` added.
2. Open the generated Xcode project, select your team with automatic signing,
   and choose a generic iOS device destination. Build and validate on a real
   phone before sending the demo to others.
3. In Xcode, choose **Product > Archive**, then use Organizer to validate and
   distribute the archive to **App Store Connect**. Resolve any signing,
   privacy-manifest, SDK, or validation errors reported by the current Xcode.
4. In App Store Connect, complete the required beta information and any export
   compliance questions. The current demo is offline, has no login, ads,
   analytics SDK, purchases, or custom encryption; review the actual uploaded
   build when answering Apple's questions.
5. Add the processed build to TestFlight. The first build for external testers
   must pass Apple's beta review. Then share the TestFlight invitation with
   Bryce. TestFlight is separate from publishing the game on the public store.

The source preset uses marketing version **1.0.7**, build **107**. After a build
has been uploaded, increment the build number for the next upload in the
generated Xcode project's build settings. Keep the version consistent with the
app record. Do not commit certificates, private keys, provisioning profiles, or
account credentials to GitHub. The repository deliberately contains none.

An ad hoc IPA is another option for a paid team, but it must be signed for
registered test devices. Simply emailing an arbitrary unsigned IPA does not
install it. For this first demo, direct Xcode installation is the shortest route;
TestFlight is easier once several remote people need to test.

## If you prefer Godot's export window

Open `project.godot` in Godot 4.7.2. Choose **Project > Export > iOS**, enter your
team ID and unique bundle identifier locally, and keep **Export Project Only**
enabled. Export into a new empty folder using `GoldenHour` as the project name
(no spaces). Then follow the Xcode steps above. Do not commit your local signing
configuration. The command-line helper is preferable because it leaves the
tracked preset unchanged.

## Five-minute demo

Start **Practice** to learn without the campaign timer. Rotate the phone to
landscape. Tap objects to interact and drag across the scene to look; **Center**
returns the camera. **Tools** exposes large touch controls if an object is hard
to reach. The large action button follows the next step in the current order.

- Read the front customer's ticket: bag or bucket, cinnamon or powdered sugar.
- Take the matching container, pick up the scoop, scoop the catch tray, and pour
  into the container. Repeat to fill it: a bag takes six donuts, a bucket twelve.
- Add the requested coating, lift the finished package, and hand it to the
  customer. Watch the next-step prompt throughout.
- Hold the repair lever or batter hopper for maintenance and release to stop.
  Use **Pause** for settings, help, or returning to the title.

Practice does not replace a campaign save. For the timed game, return to the
title and choose **Open the Stand**. Purchases and online services are outside
this version.

## First iPhone acceptance checks

Before calling this an iOS playtest build, record the device model, iOS version,
Xcode version, game version/build, and source commit. Check:

- The title and game render correctly, with readable HUD and no notch or home
  indicator overlap in landscape. Try both landscape directions if supported.
- Complete a cinnamon bag, powdered bag, and bucket. Test both physical object
  taps and the large Tools controls; drags must not trigger accidental actions.
- Hold and release repair/refill, then background during a hold. Returning must
  leave the game paused and the held action stopped.
- Save a partly filled campaign order, close and relaunch the app, and resume it.
  Confirm its contents, progress, and graphics/audio settings survive.
- Play for at least ten minutes, including a busy/full tray and fire effects.
  Record visible stutters, heat, frame-rate observations, and the graphics preset.
- Check sound, phone interruptions, headphones, pause/resume, and the on-screen
  Help/Settings/license pages.

Existing evidence includes shared automated mobile testing, an Android emulator
playthrough, and the successful unsigned iPhoneOS compile on a Mac. It does not
yet include an iPhone runtime test. Report problems with a short screen recording
and the device/build details. Leave platform acceptance pending until these
checks are actually performed.

## Troubleshooting and references

- A missing iOS template means the matching Godot export templates are not yet
  installed. Use 4.7.2 templates with the 4.7.2 editor.
- If `xcode-select -p` points to standalone Command Line Tools, select the full
  Xcode installation in Xcode's Locations settings (or follow Godot's documented
  `xcode-select` repair). Install the iOS SDK in Xcode.
- A signing error usually needs the correct Apple team, a unique registered
  bundle identifier, a trusted device, or an updated provisioning profile.
- Re-export after changing game code/assets; the generated Xcode project embeds
  an exported game pack, not a live link to this repository.
- The helper supports `--help` and `--check` on Windows too, but actual iOS
  export requires macOS and Xcode. It never substitutes an Android or Web build.

Official references checked for this handoff:
[Godot 4.7 iOS export](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html),
[Godot iOS export options](https://docs.godotengine.org/en/4.7/classes/class_editorexportplatformios.html),
[Apple device testing](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices),
[Apple account/testing limits](https://developer.apple.com/help/account/basics/about-your-developer-account),
[TestFlight](https://developer.apple.com/testflight/).
