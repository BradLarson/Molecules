precision mediump float;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump float normalizedDepth;
varying mediump float adjustedSphereRadius;

const vec3 stepValues = vec3(510.0, 255.0, 0.0);
const float scaleDownFactor = 1.0 / 255.0;

mediump vec4 encodedColorForDepth(float depthValue)
{
    vec3 intDepthValue = vec3(ceil(depthValue * 765.0));
    
    intDepthValue = intDepthValue * scaleDownFactor - (stepValues * scaleDownFactor);
    return vec4(clamp(intDepthValue, 0.0, 1.0), 1.0);
}

void main()
{
//    gl_FragColor = vec4(1.0);
    
    float distanceFromCenter = length(impostorSpaceCoordinate);
    if (distanceFromCenter > 1.0)
    {
        gl_FragColor = vec4(1.0);        
    }
    else
    {
        float precalculatedDepth = sqrt(1.0 - distanceFromCenter * distanceFromCenter);
        mediump float currentDepthValue = normalizedDepth - adjustedSphereRadius * precalculatedDepth;
        
        gl_FragColor = encodedColorForDepth(currentDepthValue);
        
    }
}