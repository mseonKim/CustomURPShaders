
#ifndef URP_UNLIT_FORWARD_PASS_INCLUDED
#define URP_UNLIT_FORWARD_PASS_INCLUDED


#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#if defined(LOD_FADE_CROSSFADE)
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/LODCrossFade.hlsl"
#endif

// TODO: Replace this with a keyword
half _SimpleLitMode;
half _UseEnvColor;


struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 uv : TEXCOORD0;
    float2 staticLightmapUV   : TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv : TEXCOORD0;
    float3 positionWS : TEXCOORD1;
    half3 normalWS : TEXCOORD2;
    float4 positionCS : SV_POSITION;
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 4);

    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

void InitializeInputData(Varyings input, out InputData inputData)
{
    inputData = (InputData)0;

    inputData.positionWS = input.positionWS;
    inputData.normalWS = normalize(input.normalWS);
    inputData.viewDirectionWS = SafeNormalize(GetWorldSpaceNormalizeViewDir(input.positionWS));
    inputData.shadowCoord = 0;
    inputData.fogCoord = 0;
    inputData.vertexLighting = half3(0, 0, 0);
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);;
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = half4(1, 1, 1, 1);
}

Varyings CustomPassVertex(Attributes input)
{
    Varyings output = (Varyings)0;

    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);

    output.positionWS.xyz = vertexInput.positionWS;
    output.positionCS = vertexInput.positionCS;
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);

    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
    OUTPUT_SH(output.normalWS, output.vertexSH);

    return output;
}

void CustomPassFragment(Varyings input , out half4 outColor : SV_Target0)
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    half2 uv = input.uv;
    
    InputData inputData;
    InitializeInputData(input, inputData);
    SETUP_DEBUG_TEXTURE_DATA(inputData, input.uv, _BaseMap);

    SurfaceData surfaceData;
    InitializeCustomLitSurfaceData(uv, surfaceData);

    BRDFData brdfData;
    InitializeBRDFData(surfaceData, brdfData);


    Light mainLight = GetMainLight();
    half3 normal = inputData.normalWS;

    half4 finalColor = half4(0, 0, 0, surfaceData.alpha);
    half3 blinnPhongColor = 0;
    half3 fragPBRColor = 0;
    AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);

// TODO: Create custom GUI for keywords
// #if defined(_SIMPLE_LIT_MODE)

/* A. Apply BRDF step by step
    //////////////////////////////////////////////////////////
    //                      Blinn Phong                     //
    //////////////////////////////////////////////////////////
    // Diffuse Term
    half3 diffuse = LightingLambert(mainLight.color, mainLight.direction, normal) * surfaceData.albedo;
    // Specular Term
    half3 viewDirWS = inputData.viewDirectionWS;
    half smoothness = exp2(10 * surfaceData.smoothness + 1); // if _Smoothness == 0.5 then smoothness is 64 => pow(NdotH, 64) in LightingSpecular()
    half3 specular = LightingSpecular(mainLight.color, mainLight.direction, normal, viewDirWS, half4(surfaceData.specular, 1), smoothness);
    // GI
    half3 giColor = inputData.bakedGI;
    MixRealtimeAndBakedGI(mainLight, inputData.normalWS, giColor, aoFactor);
    giColor *= surfaceData.albedo;

    blinnPhongColor = diffuse + specular + giColor;
*/

// #else
/** B. Step by step application of light resources */

    ///////////////////////////////////////////////////////////////////
    //                      UniversalFragmentPBR                     //
    ///////////////////////////////////////////////////////////////////
    LightingData lightingData = CreateLightingData(inputData, surfaceData);

    /* 1. Main Light (Directional Light) */
    // Diffuse = Lambert, Specular = Minimalist CookTorrance
    lightingData.mainLightColor = LightingPhysicallyBased(brdfData, mainLight, normal, inputData.viewDirectionWS);

    /* 2. Environment Light (Color or CubeMap) */
    // i. Color
    half3 envColor = _GlossyEnvironmentColor.rgb * aoFactor.indirectAmbientOcclusion;

    // ii. CubeMap
    half3 irradiance = half3(0.0h, 0.0h, 0.0h);
    half3 reflectVector = reflect(-inputData.viewDirectionWS, normal);
    half mip = PerceptualRoughnessToMipmapLevel(brdfData.perceptualRoughness);
    half4 encodedIrradiance = half4(SAMPLE_TEXTURECUBE_LOD(_GlossyEnvironmentCubeMap, sampler_GlossyEnvironmentCubeMap, reflectVector, mip));
    irradiance = DecodeHDREnvironment(encodedIrradiance, _GlossyEnvironmentCubeMap_HDR);

    half NoV = saturate(dot(normal, inputData.viewDirectionWS));
    half fresnelTerm = Pow4(1.0 - NoV);
    half3 envCubeMapColor = EnvironmentBRDF(brdfData, inputData.bakedGI, irradiance, fresnelTerm);

    // Calculate Final Color
    fragPBRColor = lightingData.mainLightColor;
    fragPBRColor += lerp(envCubeMapColor, envColor, _UseEnvColor);

// #endif

    finalColor.rgb = lerp(fragPBRColor, blinnPhongColor, _SimpleLitMode);
    outColor = finalColor;
}

#endif
