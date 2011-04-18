//
//  Shader.vsh
//  CubeExample
//
//  Created by Brad Larson on 4/20/2010.
//

attribute vec4 position;
attribute vec2 inputImpostorSpaceCoordinate;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump vec3 normalizedViewCoordinate;
varying mediump vec2 depthLookupCoordinate;

uniform mediump mat4 modelViewProjMatrix;
uniform mediump mat4 orthographicMatrix;
uniform mediump float sphereRadius;

void main()
{
    vec4 transformedPosition;
	transformedPosition = modelViewProjMatrix * position;
    impostorSpaceCoordinate = inputImpostorSpaceCoordinate.xy;
    depthLookupCoordinate = (inputImpostorSpaceCoordinate + 1.0) / 2.0;

    transformedPosition.xy = transformedPosition.xy + inputImpostorSpaceCoordinate.xy * vec2(sphereRadius);
    transformedPosition = transformedPosition * orthographicMatrix;
    
    normalizedViewCoordinate = (transformedPosition.xyz + 1.0) / 2.0;
    gl_Position = transformedPosition;
}
