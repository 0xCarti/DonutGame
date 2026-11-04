using System;
using System.Globalization;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

namespace GoldenHour.Presentation
{
    /// <summary>Screen-space fairground signage; physical service actions remain in the scene.</summary>
    public sealed class StandHUD : MonoBehaviour
    {
        static StandHUD active;
        static readonly Color Cream = new Color(.97f, .92f, .79f);
        static readonly Color Ink = new Color(.15f, .21f, .20f);
        static readonly Color Red = new Color(.66f, .18f, .14f);
        static readonly Color Teal = new Color(.11f, .31f, .29f);
        static readonly Color Gold = new Color(.91f, .66f, .29f);
        static readonly Color Muted = new Color(.44f, .46f, .39f);
        static readonly Color Shadow = new Color(.04f, .07f, .07f, .35f);
        StandController controller;
        StandAssets assets;
        Font font;
        Sprite whiteSprite;
        RectTransform canvasRoot, menuRoot, playRoot, pauseRoot, settingsRoot, guideRoot, endRoot;
        RectTransform ticket, saleToast, alertRoot;
        Text ticketNumber, ticketKind, ticketCoating, ticketQuantity, queueText, patienceText;
        Text salesText, goalText, clockText, modeText, stockText, batterText, heatText, machineText;
        Text hintText, heldText, sequenceText, toastText, alertTitle, alertText, comboText;
        Text endTitle, endSubtitle, endMoney, endGoal, endStats, endStreak;
        Text volumeValue, musicValue, menuBest, helpFooter;
        Image patienceFill, goalFill, batterFill, heatFill, alertBar, toastRule;
        Button endlessMenu, endlessEnd;
        Slider volumeSlider, musicSlider;
        Toggle motionToggle, relaxedToggle;
        CanvasGroup toastGroup;
        bool settingsOpen, guideOpen, relaxed;
        bool previousMenu = true, previousPaused = true;
        string previousToast = "";
        float previousToastUntil;
        float toastBegan;
        int previousTicket = -1;
        float ticketBegan;

        public static bool PointerOverUI
        {
            get { return EventSystem.current != null && EventSystem.current.IsPointerOverGameObject(); }
        }
        public static bool BlocksGameplayInput
        {
            get
            {
                return active != null && active.controller != null && (active.settingsOpen || active.guideOpen
                    || active.controller.Menu || active.controller.Paused || active.controller.Model.Phase != GamePhase.Playing);
            }
        }

        public void Initialize(StandController owner, StandAssets standAssets)
        {
            controller = owner;
            assets = standAssets;
            active = this;
            font = assets && assets.font ? assets.font : Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            whiteSprite = Sprite.Create(Texture2D.whiteTexture, new UnityEngine.Rect(0, 0, 1, 1), new Vector2(.5f, .5f));
            var canvasObject = new GameObject("Golden Hour · screen signage", typeof(RectTransform), typeof(Canvas), typeof(CanvasScaler), typeof(GraphicRaycaster));
            canvasObject.transform.SetParent(transform, false);
            canvasRoot = canvasObject.GetComponent<RectTransform>();
            var canvas = canvasObject.GetComponent<Canvas>();
            canvas.renderMode = RenderMode.ScreenSpaceOverlay;
            canvas.sortingOrder = 50;
            var scaler = canvasObject.GetComponent<CanvasScaler>();
            scaler.uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
            scaler.referenceResolution = new Vector2(1920, 1080);
            scaler.screenMatchMode = CanvasScaler.ScreenMatchMode.Expand;
            if (EventSystem.current == null)
            {
                var system = new GameObject("Golden Hour · UI input", typeof(EventSystem), typeof(StandaloneInputModule));
                system.transform.SetParent(transform, false);
            }
            Cursor.lockState = CursorLockMode.None;
            Cursor.visible = true;
            BuildPlayHUD();
            BuildMenu();
            BuildPause();
            BuildEndCard();
            BuildSettings();
            BuildGuide();
            RefreshVisibility();
        }

