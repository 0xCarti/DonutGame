#if GOLDEN_HOUR_CORE_TESTS
using System;
using System.Collections.Generic;
using GoldenHour;

namespace GoldenHour.Tests
{
    /// <summary>Dependency-free executable acceptance suite; tools/unity/test_core.ps1 runs it outside Unity.</summary>
    internal static class CoreSimulationTests
    {
        private static int passed;

        private static int Main()
        {
            try
            {
                Test("opening stock and tutorial tickets", OpeningStock);
                Test("physical deliveries cannot be scooped before landing", PhysicalDelivery);
                Test("stale and duplicate callbacks cannot mint food", DuplicateDelivery);
                Test("only physical reachable IDs enter the scoop", ReachableScoop);
                Test("overflow and exact physical spills conserve food", OverflowAndSpill);
                Test("complete sale pays once with earned streak tips", CorrectSale);
                Test("wrong package is retained and a recoverable order can be finished", WrongOrderRecovery);
                Test("wrong coating requires disposal without refunding seasoned food", WrongCoating);
                Test("discard returns plain IDs and counts overflow waste", DiscardOverflow);
                Test("customer punch skips one ticket and keeps prepared food", PunchSkip);
                Test("patience and queue limit hold through a full failed shift", WalkoutsAndFinish);
                Test("practice freezes tickets and clock but operates machines", Practice);
                Test("partial repair persists and prevention resets risk", Repair);
                Test("batter refill pauses output and needs the full hold", Refill);
                Test("high heat starts fire, extinguisher recovers without gifting food", FireRecovery);
                Test("lowering heat in warning interval prevents a fire", FirePrevention);
                Test("a human-paced complete shift can meet the target", CompleteShift);
                Test("seeded outcomes stay reproducible", Determinism);
                Test("invalid deltas and actions do not corrupt state", InvalidInput);
                Test("feed speed is independent, changes throughput and pauses without losing food", IndependentFeedSpeed);
                Test("chaotic mixed actions preserve every donut", RandomizedConservation);
                Console.WriteLine("PASS: " + passed + " core acceptance scenarios.");
                return 0;
            }
            catch (Exception exception)
            {
                Console.Error.WriteLine("FAIL: " + exception);
                return 1;
            }
        }

        private static void Test(string name, Action test)
        {
            test();
            passed++;
            Console.WriteLine("PASS " + name);
        }
        private static void Expect(bool condition, string message)
        {
            if (!condition) throw new Exception(message);
        }
        private static void Conserved(StandSimulation model)
        {
            var report = model.ValidateConservation();
            Expect(report.IsValid, report.Error + " Created=" + report.TotalCreated + " accounted=" + report.TotalAccounted);
        }
        private static StandSimulation New(GameMode mode = GameMode.Practice, int seed = 17)
        {
            var model = new StandSimulation(seed);
            model.Start(mode);
            model.SetHeat(2);
            return model;
        }
        private static void SettleAll(StandSimulation model)
        {
            foreach (int id in new List<int>(model.PendingDeliveryIds)) model.SettleDelivery(id, true, model.Epoch);
            Conserved(model);
        }
        private static void Advance(StandSimulation model, double seconds, bool maintain = false)
        {
            while (seconds > 0.0000001 && model.Phase == GamePhase.Playing)
            {
                double dt = Math.Min(seconds, 0.1);
                if (maintain && model.JamRisk >= 0.6) model.Repair(dt);
                if (maintain && model.Batter < 12) model.Refill(dt);
                model.Tick(dt);
                SettleAll(model);
                seconds -= dt;
            }
        }
        private static ActionResult MakeOrder(StandSimulation model, bool advance = false)
        {
            var order = model.CurrentOrder;
            Expect(order != null, "No ticket available for test.");
            Expect(model.ChoosePackage(order.Package).Success, "Package should be selectable.");
            if (advance) Advance(model, 0.5, true);
            int guard = 0;
            while (model.PackageCount < model.PackageCapacity && guard++ < 200)
            {
                if (model.Supply < Math.Min(3, model.PackageCapacity - model.PackageCount)) Advance(model, 0.5, true);
                else
                {
                    Expect(model.Scoop(new List<int>(model.StockIds)).Success, "Scoop failed.");
                    if (advance) Advance(model, 0.45, true);
                    Expect(model.Pour().Success, "Pour failed.");
                    if (advance) Advance(model, 0.45, true);
                }
            }
            Expect(guard < 200, "Preparation did not progress.");
            Expect(model.Coat(order.Coating).Success, "Coating failed.");
            if (advance) Advance(model, 0.6, true);
            var result = model.Serve();
            Expect(result.Success, "Correct service rejected: " + result.Message);
            Conserved(model);
            return result;
        }

