precision mediump float;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump float depthOffsetAlongCenterAxis;
varying mediump float normalizedDisplacementAtEndCaps;
varying mediump float normalizedDepth;
varying mediump float depthAdjustmentForOrthographicProjection;

const vec3 stepValues = vec3(510.0, 255.0, 0.0);
const float scaleDownFactor = 1.0 / 255.0;

vec4 encodedColorForDepth(float depthValue)
{
    vec3 intDepthValue = vec3(ceil(depthValue * 765.0));
    
    intDepthValue = intDepthValue * scaleDownFactor - (stepValues * scaleDownFactor);
//    intDepthValue = (intDepthValue - stepValues) * scaleDownFactor;
    return vec4(clamp(intDepthValue, 0.0, 1.0), 1.0);
}

void main()
{
    float adjustmentFromCenterAxis = sqrt(1.0 - impostorSpaceCoordinate.s * impostorSpaceCoordinate.s);
    float displacementFromCurvature = normalizedDisplacementAtEndCaps * adjustmentFromCenterAxis;
    float depthOffset = depthOffsetAlongCenterAxis * adjustmentFromCenterAxis * depthAdjustmentForOrthographicProjection;

    if ( (impostorSpaceCoordinate.t <= (-1.0 + displacementFromCurvature)) || (impostorSpaceCoordinate.t >= (1.0 + displacementFromCurvature)))
    {
        gl_FragColor = vec4(1.0);
    }

//    if ( impostorSpaceCoordinate.t <= (-1.0 + displacementFromCurvature))
 //   {
  //      discard;
  //  }

    // Use a little fudge factor to account for rounding errors when zoomed out on the ball and stick mode
    float calculatedDepth = normalizedDepth - depthOffset + 0.0025;
    
    gl_FragColor = encodedColorForDepth(calculatedDepth);
}
