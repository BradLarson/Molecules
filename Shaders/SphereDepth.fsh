precision mediump float;

uniform vec3 lightPosition;
uniform vec3 sphereColor;
uniform mediump float sphereRadius;

varying mediump vec2 impostorSpaceCoordinate;
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
    float distanceFromCenter = length(impostorSpaceCoordinate);
    
    float depthOfFragment = sphereRadius * 0.5 * sqrt(1.0 - distanceFromCenter * distanceFromCenter);
    float currentDepthValue = normalizedDepth - depthOfFragment;        

    // Establish the visual bounds of the sphere, setting depth to max if it fails
    currentDepthValue = (distanceFromCenter > 1.0) ? 1.0 : currentDepthValue;
//    gl_FragColor = vec4(vec3(currentDepthValue), 1.0);
    gl_FragColor = encodedColorForDepth(currentDepthValue);
}