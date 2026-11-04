using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;

namespace GoldenHour
{
    /// <summary>
    /// Authoritative, deterministic fairground rules. All times are seconds and all food is ID-tracked.
    /// Unity advances Tick, renders Production events, then calls SettleDelivery after a physical landing.
    /// Pure C#: no engine clock, global random, scene, input, audio or physics dependencies.
    /// </summary>
    public sealed class StandSimulation
    {
        private const double FireBuildUpSeconds = 12;
        private const double FireRecoverySeconds = 2.4;
        private const double FoamSeconds = 8;
        private const int PendingLimit = 96;
        private readonly List<int> stock = new List<int>();
        private readonly List<int> pending = new List<int>();
        private readonly List<int> scoop = new List<int>();
        private readonly List<int> package = new List<int>();
        private readonly List<CustomerOrder> orders = new List<CustomerOrder>();
        private readonly List<GameEvent> events = new List<GameEvent>();
        private readonly ReadOnlyCollection<int> stockView;
        private readonly ReadOnlyCollection<int> pendingView;
        private readonly ReadOnlyCollection<int> scoopView;
        private readonly ReadOnlyCollection<int> packageView;
        private readonly ReadOnlyCollection<CustomerOrder> ordersView;
        private uint randomState;
        private int nextDonutId = 1;
        private int nextOrderId = 1;
        private int ordersCreated;
        private int nextJamAt;
        private int lastJamProduction;
        private bool jamWarned;
        private double productionClock;
        private double arrivalClock;
        private double refillAge = 10;
        private double repairAge = 10;

        public int Seed { get; private set; }
        public int Epoch { get; private set; }
        public GamePhase Phase { get; private set; }
        public GameMode Mode { get; private set; }
        public bool Relaxed { get; private set; }
        public double TimeLeft { get; private set; }
        public double Duration { get; private set; }
        public double Elapsed { get; private set; }
        public int Target { get; private set; }
        public decimal Sales { get; private set; }
        public int Served { get; private set; }
        public int Missed { get; private set; }
        public int Mistakes { get; private set; }
        public int Streak { get; private set; }
        public int BestStreak { get; private set; }
        public int WasteCount { get; private set; }
        public int ProductionCount { get; private set; }
        public int SoldDonuts { get; private set; }
        public int OpeningStock { get; private set; }
        public int Supply { get { return stock.Count; } }
        public int SupplyCapacity { get { return 36; } }
        public int Batter { get; private set; }
        public int BatterCapacity { get { return 72; } }
        public double Temperature { get; private set; }
        public int HeatSetting { get; private set; }
        public int SpeedSetting { get; private set; }
        public double FeedMultiplier
        {
            get { return SpeedSetting == 0 ? 0 : SpeedSetting == 1 ? 0.65 : SpeedSetting == 2 ? 1 : SpeedSetting == 3 ? 1.3 : 1.6; }
        }
        public bool Jammed { get; private set; }
        public double JamRisk { get; private set; }
        public bool HeatWarning { get { return Temperature >= 195; } }
        public bool Overheated { get; private set; }
        public bool FireActive { get; private set; }
        public double FireDanger { get; private set; }
        public double FireRecovery { get; private set; }
        public double FoamTime { get; private set; }
        public double RepairProgress { get; private set; }
        public double RefillProgress { get; private set; }
        public PackageKind PackageKind { get; private set; }
        public int PackageCount { get { return package.Count; } }
        public Coating PackageCoating { get; private set; }
        public int ScoopCount { get { return scoop.Count; } }
        public int ScoopCapacity { get { return 3; } }
        public int PackageCapacity { get { return Capacity(PackageKind); } }
        public IReadOnlyList<int> StockIds { get { return stockView; } }
        public IReadOnlyList<int> PendingDeliveryIds { get { return pendingView; } }
        public IReadOnlyList<int> ScoopIds { get { return scoopView; } }
        public IReadOnlyList<int> PackageIds { get { return packageView; } }
        public IReadOnlyList<CustomerOrder> Orders { get { return ordersView; } }
        public CustomerOrder CurrentOrder { get { return orders.Count == 0 ? null : orders[0]; } }
        public ShiftResult LastResult { get; private set; }
        public string ShiftName { get { return Mode == GameMode.Practice ? "Practice at the Fair" : Mode == GameMode.Endless ? "After Hours" : "Opening Day"; } }

