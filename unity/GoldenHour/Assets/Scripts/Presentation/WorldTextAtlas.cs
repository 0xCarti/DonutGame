using UnityEngine;

namespace GoldenHour.Presentation
{
    // A dynamic font can rebuild its atlas as the HUD requests more sizes.
    // World signs share that atlas but use a depth-tested material.
    public sealed class WorldTextAtlas : MonoBehaviour
    {
        Font font;
        public Material Material {get;private set;}
        public void Initialize(Font source,Material template)
        {
            font=source;Material=new Material(template);
            Refresh(source);Font.textureRebuilt+=Refresh;
        }
        void Refresh(Font changed){if(changed==font&&font&&Material)Material.mainTexture=font.material.mainTexture;}
        void OnDestroy(){Font.textureRebuilt-=Refresh;if(Material)Destroy(Material);}
    }
}
