using UnityEngine;

namespace GoldenHour.Presentation
{
    [CreateAssetMenu(menuName = "Golden Hour/Stand Assets")]
    public sealed class StandAssets : ScriptableObject
    {
        public GameObject fryer, counter, tray, scoop, bag, bucket, shaker, shakerPowdered, donut, extinguisher, bell, customer, hands;
        public GameObject canopy, hangingSign, pendant, sandwichBoard;
        public GameObject marketStall, parkBench, ferrisWheel;
        public Material steel, wood, cream, red, teal, gold, glass, oil, ground, canvas, glow, particle, sky, worldText;
        public Font font;
        public Texture2D keyArt, seal, sign, flame;
        public AudioClip[] sounds;
    }
}