        public StandSimulation(int seed = 1)
        {
            Seed = seed;
            randomState = seed == 0 ? 1u : unchecked((uint)seed);
            stockView = stock.AsReadOnly();
            pendingView = pending.AsReadOnly();
            scoopView = scoop.AsReadOnly();
            packageView = package.AsReadOnly();
            ordersView = orders.AsReadOnly();
            Phase = GamePhase.Ready;
        }

        /// <summary>Starts a fresh level. Clear old visual bodies; StockIds are already settled opening stock.</summary>
        public void Start(GameMode mode = GameMode.Shift, bool relaxed = false)
        {
            if (!Enum.IsDefined(typeof(GameMode), mode)) throw new ArgumentOutOfRangeException("mode");
            Epoch++;
            Mode = mode;
            Relaxed = relaxed;
            Phase = GamePhase.Playing;
            randomState = Seed == 0 ? 1u : unchecked((uint)Seed);
            stock.Clear(); pending.Clear(); scoop.Clear(); package.Clear(); orders.Clear(); events.Clear();
            Duration = relaxed ? 126 : 105;
            TimeLeft = Duration;
            Target = relaxed ? 88 : 110;
            Elapsed = 0;
            Sales = 0;
            Served = Missed = Mistakes = Streak = BestStreak = WasteCount = ProductionCount = SoldDonuts = 0;
            OpeningStock = relaxed ? 24 : 18;
            for (int i = 0; i < OpeningStock; i++) stock.Add(nextDonutId++);
            Batter = BatterCapacity;
            Temperature = 175;
            HeatSetting = 3;
            SpeedSetting = 2;
            Jammed = Overheated = FireActive = jamWarned = false;
            JamRisk = FireDanger = FireRecovery = FoamTime = RepairProgress = RefillProgress = 0;
            PackageKind = PackageKind.None;
            PackageCoating = Coating.None;
            productionClock = 0;
            arrivalClock = ArrivalInterval;
            refillAge = repairAge = 10;
            lastJamProduction = ordersCreated = 0;
            nextJamAt = JamInterval + RandomInt(-2, 2);
            LastResult = null;
            Emit(GameEventType.ShiftStarted, "The fair is open. First order: a cinnamon bag.").DonutIds = CopyIds(stock);
            SpawnOrder();
        }

        public static int Capacity(PackageKind kind) { return kind == PackageKind.Bag ? 6 : kind == PackageKind.Bucket ? 12 : 0; }

        private double ArrivalInterval
        {
            get { return (Mode == GameMode.Endless ? Math.Max(6.5, 13 - Elapsed / 90) : 15) * (Relaxed ? 1.15 : 1); }
        }
        private double PatienceSeconds
        {
            get { return (Mode == GameMode.Endless ? Math.Max(30, 52 - Elapsed / 40) : 56) * (Relaxed ? 1.4 : 1); }
        }
        private int JamInterval { get { return Relaxed ? 33 : 27; } }

        /// <summary>Advance elapsed play only. Caller pauses by not calling Tick. Ignores non-finite/negative time.</summary>
        public void Tick(double delta)
        {
            if (Phase != GamePhase.Playing || !Finite(delta) || delta <= 0) return;
            // Bound accidental catch-up calls in untimed modes; ordinary frame and offline-test deltas are exact.
            double remaining = Mode == GameMode.Shift ? Math.Min(delta, TimeLeft) : Math.Min(delta, 3600);
            while (remaining > 0.00000001 && Phase == GamePhase.Playing)
            {
                double step = Math.Min(remaining, 0.05);
                Step(step);
                remaining -= step;
            }
            if (Mode == GameMode.Shift && Phase == GamePhase.Playing && TimeLeft < 0.000001) FinishShift();
        }

