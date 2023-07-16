import Foundation

/// Parses an .xyz atom coordinate file.
struct XYZFile: MolecularStructure {
    let atoms: [Atom]
    let bonds: [Bond] = []
    let centerOfMass: Coordinate
    let minimumLimits: Coordinate
    let maximumLimits: Coordinate
    let suggestedScaleFactor: Coordinate
    let metadata: MolecularMetadata? = nil
    let structureCount: Int = 1

    init(data: Data) throws {
        guard let fileContents = String(data: data, encoding: .utf8) else {
            throw PDBFileError.emptyFile
        }
        
        var parsedAtoms: [Atom] = []
        var statistics = MoleculeStatistics()

        let lines = fileContents.components(separatedBy: "\n")
        for line in lines {
            let lineComponents = line.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
            guard lineComponents.count >= 4 else { continue }

            let element: Atom.Element
            if let xyzCode = Int(lineComponents[0]) {
                element = Atom.Element(xyzCode: xyzCode)
            } else {
                element = Atom.Element(code: lineComponents[0])
            }
            guard element != .unknown else { continue }
            
            guard let xCoordinate = Float(lineComponents[1]),
                  let yCoordinate = Float(lineComponents[2]),
                  let zCoordinate = Float(lineComponents[3]) else {
                continue
            }
            let atomCoordinate = Coordinate(x: xCoordinate, y: yCoordinate, z: zCoordinate)
            statistics.update(using: atomCoordinate)
            let newAtom = Atom(element: element, location: atomCoordinate)
            parsedAtoms.append(newAtom)
        }
        guard parsedAtoms.count > 0 else {
            throw PDBFileError.emptyFile
        }
        self.atoms = parsedAtoms
        self.centerOfMass = statistics.calculatedCenterOfMass(atomCount: parsedAtoms.count)
        self.minimumLimits = statistics.minimumLimits
        self.maximumLimits = statistics.maximumLimits
        self.suggestedScaleFactor = statistics.calculatedScaleFactor()
    }
}

extension Atom.Element {
    init(xyzCode: Int) {
        switch xyzCode {
        case 1: self = .hydrogen
        case 6: self = .carbon
        case 7: self = .nitrogen
        case 8: self = .oxygen
        case 9: self = .fluorine
        case 11: self = .sodium
        case 12: self = .magnesium
        case 14: self = .silicon
        case 15: self = .phosphorous
        case 16: self = .sulfur
        case 17: self = .chlorine
        case 20: self = .calcium
        case 26: self = .iron
        case 30: self = .zinc
        case 35: self = .bromine
        case 48: self = .cadmium
        case 53: self = .iodine
        default: self = .unknown
        }
    }
}