        void BuildMenu()
        {
            menuRoot = FullLayer("Main menu", new Color(.035f, .085f, .08f, .91f));
            var content = Center(menuRoot, "Menu composition", 1680, 940);
            Stripe(content, "Top gold rule", 0, 0, 1680, 3, Gold);
            Label(content, "Fairground header", "A LITTLE STAND. A VERY GOOD DAY.", 0, 30, 900, 36, 20, Gold, FontStyle.Bold);
            Label(content, "Edition", "FAIRGROUND  /  OPENING SEASON", 1170, 35, 510, 30, 17, Cream, FontStyle.Normal, TextAnchor.UpperRight);
            Label(content, "Golden", "GOLDEN", -6, 92, 750, 150, 104, Cream, FontStyle.Bold);
            Label(content, "Hour", "HOUR", -6, 219, 750, 150, 104, Cream, FontStyle.Bold);
            Label(content, "Menu introduction", "Hot donuts. Paper bags. One busy little fryer.\nMake every order a small occasion.", 3, 382, 660, 88, 28, Cream);
            ButtonAt(content, "Open the stand", "OPENING DAY     →", 0, 500, 620, 82, Red, Cream,
                delegate { LaunchMode(GameMode.Shift); }, 28);
            ButtonAt(content, "Practice", "PRACTICE AT THE FAIR", 0, 602, 303, 66, Cream, Teal,
                delegate { LaunchMode(GameMode.Practice); }, 21);
            endlessMenu = ButtonAt(content, "Endless", "AFTER HOURS  ·  LOCKED", 319, 602, 301, 66, Cream, Teal,
                delegate { LaunchMode(GameMode.Endless); }, 20);
            relaxedToggle = ToggleAt(content, "Relaxed pace", "RELAXED PACE", 2, 695, 610,
                delegate(bool value) { relaxed = value; }, false);
            Label(content, "Relaxed explanation", "More time. More patient customers. The same hands-on service.", 42, 739, 610, 48, 18, new Color(.76f, .79f, .69f));
            ButtonAt(content, "Field guide", "FIELD GUIDE", 0, 815, 220, 54, new Color(.16f, .29f, .26f), Cream, OpenGuide, 19);
            ButtonAt(content, "Settings", "SETTINGS", 238, 815, 180, 54, new Color(.16f, .29f, .26f), Cream, OpenSettings, 19);
            ButtonAt(content, "Quit", "CLOSE", 436, 815, 184, 54, new Color(.16f, .29f, .26f), Cream, delegate { Application.Quit(); }, 19);
            menuBest = Label(content, "Career note", "", 0, 902, 940, 34, 17, Gold);

            var poster = Panel(content, "Midway poster", 770, 107, 910, 724, Cream);
            poster.localRotation = Quaternion.Euler(0, 0, -1.2f);
            if (assets && assets.keyArt)
            {
                var artMount = Rect(poster, "Poster image inset", 18, 18, 874, 603);
                var artFrame = Rect(artMount, "Original fairground artwork", 0, 0, 874, 603);
                var art = artFrame.gameObject.AddComponent<RawImage>();
                art.texture = assets.keyArt;
                art.raycastTarget = false;
                float visibleWidth=(874f/603f)/((float)assets.keyArt.width/assets.keyArt.height);
                art.uvRect=new UnityEngine.Rect(1-visibleWidth,0,visibleWidth,1);
            }
            else
            {
                Label(poster, "Poster fallback", "FRESH FROM\nTHE FRYER", 62, 120, 780, 220, 74, Red, FontStyle.Bold, TextAnchor.MiddleCenter);
                Label(poster, "Poster fallback detail", "CINNAMON  •  POWDERED SUGAR", 42, 370, 826, 60, 28, Teal, FontStyle.Bold, TextAnchor.MiddleCenter);
            }
            Stripe(poster, "Poster baseline", 30, 636, 850, 2, Red);
            Label(poster, "Poster caption", "SCOOP.  SUGAR.  SERVE.  REPEAT.", 40, 657, 830, 42, 28, Red, FontStyle.Bold, TextAnchor.MiddleCenter);
            Label(content, "Menu bottom note", "105 SECONDS  /  $110 TARGET  /  MADE WITH YOUR OWN TWO HANDS", 810, 872, 860, 52, 17, Cream, FontStyle.Normal, TextAnchor.MiddleRight);
        }

        void BuildPlayHUD()
        {
            playRoot = EmptyLayer("At the counter");
            // Keep the tall hopper and the customer's face unobstructed.
            ticket = Corner(playRoot, "Order ticket", true, false, 420, 30, 320, 215);
            Paper(ticket, 320, 215);
            Stripe(ticket, "Red ticket band", 0, 0, 320, 30, Red);
            ticketNumber = Label(ticket, "Ticket number", "ORDER 001", 18, 5, 284, 23, 16, Cream, FontStyle.Bold);
            ticketKind = Label(ticket, "Package requested", "ONE BAG", 18, 42, 284, 41, 32, Ink, FontStyle.Bold);
            ticketCoating = Label(ticket, "Requested sugar", "CINNAMON", 18, 88, 284, 29, 21, Red, FontStyle.Bold);
            ticketQuantity = Label(ticket, "Required quantity", "6 warm mini donuts", 18, 125, 284, 25, 18, Ink);
            Dashes(ticket, 18, 159, 284, Muted);
            patienceText = Label(ticket, "Patience label", "PLENTY OF TIME", 18, 172, 284, 24, 16, Muted, FontStyle.Bold);
            patienceFill = Progress(ticket, "Customer patience", 18, 202, 284, 4, Teal, new Color(.75f, .72f, .62f));
            queueText = Label(playRoot, "Next tickets", "", 0, 0, 320, 58, 16, Cream, FontStyle.Normal);
            SetCorner(queueText.rectTransform, true, false, 420, 260, 320, 58);
            ShadowText(queueText);

            var takings = Corner(playRoot, "Daily takings sign", true, false, 34, 30, 354, 175);
            Panel(takings, "Takings backing", 0, 0, 354, 175, new Color(.065f, .18f, .17f, .94f));
            Stripe(takings, "Takings top rule", 0, 0, 354, 4, Gold);
            modeText = Label(takings, "Shift label", "OPENING DAY", 22, 18, 244, 23, 16, Gold, FontStyle.Bold);
            ButtonAt(takings, "Pause", "Ⅱ", 290, 14, 46, 40, new Color(.17f, .32f, .28f), Cream, delegate { controller.TogglePause(); }, 22);
            salesText = Label(takings, "Sales", "$0.00", 20, 49, 227, 59, 46, Cream, FontStyle.Bold);
            clockText = Label(takings, "Shift time", "1:45", 230, 60, 100, 42, 31, Gold, FontStyle.Bold, TextAnchor.MiddleRight);
            goalText = Label(takings, "Daily goal", "$110  OPENING DAY TARGET", 23, 119, 307, 23, 16, Cream);
            goalFill = Progress(takings, "Daily target", 23, 153, 307, 5, Gold, new Color(.25f, .36f, .30f));
            comboText = Label(playRoot, "Service streak", "", 0, 0, 354, 34, 17, Gold, FontStyle.Bold, TextAnchor.UpperRight);
            SetCorner(comboText.rectTransform, true, false, 56, 219, 333, 34);
            ShadowText(comboText);

            var gauges = Corner(playRoot, "Machine chalk strip", false, true, 24, 28, 370, 85);
            Panel(gauges, "Machine backing", 0, 0, 370, 85, new Color(.06f, .16f, .15f, .84f));
            stockText = Label(gauges, "Ready donuts", "TRAY   18 / 36", 12, 7, 161, 22, 16, Cream, FontStyle.Bold);
            batterText = Label(gauges, "Batter amount", "BATTER   72 / 72", 184, 7, 174, 22, 16, Cream, FontStyle.Bold);
            batterFill = Progress(gauges, "Batter level", 184, 30, 174, 3, Gold, Muted);
            heatText = Label(gauges, "Oil temperature", "175°C · HEAT 3/4 · FEED 2/4", 12, 34, 346, 22, 16, Cream);
            heatFill = Progress(gauges, "Oil temperature scale", 12, 58, 346, 3, Gold, Muted);
            machineText = Label(gauges, "Production state", "MAKING DONUTS", 12, 64, 346, 21, 16, new Color(.8f, .85f, .71f), FontStyle.Bold);

            var context = Corner(playRoot, "Interaction guidance", false, true, 518, 28, 800, 55);
            AnchorBottomCenter(context, 0, 28, 800, 55);
            hintText = Label(context, "Object action", "Click an object to use it", 0, 0, 800, 27, 20, Cream, FontStyle.Bold, TextAnchor.MiddleCenter);
            sequenceText = Label(context, "Next physical action", "", 0, 31, 800, 24, 16, Gold, FontStyle.Normal, TextAnchor.MiddleCenter);
            ShadowText(hintText); ShadowText(sequenceText);
            var held = Corner(playRoot, "Held order note", true, true, 24, 28, 340, 85);
            Panel(held, "Held backing", 0, 0, 340, 85, new Color(.06f, .16f, .15f, .84f));
            Label(held, "Preparation heading", "ON YOUR COUNTER", 12, 7, 316, 22, 16, Gold, FontStyle.Bold);
            heldText = Label(held, "Prepared order", "Bag [1] or bucket [2]", 12, 33, 316, 48, 17, Cream);
            helpFooter = Label(playRoot, "Shortcut footer", "TAB  WHOLE COUNTER     ·     F1  FIELD GUIDE     ·     ESC  PAUSE     ·     F11  FULLSCREEN", 0, 0, 1100, 24, 12, Cream, FontStyle.Normal, TextAnchor.MiddleCenter);
            AnchorBottomCenter(helpFooter.rectTransform, 0, 4, 1100, 24);
            ShadowText(helpFooter);

            alertRoot = Corner(playRoot, "Machine warning", false, true, 518, 118, 760, 74);
            AnchorBottomCenter(alertRoot, 0, 118, 760, 74);
            Panel(alertRoot, "Warning backing", 0, 0, 760, 74, new Color(.55f, .13f, .10f, .94f));
            alertBar = Progress(alertRoot, "Maintenance hold", 16, 65, 728, 4, Gold, new Color(.77f, .34f, .23f));
            alertTitle = Label(alertRoot, "Warning title", "FRYER FIRE", 16, 7, 728, 26, 21, Cream, FontStyle.Bold, TextAnchor.MiddleCenter);
            alertText = Label(alertRoot, "Warning action", "Click the red extinguisher beside the fryer.", 16, 37, 728, 24, 16, Cream, FontStyle.Normal, TextAnchor.MiddleCenter);

            saleToast = Rect(playRoot, "Counter announcement", 0, 0, 700, 78);
            saleToast.anchorMin = saleToast.anchorMax = new Vector2(.5f, 1);
            saleToast.pivot = new Vector2(.5f, 1);
            saleToast.anchoredPosition = new Vector2(-180, -30);
            Panel(saleToast, "Announcement backing", 0, 0, 700, 78, new Color(.06f, .18f, .16f, .94f));
            toastRule = Stripe(saleToast, "Announcement rule", 0, 0, 700, 3, Gold).GetComponent<Image>();
            toastText = Label(saleToast, "Announcement", "", 20, 10, 660, 60, 25, Cream, FontStyle.Bold, TextAnchor.MiddleCenter);
            toastText.resizeTextForBestFit = true;
            toastText.resizeTextMinSize = 19;
            toastText.resizeTextMaxSize = 28;
            toastGroup = saleToast.gameObject.AddComponent<CanvasGroup>();
            toastGroup.blocksRaycasts = false;
            toastGroup.interactable = false;
        }