        private void Step(double step)
        {
            Elapsed += step;
            if (Mode == GameMode.Shift) TimeLeft = Math.Max(0, TimeLeft - step);
            refillAge = Math.Min(10, refillAge + step);
            repairAge = Math.Min(10, repairAge + step);
            FireRecovery = Math.Max(0, FireRecovery - step);
            FoamTime = Math.Max(0, FoamTime - step);
            double[] heatTargets = { 90, 135, 175, 210, 240 };
            double desired = heatTargets[HeatSetting];
            double rate = desired < Temperature ? 0.06 : 0.035;
            Temperature = Clamp(Temperature + (desired - Temperature) * rate * step, 20, 260);
            if (FireActive) Overheated = true;
            else if (!Overheated && Temperature >= 205)
            {
                Overheated = true;
                Emit(GameEventType.Overheated, "Oil too hot. Turn the heat down.");
            }
            else if (Overheated && Temperature <= 190)
            {
                Overheated = false;
                Emit(GameEventType.Cooled, "The fryer has cooled. Production resumes.");
            }
            UpdateFire(step, desired);
            if (CanProduce)
            {
                double interval = Clamp(1.5 - (Temperature - 145) * 0.01, 0.85, 1.5) / FeedMultiplier;
                productionClock += step;
                while (productionClock + 0.00000001 >= interval && CanProduce)
                {
                    productionClock = Math.Max(0, productionClock - interval);
                    Batter--;
                    ProductionCount++;
                    int id = nextDonutId++;
                    pending.Add(id);
                    Temperature = Math.Min(260, Temperature + 0.12);
                    var produced = Emit(GameEventType.Production, "Fresh donut leaving the fryer.");
                    produced.DeliveryId = id;
                    produced.Count = 1;
                    produced.DonutIds = CopyIds(new[] { id });
                    if (ProductionCount >= nextJamAt && Elapsed >= 22)
                    {
                        Jammed = true;
                        Emit(GameEventType.Jammed, "Feeder jammed. Hold the service control.");
                    }
                }
            }
            RefreshJamRisk();
            if (Mode == GameMode.Practice) return;
            for (int i = orders.Count - 1; i >= 0; i--)
            {
                orders[i].Wait(step);
                if (orders[i].Patience <= 0)
                {
                    var leaving = orders[i];
                    orders.RemoveAt(i);
                    Missed++;
                    Streak = 0;
                    Emit(GameEventType.CustomerLeft, "A customer ran out of patience.").Order = leaving.Copy();
                }
            }
            arrivalClock -= step;
            if (arrivalClock <= 0)
            {
                if (orders.Count < 3)
                {
                    SpawnOrder();
                    arrivalClock += ArrivalInterval + (NextRandom() - 0.5) * 1.5;
                }
                else arrivalClock = 2.5;
            }
        }

        private bool CanProduce
        {
            get
            {
                return Phase == GamePhase.Playing && !Jammed && !Overheated && !FireActive && FireRecovery <= 0
                    && Temperature >= 145 && Batter > 0 && SpeedSetting > 0 && pending.Count < PendingLimit
                    && !(RefillProgress > 0 && refillAge <= 0.25) && !(RepairProgress > 0 && repairAge <= 0.25);
            }
        }

        private void UpdateFire(double step, double desired)
        {
            if (FireActive) return;
            double previous = FireDanger;
            if (Temperature >= 205 && desired >= 205 && FireRecovery <= 0)
                FireDanger = Math.Min(1, FireDanger + step / FireBuildUpSeconds);
            else FireDanger = Math.Max(0, FireDanger - step / 5);
            if (previous < 0.35 && FireDanger >= 0.35) Emit(GameEventType.FireWarning, "Smoke rising. Lower the heat before it catches fire.");
            if (FireDanger >= 0.999999)
            {
                FireDanger = 1;
                FireActive = Overheated = true;
                Emit(GameEventType.FireStarted, "Fryer fire! Use the extinguisher.");
            }
        }

