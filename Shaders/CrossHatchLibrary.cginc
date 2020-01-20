
#ifndef CROSSHATCH_LIBRARY_INCLUDED
#define CROSSHATCH_LIBRARY_INCLUDED

float3 TriPlanarWeights(float3 normal) {
    const float _TriplanarSharpness = 1;

    float3 weights = pow(abs(normal), _TriplanarSharpness);
    weights /= (weights.x + weights.y + weights.z);

    return weights;
}

half4 Tex2DTriPlanar(sampler2D tex, float3 position, float3 weights, float scale) {
    half4 xTex = tex2D(tex, position.yz*scale);
    half4 yTex = tex2D(tex, position.xz*scale);
    half4 zTex = tex2D(tex, position.xy*scale);

    return xTex*weights.x + yTex*weights.y + zTex*weights.z;
}

half CrossShade(sampler2D crossHatchDeferredTexture, float crossHatchScale, half shade, float3 position, half3 texWeights) {
    //grab hatch info
    half4 hatch = Tex2DTriPlanar(crossHatchDeferredTexture, position, texWeights, crossHatchScale);

    //compute weights
    half4 shadingFactor = half4(shade.xxxx);
    const half4 leftRoot = half4(-0.25, 0.0, 0.25, 0.5);
    const half4 rightRoot = half4(0.25, 0.5, 0.75, 1.0);

    half4 weights = 4.0 * max(0, min(rightRoot - shadingFactor, shadingFactor - leftRoot));

    //final shade

    return dot(weights, hatch.abgr) + 4.0*clamp(shade - 0.75, 0, 0.25);
}

half3 Posterize(half3 color) {
    const float _CrossHatchPosterizeGamma = 0.6;
    const float _CrossHatchPosterizeColors = 6; 

    half3 ret = pow(color, _CrossHatchPosterizeGamma);
    ret = floor(ret*_CrossHatchPosterizeColors) / _CrossHatchPosterizeColors;
   
    return pow(ret, 1.0/_CrossHatchPosterizeGamma);
}

#endif // CROSSHATCH_LIBRARY_INCLUDED