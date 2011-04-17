precision mediump float;

uniform vec3 lightPosition;
uniform vec3 sphereColor;
uniform mediump float sphereRadius;

uniform sampler2D depthTexture;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump vec3 normalizedViewCoordinate;

const mediump vec3 oneVector = vec3(1.0, 1.0, 1.0);
const mediump float oneThird = 1.0 / 3.0;

mediump float depthFromEncodedColor(mediump vec4 encodedColor)
{
    return dot(encodedColor.rgb, oneVector) * oneThird;
//    return encodedColor.r;
}

/*vec3 normalizeColor(vec3 color)
{
    return color / max(dot(color, vec3(1.0/3.0)), 0.3);
}*/

void main()
{
    float distanceFromCenter = length(impostorSpaceCoordinate);
    
    // Establish the visual bounds of the sphere
    if (distanceFromCenter > 1.0)
    {
        discard;
    }
    
    // Previous depth values for comparison
    float previousDepthValue = depthFromEncodedColor(texture2D(depthTexture, normalizedViewCoordinate.xy));
    float normalizedDepth = sqrt(1.0 - distanceFromCenter * distanceFromCenter);
    
    // Current depth
    float depthOfFragment = sphereRadius * 0.5 * normalizedDepth;
    //        float currentDepthValue = normalizedViewCoordinate.z - depthOfFragment - 0.0025;
    float currentDepthValue = (normalizedViewCoordinate.z - depthOfFragment - 0.0025);
    
    // Check to see that this fragment is the frontmost one for this area
    if (currentDepthValue >= previousDepthValue)
    {
        discard;
    }

    // Calculate the lighting normal for the sphere
    vec3 normal = vec3(impostorSpaceCoordinate, normalizedDepth);
    
    vec3 finalSphereColor = sphereColor;
    
    // ambient
    float lightingIntensity = 0.3 + 0.7 * clamp(dot(lightPosition, normal), 0.0, 1.0);
    finalSphereColor *= lightingIntensity;
    
    // Per fragment specular lighting
    lightingIntensity  = clamp(dot(lightPosition, normal), 0.0, 1.0);
    lightingIntensity  = pow(lightingIntensity, 60.0);
    finalSphereColor += vec3(0.4, 0.4, 0.4) * lightingIntensity;

//    gl_FragColor = texture2D(depthTexture, normalizedViewCoordinate.xy);
    
    gl_FragColor = vec4(finalSphereColor, 1.0);
}