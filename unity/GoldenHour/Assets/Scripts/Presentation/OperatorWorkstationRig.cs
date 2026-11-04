using System;
using System.Collections;
using UnityEngine;

namespace GoldenHour
{
    /// <summary>
    /// An upright operator frame with an independently pitched camera. The owner
    /// starts/yields the movement coroutines; this component has no Update loop.
    /// Pass the logical hand wrapper, leaving its oriented FBX child and animation
    /// component intact. Carry held tools under Frame during operator travel.
    /// </summary>
    [DisallowMultipleComponent]
    public sealed class OperatorWorkstationRig : MonoBehaviour
    {
        public enum WorkPose { Overview, Central, Right, Custom }

        public static readonly Vector3 CentralPosition = new Vector3(.15f, 1.50f, -.60f);
        public static readonly Vector3 RightPosition = new Vector3(1.22f, 1.48f, -.22f);
        public static readonly Vector3 CentralLookTarget = new Vector3(.15f, 1.274471f, .115288f);
        public static readonly Vector3 RightLookTarget = new Vector3(1.22f, 1.254471f, .495288f);
        public static readonly Vector3 PackingMatLookTarget = new Vector3(.96f, 1.05f, .12f);
        public static readonly Vector3 HandsLocalOffset = new Vector3(0f, -.07f, 0f);
        public static readonly Vector3 HeldScoopLocalPosition = new Vector3(.22f, -.42f, .50f);
        public static readonly Vector3 HeldPackageLocalPosition = new Vector3(.02f, -.56f, .32f);

        [SerializeField] private bool reducedMotion;
        [SerializeField, Range(50f, 110f)] private float workFieldOfView = 90f;
        [SerializeField, Min(.1f)] private float maximumTravelSpeed = 1.4f;
        [SerializeField, Min(10f)] private float maximumLookSpeed = 100f;
        [SerializeField, Min(5f)] private float maximumFieldOfViewSpeed = 45f;
        [SerializeField, Min(.01f)] private float minimumBlendSeconds = .22f;

        private Transform frame;
        private Camera view;
        private Transform logicalHands;
        private Vector3 overviewPosition;
        private Quaternion overviewRotation;
        private float overviewFieldOfView;
        private int motionVersion;
        private bool configured;

        public Transform Frame => frame;
        public Camera View => view;
        public bool IsMoving { get; private set; }
        /// <summary>Eased 0..1 progress used by the frame, camera, and FOV blend.
        /// Pair carried-tool interpolation with this value. Cancel retains the
        /// current value; a completed move or explicit snap sets it to one.</summary>
        public float Progress { get; private set; } = 1f;
        public WorkPose CurrentPose { get; private set; } = WorkPose.Overview;
        public bool ReducedMotion { get => reducedMotion; set => reducedMotion = value; }
        public float WorkFieldOfView { get => workFieldOfView; set => workFieldOfView = Mathf.Clamp(value, 50f, 110f); }
        public Vector3 HeldScoopPosition => frame != null ? frame.TransformPoint(HeldScoopLocalPosition) : Vector3.zero;
        public Vector3 HeldPackagePosition => frame != null ? frame.TransformPoint(HeldPackageLocalPosition) : Vector3.zero;

        /// <summary>
        /// Call once after the camera and logical model wrappers are created.
        /// The incoming camera pose is retained as Overview. Hands must be the
        /// wrapper, not the FBX child whose local yaw corrects import orientation.
        /// Attach this component to an independent scene owner, not the camera.
        /// </summary>
        public void Configure(Camera camera, Transform handsWrapper, bool useReducedMotion = false)
        {
            if (camera == null) throw new ArgumentNullException(nameof(camera));
            if (transform == camera.transform || transform.IsChildOf(camera.transform) ||
                (handsWrapper != null && (transform == handsWrapper || transform.IsChildOf(handsWrapper))))
                throw new ArgumentException("OperatorWorkstationRig needs an owner outside the camera and hand hierarchies.");

            CancelMotion();
            reducedMotion = useReducedMotion;
            if (!configured)
            {
                overviewPosition = camera.transform.position;
                overviewRotation = camera.transform.rotation;
                overviewFieldOfView = camera.fieldOfView;
                frame = new GameObject("Upright operator frame").transform;
                frame.SetParent(transform, false);
                frame.SetPositionAndRotation(overviewPosition, Quaternion.identity);
                configured = true;
            }
            view = camera;
            view.transform.SetParent(frame, true);
            view.transform.localPosition = Vector3.zero;
            logicalHands = handsWrapper;
            if (logicalHands != null)
            {
                logicalHands.SetParent(frame, false);
                logicalHands.localPosition = HandsLocalOffset;
                logicalHands.localRotation = Quaternion.identity;
                // Do not change the wrapper's scale or any imported child/bone.
            }
        }