        /// <summary>A delivery is credited exactly once, after contact and settling. Old epochs never affect a new level.</summary>
        public ActionResult SettleDelivery(int id, bool kept, int epoch)
        {
            if (epoch != Epoch || !pending.Remove(id)) return Fail("stale_delivery", "That donut has already landed or belongs to an earlier shift.");
            bool accepted = kept && Supply < SupplyCapacity;
            if (accepted) stock.Add(id); else WasteCount++;
            var result = Ok(accepted ? "delivery_kept" : "delivery_wasted", accepted ? "Donut landed in the tray." : "A donut spilled out of the tray.", new[] { id });
            result.Accepted = accepted;
            result.Wasted = accepted ? 0 : 1;
            var landed = Emit(GameEventType.DeliverySettled, result.Message);
            landed.DeliveryId = id;
            landed.DonutIds = result.DonutIds;
            landed.Count = 1;
            landed.Accepted = accepted;
            UpdateFinalWaste();
            return result;
        }

        /// <summary>Call only for specific settled physical donuts that actually leave the tray.</summary>
        public ActionResult SpillStock(IEnumerable<int> ids)
        {
            if (ids == null) return Fail("no_stock", "No donuts left the tray.");
            var spilled = new List<int>();
            // Materialize first: callers may pass StockIds itself.
            foreach (int id in new List<int>(ids)) if (stock.Remove(id)) spilled.Add(id);
            WasteCount += spilled.Count;
            var result = Ok("stock_spilled", spilled.Count + " donuts spilled from the tray.", spilled);
            result.Wasted = spilled.Count;
            if (spilled.Count > 0)
            {
                var spill = Emit(GameEventType.StockSpilled, result.Message);
                spill.DonutIds = result.DonutIds;
                spill.Count = spilled.Count;
            }
            UpdateFinalWaste();
            return result;
        }

        public ActionResult ChoosePackage(PackageKind kind)
        {
            if (!Playing) return Closed();
            if (Capacity(kind) == 0) return Fail("invalid_package", "Choose a bag or bucket.");
            if (PackageCount > 0 && PackageKind != kind) return Fail("occupied", "Finish this package or clear it first.");
            PackageKind = kind;
            var result = Ok("package_ready", kind + " ready: " + Capacity(kind) + " donuts.");
            Emit(GameEventType.PackageChosen, result.Message);
            return result;
        }

        /// <summary>Supply exact IDs of reachable settled bodies, nearest first. Omit only for non-physical/headless play.</summary>
        public ActionResult Scoop(IEnumerable<int> visibleAvailableIds = null)
        {
            if (!Playing) return Closed();
            if (PackageKind == PackageKind.None) return Fail("no_package", "Put out a bag or bucket first.");
            if (ScoopCount > 0) return Fail("scoop_full", "Pour the donuts already in your scoop.");
            if (PackageCoating != Coating.None) return Fail("already_coated", "This package is already seasoned.");
            if (PackageCount >= PackageCapacity) return Fail("package_full", "The package is full. Add the requested sugar.");
            if (Supply == 0) return Fail("empty_supply", "The tray is empty. Check the fryer.");
            var candidates = visibleAvailableIds == null ? new List<int>(stock) : new List<int>(visibleAvailableIds);
            int count = Math.Min(ScoopCapacity, PackageCapacity - PackageCount);
            foreach (int id in candidates)
            {
                if (scoop.Count == count) break;
                if (stock.Remove(id)) scoop.Add(id);
            }
            if (ScoopCount == 0) return Fail("no_reachable_stock", "Let the donuts settle in the tray before scooping.");
            var result = Ok("scooped", ScoopCount + " donuts in the scoop.", scoop);
            var scooped = Emit(GameEventType.Scooped, result.Message);
            scooped.DonutIds = result.DonutIds;
            scooped.Count = result.Count;
            return result;
        }

        public ActionResult Pour()
        {
            if (!Playing) return Closed();
            if (PackageKind == PackageKind.None) return Fail("no_package", "Put out a bag or bucket first.");
            if (ScoopCount == 0) return Fail("empty_scoop", "Scoop some donuts first.");
            if (PackageCoating != Coating.None) return Fail("already_coated", "This package is already seasoned.");
            int count = Math.Min(ScoopCount, PackageCapacity - PackageCount);
            if (count <= 0) return Fail("package_full", "This package is already full.");
            var moved = scoop.GetRange(0, count);
            package.AddRange(moved);
            scoop.RemoveRange(0, count);
            var result = Ok("poured", PackageCount + " / " + PackageCapacity + " donuts.", moved);
            var poured = Emit(GameEventType.Poured, result.Message);
            poured.DonutIds = result.DonutIds;
            poured.Count = count;
            return result;
        }

