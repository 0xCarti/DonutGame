using System;
using System.IO;
using System.Text.RegularExpressions;
using UnityEditor;
using UnityEngine;

namespace GoldenHour.Editor
{
    // Opt-in, read-only diagnostics. This never imports, saves, or changes an asset.
    public static class GoldenHourAssetAudit
    {
        static readonly string[] Names = { "Fryer", "Counter", "Tray", "Scoop", "Bag", "Bucket", "Shaker", "ShakerPowdered", "MiniDonut", "Extinguisher", "ServiceBell", "Canopy", "HangingSign", "PendantLamp", "SandwichBoard", "MarketStall", "ParkBench", "FerrisWheel" };
        static readonly string[] Moving = { "HeatDial", "SpeedDial", "Plunger", "Flipper", "Conveyor", "BellButton" };
        static readonly Vector3[] Pivots = { new Vector3(-.600f,.346f,-.312f), new Vector3(-.490f,.346f,-.312f), new Vector3(-.510f,.400f,.015f), new Vector3(.025f,.267f,0), new Vector3(.390f,.245f,0), new Vector3(0,.089f,0) };

        [Serializable] sealed class SourceBounds { public float[] blenderBoundsMin; public float[] blenderBoundsMax; }

        [MenuItem("Golden Hour/Diagnostics/Log Prop Axes and Bounds")]
        public static void LogAll()
        {
            foreach (var name in Names)
            {
                string path = "Assets/Art/Props/" + name + ".fbx";
                var source = AssetDatabase.LoadAssetAtPath<GameObject>(path);
                var importer = AssetImporter.GetAtPath(path) as ModelImporter;
                if (importer) Debug.Log("GH_PROP_IMPORT " + name + " globalScale=" + importer.globalScale + " fileScale=" + importer.useFileScale + " bakeAxisConversion=" + importer.bakeAxisConversion);
                if (source) Inspect(source, name + " RAW", null, false);
                Validate(AssetDatabase.LoadAssetAtPath<GameObject>("Assets/Generated/Prefabs/" + name + ".prefab"), name);
            }
        }

        // Call after SaveAsPrefabAsset, with the authored asset name, to audit the
        // corrected logical root at rest. Mesh.bounds works when isReadable=false.
        public static bool Validate(GameObject prefab, string name)
        {
            Bounds? expected = null;
            const string manifest = "Assets/Art/Props/props_manifest.json";
            if (File.Exists(manifest))
            {
                // Manifest entries are flat objects containing arrays and scalar values.
                var match = Regex.Match(File.ReadAllText(manifest), "\"" + Regex.Escape(name) + "\"\\s*:\\s*(\\{[^{}]*\\})");
                if (match.Success)
                {
                    var data = JsonUtility.FromJson<SourceBounds>(match.Groups[1].Value);
                    if (data.blenderBoundsMin != null && data.blenderBoundsMax != null)
                    {
                        var bounds = new Bounds();
                        bounds.SetMinMax(ToUnity(data.blenderBoundsMin), ToUnity(data.blenderBoundsMax));
                        expected = bounds;
                    }
                }
            }
            return Inspect(prefab, name, expected, true);
        }

