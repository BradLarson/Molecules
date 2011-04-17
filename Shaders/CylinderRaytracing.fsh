precision mediump float;

uniform vec3 lightPosition;
uniform vec3 cylinderColor;
uniform sampler2D depthTexture;

varying highp vec2 impostorSpaceCoordinate;
varying highp vec3 normalAlongCenterAxis;
varying highp float depthOffsetAlongCenterAxis;
varying highp float normalizedDepthOffsetAlongCenterAxis;
varying highp float normalizedDisplacementAtEndCaps;
varying highp float normalizedRadialDisplacementAtEndCaps;
varying highp vec2 rotationFactor;
varying mediump vec3 normalizedViewCoordinate;

const mediump float oneThird = 1.0 / 3.0;

mediump float depthFromEncodedColor(mediump vec4 encodedColor)
{
    return oneThird * (encodedColor.r + encodedColor.g + encodedColor.b);
    //    return encodedColor.r;
}

void main()
{
    float adjustmentFromCenterAxis = sqrt(1.0 - impostorSpaceCoordinate.s * impostorSpaceCoordinate.s);
    float displacementFromCurvature = normalizedDisplacementAtEndCaps * adjustmentFromCenterAxis;
    float depthOffset = depthOffsetAlongCenterAxis * adjustmentFromCenterAxis;

    vec3 normal = vec3(normalizedRadialDisplacementAtEndCaps * rotationFactor.x * adjustmentFromCenterAxis + impostorSpaceCoordinate.s * rotationFactor.y,
                       normalizedRadialDisplacementAtEndCaps * rotationFactor.y * adjustmentFromCenterAxis + impostorSpaceCoordinate.s * rotationFactor.x,
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

    float currentDepthValue = normalizedViewCoordinate.z - depthOffset - 0.0025;
    float previousDepthValue = depthFromEncodedColor(texture2D(depthTexture, normalizedViewCoordinate.xy));
    
    if (currentDepthValue >= previousDepthValue)
    {
        discard;
    }
    
    vec3 finalCylinderColor = cylinderColor;
    
    // ambient
    float lightingIntensity = 0.3 + 0.7 * clamp(dot(lightPosition, normal), 0.0, 1.0);
    finalCylinderColor *= lightingIntensity;
    
    // Per fragment specular lighting
    lightingIntensity  = clamp(dot(lightPosition, normal), 0.0, 1.0);
    lightingIntensity  = pow(lightingIntensity, 60.0);
    finalCylinderColor += vec3(0.4, 0.4, 0.4) * lightingIntensity;
    
//    gl_FragColor = texture2D(depthTexture, normalizedViewCoordinate.xy);

    gl_FragColor = vec4(finalCylinderColor, 1.0);
}
