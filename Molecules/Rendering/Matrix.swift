import Foundation

// Originally from GPUImage3: https://github.com/BradLarson/GPUImage3

public struct Matrix4x4 {
    public let m11: Float, m12: Float, m13: Float, m14: Float
    public let m21: Float, m22: Float, m23: Float, m24: Float
    public let m31: Float, m32: Float, m33: Float, m34: Float
    public let m41: Float, m42: Float, m43: Float, m44: Float
    
    public init(rowMajorValues: [Float]) {
        guard rowMajorValues.count > 15 else {
            fatalError("Tried to initialize a 4x4 matrix with fewer than 16 values")
        }
        
        self.m11 = rowMajorValues[0]
        self.m12 = rowMajorValues[1]
        self.m13 = rowMajorValues[2]
        self.m14 = rowMajorValues[3]

        self.m21 = rowMajorValues[4]
        self.m22 = rowMajorValues[5]
        self.m23 = rowMajorValues[6]
        self.m24 = rowMajorValues[7]

        self.m31 = rowMajorValues[8]
        self.m32 = rowMajorValues[9]
        self.m33 = rowMajorValues[10]
        self.m34 = rowMajorValues[11]

        self.m41 = rowMajorValues[12]
        self.m42 = rowMajorValues[13]
        self.m43 = rowMajorValues[14]
        self.m44 = rowMajorValues[15]
    }
    
    public static let identity = Matrix4x4(rowMajorValues: [1.0, 0.0, 0.0, 0.0,
                                                            0.0, 1.0, 0.0, 0.0,
                                                            0.0, 0.0, 1.0, 0.0,
                                                            0.0, 0.0, 0.0, 1.0])
}

// MARK: -
// MARK: Convenience construction.

func orthographicMatrix(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float, anchorTopLeft: Bool = false) -> Matrix4x4 {
    let r_l = right - left
    let t_b = top - bottom
    let f_n = far - near
    var tx = -(right + left) / (right - left)
    var ty = -(top + bottom) / (top - bottom)
    let tz = -(far + near) / (far - near)
    
    let scale: Float
    if (anchorTopLeft) {
        scale = 4.0
        tx = -1.0
        ty = -1.0
    } else {
        scale = 2.0
    }
    
    return Matrix4x4(rowMajorValues: [
        scale / r_l, 0.0, 0.0, tx,
        0.0, scale / t_b, 0.0, ty,
        0.0, 0.0, scale / f_n, tz,
        0.0, 0.0, 0.0, 1.0])
}

// MARK: -
// MARK: Matrix manipulation.

extension Matrix4x4 {
    /// Rotates a matrix by a specified angle about an axis.
    /// - Parameters:
    ///   - angle: The rotation angle, in radians.
    ///   - x: The x component of the axis of rotation.
    ///   - y: The y component of the axis of rotation.
    ///   - z: The z component of the axis of rotation.
    func rotated(angle: Float, x: Float, y: Float, z: Float) -> Matrix4x4 {
        let distance = sqrt(x * x + y * y + z * z)
        guard distance > 0 else { return self }

        let normalizedX = -x / distance
        let normalizedY = -y / distance
        let normalizedZ = -z / distance

        let rotation = Matrix4x4(rowMajorValues: [
            cos(angle) + normalizedX * normalizedX * (1 - cos(angle)),
            normalizedX * normalizedY * (1 - cos(angle)) - normalizedZ * sin(angle),
            normalizedX * normalizedZ * (1 - cos(angle)) + normalizedY * sin(angle),
            0,

            normalizedY * normalizedX * (1 - cos(angle)) + normalizedZ * sin(angle),
            cos(angle) + normalizedY * normalizedY * (1 - cos(angle)),
            normalizedY * normalizedZ * (1 - cos(angle)) - normalizedX * sin(angle),
            0,

            normalizedZ * normalizedX * (1 - cos(angle)) - normalizedY * sin(angle),
            normalizedZ * normalizedY * (1 - cos(angle)) + normalizedX * sin(angle),
            cos(angle) + normalizedZ * normalizedZ * (1 - cos(angle)),
            0,

            0, 0, 0, 1
        ])

        return rotation * self
    }

    /// Scales a matrix by specified factors in each dimension.
    /// - Parameters:
    ///   - x: The scale factor to apply in the x dimension.
    ///   - y: The scale factor to apply in the y dimension.
    ///   - z: The scale factor to apply in the z dimension.
    func scaled(x: Float, y: Float, z: Float) -> Matrix4x4 {
        return Matrix4x4(rowMajorValues: [
            m11 * x, m12 * x, m13 * x, m14 * x,
            m21 * y, m22 * y, m23 * y, m24 * y,
            m31 * z, m32 * z, m33 * z, m34 * z,
            m41,     m42,     m43,     m44
        ])
    }

    /// Returns the current scale factor.
    var scale: Float {
        return sqrt(pow(m11, 2.0) + pow(m12, 2.0) + pow(m13, 2.0))
    }

