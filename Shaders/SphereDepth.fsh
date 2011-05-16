precision mediump float;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump float normalizedDepth;
varying mediump float adjustedSphereRadius;

//const vec3 stepValues = vec3(510.0, 255.0, 0.0);
const vec3 stepValues = vec3(2.0, 1.0, 0.0);
const float scaleDownFactor = 1.0 / 255.0;

void main()
{
//    gl_FragColor = vec4(normalizedDepth * (impostorSpaceCoordinate + 1.0) / 2.0, normalizedDepth, 1.0);
  
    float distanceFromCenter = length(impostorSpaceCoordinate);
    if (distanceFromCenter > 1.0)
    {
        gl_FragColor = vec4(1.0);
    }
    else
    {
        float calculatedDepth = sqrt(1.0 - distanceFromCenter * distanceFromCenter);
        mediump float currentDepthValue = normalizedDepth - adjustedSphereRadius * calculatedDepth;
        
        // Inlined color encoding for the depth values
        float ceiledValue = ceil(currentDepthValue * 765.0);
        
        vec3 intDepthValue = (vec3(ceiledValue) * scaleDownFactor) - stepValues;
        
        gl_FragColor = vec4(intDepthValue, 1.0);
    }
}