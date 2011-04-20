precision mediump float;

uniform vec3 lightPosition;
uniform vec3 cylinderColor;
uniform sampler2D depthTexture;
uniform sampler2D ambientOcclusionTexture;
uniform mat4 inverseModelViewProjMatrix;
uniform mediump float ambientOcclusionTexturePatchWidth;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump vec3 normalAlongCenterAxis;
varying mediump float depthOffsetAlongCenterAxis;
varying mediump float normalizedDepthOffsetAlongCenterAxis;
varying mediump float normalizedDisplacementAtEndCaps;
varying mediump float normalizedRadialDisplacementAtEndCaps;
varying mediump vec2 rotationFactor;
varying mediump vec3 normalizedViewCoordinate;
varying mediump vec2 ambientOcclusionTextureBase;
varying mediump float depthAdjustmentForOrthographicProjection;

const mediump float oneThird = 1.0 / 3.0;

mediump float depthFromEncodedColor(mediump vec4 encodedColor)
{
    return oneThird * (encodedColor.r + encodedColor.g + encodedColor.b);
    //    return encodedColor.r;
}

mediump vec2 textureCoordinateForSphereSurfacePosition(mediump vec3 sphereSurfacePosition)
{
    vec3 absoluteSphereSurfacePosition = abs(sphereSurfacePosition);
    float d = absoluteSphereSurfacePosition.x + absoluteSphereSurfacePosition.y + absoluteSphereSurfacePosition.z;
    
    if (sphereSurfacePosition.z <= 0.0)
    {
        return vec2(sphereSurfacePosition.x / d, sphereSurfacePosition.y / d);
    }
    else
    {
        return vec2(sign(sphereSurfacePosition.x) * ( 1.0 - absoluteSphereSurfacePosition.y / d), sign(sphereSurfacePosition.y) * (1.0 - absoluteSphereSurfacePosition.x / d));
    }
}

void main()
{
    float adjustmentFromCenterAxis = sqrt(1.0 - impostorSpaceCoordinate.s * impostorSpaceCoordinate.s);
    float displacementFromCurvature = normalizedDisplacementAtEndCaps * adjustmentFromCenterAxis;
    float depthOffset = depthOffsetAlongCenterAxis * adjustmentFromCenterAxis * depthAdjustmentForOrthographicProjection;

    vec3 normal = vec3(normalizedRadialDisplacementAtEndCaps * rotationFactor.x * adjustmentFromCenterAxis + impostorSpaceCoordinate.s * rotationFactor.y,
                       -(normalizedRadialDisplacementAtEndCaps * rotationFactor.y * adjustmentFromCenterAxis + impostorSpaceCoordinate.s * rotationFactor.x),
                       normalizedDepthOffsetAlongCenterAxis * adjustmentFromCenterAxis);
    
    normal = normalize(normal);
    
    if ( (impostorSpaceCoordinate.t <= (-1.0 + displacementFromCurvature)) || (impostorSpaceCoordinate.t >= (1.0 + displacementFromCurvature)))
    {
        discard;
    }

    if ( impostorSpaceCoordinate.t <= (-1.0 + displacementFromCurvature))
    {
        discard;
    }

    float currentDepthValue = normalizedViewCoordinate.z - depthOffset;
    float previousDepthValue = depthFromEncodedColor(texture2D(depthTexture, normalizedViewCoordinate.xy));
    
    if ( (floor(currentDepthValue * 765.0)) > (ceil(previousDepthValue * 765.0)) )
    {
        discard;
    }
    
    vec3 finalCylinderColor = cylinderColor;
    
    // ambient
    vec3 aoNormal = normal;
    aoNormal.z = -aoNormal.z;
    aoNormal = (inverseModelViewProjMatrix * vec4(aoNormal, 0.0)).xyz;
    aoNormal.z = -aoNormal.z;
    vec2 textureCoordinateForAOLookup = ambientOcclusionTextureBase + (ambientOcclusionTexturePatchWidth - 2.0 / 1024.0) * (1.00 + textureCoordinateForSphereSurfacePosition(aoNormal)) / 2.00;
    vec3 ambientOcclusionIntensity = texture2D(ambientOcclusionTexture, textureCoordinateForAOLookup).rgb;

    float lightingIntensity = 0.3 + 0.7 * clamp(dot(lightPosition, normal), 0.0, 1.0);
    finalCylinderColor *= lightingIntensity;
    
    // Per fragment specular lighting
    lightingIntensity  = clamp(dot(lightPosition, normal), 0.0, 1.0);
    lightingIntensity  = pow(lightingIntensity, 60.0);
    finalCylinderColor += vec3(0.4, 0.4, 0.4) * lightingIntensity;
    
//    gl_FragColor = texture2D(depthTexture, normalizedViewCoordinate.xy);

//    normal.z = -normal.z;
//    normal = (inverseModelViewProjMatrix * vec4(normal, 0.0)).xyz;
//    normal.z = -normal.z;
//    
//    gl_FragColor = vec4(normal, 1.0);

    gl_FragColor = vec4(finalCylinderColor, 1.0);
}
