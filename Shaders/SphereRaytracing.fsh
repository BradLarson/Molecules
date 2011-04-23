precision mediump float;

uniform mediump vec3 lightPosition;
uniform mediump vec3 sphereColor;
uniform mediump float sphereRadius;
uniform sampler2D precalculatedSphereDepthTexture;
uniform sampler2D depthTexture;
uniform sampler2D ambientOcclusionTexture;
uniform mediump mat4 inverseModelViewProjMatrix;
uniform mediump mat4 modelViewProjMatrix;
uniform mediump float ambientOcclusionTexturePatchWidth;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump vec2 depthLookupCoordinate;
varying mediump vec3 normalizedViewCoordinate;
varying mediump vec2 ambientOcclusionTextureBase;
varying mediump float depthAdjustmentForOrthographicProjection;

const mediump float oneThird = 1.0 / 3.0;

mediump float depthFromEncodedColor(mediump vec4 encodedColor)
{
    return oneThird * (encodedColor.r + encodedColor.g + encodedColor.b);
//    return encodedColor.r;
}

mediump vec2 textureCoordinateForSphereSurfacePosition(mediump vec3 sphereSurfacePosition)
{
    vec3 absoluteSphereSurfacePosition = abs(sphereSurfacePosition);
    float d = absoluteSphereSurfacePosition.x + absoluteSphereSurfacePosition.y + absoluteSphereSurfacePosition.z;
    
    if (sphereSurfacePosition.z <= 0.0)
    {
        return sphereSurfacePosition.xy / d;
    }
    else
    {
        return sign(sphereSurfacePosition.xy) * ( 1.0 - absoluteSphereSurfacePosition.yx / d);
    }
}

void main()
{
//    float distanceFromCenter = length(impostorSpaceCoordinate);
    float alphaValue = 1.0;
    
    // Establish the visual bounds of the sphere
//    if (distanceFromCenter > 1.0)
//    {
//        discard;
//    }
    
    vec4 precalculatedDepthAndLighting = texture2D(precalculatedSphereDepthTexture, depthLookupCoordinate);
    alphaValue = precalculatedDepthAndLighting.a;
    float previousDepthValue = depthFromEncodedColor(texture2D(depthTexture, normalizedViewCoordinate.xy));
    float currentDepthValue = normalizedViewCoordinate.z - 0.5 * sphereRadius * precalculatedDepthAndLighting.r * depthAdjustmentForOrthographicProjection;        
    
    // Check to see that this fragment is the frontmost one for this area
    if ( (floor(currentDepthValue * 765.0)) > (ceil(previousDepthValue * 765.0)) )
    {
        alphaValue = 0.0;
//        discard;
    }
    
    // Calculate the lighting normal for the sphere
    vec3 normal = vec3(impostorSpaceCoordinate, precalculatedDepthAndLighting.r);
    
    // Ambient occlusion factor
//    vec3 aoNormal = normal;
//    aoNormal.z = -aoNormal.z;
//    aoNormal = (inverseModelViewProjMatrix * vec4(aoNormal, 0.0)).xyz;
//    aoNormal.z = -aoNormal.z;
//    vec2 textureCoordinateForAOLookup = ambientOcclusionTextureBase + (ambientOcclusionTexturePatchWidth - 2.0 / 1024.0) * (1.00 + textureCoordinateForSphereSurfacePosition(aoNormal)) / 2.00;
//    vec3 ambientOcclusionIntensity = texture2D(ambientOcclusionTexture, textureCoordinateForAOLookup).rgb;

    // Ambient lighting
//    float lightingIntensity = 0.2 + 1.3 * precalculatedDepthAndLighting.g * ambientOcclusionIntensity.r;
    float lightingIntensity = 0.2 + 1.3 * precalculatedDepthAndLighting.g;
    vec3 finalSphereColor = sphereColor * lightingIntensity;
    
    // Specular lighting
//    finalSphereColor += vec3(0.4) * precalculatedDepthAndLighting.b * ambientOcclusionIntensity * 1.2 + vec3(0.2) * ambientOcclusionIntensity.r;
    finalSphereColor += vec3(0.4) * precalculatedDepthAndLighting.b;
    
    
//    float lightingIntensity = 0.2 + 1.3 * clamp(dot(lightPosition, normal), 0.0, 1.0) * ambientOcclusionIntensity.r;
//    finalSphereColor *= lightingIntensity;
//    
//    // Per fragment specular lighting
//    lightingIntensity  = clamp(dot(lightPosition, normal), 0.0, 1.0);
//    lightingIntensity  = pow(lightingIntensity, 60.0) * ambientOcclusionIntensity.r * 1.2;
//    finalSphereColor += vec3(0.4, 0.4, 0.4) * lightingIntensity + vec3(1.0, 1.0, 1.0) * 0.2 * ambientOcclusionIntensity.r;
//
//    finalSphereColor *= sqrt(ambientOcclusionIntensity);
//    finalSphereColor = finalSphereColor * 0.75 + vec3(1.0) * 0.5 * ambientOcclusionIntensity;

    
//    gl_FragColor = vec4(ambientOcclusionIntensity, 1.0);
    
//    gl_FragColor = vec4(texture2D(ambientOcclusionTexture, textureCoordinateForAOLookup).rgb, 1.0);
    
//    gl_FragColor = vec4(normal, 1.0);
    
//    gl_FragColor = texture2D(depthTexture, normalizedViewCoordinate.xy);
//    gl_FragColor = texture2D(precalculatedSphereDepthTexture, depthLookupCoordinate);
//    gl_FragColor = vec4(ambientOcclusionTextureBase, 0.0, 1.0);

//    gl_FragColor = vec4(texture2D(ambientOcclusionTexture, normalizedViewCoordinate.xy).rgb, 1.0);
//    gl_FragColor = vec4(sphereColor, 1.0);
    gl_FragColor = vec4(finalSphereColor, alphaValue);
//    gl_FragColor = vec4(normalizedViewCoordinate, 1.0);
//    gl_FragColor = vec4(precalculatedDepthAndLighting, 1.0);

}