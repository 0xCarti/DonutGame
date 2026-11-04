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

        public bool RightTargetWithinReach => right.WithinReach;
        public bool LeftTargetWithinReach => left.WithinReach;
        public float RightWeight => right.Weight;
        public float LeftWeight => left.Weight;

        private void Awake() => EnsureComponents();

        private void EnsureComponents()
        {
            if (character == null) character = GetComponent<CharacterAnimationDriver>();
            if (character == null) character = GetComponentInChildren<CharacterAnimationDriver>();
            if (character == null) return;
            if (armIK == null) armIK = character.GetComponent<HandTargetIK>();
            if (armIK == null) armIK = character.gameObject.AddComponent<HandTargetIK>();
            armIK.character = character;
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
            var proxy = new GameObject("WorkstationWristTarget." + arm.Side);
            proxy.hideFlags = HideFlags.DontSave;
            arm.Proxy = proxy.transform;
            arm.Proxy.SetParent(transform, false);
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
            arm.DesiredWeight = target == null ? 0f : Mathf.Clamp01(weight);
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
            UpdateArm(left); UpdateArm(right);
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
            bool idle = character.CurrentAction == "Idle";
            bool holding = character.CurrentAction.StartsWith("GripHold", StringComparison.OrdinalIgnoreCase);
            if (!idle && !holding) return;
            bool useLeft = left.Target != null && left.DesiredWeight > .25f;
            bool useRight = right.Target != null && right.DesiredWeight > .25f;
            string action = useLeft && useRight ? "GripHoldBoth" : useLeft ? "GripHoldLeft" : useRight ? "GripHold" : "Idle";
            if (character.CurrentAction != action) character.PlayAction(action, 0f, .10f);
        }

        private void UpdateArm(Arm arm)
        {
            if (!arm.Initialized) return;
            if (arm.Target == null) { arm.DesiredWeight = 0f; arm.WithinReach = false; }
            arm.Weight = Mathf.SmoothDamp(arm.Weight, arm.DesiredWeight, ref arm.WeightVelocity, weightBlendSeconds);
            if (arm.Weight < .001f && arm.DesiredWeight <= 0f) arm.Weight = 0f;
            if (arm.Target == null) return;

            Quaternion wristRotation = arm.Target.rotation;
            Vector3 wristPosition = arm.Target.position;
            if (arm.TargetIsGrip)
            {
                wristRotation = arm.Target.rotation * Quaternion.Inverse(arm.WristToGripRotation);
                Vector3 scaledOffset = Vector3.Scale(arm.WristToGripPosition, arm.Hand.lossyScale);
                wristPosition -= wristRotation * scaledOffset;
            }

            // Keep the elbow slightly bent at full reach. Both this layer and the
            // two-bone solver clamp length; neither writes a bone scale or position.
            Vector3 shoulder = arm.Upper.position;
            float upperLength = Vector3.Distance(shoulder, arm.Lower.position);
            float lowerLength = Vector3.Distance(arm.Lower.position, arm.Hand.position);
            float minimumReach = Mathf.Abs(upperLength - lowerLength) + .004f;
            float maximumReach = Mathf.Max(minimumReach + .005f, (upperLength + lowerLength) * maximumReachFraction);
            Vector3 shoulderToTarget = wristPosition - shoulder;
            float distance = shoulderToTarget.magnitude;
            arm.WithinReach = distance >= minimumReach && distance <= maximumReach + .005f;
            Vector3 direction = distance > .0001f ? shoulderToTarget / distance : character.transform.forward;
            wristPosition = shoulder + direction * Mathf.Clamp(distance, minimumReach, maximumReach);

            if (!arm.ProxyInitialized)
            {
                arm.Proxy.SetPositionAndRotation(arm.Hand.position, arm.Hand.rotation);
                arm.ProxyInitialized = true;
            }
            Vector3 smoothed = Vector3.SmoothDamp(arm.Proxy.position, wristPosition, ref arm.PositionVelocity, targetBlendSeconds);
            // Camera/player motion can move the shoulder while the target filter
            // is settling, so clamp the filtered target a second time.
            Vector3 filteredOffset = smoothed - shoulder;
            if (filteredOffset.sqrMagnitude > maximumReach * maximumReach)
                smoothed = shoulder + filteredOffset.normalized * maximumReach;
            float rotationBlend = 1f - Mathf.Exp(-Time.deltaTime / targetBlendSeconds);
            arm.Proxy.SetPositionAndRotation(smoothed, Quaternion.Slerp(arm.Proxy.rotation, wristRotation, rotationBlend));
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
