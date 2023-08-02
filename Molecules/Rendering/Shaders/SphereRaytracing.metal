#include <metal_stdlib>
using namespace metal;

typedef struct
{
    float4x4 modelViewProjMatrix;
    float4x4 orthographicMatrix;
    float sphereRadius;
    float3 translation;
} SphereRaytracingVertexUniform;

typedef struct
{
    float3 sphereColor;
    float4x4 inverseModelViewProjMatrix;
    float ambientOcclusionTexturePatchWidth;
} SphereRaytracingFragmentUniform;

struct SphereRaytracingVertexIO
{
    float4 position [[position]];
    float2 impostorSpaceCoordinate [[user(impostorSpaceCoordinate)]];
    float3 normalizedViewCoordinate [[user(normalizedViewCoordinate)]];
    float2 ambientOcclusionTextureBase [[user(ambientOcclusionTextureBase)]];
    float adjustedSphereRadius;
};

vertex SphereRaytracingVertexIO sphereRaytracingVertex(const device packed_float3 *position [[buffer(0)]],
                                                       const device packed_float2 *inputImpostorSpaceCoordinate [[buffer(1)]],
                                                       const device packed_float2 *ambientOcclusionTextureOffset [[buffer(2)]],
                                                       constant SphereRaytracingVertexUniform& uniform [[buffer(3)]],
                                                       uint vid [[vertex_id]])
{
    SphereRaytracingVertexIO outputVertices;
        
    outputVertices.ambientOcclusionTextureBase = ambientOcclusionTextureOffset[vid];
    
    float4 transformedPosition = uniform.modelViewProjMatrix * (float4(position[vid], 1.0) + float4(uniform.translation, 0.0));
    outputVertices.impostorSpaceCoordinate = inputImpostorSpaceCoordinate[vid];

    transformedPosition.xy = transformedPosition.xy + inputImpostorSpaceCoordinate[vid].xy * float2(uniform.sphereRadius);
    float4 transformedPosition2 = transformedPosition * uniform.orthographicMatrix;
    transformedPosition2.z = (transformedPosition2.z + 1.0) * 0.5;
    
    float4 depthAdjustmentPoint = float4(0.0, 0.0, 0.25, 1.0) * uniform.orthographicMatrix;
    float depthAdjustmentForOrthographicProjection = depthAdjustmentPoint.z / depthAdjustmentPoint.w;
    outputVertices.adjustedSphereRadius = uniform.sphereRadius * depthAdjustmentForOrthographicProjection;

    outputVertices.normalizedViewCoordinate = (transformedPosition2.xyz / 2.0) + 0.5;
    outputVertices.position = transformedPosition2;
    return outputVertices;
}

struct FragmentColorDepth {
    half4 color [[color(0)]];
    float depth [[depth(any)]];
};

constant half3 lightPosition = half3(0.312757, 0.248372, 0.916785);


float2 ambientOcclusionLookupCoordinate(float2 impostorSpaceCoordinate,
                                        float4x4 inverseModelViewProjMatrix,
                                        float distanceFromCenter)
{
    float4 aoNormal;

    if (distanceFromCenter > 1.0)
    {
        distanceFromCenter = 1.0;
        aoNormal = float4(normalize(impostorSpaceCoordinate), 0.0, 1.0);
    }
    else
    {
        float precalculatedDepth = sqrt(1.0 - distanceFromCenter * distanceFromCenter);
        aoNormal = float4(impostorSpaceCoordinate, -precalculatedDepth, 1.0);
    }

    // Ambient occlusion factor
    aoNormal = inverseModelViewProjMatrix * aoNormal;
    aoNormal.z = -aoNormal.z;

    float4 absoluteSphereSurfacePosition = abs(aoNormal);
    float d = absoluteSphereSurfacePosition.x + absoluteSphereSurfacePosition.y + absoluteSphereSurfacePosition.z;

    float2 lookupTextureCoordinate;
    if (aoNormal.z <= 0.0)
    {
        lookupTextureCoordinate = aoNormal.xy / d;
    }
    else
    {
        float2 theSign = aoNormal.xy / absoluteSphereSurfacePosition.xy;
        lookupTextureCoordinate = theSign - absoluteSphereSurfacePosition.yx * (theSign / d);
    }

    // Using a slight inset here to avoid seam artifacts, should examine this further to fix.
    return lookupTextureCoordinate / 2.1;
}

fragment FragmentColorDepth sphereRaytracingFragment(SphereRaytracingVertexIO fragmentInput [[stage_in]],
                                 texture2d<half> ambientOcclusionTexture [[texture(0)]],
                                 constant SphereRaytracingFragmentUniform& uniform [[ buffer(1) ]])
{
    half distanceFromCenter = length(fragmentInput.impostorSpaceCoordinate);
    distanceFromCenter = min(distanceFromCenter, 1.0h);
    half normalizedDepth = sqrt(1.0 - distanceFromCenter * distanceFromCenter);
    half alphaComponent = step(distanceFromCenter, 0.99h);
    
    half currentDepthValue = fragmentInput.normalizedViewCoordinate.z - fragmentInput.adjustedSphereRadius * normalizedDepth;

    // Ambient occlusion sampling
    float2 lookupTextureCoordinate = ambientOcclusionLookupCoordinate(fragmentInput.impostorSpaceCoordinate,
                                                                      uniform.inverseModelViewProjMatrix,
                                                                      distanceFromCenter);

    float2 textureCoordinateForAOLookup = fragmentInput.ambientOcclusionTextureBase + uniform.ambientOcclusionTexturePatchWidth * lookupTextureCoordinate;
    textureCoordinateForAOLookup.y = 1.0 - textureCoordinateForAOLookup.y;
    constexpr sampler ambientOcclusionSampler(mag_filter::linear,
                                              min_filter::linear);
    half ambientOcclusionIntensity = ambientOcclusionTexture.sample(ambientOcclusionSampler, textureCoordinateForAOLookup).x;

    // Ambient lighting
    half3 normal = half3(fragmentInput.impostorSpaceCoordinate.x, fragmentInput.impostorSpaceCoordinate.y, normalizedDepth);
    half ambientLightingIntensityFactor = clamp(dot(lightPosition, normal), 0.0h, 1.0h);
    
    half lightingIntensity = 0.1 + ambientLightingIntensityFactor * ambientOcclusionIntensity;
    half3 finalSphereColor = half3(uniform.sphereColor) * lightingIntensity;
    
    // Specular lighting
    half specularLightingIntensityFactor = pow(ambientLightingIntensityFactor, 60.0h) * 0.6h;
    finalSphereColor = finalSphereColor + ((specularLightingIntensityFactor * ambientOcclusionIntensity) * (half3(1.0h) - finalSphereColor));

    FragmentColorDepth colorDepth;
    colorDepth.color = half4(finalSphereColor * alphaComponent, 1.0);
    colorDepth.depth = float(currentDepthValue + (1.0 - alphaComponent));
    return colorDepth;
}
