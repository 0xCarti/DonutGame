using UnityEngine;

namespace GoldenHour
{
    /// <summary>Optional independent two-bone arm IK after the authored animation.
    /// Assign world-space hand and elbow targets. Weight zero preserves the clip.</summary>
    [DefaultExecutionOrder(150)]
    public sealed class HandTargetIK : MonoBehaviour
    {
        public CharacterAnimationDriver character;
        public Transform leftTarget;
        public Transform rightTarget;
        public Transform leftElbowHint;
        public Transform rightElbowHint;
        [Range(0f, 1f)] public float leftWeight;
        [Range(0f, 1f)] public float rightWeight;
        [Range(0f, 1f)] public float rotationWeight = .8f;

        private void LateUpdate()
        {
            if (character == null) character = GetComponent<CharacterAnimationDriver>();
            if (character == null) return;
            Solve("L", leftTarget, leftElbowHint, leftWeight);
            Solve("R", rightTarget, rightElbowHint, rightWeight);
        }

        private void Solve(string side, Transform target, Transform hint, float weight)
        {
            if (target == null || weight <= 0f) return;
            Transform upper = character.FindBone("UpperArm." + side);
            Transform lower = character.FindBone("Forearm." + side);
            Transform hand = character.FindBone("Hand." + side);
            if (upper == null || lower == null || hand == null) return;
            Vector3 a = upper.position;
            Vector3 b = lower.position;
            Vector3 c = hand.position;
            float l1 = Vector3.Distance(a, b), l2 = Vector3.Distance(b, c);
            if (l1 < .001f || l2 < .001f) return;
            Vector3 desired = Vector3.Lerp(c, target.position, Mathf.Clamp01(weight));
            Vector3 direction = desired - a;
            float distance = Mathf.Clamp(direction.magnitude, Mathf.Abs(l1 - l2) + .001f, l1 + l2 - .001f);
            if (direction.sqrMagnitude < .000001f) direction = c - a;
            if (direction.sqrMagnitude < .000001f) direction = transform.forward;
            direction.Normalize();
            desired = a + direction * distance;
            Vector3 bend = (hint != null ? hint.position : b) - a;
            bend = Vector3.ProjectOnPlane(bend, direction);
            if (bend.sqrMagnitude < .00001f) bend = Vector3.ProjectOnPlane(-transform.up, direction);
            if (bend.sqrMagnitude < .00001f) bend = Vector3.ProjectOnPlane(transform.right, direction);
            bend.Normalize();
            float along = (l1 * l1 + distance * distance - l2 * l2) / (2f * distance);
            float height = Mathf.Sqrt(Mathf.Max(0f, l1 * l1 - along * along));
            Vector3 elbow = a + direction * along + bend * height;
            upper.rotation = Quaternion.FromToRotation(b - a, elbow - a) * upper.rotation;
            lower.rotation = Quaternion.FromToRotation(hand.position - lower.position, desired - lower.position) * lower.rotation;
            hand.rotation = Quaternion.Slerp(hand.rotation, target.rotation, rotationWeight * weight);
        }
    }
}
