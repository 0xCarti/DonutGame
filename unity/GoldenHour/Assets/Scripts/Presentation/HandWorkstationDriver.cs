using System;
using UnityEngine;

namespace GoldenHour
{
    /// <summary>
    /// Couples the authored hand/finger animation to independently moving tools.
    /// The supplied target is a world-space grasp pose, with +Z forward and +Y up.
    /// Updates before HandTargetIK and never changes arm segment lengths.
    /// </summary>
    [DefaultExecutionOrder(100)]
    [DisallowMultipleComponent]
    public sealed class HandWorkstationDriver : MonoBehaviour
    {
        [SerializeField] private CharacterAnimationDriver character;
        [SerializeField] private HandTargetIK armIK;
        [SerializeField, Min(.01f)] private float weightBlendSeconds = .085f;
        [SerializeField, Min(.001f)] private float targetBlendSeconds = .035f;
        [SerializeField, Range(.8f, .995f)] private float maximumReachFraction = .975f;
        [SerializeField, Range(0f, 1f)] private float toolRotationWeight = 1f;
        [SerializeField] private bool maintainGripWhileTracking = true;
        [SerializeField] private bool useRelaxedRestPose = true;
        // Relative to the logical hands wrapper, which sits .07m below the
        // upright operator frame: frame-local wrists become (+/-.22,-.50,.22).
        [SerializeField] private Vector3 rightRestWrist = new Vector3(.22f, -.43f, .22f);
        [SerializeField, Min(.01f)] private float restBlendSeconds = .16f;
        [SerializeField, Min(.01f)] private float freeActionFadeSeconds = .04f;

        private sealed class Arm
        {
            public string Side;
            public Transform Target, RejectedTarget, Proxy, Upper, Lower, Hand, Grip;
            public Vector3 WristToGripPosition;
            public Quaternion WristToGripRotation;
            public Vector3 PositionVelocity;
            public float Weight, DesiredWeight, WeightVelocity;
            public bool TargetIsGrip = true, Initialized, ProxyInitialized;
            public bool WithinReach;
        }

        private readonly Arm left = new Arm { Side = "L" };
        private readonly Arm right = new Arm { Side = "R" };
        private int characterVersion = -1;

        public bool RightTargetWithinReach => right.WithinReach;
        public bool LeftTargetWithinReach => left.WithinReach;
        public float RightWeight => right.Weight;
        public float LeftWeight => left.Weight;
        public bool RightTracking => right.Target != null && right.DesiredWeight > .25f;
        public bool LeftTracking => left.Target != null && left.DesiredWeight > .25f;
        public float RightGripError => !RightTracking ? 0f : right.Grip == null ? float.PositiveInfinity : Vector3.Distance(right.Grip.position, right.Target.position);
        public float LeftGripError => !LeftTracking ? 0f : left.Grip == null ? float.PositiveInfinity : Vector3.Distance(left.Grip.position, left.Target.position);
        /// <summary>Distance to either side of the operator centre: .22 at
        /// Central, .50 at Right. Changing width does not alter rest depth.</summary>
        public float RestWristWidth
        {
            get => Mathf.Abs(rightRestWrist.x);
            set { if (IsFinite(value)) rightRestWrist.x = Mathf.Clamp(value, .05f, .60f); }
        }

        private void Awake() => EnsureComponents();

        private void EnsureComponents()
        {
            if (character == null) character = GetComponent<CharacterAnimationDriver>();
            if (character == null) character = GetComponentInChildren<CharacterAnimationDriver>();
            if (character == null) return;
            if (armIK == null) armIK = character.GetComponent<HandTargetIK>();
            if (armIK == null) armIK = character.gameObject.AddComponent<HandTargetIK>();
            armIK.character = character;
            if (characterVersion != character.ConfigurationVersion)
            {
                characterVersion = character.ConfigurationVersion;
                left.Initialized = right.Initialized = false;
            }
            InitializeArm(left); InitializeArm(right);
        }