    /// Inverts the matrix. Assumes coordinate transform matrix. Not totally valid.
    func inverted() -> Matrix4x4 {
        return Matrix4x4(rowMajorValues: [
            m11, m21, m31, -(m11 * m14 + m21 * m24 + m31 * m34),
            m12, m22, m32, -(m12 * m24 + m22 * m24 + m32 * m34),
            m13, m23, m33, -(m13 * m24 + m23 * m24 + m33 * m34),
            m41, m42, m43, m44
        ])
    }

    static func * (lhs: Matrix4x4, rhs: Matrix4x4) -> Matrix4x4 {
        Matrix4x4(rowMajorValues: [
            lhs.m11 * rhs.m11 + lhs.m12 * rhs.m21 + lhs.m13 * rhs.m31 + lhs.m14 * rhs.m41,
            lhs.m11 * rhs.m12 + lhs.m12 * rhs.m22 + lhs.m13 * rhs.m32 + lhs.m14 * rhs.m42,
            lhs.m11 * rhs.m13 + lhs.m12 * rhs.m23 + lhs.m13 * rhs.m33 + lhs.m14 * rhs.m43,
            lhs.m11 * rhs.m14 + lhs.m12 * rhs.m24 + lhs.m13 * rhs.m34 + lhs.m14 * rhs.m44,

            lhs.m21 * rhs.m11 + lhs.m22 * rhs.m21 + lhs.m23 * rhs.m31 + lhs.m24 * rhs.m41,
            lhs.m21 * rhs.m12 + lhs.m22 * rhs.m22 + lhs.m23 * rhs.m32 + lhs.m24 * rhs.m42,
            lhs.m21 * rhs.m13 + lhs.m22 * rhs.m23 + lhs.m23 * rhs.m33 + lhs.m24 * rhs.m43,
            lhs.m21 * rhs.m14 + lhs.m22 * rhs.m24 + lhs.m23 * rhs.m34 + lhs.m24 * rhs.m44,

            lhs.m31 * rhs.m11 + lhs.m32 * rhs.m21 + lhs.m33 * rhs.m31 + lhs.m34 * rhs.m41,
            lhs.m31 * rhs.m12 + lhs.m32 * rhs.m22 + lhs.m33 * rhs.m32 + lhs.m34 * rhs.m42,
            lhs.m31 * rhs.m13 + lhs.m32 * rhs.m23 + lhs.m33 * rhs.m33 + lhs.m34 * rhs.m43,
            lhs.m31 * rhs.m14 + lhs.m32 * rhs.m24 + lhs.m33 * rhs.m34 + lhs.m34 * rhs.m44,

            lhs.m41 * rhs.m11 + lhs.m42 * rhs.m21 + lhs.m43 * rhs.m31 + lhs.m44 * rhs.m41,
            lhs.m41 * rhs.m12 + lhs.m42 * rhs.m22 + lhs.m43 * rhs.m32 + lhs.m44 * rhs.m42,
            lhs.m41 * rhs.m13 + lhs.m42 * rhs.m23 + lhs.m43 * rhs.m33 + lhs.m44 * rhs.m43,
            lhs.m41 * rhs.m14 + lhs.m42 * rhs.m24 + lhs.m43 * rhs.m34 + lhs.m44 * rhs.m44,
        ])
    }
}

// MARK: -
// MARK: Matrix touch manipulation.

extension Matrix4x4 {
    func rotatedFromTouch(x: Float, y: Float) -> Matrix4x4 {
        let totalRotation = sqrt(x * x + y * y)

        return self.rotated(angle: totalRotation * .pi / 180.0,
                            x: ((x / totalRotation) * m12 + (y / totalRotation) * m11),
                            y: ((x / totalRotation) * m22 + (y / totalRotation) * m21),
                            z: ((x / totalRotation) * m32 + (y / totalRotation) * m31))
    }

    func scaledFromTouch(scale: Float) -> Matrix4x4 {
        return self.scaled(x: scale, y: scale, z: scale)
    }

    func translatedFromTouch(currentTranslation: Coordinate, x: Float, y: Float, backingWidth: Float) -> Coordinate {
        let currentScaleFactor = self.scale

        let xTranslation = x * 1.0 / (currentScaleFactor * currentScaleFactor * backingWidth * 0.5)
        let yTranslation = y * 1.0 / (currentScaleFactor * currentScaleFactor * backingWidth * 0.5)

        // Use the (0,4,8) components to figure the eye's X axis in the model coordinate system, translate along that
        // Use the (1,5,9) components to figure the eye's Y axis in the model coordinate system, translate along that

        return Coordinate(
            x: currentTranslation.x + xTranslation * m11 + yTranslation * m12,
            y: currentTranslation.y + xTranslation * m21 + yTranslation * m22,
            z: currentTranslation.z + xTranslation * m31 + yTranslation * m32
        )
    }
}

// MARK: -
// MARK: Encoding to buffers.

extension Matrix4x4 {
    public func toFloatArray() -> [Float] {
        // Row major
        return [m11, m12, m13, m14, m21, m22, m23, m24, m31, m32, m33, m34, m41, m42, m43, m44]
    }
}