        public ActionResult Coat(Coating coating)
        {
            if (!Playing) return Closed();
            if (coating != Coating.Cinnamon && coating != Coating.Powdered) return Fail("invalid_coating", "Choose cinnamon or powdered sugar.");
            if (PackageKind == PackageKind.None || PackageCount != PackageCapacity) return Fail("not_full", "Fill the package before adding sugar.");
            if (PackageCoating != Coating.None)
                return Fail("already_coated", PackageCoating == coating ? "This package is already coated and ready to serve." : "That sugar cannot be removed. Clear the package to start again.");
            PackageCoating = coating;
            var result = Ok("coated", CoatingName(coating) + " " + PackageKind.ToString().ToLowerInvariant() + " ready.", package);
            Emit(GameEventType.Coated, result.Message).DonutIds = result.DonutIds;
            return result;
        }

        public ActionResult Serve()
        {
            if (!Playing) return Closed();
            if (CurrentOrder == null) return Fail("no_customer", "Wait for a customer to reach the counter.");
            if (PackageKind == PackageKind.None || PackageCount == 0) return Fail("no_food", "Prepare the customer's order first.");
            var order = CurrentOrder;
            if (PackageKind != order.Package || PackageCount != order.Quantity || PackageCoating != order.Coating)
            {
                Mistakes++;
                Streak = 0;
                if (Mode != GameMode.Practice) order.Wait(4);
                string message = "They want a " + order.Package.ToString().ToLowerInvariant() + " of " + CoatingName(order.Coating).ToLowerInvariant() + ". Your food stays on the counter.";
                Emit(GameEventType.WrongOrder, message).Order = order.Copy();
                return Fail("wrong_order", message);
            }
            var receipt = new SaleReceipt
            {
                OrderId = order.Id,
                Package = order.Package,
                Coating = order.Coating,
                BasePrice = order.BasePrice,
                PatienceTip = (decimal)Math.Floor((order.Package == PackageKind.Bucket ? 6 : 4) * order.PatienceRatio),
                StreakTip = Math.Min(Streak, 5) * 0.5m,
                Streak = Streak + 1
            };
            var servedIds = CopyIds(package);
            Sales += receipt.Amount;
            SoldDonuts += PackageCount;
            Served++;
            Streak++;
            BestStreak = Math.Max(BestStreak, Streak);
            orders.RemoveAt(0);
            package.Clear();
            PackageKind = PackageKind.None;
            PackageCoating = Coating.None;
            var result = Ok("served", "Order served! +$" + receipt.Amount.ToString("0.00", System.Globalization.CultureInfo.InvariantCulture), servedIds);
            result.Receipt = receipt;
            var sale = Emit(GameEventType.Sale, result.Message);
            sale.Receipt = receipt;
            sale.Order = order.Copy();
            sale.DonutIds = servedIds;
            sale.Count = servedIds.Count;
            if (Mode == GameMode.Practice) SpawnOrder();
            return result;
        }

        /// <summary>Returns plain food to available tray spaces; seasoned food and overflow become waste.</summary>
        public ActionResult Discard()
        {
            if (!Playing) return Closed();
            var all = new List<int>(scoop);
            all.AddRange(package);
            var recoverable = new List<int>(scoop);
            if (PackageCoating == Coating.None) recoverable.AddRange(package);
            int returned = Math.Min(recoverable.Count, SupplyCapacity - Supply);
            for (int i = 0; i < returned; i++) stock.Add(recoverable[i]);
            int wasted = all.Count - returned;
            WasteCount += wasted;
            scoop.Clear(); package.Clear();
            PackageKind = PackageKind.None;
            PackageCoating = Coating.None;
            var result = Ok("cleared", "Counter cleared. " + returned + " plain donuts recovered; " + wasted + " discarded.", all);
            result.Returned = returned;
            result.Wasted = wasted;
            var cleared = Emit(GameEventType.PackageCleared, result.Message);
            cleared.DonutIds = result.DonutIds;
            cleared.Count = all.Count;
            return result;
        }