        private void InitializeArm(Arm arm)
        {
            if (arm.Initialized || character == null) return;
            arm.Upper = character.FindBone("UpperArm." + arm.Side);
            arm.Lower = character.FindBone("Forearm." + arm.Side);
            arm.Hand = character.FindBone("Hand." + arm.Side);
            arm.Grip = character.Grip(arm.Side);
            if (arm.Upper == null || arm.Lower == null || arm.Hand == null || arm.Grip == null) return;
            arm.WristToGripPosition = arm.Hand.InverseTransformPoint(arm.Grip.position);
            arm.WristToGripRotation = Quaternion.Inverse(arm.Hand.rotation) * arm.Grip.rotation;
            if (arm.Proxy == null)
            {
                var proxy = new GameObject("WorkstationWristTarget." + arm.Side);
                proxy.hideFlags = HideFlags.DontSave;
                arm.Proxy = proxy.transform;
                arm.Proxy.SetParent(transform, false);
            }
            arm.Proxy.SetPositionAndRotation(arm.Hand.position, arm.Hand.rotation);
            arm.Initialized = true;
        }

        /// <summary>
        /// Track a tool's grasp-point child or another independent world transform.
        /// targetIsGrip=true maps the tool grasp pose onto the palm attachment;
        /// false treats target as a raw wrist pose. Never track a target that is
        /// already parented beneath this hand rig (that creates a feedback loop).
        /// </summary>
        public void SetToolTarget(Transform target, float weight = 1f, string side = "R", bool targetIsGrip = true)
        {
            EnsureComponents();
            Arm arm = SelectArm(side);
            if (target != null && character != null && target.IsChildOf(character.transform))
            {
                if (arm.RejectedTarget != target)
                    Debug.LogWarning("HandWorkstationDriver requires an independent world-space tool target. A tool already parented to Grip follows the hand without IK.", this);
                arm.RejectedTarget = target;
                arm.Target = null;
                arm.DesiredWeight = 0f;
                return;
            }
            if (arm.Target != target)
            {
                arm.PositionVelocity = Vector3.zero;
                // Start the new reach at the current wrist so switching from scoop
                // to shaker does not teleport the hand between work surfaces.
                if (arm.Hand != null && arm.Proxy != null)
                    arm.Proxy.SetPositionAndRotation(arm.Hand.position, arm.Hand.rotation);
                arm.ProxyInitialized = arm.Hand != null;
            }
            arm.Target = target;
            arm.RejectedTarget = null;
            arm.TargetIsGrip = targetIsGrip;
            arm.DesiredWeight = target == null || !IsFinite(weight) ? 0f : Mathf.Clamp01(weight);
        }

        /// <summary>Useful for holding a paper bag with the left hand while the right works.</summary>
        public void SetBimanualTargets(Transform rightGrasp, Transform leftGrasp, float weight = 1f)
        {
            SetToolTarget(rightGrasp, weight, "R");
            SetToolTarget(leftGrasp, weight, "L");
        }

        public void ClearToolTarget(string side = "R")
        {
            Arm arm = SelectArm(side);
            arm.Target = null;
            arm.DesiredWeight = 0f;
            arm.WithinReach = false;
        }

        public void ClearAllTargets()
        {
            ClearToolTarget("L"); ClearToolTarget("R");
        }

        /// <summary>Use when starting/resetting a shift. Clears tool ownership
        /// and all damping history; the next live frame starts from the current
        /// authored wrists. Safe while paused; does not invoke SmoothDamp.</summary>
        public void ResetPoseTracking()
        {
            ResetArmTracking(left); ResetArmTracking(right);
            if (armIK != null)
            {
                armIK.leftTarget = armIK.rightTarget = null;
                armIK.leftWeight = armIK.rightWeight = 0f;
            }
        }

        private static void ResetArmTracking(Arm arm)
        {
            arm.Target = arm.RejectedTarget = null;
            arm.Weight = arm.DesiredWeight = arm.WeightVelocity = 0f;
            arm.PositionVelocity = Vector3.zero;
            arm.ProxyInitialized = false;
            arm.WithinReach = false;
            arm.TargetIsGrip = true;
        }

        public void PlayToolAction(string action, float duration = .5f, float blend = .08f)
        {
            EnsureComponents();
            if (character != null) character.PlayAction(action, duration, blend);
        }

        /// <summary>The hand-following attachment for tools that do not need world-space IK.</summary>
        public Transform Grip(string side = "R")
        {
            EnsureComponents();
            return character == null ? null : character.Grip(side);
        }

