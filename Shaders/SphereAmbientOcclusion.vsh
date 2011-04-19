//
//  Shader.vsh
//  CubeExample
//
//  Created by Brad Larson on 4/20/2010.
//

attribute vec4 position;
attribute vec2 inputImpostorSpaceCoordinate;
attribute vec2 ambientOcclusionTextureOffset;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump vec2 depthLookupCoordinate;
varying mediump vec3 normalizedViewCoordinate;
varying mediump float halfSphereRadius;
varying mediump vec3 adjustmentForOrthographicProjection;
varying mediump float depthAdjustmentForOrthographicProjection;

uniform mediump mat4 modelViewProjMatrix;
uniform mediump float sphereRadius;
uniform mediump mat4 orthographicMatrix;
uniform mediump float ambientOcclusionTexturePatchWidth;

void main()
{
    vec4 transformedPosition;
	transformedPosition = modelViewProjMatrix * position;
    impostorSpaceCoordinate = inputImpostorSpaceCoordinate.xy;
    depthLookupCoordinate = (inputImpostorSpaceCoordinate + 1.0) / 2.0;
    
    halfSphereRadius = sphereRadius * 0.5;
    
//    transformedPosition.xy = transformedPosition.xy + inputImpostorSpaceCoordinate.xy * vec2(sphereRadius);
    transformedPosition = transformedPosition * orthographicMatrix;
    
    adjustmentForOrthographicProjection = (vec4(1.0, 1.0, 1.0, 0.0) * orthographicMatrix).xyz;
    
    normalizedViewCoordinate = (transformedPosition.xyz + 1.0) / 2.0;
//    gl_Position = transformedPosition;
    gl_Position = vec4(ambientOcclusionTextureOffset * 2.0 - vec2(1.0) + (ambientOcclusionTexturePatchWidth * depthLookupCoordinate * 2.0), 0.0, 1.0);
}
