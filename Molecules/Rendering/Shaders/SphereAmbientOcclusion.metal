#include <metal_stdlib>
using namespace metal;

constant float ambientOcclusionTextureWidth = 1024.0;

typedef struct
{
    float4x4 modelViewProjMatrix;
    float4x4 orthographicMatrix;
    float sphereRadius;
    float ambientOcclusionTexturePatchWidth;
} SphereAmbientOcclusionVertexUniform;

typedef struct
{
    float4x4 modelViewProjMatrix;
    float4x4 inverseModelViewProjMatrix;
    float intensityFactor;
} SphereAmbientOcclusionFragmentUniform;

struct SphereAmbientOcclusionVertexIO
{
    float4 position [[position]];
    float2 impostorSpaceCoordinate [[user(impostorSpaceCoordinate)]];
    float3 normalizedViewCoordinate [[user(normalizedViewCoordinate)]];
    float adjustedSphereRadius;
    float3 adjustmentForOrthographicProjection [[user(adjustmentForOrthographicProjection)]];
    float depthAdjustmentForOrthographicProjection;
};

vertex SphereAmbientOcclusionVertexIO sphereAmbientOcclusionVertex(const device packed_float3 *position [[buffer(0)]],
                                                       const device packed_float2 *inputImpostorSpaceCoordinate [[buffer(1)]],
                                                       const device packed_float2 *ambientOcclusionTextureOffset [[buffer(2)]],
                                                       constant SphereAmbientOcclusionVertexUniform& uniform [[buffer(3)]],
                                                       uint vid [[vertex_id]])
{
    SphereAmbientOcclusionVertexIO outputVertices;

    float4 transformedPosition = uniform.modelViewProjMatrix * float4(position[vid], 1.0);
    //    impostorSpaceCoordinate = inputImpostorSpaceCoordinate;
    float2 adjustedImpostorSpaceCoordinate;
    if (inputImpostorSpaceCoordinate[vid].x != 0.0)
    {
        adjustedImpostorSpaceCoordinate = sign(inputImpostorSpaceCoordinate[vid]);
    }
    else
    {
        adjustedImpostorSpaceCoordinate = float2(0.0, 0.0);
    }


    outputVertices.impostorSpaceCoordinate = adjustedImpostorSpaceCoordinate * (1.0 + 2.0 / (ambientOcclusionTextureWidth * uniform.ambientOcclusionTexturePatchWidth));

    outputVertices.adjustedSphereRadius = uniform.sphereRadius;

    transformedPosition = transformedPosition * uniform.orthographicMatrix;
    transformedPosition.z = (transformedPosition.z + 1.0) * 0.5;

    outputVertices.adjustmentForOrthographicProjection = (float4(0.5, 0.5, 0.5, 1.0) * uniform.orthographicMatrix).xyz;

    outputVertices.normalizedViewCoordinate = ((transformedPosition / 2.0) + 0.5).xyz;

    outputVertices.position = float4(ambientOcclusionTextureOffset[vid] * 2.0 - float2(1.0) + (uniform.ambientOcclusionTexturePatchWidth * adjustedImpostorSpaceCoordinate), 0.0, 1.0);
    return outputVertices;
}

constant float oneThird = 1.0 / 3.0;

float depthFromEncodedColor(float4 encodedColor)
{
    return oneThird * (encodedColor.r + encodedColor.g + encodedColor.b);
}

float3 coordinateFromTexturePosition(float2 texturePosition)
{
    float2 absoluteTexturePosition = abs(texturePosition);
    float h = 1.0 - absoluteTexturePosition.x - absoluteTexturePosition.y;

    if (h >= 0.0)
    {
        return float3(texturePosition.x, texturePosition.y, h);
    }
    else
    {
        return float3(sign(texturePosition.x) * (1.0 - absoluteTexturePosition.y), sign(texturePosition.y) * (1.0 - absoluteTexturePosition.x), h);
    }
}

fragment half4 sphereAmbientOcclusionFragment(SphereAmbientOcclusionVertexIO fragmentInput [[stage_in]],
                                                           texture2d<half> depthTexture [[texture(0)]],
                                                           constant SphereAmbientOcclusionFragmentUniform& uniform [[ buffer(1) ]])
{
    float4 currentSphereSurfaceCoordinate = float4(coordinateFromTexturePosition(clamp(fragmentInput.impostorSpaceCoordinate, -1.0, 1.0)), 1.0);

    currentSphereSurfaceCoordinate = normalize(uniform.modelViewProjMatrix * currentSphereSurfaceCoordinate);

    float3 currentPositionCoordinate = fragmentInput.normalizedViewCoordinate + fragmentInput.adjustedSphereRadius * currentSphereSurfaceCoordinate.xyz * fragmentInput.adjustmentForOrthographicProjection;


    constexpr sampler depthSampler;
    currentPositionCoordinate.y = 1.0 - currentPositionCoordinate.y;
    float previousDepthValue = depthFromEncodedColor(float4(depthTexture.sample(depthSampler, currentPositionCoordinate.xy)));

    if ( (floor(currentPositionCoordinate.z * 765.0 - 5.0)) <= (ceil(previousDepthValue * 765.0)) )
    {
        return half4(half3(uniform.intensityFactor), 1.0h);
    }
    else
    {
        return half4(0.0h, 0.0h, 0.0h, 1.0h);
    }
}