        void BuildPause()
        {
            pauseRoot = FullLayer("Pause curtain", new Color(.025f, .08f, .075f, .83f));
            var card = Center(pauseRoot, "On a short break", 640, 700);
            Paper(card, 640, 700);
            Label(card, "Pause eyebrow", "THE FRYER CAN WAIT", 55, 47, 530, 32, 18, Red, FontStyle.Bold, TextAnchor.MiddleCenter);
            Label(card, "Pause title", "ON A\nSHORT BREAK", 45, 102, 550, 157, 57, Ink, FontStyle.Bold, TextAnchor.MiddleCenter);
            Label(card, "Pause detail", "Your stand is paused. Take your time.", 50, 278, 540, 42, 22, Muted, FontStyle.Normal, TextAnchor.MiddleCenter);
            ButtonAt(card, "Resume", "BACK TO THE COUNTER", 65, 357, 510, 70, Red, Cream, delegate { controller.TogglePause(); }, 25);
            ButtonAt(card, "Pause guide", "FIELD GUIDE", 65, 449, 246, 58, Teal, Cream, OpenGuide, 20);
            ButtonAt(card, "Pause settings", "SETTINGS", 329, 449, 246, 58, Teal, Cream, OpenSettings, 20);
            ButtonAt(card, "Main menu", "RETURN TO THE FAIR", 65, 529, 510, 58, new Color(.85f, .81f, .69f), Ink, delegate { controller.BackToMenu(); }, 20);
            Label(card, "Pause menu consequence", "Returning to the fair ends this attempt.", 65, 610, 510, 28, 16, Muted, FontStyle.Normal, TextAnchor.MiddleCenter);
        }