        public ActionResult PunchCustomer()
        {
            if (!Playing) return Closed();
            if (CurrentOrder == null) return Fail("no_customer", "There is nobody at the counter.");
            var leaving = CurrentOrder;
            orders.RemoveAt(0);
            Missed++;
            Streak = 0;
            Emit(GameEventType.CustomerPunched, "That customer has had enough!").Order = leaving.Copy();
            if (Mode == GameMode.Practice) SpawnOrder();
            else if (orders.Count == 0) arrivalClock = Math.Min(arrivalClock, 1.2);
            return Ok("customer_punched", "That customer has had enough! Your prepared food stays on the counter.");
        }

        public ActionResult SetHeat(int setting)
        {
            if (!Playing) return Closed();
            HeatSetting = Math.Max(0, Math.Min(4, setting));
            var result = Ok("heat_changed", "Heat setting " + HeatSetting + " / 4.");
            Emit(GameEventType.HeatChanged, result.Message);
            return result;
        }
        public ActionResult AdjustHeat(int change) { return SetHeat(HeatSetting + Math.Max(-4, Math.Min(4, change))); }

        /// <summary>Independent feeder control. Zero pauses new production without touching in-flight food or heat.</summary>
        public ActionResult SetSpeed(int setting)
        {
            if (!Playing) return Closed();
            SpeedSetting = Math.Max(0, Math.Min(4, setting));
            var result = Ok("speed_changed", SpeedSetting == 0 ? "Feed paused. The oil temperature still needs attention." : "Feed speed " + SpeedSetting + " / 4.");
            Emit(GameEventType.SpeedChanged, result.Message);
            return result;
        }
        public ActionResult AdjustSpeed(int change) { return SetSpeed(SpeedSetting + Math.Max(-4, Math.Min(4, change))); }

        public ActionResult Repair(double delta)
        {
            if (!Playing) return Closed();
            if (FireActive) return Fail("fire_active", "Put out the fire before servicing the feeder.");
            if (!Jammed && JamRisk < 0.5 && RepairProgress <= 0) return Fail("not_jammed", "The feeder is healthy. Service it above 50% feed risk.");
            if (!Finite(delta) || delta <= 0 || delta > 1) return Fail("invalid_time", "Keep holding the service control.");
            repairAge = 0;
            bool wasJammed = Jammed;
            RepairProgress = Math.Min(1, RepairProgress + delta / (wasJammed ? 1.8 : 1.2));
            if (RepairProgress >= 0.999999)
            {
                Jammed = false;
                RepairProgress = 0;
                lastJamProduction = ProductionCount;
                nextJamAt = ProductionCount + JamInterval + RandomInt(-2, 2);
                jamWarned = false;
                repairAge = 10;
                RefreshJamRisk();
                Emit(GameEventType.Repaired, wasJammed ? "Feeder cleared. Donuts are moving again." : "Feeder serviced before it jammed.").Preventive = !wasJammed;
                return Ok(wasJammed ? "repaired" : "serviced", wasJammed ? "Feeder cleared. Donuts are moving again." : "Feeder serviced before it jammed.");
            }
            var result = Ok("repairing", "Clearing the feeder...");
            result.Progress = RepairProgress;
            return result;
        }

        public ActionResult Refill(double delta)
        {
            if (!Playing) return Closed();
            if (FireActive) return Fail("fire_active", "Put out the fire before adding batter.");
            if (Batter >= BatterCapacity) return Fail("batter_full", "The hopper is already full.");
            if (!Finite(delta) || delta <= 0 || delta > 1) return Fail("invalid_time", "Keep holding the batter refill.");
            refillAge = 0;
            RefillProgress = Math.Min(1, RefillProgress + delta / 2);
            if (RefillProgress >= 0.999999)
            {
                Batter = BatterCapacity;
                RefillProgress = 0;
                refillAge = 10;
                Emit(GameEventType.Refilled, "Batter hopper filled.");
                return Ok("refilled", "Batter hopper filled.");
            }
            var result = Ok("refilling", "Refilling batter...");
            result.Progress = RefillProgress;
            return result;
        }

