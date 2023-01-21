#ifndef UNIVERSAL_CUSTOMLIT_INPUT_INCLUDED
#define UNIVERSAL_CUSTOMLIT_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
half4 _BaseColor;
half4 _SpecColor;
half4 _EmissionColor;
half _Cutoff;
half _Surface;
half _Metallic;
half _Smoothness;
CBUFFER_END


inline void InitializeCustomLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
{
    half4 texColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
    half3 color = texColor.rgb * _BaseColor.rgb;
    half alpha = texColor.a * _BaseColor.a;

    outSurfaceData.alpha = AlphaDiscard(alpha, _Cutoff);
    outSurfaceData.albedo = color;
    outSurfaceData.albedo = AlphaModulate(outSurfaceData.albedo, outSurfaceData.alpha);

    half4 specGloss;
    specGloss.rgb = _SpecColor.rgb;
    specGloss.a = _Smoothness;

    outSurfaceData.specular = specGloss.rgb;
    outSurfaceData.metallic = _Metallic;

    outSurfaceData.smoothness = exp2(10 * specGloss.a + 1);   // if _Smoothness == 0.5 then smoothness is 64 => pow(NdotH, 64) in LightingSpecular()
    outSurfaceData.emission = _EmissionColor.rgb;

    // Fill dummy values
    outSurfaceData.normalTS = 0;
    outSurfaceData.occlusion = 1;
    outSurfaceData.clearCoatMask = 0;
    outSurfaceData.clearCoatSmoothness = 0;
}

#endif