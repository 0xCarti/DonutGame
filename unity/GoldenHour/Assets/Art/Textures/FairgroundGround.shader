Shader "GoldenHour/FairgroundGround"
{
    Properties
    {
        [MainColor] _BaseColor ("Dust and compacted earth", Color) = (0.30,0.29,0.265,1)
        _StoneColor ("Neutral stone aggregate", Color) = (0.43,0.435,0.42,1)
        _StoneScale ("Aggregate cells per metre", Range(20,110)) = 58
        _MacroScale ("Dust variation per metre", Range(0.05,2)) = 0.36
        _MicroScale ("Fine grit per metre", Range(80,400)) = 205
        _Variation ("Natural colour variation", Range(0,0.6)) = 0.24
        _NormalStrength ("Aggregate surface relief", Range(0,0.5)) = 0.16
        _Smoothness ("Dry surface smoothness", Range(0,0.35)) = 0.08
    }
    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" "RenderType"="Opaque" "Queue"="Geometry" "UniversalMaterialType"="Lit" }
        LOD 250
        Cull Back
        ZWrite On

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        // All passes use the same material layout for SRP batching.
        CBUFFER_START(UnityPerMaterial)
            half4 _BaseColor;
            half4 _StoneColor;
            float _StoneScale;
            float _MacroScale;
            float _MicroScale;
            half _Variation;
            half _NormalStrength;
            half _Smoothness;
        CBUFFER_END
        ENDHLSL

        Pass
        {
            Name "GroundForward"
            Tags { "LightMode"="UniversalForwardOnly" }
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex GroundVertex
            #pragma fragment GroundFragment
            #pragma multi_compile_instancing
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct GroundAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };
            struct GroundVaryings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                half3 normalWS : TEXCOORD1;
                half4 fogAndVertexLight : TEXCOORD2;
                float4 shadowCoord : TEXCOORD3;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            // Integer mixing stays stable in negative world coordinates and avoids
            // trigonometric hashing or a repeated texture tile.
            uint GroundMix(uint value)
            {
                value ^= value >> 16;
                value *= 0x7feb352du;
                value ^= value >> 15;
                value *= 0x846ca68bu;
                return value ^ (value >> 16);
            }
            float3 GroundRandom(int2 cell)
            {
                uint seed = (uint)cell.x * 0x9e3779b9u ^ (uint)cell.y * 0x85ebca6bu;
                return float3(GroundMix(seed), GroundMix(seed ^ 0xc2b2ae35u), GroundMix(seed ^ 0x27d4eb2fu)) * (1.0 / 4294967296.0);
            }
            // Value and analytic derivatives: fine grit needs no extra noise samples.
            float3 GroundNoise(float2 p)
            {
                int2 cell = (int2)floor(p);
                float2 f = frac(p);
                float2 blend = f * f * (3.0 - 2.0 * f);
                float2 derivative = 6.0 * f * (1.0 - f);
                float a = GroundRandom(cell).x;
                float b = GroundRandom(cell + int2(1,0)).x;
                float c = GroundRandom(cell + int2(0,1)).x;
                float d = GroundRandom(cell + int2(1,1)).x;
                return float3(lerp(lerp(a,b,blend.x), lerp(c,d,blend.x), blend.y),
                    lerp(b-a,d-c,blend.y) * derivative.x,
                    lerp(c-a,d-b,blend.x) * derivative.y);
            }

            void GroundSurface(float3 positionWS, half3 geometricNormal, out half3 albedo, out half3 normalWS, out half smoothness, out half occlusion)
            {
                float2 p = GetAbsolutePositionWS(positionWS).xz;
                // Different frequencies and a rotated coordinate basis conceal the
                // low-frequency interpolation lattice without expensive fractal noise.
                float broad = GroundNoise(p * _MacroScale + float2(17.4,-9.1)).x;
                float2 rotated = float2(p.x * .8 - p.y * .6, p.x * .6 + p.y * .8);
                float drift = GroundNoise(rotated * (_MacroScale * .31) + float2(-3.8,21.2)).x;
                float2 q = (p + float2(broad-.5,drift-.5) * .12) * _StoneScale;
                float pixelWidth = max(length(ddx(q)), length(ddy(q)));
                float detail = 1.0 - smoothstep(.35,1.35,pixelWidth);
                float stone = .47;
                float stoneTone = 1.0;
                float2 slope = 0;

                // Only nine candidate stones; completely skip their evaluation once
                // aggregate is smaller than a pixel. No parallax or displacement.
                [branch] if (detail > .001)
                {
                    int2 cell = (int2)floor(q);
                    float2 within = frac(q);
                    float nearest = 8.0;
                    float2 nearestDelta = 0;
                    float3 nearestRandom = .5;
                    [unroll] for (int y = -1; y <= 1; y++)
                    {
                        [unroll] for (int x = -1; x <= 1; x++)
                        {
                            int2 offset = int2(x,y);
                            float3 random = GroundRandom(cell + offset);
                            float2 delta = (float2)offset + random.xy - within;
                            float distanceSquared = dot(delta,delta);
                            if (distanceSquared < nearest)
                            {
                                nearest = distanceSquared;
                                nearestDelta = delta;
                                nearestRandom = random;
                            }
                        }
                    }
                    float radius = lerp(.32,.49,nearestRandom.z);
                    float radial = sqrt(nearest) / radius;
                    float aa = min(.48,pixelWidth / max(radius,.1));
                    float pebble = 1.0 - smoothstep(.60-aa,1.0+aa,radial);
                    stone = lerp(.47,pebble,detail);
                    stoneTone = lerp(1.0,lerp(.76,1.18,nearestRandom.z),detail);
                    slope = -nearestDelta / radius * pebble * detail;
                }

                float microWidth = pixelWidth * _MicroScale / max(_StoneScale,1.0);
                float microDetail = 1.0 - smoothstep(.30,1.0,microWidth);
                float3 grit = float3(.5,0,0);
                [branch] if (microDetail > .001)
                    grit = GroundNoise(rotated * _MicroScale + float2(8.7,3.2));
                float2 gritSlope = float2(grit.y * .8 + grit.z * .6, -grit.y * .6 + grit.z * .8);
                slope += gritSlope * (.17 * microDetail);

                albedo = lerp(_BaseColor.rgb,_StoneColor.rgb * stoneTone,stone * .86);
                albedo *= 1.0 + _Variation * ((broad-.5) * .70 + (drift-.5) * .45);
                albedo *= 1.0 + (grit.x-.5) * (.10 * microDetail);
                float3 relief = float3(slope.x,0,slope.y);
                relief -= geometricNormal * dot(relief,geometricNormal);
                normalWS = normalize(geometricNormal + relief * _NormalStrength);
                smoothness = saturate(_Smoothness + (stone-.47) * .035);
                occlusion = lerp(.96,1.0,stone);
            }

            GroundVaryings GroundVertex(GroundAttributes input)
            {
                GroundVaryings output = (GroundVaryings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input,output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);
                VertexPositionInputs position = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = position.positionCS;
                output.positionWS = position.positionWS;
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.fogAndVertexLight = half4(ComputeFogFactor(position.positionCS.z), VertexLighting(position.positionWS,output.normalWS));
                output.shadowCoord = GetShadowCoord(position);
                return output;
            }

            half4 GroundFragment(GroundVaryings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                SurfaceData surface = (SurfaceData)0;
                InputData lighting = (InputData)0;
                GroundSurface(input.positionWS,normalize(input.normalWS),surface.albedo,lighting.normalWS,surface.smoothness,surface.occlusion);
                surface.metallic = 0;
                surface.specular = half3(.04,.04,.04);
                surface.normalTS = half3(0,0,1);
                surface.alpha = 1;
                lighting.positionWS = input.positionWS;
                lighting.positionCS = input.positionCS;
                lighting.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                #if defined(_MAIN_LIGHT_SHADOWS_SCREEN)
                    lighting.shadowCoord = input.shadowCoord;
                #else
                    // Evaluate cascades per pixel on the large ground mesh.
                    lighting.shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                #endif
                lighting.fogCoord = input.fogAndVertexLight.x;
                lighting.vertexLighting = input.fogAndVertexLight.yzw;
                lighting.bakedGI = SampleSHPixel(half3(0,0,0),lighting.normalWS);
                lighting.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
                lighting.shadowMask = half4(1,1,1,1);
                half4 color = UniversalFragmentPBR(lighting,surface);
                color.rgb = MixFog(color.rgb,lighting.fogCoord);
                color.a = 1;
                return color;
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }
            ColorMask 0
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #pragma multi_compile_instancing
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode"="DepthOnly" }
            ColorMask R
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment
            #pragma multi_compile_instancing
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }
        Pass
        {
            Name "DepthNormalsOnly"
            Tags { "LightMode"="DepthNormalsOnly" }
            HLSLPROGRAM
            #pragma target 3.5
            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment
            #pragma multi_compile_instancing
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthNormalsPass.hlsl"
            ENDHLSL
        }
    }
    Fallback "Hidden/Universal Render Pipeline/FallbackError"
}
