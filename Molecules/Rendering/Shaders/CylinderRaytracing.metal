#include <metal_stdlib>
using namespace metal;

typedef struct
{
    float4x4 modelViewProjMatrix;
    float4x4 orthographicMatrix;
    float cylinderRadius;
    float3 translation;
} CylinderRaytracingVertexUniform;

typedef struct
{
    float3 cylinderColor;
    float4x4 inverseModelViewProjMatrix;
    // TODO: Ambient occlusion texture and parameters.
} CylinderRaytracingFragmentUniform;

struct CylinderRaytracingVertexIO
{
    float4 position [[position]];
    float2 impostorSpaceCoordinate [[user(impostorSpaceCoordinate)]];
    float3 normalizedViewCoordinate [[user(normalizedViewCoordinate)]];
    float3 normalAlongCenterAxis [[user(normalAlongCenterAxis)]];
    float2 rotationFactor [[user(rotationFactor)]];
    float depthOffsetAlongCenterAxis;
    float normalizedDepthOffsetAlongCenterAxis;
    float normalizedDisplacementAtEndCaps;
    float normalizedRadialDisplacementAtEndCaps;
    float depthAdjustmentForOrthographicProjection;
    float normalizedDistanceAlongZAxis;
};

vertex CylinderRaytracingVertexIO cylinderRaytracingVertex(const device packed_float3 *position [[buffer(0)]],
                                                           const device packed_float3 *direction [[buffer(1)]],
                                                           const device packed_float2 *inputImpostorSpaceCoordinate [[buffer(2)]],
                                                           //const device packed_float2 *ambientOcclusionTextureOffset [[buffer(2)]],
                                                           constant CylinderRaytracingVertexUniform& uniform [[buffer(4)]],
                                                           uint vid [[vertex_id]])
{
    CylinderRaytracingVertexIO outputVertices;
        
//    ambientOcclusionTextureBase = ambientOcclusionTextureOffset;
    outputVertices.normalizedDistanceAlongZAxis = inputImpostorSpaceCoordinate[vid].y;

    float4 transformedDirection, transformedPosition, transformedOtherPosition;
    float3 viewDisplacementForVertex, displacementDirectionAtEndCap;
    float displacementAtEndCaps, lengthOfCylinder, lengthOfCylinderInView;

    outputVertices.depthAdjustmentForOrthographicProjection = (float4(0.0, 0.0, 0.5, 1.0) * uniform.orthographicMatrix).z;

    transformedPosition = uniform.modelViewProjMatrix * (float4(position[vid] + uniform.translation, 1.0));
    transformedPosition.z = (transformedPosition.z + 1.0) * 0.5;

    transformedOtherPosition = uniform.modelViewProjMatrix * float4(position[vid] + direction[vid] + uniform.translation, 1.0);
    transformedOtherPosition.z = (transformedOtherPosition.z + 1.0) * 0.5;

    transformedDirection = transformedOtherPosition - transformedPosition;

    lengthOfCylinder = length(transformedDirection.xyz);
    lengthOfCylinderInView = length(transformedDirection.xy);
    outputVertices.rotationFactor = transformedDirection.xy / lengthOfCylinderInView;

    displacementAtEndCaps = uniform.cylinderRadius * (transformedOtherPosition.z - transformedPosition.z) / lengthOfCylinder;
    outputVertices.normalizedDisplacementAtEndCaps = displacementAtEndCaps / lengthOfCylinderInView;
    outputVertices.normalizedRadialDisplacementAtEndCaps = displacementAtEndCaps / uniform.cylinderRadius;

    outputVertices.depthOffsetAlongCenterAxis = uniform.cylinderRadius * lengthOfCylinder * rsqrt(lengthOfCylinder * lengthOfCylinder - (transformedOtherPosition.z - transformedPosition.z) * (transformedOtherPosition.z - transformedPosition.z));
    outputVertices.depthOffsetAlongCenterAxis = clamp(outputVertices.depthOffsetAlongCenterAxis, 0.0, uniform.cylinderRadius * 2.0);
    outputVertices.normalizedDepthOffsetAlongCenterAxis = outputVertices.depthOffsetAlongCenterAxis / (uniform.cylinderRadius);

    displacementDirectionAtEndCap.xy = displacementAtEndCaps * outputVertices.rotationFactor;
    displacementDirectionAtEndCap.z = transformedDirection.z * displacementAtEndCaps / lengthOfCylinder;

    transformedDirection.xy = normalize(transformedDirection.xy);

    if ((displacementAtEndCaps * inputImpostorSpaceCoordinate[vid].y) > 0.0)
    {
        viewDisplacementForVertex.x = inputImpostorSpaceCoordinate[vid].x * transformedDirection.y * uniform.cylinderRadius + displacementDirectionAtEndCap.x;
        viewDisplacementForVertex.y = -inputImpostorSpaceCoordinate[vid].x * transformedDirection.x * uniform.cylinderRadius + displacementDirectionAtEndCap.y;
        viewDisplacementForVertex.z = displacementDirectionAtEndCap.z;
        outputVertices.impostorSpaceCoordinate = float2(inputImpostorSpaceCoordinate[vid].x, inputImpostorSpaceCoordinate[vid].y + 1.0 * outputVertices.normalizedDisplacementAtEndCaps);
    }
    else
    {
        viewDisplacementForVertex.x = inputImpostorSpaceCoordinate[vid].x * transformedDirection.y * uniform.cylinderRadius;
        viewDisplacementForVertex.y = -inputImpostorSpaceCoordinate[vid].x * transformedDirection.x * uniform.cylinderRadius;
        viewDisplacementForVertex.z = 0.0;
        //        impostorSpaceCoordinate = inputImpostorSpaceCoordinate.st;
        outputVertices.impostorSpaceCoordinate = float2(inputImpostorSpaceCoordinate[vid].x, inputImpostorSpaceCoordinate[vid].y);
    }

    transformedPosition.xyz = transformedPosition.xyz + viewDisplacementForVertex;
    //    transformedPosition.z = 0.0;

    transformedPosition = transformedPosition * uniform.orthographicMatrix;

    outputVertices.normalizedViewCoordinate = ((transformedPosition / 2.0) + 0.5).xyz;

    outputVertices.position = transformedPosition;
    return outputVertices;
}

