GOLDEN HOUR: ON THE CIRCUIT — IDEA #4 DEMO 0.3.0

A portrait fairground business game. Book stops, choose recipes, look after your
crew and equipment, and build a reputation across the travelling fair circuit.
The demo plays offline and contains no purchases or payment integration.

LIVING CIRCUIT UPDATE — 0.3.0
Your illustrated stand now reflects your equipment, crew, weather and earned
decorations. A visual route map and calendar help plan the season. Queue up to
three future stops, see estimated costs and dates, and change the plan freely.
Planning does not reserve a venue or spend money; costs are charged only when
you actually book. Reputation, cash and remaining season dates still matter.

Three season contracts are selected from eight definitions. Their visible
progress tracks sales, completed stops, activities, profit, reputation, crew
training, excellent activity results or equipment upgrades. Claim a completed
contract for cash and a permanent decoration; rewards cannot be claimed twice.
Final-day rewards can be collected from the season summary before continuing.
Crew now have mood labels, personal moments, wage conversations, mentoring and
growing friendships. Raises affect each trading day's wages; spending time
together can improve morale, loyalty and skills. Daily results include animated
sales and concise explanations of the biggest influences on the day.

The optional opening batch still has heat, coat and pack timing stages. Three
new activities add a rotating repair puzzle, illustrated order memory and a
stand inspection. Handle an available job yourself, delegate to suitable crew,
or pay for help. Choices show costs and expected benefits. Activity attempts
have limited moves or mistakes where relevant, but no real-time deadline.
Closing an unfinished activity gives no reward. Sounds, reduced motion and
optional phone vibration can be controlled in Settings. Existing local saves
continue from versions 0.1.0, 0.1.1 and 0.2.0.

Portrait staff cards, visual skill ratings and expandable stories keep routine
decisions compact. Events separate immediate effects, temporary bonuses and
risks. Effect cards state duration and let you inspect the actual result.

PLAYING YOUR FIRST SEASON
Name your company, then choose Willowbank in Circuit for a modest first stop.
Booking pays all pitch fees and fuel up front and uses a travel day. Resolve
the travel decision, then prepare at your own pace: choose a recipe, set a
price, buy stock, and maintain equipment. Tap Open the stand to trade one day.
Respond to the day's event, read the receipt, then close the books to continue.

The owner can run the first fairs alone. Hire people when their extra capacity,
skill and kindness justify their wages. Match recipes to local favourites;
earned recipes remain in your book even if reputation falls. Equipment unlocks
larger operations; a better fryer alone cannot solve a staffing bottleneck.

Your season closes at 36 days or 8 completed stops. A company score and journal
record the result. Begin another season with your equipment, crew, recipes and
town relationships. Stories can continue at later stops and in later seasons.
If money is tight, Company offers working-capital loans and Circuit offers a
small roadside pop-up. A gentler first season grants extra starting cash.

INCLUDED
12 fictional venues; 10 recipes; 14 recruitable staff; four tiers each of truck,
fryer and stand; 61 events and 184 choices; 10 connected storylines; 12 milestones;
four optional mini-games including the three-stage opening batch; eight season
contract definitions with three active per season; a three-stop route planner;
crew moments and friendships; a living stand and animated sales results;
settings for sound, music, motion, guidance and phone vibration; local automatic
saves with a recovery copy.

READING THE RECEIPT
Supplies cost $1 per bag when purchased. Consumed stock and prepaid pitch/travel
costs count toward operating profit, but are never deducted from cash twice.
Recipe/quality extras, wages and interest are charged during trading. The
receipt separates cash change from operating profit; tap Story & receipt to
inspect demand, capacity, weather and the effects of your decisions.

CONTROLS
Tap/click buttons and scroll the journal or long pages. Android Back or Esc
closes ordinary sheets. Decisions and trading receipts must be resolved before
time can move. Space also plays each opening-batch stage. There is no
real-time waiting, and browsing never advances a day. Company contains help,
settings, credits, loans, milestones and new-company controls.

ANDROID
Install GoldenHourCircuit-0.3.0-Android.apk on Android 7.0 or later. Your Android
device may ask you to allow installation from the app that opened the APK.
The package is com.goldenhourgame.circuit; it can coexist with the original
Golden Hour mini-donut game. Saves stay on the device. Backups are not uploaded.
New APKs signed with the same private release key can update this package.
The only requested Android permission is VIBRATE, used for short optional
tactile feedback on supported phones. Turn vibration off in Settings if desired.
The game does not request Internet access, contacts, location, camera or storage
permissions, and contains no advertising or real-money purchases.

WINDOWS COMPANION
Extract the complete Windows ZIP, then open GoldenHourCircuit.exe. It uses a
portrait window with mouse and touch-friendly controls. SmartScreen may ask
about an unsigned independent application. Saves use Golden Hour Circuit's
separate Godot user-data directory.

WEB DEMO
Serve the web folder through an HTTP server and open index.html. For example,
with Python installed, run: python -m http.server 8766 --directory web
Then visit http://localhost:8766 in a modern browser. The demo is single-threaded;
it does not require cross-origin isolation headers. Browser saves belong to
that browser and site address. Opening index.html directly is unsupported.

iOS
The iOS source handoff uses the same game and an opaque Apple app icon. An
unsigned IPA, when present, is an ARM64 iPhoneOS build for iOS 15 or later.
It is not directly installable until signed with an Apple developer identity
and provisioning profile. No Apple account, store upload, or payment is used.
An unsigned IPA is not evidence of a physical iPhone playtest.

BUILD EVIDENCE
Versioned outputs live under ../builds/circuit/0.3.0/rN/. Each new build gets a
new revision folder. build-manifest.json identifies exact artifacts and hashes;
logs/ contains export and verification output. Physical-device validation is
recorded separately from automated checks and emulator testing.

DEVELOPER COMMANDS
Use the cached Godot 4.7.2 stable engine and matching export templates.
python tools/build_release.py --platform all
python tools/build_release.py --platform android
python tools/build_release.py --platform windows
python tools/build_release.py --platform web
python tools/build_ios.py --check
On a Mac with Xcode and Godot 4.7.2:
python3 tools/build_ios.py --godot /Applications/Godot.app/Contents/MacOS/Godot

Android signing credentials are read only from the existing private cache and
are never copied into source, logs, command arguments, or the source handoff.
The source archive accompanying each release is suitable for the Mac build.
The build scripts never modify or overwrite the original 3D game's releases.
