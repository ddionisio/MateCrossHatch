Shader "Hidden/Internal-DeferredShading-CrossHatch" {
Properties {
	_LightTexture0 ("", any) = "" {}
    _LightTextureB0 ("", 2D) = "" {}
    _ShadowMapTexture ("", any) = "" {}
    _SrcBlend ("", Float) = 1
    _DstBlend ("", Float) = 1
	
	//Cross-Hatch Properties
	_CrossHatchDeferredTexture("Cross Hatch Lookup", 2D) = "" {}
    _CrossHatchDeferredLightTexture("Cross Hatch Light Lookup", 2D) = "" {}
    //_CrossHatchDeferredLightRamp("Light Ramp", 2D) = "" {}
}
SubShader {

// Pass 1: Lighting pass
//  LDR case - Lighting encoded into a subtractive ARGB8 buffer
//  HDR case - Lighting additively blended into floating point buffer
Pass {
	ZWrite Off
	Blend [_SrcBlend] [_DstBlend]

CGPROGRAM
#pragma target 3.0
#pragma vertex vert_deferred
#pragma fragment frag
#pragma multi_compile_lightpass
#pragma multi_compile ___ UNITY_HDR_ON

#pragma exclude_renderers nomrt

#include "UnityCG.cginc"
#include "UnityDeferredLibrary.cginc"
#include "UnityPBSLighting.cginc"
#include "UnityStandardUtils.cginc"
#include "UnityGBuffer.cginc"
#include "UnityStandardBRDF.cginc"

//Cross-Hatch Includes
#include "CrossHatchLibrary.cginc"

sampler2D _CameraGBufferTexture0;
sampler2D _CameraGBufferTexture1;
sampler2D _CameraGBufferTexture2;

//Cross-Hatch Variables
sampler2D _CrossHatchDeferredTexture;
sampler2D _CrossHatchDeferredLightTexture;
sampler2D _CrossHatchDeferredLightRamp;

//Cross-Hatch BRDF
half4 BRDF3_CrossHatch_PBS (UnityStandardData data, float3 wpos, float atten, half oneMinusReflectivity,
	float3 viewDir, UnityLight light, UnityIndirect gi)
{
	half3 diffColor = data.diffuseColor;
	half3 specColor = data.specularColor;
	half smoothness = data.smoothness;
    float3 normal = data.normalWorld;
	
    float3 reflDir = reflect (viewDir, normal);

    half nl = saturate(dot(normal, light.dir));
    half nv = saturate(dot(normal, viewDir));

    // Vectorize Pow4 to save instructions
    half2 rlPow4AndFresnelTerm = Pow4 (float2(dot(reflDir, light.dir), 1-nv));  // use R.L instead of N.H to save couple of instructions
    half rlPow4 = rlPow4AndFresnelTerm.x; // power exponent must match kHorizontalWarpExp in NHxRoughness() function in GeneratedTextures.cpp
    half fresnelTerm = rlPow4AndFresnelTerm.y;

    half grazingTerm = saturate(smoothness + (1-oneMinusReflectivity));
	
	//Cross-Hatch
	
	//grab texture uv weights
    float3 uvWeights = TriPlanarWeights(data.normalWorld);
	
	const float crossHatchScale = 1;
	
	//float lightColor = _LightColor.rgb * atten;
	
	half lumV = Luminance(atten * nl);
    half cross = CrossShade(_CrossHatchDeferredTexture, crossHatchScale, lumV, wpos, uvWeights);
	
	//light.color = cross;//_LightColor.rgb * cross;
	
	//

    half3 color = BRDF3_Direct(diffColor, specColor, rlPow4, smoothness);
    //color *= light.color * nl;
    //color += BRDF3_Indirect(diffColor, specColor, gi, grazingTerm, fresnelTerm);
	
	color *= _LightColor.rgb;
	color += BRDF3_Indirect(diffColor, specColor, gi, grazingTerm, fresnelTerm);
	color *= cross;

    return half4(color, 1);
}

half4 CalculateLight (unity_v2f_deferred i)
{
    float3 wpos;
    float2 uv;
    float atten, fadeDist;
    UnityLight light;
    UNITY_INITIALIZE_OUTPUT(UnityLight, light);
    UnityDeferredCalculateLightParams (i, wpos, uv, light.dir, atten, fadeDist);

    //light.color = _LightColor.rgb * atten;

    // unpack Gbuffer
    half4 gbuffer0 = tex2D (_CameraGBufferTexture0, uv);
    half4 gbuffer1 = tex2D (_CameraGBufferTexture1, uv);
    half4 gbuffer2 = tex2D (_CameraGBufferTexture2, uv);
    UnityStandardData data = UnityStandardDataFromGbuffer(gbuffer0, gbuffer1, gbuffer2);

    float3 eyeVec = normalize(wpos-_WorldSpaceCameraPos);
    half oneMinusReflectivity = 1 - SpecularStrength(data.specularColor.rgb);

    UnityIndirect ind;
    UNITY_INITIALIZE_OUTPUT(UnityIndirect, ind);
    ind.diffuse = 0;
    ind.specular = 0;

    half4 res = BRDF3_CrossHatch_PBS (data, wpos, atten, oneMinusReflectivity, -eyeVec, light, ind);

    return res;
}

#ifdef UNITY_HDR_ON
half4
#else
fixed4
#endif
frag (unity_v2f_deferred i) : SV_Target
{
    half4 c = CalculateLight(i);
    #ifdef UNITY_HDR_ON
    return c;
    #else
    return exp2(-c);
    #endif
}

ENDCG
}


// Pass 2: Final decode pass.
// Used only with HDR off, to decode the logarithmic buffer into the main RT
Pass {
    ZTest Always Cull Off ZWrite Off
    Stencil {
        ref [_StencilNonBackground]
        readmask [_StencilNonBackground]
        // Normally just comp would be sufficient, but there's a bug and only front face stencil state is set (case 583207)
        compback equal
        compfront equal
    }

CGPROGRAM
#pragma target 3.0
#pragma vertex vert
#pragma fragment frag
#pragma exclude_renderers nomrt

#include "UnityCG.cginc"

sampler2D _LightBuffer;
struct v2f {
    float4 vertex : SV_POSITION;
    float2 texcoord : TEXCOORD0;
};

v2f vert (float4 vertex : POSITION, float2 texcoord : TEXCOORD0)
{
    v2f o;
    o.vertex = UnityObjectToClipPos(vertex);
    o.texcoord = texcoord.xy;
#ifdef UNITY_SINGLE_PASS_STEREO
    o.texcoord = TransformStereoScreenSpaceTex(o.texcoord, 1.0f);
#endif
    return o;
}

fixed4 frag (v2f i) : SV_Target
{
    return -log2(tex2D(_LightBuffer, i.texcoord));
}
ENDCG
}

}
Fallback Off
}