        public void SetElbowHint(Transform hint, string side = "R")
        {
            EnsureComponents();
            if (armIK == null) return;
            if (SelectArm(side) == left) armIK.leftElbowHint = hint;
            else armIK.rightElbowHint = hint;
        }

        private Arm SelectArm(string side) => string.Equals(side, "L", StringComparison.OrdinalIgnoreCase) ? left : right;

        private void LateUpdate()
        {
            EnsureComponents();
            if (armIK == null) return;
            float deltaTime = Time.deltaTime;
            // SmoothDamp's zero-step velocity calculation can produce NaN.
            // Freeze filtering and clip transitions until scaled time advances.
            if (!IsFinite(deltaTime) || deltaTime <= 0f) return;
            UpdateArm(left, deltaTime); UpdateArm(right, deltaTime);
            armIK.leftTarget = left.Proxy;
            armIK.rightTarget = right.Proxy;
            armIK.leftWeight = left.Weight;
            armIK.rightWeight = right.Weight;
            armIK.rotationWeight = toolRotationWeight;
            MaintainGrip();
        }

        private void MaintainGrip()
        {
            if (!maintainGripWhileTracking || character == null) return;
            bool useLeft = left.Target != null && left.DesiredWeight > .25f;
            bool useRight = right.Target != null && right.DesiredWeight > .25f;
            // Active world-space tool paths + IK provide arm motion. Keep the
            // corresponding physical fingers closed instead of playing an
            // authored tool clip on the opposite imported side. Free actions
            // (Punch/Handoff/Idle) remain available after their grasps clear.
            if (!useLeft && !useRight && !character.CurrentAction.StartsWith("GripHold", StringComparison.OrdinalIgnoreCase)) return;
            string action = useLeft && useRight ? "GripHoldBoth" : useLeft ? "GripHoldLeft" : useRight ? "GripHold" : "Idle";
            if (character.CurrentAction != action) character.PlayAction(action, 0f, .10f);
        }

