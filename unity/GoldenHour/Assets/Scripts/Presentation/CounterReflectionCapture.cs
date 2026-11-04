using System.Collections;
using UnityEngine;
using UnityEngine.Rendering;

namespace GoldenHour.Presentation
{
    /// <summary>Captures the completed runtime stand once, without per-frame cubemap rendering.</summary>
    [RequireComponent(typeof(ReflectionProbe))]
    [DisallowMultipleComponent]
    public sealed class CounterReflectionCapture : MonoBehaviour
    {
        ReflectionProbe probe;

        void Awake()
        {
            probe = GetComponent<ReflectionProbe>();
            probe.mode = ReflectionProbeMode.Realtime;
            probe.refreshMode = ReflectionProbeRefreshMode.ViaScripting;
            probe.timeSlicingMode = ReflectionProbeTimeSlicingMode.NoTimeSlicing;
            probe.resolution = 256;
            probe.hdr = true;
            probe.boxProjection = true;
            probe.clearFlags = ReflectionProbeClearFlags.Skybox;
            probe.nearClipPlane = .05f;
            probe.farClipPlane = 40f;
            probe.intensity = 1.25f;
            probe.blendDistance = 1f;
        }

        IEnumerator Start()
        {
            // WorldBuilder finishes geometry, sky and lights in the same frame.
            // Yielding frames also lets the pipeline initialize and works at timeScale 0.
            yield return null;
            yield return null;
            if (probe && probe.isActiveAndEnabled) probe.RenderProbe();
        }
    }
}
