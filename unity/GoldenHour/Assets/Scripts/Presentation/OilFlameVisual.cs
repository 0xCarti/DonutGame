using System;
using UnityEngine;
using UnityEngine.Rendering;

namespace GoldenHour.Presentation
{
    /// <summary>Short, overlapping oil flames with a fixed base and no rising billboard emission.</summary>
    [DisallowMultipleComponent]
    public sealed class OilFlameVisual : MonoBehaviour
    {
        sealed class FlameCard
        {
            public Transform Transform;
            public MeshRenderer Renderer;
            public Vector3 Anchor;
            public float Width, Height, Phase, Speed, Opacity;
        }

        static readonly int BaseColor = Shader.PropertyToID("_BaseColor");
        static readonly int BaseMap = Shader.PropertyToID("_BaseMap");
        const float FadeInSeconds = .14f;
        const float FadeOutSeconds = .22f;

        Camera viewCamera;
        Transform pan;
        GameObject cardsRoot;
        Material ownedMaterial;
        Mesh forwardMesh, mirroredMesh;
        MaterialPropertyBlock properties;
        FlameCard[] cards;
        float animationTime;

        public bool IsBurning { get; private set; }
        public float Intensity { get; private set; }

        /// <param name="transparentMaterial">Saved transparent unlit/particle material; this component owns a clone.</param>
        /// <param name="localOilBounds">Oil footprint in pan-local coordinates; its maximum Y is the flame base.</param>
        /// <param name="flameTexture">Optional texture override, normally StandAssets.flame.</param>
        public void Initialize(Camera camera, Material transparentMaterial, Transform panTransform,
            Bounds localOilBounds, Texture flameTexture = null)
        {
            if (!camera) throw new ArgumentNullException(nameof(camera));
            if (!transparentMaterial) throw new ArgumentNullException(nameof(transparentMaterial));
            if (!panTransform) throw new ArgumentNullException(nameof(panTransform));
            if (localOilBounds.size.x <= 0 || localOilBounds.size.z <= 0)
                throw new ArgumentException("Oil bounds need a positive width and depth.", nameof(localOilBounds));

            ReleaseResources();
            viewCamera = camera;
            pan = panTransform;
            IsBurning = false;
            Intensity = 0;
            animationTime = 0;
            properties = new MaterialPropertyBlock();
            ownedMaterial = new Material(transparentMaterial) { name = "Anchored oil flame material" };
            // Use the transparent variant already retained by the saved source material.
            // Double-sided cards also remain visible while looking around the workstation.
            ownedMaterial.SetFloat("_Cull", (float)CullMode.Off);
            ownedMaterial.SetColor(BaseColor, Color.white);
            if (flameTexture) ownedMaterial.SetTexture(BaseMap, flameTexture);

            forwardMesh = MakeCardMesh(false);
            mirroredMesh = MakeCardMesh(true);
            cardsRoot = new GameObject("Flames on the oil surface");
            cardsRoot.transform.SetParent(pan, false);
            int columns = Mathf.Clamp(Mathf.CeilToInt(localOilBounds.size.x / .16f), 4, 8);
            const int rows = 2;
            cards = new FlameCard[columns * rows];
            var random = new System.Random(6173);
            float cellWidth = localOilBounds.size.x / columns;
            float cardWidth = Mathf.Min(.24f, cellWidth * 1.6f);
            float halfSpan = Mathf.Max(0, (localOilBounds.size.x - cardWidth * 1.13f) * .5f);
            for (int row = 0; row < rows; row++)
            {
                for (int column = 0; column < columns; column++)
                {
                    int index = row * columns + column;
                    float variation = (float)random.NextDouble();
                    var child = new GameObject("Oil flame " + index, typeof(MeshFilter), typeof(MeshRenderer));
                    child.transform.SetParent(cardsRoot.transform, false);
                    child.GetComponent<MeshFilter>().sharedMesh = index % 2 == 0 ? forwardMesh : mirroredMesh;
                    var renderer = child.GetComponent<MeshRenderer>();
                    renderer.sharedMaterial = ownedMaterial;
                    renderer.shadowCastingMode = ShadowCastingMode.Off;
                    renderer.receiveShadows = false;
                    renderer.lightProbeUsage = LightProbeUsage.Off;
                    renderer.reflectionProbeUsage = ReflectionProbeUsage.Off;
                    renderer.motionVectorGenerationMode = MotionVectorGenerationMode.ForceNoMotion;
                    float x = Mathf.Lerp(-halfSpan, halfSpan, column / (float)(columns - 1));
                    if (column > 0 && column < columns - 1) x += (variation - .5f) * cellWidth * .25f;
                    float z = (row == 0 ? -.22f : .22f) * localOilBounds.size.z;
                    z += ((float)random.NextDouble() - .5f) * localOilBounds.size.z * .08f;
                    var anchor = new Vector3(localOilBounds.center.x + x, localOilBounds.max.y + .002f,
                        localOilBounds.center.z + z);
                    cards[index] = new FlameCard
                    {
                        Transform = child.transform,
                        Renderer = renderer,
                        Anchor = anchor,
                        Width = cardWidth * Mathf.Lerp(.84f, 1f, variation),
                        Height = Mathf.Lerp(.18f, .36f, (float)random.NextDouble()) * (row == 0 ? 1f : .83f),
                        Phase = (float)random.NextDouble() * Mathf.PI * 2f,
                        Speed = Mathf.Lerp(3.2f, 5.1f, (float)random.NextDouble()),
                        Opacity = Mathf.Lerp(.57f, .76f, (float)random.NextDouble())
                    };
                    child.transform.localPosition = anchor;
                }
            }
            cardsRoot.SetActive(false);
        }

