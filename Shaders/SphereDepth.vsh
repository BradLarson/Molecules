//
//  Shader.vsh
//  CubeExample
//
//  Created by Brad Larson on 4/20/2010.
//

attribute vec4 position;
attribute vec4 inputImpostorSpaceCoordinate;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump float normalizedDepth;

uniform mat4 modelViewProjMatrix;
uniform mediump float sphereRadius;
uniform mediump mat4 orthographicMatrix;

void main()
{
    vec4 transformedPosition;
	transformedPosition = modelViewProjMatrix * position;
    impostorSpaceCoordinate = inputImpostorSpaceCoordinate.xy;
    
    transformedPosition.xy = transformedPosition.xy + inputImpostorSpaceCoordinate.xy * vec2(sphereRadius);
    transformedPosition = transformedPosition * orthographicMatrix;

    normalizedDepth = (transformedPosition.z + 1.0) / 2.0;
    gl_Position = transformedPosition;
}
