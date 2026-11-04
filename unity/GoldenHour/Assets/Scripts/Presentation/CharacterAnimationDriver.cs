using System;
using System.Collections.Generic;
using UnityEngine;

namespace GoldenHour
{
    /// <summary>Plays the authored baker/customer FBX clips and exposes tool/IK anchors.</summary>
    [DisallowMultipleComponent]
    public sealed class CharacterAnimationDriver : MonoBehaviour
    {
        [SerializeField] private AnimationClip[] clips = Array.Empty<AnimationClip>();
        [SerializeField] private bool isHands;
        [SerializeField, Range(0f, 1f)] private float mood = 1f;
        private Animation player;
        private readonly Dictionary<string, string> actions = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        private readonly Dictionary<string, Transform> bones = new Dictionary<string, Transform>(StringComparer.OrdinalIgnoreCase);
        private readonly Dictionary<string, Transform> grips = new Dictionary<string, Transform>();
        private float returnToIdleAt = -1f;
        private float idleBlend = .12f;
        private bool configured;

        public bool IsHands => isHands;
        public string CurrentAction { get; private set; } = "Idle";

        public void Configure(AnimationClip[] importedClips, bool hands)
        {
            clips = importedClips ?? Array.Empty<AnimationClip>();
            isHands = hands;
            configured = false;
            Initialize();
            PlayAction("Idle");
        }

        private void Awake() => Initialize();
        private void OnEnable()
        {
            if (configured && player != null && actions.Count > 0) PlayAction("Idle");
        }

        private void Initialize()
        {
            if (configured) return;
            configured = true;
            player = GetComponent<Animation>();
            if (player == null) player = gameObject.AddComponent<Animation>();
            player.playAutomatically = false;
            player.cullingType = isHands ? AnimationCullingType.AlwaysAnimate : AnimationCullingType.BasedOnRenderers;
            actions.Clear(); bones.Clear();
            foreach (Transform child in GetComponentsInChildren<Transform>(true))
                if (!bones.ContainsKey(child.name)) bones.Add(child.name, child);
            foreach (AnimationClip source in clips)
            {
                if (source == null || source.name.StartsWith("__preview__", StringComparison.Ordinal)) continue;
                // Import with ModelImporterAnimationType.Legacy. The clone keeps a
                // runtime-created scene usable if a caller supplies a generic clip.
                AnimationClip clip = source;
                if (!source.legacy)
                {
                    clip = Instantiate(source);
                    clip.name = source.name;
                    clip.legacy = true;
                }
                string action = ShortName(source.name);
                string key = "GH_" + action;
                player.AddClip(clip, key);
                AnimationState state = player[key];
                state.wrapMode = action == "Idle" || action.StartsWith("GripHold", StringComparison.OrdinalIgnoreCase) ? WrapMode.Loop : WrapMode.Once;
                actions[action] = key;
            }
            if (actions.TryGetValue("Idle", out string idle)) player.clip = player[idle].clip;
            // Derive the palm frame from bone positions. This survives FBX root
            // axis conversion instead of assuming the imported root has zero yaw.
            CreateGrip("L"); CreateGrip("R");
        }

        private static string ShortName(string name)
        {
            int marker = name.LastIndexOf("Hands_", StringComparison.Ordinal);
            if (marker >= 0) return name.Substring(marker + 6);
            marker = name.LastIndexOf("Customer_", StringComparison.Ordinal);
            if (marker >= 0) return name.Substring(marker + 9);
            int pipe = name.LastIndexOf('|');
            return pipe >= 0 ? name.Substring(pipe + 1) : name;
        }

        /// <param name="action">Idle, Reach, Grip, GripHold, Scoop, Pour, Shake,
        /// Handoff, Punch/PunchRapid, Order, Receive, Happy, Impatient, Recoil/ComicRecoil.</param>
        /// <param name="duration">Requested playback seconds; zero uses authored clip duration.</param>
        public void PlayAction(string action, float duration = 0f, float blend = .12f)
        {
            Initialize();
            if (string.IsNullOrWhiteSpace(action)) action = "Idle";
            if (action.Equals("Punch", StringComparison.OrdinalIgnoreCase)) action = "PunchRapid";
            if (action.Equals("Recoil", StringComparison.OrdinalIgnoreCase) || action.Equals("Backhop", StringComparison.OrdinalIgnoreCase)) action = "ComicRecoil";
            if (!actions.TryGetValue(action, out string key))
            {
                if (!actions.TryGetValue("Idle", out key)) return;
                action = "Idle";
            }
            AnimationState state = player[key];
            if (CurrentAction == action && state.wrapMode == WrapMode.Loop && player.IsPlaying(key)) return;
            float seconds = duration > .015f ? duration : Mathf.Max(.03f, state.length);
            state.speed = state.length / seconds;
            state.time = 0f;
            blend = Mathf.Clamp(blend, 0f, seconds * .3f);
            player.CrossFade(key, blend, PlayMode.StopSameLayer);
            CurrentAction = action;
            idleBlend = Mathf.Max(.04f, blend);
            returnToIdleAt = state.wrapMode == WrapMode.Loop ? -1f : Time.time + seconds - idleBlend;
        }

        public void SetMood(float satisfaction)
        {
            mood = Mathf.Clamp01(satisfaction);
            if (!isHands && CurrentAction == "Idle" && mood < .3f) PlayAction("Impatient");
        }

        public Transform FindBone(string exactName)
        {
            Initialize();
            return bones.TryGetValue(exactName, out Transform value) ? value : null;
        }

        /// <summary>Palm anchor, +Z forward and +Y up in the bind pose; parent a held tool here.</summary>
        public Transform Grip(string side = "R")
        {
            Initialize();
            side = side.Equals("L", StringComparison.OrdinalIgnoreCase) ? "L" : "R";
            return grips.TryGetValue(side, out Transform value) ? value : null;
        }

        private void CreateGrip(string side)
        {
            if (grips.ContainsKey(side) && grips[side] != null) return;
            Transform bone = FindBone("Grip." + side) ?? FindBone("Hand." + side);
            if (bone == null) return;
            Transform anchor = bone.Find("ToolGrip." + side);
            if (anchor == null)
            {
                anchor = new GameObject("ToolGrip." + side).transform;
                anchor.SetParent(bone, false);
                anchor.position = bone.position;
                Transform hand = FindBone("Hand." + side);
                Transform middle = FindBone("Middle.01." + side);
                if (hand != null && middle != null)
                {
                    Vector3 forward = middle.position - hand.position;
                    Vector3 up = Vector3.ProjectOnPlane(hand.position - bone.position, forward);
                    if (up.sqrMagnitude < .000001f) up = Vector3.ProjectOnPlane(transform.up, forward);
                    if (up.sqrMagnitude < .000001f) up = Vector3.ProjectOnPlane(transform.forward, forward);
                    anchor.rotation = Quaternion.LookRotation(forward.normalized, up.normalized);
                }
                else anchor.rotation = transform.rotation;
            }
            grips[side] = anchor;
        }

        private void Update()
        {
            if (returnToIdleAt >= 0f && Time.time >= returnToIdleAt)
            {
                returnToIdleAt = -1f;
                PlayAction("Idle", 0f, idleBlend);
            }
        }
    }
}