        public ActionResult ExtinguishFire()
        {
            if (!Playing) return Closed();
            if (!FireActive) return Fail("no_fire", "The fryer is not on fire.");
            FireActive = false;
            FireDanger = 0;
            FireRecovery = FireRecoverySeconds;
            FoamTime = FoamSeconds;
            HeatSetting = 0;
            Temperature = 175;
            Overheated = false;
            Emit(GameEventType.FireExtinguished, "Fire out! Let the fryer settle, then set the heat.");
            return Ok("extinguished", "Fire out! Let the fryer settle, then set the heat.");
        }

        /// <summary>Practice-only drills exercise the actual fault/recovery rules, with no sales or stock gifts.</summary>
        public ActionResult TriggerPracticeFault(MachineFault fault)
        {
            if (!Playing || Mode != GameMode.Practice) return Fail("practice_only", "Fault drills are available in Practice.");
            if (fault == MachineFault.Jam)
            {
                Jammed = true;
                RepairProgress = 0;
                RefreshJamRisk();
                Emit(GameEventType.Jammed, "Practice: feeder jam. Hold service to clear it.");
            }
            else if (fault == MachineFault.Fire)
            {
                Temperature = 215;
                HeatSetting = 4;
                FireActive = Overheated = true;
                FireDanger = 1;
                FireRecovery = 0;
                Emit(GameEventType.FireStarted, "Practice: fryer fire. Use the extinguisher.");
            }
            else if (fault == MachineFault.EmptyBatter)
            {
                Batter = 0;
                RefillProgress = 0;
            }
            else return Fail("invalid_fault", "Choose a jam, fire or empty-hopper drill.");
            return Ok("practice_fault", "Practice fault ready. Follow the machine status to recover.");
        }

        public string ProductionStatus
        {
            get
            {
                if (!Playing) return "Stand closed";
                if (FireActive) return "FRYER FIRE - use extinguisher";
                if (FireRecovery > 0) return "Fryer settling after fire";
                if (Jammed) return "JAMMED - hold service";
                if (Overheated) return "TOO HOT - lower heat";
                if (SpeedSetting == 0) return "Feed paused";
                if (Temperature < 145) return "Warming up - raise heat";
                if (Batter <= 0) return "OUT OF BATTER - hold refill";
                if (RefillProgress > 0 && refillAge <= 0.25) return "Refilling batter";
                if (RepairProgress > 0 && repairAge <= 0.25) return "Servicing feeder";
                if (pending.Count >= PendingLimit) return "Chute blocked - wait for donuts to settle";
                if (Supply >= SupplyCapacity) return "TRAY FULL - donuts will overflow";
                return "Making donuts";
            }
        }

        public GameEvent[] DrainEvents()
        {
            var result = events.ToArray();
            events.Clear();
            return result;
        }

        public ConservationReport ValidateConservation()
        {
            var report = new ConservationReport
            {
                OpeningStock = OpeningStock, Produced = ProductionCount, Stock = Supply,
                Pending = pending.Count, Scoop = ScoopCount, Package = PackageCount,
                Sold = SoldDonuts, Wasted = WasteCount, IsValid = true, Error = ""
            };
            var ids = new HashSet<int>();
            foreach (var group in new[] { stock, pending, scoop, package })
                foreach (int id in group)
                    if (id <= 0 || !ids.Add(id)) { report.IsValid = false; report.Error = "A donut identity is duplicated or invalid."; }
            if (report.TotalCreated != report.TotalAccounted) { report.IsValid = false; report.Error = "Created and accounted food totals differ."; }
            if (Supply > SupplyCapacity || ScoopCount > ScoopCapacity || PackageCount > PackageCapacity)
            { report.IsValid = false; report.Error = "A food container exceeds its capacity."; }
            if (PackageCoating != Coating.None && (PackageCapacity == 0 || PackageCount != PackageCapacity))
            { report.IsValid = false; report.Error = "A seasoned package is not full."; }
            return report;
        }

