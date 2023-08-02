/// A basic representation of 3-D spatial coordinates for atoms and bonds.
struct Coordinate {
    let x: Float
    let y: Float
    let z: Float
}

extension Coordinate: AdditiveArithmetic {
    static func - (lhs: Coordinate, rhs: Coordinate) -> Coordinate {
        Coordinate(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    static func + (lhs: Coordinate, rhs: Coordinate) -> Coordinate {
        Coordinate(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    static var zero: Coordinate { Coordinate(x: 0.0, y: 0.0, z: 0.0) }
}

extension Coordinate {
    static func * (lhs: Coordinate, rhs: Float) -> Coordinate {
        Coordinate(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }

    static func * (lhs: Float, rhs: Coordinate) -> Coordinate {
        Coordinate(x: lhs * rhs.x, y: lhs * rhs.y, z: lhs * rhs.z)
    }
}