        public IEnumerator MoveToCentral(float minimumSeconds = 0f) =>
            Move(WorkPose.Central, CentralPosition, LookRotation(CentralPosition, CentralLookTarget), workFieldOfView, minimumSeconds);

        public IEnumerator MoveToRight(float minimumSeconds = 0f) =>
            Move(WorkPose.Right, RightPosition, LookRotation(RightPosition, RightLookTarget), workFieldOfView, minimumSeconds);

        public IEnumerator MoveToOverview(float minimumSeconds = 0f) =>
            Move(WorkPose.Overview, overviewPosition, overviewRotation, overviewFieldOfView, minimumSeconds);

        /// <summary>Changes view only; body yaw and position remain unchanged.</summary>
        public IEnumerator LookAtPackingMat(float minimumSeconds = 0f)
        {
            if (!configured) yield break;
            yield return Move(CurrentPose, frame.position, LookRotation(frame.position, PackingMatLookTarget), workFieldOfView, minimumSeconds);
        }

        /// <summary>Restores the current station's held-work gaze without travelling.</summary>
        public IEnumerator LookAtHeldWork(float minimumSeconds = 0f)
        {
            if (!configured) yield break;
            Vector3 target = frame.position + new Vector3(0f, -.225529f, .715288f);
            yield return Move(CurrentPose, frame.position, LookRotation(frame.position, target), workFieldOfView, minimumSeconds);
        }

        public IEnumerator MoveTo(Vector3 position, Vector3 lookTarget, float fieldOfView, float minimumSeconds = 0f) =>
            Move(WorkPose.Custom, position, LookRotation(position, lookTarget), fieldOfView, minimumSeconds);

        public void SnapToCentral() => Snap(WorkPose.Central, CentralPosition, LookRotation(CentralPosition, CentralLookTarget), workFieldOfView);
        public void SnapToRight() => Snap(WorkPose.Right, RightPosition, LookRotation(RightPosition, RightLookTarget), workFieldOfView);
        public void SnapToOverview() => Snap(WorkPose.Overview, overviewPosition, overviewRotation, overviewFieldOfView);

        /// <summary>Stops this component's active motion at its present pose.</summary>
        public void CancelMotion()
        {
            ++motionVersion;
            IsMoving = false;
        }