        void BuildSettings()
        {
            settingsRoot = FullLayer("Settings curtain", new Color(.025f, .08f, .075f, .96f));
            var content = Center(settingsRoot, "Settings", 1000, 800);
            Label(content, "Settings kicker", "MAKE YOURSELF COMFORTABLE", 0, 0, 1000, 30, 18, Gold, FontStyle.Bold);
            Label(content, "Settings title", "YOUR CORNER\nOF THE FAIR.", -4, 57, 1000, 184, 63, Cream, FontStyle.Bold);
            Stripe(content, "Settings rule", 0, 250, 1000, 2, Gold);
            Label(content, "Effects label", "COUNTER SOUNDS", 0, 296, 590, 32, 23, Cream, FontStyle.Bold);
            volumeValue = Label(content, "Effects percentage", "75%", 840, 296, 160, 32, 24, Gold, FontStyle.Bold, TextAnchor.UpperRight);
            volumeSlider = SliderAt(content, "Counter sound volume", 0, 351, 1000, controller.Volume, delegate(float value) { controller.Volume = value; });
            Label(content, "Music label", "FAIRGROUND MUSIC", 0, 424, 590, 32, 23, Cream, FontStyle.Bold);
            musicValue = Label(content, "Music percentage", "25%", 840, 424, 160, 32, 24, Gold, FontStyle.Bold, TextAnchor.UpperRight);
            musicSlider = SliderAt(content, "Music volume", 0, 479, 1000, controller.MusicVolume, delegate(float value) { controller.MusicVolume = value; });
            motionToggle = ToggleAt(content, "Reduced motion", "REDUCED MOTION", 0, 563, 1000,
                delegate(bool value) { controller.ReducedMotion = value; }, controller.ReducedMotion);
            Label(content, "Motion explanation", "Keeps the rewards and removes camera shake.", 43, 608, 940, 30, 19, Cream);
            Label(content, "Settings saving", "Your preferences are saved on this computer.", 0, 693, 680, 30, 18, new Color(.73f, .78f, .67f));
            ButtonAt(content, "Settings done", "DONE  →", 746, 686, 254, 68, Red, Cream,
                delegate { settingsOpen = false; controller.SaveSettings(); RefreshVisibility(); }, 24);
        }

        void BuildGuide()
        {
            guideRoot = FullLayer("Field guide curtain", new Color(.025f, .08f, .075f, .97f));
            var content = Center(guideRoot, "Field guide", 1490, 910);
            Label(content, "Guide eyebrow", "THE GOLDEN HOUR FIELD GUIDE", 0, 0, 1350, 32, 18, Gold, FontStyle.Bold);
            Label(content, "Guide title", "A GOOD ORDER,\nONE SMALL STEP AT A TIME.", -3, 57, 1480, 180, 60, Cream, FontStyle.Bold);
            Stripe(content, "Guide rule", 0, 243, 1490, 2, Gold);
            GuideStep(content, 0, 293, "01", "PAPER FIRST", "Read the ticket. Pick a bag for 6\nor a bucket for 12 mini donuts.", "1  BAG     2  BUCKET");
            GuideStep(content, 505, 293, "02", "SCOOP & POUR", "Pick up the scoop, then the tray.\nPour 3 at a time into the package.", "R  EQUIP / SCOOP     Q  POUR");
            GuideStep(content, 1010, 293, "03", "SUGAR & SERVE", "Fill the package. Add the right sugar,\nthen lift it and hand it over.", "C / V  SUGAR     Q  LIFT     E  SERVE");
            Dashes(content, 0, 532, 1490, new Color(.46f, .55f, .43f));
            Label(content, "Machine guide", "LOOK AFTER THE LITTLE FRYER", 0, 570, 920, 35, 24, Gold, FontStyle.Bold);
            Label(content, "Machine directions", "JAM   Hold the motor service control. TAB shows the whole counter.\nBATTER   Hold the hopper to refill.\nHEAT / FEED   Left-click a dial to lower; right-click to raise.\nFIRE   Press F or click the extinguisher. Reset the heat afterward.", 0, 625, 875, 151, 21, Cream);
            Label(content, "Recovery guide", "A WRONG TURN?", 1030, 570, 460, 35, 24, Gold, FontStyle.Bold);
            Label(content, "Recovery directions", "An unfinished order can be completed.\nWrong sugar? Use the discard opening.\nPlain donuts return if the tray has room.\nClicking a customer empty-handed\nskips them and breaks your streak.", 1030, 625, 460, 158, 19, Cream);
            Label(content, "Guide physical note", "Fresh donuts become stock after they land. Rapid tray clicks can send them flying.", 0, 843, 1140, 35, 18, new Color(.76f, .80f, .70f));
            ButtonAt(content, "Guide done", "GOT IT  →", 1236, 825, 254, 68, Red, Cream,
                delegate { guideOpen = false; RefreshVisibility(); }, 24);
        }

        void GuideStep(RectTransform parent, float x, float y, string number, string title, string description, string keys)
        {
            Label(parent, title + " number", number, x, y, 70, 45, 35, Gold, FontStyle.Bold);
            Label(parent, title + " heading", title, x + 86, y + 8, 385, 38, 25, Cream, FontStyle.Bold);
            Label(parent, title + " explanation", description, x, y + 75, 480, 71, 22, Cream);
            Label(parent, title + " shortcuts", keys, x, y + 170, 480, 31, 16, Gold, FontStyle.Bold);
        }

        void BuildEndCard()
        {
            endRoot = FullLayer("End of day", new Color(.025f, .08f, .075f, .90f));
            var card = Center(endRoot, "End of day receipt", 870, 920);
            Paper(card, 870, 920);
            Label(card, "Receipt eyebrow", "GOLDEN HOUR  /  END OF DAY", 50, 38, 770, 32, 18, Red, FontStyle.Bold, TextAnchor.MiddleCenter);
            endTitle = Label(card, "Day verdict", "A VERY\nGOOD DAY.", 55, 90, 760, 168, 58, Ink, FontStyle.Bold, TextAnchor.MiddleCenter);
            endSubtitle = Label(card, "Day note", "Opening Day complete. After Hours is yours.", 60, 256, 750, 56, 23, Muted, FontStyle.Normal, TextAnchor.MiddleCenter);
            Dashes(card, 65, 336, 740, Muted);
            endMoney = Label(card, "Final sales", "$0.00", 60, 369, 750, 87, 72, Red, FontStyle.Bold, TextAnchor.MiddleCenter);
            endGoal = Label(card, "Sales comparison", "TAKEN AT THE WINDOW  /  $110 TARGET", 60, 469, 750, 32, 17, Muted, FontStyle.Bold, TextAnchor.MiddleCenter);
            endStats = Label(card, "Day statistics", "0 SERVED      0 MISSED      0 WASTED", 60, 537, 750, 36, 23, Ink, FontStyle.Bold, TextAnchor.MiddleCenter);
            endStreak = Label(card, "Best service run", "BEST STREAK  0", 60, 587, 750, 31, 18, Teal, FontStyle.Bold, TextAnchor.MiddleCenter);
            Dashes(card, 65, 644, 740, Muted);
            ButtonAt(card, "Try another day", "PLAY OPENING DAY AGAIN", 65, 686, 740, 68, Red, Cream, delegate { LaunchMode(GameMode.Shift); }, 25);
            endlessEnd = ButtonAt(card, "Continue after hours", "AFTER HOURS", 65, 777, 359, 59, Teal, Cream, delegate { LaunchMode(GameMode.Endless); }, 21);
            ButtonAt(card, "End menu", "BACK TO THE FAIR", 442, 777, 363, 59, new Color(.84f, .80f, .68f), Ink, delegate { controller.BackToMenu(); }, 21);
            Label(card, "Receipt footer", "FRESH DONUTS. WELL EARNED.", 60, 865, 750, 25, 14, Muted, FontStyle.Bold, TextAnchor.MiddleCenter);
        }

