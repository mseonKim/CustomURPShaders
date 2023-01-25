Shader "Custom/RadialBlur"
{
    Properties
    {
        _SampleCount("SampleCount", Float) = 32
        _Intensity("Intensity", Range(0.0, 1.0)) = 0.25
        _CenterPos("CenterPos", Vector) = (0.5, 0.5, 0, 0)
    }
    
    SubShader
    {
        Tags {"RenderType" = "Opaque"  "RenderPipeline" = "UniversalPipeline"}
        LOD 100

        Pass
        {
            Name "RadialBlur"
            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex RadialBlurVert
            #pragma fragment RadialBlurFragment

                
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            SAMPLER(sampler_BlitTexture);

            float _SampleCount;
            float _Intensity;
            float4 _CenterPos;

            Varyings RadialBlurVert(Attributes input)
            {
                Varyings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

            #if SHADER_API_GLES
                float4 pos = input.positionOS;
                float2 uv  = input.uv;
            #else
                float4 pos = GetFullScreenTriangleVertexPosition(input.vertexID);
                float2 uv  = GetFullScreenTriangleTexCoord(input.vertexID);
            #endif

                output.positionCS = pos;
                output.texcoord   = uv;
                return output;
            }

            half4 RadialBlurFragment(Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float2 uv = UnityStereoTransformScreenSpaceTex(input.texcoord);
                half3 color = SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, uv).xyz;
                half3 finalColor = color;

                float2 v = _CenterPos.xy - uv;
                half dist = length(v);
                float2 dir = normalize(v);
                float2 offset = dir * rcp(_SampleCount) * _Intensity * dist;


                for (int idx = 1; idx <= _SampleCount; ++idx)
                {
                    finalColor += SAMPLE_TEXTURE2D_X(_BlitTexture, sampler_BlitTexture, uv).xyz;
                    uv += offset;
                }
                finalColor /= _SampleCount;

                return half4(finalColor, 1);
            }


            ENDHLSL
        }
    }
}
