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
        return vec2(sphereSurfacePosition.x / d, sphereSurfacePosition.y / d);
    }
    else
    {
        return vec2(sign(sphereSurfacePosition.x) * ( 1.0 - absoluteSphereSurfacePosition.y / d), sign(sphereSurfacePosition.y) * (1.0 - absoluteSphereSurfacePosition.x / d));
    }
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
    float currentDepthValue = normalizedViewCoordinate.z - 0.5 * sphereRadius * precalculatedDepth * depthAdjustmentForOrthographicProjection;        
    
    // Check to see that this fragment is the frontmost one for this area
    if ( (floor(currentDepthValue * 765.0)) > (ceil(previousDepthValue * 765.0)) )
    {
        discard;
    }
    
    // Calculate the lighting normal for the sphere
    vec3 normal = vec3(impostorSpaceCoordinate, precalculatedDepth);
    
    vec3 finalSphereColor = sphereColor;
    

    // ambient
    vec3 aoNormal = normal;
    aoNormal.z = -aoNormal.z;
    aoNormal = (inverseModelViewProjMatrix * vec4(aoNormal, 0.0)).xyz;
    aoNormal.z = -aoNormal.z;
    vec2 textureCoordinateForAOLookup = ambientOcclusionTextureBase + (ambientOcclusionTexturePatchWidth - 2.0 / 1024.0) * (1.00 + textureCoordinateForSphereSurfacePosition(aoNormal)) / 2.00;
    vec3 ambientOcclusionIntensity = texture2D(ambientOcclusionTexture, textureCoordinateForAOLookup).rgb;
        
    float lightingIntensity = 0.3 + 0.7 * clamp(dot(lightPosition, normal), 0.0, 1.0);
    finalSphereColor *= lightingIntensity;
    
    // Per fragment specular lighting
    lightingIntensity  = clamp(dot(lightPosition, normal), 0.0, 1.0);
    lightingIntensity  = pow(lightingIntensity, 60.0);
    finalSphereColor += vec3(0.4, 0.4, 0.4) * lightingIntensity;
    
//
//    finalSphereColor *= sqrt(ambientOcclusionIntensity);
    finalSphereColor = finalSphereColor * 0.5 + vec3(1.0) * ambientOcclusionIntensity;

    
//    gl_FragColor = vec4(ambientOcclusionIntensity, 1.0);
    
//    gl_FragColor = vec4(texture2D(ambientOcclusionTexture, textureCoordinateForAOLookup).rgb, 1.0);
    
//    gl_FragColor = vec4(normal, 1.0);
    
//    gl_FragColor = texture2D(depthTexture, normalizedViewCoordinate.xy);
//    gl_FragColor = texture2D(precalculatedSphereDepthTexture, depthLookupCoordinate);
    
//    gl_FragColor = vec4(texture2D(ambientOcclusionTexture, normalizedViewCoordinate.xy).rgb, 1.0);
//    gl_FragColor = vec4(texture2D(ambientOcclusionTexture, (normalizedViewCoordinate.xy)).rgb, 1.0);
//    gl_FragColor = vec4(sphereColor, 1.0);
    gl_FragColor = vec4(finalSphereColor, 1.0);

}