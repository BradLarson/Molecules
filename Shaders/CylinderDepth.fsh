precision mediump float;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump float depthOffsetAlongCenterAxis;
varying mediump float normalizedDisplacementAtEndCaps;
varying mediump float normalizedDepth;
varying mediump float depthAdjustmentForOrthographicProjection;

vec4 encodedColorForDepth(float depthValue)
{
    float intDepthValue = ceil(depthValue * 765.0);
    
    float blueInt = max(0.0, intDepthValue - 510.0);
    float greenInt = max(0.0, intDepthValue - 255.0 - blueInt);
    float redInt = intDepthValue - blueInt - greenInt;
    
    return vec4(vec3(blueInt, greenInt, redInt) / 255.0, 1.0);
}

void main()
{
    float adjustmentFromCenterAxis = sqrt(1.0 - impostorSpaceCoordinate.s * impostorSpaceCoordinate.s);
    float displacementFromCurvature = normalizedDisplacementAtEndCaps * adjustmentFromCenterAxis;
    float depthOffset = depthOffsetAlongCenterAxis * adjustmentFromCenterAxis * depthAdjustmentForOrthographicProjection;

    if ( (impostorSpaceCoordinate.t <= (-1.0 + displacementFromCurvature)) || (impostorSpaceCoordinate.t >= (1.0 + displacementFromCurvature)))
    {
        discard;
    }

    if ( impostorSpaceCoordinate.t <= (-1.0 + displacementFromCurvature))
    {
        discard;
    }

    float calculatedDepth = normalizedDepth - depthOffset + 0.0025;
    
    gl_FragColor = encodedColorForDepth(calculatedDepth);
}