        /// <summary>Use immediate=true when resetting a shift; ordinary extinguishing fades from the surface.</summary>
        public void SetBurning(bool burning, bool immediate = false)
        {
            IsBurning = burning;
            if (immediate) Intensity = burning ? 1f : 0f;
            if (cardsRoot && (burning || immediate)) cardsRoot.SetActive(burning || Intensity > 0);
        }

        void LateUpdate()
        {
            if (cards == null || !cardsRoot || !pan || !viewCamera) return;
            float delta = Time.deltaTime;
            Intensity = Mathf.MoveTowards(Intensity, IsBurning ? 1f : 0f,
                delta / (IsBurning ? FadeInSeconds : FadeOutSeconds));
            if (Intensity <= 0)
            {
                if (cardsRoot.activeSelf) cardsRoot.SetActive(false);
                return;
            }
            if (!cardsRoot.activeSelf) cardsRoot.SetActive(true);
            animationTime += delta;
            Vector3 up = pan.up;
            foreach (var card in cards)
            {
                // Every bottom edge remains on the oil plane. Only yaw, height and
                // width change; there is no vertical translation or tilted billboard.
                Vector3 worldAnchor = pan.TransformPoint(card.Anchor);
                Vector3 facing = Vector3.ProjectOnPlane(viewCamera.transform.position - worldAnchor, up);
                if (facing.sqrMagnitude < .0001f) facing = Vector3.ProjectOnPlane(-viewCamera.transform.forward, up);
                if (facing.sqrMagnitude < .0001f) facing = pan.forward;
                float phase = animationTime * card.Speed + card.Phase;
                float slow = Mathf.Sin(phase);
                float quick = Mathf.Sin(phase * 2.37f + card.Phase);
                card.Transform.localPosition = card.Anchor;
                card.Transform.rotation = Quaternion.LookRotation(facing.normalized, up)
                    * Quaternion.Euler(0, slow * 7f, 0);
                card.Transform.localScale = new Vector3(card.Width * (1f + slow * .07f),
                    card.Height * (.88f + slow * .08f + quick * .04f) * (.25f + Intensity * .75f), 1f);
                properties.SetColor(BaseColor, new Color(1f, .97f + quick * .03f, .93f + slow * .04f,
                    card.Opacity * (.93f + quick * .07f) * Intensity));
                card.Renderer.SetPropertyBlock(properties);
            }
        }

        static Mesh MakeCardMesh(bool mirrored)
        {
            var mesh = new Mesh { name = mirrored ? "Oil flame card mirrored" : "Oil flame card" };
            // The supplied texture has faint transparent padding below its flame.
            // Cropping the UVs brings the luminous base to y=0 without editing it.
            float left = mirrored ? .875f : .125f;
            float right = mirrored ? .125f : .875f;
            mesh.vertices = new[] { new Vector3(-.5f, 0, 0), new Vector3(.5f, 0, 0),
                new Vector3(-.5f, 1, 0), new Vector3(.5f, 1, 0) };
            mesh.uv = new[] { new Vector2(left, .06f), new Vector2(right, .06f),
                new Vector2(left, .97f), new Vector2(right, .97f) };
            mesh.normals = new[] { Vector3.forward, Vector3.forward, Vector3.forward, Vector3.forward };
            // URP's particle unlit shader multiplies the texture by vertex color.
            mesh.colors = new[] { Color.white, Color.white, Color.white, Color.white };
            mesh.triangles = new[] { 0, 1, 2, 2, 1, 3 };
            mesh.RecalculateBounds();
            return mesh;
        }

        void OnDestroy() { ReleaseResources(); }

        void ReleaseResources()
        {
            if (cardsRoot) { cardsRoot.SetActive(false); Destroy(cardsRoot); }
            if (ownedMaterial) Destroy(ownedMaterial);
            if (forwardMesh) Destroy(forwardMesh);
            if (mirroredMesh) Destroy(mirroredMesh);
            cardsRoot = null;
            ownedMaterial = null;
            forwardMesh = null;
            mirroredMesh = null;
            cards = null;
        }
    }
}