struct FragmentColorDepth {
    half4 color [[color(0)]];
    float depth [[depth(any)]];
};

constant half3 lightPosition = half3(0.312757, 0.248372, 0.916785);

fragment FragmentColorDepth cylinderRaytracingFragment(CylinderRaytracingVertexIO fragmentInput [[stage_in]],
//                                 texture2d<half> ambientOcclusionTexture [[texture(0)]],
//                                 texture2d<half> precalculatedAOLookupTexture [[texture(1)]],
                                 constant CylinderRaytracingFragmentUniform& uniform [[ buffer(1) ]])
{
    float adjustmentFromCenterAxis = sqrt(1.0 - fragmentInput.impostorSpaceCoordinate.x * fragmentInput.impostorSpaceCoordinate.x);
    float displacementFromCurvature = fragmentInput.normalizedDisplacementAtEndCaps * adjustmentFromCenterAxis;
    float depthOffset = fragmentInput.depthOffsetAlongCenterAxis * adjustmentFromCenterAxis * fragmentInput.depthAdjustmentForOrthographicProjection;

    half3 normal = half3(fragmentInput.normalizedRadialDisplacementAtEndCaps * fragmentInput.rotationFactor.x * adjustmentFromCenterAxis + fragmentInput.impostorSpaceCoordinate.x * fragmentInput.rotationFactor.y,
                       -(fragmentInput.normalizedRadialDisplacementAtEndCaps * fragmentInput.rotationFactor.y * adjustmentFromCenterAxis + fragmentInput.impostorSpaceCoordinate.x * fragmentInput.rotationFactor.x),
                         fragmentInput.normalizedDepthOffsetAlongCenterAxis * adjustmentFromCenterAxis);

    normal = normalize(normal);

    if ( (fragmentInput.impostorSpaceCoordinate.y <= (-1.0 + displacementFromCurvature)) || (fragmentInput.impostorSpaceCoordinate.y >= (1.0 + displacementFromCurvature)))
    {
        FragmentColorDepth colorDepth;
        colorDepth.color = half4(0.0); // Black background
//        colorDepth.color = half4(1.0); // White background
        colorDepth.depth = 1.0;
        return colorDepth;
    }
    else
    {
        float currentDepthValue = fragmentInput.normalizedViewCoordinate.z - depthOffset + 0.0025;

        half3 finalCylinderColor = half3(uniform.cylinderColor);

        // ambient
//        vec3 aoNormal = vec3(0.5, 0.5, normalizedDistanceAlongZAxis);
//        vec2 textureCoordinateForAOLookup = ambientOcclusionTextureBase + ambientOcclusionTexturePatchWidth * 0.5 * textureCoordinateForCylinderSurfacePosition(aoNormal);
//        vec3 ambientOcclusionIntensity = texture2D(ambientOcclusionTexture, textureCoordinateForAOLookup).rgb;

        half lightingIntensity = 0.1 + clamp(dot(lightPosition, normal), 0.0h, 1.0h); // * ambientOcclusionIntensity.r;
        finalCylinderColor *= lightingIntensity;

        // Per fragment specular lighting
        lightingIntensity  = clamp(dot(lightPosition, normal), 0.0h, 1.0h);
        lightingIntensity  = pow(lightingIntensity, 60.0h) /* * ambientOcclusionIntensity.r */ * 1.2h;
        finalCylinderColor += 0.4 * lightingIntensity;

        FragmentColorDepth colorDepth;
        colorDepth.color = half4(finalCylinderColor, 1.0);
        colorDepth.depth = currentDepthValue;
        return colorDepth;
    }
}
