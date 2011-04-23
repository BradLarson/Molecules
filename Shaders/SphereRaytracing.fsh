precision mediump float;

uniform mediump vec3 sphereColor;
uniform sampler2D precalculatedSphereDepthTexture;
uniform sampler2D depthTexture;
uniform sampler2D ambientOcclusionTexture;
uniform mediump mat4 inverseModelViewProjMatrix;
uniform mediump float ambientOcclusionTexturePatchWidth;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump vec2 depthLookupCoordinate;
varying mediump vec3 normalizedViewCoordinate;
varying mediump vec2 ambientOcclusionTextureBase;
varying mediump float adjustedSphereRadius;

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
    
    return (sphereSurfacePosition.z <= 0.0) ? sphereSurfacePosition.xy / d : sign(sphereSurfacePosition.xy) * ( 1.0 - absoluteSphereSurfacePosition.yx / d);    
}

void main()
{
    vec4 precalculatedDepthAndLighting = texture2D(precalculatedSphereDepthTexture, depthLookupCoordinate);
    float alphaValue = precalculatedDepthAndLighting.a;
    float previousDepthValue = depthFromEncodedColor(texture2D(depthTexture, normalizedViewCoordinate.xy));
    float currentDepthValue = normalizedViewCoordinate.z - adjustedSphereRadius * precalculatedDepthAndLighting.r;        
    
    // Check to see that this fragment is the frontmost one for this area
    alphaValue = ( (floor(currentDepthValue * 765.0)) > (ceil(previousDepthValue * 765.0)) ) ? 0.0 : alphaValue;
    
    // Ambient occlusion factor
    vec3 aoNormal = vec3(impostorSpaceCoordinate, -precalculatedDepthAndLighting.r);
    aoNormal = (inverseModelViewProjMatrix * vec4(aoNormal, 0.0)).xyz;
    aoNormal.z = -aoNormal.z;
    vec2 textureCoordinateForAOLookup = ambientOcclusionTextureBase + (ambientOcclusionTexturePatchWidth - 2.0 / 1024.0) * (1.00 + textureCoordinateForSphereSurfacePosition(aoNormal)) / 2.00;
    float ambientOcclusionIntensity = texture2D(ambientOcclusionTexture, textureCoordinateForAOLookup).r;

    // Ambient lighting
    float lightingIntensity = 0.2 + 1.3 * precalculatedDepthAndLighting.g * ambientOcclusionIntensity;
    vec3 finalSphereColor = sphereColor * lightingIntensity;
    
    // Specular lighting
    finalSphereColor += vec3(precalculatedDepthAndLighting.b * ambientOcclusionIntensity);
    
    gl_FragColor = vec4(finalSphereColor, alphaValue);
//    gl_FragColor = vec4(normalizedViewCoordinate, 1.0);
//    gl_FragColor = vec4(precalculatedDepthAndLighting, 1.0);

}