        static bool Inspect(GameObject root, string label, Bounds? expected, bool checkPivots)
        {
            if (!root) { Debug.LogWarning("GH_PROP_AUDIT missing " + label); return false; }
            var inverse = root.transform.worldToLocalMatrix;
            Debug.Log("GH_PROP_ROOT " + label + " " + Trs(root.transform));
            bool any = false, conservative = false, valid = true;
            var total = new Bounds();
            foreach (var filter in root.GetComponentsInChildren<MeshFilter>(true))
            {
                if (!filter.sharedMesh) continue;
                var matrix = inverse * filter.transform.localToWorldMatrix;
                var bounds = TransformBounds(filter.sharedMesh.bounds, matrix);
                if (!any) total = bounds; else total.Encapsulate(bounds);
                any = true;
                conservative |= !AxisAligned(matrix);
                Debug.Log("GH_PROP_MESH " + label + "/" + filter.name + " mesh=" + B(filter.sharedMesh.bounds) + " logicalEnvelope=" + B(bounds) + " " + Trs(filter.transform));
            }
            string comparison = "";
            if (expected.HasValue && any)
            {
                var target = expected.Value;
                float error = Mathf.Max((total.min - target.min).magnitude, (total.max - target.max).magnitude);
                comparison = " expected=" + B(target) + " envelopeError=" + error.ToString("F6") + "m";
                // Rotated local AABBs can overestimate exact vertex bounds. Do not
                // incorrectly fail the tilted SandwichBoard on that approximation.
                if (!conservative && error > .003f) valid = false;
            }
            Debug.Log("GH_PROP_BOUNDS " + label + " " + B(total) + " conservative=" + conservative + comparison);
            var foundParts = new bool[Moving.Length];
            foreach (var transform in root.GetComponentsInChildren<Transform>(true))
            {
                int index = Array.IndexOf(Moving, transform.name);
                if (index < 0) continue;
                foundParts[index] = true;
                var local = Matrix4x4.TRS(transform.localPosition, transform.localRotation, transform.localScale);
                var logical = inverse * transform.localToWorldMatrix;
                var pivot = logical.MultiplyPoint3x4(Vector3.zero);
                float error = Vector3.Distance(pivot, Pivots[index]);
                Debug.Log("GH_PROP_PART " + label + "/" + transform.name + " logicalPivot=" + V(pivot) + " expected=" + V(Pivots[index]) + " error=" + error.ToString("F6") + "m " + Trs(transform) + " localMatrix=" + M(local) + " logicalMatrix=" + M(logical) + " worldMatrix=" + M(transform.localToWorldMatrix));
                if (checkPivots && error > .002f) valid = false;
            }
            if (checkPivots)
                for (int i = 0; i < Moving.Length; i++)
                    if (((label == "Fryer" && i < 5) || (label == "ServiceBell" && i == 5)) && !foundParts[i])
                    {
                        Debug.LogWarning("GH_PROP_AUDIT missing moving part " + label + "/" + Moving[i]);
                        valid = false;
                    }
            if (!any) valid = false;
            if (!valid && checkPivots) Debug.LogWarning("GH_PROP_AUDIT review bounds/pivots: " + label);
            return valid;
        }

        static Vector3 ToUnity(float[] xyz) { return new Vector3(xyz[0], xyz[2], xyz[1]); }
        static string V(Vector3 v) { return v.ToString("F6"); }
        static string B(Bounds b) { return "min=" + V(b.min) + " max=" + V(b.max); }
        static string Trs(Transform t) { return "localPosition=" + V(t.localPosition) + " localRotation=" + t.localRotation.ToString("F6") + " localScale=" + V(t.localScale); }
        static string M(Matrix4x4 m) { return m.ToString("F6").Replace("\r", "").Replace("\n", ";"); }
        static Bounds TransformBounds(Bounds source, Matrix4x4 matrix)
        {
            var result = new Bounds(matrix.MultiplyPoint3x4(source.center), Vector3.zero);
            for (int i = 0; i < 8; i++) result.Encapsulate(matrix.MultiplyPoint3x4(source.center + Vector3.Scale(source.extents, new Vector3((i & 1) == 0 ? -1 : 1, (i & 2) == 0 ? -1 : 1, (i & 4) == 0 ? -1 : 1))));
            return result;
        }
        static bool AxisAligned(Matrix4x4 matrix)
        {
            for (int i = 0; i < 3; i++)
            {
                Vector3 axis = matrix.GetColumn(i); axis.Normalize();
                if (Mathf.Max(Mathf.Abs(axis.x), Mathf.Abs(axis.y), Mathf.Abs(axis.z)) < .99999f) return false;
            }
            return true;
        }
    }
}