        private static void OpeningStock()
        {
            var model = New();
            Expect(model.StockIds.Count == 18 && model.PendingDeliveryIds.Count == 0, "Opening stock wrong.");
            Expect(new HashSet<int>(model.StockIds).Count == 18, "Opening identities duplicate.");
            Expect(model.CurrentOrder.Package == PackageKind.Bag && model.CurrentOrder.Coating == Coating.Cinnamon, "First teaching ticket wrong.");
            MakeOrder(model);
            Expect(model.CurrentOrder.Package == PackageKind.Bag && model.CurrentOrder.Coating == Coating.Powdered, "Second teaching ticket wrong.");
            MakeOrder(model);
            Expect(model.CurrentOrder.Package == PackageKind.Bucket && model.CurrentOrder.Coating == Coating.Cinnamon, "Third teaching ticket wrong.");
            Conserved(model);
        }

        private static void PhysicalDelivery()
        {
            var model = New();
            model.DrainEvents();
            model.Tick(1.3);
            Expect(model.ProductionCount == 1 && model.Supply == 18 && model.PendingDeliveryIds.Count == 1, "Production prematurely credited inventory.");
            int id = model.PendingDeliveryIds[0];
            model.ChoosePackage(PackageKind.Bag);
            Expect(!model.Scoop(new[] { id }).Success && model.ScoopCount == 0, "Flying food was scooped.");
            var events = model.DrainEvents();
            GameEvent produced = Array.Find(events, e => e.Type == GameEventType.Production);
            Expect(produced != null && produced.DeliveryId == id && produced.Epoch == model.Epoch, "Production lacks identity/epoch.");
            Expect(model.SettleDelivery(id, true, model.Epoch).Accepted && model.Supply == 19, "Landing did not credit.");
            var result = model.Scoop(new[] { id });
            Expect(result.Success && result.Count == 1 && result.DonutIds[0] == id, "Physical identity lost during scoop.");
            Conserved(model);
        }

        private static void DuplicateDelivery()
        {
            var model = New();
            model.Tick(1.3);
            int id = model.PendingDeliveryIds[0];
            int oldEpoch = model.Epoch;
            Expect(!model.SettleDelivery(id, true, oldEpoch - 1).Success && model.PendingDeliveryIds.Count == 1, "Wrong epoch consumed current delivery.");
            model.SettleDelivery(id, true, oldEpoch);
            Expect(!model.SettleDelivery(id, true, oldEpoch).Success && model.Supply == 19, "Repeated callback minted food.");
            model.Start(GameMode.Practice);
            Expect(!model.SettleDelivery(id, true, oldEpoch).Success && model.Supply == 18, "Old body altered fresh run.");
            Expect(!new HashSet<int>(model.StockIds).Contains(id), "New run reused old physical ID.");
            Conserved(model);
        }

        private static void ReachableScoop()
        {
            var model = New();
            model.ChoosePackage(PackageKind.Bag);
            var ids = new List<int>(model.StockIds);
            var result = model.Scoop(new[] { -1, ids[8], ids[8], 99999, ids[12], ids[5], ids[3] });
            Expect(result.Count == 3 && result.DonutIds[0] == ids[8] && result.DonutIds[1] == ids[12] && result.DonutIds[2] == ids[5], "Reachability/order/deduplication broken.");
            Expect(!model.Scoop(ids).Success && model.Supply == 15, "Rapid scoop consumed extra food.");
            model.Pour();
            Expect(model.PackageIds[0] == ids[8] && model.ScoopCount == 0, "Pour did not transfer exact identities.");
            Conserved(model);
        }

