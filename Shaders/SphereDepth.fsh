precision mediump float;

uniform sampler2D precalculatedSphereDepthTexture;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump vec2 depthLookupCoordinate;
varying mediump float normalizedDepth;
varying mediump float halfSphereRadius;
varying mediump float depthAdjustmentForOrthographicProjection;

/*vec4 encodedColorForDepth(float depthValue)
{
    vec4 encodedColor;
    encodedColor.a = 1.0;
    encodedColor.b = max(0.0, depthValue - (2.0 / 3.0));
    encodedColor.g = max(0.0, depthValue - (1.0 / 3.0) - encodedColor.b);
    encodedColor.r = depthValue - encodedColor.b - encodedColor.g;
    encodedColor.rgb *= 3.0;
    return encodedColor;
    
//    return vec4(vec3(depthValue), 1.0);
}*/

/*
vec4 encodedColorForDepth(float depthValue)
{
    float intDepthValue = ceil(depthValue * 765.0);
    
    float blueInt = max(0.0, ceil(intDepthValue - 510.0));
    float greenInt = max(0.0, ceil(intDepthValue - 255.0 - blueInt));
    float redInt = intDepthValue - blueInt - greenInt;

    return vec4(vec3(blueInt, greenInt, redInt) / 255.0, 1.0);
}
 */

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
    mediump float precalculatedDepth = texture2D(precalculatedSphereDepthTexture, depthLookupCoordinate).r * depthAdjustmentForOrthographicProjection;
    // Establish the visual bounds of the sphere, setting depth to max if it fails
    mediump float currentDepthValue = (precalculatedDepth > 0.00) ? normalizedDepth - halfSphereRadius * precalculatedDepth : 1.0;
    
    gl_FragColor = encodedColorForDepth(currentDepthValue);
}