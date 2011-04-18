precision mediump float;

uniform vec3 lightPosition;
uniform vec3 sphereColor;
uniform mediump float sphereRadius;
uniform sampler2D precalculatedSphereDepthTexture;
uniform sampler2D depthTexture;
uniform mat4 inverseModelViewProjMatrix;
uniform mat4 modelViewProjMatrix;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump vec2 depthLookupCoordinate;
varying mediump vec3 normalizedViewCoordinate;

const mediump float oneThird = 1.0 / 3.0;

mediump float depthFromEncodedColor(mediump vec4 encodedColor)
{
    return oneThird * (encodedColor.r + encodedColor.g + encodedColor.b);
//    return encodedColor.r;
}

void main()
{
    float distanceFromCenter = length(impostorSpaceCoordinate);
    
    // Establish the visual bounds of the sphere
    if (distanceFromCenter > 1.0)
    {
        discard;
    }
    
    float precalculatedDepth = texture2D(precalculatedSphereDepthTexture, depthLookupCoordinate).r;    
    float previousDepthValue = depthFromEncodedColor(texture2D(depthTexture, normalizedViewCoordinate.xy));
    float currentDepthValue = normalizedViewCoordinate.z - 0.5 * sphereRadius * precalculatedDepth - 0.0025;        
    
    // Check to see that this fragment is the frontmost one for this area
    if (currentDepthValue >= previousDepthValue)
    {
        discard;
    }
    
    // Calculate the lighting normal for the sphere
    vec3 normal = vec3(impostorSpaceCoordinate, precalculatedDepth);
    
    vec3 finalSphereColor = sphereColor;
    
    // ambient
    float lightingIntensity = 0.3 + 0.7 * clamp(dot(lightPosition, normal), 0.0, 1.0);
    finalSphereColor *= lightingIntensity;
    
    // Per fragment specular lighting
    lightingIntensity  = clamp(dot(lightPosition, normal), 0.0, 1.0);
    lightingIntensity  = pow(lightingIntensity, 60.0);
    finalSphereColor += vec3(0.4, 0.4, 0.4) * lightingIntensity;
    
  
    normal.z = -normal.z;
    normal = (inverseModelViewProjMatrix * vec4(normal, 0.0)).xyz;
    normal.z = -normal.z;
    
//    gl_FragColor = vec4(normal, 1.0);
    
//    gl_FragColor = texture2D(depthTexture, normalizedViewCoordinate.xy);
//    gl_FragColor = texture2D(precalculatedSphereDepthTexture, depthLookupCoordinate);
    gl_FragColor = vec4(finalSphereColor, 1.0);
//    gl_FragColor = vec4(sphereColor, 1.0);

}