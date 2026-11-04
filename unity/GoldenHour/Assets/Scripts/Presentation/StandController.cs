using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace GoldenHour.Presentation
{
    public sealed class StandController : MonoBehaviour
    {
        public StandAssets assets;
        public StandSimulation Model { get; private set; }
        public WorldBuilder World { get; private set; }
        public bool Paused {get;private set;} = true;
        public bool Menu {get;private set;} = true;
        public bool ScoopEquipped {get;private set;}
        public bool PackageLifted {get;private set;}
        public bool Busy {get;private set;}
        public bool ReducedMotion {get;set;}
        public float Volume {get;set;}=.75f;
        public float MusicVolume {get;set;}=.25f;
        public string Hint {get;private set;}="Welcome to the midway.";
        public string Toast {get;private set;}="";
        public float ToastUntil {get;private set;}
        public float Celebration {get;private set;}
        public Station Hover {get;private set;}
        public Transform Package {get;private set;}
        public readonly Dictionary<int,DonutBody> Food=new Dictionary<int,DonutBody>();
        public Action<string> OnCue;
        Vector3 scoopRest,customerRest,cameraRest;
        Quaternion cameraRotation;
        Transform heldTool;
        CharacterAnimationDriver handDriver,customerDriver;
        HandWorkstationDriver handWork;
        AudioSource effects,music;
        float shakeCombo,lastShake,heatVisual=3,feedVisual=2,screenShake,bellUntil;
        float saveCheck;
        int lastCustomer;
        ParticleSystem fire,foam,score;
        Light fireLight;
        readonly System.Random visualRandom=new System.Random(411);
        readonly Dictionary<Transform,Vector3> restPositions=new Dictionary<Transform,Vector3>();
        readonly Dictionary<Transform,Quaternion> restRotations=new Dictionary<Transform,Quaternion>();
        void Awake()
        {
            Application.targetFrameRate=120; QualitySettings.vSyncCount=1;
            ReducedMotion=PlayerPrefs.GetInt("motion",0)==1;
            Volume=PlayerPrefs.GetFloat("volume",.75f); MusicVolume=PlayerPrefs.GetFloat("music",.25f);
            Model=new StandSimulation(20261104);
            World=new WorldBuilder(assets,transform); World.Build();
            foreach(var station in World.Stations.Values){restPositions[station.transform]=station.transform.position;restRotations[station.transform]=station.transform.rotation;}
            cameraRest=World.Camera.transform.position; cameraRotation=World.Camera.transform.rotation;
            scoopRest=World.Scoop.position; customerRest=World.Customer.position;
            if(World.Hands){handDriver=World.Hands.GetComponent<CharacterAnimationDriver>();handWork=World.Hands.gameObject.AddComponent<HandWorkstationDriver>();}
            customerDriver=World.Customer.GetComponent<CharacterAnimationDriver>();
            effects=gameObject.AddComponent<AudioSource>(); effects.spatialBlend=0;
            music=gameObject.AddComponent<AudioSource>(); music.clip=Sound("fairground_loop"); music.loop=true; music.volume=MusicVolume; if(music.clip) music.Play();
            fire=Particles("Oil flames",World.Fryer.position+new Vector3(0,.25f,0),new Color(1,.25f,.015f,.7f),.17f,70,1.0f);
            var shape=fire.shape; shape.shapeType=ParticleSystemShapeType.Box; shape.scale=new Vector3(.72f,.015f,.19f);
            var main=fire.main; main.startSpeed=new ParticleSystem.MinMaxCurve(.24f,.8f); main.startSize=new ParticleSystem.MinMaxCurve(.055f,.18f); main.gravityModifier=-.12f;
            if(assets.flame)
            {
                fire.GetComponent<ParticleSystemRenderer>().material.mainTexture=assets.flame;
                main.startColor=Color.white;main.startSize3D=true;main.startSizeX=new ParticleSystem.MinMaxCurve(.16f,.24f);main.startSizeY=new ParticleSystem.MinMaxCurve(.25f,.47f);main.startSizeZ=.2f;
                var emission=fire.emission;emission.rateOverTime=18;
                var fireColor=fire.colorOverLifetime;var fireGradient=new Gradient();fireGradient.SetKeys(new[]{new GradientColorKey(Color.white,0),new GradientColorKey(new Color(1,.55f,.25f),1)},new[]{new GradientAlphaKey(0,0),new GradientAlphaKey(.75f,.2f),new GradientAlphaKey(0,1)});fireColor.color=fireGradient;
            }
            var size=fire.sizeOverLifetime;size.enabled=true;size.size=new ParticleSystem.MinMaxCurve(1,AnimationCurve.EaseInOut(0,1,1,0));
            fire.Stop(true,ParticleSystemStopBehavior.StopEmittingAndClear);
            fireLight=new GameObject("Oil fire light",typeof(Light)).GetComponent<Light>(); fireLight.transform.position=fire.transform.position+Vector3.up*.25f; fireLight.color=new Color(1,.25f,.025f); fireLight.range=3; fireLight.intensity=0;
            foam=Particles("Extinguisher mist",World.Fryer.position+Vector3.up*.35f,new Color(.95f,.98f,1,.8f),.12f,110,.8f); foam.Stop(true,ParticleSystemStopBehavior.StopEmittingAndClear);
            score=Particles("Golden crumbs",new Vector3(.1f,1.6f,.2f),new Color(1,.67f,.18f),.018f,0,.9f); score.Stop();
            gameObject.AddComponent<StandHUD>().Initialize(this,assets);
            if(Environment.GetCommandLineArgs().Contains("--gh-practice"))StartShift(GameMode.Practice);
            if(Environment.GetCommandLineArgs().Contains("--gh-smoke")){StartShift(GameMode.Practice);StartCoroutine(SmokeRun());}
            if(Environment.GetCommandLineArgs().Contains("--gh-acceptance"))gameObject.AddComponent<SceneAcceptance>();
        }
        public void StartShift(GameMode mode,bool relaxed=false)
        {
            StopAllCoroutines(); Busy=false;
            foreach(var pair in restPositions)if(pair.Key){pair.Key.position=pair.Value;pair.Key.rotation=restRotations[pair.Key];}
            if(fire)fire.Stop(true,ParticleSystemStopBehavior.StopEmittingAndClear);
            if(foam)foam.Stop(true,ParticleSystemStopBehavior.StopEmittingAndClear);
            if(score)score.Stop(true,ParticleSystemStopBehavior.StopEmittingAndClear);
            foreach(var transient in GetComponentsInChildren<ParticleSystem>())if(transient!=fire&&transient!=foam&&transient!=score)Destroy(transient.gameObject);
            shakeCombo=0;lastShake=-10;screenShake=0;Celebration=0;
            handWork?.ClearToolTarget("L");handWork?.ClearToolTarget("R");
            foreach(var f in Food.Values)if(f)Destroy(f.gameObject); Food.Clear();
            if(Package)Destroy(Package.gameObject); Package=null;
            Model.Start(mode,relaxed); Menu=false;Paused=false;Time.timeScale=1;ScoopEquipped=false;PackageLifted=false;
            World.Scoop.SetParent(transform); World.Scoop.position=scoopRest;World.Scoop.rotation=Quaternion.identity;World.Scoop.gameObject.SetActive(true);
            World.Customer.position=customerRest;World.Customer.rotation=Quaternion.identity;World.Customer.gameObject.SetActive(true);
            int index=0; foreach(int id in Model.StockIds)
            {
                var d=CreateDonut(id,false); d.transform.position=World.TrayCenter+new Vector3((index%6-2.5f)*.066f,.045f+(index/18)*.035f,(index/6%3-1)*.077f);
                d.transform.rotation=Quaternion.Euler(Rand(-12,12),Rand(0,360),Rand(-12,12));d.InTray=true;d.MakePhysical();index++;
            }
            HandleEvents();Notify("Start with a bag. Scoop twice, add cinnamon, then hand it over.");
        }
        public void TogglePause()
        {
            if(Menu)return; Paused=!Paused;Time.timeScale=Paused?0:1;
            if(Paused)SaveSettings();
        }
        public void BackToMenu() { Menu=true;Paused=true;Time.timeScale=0;SaveSettings(); }
        public void SaveSettings() { PlayerPrefs.SetInt("motion",ReducedMotion?1:0);PlayerPrefs.SetFloat("volume",Volume);PlayerPrefs.SetFloat("music",MusicVolume);PlayerPrefs.Save(); }
        void Update()
        {
            music.volume=MusicVolume;effects.volume=Volume;
            if(Input.GetKeyDown(KeyCode.F11))Screen.fullScreen=!Screen.fullScreen;
            if(Input.GetKeyDown(KeyCode.Escape))TogglePause();
            if(Menu||Paused||Model.Phase!=GamePhase.Playing)return;
            Model.Tick(Time.deltaTime);HandleEvents();
            if(!Busy)
            {
                World.Customer.gameObject.SetActive(Model.CurrentOrder!=null);
                if(Model.CurrentOrder!=null&&Model.CurrentOrder.Id!=lastCustomer){lastCustomer=Model.CurrentOrder.Id;customerDriver?.PlayAction("Order",1.1f);}
                customerDriver?.SetMood(Model.CurrentOrder==null?1:(float)Model.CurrentOrder.PatienceRatio);
            }
            Celebration=Mathf.MoveTowards(Celebration,0,Time.deltaTime*.8f);
            screenShake=Mathf.MoveTowards(screenShake,0,Time.deltaTime*.7f);
            World.Camera.transform.position=cameraRest+(ReducedMotion?Vector3.zero:new Vector3(Mathf.Sin(Time.time*49),Mathf.Cos(Time.time*41),0)*screenShake*.012f);
            World.Camera.transform.rotation=cameraRotation;
            foreach(var l in World.Bulbs)l.intensity=.4f+Celebration*(1+Mathf.Sin(Time.time*15+l.transform.position.x));
            heatVisual=Mathf.Lerp(heatVisual,Model.HeatSetting,1-Mathf.Exp(-Time.deltaTime*12));
            if(World.HeatDial)World.HeatDial.localRotation=Quaternion.Euler(0,0,-120+heatVisual*60);
            feedVisual=Mathf.Lerp(feedVisual,Model.SpeedSetting,1-Mathf.Exp(-Time.deltaTime*12));
            if(World.ServiceDial)World.ServiceDial.localRotation=Quaternion.Euler(0,0,-120+feedVisual*60);
            AnimateMachine();
            if(Model.FireActive) { if(!fire.isPlaying)fire.Play();fireLight.intensity=1.8f+Mathf.Sin(Time.time*29)*.5f; }
            else { if(fire.isPlaying)fire.Stop();fireLight.intensity=0; }
            UpdatePointer();
            if(Busy||StandHUD.BlocksGameplayInput)return;
            if(Input.GetMouseButtonDown(0)&&Hover&&!StandHUD.PointerOverUI)Act(Hover.kind);
            if(Hover&&Hover.kind==StationKind.HeatDown&&Input.GetMouseButtonDown(1)){Report(Model.AdjustHeat(1));Cue("click");}
            if(Hover&&Hover.kind==StationKind.FeedDown&&Input.GetMouseButtonDown(1)){Report(Model.AdjustSpeed(1));Cue("click");}
            if(Input.GetMouseButton(0)&&Hover&&!StandHUD.PointerOverUI)
            {
                if(Hover.kind==StationKind.Repair){var r=Model.Repair(Time.deltaTime);Hint=r.Message;}
                if(Hover.kind==StationKind.Batter){var r=Model.Refill(Time.deltaTime);Hint=r.Message;}
            }
            if(Input.GetKeyDown(KeyCode.Alpha1))Act(StationKind.Bag);
            if(Input.GetKeyDown(KeyCode.Alpha2))Act(StationKind.Bucket);
            if(Input.GetKeyDown(KeyCode.E))Act(StationKind.Customer);
            if(Input.GetKeyDown(KeyCode.R))Act(ScoopEquipped?StationKind.Tray:StationKind.Scoop);
            if(Input.GetKeyDown(KeyCode.Q))Act(StationKind.Package);
            if(Input.GetKeyDown(KeyCode.C))Act(StationKind.Cinnamon);
            if(Input.GetKeyDown(KeyCode.V))Act(StationKind.Powdered);
        }
        void UpdatePointer()
        {
            if(Hover)Hover.Hovered=false;Hover=null;
            if(StandHUD.PointerOverUI||StandHUD.BlocksGameplayInput)return;
            Ray ray=World.Camera.ScreenPointToRay(Input.mousePosition);
            var hits=Physics.RaycastAll(ray,8,~0,QueryTriggerInteraction.Collide).OrderBy(h=>h.distance);
            foreach(var hit in hits){var s=hit.collider.GetComponentInParent<Station>();if(s){Hover=s;break;}}
            if(Hover) { Hover.Hovered=true;Hint=Hover.title; if(Hover.kind==StationKind.Tray)Hint=ScoopEquipped?"SCOOP · 3 MINI DONUTS":"SHAKE TRAY · CLICK QUICKLY FOR TROUBLE"; }
            else Hint=ScoopEquipped?"Scoop in hand · click tray to fill · click package to pour":"Click an object to use it";
        }
        public void Act(StationKind kind)
        {
            if(Busy||Paused||Menu||Model.Phase!=GamePhase.Playing)return;
            switch(kind)
            {
                case StationKind.Bag: ChoosePackage(PackageKind.Bag);break;
                case StationKind.Bucket: ChoosePackage(PackageKind.Bucket);break;
                case StationKind.Scoop:
                    ScoopEquipped=!ScoopEquipped;PackageLifted=false;
                    if(ScoopEquipped)TrackHand(World.Scoop,"R",new Vector3(0,.03f,-.08f));else handWork?.ClearToolTarget("R");
                    StartCoroutine(MoveTool(World.Scoop,ScoopEquipped?HeldScoop:scoopRest,.32f,"Reach"));Cue("click");break;
                case StationKind.Tray:
                    if(!ScoopEquipped){ShakeTray();break;}
                    var ids=Food.Values.Where(d=>d&&d.Reachable).OrderBy(d=>d.transform.position.y).Reverse().Select(d=>d.Id).ToArray();
                    var scoop=Model.Scoop(ids);if(Report(scoop))StartCoroutine(ScoopMotion(scoop.DonutIds));break;
                case StationKind.Package:
                    if(!Package){Notify("Choose a paper bag or bucket first.");break;}
                    if(Model.ScoopCount>0){var r=Model.Pour();if(Report(r))StartCoroutine(PourMotion(r.DonutIds));}
                    else {PackageLifted=!PackageLifted;if(PackageLifted)TrackHand(Package,"L",new Vector3(-.08f,.13f,0));else handWork?.ClearToolTarget("L");StartCoroutine(MoveTool(Package,PackageLifted?World.Camera.transform.TransformPoint(new Vector3(-.22f,-.32f,.60f)):World.PackageSpot.position,.40f,"Reach"));}break;
                case StationKind.Cinnamon: Coat(Coating.Cinnamon,kind);break;
                case StationKind.Powdered: Coat(Coating.Powdered,kind);break;
                case StationKind.Customer:
                    if(PackageLifted&&Package){var sale=Model.Serve();if(Report(sale))StartCoroutine(ServeMotion());}
                    else if(Package&&Model.PackageCount==Model.PackageCapacity&&Model.PackageCoating!=Coating.None){PackageLifted=true;var sale=Model.Serve();if(Report(sale))StartCoroutine(ServeMotion());}
                    else {var punch=Model.PunchCustomer();if(Report(punch))StartCoroutine(PunchMotion());}break;
                case StationKind.Waste: Discard();break;
                case StationKind.HeatDown: Report(Model.AdjustHeat(-1));Cue("click");break;
                case StationKind.HeatUp: Report(Model.AdjustHeat(1));Cue("click");break;
                case StationKind.FeedDown: Report(Model.AdjustSpeed(-1));Cue("click");break;
                case StationKind.FeedUp: Report(Model.AdjustSpeed(1));Cue("click");break;
                case StationKind.Extinguisher: if(Report(Model.ExtinguishFire())){foam.Play();StartCoroutine(StopFoam());handDriver?.PlayAction("Reach",.55f);Cue("fire_out");}break;
                case StationKind.Bell: if(Time.time>bellUntil){bellUntil=Time.time+.15f;Cue("bell");Notify("Ding! Management has been notified. Management is you.");}break;
            }
            HandleEvents();
        }
        void ChoosePackage(PackageKind kind)
        {
            PackageKind previous=Model.PackageKind;
            if(!Report(Model.ChoosePackage(kind)))return;
            if(Package&&previous==kind){Notify("Your "+kind.ToString().ToLowerInvariant()+" is already on the packing mat.");return;}
            if(Package)Destroy(Package.gameObject);
            var rack=World.Stations[kind==PackageKind.Bag?StationKind.Bag:StationKind.Bucket].transform;
            Package=World.Model(kind==PackageKind.Bag?assets.bag:assets.bucket,"Current order",rack.position);
            PackageLifted=false;StartCoroutine(MoveTool(Package,World.PackageSpot.position,.46f,"Reach"));Cue("bag_pickup");
        }
        void Coat(Coating coating,StationKind station)
        {
            if(!Report(Model.Coat(coating)))return;
            StartCoroutine(SeasonMotion(World.Stations[station].transform,coating));
        }
        void Discard()
        {
            var ids=Model.PackageIds.Concat(Model.ScoopIds).ToArray();var r=Model.Discard();if(!Report(r))return;
            int index=0;
            foreach(int id in ids)if(Food.TryGetValue(id,out var d)&&d)
            {
                d.transform.SetParent(transform);d.transform.position=Model.StockIds.Contains(id)?World.TrayCenter+new Vector3((index%6-2.5f)*.066f,.10f+index/18*.035f,(index/6%3-1)*.077f):new Vector3(1.48f,1.02f,-.07f);
                d.Pending=false;d.InTray=Model.StockIds.Contains(id);d.MakePhysical();
                d.Body.linearVelocity=Vector3.zero;d.Body.angularVelocity=Vector3.zero;index++;
            }
            if(Package)Destroy(Package.gameObject);Package=null;PackageLifted=false;Cue("drop");
        }
        IEnumerator MoveTool(Transform item,Vector3 target,float duration,string action)
        {
            Busy=true;handDriver?.PlayAction(action,duration);var from=item.position;var rot=item.rotation;
            for(float t=0;t<duration;t+=Time.deltaTime){if(!item)break;float f=Smooth(t/duration);item.position=Vector3.Lerp(from,target,f)+Vector3.up*(Mathf.Sin(f*Mathf.PI)*.09f);item.rotation=Quaternion.Slerp(rot,Quaternion.identity,f);yield return null;}
            if(item)item.position=target;Busy=false;
        }
        IEnumerator ScoopMotion(IReadOnlyList<int> ids)
        {
            Busy=true;handDriver?.PlayAction("Scoop",.65f);
            Vector3 from=World.Scoop.position,target=World.TrayCenter+new Vector3(0,.025f,-.02f);
            for(float t=0;t<.26f;t+=Time.deltaTime){World.Scoop.position=Vector3.Lerp(from,target,Smooth(t/.26f));World.Scoop.rotation=Quaternion.Euler(Mathf.Sin(t/.26f*Mathf.PI)*-25,0,0);yield return null;}
            int i=0;foreach(int id in ids)if(Food.TryGetValue(id,out var d)&&d){d.Hold();d.transform.SetParent(World.Scoop);d.transform.localPosition=new Vector3((i-1)*.042f,.045f,.07f);d.transform.localRotation=Quaternion.Euler(0,i*67,0);i++;}
            Cue("scoop");
            for(float t=0;t<.34f;t+=Time.deltaTime){World.Scoop.position=Vector3.Lerp(target,HeldScoop,Smooth(t/.34f));World.Scoop.rotation=Quaternion.Slerp(World.Scoop.rotation,Quaternion.identity,.15f);yield return null;}
            Busy=false;
        }
        IEnumerator PourMotion(IReadOnlyList<int> ids)
        {
            Busy=true;handDriver?.PlayAction("Pour",.82f);Vector3 start=World.Scoop.position;Vector3 target=Package.position+new Vector3(-.07f,.38f,0);
            for(float t=0;t<.30f;t+=Time.deltaTime){World.Scoop.position=Vector3.Lerp(start,target,Smooth(t/.30f));yield return null;}
            var destinations=new List<KeyValuePair<DonutBody,Vector3>>();int i=Model.PackageCount-ids.Count;
            foreach(int id in ids)if(Food.TryGetValue(id,out var d)&&d){d.transform.SetParent(Package);destinations.Add(new KeyValuePair<DonutBody,Vector3>(d,new Vector3(Mathf.Sin(i*2.4f)*.055f,.04f+(i/3)*.034f,Mathf.Cos(i*2.4f)*.035f)));i++;}
            var starts=destinations.Select(x=>x.Key.transform.localPosition).ToArray();
            for(float t=0;t<.27f;t+=Time.deltaTime){float f=Smooth(t/.27f);World.Scoop.rotation=Quaternion.Euler(0,0,-f*65);for(i=0;i<destinations.Count;i++)destinations[i].Key.transform.localPosition=Vector3.Lerp(starts[i],destinations[i].Value,f);yield return null;}
            Cue("pour");
            for(float t=0;t<.24f;t+=Time.deltaTime){World.Scoop.position=Vector3.Lerp(target,start,Smooth(t/.24f));World.Scoop.rotation=Quaternion.Euler(0,0,-65*(1-Smooth(t/.24f)));yield return null;}
            World.Scoop.rotation=Quaternion.identity;Busy=false;
        }
        IEnumerator SeasonMotion(Transform shaker,Coating coating)
        {
            Busy=true;handDriver?.PlayAction("Shake",.85f);Vector3 start=shaker.position;Quaternion rotation=shaker.rotation;Vector3 target=Package.position+new Vector3(0,.40f,0);
            TrackHand(shaker,"L",new Vector3(0,.06f,0));
            for(float t=0;t<.23f;t+=Time.deltaTime){shaker.position=Vector3.Lerp(start,target,Smooth(t/.23f));shaker.rotation=Quaternion.Euler(0,0,Smooth(t/.23f)*135);yield return null;}
            var dust=Particles("Sugar dust",target-Vector3.up*.10f,coating==Coating.Powdered?Color.white:new Color(.69f,.38f,.12f),.008f,80,.35f);var m=dust.main;m.startSpeed=.15f;m.gravityModifier=.6f;
            for(float t=0;t<.42f;t+=Time.deltaTime){shaker.position=target+Vector3.up*Mathf.Sin(t*65)*.018f;yield return null;}
            dust.Stop();Destroy(dust.gameObject,1);Cue("coat");
            foreach(int id in Model.PackageIds)if(Food.TryGetValue(id,out var d)&&d)foreach(var r in d.GetComponentsInChildren<Renderer>()){var block=new MaterialPropertyBlock();block.SetColor("_BaseColor",coating==Coating.Powdered?new Color(.98f,.91f,.78f):new Color(.65f,.29f,.08f));r.SetPropertyBlock(block);}
            for(float t=0;t<.22f;t+=Time.deltaTime){shaker.position=Vector3.Lerp(target,start,Smooth(t/.22f));shaker.rotation=Quaternion.Slerp(Quaternion.Euler(0,0,135),rotation,Smooth(t/.22f));yield return null;}
            shaker.position=start;shaker.rotation=rotation;handWork?.ClearToolTarget("L");Busy=false;
        }
        IEnumerator ServeMotion()
        {
            Busy=true;handDriver?.PlayAction("Handoff",.7f);customerDriver?.PlayAction("Receive",.7f);
            TrackHand(Package,"L",new Vector3(-.08f,.13f,0));
            Transform package=Package;Package=null;PackageLifted=false;Vector3 from=package.position;
            for(float t=0;t<.55f;t+=Time.deltaTime){package.position=Vector3.Lerp(from,new Vector3(.13f,1.14f,.80f),Smooth(t/.55f))+Vector3.up*Mathf.Sin(t/.55f*Mathf.PI)*.12f;yield return null;}
            Destroy(package.gameObject);handWork?.ClearToolTarget("L");Busy=false;customerDriver?.PlayAction("Happy",1.1f);
        }
        IEnumerator PunchMotion()
        {
            Busy=true;handDriver?.PlayAction("Punch",.28f,.025f);yield return new WaitForSeconds(.075f);
            customerDriver?.PlayAction("ComicRecoil",.55f,.025f);Cue("punch");screenShake=.8f;
            for(float t=0;t<.36f;t+=Time.deltaTime){float f=t/.36f;World.Customer.position=customerRest+new Vector3(f*f*1.4f,Mathf.Sin(f*Mathf.PI)*.32f,f*.35f);World.Customer.rotation=Quaternion.Euler(0,f*220,-Mathf.Sin(f*Mathf.PI)*40);yield return null;}
            World.Customer.position=customerRest;World.Customer.rotation=Quaternion.identity;Busy=false;
        }
        void ShakeTray()
        {
            shakeCombo=Time.time-lastShake<.38f?Mathf.Min(shakeCombo+1,6):1;lastShake=Time.time;
            foreach(var d in Food.Values)if(d&&d.InTray&&d.Body&&!d.Transferring)
            {
                Vector3 away=d.transform.position-World.TrayCenter;away.y=0;if(away.sqrMagnitude<.001f)away=new Vector3(Rand(-1,1),0,Rand(-1,1));
                d.Body.AddForce((away.normalized*Rand(.12f,.35f)+Vector3.up*(.22f+shakeCombo*.17f))*(shakeCombo>3?1.6f:1),ForceMode.VelocityChange);
                d.Body.AddTorque(new Vector3(Rand(-2,2),Rand(-2,2),Rand(-2,2)),ForceMode.VelocityChange);
            }
            StartCoroutine(TrayJiggle());Cue("tray_shake");if(shakeCombo>=4)Notify("DONUT WEATHER ADVISORY");
        }
        IEnumerator TrayJiggle(){Vector3 p=World.Tray.position;for(float t=0;t<.14f;t+=Time.deltaTime){World.Tray.position=p+new Vector3(Mathf.Sin(t*90)*.012f,0,0);yield return null;}World.Tray.position=p;}
        IEnumerator StopFoam(){yield return new WaitForSeconds(1.3f);foam.Stop();}
        public void MarkWaste(DonutBody donut){donut.InTray=false;donut.Pending=false;donut.Age=0;}
        Vector3 HeldScoop {get{return World.Camera.transform.TransformPoint(new Vector3(.22f,-.28f,.60f));}}
        void TrackHand(Transform tool,string side,Vector3 gripOffset)
        {
            if(!handWork||!tool)return;var grasp=tool.Find("GH_Grasp_"+side);
            if(!grasp){grasp=new GameObject("GH_Grasp_"+side).transform;grasp.SetParent(tool,false);grasp.localPosition=gripOffset;}
            handWork.SetToolTarget(grasp,1,side);
        }
        DonutBody CreateDonut(int id,bool pending)
        {
            Transform mesh=World.Model(assets.donut,"Mini donut #"+id,World.TrayCenter);
            var d=mesh.gameObject.AddComponent<DonutBody>();d.Id=id;d.Epoch=Model.Epoch;d.Owner=this;d.Pending=pending;Food[id]=d;return d;
        }
        IEnumerator Cook(int id,int epoch)
        {
            var d=CreateDonut(id,true);d.Transferring=true;
            Vector3[] path={new Vector3(-.51f,.24f,0),new Vector3(-.34f,.24f,0),new Vector3(.38f,.24f,0),new Vector3(.72f,.395f,0),new Vector3(.89f,.32f,0)};
            float[] seconds={.25f,2.0f,.65f,.30f};
            for(int n=0;n<4;n++)for(float t=0;t<seconds[n];t+=Time.deltaTime)
            {
                if(!d||epoch!=Model.Epoch)yield break;
                d.transform.position=World.Fryer.TransformPoint(Vector3.Lerp(path[n],path[n+1],t/seconds[n]));
                d.transform.rotation=Quaternion.Euler(0,id*47,(n==2?Mathf.Sin(t/seconds[n]*Mathf.PI)*13:0));yield return null;
            }
            d.transform.position=World.Fryer.TransformPoint(path[4]);d.MakePhysical();d.Body.linearVelocity=new Vector3(.15f,-.12f,Mathf.Sin(Time.time)*.08f);
        }
        void HandleEvents()
        {
            foreach(var e in Model.DrainEvents())
            {
                if(e.Type==GameEventType.Production)StartCoroutine(Cook(e.DeliveryId,e.Epoch));
                if(e.Type==GameEventType.Sale){Celebration=Mathf.Min(3,.6f+e.Receipt.Streak*.3f);screenShake=Celebration;score.Emit(12+e.Receipt.Streak*7);Cue(e.Receipt.Streak>=4?"sale_jackpot":"sale");Notify("+$"+e.Receipt.Amount.ToString("0.00")+"   •   "+e.Receipt.Streak+" SERVED IN A ROW");}
                if(e.Type==GameEventType.Jammed||e.Type==GameEventType.FireStarted||e.Type==GameEventType.Overheated||e.Type==GameEventType.JamWarning){Notify(e.Message);Cue("warning");}
                if(e.Type==GameEventType.Repaired||e.Type==GameEventType.Refilled||e.Type==GameEventType.FireExtinguished){Notify(e.Message);Cue("repair");}
                if(e.Type==GameEventType.CustomerArrived&&Model.CurrentOrder!=null&&Model.CurrentOrder.Id!=lastCustomer){lastCustomer=Model.CurrentOrder.Id;customerDriver?.PlayAction("Order",1.1f);}
            if(e.Type==GameEventType.ShiftEnded){Notify(e.Message);Cue(Model.Phase==GamePhase.Won?"win":"failure");PlayerPrefs.SetInt("best_streak",Math.Max(PlayerPrefs.GetInt("best_streak",0),Model.BestStreak));if(Model.Phase==GamePhase.Won)PlayerPrefs.SetInt("opening_cleared",1);PlayerPrefs.Save();Time.timeScale=0;}
            }
        }
        void AnimateMachine()
        {
            var plunger=WorldBuilder.Find(World.Fryer,"Plunger");if(plunger)plunger.localPosition=new Vector3(-.51f,.4f+Mathf.Sin(Time.time*5)*.018f,0);
            var flipper=WorldBuilder.Find(World.Fryer,"Flipper");if(flipper&&!Model.Jammed&&!Model.FireActive)flipper.localRotation=Quaternion.Euler(Time.time*60,0,0);
        }
        bool Report(ActionResult result){if(!result.Success)Notify(result.Message);return result.Success;}
        public void Notify(string text){Toast=text;ToastUntil=Time.unscaledTime+4.4f;}
        AudioClip Sound(string key){return assets.sounds?.FirstOrDefault(c=>c&&c.name==key)??assets.sounds?.FirstOrDefault(c=>c&&c.name.Contains(key));}
        void Cue(string key){var clip=Sound(key)??Sound("click");if(clip)effects.PlayOneShot(clip,1);OnCue?.Invoke(key);}
        float Rand(float min,float max){return min+(float)visualRandom.NextDouble()*(max-min);}
        static float Smooth(float t){t=Mathf.Clamp01(t);return t*t*t*(t*(t*6-15)+10);}
        ParticleSystem Particles(string name,Vector3 p,Color color,float size,float rate,float lifetime)
        {
            var go=new GameObject(name,typeof(ParticleSystem));go.transform.SetParent(transform);go.transform.position=p;var ps=go.GetComponent<ParticleSystem>();ps.Stop();
            var main=ps.main;main.startColor=color;main.startLifetime=lifetime;main.startSize=size;main.startSpeed=.4f;main.simulationSpace=ParticleSystemSimulationSpace.World;main.maxParticles=400;
            var emission=ps.emission;emission.rateOverTime=rate;var shape=ps.shape;shape.shapeType=ParticleSystemShapeType.Cone;shape.angle=25;shape.radius=.08f;
            var renderer=ps.GetComponent<ParticleSystemRenderer>();var mat=assets.particle?new Material(assets.particle):new Material(Shader.Find("Universal Render Pipeline/Particles/Unlit"));mat.SetFloat("_Surface",1);mat.SetFloat("_Blend",0);mat.EnableKeyword("_SURFACE_TYPE_TRANSPARENT");mat.SetInt("_SrcBlend",(int)UnityEngine.Rendering.BlendMode.SrcAlpha);mat.SetInt("_DstBlend",(int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);mat.SetInt("_ZWrite",0);mat.renderQueue=3000;
            var tex=new Texture2D(64,64,TextureFormat.RGBA32,false);for(int y=0;y<64;y++)for(int x=0;x<64;x++){float r=Vector2.Distance(new Vector2(x,y),new Vector2(31.5f,31.5f))/31.5f;tex.SetPixel(x,y,new Color(1,1,1,Mathf.Pow(Mathf.Clamp01(1-r),1.8f)));}tex.Apply();mat.mainTexture=tex;renderer.material=mat;
            var col=ps.colorOverLifetime;col.enabled=true;var gradient=new Gradient();gradient.SetKeys(new[]{new GradientColorKey(color,0),new GradientColorKey(color,1)},new[]{new GradientAlphaKey(.1f,0),new GradientAlphaKey(.85f,.15f),new GradientAlphaKey(0,1)});col.color=gradient;
            ps.Play();return ps;
        }
        IEnumerator SmokeRun()
        {
            yield return new WaitForSeconds(7);
            string dir=System.IO.Path.Combine(Application.persistentDataPath,"Captures");System.IO.Directory.CreateDirectory(dir);ScreenCapture.CaptureScreenshot(System.IO.Path.Combine(dir,"unity-workstation.png"));
            yield return new WaitForSeconds(1);
            Debug.Log("GH_SMOKE "+JsonUtility.ToJson(new SmokeResult{food=Food.Count,stock=Model.Supply,valid=Model.ValidateConservation().IsValid,scene=World.Camera!=null}));
            Application.Quit();
        }
        [Serializable]class SmokeResult {public int food,stock;public bool valid,scene;}
    }
}
