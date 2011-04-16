attribute vec4 position;
attribute vec4 direction;
attribute vec4 inputImpostorSpaceCoordinate;

uniform mat4 modelViewProjMatrix;
uniform highp float cylinderRadius;
uniform mediump mat4 orthographicMatrix;

varying highp vec2 impostorSpaceCoordinate;
varying highp float depthOffsetAlongCenterAxis;
varying highp float normalizedDepthOffsetAlongCenterAxis;
varying highp float normalizedDisplacementAtEndCaps;
varying highp float normalizedRadialDisplacementAtEndCaps;
varying highp vec2 rotationFactor;
varying mediump vec3 normalizedViewCoordinate;

void main()
{
    vec4 transformedDirection, transformedPosition, transformedOtherPosition;
    vec3 viewDisplacementForVertex, displacementDirectionAtEndCap;
    float displacementAtEndCaps, lengthOfCylinder, lengthOfCylinderInView;
    
	transformedPosition = modelViewProjMatrix * position;
    transformedOtherPosition = modelViewProjMatrix * (position + direction);
    transformedDirection = transformedOtherPosition - transformedPosition;

    lengthOfCylinder = length(transformedDirection.xyz);
    lengthOfCylinderInView = length(transformedDirection.xy);
    rotationFactor = transformedDirection.xy / lengthOfCylinderInView;

    displacementAtEndCaps = cylinderRadius * (transformedOtherPosition.z - transformedPosition.z) / lengthOfCylinder;
    normalizedDisplacementAtEndCaps = displacementAtEndCaps / lengthOfCylinderInView;
    normalizedRadialDisplacementAtEndCaps = displacementAtEndCaps / cylinderRadius;
    
    depthOffsetAlongCenterAxis = cylinderRadius * 0.5 * lengthOfCylinder * inversesqrt(lengthOfCylinder * lengthOfCylinder - (transformedOtherPosition.z - transformedPosition.z) * (transformedOtherPosition.z - transformedPosition.z));
    depthOffsetAlongCenterAxis = clamp(depthOffsetAlongCenterAxis, 0.0, cylinderRadius);
    normalizedDepthOffsetAlongCenterAxis = depthOffsetAlongCenterAxis / (cylinderRadius * 0.5);
    
    displacementDirectionAtEndCap.xy = displacementAtEndCaps * rotationFactor;
    displacementDirectionAtEndCap.z = transformedDirection.z * displacementAtEndCaps / lengthOfCylinder;

    transformedDirection.xy = normalize(transformedDirection.xy);
    
    if ((displacementAtEndCaps * inputImpostorSpaceCoordinate.t) > 0.0)
    {
        viewDisplacementForVertex.x = inputImpostorSpaceCoordinate.x * transformedDirection.y * cylinderRadius + displacementDirectionAtEndCap.x;
        viewDisplacementForVertex.y = -inputImpostorSpaceCoordinate.x * transformedDirection.x * cylinderRadius + displacementDirectionAtEndCap.y;    
        viewDisplacementForVertex.z = displacementDirectionAtEndCap.z;
        impostorSpaceCoordinate = vec2(inputImpostorSpaceCoordinate.s, inputImpostorSpaceCoordinate.t + 1.0 * normalizedDisplacementAtEndCaps);
    }
    else
    {
        viewDisplacementForVertex.x = inputImpostorSpaceCoordinate.x * transformedDirection.y * cylinderRadius;
        viewDisplacementForVertex.y = -inputImpostorSpaceCoordinate.x * transformedDirection.x * cylinderRadius;    
        viewDisplacementForVertex.z = 0.0;
//        impostorSpaceCoordinate = inputImpostorSpaceCoordinate.st;
        impostorSpaceCoordinate = vec2(inputImpostorSpaceCoordinate.s, inputImpostorSpaceCoordinate.t);
    }
        
    transformedPosition.xyz = transformedPosition.xyz + viewDisplacementForVertex;
    //    transformedPosition.z = 0.0;
    
    transformedPosition *= orthographicMatrix;
    normalizedViewCoordinate = (transformedPosition.xyz + 1.0) / 2.0;
    gl_Position = transformedPosition;
//    gl_Position = transformedPosition;
//    impostorSpaceCoordinate = displacementDirectionAtEndCap / cylinderRadius;
}
