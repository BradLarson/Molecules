precision mediump float;

uniform mediump vec3 sphereColor;
uniform sampler2D depthTexture;
uniform sampler2D ambientOcclusionTexture;
uniform sampler2D precalculatedAOLookupTexture;
uniform mediump mat3 inverseModelViewProjMatrix;
uniform mediump float ambientOcclusionTexturePatchWidth;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump vec2 depthLookupCoordinate;
varying mediump vec3 normalizedViewCoordinate;
varying mediump vec2 ambientOcclusionTextureBase;
varying mediump float adjustedSphereRadius;

const mediump float oneThird = 1.0 / 3.0;
const vec3 lightPosition = vec3(0.312757, 0.248372, 0.916785);

mediump float depthFromEncodedColor(mediump vec3 encodedColor)
{
    return (encodedColor.r + encodedColor.g + encodedColor.b) * oneThird;
}

void main()
{
//    gl_FragColor = vec4(1.0);

    float distanceFromCenter = length(impostorSpaceCoordinate);

//    vec4 precalculatedDepthAndLighting = texture2D(precalculatedSphereDepthTexture, depthLookupCoordinate);

    //    vec4 precalculatedDepthAndLighting = vec4(1.0);

//    if (precalculatedDepthAndLighting.r < 0.05)
//    {
//        gl_FragColor = vec4(0.0);
//    }
    if (distanceFromCenter > 1.0)
    {
        gl_FragColor = vec4(0.0);
    }
    else
    {
        float normalizedDepth = sqrt(1.0 - distanceFromCenter * distanceFromCenter);

//        float currentDepthValue = normalizedViewCoordinate.z - adjustedSphereRadius * precalculatedDepthAndLighting.r;        
        float currentDepthValue = normalizedViewCoordinate.z - adjustedSphereRadius * normalizedDepth;        
        vec3 encodedColor = texture2D(depthTexture, normalizedViewCoordinate.xy).rgb;
        float previousDepthValue = depthFromEncodedColor(encodedColor);
      
        // Check to see that this fragment is the frontmost one for this area
  //      if ( (floor(currentDepthValue * 765.0)) > (ceil(previousDepthValue)) )
        if ( (currentDepthValue - 0.002) > (previousDepthValue) )
        {
            gl_FragColor = vec4(0.0);
        }
        else
        {            
            vec2 lookupTextureCoordinate = texture2D(precalculatedAOLookupTexture, depthLookupCoordinate).st;
            lookupTextureCoordinate = (lookupTextureCoordinate * 2.0) - 1.0;
            
            vec2 textureCoordinateForAOLookup = ambientOcclusionTextureBase + ambientOcclusionTexturePatchWidth * lookupTextureCoordinate;
            float ambientOcclusionIntensity = texture2D(ambientOcclusionTexture, textureCoordinateForAOLookup).r;
            
//            float ambientOcclusionIntensity = 1.0;
            
            // Ambient lighting
            vec3 normal = vec3(impostorSpaceCoordinate, normalizedDepth);
            float ambientLightingIntensityFactor = clamp(dot(lightPosition, normal), 0.0, 1.0);
            
            float lightingIntensity = 0.2 + 1.7 * ambientLightingIntensityFactor * ambientOcclusionIntensity;
//            float lightingIntensity = 0.2 + 1.7 * precalculatedDepthAndLighting.g * ambientOcclusionIntensity;
            vec3 finalSphereColor = sphereColor * lightingIntensity;
            
            // Specular lighting
            float specularLightingIntensityFactor = pow(ambientLightingIntensityFactor, 60.0) * 0.6;
//            finalSphereColor = finalSphereColor + (precalculatedDepthAndLighting.b * ambientOcclusionIntensity);
            finalSphereColor = finalSphereColor + (specularLightingIntensityFactor * ambientOcclusionIntensity);
            
            gl_FragColor = vec4(finalSphereColor, 1.0);
//            gl_FragColor = vec4(texture2D(ambientOcclusionTexture, textureCoordinateForAOLookup).rgb, 1.0);
//            gl_FragColor = vec4(textureCoordinateForAOLookup, 0.0, 1.0);
            //    gl_FragColor = vec4(normalizedViewCoordinate, 1.0);
            //    gl_FragColor = vec4(precalculatedDepthAndLighting, 1.0);
        }
    }
}