        private static void OverflowAndSpill()
        {
            var model = New();
            Advance(model, 32);
            Expect(model.Supply == 36 && model.WasteCount > 0, "Full tray incorrectly stops production or accepts overflow.");
            var ids = new List<int>(model.StockIds);
            int waste = model.WasteCount;
            var spilled = model.SpillStock(new[] { ids[2], ids[2], ids[6], -1, 9999 });
            Expect(spilled.Count == 2 && model.Supply == 34 && model.WasteCount == waste + 2, "Spill lost or duplicated stock.");
            model.SpillStock(new[] { ids[2] });
            Expect(model.WasteCount == waste + 2, "Spill callback applied twice.");
            Conserved(model);
        }

        private static void CorrectSale()
        {
            var model = New();
            model.DrainEvents();
            var first = MakeOrder(model);
            Expect(first.Receipt.Amount == 22m && first.Receipt.PatienceTip == 4m && first.Receipt.StreakTip == 0m, "First receipt math incorrect.");
            Expect(model.Sales == 22m && model.SoldDonuts == 6 && model.Served == 1 && model.Streak == 1, "Sale state incorrect.");
            Expect(!model.Serve().Success && model.Sales == 22m, "Repeat handoff paid again.");
            var second = MakeOrder(model);
            Expect(second.Receipt.Amount == 22.5m && model.Streak == 2, "Earned streak tip missing.");
            var saleEvents = Array.FindAll(model.DrainEvents(), e => e.Type == GameEventType.Sale);
            Expect(saleEvents.Length == 2 && object.ReferenceEquals(saleEvents[0].Receipt, first.Receipt), "Receipt event duplicated or recalculated.");
            Expect(model.DrainEvents().Length == 0, "Events were redelivered.");
            Conserved(model);
        }

        private static void WrongOrderRecovery()
        {
            var model = New(GameMode.Shift);
            model.ChoosePackage(PackageKind.Bag);
            model.Scoop(); model.Pour();
            int orderId = model.CurrentOrder.Id;
            double before = model.CurrentOrder.Patience;
            var wrong = model.Serve();
            Expect(!wrong.Success && wrong.Code == "wrong_order", "Underfilled order accepted.");
            Expect(model.PackageCount == 3 && model.CurrentOrder.Id == orderId && model.CurrentOrder.Patience == before - 4, "Wrong order destroyed recovery path.");
            model.Scoop(); model.Pour(); model.Coat(Coating.Cinnamon);
            Expect(model.Serve().Success && model.Mistakes == 1 && model.Served == 1, "Underfilled order could not be completed.");
            Conserved(model);
        }

        private static void WrongCoating()
        {
            var model = New();
            model.ChoosePackage(PackageKind.Bag);
            model.Scoop(); model.Pour(); model.Scoop(); model.Pour();
            model.Coat(Coating.Powdered);
            Expect(!model.Coat(Coating.Cinnamon).Success, "Seasoning could be overwritten.");
            Expect(!model.Serve().Success && model.PackageCount == 6, "Wrong coating was sold/lost.");
            var cleared = model.Discard();
            Expect(cleared.Wasted == 6 && cleared.Returned == 0 && model.Supply == 12, "Seasoned donuts became plain stock.");
            MakeOrder(model);
            Conserved(model);
        }

        private static void DiscardOverflow()
        {
            var model = New();
            model.ChoosePackage(PackageKind.Bucket);
            model.Scoop(); model.Pour(); model.Scoop();
            var held = new List<int>(model.PackageIds);
            held.AddRange(model.ScoopIds);
            Advance(model, 32, true);
            Expect(model.Supply == 36, "Test must have a full tray.");
            int waste = model.WasteCount;
            var cleared = model.Discard();
            Expect(cleared.Returned == 0 && cleared.Wasted == 6 && model.WasteCount == waste + 6, "Discard overflow incorrectly refunded food.");
            model.ChoosePackage(PackageKind.Bag); model.Scoop(); model.Pour();
            var exact = new List<int>(model.PackageIds);
            cleared = model.Discard();
            Expect(cleared.Returned == 3 && cleared.Wasted == 0, "Plain recovery failed.");
            foreach (int id in exact) Expect(new List<int>(model.StockIds).Contains(id), "Recovered donut got a new identity.");
            Conserved(model);
        }