        void Update()
        {
            if (controller == null) return;
            if (Input.GetKeyDown(KeyCode.F1))
            {
                if (guideOpen) guideOpen = false;
                else OpenGuide();
            }
            if ((previousPaused && !controller.Paused) || (!previousMenu && controller.Menu))
            {
                if (settingsOpen) controller.SaveSettings();
                settingsOpen = guideOpen = false;
            }
            previousMenu = controller.Menu;
            previousPaused = controller.Paused;
            RefreshVisibility();
            if (menuRoot.gameObject.activeSelf)
            {
                bool unlocked = PlayerPrefs.GetInt("opening_cleared", 0) == 1;
                endlessMenu.interactable = unlocked;
                endlessMenu.GetComponentInChildren<Text>().text = unlocked ? "AFTER HOURS" : "AFTER HOURS · LOCKED";
                menuBest.text = unlocked ? "OPENING DAY CLEARED     /     BEST SERVICE STREAK  " + PlayerPrefs.GetInt("best_streak", 0)
                    : "CLEAR OPENING DAY TO UNLOCK AFTER HOURS.";
            }
            if (settingsOpen)
            {
                volumeValue.text = Mathf.RoundToInt(controller.Volume * 100) + "%";
                musicValue.text = Mathf.RoundToInt(controller.MusicVolume * 100) + "%";
            }
            if (playRoot.gameObject.activeSelf) RefreshPlayHUD();
            if (endRoot.gameObject.activeSelf) RefreshEndCard();
        }

        void RefreshVisibility()
        {
            bool ended = controller.Model.Phase == GamePhase.Won || controller.Model.Phase == GamePhase.Lost;
            bool overlay = settingsOpen || guideOpen;
            menuRoot.gameObject.SetActive(controller.Menu && !overlay);
            playRoot.gameObject.SetActive(!controller.Menu && !ended && !overlay);
            pauseRoot.gameObject.SetActive(!controller.Menu && controller.Paused && !ended && !overlay);
            endRoot.gameObject.SetActive(!controller.Menu && ended && !overlay);
            settingsRoot.gameObject.SetActive(settingsOpen);
            guideRoot.gameObject.SetActive(guideOpen);
        }

        void RefreshPlayHUD()
        {
            var model = controller.Model;
            var order = model.CurrentOrder;
            int orderId = order == null ? -1 : order.Id;
            if (orderId != previousTicket) { previousTicket = orderId; ticketBegan = Time.unscaledTime; }
            float entrance = controller.ReducedMotion ? 1 : Mathf.Clamp01((Time.unscaledTime - ticketBegan) * 6);
            ticket.localRotation = Quaternion.Euler(0, 0, Mathf.Lerp(-2.5f, -.4f, entrance));
            if (order != null)
            {
                ticketKind.resizeTextForBestFit = false;
                ticketKind.fontSize = 32;
                ticketNumber.text = "ORDER " + order.Id.ToString("000");
                ticketKind.text = order.Package == PackageKind.Bag ? "ONE BAG" : "ONE BUCKET";
                ticketCoating.text = order.Coating == Coating.Powdered ? "POWDERED SUGAR" : "CINNAMON SUGAR";
                ticketQuantity.text = order.Quantity + " warm mini donuts";
                patienceFill.fillAmount = (float)order.PatienceRatio;
                patienceFill.color = order.PatienceRatio < .3 ? Red : Teal;
                patienceText.text = model.Mode == GameMode.Practice ? "TAKE YOUR TIME  ·  PRACTICE"
                    : order.PatienceRatio < .3 ? "GETTING RESTLESS  ·  " + Mathf.CeilToInt((float)order.Patience) + "s"
                    : order.PatienceRatio < .6 ? "WAITING PATIENTLY" : "PLENTY OF TIME";
            }
            else
            {
                ticketNumber.text = "AT THE WINDOW";
                ticketKind.text = "A QUIET MOMENT";
                ticketKind.resizeTextForBestFit = true;
                ticketKind.resizeTextMinSize = 27;
                ticketKind.resizeTextMaxSize = 32;
                ticketCoating.text = "THE FAIR IS STILL OPEN";
                ticketQuantity.text = "The next guest is on their way.";
                patienceText.text = "READY WHEN THEY ARE";
                patienceFill.fillAmount = 0;
            }
            string queue = "";
            for (int i = 1; i < model.Orders.Count; i++)
            {
                var waiting = model.Orders[i];
                queue += (i == 1 ? "NEXT  " : "THEN  ") + (waiting.Package == PackageKind.Bag ? "BAG" : "BUCKET") + " / "
                    + (waiting.Coating == Coating.Powdered ? "POWDERED" : "CINNAMON") + (i < model.Orders.Count - 1 ? "\n" : "");
            }
            queueText.text = queue;
            modeText.text = model.Mode == GameMode.Practice ? "PRACTICE AT THE FAIR" : model.Mode == GameMode.Endless ? "AFTER HOURS" : model.Relaxed ? "OPENING DAY · RELAXED" : "OPENING DAY";
            salesText.text = "$" + model.Sales.ToString("0.00", CultureInfo.InvariantCulture);
            clockText.text = model.Mode == GameMode.Shift ? Clock(model.TimeLeft) : model.Mode == GameMode.Practice ? "∞" : Clock(model.Elapsed);
            clockText.color = model.Mode == GameMode.Shift && model.TimeLeft <= 20 ? new Color(1, .54f, .36f) : Gold;
            goalText.text = model.Mode == GameMode.Practice ? "PRACTICE · NO CLOCK OR QUOTA"
                : model.Mode == GameMode.Endless ? model.Served + " SERVED · KEEP THE FAIR MOVING"
                : model.Sales >= model.Target ? "TARGET MET · KEEP THEM COMING" : "$" + model.Target + "  OPENING DAY TARGET";
            goalFill.fillAmount = model.Mode == GameMode.Shift ? Mathf.Clamp01((float)(model.Sales / model.Target)) : 1;
            comboText.text = model.Streak >= 2 ? model.Streak + " IN A ROW · NEXT TIP +$" + (Math.Min(model.Streak, 5) * .5m).ToString("0.00", CultureInfo.InvariantCulture) : "";
            stockText.text = "TRAY   " + model.Supply + " / " + model.SupplyCapacity;
            batterText.text = "BATTER   " + model.Batter + " / " + model.BatterCapacity;
            batterFill.fillAmount = (float)model.Batter / model.BatterCapacity;
            batterFill.color = model.Batter <= 12 ? new Color(1, .46f, .29f) : Gold;
            heatText.text = Mathf.RoundToInt((float)model.Temperature) + "°C · HEAT " + model.HeatSetting + "/4 · FEED " + model.SpeedSetting + "/4";
            heatFill.fillAmount = Mathf.InverseLerp(90, 240, (float)model.Temperature);
            heatFill.color = model.Temperature >= 195 ? new Color(1, .46f, .29f) : Gold;
            machineText.text = model.ProductionStatus.ToUpperInvariant();
            hintText.text = controller.Busy ? "A LITTLE CARE MAKES A GOOD ORDER." : controller.Hint;
            sequenceText.text = NextStep();
            heldText.text = HeldDescription();
            RefreshWarning();
            RefreshToast();
        }