        private void SpawnOrder()
        {
            if (orders.Count >= 3) return;
            PackageKind kind;
            Coating coating;
            if (ordersCreated < 3)
            {
                kind = ordersCreated == 2 ? PackageKind.Bucket : PackageKind.Bag;
                coating = ordersCreated == 1 ? Coating.Powdered : Coating.Cinnamon;
            }
            else
            {
                kind = NextRandom() < (Mode == GameMode.Endless ? 0.45 : 0.35) ? PackageKind.Bucket : PackageKind.Bag;
                coating = NextRandom() < 0.5 ? Coating.Powdered : Coating.Cinnamon;
            }
            double patience = PatienceSeconds + (kind == PackageKind.Bucket ? 8 : 0);
            var order = new CustomerOrder(nextOrderId++, kind, coating, patience);
            orders.Add(order);
            ordersCreated++;
            Emit(GameEventType.CustomerArrived, "A " + CoatingName(coating).ToLowerInvariant() + " " + kind.ToString().ToLowerInvariant() + ", please.").Order = order.Copy();
        }

        private void RefreshJamRisk()
        {
            JamRisk = Jammed ? 1 : Clamp((double)(ProductionCount - lastJamProduction) / Math.Max(1, nextJamAt - lastJamProduction), 0, 1);
            if (JamRisk >= 0.72 && !Jammed && !jamWarned)
            {
                jamWarned = true;
                Emit(GameEventType.JamWarning, "Feeder getting sticky. Preventive service is available.");
            }
        }

        private void FinishShift()
        {
            TimeLeft = 0;
            bool cleared = Sales >= Target;
            Phase = cleared ? GamePhase.Won : GamePhase.Lost;
            LastResult = new ShiftResult
            {
                Cleared = cleared, Sales = Sales, Target = Target, Served = Served, Missed = Missed,
                Mistakes = Mistakes, BestStreak = BestStreak, WasteCount = WasteCount,
                Duration = Duration, Mode = Mode
            };
            Emit(GameEventType.ShiftEnded, cleared ? "Opening Day complete! The fairground is yours." : "Shift finished. Try again to reach the sales target.").Result = LastResult;
        }

        private void UpdateFinalWaste() { if (LastResult != null) LastResult.WasteCount = WasteCount; }
        private bool Playing { get { return Phase == GamePhase.Playing; } }
        private ActionResult Closed() { return Fail("closed", "The stand is closed."); }
        private ActionResult Fail(string code, string message) { return new ActionResult(false, code, message); }
        private ActionResult Ok(string code, string message, IEnumerable<int> ids = null)
        {
            var result = new ActionResult(true, code, message);
            if (ids != null) { result.DonutIds = CopyIds(ids); result.Count = result.DonutIds.Count; }
            return result;
        }
        private GameEvent Emit(GameEventType type, string message)
        {
            var result = new GameEvent(type, Epoch, message);
            events.Add(result);
            return result;
        }
        private static IReadOnlyList<int> CopyIds(IEnumerable<int> source) { return new List<int>(source).AsReadOnly(); }
        private static bool Finite(double value) { return !double.IsNaN(value) && !double.IsInfinity(value); }
        private static double Clamp(double value, double min, double max) { return Math.Max(min, Math.Min(max, value)); }
        public static string CoatingName(Coating coating) { return coating == Coating.Powdered ? "Powdered sugar" : coating == Coating.Cinnamon ? "Cinnamon" : "Plain"; }

        // Explicit PRNG algorithm keeps seeded orders stable across Mono, IL2CPP and .NET runtime versions.
        private double NextRandom()
        {
            uint value = randomState;
            value ^= value << 13; value ^= value >> 17; value ^= value << 5;
            randomState = value;
            return value / 4294967296.0;
        }
        private int RandomInt(int minimum, int maximum) { return minimum + (int)(NextRandom() * (maximum - minimum + 1)); }
    }
}