        private static void PunchSkip()
        {
            var model = New(GameMode.Shift);
            model.ChoosePackage(PackageKind.Bag); model.Scoop(); model.Pour();
            Advance(model, 16);
            int oldId = model.CurrentOrder.Id;
            int count = model.Orders.Count;
            model.DrainEvents();
            var result = model.PunchCustomer();
            Expect(result.Success && model.Missed == 1 && model.Orders.Count == count - 1 && model.CurrentOrder.Id != oldId, "Punch did not skip exactly one customer.");
            Expect(model.PackageCount == 3 && model.Sales == 0, "Punch stole food or granted sales.");
            Expect(Array.FindAll(model.DrainEvents(), e => e.Type == GameEventType.CustomerPunched).Length == 1, "Punch visual event missing.");
            Conserved(model);
        }

        private static void WalkoutsAndFinish()
        {
            var model = New(GameMode.Shift);
            for (int i = 0; i < 1050; i++)
            {
                Advance(model, 0.1);
                Expect(model.Orders.Count <= 3, "Queue exceeded three customers.");
            }
            Expect(model.Phase == GamePhase.Lost && model.TimeLeft == 0 && model.Missed >= 3, "Timed loss or walkouts failed.");
            Expect(model.LastResult != null && !model.LastResult.Cleared && model.LastResult.Sales == 0, "Failure summary wrong.");
            Expect(!model.ChoosePackage(PackageKind.Bag).Success && !model.Repair(1).Success, "Closed stand accepts service actions.");
            int produced = model.ProductionCount;
            model.Tick(100);
            Expect(model.ProductionCount == produced, "Closed stand kept producing.");
            Conserved(model);
        }

        private static void Practice()
        {
            var model = New();
            int ticket = model.CurrentOrder.Id;
            double patience = model.CurrentOrder.Patience;
            Advance(model, 200);
            Expect(model.TimeLeft == model.Duration && model.Phase == GamePhase.Playing && model.Missed == 0, "Practice inherited timed failure.");
            Expect(model.CurrentOrder.Id == ticket && model.CurrentOrder.Patience == patience, "Practice ticket expired.");
            Expect(model.ProductionCount > 0 && model.Jammed, "Practice machine was frozen.");
            Conserved(model);
        }

        private static void Repair()
        {
            var model = New();
            Advance(model, 32);
            Expect(model.Jammed && model.JamRisk == 1, "Expected a real production jam.");
            int made = model.ProductionCount;
            model.Repair(0.6);
            double progress = model.RepairProgress;
            model.Tick(2);
            Expect(model.RepairProgress == progress && model.ProductionCount == made, "Partial repair decayed or jam produced food.");
            model.Repair(0.6); model.Repair(0.6);
            Expect(!model.Jammed && model.JamRisk == 0 && model.RepairProgress == 0, "Repair failed to clear fault.");
            Advance(model, 20);
            Expect(model.JamRisk >= 0.5 && !model.Jammed, "Expected prevention window.");
            model.Repair(0.6); model.Repair(0.6);
            Expect(model.JamRisk == 0 && !model.Jammed, "Preventive service failed.");
            Conserved(model);
        }

        private static void Refill()
        {
            var model = New();
            model.TriggerPracticeFault(MachineFault.EmptyBatter);
            int made = model.ProductionCount;
            Advance(model, 5);
            Expect(model.ProductionCount == made && model.Batter == 0, "Empty hopper produced food.");
            model.Refill(0.75); model.Tick(0.1);
            model.Refill(0.75); model.Tick(0.1);
            Expect(model.Batter == 0 && model.RefillProgress == 0.75, "Refill completed too early.");
            model.Refill(0.5);
            Expect(model.Batter == 72 && model.RefillProgress == 0, "Refill did not finish.");
            Advance(model, 1.3);
            Expect(model.ProductionCount == made + 1 && model.Batter == 71, "Production did not resume after refill.");
            Conserved(model);
        }

