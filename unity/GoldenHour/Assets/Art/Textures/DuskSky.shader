Shader "GoldenHour/DuskSky"
{
    Properties
    {
        _Zenith ("Deep evening", Color) = (0.025,0.055,0.12,1)
        _Horizon ("Last light", Color) = (0.36,0.25,0.25,1)
        _Ground ("Below horizon", Color) = (0.055,0.07,0.09,1)
    }
    SubShader
    {
        Tags { "Queue"="Background" "RenderType"="Background" "PreviewType"="Skybox" }
        Cull Off ZWrite Off
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            CBUFFER_START(UnityPerMaterial)
            half4 _Zenith, _Horizon, _Ground;
            CBUFFER_END
            struct Attributes { float4 vertex:POSITION; };
            struct Varyings { float4 vertex:SV_POSITION; float3 direction:TEXCOORD0; };
            Varyings vert(Attributes i) { Varyings o; o.vertex=TransformObjectToHClip(i.vertex.xyz);o.direction=i.vertex.xyz;return o; }
            float hash(float3 p) { p=frac(p*.1031);p+=dot(p,p.yzx+33.33);return frac((p.x+p.y)*p.z); }
            half4 frag(Varyings i):SV_Target
            {
                float3 d=normalize(i.direction);
                float h=saturate(d.y);
                half3 sky=lerp(_Horizon.rgb,_Zenith.rgb,pow(h,.48));
                sky=lerp(sky,_Ground.rgb,saturate(-d.y*5));
                float sunset=pow(saturate(dot(d,normalize(float3(-.7,.055,.65)))),12)*pow(1-h,4);
                sky+=half3(.18,.075,.024)*sunset;
                float3 starCell=floor(d*550);
                float star=step(.9988,hash(starCell))*pow(saturate(1-length(frac(d*550)-.5)*2),5)*smoothstep(.16,.8,h);
                sky+=star*half3(.65,.73,.9);
                return half4(sky,1);
            }
            ENDHLSL
        }
    }
}
