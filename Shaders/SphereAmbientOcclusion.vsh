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
varying mediump float adjustedSphereRadius;
varying mediump vec3 adjustmentForOrthographicProjection;
varying mediump float depthAdjustmentForOrthographicProjection;

uniform mediump mat4 modelViewProjMatrix;
uniform mediump float sphereRadius;
uniform mediump mat4 orthographicMatrix;
uniform mediump float ambientOcclusionTexturePatchWidth;

void main()
{
	vec4 transformedPosition = modelViewProjMatrix * position;
    impostorSpaceCoordinate = inputImpostorSpaceCoordinate.xy;
    depthLookupCoordinate = (inputImpostorSpaceCoordinate + 1.0) / 2.0;
    
    adjustedSphereRadius = sphereRadius;
    
    transformedPosition = transformedPosition * orthographicMatrix;
    
    adjustmentForOrthographicProjection = (vec4(0.5, 0.5, 1.0, 0.0) * orthographicMatrix).xyz;
    
    normalizedViewCoordinate.xy = (transformedPosition.xy + 1.0) / 2.0;
    normalizedViewCoordinate.z = transformedPosition.z + 1.0;

    gl_Position = vec4(ambientOcclusionTextureOffset * 2.0 - vec2(1.0) + (ambientOcclusionTexturePatchWidth * depthLookupCoordinate * 2.0), 0.0, 1.0);
}