        private static void FireRecovery()
        {
            var model = New();
            model.SetHeat(4);
            Advance(model, 45);
            Expect(model.FireActive && model.FireDanger == 1 && model.Overheated, "Sustained dangerous heat never ignited.");
            int made = model.ProductionCount;
            int food = model.ValidateConservation().TotalCreated;
            Expect(!model.Repair(1).Success && !model.Refill(1).Success, "Maintenance ignored active fire.");
            Expect(model.ExtinguishFire().Success, "Extinguisher failed.");
            Expect(!model.FireActive && !model.Overheated && model.HeatSetting == 0 && model.FireRecovery == 2.4 && model.FoamTime == 8, "Fire reset contract broken.");
            model.SetHeat(2);
            if (model.Jammed) { model.Repair(0.9); model.Repair(0.9); }
            Advance(model, 2);
            Expect(model.ProductionCount == made, "Fryer produced during mandatory settling.");
            Advance(model, 2);
            Expect(model.ProductionCount > made && model.ValidateConservation().TotalCreated > food, "Fryer did not resume after recovery.");
            Expect(!model.ExtinguishFire().Success, "Extinguisher applied twice without a fire.");
            Conserved(model);
        }

        private static void FirePrevention()
        {
            var model = New();
            model.SetHeat(4);
            int guard = 0;
            while (model.FireDanger < 0.4 && guard++ < 1000) Advance(model, 0.1);
            Expect(model.FireDanger >= 0.4 && !model.FireActive, "Fire warning did not leave a reaction interval.");
            model.SetHeat(2);
            Advance(model, 10);
            Expect(!model.FireActive && model.FireDanger == 0, "Turning heat down failed to prevent ignition.");
            Conserved(model);
        }

        private static void CompleteShift()
        {
            var model = New(GameMode.Shift);
            while (model.Phase == GamePhase.Playing)
            {
                if (model.CurrentOrder != null && model.TimeLeft > 12) MakeOrder(model, true);
                else Advance(model, 0.2, true);
            }
            Expect(model.Phase == GamePhase.Won && model.Sales >= 110 && model.Served >= 5, "Human-paced healthy service cannot clear opening day: sales=" + model.Sales + ", served=" + model.Served);
            Expect(model.LastResult.Cleared && model.LastResult.BestStreak == model.BestStreak, "Win summary lost streak.");
            Conserved(model);
            Console.WriteLine("  Completion evidence: $" + model.Sales + ", " + model.Served + " served, " + model.Missed + " missed, " + model.WasteCount + " waste.");
        }

        private static void Determinism()
        {
            var first = New(GameMode.Shift, 12345);
            var second = New(GameMode.Shift, 12345);
            for (int i = 0; i < 1000; i++)
            {
                if (i % 70 == 0) { first.PunchCustomer(); second.PunchCustomer(); }
                Advance(first, 0.1, true); Advance(second, 0.1, true);
            }
            Expect(first.Orders.Count == second.Orders.Count && first.ProductionCount == second.ProductionCount && first.WasteCount == second.WasteCount, "Seeded simulation diverged.");
            for (int i = 0; i < first.Orders.Count; i++)
                Expect(first.Orders[i].Package == second.Orders[i].Package && first.Orders[i].Coating == second.Orders[i].Coating && first.Orders[i].Patience == second.Orders[i].Patience, "Seeded tickets differ.");
        }

        private static void InvalidInput()
        {
            var model = New();
            foreach (double time in new[] { 0d, -1d, double.NaN, double.PositiveInfinity, double.NegativeInfinity })
            {
                model.Tick(time);
                Expect(!model.Repair(time).Success && !model.Refill(time).Success, "Invalid maintenance time accepted.");
            }
            Expect(model.ProductionCount == 0 && model.Supply == 18, "Invalid time changed inventory.");
            Expect(!model.ChoosePackage((PackageKind)999).Success && !model.Coat((Coating)999).Success, "Invalid enum accepted.");
            Expect(!model.Scoop().Success && !model.Pour().Success && !model.Serve().Success, "Incomplete action bypassed physical sequence.");
            model.SetHeat(int.MaxValue);
            Expect(model.HeatSetting == 4, "Heater upper clamp failed.");
            model.SetHeat(int.MinValue);
            Expect(model.HeatSetting == 0, "Heater lower clamp failed.");
            Conserved(model);
        }

