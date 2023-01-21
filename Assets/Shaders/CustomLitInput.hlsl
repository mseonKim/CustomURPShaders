#ifndef UNIVERSAL_CUSTOMLIT_INPUT_INCLUDED
#define UNIVERSAL_CUSTOMLIT_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
half4 _BaseColor;
half4 _SpecColor;
half _Cutoff;
half _Surface;
half _Smoothness;
CBUFFER_END

#endif