        private IEnumerator Move(WorkPose pose, Vector3 position, Quaternion rotation, float fieldOfView, float requestedSeconds)
        {
            if (!configured || view == null || frame == null) yield break;
            int version = ++motionVersion;
            Vector3 startPosition = frame.position;
            Quaternion startRotation = view.transform.rotation;
            float startFov = view.fieldOfView;
            fieldOfView = Mathf.Clamp(fieldOfView, 20f, 110f);
            // Quintic ease has maximum derivative 1.875. These bounds therefore
            // constrain peak speed, not merely average speed.
            float seconds = Mathf.Max(minimumBlendSeconds, requestedSeconds);
            seconds = Mathf.Max(seconds, 1.875f * Vector3.Distance(startPosition, position) / Mathf.Max(.1f, maximumTravelSpeed));
            seconds = Mathf.Max(seconds, 1.875f * Quaternion.Angle(startRotation, rotation) / Mathf.Max(10f, maximumLookSpeed));
            seconds = Mathf.Max(seconds, 1.875f * Mathf.Abs(startFov - fieldOfView) / Mathf.Max(5f, maximumFieldOfViewSpeed));
            IsMoving = true;
            Progress = 0f;
            CurrentPose = WorkPose.Custom;
            try
            {
                if (!reducedMotion)
                {
                    for (float elapsed = 0f; elapsed < seconds; elapsed += Time.deltaTime)
                    {
                        if (version != motionVersion || view == null || frame == null) yield break;
                        if (reducedMotion) break;
                        float t = Mathf.Clamp01(elapsed / seconds);
                        float f = t * t * t * (t * (t * 6f - 15f) + 10f);
                        Progress = f;
                        Apply(Vector3.Lerp(startPosition, position, f), Quaternion.Slerp(startRotation, rotation, f), Mathf.Lerp(startFov, fieldOfView, f));
                        yield return null;
                    }
                }
                if (version == motionVersion && view != null && frame != null)
                {
                    Apply(position, rotation, fieldOfView);
                    Progress = 1f;
                    CurrentPose = pose;
                }
            }
            finally
            {
                if (version == motionVersion) IsMoving = false;
            }
        }

        private void Snap(WorkPose pose, Vector3 position, Quaternion rotation, float fieldOfView)
        {
            CancelMotion();
            if (!configured || view == null || frame == null) return;
            Apply(position, rotation, Mathf.Clamp(fieldOfView, 20f, 110f));
            Progress = 1f;
            CurrentPose = pose;
        }

        private void Apply(Vector3 position, Quaternion rotation, float fieldOfView)
        {
            frame.SetPositionAndRotation(position, Quaternion.identity);
            view.transform.localPosition = Vector3.zero;
            view.transform.rotation = rotation;
            view.fieldOfView = fieldOfView;
        }

        private static Quaternion LookRotation(Vector3 position, Vector3 target)
        {
            Vector3 forward = target - position;
            return forward.sqrMagnitude < .000001f ? Quaternion.identity : Quaternion.LookRotation(forward, Vector3.up);
        }

        /// <summary>
        /// Native acceptance helper: inspect geometry after the import correction.
        /// Does not guess or mutate axes. Invoke once in Idle after Configure.
        /// </summary>
        public bool ValidateHandAxes(out string detail)
        {
            if (!configured || logicalHands == null)
            {
                detail = "Operator frame or hand wrapper is not configured.";
                return false;
            }
            var driver = logicalHands.GetComponentInChildren<CharacterAnimationDriver>(true);
            if (driver == null)
            {
                detail = "CharacterAnimationDriver must remain on the imported FBX child.";
                return false;
            }
            foreach (string side in new[] { "R", "L" })
            {
                Transform upper = driver.FindBone("UpperArm." + side);
                Transform lower = driver.FindBone("Forearm." + side);
                Transform wrist = driver.FindBone("Hand." + side);
                if (upper == null || lower == null || wrist == null)
                {
                    detail = "Missing arm bones for " + side;
                    return false;
                }
                Vector3 shoulderLocal = frame.InverseTransformPoint(upper.position);
                Vector3 wristLocal = frame.InverseTransformPoint(wrist.position);
                float sign = side == "R" ? 1f : -1f;
                float upperLength = Vector3.Distance(upper.position, lower.position);
                float lowerLength = Vector3.Distance(lower.position, wrist.position);
                if (shoulderLocal.x * sign < .10f || wristLocal.z < shoulderLocal.z + .20f ||
                    Mathf.Abs(upperLength - .343548f) > .02f || Mathf.Abs(lowerLength - .339190f) > .02f)
                {
                    detail = $"{side} axes/scale mismatch: shoulder={shoulderLocal:F4}, wrist={wristLocal:F4}, lengths={upperLength:F4}/{lowerLength:F4}. Expected R at +X, L at -X, wrists forward +Z, unit scale.";
                    return false;
                }
            }
            detail = "Hand sides, forward reach, and metre-scale arm lengths match the upright operator contract.";
            return true;
        }

        private void OnDisable() => CancelMotion();
    }
}
