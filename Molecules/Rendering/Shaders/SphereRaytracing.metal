#include <metal_stdlib>
using namespace metal;

typedef struct
{
    float3x3 modelViewProjMatrix;
    float4x4 orthographicMatrix;
    float sphereRadius;
    float3 translation;
} SphereRaytracingVertexUniform;

typedef struct
{
    float3 sphereColor;
    float3x3 inverseModelViewProjMatrix;
    // TODO: Ambient occlusion texture and parameters.
} SphereRaytracingFragmentUniform;

struct SphereRaytracingVertexIO
{
    float4 position [[position]];
    float2 impostorSpaceCoordinate [[user(impostorSpaceCoordinate)]];
    float3 normalizedViewCoordinate [[user(normalizedViewCoordinate)]];
    float adjustedSphereRadius;
};

vertex SphereRaytracingVertexIO sphereRaytracingVertex(const device packed_float3 *position [[buffer(0)]],
                                                       const device packed_float2 *inputImpostorSpaceCoordinate [[buffer(1)]],
                                                       //const device packed_float2 *ambientOcclusionTextureOffset [[buffer(2)]],
                                                       constant SphereRaytracingVertexUniform& uniform [[buffer(3)]],
                                                       uint vid [[vertex_id]])
{
    SphereRaytracingVertexIO outputVertices;
        
//    ambientOcclusionTextureBase = ambientOcclusionTextureOffset;
    
    float3 transformedPosition = uniform.modelViewProjMatrix * (float3(position[vid]) + uniform.translation);
    outputVertices.impostorSpaceCoordinate = inputImpostorSpaceCoordinate[vid];

    transformedPosition.xy = transformedPosition.xy + inputImpostorSpaceCoordinate[vid].xy * float2(uniform.sphereRadius);
    float4 transformedPosition2 = float4(transformedPosition, 1.0) * uniform.orthographicMatrix;
    
    float4 depthAdjustmentPoint = float4(0.0, 0.0, 0.5, 1.0) * uniform.orthographicMatrix;
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

fragment FragmentColorDepth sphereRaytracingFragment(SphereRaytracingVertexIO fragmentInput [[stage_in]],
//                                 texture2d<half> ambientOcclusionTexture [[texture(0)]],
//                                 texture2d<half> precalculatedAOLookupTexture [[texture(1)]],
                                 constant SphereRaytracingFragmentUniform& uniform [[ buffer(1) ]])
{
    half distanceFromCenter = length(fragmentInput.impostorSpaceCoordinate);
    distanceFromCenter = min(distanceFromCenter, 1.0h);
    half normalizedDepth = sqrt(1.0 - distanceFromCenter * distanceFromCenter);
    half alphaComponent = step(distanceFromCenter, 0.99h);
    
    half currentDepthValue = fragmentInput.normalizedViewCoordinate.z - fragmentInput.adjustedSphereRadius * normalizedDepth;

//    half2 lookupTextureCoordinate = ambientOcclusionLookupCoordinate(distanceFromCenter);
//
//    lookupTextureCoordinate = (lookupTextureCoordinate * 2.0h) - 1.0h;
//
//    half2 textureCoordinateForAOLookup = ambientOcclusionTextureBase + ambientOcclusionTexturePatchWidth * lookupTextureCoordinate;
//    half ambientOcclusionIntensity = texture2D(ambientOcclusionTexture, textureCoordinateForAOLookup).r;
    half ambientOcclusionIntensity = 1.0h;
    
    // Ambient lighting
    half3 normal = half3(fragmentInput.impostorSpaceCoordinate.x, fragmentInput.impostorSpaceCoordinate.y, normalizedDepth);
    half ambientLightingIntensityFactor = clamp(dot(lightPosition, normal), 0.0h, 1.0h);
    
    half lightingIntensity = 0.1 + ambientLightingIntensityFactor * ambientOcclusionIntensity;
    half3 finalSphereColor = half3(uniform.sphereColor) * lightingIntensity;
    
    // Specular lighting
    half specularLightingIntensityFactor = pow(ambientLightingIntensityFactor, 60.0h) * 0.6h;
    finalSphereColor = finalSphereColor + ((specularLightingIntensityFactor * ambientOcclusionIntensity)  * (half3(1.0h) - finalSphereColor));

    FragmentColorDepth colorDepth;
    colorDepth.color = half4(finalSphereColor * alphaComponent, 1.0);
    colorDepth.depth = float(currentDepthValue + (1.0 - alphaComponent));
    return colorDepth;
}
