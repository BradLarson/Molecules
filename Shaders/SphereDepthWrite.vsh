attribute vec3 position;
attribute vec2 inputImpostorSpaceCoordinate;

uniform mediump mat3 modelViewProjMatrix;
uniform mediump float sphereRadius;
uniform mediump mat3 orthographicMatrix;
uniform mediump vec3 translation;

void main()
{
    vec3 transformedPosition = modelViewProjMatrix * (position + translation);
    vec2 insetRectangleCoordinate = normalize(inputImpostorSpaceCoordinate.xy);
//    mediump vec2 insetRectangleCoordinate = inputImpostorSpaceCoordinate.xy;
    
    transformedPosition.xy = transformedPosition.xy + insetRectangleCoordinate * vec2(sphereRadius);
    transformedPosition = transformedPosition * orthographicMatrix;
    
    gl_Position = vec4(transformedPosition, 1.0);
}
