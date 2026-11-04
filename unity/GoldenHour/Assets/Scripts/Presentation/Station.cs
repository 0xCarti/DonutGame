using UnityEngine;

namespace GoldenHour.Presentation
{
    public enum StationKind { Tray, Scoop, Bag, Bucket, Package, Cinnamon, Powdered, HeatDown, HeatUp, FeedDown, FeedUp, Repair, Batter, Customer, Waste, Extinguisher, Bell }
    public sealed class Station : MonoBehaviour
    {
        public StationKind kind;
        public string title;
        public Transform animatedPart;
        Renderer[] surfaces;
        MaterialPropertyBlock block;
        float glow;
        Transform lastPart;
        public bool Hovered { get; set; }
        public void SetHighlight(Transform part) { animatedPart=part; lastPart=part; surfaces=part?part.GetComponentsInChildren<Renderer>():GetComponentsInChildren<Renderer>(); }
        void Awake() { surfaces = GetComponentsInChildren<Renderer>(); block = new MaterialPropertyBlock(); }
        void Update()
        {
            if(animatedPart!=lastPart)SetHighlight(animatedPart);
            float target = Hovered ? .32f : 0;
            if (Mathf.Abs(glow - target) < .001f) return;
            glow = Mathf.Lerp(glow, target, 1 - Mathf.Exp(-Time.unscaledDeltaTime * 14));
            block.SetColor("_EmissionColor", new Color(1,.61f,.20f) * glow);
            foreach (var r in surfaces) if (r) r.SetPropertyBlock(block);
        }
    }
}
