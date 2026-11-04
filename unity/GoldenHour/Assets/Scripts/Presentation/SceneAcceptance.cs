using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;

namespace GoldenHour.Presentation
{
    /// <summary>Opt-in player-side acceptance run. Exercises the real presentation and physics at real time.</summary>
    [DefaultExecutionOrder(200)]
    public sealed class SceneAcceptance : MonoBehaviour
    {
        StandController game;
        string directory;
        int assertions;
        bool failed;
        bool reachFailure;
        float unreachableSeconds;
        float armIntersectionSeconds;
        bool armIntersectionFailure;
        bool captureMotion;
        int motionSequence;
        readonly List<float> frameTimes=new List<float>();
        IEnumerator Start()
        {
            game=GetComponent<StandController>();
            directory=Path.Combine(Application.persistentDataPath,"Acceptance",DateTime.UtcNow.ToString("yyyyMMdd-HHmmss"));
            Directory.CreateDirectory(directory);
            Application.logMessageReceived+=OnLog;
            yield return null;
            game.StartShift(GameMode.Practice);
            game.Model.SetHeat(2);
            yield return null;
            Check(game.Operator.ValidateHandAxes(out string axes),axes);
            yield return new WaitForSecondsRealtime(5);
            Quaternion heatBefore=game.World.HeatDial.rotation,feedBefore=game.World.ServiceDial.rotation;
            game.Model.SetHeat(1);yield return new WaitForSecondsRealtime(.3f);
            Check(Quaternion.Angle(heatBefore,game.World.HeatDial.rotation)>20&&Quaternion.Angle(feedBefore,game.World.ServiceDial.rotation)<.1f,"Heat dial turns independently of the feed dial");
            game.Model.SetHeat(2);
            Check(game.Model.Supply>game.Model.OpeningStock,"New production physically landed and entered stock");
            Check(game.Model.PendingDeliveryIds.Count>0,"Production pipeline has independently tracked in-flight food");
            yield return Capture("01-workstation");
            yield return ServeCurrent(true);
            Check(game.Model.Served==1,"Physical serving flow completed exactly one sale");
            Check(game.Model.Sales>0,"Sale produced earnings");
            Check(game.Model.ValidateConservation().IsValid,"All food accounted after the sale");
            yield return Capture("02-first-sale");
            game.Model.TriggerPracticeFault(MachineFault.Fire);
            yield return new WaitForSecondsRealtime(.5f);
            yield return Capture("03-fryer-fire");
            game.Act(StationKind.Extinguisher);
            yield return new WaitForSecondsRealtime(1.6f);
            Check(!game.Model.FireActive,"Fire extinguisher clears the active fire");
            // Drop the scoop to expose the empty-hand tray gag, then compound six quick taps.
            if(game.ScoopEquipped){game.Act(StationKind.Scoop);yield return Idle();}
            for(int i=0;i<6;i++){game.Act(StationKind.Tray);yield return new WaitForSecondsRealtime(.09f);}
            yield return new WaitForSecondsRealtime(2);
            Check(game.Model.ValidateConservation().IsValid,"Tray chaos preserves food accounting");
            yield return Capture("04-tray-chaos");
            int order=game.Model.CurrentOrder==null?-1:game.Model.CurrentOrder.Id;
            if(order!=-1)
            {
                game.Act(StationKind.Customer);yield return Idle();
                Check(game.Model.CurrentOrder==null||game.Model.CurrentOrder.Id!=order,"A punch skips the front customer");
            }
            game.StartShift(GameMode.Practice);game.Model.SetHeat(2);
            yield return ServeCurrent(false,true);
            game.StartShift(GameMode.Shift);
            game.Model.SetHeat(2);
            float deadline=Time.realtimeSinceStartup+145;
            while(game.Model.Phase==GamePhase.Playing&&Time.realtimeSinceStartup<deadline&&!failed)
            {
                if(game.Model.Jammed){game.Model.Repair(.1);yield return new WaitForSecondsRealtime(.1f);continue;}
                if(game.Model.Batter<12){game.Model.Refill(.1);yield return new WaitForSecondsRealtime(.1f);continue;}
                if(game.Model.CurrentOrder!=null)yield return ServeCurrent(false);
                else yield return new WaitForSecondsRealtime(.25f);
            }
            Check(game.Model.Phase==GamePhase.Won,"Opening Day reaches its winning end card");
            Check(game.Model.Sales>=game.Model.Target,"Won shift actually meets its earnings target");
            Check(game.Model.ValidateConservation().IsValid,"Completed level conserves all food");
            game.TogglePause();game.TogglePause();
            Check(Time.timeScale==0,"Escape cannot resume the simulation behind the completed shift card");
            yield return Capture("05-end-card");
            var ordered=frameTimes.OrderBy(x=>x).ToArray();
            var result=new Result{passed=!failed,assertions=assertions,sales=(float)game.Model.Sales,served=game.Model.Served,wasted=game.Model.WasteCount,captures=directory,width=Screen.width,height=Screen.height,averageFps=frameTimes.Count>0?1000f/frameTimes.Average():0,p95FrameMs=ordered.Length>0?ordered[(int)((ordered.Length-1)*.95f)]:0};
            string json=JsonUtility.ToJson(result,true);File.WriteAllText(Path.Combine(directory,"result.json"),json);Debug.Log("GH_ACCEPTANCE "+json);
            Application.logMessageReceived-=OnLog;
            Application.Quit(failed?1:0);
        }
        IEnumerator ServeCurrent(bool checkReselect,bool interruptHandoff=false)
        {
            captureMotion=checkReselect;
            var order=game.Model.CurrentOrder;if(order==null)yield break;
            var kind=order.Package;
            game.Act(kind==PackageKind.Bag?StationKind.Bag:StationKind.Bucket);yield return Idle("packaging");
            if(checkReselect)
            {
                Vector3 cameraPosition=game.World.Camera.transform.position;
                game.TogglePause();yield return new WaitForSecondsRealtime(.25f);
                Check(game.Paused&&Vector3.Distance(cameraPosition,game.World.Camera.transform.position)<.001f,"Pause freezes the operator pose");
                game.TogglePause();yield return new WaitForSecondsRealtime(.12f);
                var hands=game.World.Hands.GetComponent<HandWorkstationDriver>();
                Check(hands&&hands.LeftGripError<.035f&&!float.IsNaN(hands.LeftWeight),"Pausing and resuming preserves finite hand contact");
            }
            if(!game.ScoopEquipped){game.Act(StationKind.Scoop);yield return Idle("equip");}
            float deadline=Time.realtimeSinceStartup+24;
            while(game.Model.PackageCount<game.Model.PackageCapacity&&game.Model.Phase==GamePhase.Playing&&Time.realtimeSinceStartup<deadline)
            {
                if(game.Model.Jammed)game.Model.Repair(.1);
                if(game.Model.Batter<8)game.Model.Refill(.1);
                if(game.Model.ScoopCount==0)
                {
                    if(!game.Food.Values.Any(d=>d&&d.Reachable)){yield return new WaitForSecondsRealtime(.1f);continue;}
                    game.Act(StationKind.Tray);yield return Idle("scoop");
                    if(checkReselect&&game.Model.PackageCount==0)
                    {
                        int loaded=game.Model.ScoopCount;
                        game.Act(StationKind.Scoop);yield return Idle("put-loaded-scoop-down");
                        game.Act(StationKind.Package);
                        Check(game.Model.ScoopCount==loaded&&game.Model.PackageCount==0&&!game.Busy,"A dropped loaded scoop cannot pour by itself");
                        game.Act(StationKind.Scoop);yield return Idle("pick-loaded-scoop-up");
                    }
                }
                if(game.Model.ScoopCount>0){game.Act(StationKind.Package);yield return Idle("pour");}
            }
            if(game.Model.Phase!=GamePhase.Playing)yield break;
            Check(game.Model.PackageCount==game.Model.PackageCapacity,"Physical scoop/pour fills the requested package");
            if(checkReselect)
            {
                var package=game.Package;var ids=game.Model.PackageIds.ToArray();
                game.Act(kind==PackageKind.Bag?StationKind.Bag:StationKind.Bucket);yield return Idle();
                Check(game.Package==package&&ids.All(id=>game.Food.ContainsKey(id)&&game.Food[id]),"Re-selecting a filled package preserves its physical contents");
                yield return Capture("01b-filled-package");
            }
            game.Act(order.Coating==Coating.Cinnamon?StationKind.Cinnamon:StationKind.Powdered);yield return Idle("coat");
            game.Act(StationKind.Package);yield return Idle("lift");
            Transform departing=game.Package;
            game.Act(StationKind.Customer);
            if(interruptHandoff)
            {
                yield return new WaitForSecondsRealtime(.25f);
                game.TogglePause();game.BackToMenu();game.StartShift(GameMode.Practice);
                yield return null;
                Check(!departing&&game.Package==null&&!game.Busy,"Restarting during a handoff destroys the departing package");
                Check(game.Model.ValidateConservation().IsValid,"Restart during handoff resets food ownership cleanly");
                yield break;
            }
            yield return Idle("serve");
            Check(game.Model.ValidateConservation().IsValid,"Order action sequence preserves conservation");
            captureMotion=false;
        }
        IEnumerator Idle(string label="action")
        {
            float deadline=Time.realtimeSinceStartup+4;
            float started=Time.realtimeSinceStartup,nextCapture=started+.2f;
            int frame=0,sequence=++motionSequence;
            yield return null;
            while(game.Busy&&game.Model.Phase==GamePhase.Playing&&Time.realtimeSinceStartup<deadline)
            {
                if(captureMotion&&Time.realtimeSinceStartup>=nextCapture)
                {
                    ScreenCapture.CaptureScreenshot(Path.Combine(directory,$"motion-{sequence:D2}-{label}-{++frame:D2}.png"));
                    nextCapture=Time.realtimeSinceStartup+.4f;
                }
                yield return null;
            }
            Check(!game.Busy||game.Model.Phase!=GamePhase.Playing,label+" animation completes within four real seconds ("+(Time.realtimeSinceStartup-started).ToString("0.00")+"s)");
            yield return new WaitForSecondsRealtime(.08f);
            var hands=game.World.Hands.GetComponent<HandWorkstationDriver>();
            if(game.Model.Phase==GamePhase.Playing&&hands)
            {
                if(hands.RightTracking)Check(hands.RightGripError<.035f,label+" right hand contacts tool within 3.5cm ("+hands.RightGripError.ToString("0.000")+"m)");
                if(hands.LeftTracking)Check(hands.LeftGripError<.035f,label+" left hand contacts tool within 3.5cm ("+hands.LeftGripError.ToString("0.000")+"m)");
            }
        }
        IEnumerator Capture(string name)
        {
            yield return new WaitForEndOfFrame();
            string path=Path.Combine(directory,name+".png");
            ScreenCapture.CaptureScreenshot(path);
            yield return null;
            float deadline=Time.realtimeSinceStartup+5;
            while(!File.Exists(path)&&Time.realtimeSinceStartup<deadline)yield return null;
            Check(File.Exists(path),"Native screenshot saved: "+name);
        }
        void Check(bool condition,string message)
        {
            assertions++;if(!condition)failed=true;
            Debug.Log((condition?"GH_PASS ":"GH_FAIL ")+message);
        }
        void LateUpdate()
        {
            if(game&&game.Model.Phase==GamePhase.Playing&&!game.Paused&&Time.unscaledDeltaTime>0)frameTimes.Add(Time.unscaledDeltaTime*1000);
            CheckArmClearance();
            if(!game||reachFailure||!game.World.Hands)return;
            var hands=game.World.Hands.GetComponent<HandWorkstationDriver>();
            if(!hands)return;
            bool unreachable=(hands.RightTracking&&hands.RightWeight>.8f&&!hands.RightTargetWithinReach)
                ||(hands.LeftTracking&&hands.LeftWeight>.8f&&!hands.LeftTargetWithinReach);
            unreachableSeconds=unreachable?unreachableSeconds+Time.deltaTime:0;
            if(unreachableSeconds>.2f)
            {
                reachFailure=true;
                Check(false,"Hand-to-tool target stayed outside natural arm reach; inspect camera/workstation staging");
            }
        }
        void CheckArmClearance()
        {
            if(!game||armIntersectionFailure||!game.Package||!game.World.Hands||game.Paused)return;
            var collider=game.Package.GetComponent<BoxCollider>();
            var character=game.World.Hands.GetComponentInChildren<CharacterAnimationDriver>();
            if(!collider||!character)return;
            var interior=collider.bounds;interior.Expand(new Vector3(-.05f,-.04f,-.035f));
            bool intersects=false;string intersection="";
            foreach(string side in new[]{"L","R"})
            {
                var upper=character.FindBone("UpperArm."+side);var elbow=character.FindBone("Forearm."+side);var wrist=character.FindBone("Hand."+side);
                if(!upper||!elbow||!wrist)continue;
                for(int i=1;i<9;i++)
                    if(interior.Contains(Vector3.Lerp(upper.position,elbow.position,i/10f))||interior.Contains(Vector3.Lerp(elbow.position,wrist.position,i/10f)))
                    {intersects=true;intersection=$" side={side} upper={upper.position:F3} elbow={elbow.position:F3} wrist={wrist.position:F3} package={game.Package.position:F3} kind={game.Model.PackageKind}";}
            }
            armIntersectionSeconds=intersects?armIntersectionSeconds+Time.deltaTime:0;
            if(armIntersectionSeconds>.15f){armIntersectionFailure=true;ScreenCapture.CaptureScreenshot(Path.Combine(directory,"failure-arm-clearance.png"));Check(false,"Arm bones must not pass through the inside of the order package"+intersection);}
        }
        void OnLog(string message,string stack,LogType type){if(type==LogType.Exception||type==LogType.Error){failed=true;File.AppendAllText(Path.Combine(directory,"errors.txt"),message+"\n"+stack+"\n");}}
        [Serializable]sealed class Result{public bool passed;public int assertions,served,wasted,width,height;public float sales,averageFps,p95FrameMs;public string captures;}
    }
}