        string NextStep()
        {
            var model = controller.Model;
            if (model.FireActive) return "F  EXTINGUISH  →  SET HEAT TO 2  →  RESUME SERVICE";
            if (model.PackageKind == PackageKind.None) return "1 / 2  CHOOSE PACKAGE     ·     R  PICK UP SCOOP";
            if (model.ScoopCount > 0) return "Q  POUR " + model.ScoopCount + " DONUTS INTO YOUR " + model.PackageKind.ToString().ToUpperInvariant();
            if (model.PackageCount < model.PackageCapacity) return controller.ScoopEquipped ? "R  SCOOP THREE     →     Q  POUR" : "R  PICK UP THE SCOOP     →     R  SCOOP THREE";
            if (model.PackageCoating == Coating.None) return "C  CINNAMON     /     V  POWDERED SUGAR";
            return controller.PackageLifted ? "E  HAND OVER THE ORDER" : "Q  LIFT YOUR ORDER     →     E  HAND IT OVER";
        }

        string HeldDescription()
        {
            var model = controller.Model;
            if (model.PackageKind == PackageKind.None) return controller.ScoopEquipped ? "Scoop in hand\nBag [1] or bucket [2]" : "Bag [1] or bucket [2]\nScoop holds 3 mini donuts";
            string line = model.PackageKind.ToString().ToUpperInvariant() + "   " + model.PackageCount + " / " + model.PackageCapacity;
            string second = model.PackageCoating == Coating.None ? "PLAIN" : model.PackageCoating == Coating.Powdered ? "POWDERED SUGAR" : "CINNAMON SUGAR";
            if (model.ScoopCount > 0) second += " · SCOOP " + model.ScoopCount;
            if (controller.PackageLifted) second += " · LIFTED";
            return line + "\n" + second;
        }

        void RefreshWarning()
        {
            var model = controller.Model;
            string title = null, detail = "";
            float progress = 0;
            if (model.FireActive) { title = "FRYER FIRE"; detail = "Press F or click the red extinguisher. TAB shows the whole counter."; progress = 1; }
            else if (model.FireRecovery > 0) { title = "LET THE FRYER SETTLE"; detail = "Fire out. Set the heat to 2 when the fryer is ready."; progress = 1 - (float)model.FireRecovery / 2.4f; }
            else if (model.Jammed) { title = "FEEDER JAMMED"; detail = "Hold the motor service control on the left of the machine."; progress = (float)model.RepairProgress; }
            else if (model.Overheated) { title = "THE OIL IS TOO HOT"; detail = "Left-click the heat dial to lower it. Setting 2 is steady."; progress = (float)model.FireDanger; }
            else if (model.Batter == 0 || model.RefillProgress > 0) { title = "BATTER " + (model.Batter == 0 ? "HOPPER EMPTY" : "REFILL"); detail = "Hold the batter hopper to refill. Partial progress is kept."; progress = (float)model.RefillProgress; }
            else if (model.Temperature < 145) { title = "WAITING FOR THE OIL"; detail = "Right-click the heat dial to raise it. Setting 2 is steady."; progress = Mathf.InverseLerp(90, 145, (float)model.Temperature); }
            else if (model.RepairProgress > 0) { title = "SERVICING THE FEEDER"; detail = "Keep holding the motor service control to finish."; progress = (float)model.RepairProgress; }
            else if (model.SpeedSetting == 0) { title = "FEED PAUSED"; detail = "Right-click the feed dial to start making donuts. The oil is still hot."; }
            alertRoot.gameObject.SetActive(title != null);
            if (title != null) { alertTitle.text = title; alertText.text = detail; alertBar.fillAmount = progress; }
        }

