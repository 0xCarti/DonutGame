using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace GoldenHour.Presentation
{
    public sealed class WorldBuilder
    {
        readonly StandAssets a;
        readonly Transform root;
        WorldTextAtlas lettering;
        public Camera Camera { get; private set; }
        public Transform Fryer, Tray, Scoop, PackageSpot, Customer, Hands, HeatDial, ServiceDial;
        public readonly List<Light> Bulbs = new List<Light>();
        public readonly Dictionary<StationKind, Station> Stations = new Dictionary<StationKind, Station>();
        public Vector3 TrayCenter { get { return Tray.position + Vector3.up * .035f; } }
        public WorldBuilder(StandAssets assets, Transform parent) { a=assets; root=parent; }
        public void Build()
        {
            lettering=root.gameObject.AddComponent<WorldTextAtlas>();lettering.Initialize(a.font,a.worldText);
            Camera = new GameObject("Operator camera", typeof(Camera), typeof(AudioListener)).GetComponent<Camera>();
            Camera.transform.SetParent(root);
            Camera.transform.position = new Vector3(0,1.70f,-1.40f);
            Camera.transform.rotation = Quaternion.LookRotation(new Vector3(0,1.18f,.15f)-Camera.transform.position);
            Camera.fieldOfView=67; Camera.nearClipPlane=.035f; Camera.farClipPlane=70;
            Camera.allowHDR=true; Camera.allowMSAA=true; Camera.backgroundColor=new Color(.09f,.13f,.24f);
            RenderSettings.skybox=a.sky;
            Camera.clearFlags=a.sky?CameraClearFlags.Skybox:CameraClearFlags.SolidColor;
            var data=Camera.GetUniversalAdditionalCameraData(); data.renderPostProcessing=true;
            data.antialiasing=AntialiasingMode.SubpixelMorphologicalAntiAliasing;
            data.antialiasingQuality=AntialiasingQuality.High;
            var sun=new GameObject("Late summer sun",typeof(Light)).GetComponent<Light>();
            sun.transform.rotation=Quaternion.Euler(30,-35,0); sun.type=LightType.Directional;
            sun.color=new Color(1,.94f,.86f); sun.intensity=1.25f; sun.shadows=LightShadows.Soft;sun.shadowStrength=.8f;
            sun.shadowBias=.03f; sun.shadowNormalBias=.15f;
            RenderSettings.ambientMode=AmbientMode.Trilight;
            RenderSettings.ambientSkyColor=new Color(.40f,.47f,.56f);
            RenderSettings.ambientEquatorColor=new Color(.32f,.35f,.39f);
            RenderSettings.ambientGroundColor=new Color(.20f,.19f,.17f);
            RenderSettings.fog=true; RenderSettings.fogColor=new Color(.17f,.20f,.28f); RenderSettings.fogMode=FogMode.Exponential; RenderSettings.fogDensity=.022f;
            var volume=new GameObject("Warm film",typeof(Volume)).GetComponent<Volume>(); volume.isGlobal=true;
            volume.profile=ScriptableObject.CreateInstance<VolumeProfile>();
            var tone=volume.profile.Add<Tonemapping>(true); tone.mode.Override(TonemappingMode.ACES);
            var bloom=volume.profile.Add<Bloom>(true); bloom.intensity.Override(.24f); bloom.threshold.Override(1.25f); bloom.scatter.Override(.5f);
            var grade=volume.profile.Add<ColorAdjustments>(true); grade.postExposure.Override(.05f); grade.contrast.Override(2); grade.saturation.Override(-8);
            var vignette=volume.profile.Add<Vignette>(true); vignette.intensity.Override(.13f); vignette.smoothness.Override(.55f);
            Box("Fairground",new Vector3(0,-.08f,5),new Vector3(70,.15f,70),a.ground,true);
            var counter=Model(a.counter,"Oak counter",Vector3.zero);
            // Four separate slabs preserve the actual discard cutout at the right end.
            Box("Counter collision",new Vector3(-.255f,.883f,0),new Vector3(3.09f,.05f,.85f),a.wood,true,false);
            Box("Waste rim back",new Vector3(1.485f,.883f,.28f),new Vector3(.39f,.05f,.29f),a.wood,true,false);
            Box("Waste rim front",new Vector3(1.485f,.883f,-.28f),new Vector3(.39f,.05f,.29f),a.wood,true,false);
            Box("Waste rim right",new Vector3(1.74f,.883f,0),new Vector3(.12f,.05f,.85f),a.wood,true,false);
            Fryer=Model(a.fryer,"Little Golden fryer",new Vector3(-.56f,.908f,.09f));
            Tray=Model(a.tray,"Catch tray",new Vector3(.39f,.905f,-.02f));
            Station(Tray,StationKind.Tray,"CATCH TRAY",new Vector3(0,.035f,0),new Vector3(.47f,.09f,.33f));
            TrayWall("Tray bottom",new Vector3(0,.0055f,0),new Vector3(.45f,.005f,.31f));
            TrayWall("Tray left lip",new Vector3(-.227f,.033f,0),new Vector3(.015f,.05f,.32f));
            TrayWall("Tray right lip",new Vector3(.227f,.033f,0),new Vector3(.015f,.05f,.32f));
            TrayWall("Tray back lip",new Vector3(0,.033f,.156f),new Vector3(.46f,.05f,.014f));
            TrayWall("Tray front lip",new Vector3(0,.033f,-.156f),new Vector3(.46f,.05f,.014f));
            Scoop=Model(a.scoop,"The scoop",new Vector3(-.02f,.9112f,-.3f));
            Scoop.rotation=Quaternion.Euler(0,180,0);
            Station(Scoop,StationKind.Scoop,"SCOOP",new Vector3(0,.046f,.065f),new Vector3(.12f,.11f,.35f));
            // Keep large buckets to the right of the left arm's path to both
            // shakers, including the pickup/return pose at their resting spots.
            PackageSpot=new GameObject("Packing mat").transform; PackageSpot.SetParent(root); PackageSpot.position=new Vector3(1.10f,.9165f,-.17f);
            Box("Packing mat",PackageSpot.position-Vector3.up*.0045f,new Vector3(.35f,.009f,.32f),a.teal,false);
            var fill=Station(PackageSpot,StationKind.Package,"FILL / LIFT ORDER",new Vector3(0,.10f,0),new Vector3(.32f,.24f,.29f));
            var bags=Model(a.bag,"Paper bags",new Vector3(1.42f,.908f,.19f));
            Station(bags,StationKind.Bag,"PAPER BAG · 6",new Vector3(0,.14f,0),new Vector3(.22f,.30f,.15f));
            for(int i=1;i<4;i++) { var b=Model(a.bag,"Folded bag",bags.position+new Vector3(i*.027f,0,i*.011f)); b.localScale=new Vector3(1,1,.22f); }
            var buckets=Model(a.bucket,"Buckets",new Vector3(1.18f,.906f,.22f));
            Station(buckets,StationKind.Bucket,"BUCKET · 12",new Vector3(0,.12f,0),new Vector3(.28f,.28f,.28f));
            var cin=Model(a.shaker,"Cinnamon shaker",new Vector3(.70f,.904f,.22f));
            Station(cin,StationKind.Cinnamon,"CINNAMON SUGAR",new Vector3(0,.08f,0),new Vector3(.11f,.19f,.11f));
            var pow=Model(a.shakerPowdered,"Powdered shaker",new Vector3(.86f,.904f,.25f));
            Station(pow,StationKind.Powdered,"POWDERED SUGAR",new Vector3(0,.08f,0),new Vector3(.11f,.19f,.11f));
            var ext=Model(a.extinguisher,"Fire extinguisher",new Vector3(-1.43f,.903f,-.28f));
            Station(ext,StationKind.Extinguisher,"FIRE EXTINGUISHER",new Vector3(0,.17f,0),new Vector3(.20f,.37f,.20f));
            var bell=Model(a.bell,"Service bell",new Vector3(-1.20f,.905f,-.32f));
            Station(bell,StationKind.Bell,"RING FOR GOOD LUCK",new Vector3(0,.05f,0),new Vector3(.16f,.13f,.16f));
            var waste=new GameObject("Discard opening").transform; waste.SetParent(root); waste.position=new Vector3(1.485f,.88f,0);
            Station(waste,StationKind.Waste,"DISCARD",Vector3.zero,new Vector3(.39f,.12f,.27f));
            HeatDial=Find(Fryer,"HeatDial"); ServiceDial=Find(Fryer,"SpeedDial");
            var heat=new GameObject("Heat control").transform; heat.SetParent(root); heat.position=Fryer.position+new Vector3(-.60f,.346f,-.312f);
            Station(heat,StationKind.HeatDown,"HEAT · LEFT LOWER / RIGHT HIGHER",Vector3.zero,new Vector3(.10f,.11f,.08f)).SetHighlight(HeatDial);
            var feed=new GameObject("Feed control").transform;feed.SetParent(root);feed.position=Fryer.position+new Vector3(-.49f,.346f,-.312f);
            Station(feed,StationKind.FeedDown,"FEED · LEFT SLOWER / RIGHT FASTER",Vector3.zero,new Vector3(.10f,.11f,.08f)).SetHighlight(ServiceDial);
            var repair=new GameObject("Motor service").transform; repair.SetParent(root); repair.position=Fryer.position+new Vector3(-.70f,.30f,-.02f);
            Station(repair,StationKind.Repair,"MOTOR · HOLD TO CLEAR JAM",Vector3.zero,new Vector3(.19f,.22f,.30f)).SetHighlight(Fryer);
            var batter=new GameObject("Batter hopper").transform; batter.SetParent(root); batter.position=Fryer.position+new Vector3(-.51f,.65f,0);
            Station(batter,StationKind.Batter,"HOPPER · HOLD TO REFILL",Vector3.zero,new Vector3(.33f,.32f,.33f)).SetHighlight(Fryer);
            Customer=Model(a.customer,"Fairgoer",new Vector3(.15f,0,1.2f)); Customer.rotation=Quaternion.identity;
            Station(Customer,StationKind.Customer,"CUSTOMER",new Vector3(0,1.2f,0),new Vector3(.6f,1.35f,.42f));
            if (a.hands) { Hands=Model(a.hands,"Operator hands",Vector3.zero); Hands.SetParent(Camera.transform,false); }
            BuildCanopy(); BuildFairground();
            var fillLight=new GameObject("Counter softbox",typeof(Light)).GetComponent<Light>();
            fillLight.type=LightType.Point; fillLight.range=5; fillLight.intensity=2.4f; fillLight.color=new Color(.84f,.91f,1); fillLight.transform.position=new Vector3(0,2.3f,-.5f);
            var probe=new GameObject("Counter reflections",typeof(ReflectionProbe)).GetComponent<ReflectionProbe>();
            probe.transform.position=new Vector3(0,1.7f,-.75f); probe.size=new Vector3(8,5,8); probe.mode=ReflectionProbeMode.Realtime; probe.refreshMode=ReflectionProbeRefreshMode.OnAwake; probe.resolution=128; probe.boxProjection=true;
            probe.gameObject.AddComponent<CounterReflectionCapture>();
        }
        void TrayWall(string name,Vector3 p,Vector3 size) { var g=Box(name,Vector3.zero,size,a.steel,true,false); g.transform.SetParent(Tray,false); g.transform.localPosition=p; }
        public Transform Model(GameObject prefab,string name,Vector3 position)
        {
            var obj=prefab?Object.Instantiate(prefab,root):new GameObject(name); obj.name=name; obj.transform.SetParent(root); obj.transform.position=position;
            return obj.transform;
        }
        Station Station(Transform t,StationKind k,string title,Vector3 center,Vector3 size)
        {
            var c=t.gameObject.AddComponent<BoxCollider>(); c.center=center; c.size=size; c.isTrigger=true;
            var s=t.gameObject.AddComponent<Station>(); s.kind=k; s.title=title; Stations[k]=s; return s;
        }
        public GameObject Box(string name,Vector3 p,Vector3 size,Material mat,bool collider=false,bool visible=true)
        {
            var go=GameObject.CreatePrimitive(PrimitiveType.Cube); go.name=name; go.transform.SetParent(root); go.transform.position=p; go.transform.localScale=size;
            go.GetComponent<Renderer>().sharedMaterial=mat; go.GetComponent<Renderer>().enabled=visible;
            if(!collider) Object.Destroy(go.GetComponent<Collider>()); return go;
        }
        void BuildCanopy()
        {
            Model(a.canopy,"Striped canvas canopy",new Vector3(0,0,.20f));
            Model(a.pendant,"Workshop pendant",new Vector3(-.55f,2.30f,.02f));
            Model(a.sandwichBoard,"Today's specials",new Vector3(-2.4f,0,1.9f));
            for(int i=0;i<19;i++)
            {
                float x=-1.90f+i*.21f, y=2.43f-.15f*(1-x*x/3.61f);
                var b=GameObject.CreatePrimitive(PrimitiveType.Sphere); b.name="Festoon bulb"; b.transform.SetParent(root); b.transform.position=new Vector3(x,y,-.15f); b.transform.localScale=Vector3.one*.04f;
                Object.Destroy(b.GetComponent<Collider>()); b.GetComponent<Renderer>().sharedMaterial=a.glow;
                if(i%4==0) { var l=b.AddComponent<Light>(); l.type=LightType.Point; l.range=1.3f; l.color=new Color(1,.57f,.18f); l.intensity=.4f; Bulbs.Add(l); }
            }
            Text("GOLDEN HOUR",new Vector3(0,2.64f,-.175f),.30f,Color.white);
            Text("HOT • FRESH • LITTLE",new Vector3(0,.67f,-.445f),.14f,new Color(1,.81f,.42f));
        }
        void BuildFairground()
        {
            for(int i=0;i<7;i++)
            {
                float x=(i-3)*3.7f;
                Model(a.marketStall,"Midway stall",new Vector3(x,0,7.5f+(i%2)));
                Text(new[]{"LEMONADE","CANDY APPLES","THE MIDWAY","TICKETS","ARCADE","POPCORN","FUN & GAMES"}[i],new Vector3(x,2.05f,6.62f+i%2),.28f,Color.white);
                var l=new GameObject("Stall lamp",typeof(Light)).GetComponent<Light>(); l.transform.position=new Vector3(x,2,6.4f+i%2); l.type=LightType.Point; l.color=new Color(1,.57f,.26f); l.intensity=2; l.range=5;
            }
            Model(a.ferrisWheel,"Midway ferris wheel",new Vector3(-8,0,15));
            Model(a.parkBench,"Midway bench",new Vector3(3.7f,0,3.8f));
            Model(a.parkBench,"Midway bench",new Vector3(-4.2f,0,4.2f));
            for(int i=0;i<24;i++)
            {
                float x=-13+i*1.1f;
                var b=Box("Midway string light",new Vector3(x,4-Mathf.Sin(i*.14f)*.6f,5),Vector3.one*.07f,a.glow);
            }
        }
        public void Text(string text,Vector3 p,float size,Color color)
        {
            var go=new GameObject(text,typeof(TextMesh)); go.transform.SetParent(root); go.transform.position=p; go.transform.rotation=Quaternion.identity;
            var tm=go.GetComponent<TextMesh>(); tm.text=text; tm.fontSize=90; tm.characterSize=size*10f/tm.fontSize; tm.anchor=TextAnchor.MiddleCenter; tm.alignment=TextAlignment.Center; tm.color=color;
            if(a.font) { a.font.RequestCharactersInTexture(text,90,FontStyle.Normal);tm.font=a.font; tm.GetComponent<Renderer>().sharedMaterial=lettering.Material; }
        }
        static void TintLabel(Transform root,Color tint) { foreach(var r in root.GetComponentsInChildren<Renderer>()) if(r.name.ToLowerInvariant().Contains("label")) { var m=new Material(r.sharedMaterial); m.color=tint; r.sharedMaterial=m; } }
        public static Transform Find(Transform root,string name) { foreach(var t in root.GetComponentsInChildren<Transform>()) if(t.name==name) return t; return null; }
    }
}
