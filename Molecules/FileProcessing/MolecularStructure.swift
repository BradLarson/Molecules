import Foundation

/// All molecular file types need to conform to this protocol in order to be rendered.
protocol MolecularStructure {
    // TODO: Support multiple structures.
    var atoms: [Atom] { get }
    var bonds: [Bond] { get }
    var centerOfMass: Coordinate { get }
    var minimumLimits: Coordinate { get }
    var maximumLimits: Coordinate { get }
    var suggestedScaleFactor: Coordinate { get }

    var structureCount: Int { get }
    var metadata: MolecularMetadata? { get }

    init(data: Data) throws
}

extension MolecularStructure {
    var overallScaleFactor: Float {
        return min(suggestedScaleFactor.x, suggestedScaleFactor.y, suggestedScaleFactor.z)
    }

    var defaultVisualizationStyle: MoleculeVisualizationStyle {
        if (atoms.count < 600) && (bonds.count > 0) {
            return .ballAndStick
        } else {
            return .spacefilling
        }
    }
}


/// Protein Data Bank files contain a lot of structure and publication metadata.
struct MolecularMetadata {
    let title: String
    let compound: String
    let authors: String
    let source: String
    let journal: String
    let sequence: String
}

/// To aid in scaling and other rendering tasks, statistics of a molecule are captured during
/// parsing. This helps aggregate commonly-used operations in a shared data structure.
struct MoleculeStatistics {
    var minimumXPosition: Float = 1000.0
    var maximumXPosition: Float = 0.0
    var minimumYPosition: Float = 1000.0
    var maximumYPosition: Float = 0.0
    var minimumZPosition: Float = 1000.0
    var maximumZPosition: Float = 0.0
    var tallyForCenterOfMassInX: Float = 0.0
    var tallyForCenterOfMassInY: Float = 0.0
    var tallyForCenterOfMassInZ: Float = 0.0

    var minimumLimits: Coordinate {
        Coordinate(x: minimumXPosition, y: minimumYPosition, z: minimumZPosition)
    }

    var maximumLimits: Coordinate {
        Coordinate(x: maximumXPosition, y: maximumYPosition, z: maximumZPosition)
    }

    func calculatedCenterOfMass(atomCount: Int) -> Coordinate {
        return Coordinate(
            x: tallyForCenterOfMassInX / Float(atomCount),
            y: tallyForCenterOfMassInY / Float(atomCount),
            z: tallyForCenterOfMassInZ / Float(atomCount)
        )
    }

    mutating func update(using newCoordinate: Coordinate) {
        tallyForCenterOfMassInX += newCoordinate.x
        tallyForCenterOfMassInY += newCoordinate.y
        tallyForCenterOfMassInZ += newCoordinate.z
        minimumXPosition = min(minimumXPosition, newCoordinate.x)
        minimumYPosition = min(minimumYPosition, newCoordinate.y)
        minimumZPosition = min(minimumZPosition, newCoordinate.z)
        maximumXPosition = max(maximumXPosition, newCoordinate.x)
        maximumYPosition = max(maximumYPosition, newCoordinate.y)
        maximumZPosition = max(maximumZPosition, newCoordinate.z)
    }
    
    func calculatedScaleFactor() -> Coordinate {
        guard maximumXPosition > minimumXPosition,
              maximumYPosition > minimumYPosition,
              maximumZPosition > minimumZPosition else {
            return Coordinate(x: 1.0, y: 1.0, z: 1.0)
        }
        return Coordinate(x: 1.5 / (maximumXPosition - minimumXPosition),
                          y: 1.5 / (maximumYPosition - minimumYPosition),
                          z: (1.5 * 1.25) / (maximumZPosition - minimumZPosition)
        )
    }
}
