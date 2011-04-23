precision mediump float;

uniform sampler2D precalculatedSphereDepthTexture;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump vec2 depthLookupCoordinate;
varying mediump float normalizedDepth;
varying mediump float halfSphereRadius;
varying mediump float depthAdjustmentForOrthographicProjection;

const vec3 stepValues = vec3(510.0, 255.0, 0.0);
const float scaleDownFactor = 1.0 / 255.0;

vec4 encodedColorForDepth(float depthValue)
{
    vec3 intDepthValue = vec3(ceil(depthValue * 765.0));
    
    intDepthValue = (intDepthValue - stepValues) * scaleDownFactor;
    return vec4(clamp(intDepthValue, 0.0, 1.0), 1.0);
}
 
void main()
{
    mediump float precalculatedDepth = texture2D(precalculatedSphereDepthTexture, depthLookupCoordinate).r * depthAdjustmentForOrthographicProjection;
    // Establish the visual bounds of the sphere, setting depth to max if it fails
    mediump float currentDepthValue = (precalculatedDepth > 0.00) ? normalizedDepth - halfSphereRadius * precalculatedDepth : 1.0;
    
    gl_FragColor = encodedColorForDepth(currentDepthValue);
}