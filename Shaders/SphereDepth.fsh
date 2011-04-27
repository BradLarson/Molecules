precision mediump float;

uniform sampler2D precalculatedSphereDepthTexture;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump vec2 depthLookupCoordinate;
varying mediump float normalizedDepth;
varying mediump float adjustedSphereRadius;

const vec3 stepValues = vec3(510.0, 255.0, 0.0);
const float scaleDownFactor = 1.0 / 255.0;

lowp vec4 encodedColorForDepth(float depthValue)
{
    vec3 intDepthValue = vec3(ceil(depthValue * 765.0));
    
    intDepthValue = (intDepthValue - stepValues) * scaleDownFactor;
    return vec4(clamp(intDepthValue, 0.0, 1.0), 1.0);
}

void main()
{
    lowp float precalculatedDepth = texture2D(precalculatedSphereDepthTexture, depthLookupCoordinate).r;
    if (precalculatedDepth < 0.01)
    {
        gl_FragColor = vec4(1.0);
    }
    else
    {
        mediump float currentDepthValue = normalizedDepth - adjustedSphereRadius * precalculatedDepth;
        
        gl_FragColor = encodedColorForDepth(currentDepthValue);
    }
    
    
    // Establish the visual bounds of the sphere, setting depth to max if it fails
//    mediump float currentDepthValue = (precalculatedDepth > 0.00) ? normalizedDepth - halfSphereRadius * precalculatedDepth * depthAdjustmentForOrthographicProjection: 1.0;
//    
//    gl_FragColor = encodedColorForDepth(currentDepthValue);
}