precision mediump float;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump float normalizedDepth;
varying mediump float adjustedSphereRadius;
varying mediump vec2 depthLookupCoordinate;

uniform lowp sampler2D sphereDepthMap;

const lowp vec3 stepValues = vec3(2.0, 1.0, 0.0);
const mediump float scaleDownFactor = 1.0 / 255.0;

void main()
{
//    gl_FragColor = vec4(normalizedDepth * (impostorSpaceCoordinate + 1.0) / 2.0, normalizedDepth, 1.0);
    lowp vec2 precalculatedDepthAndAlpha = texture2D(sphereDepthMap, depthLookupCoordinate).ra;

    float inCircleMultiplier = step(0.5, precalculatedDepthAndAlpha.g);
    
//    if (precalculatedDepthAndAlpha.g < 0.5)
//    {
//        gl_FragColor = vec4(1.0);
//    }
//    else
//    {
        float currentDepthValue = normalizedDepth + adjustedSphereRadius - adjustedSphereRadius * precalculatedDepthAndAlpha.r;
        
        // Inlined color encoding for the depth values
        currentDepthValue = currentDepthValue * 3.0;
        //float ceiledValue = ceil(currentDepthValue * 765.0) * scaleDownFactor;
        
        lowp vec3 intDepthValue = vec3(currentDepthValue) - stepValues;
//        lowp vec4 outputColor = vec4(intDepthValue, 1.0);
//        
//        gl_FragColor = outputColor;

    gl_FragColor = vec4(1.0 - inCircleMultiplier) + vec4(intDepthValue, inCircleMultiplier);
//    }
}