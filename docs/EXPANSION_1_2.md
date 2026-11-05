# Golden Hour 1.2 — the stand goes on tour

Android and iPhone are the primary release targets. Every gameplay system below
is in the shared Godot project, with touch controls and local save migration.
The Windows edition uses the same rules. The separate Unity checkpoint is retained.

## Tour and machines

| Shifts | Venue | Earned machine | Base tray / hopper |
| --- | --- | --- | --- |
|1–6|Fairground|Compact|36 /72|
|7–12|Concert|Twin-Lane|48 /102|
|13–18|Stadium|Festival Pro|60 /132|

Concert breaks and stadium half-time change arrival patterns. Stage lighting,
crowds, sports seating and the field change the environment; the counter layout
stays familiar. Larger machines add visible feed hardware, extra conveyor lanes,
greater capacity, faster production and more time between jams. Machines and the
nineteen equipment upgrades are earned within the current run. They persist in
its checkpoint; opening a fresh campaign starts a new stand.

Practice → Pause → Explore Venues & Machines lets a tester try all three locations
without completing the tour. Practice awards no career progress or Tickets.

## Service and appeal

Appeal starts at 60 and is bounded 0–100. Quick, correct orders improve ratings;
long waits, walkouts, wrong orders and punches hurt them. Higher appeal brings
customers sooner, with bounded arrival changes so recovery remains possible.

A full, coated wrong order can be handed over. A wrong container **or** flavor
earns 40% of the lower applicable base price; getting both wrong earns 25%.
There are no tips, the streak breaks, and appeal falls. An empty, unfinished or
unseasoned package still needs preparation. The Friendly Apology upgrade softens
the appeal penalty without converting the order into a correct sale.

The feeder has Slow, Normal and Fast settings, independent of the heater.
Use its physical controls or **Tools → Fryer → Feed slower / Feed faster**.
Desktop shortcuts are `[` and `]`. Slow is a nonzero production speed.

## Ticket Booth

Open **Your Collection → Ticket Booth**, or visit between shifts. Tickets are
earned by completing shifts and collecting badges. These career Tickets are
separate from the equipment coins spent during a run.

Three coordinated sets—Neon Midway, Grandma's Recipe and Chrome Carnival—offer separately equippable
stand styling, gloves, sleeves, watches, tip jars, bells, shaker accents and
packaging accents. Individual pieces can be mixed. Confetti, carnival-ticket and
firework celebrations can be previewed and equipped. The original three earned
palettes keep their existing unlocks.

| One-shift supply | Effect | Tickets |
| --- | --- | --- |
|Fresh Oil|Heat 3 regulates around 190°C|25|
|Freshly Serviced|18 more donuts between jams|30|
|Good Vibes|10 seconds more patience;2 more appeal per correct sale|25|
|Emergency Batter|One automatic full refill when the hopper empties|20|
|Rush Contract|More arrivals;25% more correct-sale pay;15% higher quota|40|

Queue one supply before a shift. It is consumed when that shift opens, not while
browsing. The effect lasts for gameplay in that shift; pausing or backgrounding
does not use up a real-time timer. Save receipts prevent repeated consumption
after an interrupted start. Supplies are optional and the campaign is balanced
without them.

**Real-money checkout is not connected.** The catalog and gateway provide an
explicit unavailable state. No real product prices, payments, paid receipts or
restored purchases are simulated. Steam, Apple and Google billing need their
actual platform setup and a verified purchase/restore implementation before sale.

## Ten new badges

These join the six existing career badges. Locked secrets have hints in the
three-page bragging wall. The conditions below are spoilers for testers.

| Badge | Condition |
| --- | --- |
|Rush Hour|Five correct orders within 45 seconds|
|No Crumb Left Behind|Clear a shift with at least 8 served and zero waste at closing|
|This Is Fine|Correctly serve within 10 seconds after extinguishing a fire|
|Head Chef — secret|Click a customer with a loaded scoop to toss a donut hat, then correctly serve that customer|
|Express Checkout — secret|Punch three customers out of the queue in one shift|
|Air Mail — secret|A real tray-launched donut lands in an open, unseasoned bag|
|Close Enough|Complete an imperfect sale|
|Five-Star Comeback|Recover from appeal 25 or less to 85 or more in one run|
|Slow and Steady|Meet quota with every produced donut made at Slow speed|
|Definitely Human — secret|Feed the seagull three times, then correctly serve the trench-coat customer|

The hat uses a donut from the scoop and counts it as waste. Air Mail moves one
real stock object into the bag without duplicating inventory or charging waste.
Neither secret provides a real-money entitlement.

## Save and validation boundaries

Run schema 5 migrates the earlier run schemas; career schema 2 retains the original
palettes, records and badges. Career writes keep a valid backup, and purchases
roll back in memory if their save fails. Source builds and previous 1.0.6/1.0.7
packages are retained separately.

Automated checks cover the 18-shift tour with real action durations and conservative
physical transit, economy/save replay, physics, touch UI, interruption handling,
and old-save migration. Rendered screenshots check real in-game layouts.
The platform build manifests report signing/package verification separately from
physical-phone testing. An emulator or successful IPA compilation does not verify
performance, thermals, touch comfort or lifecycle behavior on a real phone.