        private static void RandomizedConservation()
        {
            var model = New(GameMode.Endless, 88);
            var random = new Random(8231);
            for (int i = 0; i < 12000; i++)
            {
                switch (random.Next(15))
                {
                    case 0: model.ChoosePackage(PackageKind.Bag); break;
                    case 1: model.ChoosePackage(PackageKind.Bucket); break;
                    case 2: model.Scoop(new List<int>(model.StockIds)); break;
                    case 3: model.Pour(); break;
                    case 4: model.Coat(Coating.Cinnamon); break;
                    case 5: model.Coat(Coating.Powdered); break;
                    case 6: model.Serve(); break;
                    case 7: model.Discard(); break;
                    case 8: model.PunchCustomer(); break;
                    case 9: model.Repair(0.25); break;
                    case 10: model.Refill(0.25); break;
                    case 11: model.SetHeat(random.Next(5)); break;
                    case 12: model.ExtinguishFire(); break;
                    case 13:
                        if (model.StockIds.Count > 0) model.SpillStock(new[] { model.StockIds[random.Next(model.StockIds.Count)] });
                        break;
                    case 14:
                        foreach (int id in new List<int>(model.PendingDeliveryIds)) model.SettleDelivery(id, random.Next(4) != 0, model.Epoch);
                        break;
                }
                model.Tick(0.1);
                if (i % 100 == 0) model.DrainEvents();
                Conserved(model);
                Expect(model.Batter >= 0 && model.Batter <= 72 && model.Orders.Count <= 3, "Chaotic play exceeded bounded state.");
            }
            Expect(model.Phase == GamePhase.Playing, "Endless mode timed out.");
        }

        private static void IndependentFeedSpeed()
        {
            int[] produced = new int[5];
            for (int speed = 0; speed <= 4; speed++)
            {
                var model = New();
                Expect(model.SpeedSetting == 2 && model.FeedMultiplier == 1, "Default feed changed the established pacing.");
                model.DrainEvents();
                double oilBefore = model.Temperature;
                Expect(model.SetSpeed(speed).Success, "Valid feed setting rejected.");
                Expect(model.HeatSetting == 2 && model.Temperature == oilBefore, "Changing feed changed heater state.");
                var settingEvents = model.DrainEvents();
                Expect(settingEvents.Length == 1 && settingEvents[0].Type == GameEventType.SpeedChanged, "Feed event contract wrong.");
                Advance(model, 12);
                produced[speed] = model.ProductionCount;
                Conserved(model);
            }
            Expect(produced[0] == 0 && produced[1] < produced[2] && produced[2] < produced[3] && produced[3] < produced[4],
                "Feed settings did not produce independent, ordered rates: " + string.Join(",", produced));

            var paused = New();
            paused.Tick(1.3);
            Expect(paused.PendingDeliveryIds.Count == 1, "Test needs a genuine in-flight donut.");
            int pendingId = paused.PendingDeliveryIds[0];
            int supply = paused.Supply, batter = paused.Batter;
            paused.SetSpeed(0);
            paused.Tick(10);
            Expect(paused.ProductionStatus == "Feed paused" && paused.ProductionCount == 1, "Feed zero failed to pause production.");
            Expect(paused.PendingDeliveryIds.Count == 1 && paused.PendingDeliveryIds[0] == pendingId && paused.Supply == supply && paused.Batter == batter,
                "Pausing feed discarded or credited existing food.");
            Expect(paused.SettleDelivery(pendingId, true, paused.Epoch).Accepted && paused.Supply == supply + 1, "A landing could not complete with feed paused.");
            paused.SetHeat(4);
            paused.AdjustSpeed(2);
            Expect(paused.SpeedSetting == 2 && paused.HeatSetting == 4, "Feed/heat controls are coupled.");
            paused.Tick(1.3);
            Expect(paused.ProductionCount == 2, "Feed did not resume after pause.");
            paused.SetSpeed(int.MaxValue);
            Expect(paused.SpeedSetting == 4 && paused.FeedMultiplier == 1.6, "Maximum feed clamp wrong.");
            paused.AdjustSpeed(int.MinValue);
            Expect(paused.SpeedSetting == 0 && paused.FeedMultiplier == 0, "Minimum feed clamp wrong.");
            Conserved(paused);
        }
    }
}
#endif
