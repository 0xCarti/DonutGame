using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEngine;
using UnityEngine.UI;
using UnityEngine.EventSystems;

namespace GoldenHour.Presentation
{
    /// <summary>Opt-in native UI check using the actual visible buttons and controls.</summary>
    public sealed class MenuAcceptance : MonoBehaviour
    {
        StandController game;
        string directory;
        int checks;
        bool failed;
        IEnumerator Start()
        {
            game=GetComponent<StandController>();
            directory=Path.Combine(Application.persistentDataPath,"UIAcceptance",DateTime.UtcNow.ToString("yyyyMMdd-HHmmss"));
            Directory.CreateDirectory(directory);
            Application.logMessageReceived+=OnLog;
            yield return null;
            yield return Capture("01-menu");
            CheckTextFits("Golden");CheckTextFits("Hour");
            Check(game.Menu&&StandHUD.BlocksGameplayInput,"The menu blocks counter input");
            Click("Settings");yield return null;
            CheckTextFits("Settings title");
            var slider=GetComponentsInChildren<Slider>(true).First(s=>s.name=="Counter sound volume");
            float originalVolume=game.Volume;slider.value=.4f;
            Check(Mathf.Abs(game.Volume-.4f)<.001f,"Effects slider changes the live mix");slider.value=originalVolume;
            CheckSliderBounds(slider);
            CheckSliderBounds(GetComponentsInChildren<Slider>(true).First(s=>s.name=="Music volume"));
            var toggle=GetComponentsInChildren<Toggle>(true).First(t=>t.name=="Reduced motion");
            bool originalMotion=game.ReducedMotion;toggle.isOn=!originalMotion;
            Check(game.ReducedMotion==!originalMotion,"Reduced-motion control changes the operator setting");toggle.isOn=originalMotion;
            yield return Capture("02-settings");
            Click("Settings done");yield return null;
            Click("Field guide");yield return null;
            CheckTextFits("Guide title");
            yield return Capture("03-field-guide");
            Click("Guide done");yield return null;
            Click("Practice");yield return null;
            Check(!game.Menu&&!game.Paused&&game.Model.Mode==GameMode.Practice&&!StandHUD.BlocksGameplayInput,"Practice button opens the playable counter");
            game.TogglePause();yield return null;
            Check(game.Paused&&StandHUD.BlocksGameplayInput&&Time.timeScale==0,"Pause blocks counter input and stops the simulation");
            yield return Capture("04-pause");
            CheckTextFits("Pause title");
            Click("Resume");yield return null;
            Check(!game.Paused&&!StandHUD.BlocksGameplayInput&&Time.timeScale==1,"Resume returns control to the player");
            game.TogglePause();yield return null;
            Click("Main menu");yield return null;
            Check(game.Menu&&StandHUD.BlocksGameplayInput,"Return to the fair restores the menu");
            var result=new Result{passed=!failed,assertions=checks,width=Screen.width,height=Screen.height,captures=directory};
            string json=JsonUtility.ToJson(result,true);File.WriteAllText(Path.Combine(directory,"result.json"),json);Debug.Log("GH_UI_ACCEPTANCE "+json);
            Application.logMessageReceived-=OnLog;Application.Quit(failed?1:0);
        }
        void Click(string name)
        {
            var button=GetComponentsInChildren<Button>(true).FirstOrDefault(b=>b.name==name&&b.gameObject.activeInHierarchy);
            bool usable=button&&button.interactable;Check(usable,"Visible button is usable: "+name);
            if(usable)
            {
                Canvas.ForceUpdateCanvases();
                var rect=(RectTransform)button.transform;
                var pointer=new PointerEventData(EventSystem.current){position=RectTransformUtility.WorldToScreenPoint(null,rect.TransformPoint(rect.rect.center))};
                var hits=new List<RaycastResult>();EventSystem.current.RaycastAll(pointer,hits);
                Check(hits.Count>0&&hits[0].gameObject.GetComponentInParent<Button>()==button,"Button centre accepts pointer hits: "+name);
                button.onClick.Invoke();
            }
        }
        void CheckTextFits(string name)
        {
            var label=GetComponentsInChildren<Text>(true).First(t=>t.name==name);
            Check(label.preferredHeight<=label.rectTransform.rect.height+.5f,"Complete heading fits its text area: "+name);
        }
        void CheckSliderBounds(Slider slider)
        {
            float saved=slider.value;
            foreach(float value in new[]{0f,.4f,1f})
            {
                slider.value=value;Canvas.ForceUpdateCanvases();
                var frame=(RectTransform)slider.transform;var corners=new Vector3[4];slider.fillRect.GetWorldCorners(corners);
                Check(corners.All(p=>{var local=frame.InverseTransformPoint(p);return local.x>=frame.rect.xMin-.01f&&local.x<=frame.rect.xMax+.01f&&local.y>=frame.rect.yMin-.01f&&local.y<=frame.rect.yMax+.01f;}),"Slider fill stays inside its track: "+slider.name+" @ "+value);
            }
            slider.value=saved;
        }
        IEnumerator Capture(string name)
        {
            yield return new WaitForEndOfFrame();
            string path=Path.Combine(directory,name+".png");ScreenCapture.CaptureScreenshot(path);
            float until=Time.realtimeSinceStartup+5;
            while(!File.Exists(path)&&Time.realtimeSinceStartup<until)yield return null;
            Check(File.Exists(path),"Native UI screenshot saved: "+name);
        }
        void Check(bool condition,string description){checks++;failed|=!condition;Debug.Log((condition?"GH_UI_PASS ":"GH_UI_FAIL ")+description);}
        void OnLog(string message,string stack,LogType type){if(type==LogType.Exception||type==LogType.Error){failed=true;File.AppendAllText(Path.Combine(directory,"errors.txt"),message+"\n"+stack+"\n");}}
        [Serializable]sealed class Result{public bool passed;public int assertions,width,height;public string captures;}
    }
}