        void RefreshToast()
        {
            if (controller.Toast != previousToast || controller.ToastUntil != previousToastUntil)
            {
                previousToast = controller.Toast;
                previousToastUntil = controller.ToastUntil;
                toastBegan = Time.unscaledTime;
                toastText.text = previousToast;
                bool sale = previousToast.StartsWith("+$", StringComparison.Ordinal);
                toastText.color = sale ? Gold : Cream;
                toastRule.color = sale ? Gold : Red;
            }
            float left = controller.ToastUntil - Time.unscaledTime;
            float age = Time.unscaledTime - toastBegan;
            bool visible = left > 0 && !string.IsNullOrEmpty(previousToast);
            toastGroup.alpha = visible ? Mathf.Min(Mathf.Clamp01(age * 9), Mathf.Clamp01(left * 3)) : 0;
            if (controller.ReducedMotion) saleToast.localScale = Vector3.one;
            else
            {
                float pulse = Mathf.Sin(Mathf.Clamp01(age * 4) * Mathf.PI) * .035f;
                saleToast.localScale = Vector3.one * (1 + pulse);
            }
        }

        void RefreshEndCard()
        {
            var model = controller.Model;
            bool won = model.Phase == GamePhase.Won;
            endTitle.text = won ? "A VERY\nGOOD DAY." : "ANOTHER DAY,\nANOTHER DOZEN.";
            endSubtitle.text = won ? "Opening Day complete. After Hours is yours." : "The fair will be here. Find your rhythm and try again.";
            endMoney.text = "$" + model.Sales.ToString("0.00", CultureInfo.InvariantCulture);
            endGoal.text = "TAKEN AT THE WINDOW  /  $" + model.Target + " TARGET";
            endStats.text = model.Served + " SERVED      " + model.Missed + " MISSED      " + model.WasteCount + " WASTED";
            endStreak.text = "BEST STREAK  " + model.BestStreak + "      /      " + model.Mistakes + " ORDER MISTAKES";
            bool unlocked = PlayerPrefs.GetInt("opening_cleared", 0) == 1 || won;
            endlessEnd.interactable = unlocked;
            endlessEnd.GetComponentInChildren<Text>().text = unlocked ? "AFTER HOURS" : "AFTER HOURS · LOCKED";
        }

        void LaunchMode(GameMode mode)
        {
            if (mode == GameMode.Endless && PlayerPrefs.GetInt("opening_cleared", 0) != 1) return;
            settingsOpen = guideOpen = false;
            previousToast = "";
            previousTicket = -1;
            controller.StartShift(mode, relaxed);
            RefreshVisibility();
        }
        void OpenSettings()
        {
            if (!controller.Menu && !controller.Paused) controller.TogglePause();
            settingsOpen = true;
            guideOpen = false;
            volumeSlider.SetValueWithoutNotify(controller.Volume);
            musicSlider.SetValueWithoutNotify(controller.MusicVolume);
            motionToggle.SetIsOnWithoutNotify(controller.ReducedMotion);
            RefreshVisibility();
        }
        void OpenGuide()
        {
            if (!controller.Menu && !controller.Paused) controller.TogglePause();
            guideOpen = true;
            settingsOpen = false;
            RefreshVisibility();
        }
        static string Clock(double seconds)
        {
            int value = Mathf.CeilToInt((float)seconds);
            return (value / 60) + ":" + (value % 60).ToString("00");
        }

