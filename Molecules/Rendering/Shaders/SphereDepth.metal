#include <metal_stdlib>
using namespace metal;

typedef struct
{
    float4x4 modelViewProjMatrix;
    float4x4 orthographicMatrix;
    float sphereRadius;
    float3 translation;
} SphereDepthVertexUniform;

typedef struct
{
    float4x4 inverseModelViewProjMatrix;
    float ambientOcclusionTexturePatchWidth;
} SphereDepthFragmentUniform;

struct SphereDepthVertexIO
{
    float4 position [[position]];
    float2 impostorSpaceCoordinate [[user(impostorSpaceCoordinate)]];
    float normalizedDepth [[user(normalizedDepth)]];
    float adjustedSphereRadius;
};

vertex SphereDepthVertexIO sphereDepthVertex(const device packed_float3 *position [[buffer(0)]],
                                                       const device packed_float2 *inputImpostorSpaceCoordinate [[buffer(1)]],
                                                       constant SphereDepthVertexUniform& uniform [[buffer(3)]],
                                                       uint vid [[vertex_id]])
{
    SphereDepthVertexIO outputVertices;

    float4 transformedPosition = uniform.modelViewProjMatrix * (float4(position[vid], 1.0) + float4(uniform.translation, 0.0));
//    transformedPosition.z = transformedPosition.z + 10.0; // ?

    outputVertices.impostorSpaceCoordinate = inputImpostorSpaceCoordinate[vid];

    transformedPosition.xy = transformedPosition.xy + inputImpostorSpaceCoordinate[vid].xy * float2(uniform.sphereRadius);
    float4 transformedPosition2 = transformedPosition * uniform.orthographicMatrix;
    transformedPosition2.z = (transformedPosition2.z + 1.0) * 0.5;
    
    float4 depthAdjustmentPoint = float4(0.0, 0.0, 0.25, 1.0) * uniform.orthographicMatrix;
    float depthAdjustmentForOrthographicProjection = depthAdjustmentPoint.z / depthAdjustmentPoint.w;
    outputVertices.adjustedSphereRadius = uniform.sphereRadius * depthAdjustmentForOrthographicProjection;

    outputVertices.normalizedDepth = (transformedPosition2.z / 2.0) + 0.5;
    outputVertices.position = transformedPosition2;
    return outputVertices;
}

struct FragmentColorDepth {
    half4 color [[color(0)]];
    float depth [[depth(any)]];
};

constant float3 stepValues = float3(2.0, 1.0, 0.0);

fragment FragmentColorDepth sphereDepthFragment(SphereDepthVertexIO fragmentInput [[stage_in]],
                                 constant SphereDepthFragmentUniform& uniform [[ buffer(1) ]])
{
    float distanceFromCenter = length(fragmentInput.impostorSpaceCoordinate);
    distanceFromCenter = min(distanceFromCenter, 1.0);
    float normalizedSphereDepth = sqrt(1.0 - distanceFromCenter * distanceFromCenter);
    float alphaComponent = step(distanceFromCenter, 0.99);

    float currentDepthValue = fragmentInput.normalizedDepth - fragmentInput.adjustedSphereRadius * normalizedSphereDepth;

    // Inlined color encoding for the depth values
    currentDepthValue = currentDepthValue * 3.0;

    float3 intDepthValue = float3(currentDepthValue) - stepValues;

    float3 temporaryColor = float3(1.0 - alphaComponent) + float3(alphaComponent) * intDepthValue;

    FragmentColorDepth colorDepth;
    colorDepth.color = half4(half3(temporaryColor), 1.0h);
    colorDepth.depth = float(currentDepthValue + (1.0 - alphaComponent));
    return colorDepth;
}
