# Golden Hour playtest balance

This is the first playable interpretation of Game Idea #1: a fixed 3D mini-donut machine, increasingly demanding shifts, and upgrade combinations. It deliberately compresses a full run into six 65-second shifts plus shopping, so a tester can experience a complete build in roughly 8–12 minutes. Human playtesting should determine the final run length.

## Rules

- Six targets: $180, $340, $560, $850, $1,250, $1,800.
- Three trays, six donuts each. A batch makes six donuts for one chosen tray.
- Cinnamon starts at $4 per donut, powdered at $4.50, cocoa at $5. Recipe upgrades can change the best choice.
- A full matching tray multiplies its donut value by 2. A full mixed tray multiplies it by 1.6. Partial trays can be sold at any time for their individual value.
- Donuts begin landing after eight seconds and arrive progressively over the following 2.6 seconds. Upgrades can shorten the whole trip.
- The fryer holds at most 18 donuts in transit. Donuts waiting at a full tray stay in the fryer until the tray is sold; the game never silently discards them.
- Loading has a two-second cooldown. Each shift provides 120 batter plus 12 for each shift after the first. Supply and feed upgrades can change these constraints.
- The sales target is gross revenue. Shop credits are separate: 24 at the start of a run, then 10 + 3 per completed shift after the first + floor(sales / 18) after each successful shift.
- Four shop offers appear after each successful nonfinal shift. Each card can be purchased once in that shop. Offers are seeded, persist through saves, and always include an eligible direct value upgrade.
- The timer ends the shift. Meeting the target opens the shop, and meeting the sixth target wins. Unsold stock does not count as sales.

## Builds to explore

**Matching sets:** Cinnamon royalty / Powder money / Cocoa crown, Perfect dozen / 2, Fancy packaging, and Sweet dividends multiply together.

**Golden donuts:** The golden sixth makes one golden donut in each batch. Its 2.5x individual value is applied before tray bonuses; 24-karat glaze increases that multiplier.

**Variety:** Variety pack changes two donuts in each batch into the other recipes. Pick 'n' mix raises the full mixed-tray multiplier. Buying Variety pack alone trades away matching sets, so testers should assess whether the shop makes this trade-off sufficiently clear.

**Chains:** Rush hour rewards successive full tray sales within seven seconds. Echo box repeats part of the previous full tray's total every third full sale. Better production makes these builds easier to sustain.

**Timing:** Opening special strengthens the first three full trays of a shift; Last call rewards selling during the final 15 seconds. Overtime permit adds time but also delays that last-call window.

## Automated evidence

Run the standalone model test with:

```powershell
& 'C:\Users\bryce\.cache\donutsgame\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_run_model.gd
```

The suite checks action validation, conservation of donuts behind blocked trays, exact payout arithmetic, upgrade combinations, cooldown and resource rules, buying, phase transitions, victory/defeat, JSON save restoration, exact 64-bit RNG continuity, and rejection of malformed or nonfinite save data. It also simulates whole runs.

Measured on Godot 4.7.2:

| Scenario | Wins | Sales example by shift |
| --- | --- | --- |
| Immediate reactions, full trays, value-oriented purchases; 20 seeds | 20/20 | 975 / 1,560 / 2,527 / 4,476 / 6,313 / 9,233 |
| One action every 1.5 seconds, 12% of decisions skipped, at most two purchases per shop; 30 seeds | 25/30 | 720 / 1,264 / 1,303 / 1,785 / 2,062 / 2,084 |

The slower scenario cleared shifts 1–4 on all 30 seeds, shift 5 on 29, and shift 6 on 25. It still understands the rules and chooses the strongest recipe; this is **a reproducible balance scenario, not a measured human success rate**. Neither scenario chooses the mixed-tray build. The large optimized payouts are intentional evidence that combinations can snowball, though their entertainment value needs real playtests.

## Questions for the first human sessions

1. Can a new player explain the difference between sales revenue and shop credits after the first shop?
2. Do they discover and use all three trays without prompting?
3. Does a tray waiting for its sixth donut feel like anticipation or idle time?
4. Is a blocked tray visibly understandable, and can the player recover quickly?
5. Can players identify at least one meaningful upgrade combination?
6. Does final-shift pressure appear at a satisfying time? Record recipe/build and sold tray count alongside win/loss.
7. Does touch interaction cause accidental tray selection, recipe choice, or sale?
8. Is Variety pack's matching-versus-mixed trade-off clear before purchase?

Adjust target progression after these observations. A target increase alone does not improve decisions; if expert runs are effortless, test more interesting recipe or timing incentives before adding repetitive production work.
