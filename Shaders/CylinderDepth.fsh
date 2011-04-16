precision mediump float;

varying highp vec2 impostorSpaceCoordinate;
varying highp float depthOffsetAlongCenterAxis;
varying highp float normalizedDisplacementAtEndCaps;
varying mediump float normalizedDepth;

vec4 encodedColorForDepth(float depthValue)
{
    vec4 encodedColor;
    encodedColor.a = 1.0;
    encodedColor.b = max(0.0, depthValue - (2.0 / 3.0));
    encodedColor.g = max(0.0, depthValue - (1.0 / 3.0) - encodedColor.b);
    encodedColor.r = depthValue - encodedColor.b - encodedColor.g;
    encodedColor.rgb *= 3.0;
    return encodedColor;
    
    //    return vec4(vec3(depthValue), 1.0);
}

void main()
{
    float adjustmentFromCenterAxis = sqrt(1.0 - impostorSpaceCoordinate.s * impostorSpaceCoordinate.s);
    float displacementFromCurvature = normalizedDisplacementAtEndCaps * adjustmentFromCenterAxis;
    float depthOffset = depthOffsetAlongCenterAxis * adjustmentFromCenterAxis;

    if ( (impostorSpaceCoordinate.t <= (-1.0 + displacementFromCurvature)) || (impostorSpaceCoordinate.t >= (1.0 + displacementFromCurvature)))
    {
        discard;
    }

    if ( impostorSpaceCoordinate.t <= (-1.0 + displacementFromCurvature))
    {
        discard;
    }

    float calculatedDepth = normalizedDepth - depthOffset;
    
    gl_FragColor = encodedColorForDepth(calculatedDepth);
}