        private void UpdateArm(Arm arm, float deltaTime)
        {
            if (!arm.Initialized) return;
            if (!IsFinite(arm.Weight)) arm.Weight = 0f;
            if (!IsFinite(arm.WeightVelocity)) arm.WeightVelocity = 0f;
            if (!IsFinite(arm.PositionVelocity)) arm.PositionVelocity = Vector3.zero;
            if (arm.Target == null) { arm.DesiredWeight = 0f; arm.WithinReach = false; }
            bool resting = arm.Target == null && AllowsRestPose();
            float desiredSolveWeight = resting ? 1f : arm.DesiredWeight;
            // Authored free actions, especially the rapid punch and handoff,
            // fade the resting IK out quickly instead of pinning the wrist.
            float weightTime = arm.Target == null && !resting ? freeActionFadeSeconds : weightBlendSeconds;
            arm.Weight = Mathf.SmoothDamp(arm.Weight, desiredSolveWeight, ref arm.WeightVelocity, weightTime, Mathf.Infinity, deltaTime);
            if (arm.Weight < .001f && desiredSolveWeight <= 0f) arm.Weight = 0f;
            if (arm.Target == null && !resting) return;

            // LateUpdate sees the current authored idle wrist rotation before
            // HandTargetIK runs. Keep that relaxed orientation and open fingers;
            // only the resting wrist location is supplied by this fallback.
            Quaternion wristRotation = resting ? arm.Hand.rotation : arm.Target.rotation;
            Vector3 wristPosition;
            if (resting)
            {
                Vector3 local = rightRestWrist;
                local.x = Mathf.Abs(local.x) * (arm.Side == "R" ? 1f : -1f);
                wristPosition = transform.TransformPoint(local);
            }
            else wristPosition = arm.Target.position;
            if (!resting && arm.TargetIsGrip)
            {
                wristRotation = arm.Target.rotation * Quaternion.Inverse(arm.WristToGripRotation);
                Vector3 scaledOffset = Vector3.Scale(arm.WristToGripPosition, arm.Hand.lossyScale);
                wristPosition -= wristRotation * scaledOffset;
            }

            if (!IsFinite(wristPosition) || !IsFinite(wristRotation) ||
                !IsFinite(arm.Upper.position) || !IsFinite(arm.Lower.position) || !IsFinite(arm.Hand.position))
            {
                InvalidateFilter(arm);
                return;
            }

            // Keep the elbow slightly bent at full reach. Both this layer and the
            // two-bone solver clamp length; neither writes a bone scale or position.
            Vector3 shoulder = arm.Upper.position;
            float upperLength = Vector3.Distance(shoulder, arm.Lower.position);
            float lowerLength = Vector3.Distance(arm.Lower.position, arm.Hand.position);
            if (!IsFinite(upperLength) || !IsFinite(lowerLength) || upperLength < .001f || lowerLength < .001f)
            {
                InvalidateFilter(arm);
                return;
            }
            float minimumReach = Mathf.Abs(upperLength - lowerLength) + .004f;
            float maximumReach = Mathf.Max(minimumReach + .005f, (upperLength + lowerLength) * maximumReachFraction);
            Vector3 shoulderToTarget = wristPosition - shoulder;
            float distance = shoulderToTarget.magnitude;
            // Resting is never reported as a tracked tool or a reachable grasp.
            arm.WithinReach = !resting && distance >= minimumReach && distance <= maximumReach + .005f;
            Vector3 direction = distance > .0001f ? shoulderToTarget / distance : character.transform.forward;
            wristPosition = shoulder + direction * Mathf.Clamp(distance, minimumReach, maximumReach);

            if (!arm.ProxyInitialized || !IsFinite(arm.Proxy.position) || !IsFinite(arm.Proxy.rotation))
            {
                arm.Proxy.SetPositionAndRotation(arm.Hand.position, arm.Hand.rotation);
                arm.ProxyInitialized = true;
            }
            float positionTime = resting ? restBlendSeconds : targetBlendSeconds;
            Vector3 smoothed = Vector3.SmoothDamp(arm.Proxy.position, wristPosition, ref arm.PositionVelocity, positionTime, Mathf.Infinity, deltaTime);
            // Camera/player motion can move the shoulder while the target filter
            // is settling, so clamp the filtered target a second time.
            Vector3 filteredOffset = smoothed - shoulder;
            if (filteredOffset.sqrMagnitude > maximumReach * maximumReach)
                smoothed = shoulder + filteredOffset.normalized * maximumReach;
            float rotationBlend = 1f - Mathf.Exp(-deltaTime / positionTime);
            Quaternion smoothedRotation = Quaternion.Slerp(arm.Proxy.rotation, wristRotation, rotationBlend);
            if (!IsFinite(smoothed) || !IsFinite(smoothedRotation) || !IsFinite(arm.Weight) ||
                !IsFinite(arm.WeightVelocity) || !IsFinite(arm.PositionVelocity))
            {
                InvalidateFilter(arm);
                return;
            }
            arm.Proxy.SetPositionAndRotation(smoothed, smoothedRotation);
        }

        private static void InvalidateFilter(Arm arm)
        {
            // Retain the active target so failed contact remains visible to the
            // acceptance checks, but never pass non-finite state into bone IK.
            arm.Weight = arm.WeightVelocity = 0f;
            arm.PositionVelocity = Vector3.zero;
            arm.ProxyInitialized = false;
            arm.WithinReach = false;
        }

        private static bool IsFinite(float value) => !float.IsNaN(value) && !float.IsInfinity(value);
        private static bool IsFinite(Vector3 value) => IsFinite(value.x) && IsFinite(value.y) && IsFinite(value.z);
        private static bool IsFinite(Quaternion value) => IsFinite(value.x) && IsFinite(value.y) && IsFinite(value.z) && IsFinite(value.w);

        private bool AllowsRestPose()
        {
            if (!useRelaxedRestPose || character == null || !character.IsHands) return false;
            string action = character.CurrentAction;
            // Only idle/holding clips receive the resting fallback. With no
            // target, Punch/PunchRapid, Handoff, Reach, and every other authored
            // action retain their arm motion while the fallback weight fades.
            return string.Equals(action, "Idle", StringComparison.OrdinalIgnoreCase) ||
                action.StartsWith("GripHold", StringComparison.OrdinalIgnoreCase);
        }

        private void OnDisable()
        {
            left.Weight = right.Weight = 0f;
            if (armIK != null) armIK.leftWeight = armIK.rightWeight = 0f;
        }

        private void OnDestroy()
        {
            if (left.Proxy != null) Destroy(left.Proxy.gameObject);
            if (right.Proxy != null) Destroy(right.Proxy.gameObject);
        }
    }
}
