# Stand simulation integration

`StandSimulation` owns food identities, tickets, patience, production, maintenance and earnings. It contains no Unity dependencies and compiles as C# 7.3. The renderer owns rigid bodies, hit targets, held-tool state and animation.

## Starting and updating

```csharp
var model = new StandSimulation(seed: 17);
model.Start(GameMode.Shift); // Practice and Endless are also supported.
int epoch = model.Epoch;
// Spawn one settled physical donut per model.StockIds entry.

model.Tick(Time.deltaTime); // Do not call while paused/in menus.
foreach (var evt in model.DrainEvents())
{
    if (evt.Type == GameEventType.Production)
    {
        // Spawn a body travelling from the fryer to the tray.
        // Keep evt.DeliveryId and evt.Epoch with that body.
    }
}
```

Production consumes batter and creates a pending donut. It **does not** increase `Supply`. Once that body's physical landing is resolved, call `SettleDelivery(id, keptInTray, epoch)` exactly once. Its `Accepted` value is the final authority: a full tray rejects an otherwise valid landing. Duplicates and previous-run callbacks fail harmlessly. A donut already credited to stock can leave again; report its exact identity through `SpillStock(ids)`.

Opening stock is already settled. Do not call `SettleDelivery` on the IDs in `StockIds` immediately after `Start`. Clear previous-run visual bodies when starting another level. Donut IDs are not reused during a simulation object's lifetime, and the epoch also changes.

## Serving

1. `ChoosePackage(PackageKind.Bag)` or `Bucket` creates a six- or twelve-donut package.
2. `Scoop(reachableSettledBodyIds)` removes up to three available IDs in the supplied order. Pending, invalid and duplicate IDs cannot enter a scoop. Use the returned `DonutIds` to attach the same physical donuts to the scoop.
3. `Pour()` transfers the same identities into the package. Keep the scoop equipped in presentation.
4. `Coat(Coating.Cinnamon)` or `Powdered` works only on a full package. A coating cannot be replaced.
5. Animate picking up and handing over the package, then call `Serve()` once. A mismatch retains the food and ticket, resets the streak, and costs four seconds of patience outside Practice.

`Discard()` returns plain scoop/package food to available tray spaces, while coated food and overflow become waste. Reconcile the returned IDs against `StockIds` to position recovered bodies correctly. `PunchCustomer()` removes one front ticket, counts one missed customer and resets the streak; it leaves prepared food intact. Rapid tray disturbance should apply physical forces first, then report only bodies that actually leave as spills.

The first three tickets teach a cinnamon bag, powdered bag and cinnamon bucket. The queue is capped at three. Practice freezes ticket patience and the shift clock, but machine heat, production and faults still run. Practice immediately supplies a new ticket after a serve/skip. `TriggerPracticeFault` exercises real recovery for a jam, empty hopper or fryer fire.

## Feedback, money and maintenance

An `ActionResult` contains `Success`, `Code`, `Message` and action-specific IDs/counts. Failed actions never silently move food. Results are useful for immediate UI messages. Events are useful for audiovisual effects; `DrainEvents()` delivers each event once.

**Use the `Sale` event receipt for sale effects.** `Serve().Receipt` is the same receipt object; reacting to both would duplicate feedback. `Amount = BasePrice + PatienceTip + StreakTip`, with no hidden multiplier. The first perfect instant bag pays $22. The prior streak adds $0.50 per step, capped at $2.50.

`Repair(dt)` and `Refill(dt)` accept finite hold increments greater than zero and at most one second. They preserve partial progress when released. Feed risk above 50% permits preventive service. A jam needs 1.8 seconds; preventive service needs 1.2 seconds; a refill needs 2 seconds. Servicing/refilling pauses production while held. Both reject active fires.

Heat settings 0–4 target 90, 135, 175, 210 and 240 degrees. Setting 2 is stable. Setting 3 produces faster but eventually requires attention. Overheat stops production at 205 degrees and clears at 190. Continued dangerous heat ignites after 12 seconds; lowering the setting immediately reduces fire danger. `ExtinguishFire()` sets heat to zero, clears flames, and enforces a 2.4-second production recovery with 8 seconds of visible foam. It does not clear an unrelated jam or refill batter.

The separate feed-speed control uses `SetSpeed(0..4)` / `AdjustSpeed(change)` and emits `SpeedChanged`. Settings 0, 1, 2, 3 and 4 produce at 0, 0.65, 1, 1.3 and 1.6 times the temperature-dependent baseline. Default setting 2 preserves the original pacing. Setting 0 pauses new output without removing pending bodies, stock or partial production progress. It does not turn off the heater. Faster feed reaches the per-donut jam threshold sooner.

## End of level and validation

Opening Day is 105 seconds with a $110 target. Relaxed is 126 seconds with an $88 target and slower/more patient arrivals. After the timer, `Phase` is `Won` or `Lost`, `LastResult` contains the summary and a single `ShiftEnded` event fires. Pending physical landings may still resolve after closure; summary waste updates accordingly. Restart with `Start`. Endless keeps increasing arrival pressure without a timer or fabricated win condition.

The conservation invariant is:

```
OpeningStock + ProductionCount = Supply + Pending + ScoopCount + PackageCount + SoldDonuts + WasteCount
```

`ValidateConservation()` checks totals, unique active identities, capacity and coating invariants. Run the standalone acceptance suite from the repository root with `powershell -NoProfile -ExecutionPolicy Bypass -File tools/unity/test_core.ps1`. It compiles the same source with warnings as errors and runs 21 scenarios, including a full successful shift, independent heater/feed controls and 12,000 chaotic actions. The test executable and intermediate files are written under the system temporary directory.
