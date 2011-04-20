//
//  Shader.vsh
//  CubeExample
//
//  Created by Brad Larson on 4/20/2010.
//

attribute vec4 position;
attribute vec2 inputImpostorSpaceCoordinate;
attribute vec4 direction;
attribute vec2 ambientOcclusionTextureOffset;

varying mediump vec2 impostorSpaceCoordinate;
varying mediump vec2 depthLookupCoordinate;
varying mediump vec3 normalizedStartingCoordinate;
varying mediump vec3 normalizedEndingCoordinate;
varying mediump float halfCylinderRadius;
varying mediump vec3 adjustmentForOrthographicProjection;
varying mediump float depthAdjustmentForOrthographicProjection;

uniform mediump mat4 modelViewProjMatrix;
uniform mediump float cylinderRadius;
uniform mediump mat4 orthographicMatrix;
uniform mediump float ambientOcclusionTexturePatchWidth;

void main()
{
    vec4 transformedStartingCoordinate, transformedEndingCoordinate;
    
    if (inputImpostorSpaceCoordinate.t < 0.0)
    {
        transformedStartingCoordinate = modelViewProjMatrix * position * orthographicMatrix;
        transformedEndingCoordinate = modelViewProjMatrix * (position + direction) * orthographicMatrix;
    }
    else
    {
        transformedStartingCoordinate = modelViewProjMatrix * (position - direction) * orthographicMatrix;
        transformedEndingCoordinate = modelViewProjMatrix * position * orthographicMatrix;
    }
    
    normalizedStartingCoordinate = (transformedStartingCoordinate.xyz + 1.0) / 2.0;
    normalizedEndingCoordinate = (transformedEndingCoordinate.xyz + 1.0) / 2.0;    
    
    impostorSpaceCoordinate = inputImpostorSpaceCoordinate.xy;
    depthLookupCoordinate = (inputImpostorSpaceCoordinate + 1.0) / 2.0;
    
    halfCylinderRadius = cylinderRadius * 0.5;
    
    adjustmentForOrthographicProjection = (vec4(1.0, 1.0, 1.0, 0.0) * orthographicMatrix).xyz;

    gl_Position = vec4(ambientOcclusionTextureOffset * 2.0 - vec2(1.0) + (ambientOcclusionTexturePatchWidth * depthLookupCoordinate * 2.0), 0.0, 1.0);
}
