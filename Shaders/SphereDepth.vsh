//
//  Shader.vsh
//  CubeExample
//
//  Created by Brad Larson on 4/20/2010.
//

attribute vec4 position;
attribute vec2 inputImpostorSpaceCoordinate;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump vec2 depthLookupCoordinate;
varying mediump float normalizedDepth;
varying mediump float halfSphereRadius;
varying mediump float depthAdjustmentForOrthographicProjection;

uniform mediump mat4 modelViewProjMatrix;
uniform mediump float sphereRadius;
uniform mediump mat4 orthographicMatrix;

void main()
{
    vec4 transformedPosition;
	transformedPosition = modelViewProjMatrix * position;
    impostorSpaceCoordinate = inputImpostorSpaceCoordinate.xy;
    depthLookupCoordinate = (inputImpostorSpaceCoordinate + 1.0) / 2.0;
    
    halfSphereRadius = sphereRadius * 0.5;
    
    transformedPosition.xy = transformedPosition.xy + inputImpostorSpaceCoordinate.xy * vec2(sphereRadius);
    transformedPosition = transformedPosition * orthographicMatrix;

    depthAdjustmentForOrthographicProjection = (vec4(0.0, 0.0, 1.0, 0.0) * orthographicMatrix).z;
    
    normalizedDepth = (transformedPosition.z + 1.0) / 2.0;
    gl_Position = transformedPosition;
}
