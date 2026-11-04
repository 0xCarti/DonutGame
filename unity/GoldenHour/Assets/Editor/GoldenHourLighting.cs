using System;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering.Universal;

namespace GoldenHour.Editor
{
    /// <summary>Desktop lighting quality applied before saving/building the URP asset.</summary>
    public static class GoldenHourLighting
    {
        public static void Configure(UniversalRenderPipelineAsset pipeline)
        {
            if (pipeline == null) throw new ArgumentNullException(nameof(pipeline));

            // These setters are internal in URP 17.3. Configure their serialized
            // fields before the build so Unity retains the corresponding variants.
            var settings = new SerializedObject(pipeline);
            Require(settings, "m_SoftShadowsSupported").boolValue = true;
            Require(settings, "m_SoftShadowQuality").intValue = (int)SoftShadowQuality.High;
            Require(settings, "m_ReflectionProbeBlending").boolValue = true;
            Require(settings, "m_ReflectionProbeBoxProjection").boolValue = true;
            settings.ApplyModifiedPropertiesWithoutUndo();

            pipeline.mainLightShadowmapResolution = 2048;
            pipeline.shadowDistance = 30f;
            pipeline.shadowCascadeCount = 2;
            pipeline.cascade2Split = .2f;
            pipeline.supportsHDR = true;
            pipeline.colorGradingMode = ColorGradingMode.HighDynamicRange;
            pipeline.colorGradingLutSize = 32;
            pipeline.msaaSampleCount = 4;
            pipeline.maxAdditionalLightsCount = 8;
            QualitySettings.realtimeReflectionProbes = true;
            QualitySettings.anisotropicFiltering = AnisotropicFiltering.ForceEnable;
            EditorUtility.SetDirty(pipeline);
        }

        static SerializedProperty Require(SerializedObject settings, string name)
        {
            var property = settings.FindProperty(name);
            if (property == null)
                throw new InvalidOperationException("URP lighting property is unavailable: " + name);
            return property;
        }
    }
}
