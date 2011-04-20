precision mediump float;

uniform sampler2D depthTexture;
uniform mediump mat4 modelViewProjMatrix;
uniform mediump mat4 inverseModelViewProjMatrix;
uniform mediump float intensityFactor;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump vec2 depthLookupCoordinate;
varying mediump vec3 normalizedViewCoordinate;
varying mediump float halfSphereRadius;
varying mediump vec3 adjustmentForOrthographicProjection;

const mediump float oneThird = 1.0 / 3.0;

mediump float depthFromEncodedColor(mediump vec4 encodedColor)
{
    return oneThird * (encodedColor.r + encodedColor.g + encodedColor.b);
    //    return encodedColor.r;
}

mediump vec3 coordinateFromTexturePosition(mediump vec2 texturePosition)
{
    vec2 absoluteTexturePosition = abs(texturePosition);
    float h = 1.0 - absoluteTexturePosition.s - absoluteTexturePosition.t;
    
    if (h >= 0.0)
    {
        return vec3(texturePosition.s, texturePosition.t, h);
    }
    else
    {
        return vec3(sign(texturePosition.s) * (1.0 - absoluteTexturePosition.t), sign(texturePosition.t) * (1.0 - absoluteTexturePosition.s), h);
    }
    
}

void main()
{
    vec3 currentSphereSurfaceCoordinate = coordinateFromTexturePosition(impostorSpaceCoordinate);
//    currentSphereSurfaceCoordinate.z = -currentSphereSurfaceCoordinate.z;
//    currentSphereSurfaceCoordinate = (inverseModelViewProjMatrix * vec4(currentSphereSurfaceCoordinate, 0.0)).xyz;
//    currentSphereSurfaceCoordinate.z = -currentSphereSurfaceCoordinate.z;

    
//    currentSphereSurfaceCoordinate.z = -currentSphereSurfaceCoordinate.z;
    currentSphereSurfaceCoordinate = normalize((modelViewProjMatrix * vec4(currentSphereSurfaceCoordinate, 0.0)).xyz);
//    currentSphereSurfaceCoordinate.z = -currentSphereSurfaceCoordinate.z;
     
    vec3 currentPositionCoordinate = normalizedViewCoordinate + halfSphereRadius * currentSphereSurfaceCoordinate * adjustmentForOrthographicProjection;
//    vec3 currentPositionCoordinate = normalizedViewCoordinate + halfSphereRadius * vec3(impostorSpaceCoordinate, 0.0) * vec3(radiusAdjustment, 1.0);
//    currentPositionCoordinate = (vec4(currentPositionCoordinate, 0.0) * orthographicMatrix).xyz;
    
                                                                 
    float previousDepthValue = depthFromEncodedColor(texture2D(depthTexture, currentPositionCoordinate.xy));

//    gl_FragColor = vec4(texture2D(depthTexture, currentPositionCoordinate.xy).rgb, 1.0);

//    gl_FragColor = vec4(currentSphereSurfaceCoordinate, 1.0);

    if ( (floor(currentPositionCoordinate.z * 765.0) - 1.0) <= (ceil(previousDepthValue * 765.0)) )
    {
//        gl_FragColor = vec4(vec3(previousDepthValue - currentPositionCoordinate.z), 1.0);
//        gl_FragColor = vec4(normalizedViewCoordinate, 1.0);
        gl_FragColor = vec4(vec3(intensityFactor), 1.0);
    }
    else
    {
        gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
    }
     
    
//    gl_FragColor = vec4(currentSphereSurfaceCoordinate, 1.0);
}