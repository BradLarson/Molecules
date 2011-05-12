precision mediump float;

uniform mediump vec3 sphereColor;
uniform sampler2D precalculatedSphereDepthTexture;
uniform sampler2D depthTexture;
uniform sampler2D ambientOcclusionTexture;
uniform mediump mat3 inverseModelViewProjMatrix;
uniform mediump float ambientOcclusionTexturePatchWidth;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump vec2 depthLookupCoordinate;
varying mediump vec3 normalizedViewCoordinate;
varying mediump vec2 ambientOcclusionTextureBase;
varying mediump float adjustedSphereRadius;

const mediump float oneThird = 1.0 / 3.0;

mediump float depthFromEncodedColor(mediump vec3 encodedColor)
{
    return (encodedColor.r + encodedColor.g + encodedColor.b) * oneThird;
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
    vec3 encodedColor = texture2D(depthTexture, normalizedViewCoordinate.xy).rgb;

    if (precalculatedDepthAndLighting.r < 0.05)
    {
        gl_FragColor = vec4(0.0);
    }
    else
    {
        float currentDepthValue = normalizedViewCoordinate.z - adjustedSphereRadius * precalculatedDepthAndLighting.r;        
        float previousDepthValue = depthFromEncodedColor(encodedColor);
      
        // Check to see that this fragment is the frontmost one for this area
  //      if ( (floor(currentDepthValue * 765.0)) > (ceil(previousDepthValue)) )
        if ( (currentDepthValue - 0.002) > (previousDepthValue) )
        {
            gl_FragColor = vec4(0.0);
        }
        else
        {            
            // Ambient occlusion factor
            vec3 aoNormal = vec3(impostorSpaceCoordinate, -precalculatedDepthAndLighting.r);
            aoNormal = inverseModelViewProjMatrix * aoNormal;
            aoNormal.z = -aoNormal.z;
                        
            // Test function inlining for profiling
            
             vec3 absoluteSphereSurfacePosition = abs(aoNormal);
   			 float d = absoluteSphereSurfacePosition.x + absoluteSphereSurfacePosition.y + absoluteSphereSurfacePosition.z;
    
    		vec2 lookupTextureCoordinate;
    		if (aoNormal.z <= 0.0)
    		{
    			lookupTextureCoordinate = aoNormal.xy / d;
    		}
    		else
    		{
    			vec2 theSign = aoNormal.xy / absoluteSphereSurfacePosition.xy;
    			//vec2 aSign = sign(aoNormal.xy);
    			lookupTextureCoordinate =  theSign  - absoluteSphereSurfacePosition.yx * (theSign / d); 
    		}
            
            // Test
            
           // vec2 lookupTextureCoordinate = textureCoordinateForSphereSurfacePosition(aoNormal);
            vec2 textureCoordinateForAOLookup = ambientOcclusionTextureBase + ambientOcclusionTexturePatchWidth * lookupTextureCoordinate;
            float ambientOcclusionIntensity = texture2D(ambientOcclusionTexture, textureCoordinateForAOLookup).r;
            
            // Ambient lighting
            float lightingIntensity = 0.2 + 1.7 * precalculatedDepthAndLighting.g * ambientOcclusionIntensity;
            vec3 finalSphereColor = sphereColor * lightingIntensity;
            
            // Specular lighting
            finalSphereColor = finalSphereColor + (precalculatedDepthAndLighting.b * ambientOcclusionIntensity);
            
            gl_FragColor = vec4(finalSphereColor, 1.0);
//            gl_FragColor = vec4(texture2D(ambientOcclusionTexture, textureCoordinateForAOLookup).rgb, 1.0);
//            gl_FragColor = vec4(textureCoordinateForAOLookup, 0.0, 1.0);
            //    gl_FragColor = vec4(normalizedViewCoordinate, 1.0);
            //    gl_FragColor = vec4(precalculatedDepthAndLighting, 1.0);
        }
    }
}