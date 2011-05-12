precision mediump float;

uniform sampler2D precalculatedSphereDepthTexture;
uniform mediump mat3 inverseModelViewProjMatrix;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump vec2 depthLookupCoordinate;

void main()
{
    float precalculatedDepth = texture2D(precalculatedSphereDepthTexture, depthLookupCoordinate).r;

    if (precalculatedDepth < 0.05)
    {
        gl_FragColor = vec4(0.0);
    }
    else
    {
        // Ambient occlusion factor
        vec3 aoNormal = vec3(impostorSpaceCoordinate, -precalculatedDepth);
        aoNormal = inverseModelViewProjMatrix * aoNormal;
        aoNormal.z = -aoNormal.z;
                        
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
            
        gl_FragColor = vec4((lookupTextureCoordinate / 2.0) + 0.5, 0.0, 1.0);
    }
}