        RectTransform EmptyLayer(string name)
        {
            var result = Rect(canvasRoot, name, 0, 0, 0, 0);
            Stretch(result);
            return result;
        }
        RectTransform FullLayer(string name, Color color)
        {
            var result = EmptyLayer(name);
            var image = result.gameObject.AddComponent<Image>();
            image.color = color;
            image.raycastTarget = true;
            return result;
        }
        static void Stretch(RectTransform rect)
        {
            rect.anchorMin = Vector2.zero; rect.anchorMax = Vector2.one;
            rect.offsetMin = rect.offsetMax = Vector2.zero;
        }
        RectTransform Rect(Transform parent, string name, float x, float y, float width, float height)
        {
            var result = new GameObject(name, typeof(RectTransform)).GetComponent<RectTransform>();
            result.SetParent(parent, false);
            result.anchorMin = result.anchorMax = new Vector2(0, 1);
            result.pivot = new Vector2(0, 1);
            result.anchoredPosition = new Vector2(x, -y);
            result.sizeDelta = new Vector2(width, height);
            return result;
        }
        RectTransform Center(Transform parent, string name, float width, float height)
        {
            var result = Rect(parent, name, 0, 0, width, height);
            result.anchorMin = result.anchorMax = result.pivot = new Vector2(.5f, .5f);
            return result;
        }
        RectTransform Corner(Transform parent, string name, bool right, bool bottom, float x, float y, float width, float height)
        {
            var result = Rect(parent, name, x, y, width, height);
            SetCorner(result, right, bottom, x, y, width, height);
            return result;
        }
        static void SetCorner(RectTransform result, bool right, bool bottom, float x, float y, float width, float height)
        {
            result.anchorMin = result.anchorMax = result.pivot = new Vector2(right ? 1 : 0, bottom ? 0 : 1);
            result.anchoredPosition = new Vector2(right ? -x : x, bottom ? y : -y);
            result.sizeDelta = new Vector2(width, height);
        }
        static void AnchorBottomCenter(RectTransform result, float x, float y, float width, float height)
        {
            result.anchorMin = result.anchorMax = result.pivot = new Vector2(.5f, 0);
            result.anchoredPosition = new Vector2(x, y);
            result.sizeDelta = new Vector2(width, height);
        }
        RectTransform Panel(Transform parent, string name, float x, float y, float width, float height, Color color)
        {
            var result = Rect(parent, name, x, y, width, height);
            var image = result.gameObject.AddComponent<Image>();
            image.color = color;
            image.raycastTarget = false;
            return result;
        }
        RectTransform Stripe(Transform parent, string name, float x, float y, float width, float height, Color color)
        { return Panel(parent, name, x, y, width, height, color); }
        void Paper(RectTransform parent, float width, float height)
        {
            Panel(parent, "Offset paper shadow", 8, 9, width, height, Shadow);
            Panel(parent, "Warm paper", 0, 0, width, height, Cream);
            for (int i = 1; i < (int)(width / 20); i++)
            {
                var tooth = Panel(parent, "Receipt edge", i * 20 - 3, height - 1, 7, 7, Cream);
                tooth.localRotation = Quaternion.Euler(0, 0, 45);
            }
        }
        void Dashes(Transform parent, float x, float y, float width, Color color)
        {
            int count = (int)(width / 14);
            for (int i = 0; i < count; i++) Stripe(parent, "Perforation", x + i * 14, y, 7, 1, color);
        }
        Text Label(Transform parent, string name, string value, float x, float y, float width, float height, int size, Color color,
            FontStyle style = FontStyle.Normal, TextAnchor alignment = TextAnchor.UpperLeft)
        {
            var rect = Rect(parent, name, x, y, width, height);
            var label = rect.gameObject.AddComponent<Text>();
            label.font = font;
            label.text = value;
            label.fontSize = size;
            label.fontStyle = style;
            label.color = color;
            label.alignment = alignment;
            label.horizontalOverflow = HorizontalWrapMode.Wrap;
            label.verticalOverflow = VerticalWrapMode.Truncate;
            label.supportRichText = false;
            label.raycastTarget = false;
            label.lineSpacing = 1.08f;
            return label;
        }
        void ShadowText(Text label)
        {
            var shadow = label.gameObject.AddComponent<UnityEngine.UI.Shadow>();
            shadow.effectColor = new Color(0, 0, 0, .8f);
            shadow.effectDistance = new Vector2(0, -2);
        }
        Button ButtonAt(Transform parent, string name, string label, float x, float y, float width, float height,
            Color background, Color foreground, UnityEngine.Events.UnityAction action, int fontSize)
        {
            var rect = Panel(parent, name, x, y, width, height, background);
            var image = rect.GetComponent<Image>();
            image.raycastTarget = true;
            var button = rect.gameObject.AddComponent<Button>();
            button.targetGraphic = image;
            var colors = button.colors;
            colors.normalColor = Color.white;
            colors.highlightedColor = new Color(1.14f, 1.14f, 1.08f);
            colors.pressedColor = new Color(.76f, .79f, .70f);
            colors.selectedColor = new Color(1.1f, 1.1f, 1.02f);
            colors.disabledColor = new Color(.59f, .63f, .59f, .65f);
            colors.fadeDuration = .09f;
            button.colors = colors;
            button.onClick.AddListener(action);
            var text = Label(rect, "Label", label, 16, 0, width - 32, height, fontSize, foreground, FontStyle.Bold, TextAnchor.MiddleCenter);
            text.resizeTextForBestFit = true;
            text.resizeTextMinSize = fontSize - 4;
            text.resizeTextMaxSize = fontSize;
            return button;
        }
        Image Progress(Transform parent, string name, float x, float y, float width, float height, Color fill, Color backing)
        {
            var rect = Panel(parent, name + " background", x, y, width, height, backing);
            var child = Panel(rect, name + " fill", 0, 0, width, height, fill);
            var image = child.GetComponent<Image>();
            image.sprite = whiteSprite;
            image.type = Image.Type.Filled;
            image.fillMethod = Image.FillMethod.Horizontal;
            image.fillOrigin = 0;
            image.fillAmount = 1;
            return image;
        }
        Toggle ToggleAt(Transform parent, string name, string label, float x, float y, float width, UnityEngine.Events.UnityAction<bool> action, bool initial)
        {
            var rect = Rect(parent, name, x, y, width, 43);
            var hit = rect.gameObject.AddComponent<Image>();
            hit.color = new Color(1, 1, 1, 0);
            hit.raycastTarget = true;
            var box = Panel(rect, "Checkbox", 0, 5, 30, 30, Cream).GetComponent<Image>();
            var tick = Panel(rect, "Check", 6, 11, 18, 18, Red).GetComponent<Image>();
            var toggle = rect.gameObject.AddComponent<Toggle>();
            toggle.targetGraphic = box;
            toggle.graphic = tick;
            toggle.SetIsOnWithoutNotify(initial);
            toggle.onValueChanged.AddListener(action);
            Label(rect, "Label", label, 43, 4, width - 43, 36, 21, Cream, FontStyle.Bold, TextAnchor.MiddleLeft);
            return toggle;
        }
        Slider SliderAt(Transform parent, string name, float x, float y, float width, float initial, UnityEngine.Events.UnityAction<float> action)
        {
            var rect = Rect(parent, name, x, y, width, 35);
            var hit = rect.gameObject.AddComponent<Image>();
            hit.color = new Color(1, 1, 1, 0);
            hit.raycastTarget = true;
            Panel(rect, "Track", 0, 14, width, 6, new Color(.32f, .42f, .34f));
            var fillArea = Rect(rect, "Fill area", 0, 14, width, 6);
            var fill = Panel(fillArea, "Filled track", 0, 0, width, 6, Gold);
            fill.anchorMin = Vector2.zero; fill.anchorMax = Vector2.one;
            fill.offsetMin = fill.offsetMax = Vector2.zero;
            var handleArea = Rect(rect, "Handle area", 12, 0, width - 24, 35);
            var handle = Panel(handleArea, "Handle", 0, 5, 24, 24, Cream);
            handle.pivot = new Vector2(.5f,.5f);
            handle.anchorMin = handle.anchorMax = new Vector2(0,.5f);
            handle.anchoredPosition = Vector2.zero;
            handle.sizeDelta = new Vector2(24,24);
            var slider = rect.gameObject.AddComponent<Slider>();
            slider.minValue = 0; slider.maxValue = 1; slider.wholeNumbers = false;
            slider.direction = Slider.Direction.LeftToRight;
            slider.fillRect = fill;
            slider.handleRect = handle;
            slider.targetGraphic = handle.GetComponent<Image>();
            slider.SetValueWithoutNotify(initial);
            slider.onValueChanged.AddListener(action);
            return slider;
        }
        void OnDestroy()
        {
            if (active == this) active = null;
            if (whiteSprite) Destroy(whiteSprite);
        }
    }
}
