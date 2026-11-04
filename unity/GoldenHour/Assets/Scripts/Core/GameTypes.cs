using System;
using System.Collections.Generic;

namespace GoldenHour
{
    public enum GamePhase { Ready, Playing, Won, Lost }
    public enum GameMode { Shift, Practice, Endless }
    public enum PackageKind { None, Bag, Bucket }
    public enum Coating { None, Cinnamon, Powdered }
    public enum MachineFault { Jam, Fire, EmptyBatter }
    public enum GameEventType
    {
        ShiftStarted, Production, DeliverySettled, StockSpilled,
        CustomerArrived, CustomerLeft, CustomerPunched, PackageChosen,
        Scooped, Poured, Coated, PackageCleared, WrongOrder, Sale,
        HeatChanged, SpeedChanged, JamWarning, Jammed, Repaired, Refilled,
        Overheated, Cooled, FireWarning, FireStarted, FireExtinguished, ShiftEnded
    }

    /// <summary>A live, read-only ticket. Presentation must never invent its own patience clock.</summary>
    public sealed class CustomerOrder
    {
        public int Id { get; private set; }
        public PackageKind Package { get; private set; }
        public Coating Coating { get; private set; }
        public double Patience { get; private set; }
        public double MaxPatience { get; private set; }
        public decimal BasePrice { get { return Package == PackageKind.Bucket ? 32m : 18m; } }
        public int Quantity { get { return Package == PackageKind.Bucket ? 12 : 6; } }
        public double PatienceRatio { get { return MaxPatience > 0 ? Patience / MaxPatience : 0; } }

        internal CustomerOrder(int id, PackageKind package, Coating coating, double patience)
        {
            Id = id;
            Package = package;
            Coating = coating;
            Patience = MaxPatience = patience;
        }

        internal void Wait(double seconds) { Patience = Math.Max(0, Patience - seconds); }

        internal CustomerOrder Copy()
        {
            var copy = new CustomerOrder(Id, Package, Coating, MaxPatience);
            copy.Patience = Patience;
            return copy;
        }
    }

    /// <summary>Money is calculated once. React to the Sale event OR this receipt, never both.</summary>
    public sealed class SaleReceipt
    {
        public int OrderId { get; internal set; }
        public int Streak { get; internal set; }
        public PackageKind Package { get; internal set; }
        public Coating Coating { get; internal set; }
        public decimal BasePrice { get; internal set; }
        public decimal PatienceTip { get; internal set; }
        public decimal StreakTip { get; internal set; }
        public decimal Tip { get { return PatienceTip + StreakTip; } }
        public decimal Amount { get { return BasePrice + Tip; } }
    }

    public sealed class ActionResult
    {
        public bool Success { get; internal set; }
        public bool Accepted { get; internal set; }
        public string Code { get; internal set; }
        public string Message { get; internal set; }
        public int Count { get; internal set; }
        public int Wasted { get; internal set; }
        public int Returned { get; internal set; }
        public double Progress { get; internal set; }
        public IReadOnlyList<int> DonutIds { get; internal set; }
        public SaleReceipt Receipt { get; internal set; }

        internal ActionResult(bool success, string code, string message)
        {
            Success = success;
            Accepted = success;
            Code = code;
            Message = message;
            DonutIds = Array.AsReadOnly(new int[0]);
        }
    }

    /// <summary>Immutable-by-convention events, delivered only once by DrainEvents.</summary>
    public sealed class GameEvent
    {
        public GameEventType Type { get; internal set; }
        public int Epoch { get; internal set; }
        public int DeliveryId { get; internal set; }
        public int Count { get; internal set; }
        public bool Accepted { get; internal set; }
        public bool Preventive { get; internal set; }
        public string Message { get; internal set; }
        public IReadOnlyList<int> DonutIds { get; internal set; }
        public CustomerOrder Order { get; internal set; }
        public SaleReceipt Receipt { get; internal set; }
        public ShiftResult Result { get; internal set; }

        internal GameEvent(GameEventType type, int epoch, string message)
        {
            Type = type;
            Epoch = epoch;
            Message = message;
            DonutIds = Array.AsReadOnly(new int[0]);
        }
    }

    public sealed class ShiftResult
    {
        public bool Cleared { get; internal set; }
        public decimal Sales { get; internal set; }
        public int Target { get; internal set; }
        public int Served { get; internal set; }
        public int Missed { get; internal set; }
        public int Mistakes { get; internal set; }
        public int BestStreak { get; internal set; }
        public int WasteCount { get; internal set; }
        public double Duration { get; internal set; }
        public GameMode Mode { get; internal set; }
    }

    /// <summary>Every cooked donut occupies exactly one of these accounting buckets.</summary>
    public sealed class ConservationReport
    {
        public int OpeningStock { get; internal set; }
        public int Produced { get; internal set; }
        public int Stock { get; internal set; }
        public int Pending { get; internal set; }
        public int Scoop { get; internal set; }
        public int Package { get; internal set; }
        public int Sold { get; internal set; }
        public int Wasted { get; internal set; }
        public int TotalCreated { get { return OpeningStock + Produced; } }
        public int TotalAccounted { get { return Stock + Pending + Scoop + Package + Sold + Wasted; } }
        public bool IsValid { get; internal set; }
        public string Error { get; internal set; }
    }
}
