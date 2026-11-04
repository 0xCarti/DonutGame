using System;
using System.Collections;
using System.IO;
using System.Linq;
using UnityEngine;

namespace GoldenHour.Presentation
{
    /// <summary>Opt-in player-side acceptance run. Exercises the real presentation and physics at real time.</summary>
    public sealed class SceneAcceptance : MonoBehaviour
    {
        StandController game;
        string directory;
        int assertions;
        bool failed;
        bool reachFailure;
        float unreachableSeconds;
        IEnumerator Start()
        {
            game=GetComponent<StandController>();
            directory=Path.Combine(Application.persistentDataPath,"Acceptance",DateTime.UtcNow.ToString("yyyyMMdd-HHmmss"));
            Directory.CreateDirectory(directory);
            Application.logMessageReceived+=OnLog;
            yield return null;
            game.StartShift(GameMode.Practice);
            game.Model.SetHeat(2);
            yield return new WaitForSecondsRealtime(5);
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
            yield return Capture("05-end-card");
            var result=new Result{passed=!failed,assertions=assertions,sales=(float)game.Model.Sales,served=game.Model.Served,wasted=game.Model.WasteCount,captures=directory};
            string json=JsonUtility.ToJson(result,true);File.WriteAllText(Path.Combine(directory,"result.json"),json);Debug.Log("GH_ACCEPTANCE "+json);
            Application.logMessageReceived-=OnLog;
            Application.Quit(failed?1:0);
        }
        IEnumerator ServeCurrent(bool checkReselect)
        {
            var order=game.Model.CurrentOrder;if(order==null)yield break;
            var kind=order.Package;
            game.Act(kind==PackageKind.Bag?StationKind.Bag:StationKind.Bucket);yield return Idle();
            if(!game.ScoopEquipped){game.Act(StationKind.Scoop);yield return Idle();}
            float deadline=Time.realtimeSinceStartup+24;
            while(game.Model.PackageCount<game.Model.PackageCapacity&&game.Model.Phase==GamePhase.Playing&&Time.realtimeSinceStartup<deadline)
            {
                if(game.Model.Jammed)game.Model.Repair(.1);
                if(game.Model.Batter<8)game.Model.Refill(.1);
                if(game.Model.ScoopCount==0)
                {
                    if(!game.Food.Values.Any(d=>d&&d.Reachable)){yield return new WaitForSecondsRealtime(.1f);continue;}
                    game.Act(StationKind.Tray);yield return Idle();
                }
                if(game.Model.ScoopCount>0){game.Act(StationKind.Package);yield return Idle();}
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
            game.Act(order.Coating==Coating.Cinnamon?StationKind.Cinnamon:StationKind.Powdered);yield return Idle();
            game.Act(StationKind.Package);yield return Idle();
            game.Act(StationKind.Customer);yield return Idle();
            Check(game.Model.ValidateConservation().IsValid,"Order action sequence preserves conservation");
        }
        IEnumerator Idle()
        {
            float deadline=Time.realtimeSinceStartup+4;
            yield return null;
            while(game.Busy&&game.Model.Phase==GamePhase.Playing&&Time.realtimeSinceStartup<deadline)yield return null;
            Check(!game.Busy||game.Model.Phase!=GamePhase.Playing,"Action animation completes or the shift ends within four real seconds");
            yield return null;
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
        void OnLog(string message,string stack,LogType type){if(type==LogType.Exception||type==LogType.Error){failed=true;File.AppendAllText(Path.Combine(directory,"errors.txt"),message+"\n"+stack+"\n");}}
        [Serializable]sealed class Result{public bool passed;public int assertions,served,wasted;public float sales;public string captures;}
    }
}
