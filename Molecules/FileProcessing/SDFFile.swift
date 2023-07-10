import Foundation

/// Parses an .sdf file in the format used by PubChem:
/// https://en.wikipedia.org/wiki/Chemical_table_file
struct SDFFile: MolecularStructure {
    let atoms: [Atom]
    let bonds: [Bond]
    let centerOfMass: Coordinate
    let minimumLimits: Coordinate
    let maximumLimits: Coordinate
    let suggestedScaleFactor: Coordinate

    init(data: Data) throws {
        guard let fileContents = String(data: data, encoding: .utf8) else {
            throw PDBFileError.emptyFile
        }
        
        var statistics = MoleculeStatistics()

        var parsedAtoms: [Atom] = []
        var parsedBonds: [Bond] = []
        var stillCountingAtomsInFirstStructure = true
        var hasReachedAtoms = false
        var hasReachedBonds = false

        let lines = fileContents.components(separatedBy: "\n")
        for line in lines {
            if line.count > 67 {
                guard stillCountingAtomsInFirstStructure else { continue }
                if hasReachedBonds {
                    stillCountingAtomsInFirstStructure = false
                    continue
                }
                hasReachedAtoms = true
                guard let xCoordinate = Float(line.whitespaceTrimmedString(from: 0, to: 10)),
                      let yCoordinate = Float(line.whitespaceTrimmedString(from: 10, to: 20)),
                      let zCoordinate = Float(line.whitespaceTrimmedString(from: 20, to: 30)) else {
                    continue
                }
                let atomCoordinate = Coordinate(x: xCoordinate, y: yCoordinate, z: zCoordinate)
                statistics.update(using: atomCoordinate)
                let elementIdentifier = line.whitespaceTrimmedString(from: 31, to: 34)
                let element = Atom.Element(code: elementIdentifier)
                let newAtom = Atom(element: element, location: atomCoordinate)
                parsedAtoms.append(newAtom)
            } else if (line.count > 20) && hasReachedAtoms {
                guard stillCountingAtomsInFirstStructure else { continue }
                hasReachedBonds = true
                guard let firstAtomIndex = Int(line.whitespaceTrimmedString(from: 0, to: 3)),
                      let secondAtomIndex = Int(line.whitespaceTrimmedString(from: 3, to: 6)),
                      firstAtomIndex > 0,
                      secondAtomIndex > 0,
                      firstAtomIndex <= parsedAtoms.count,
                      secondAtomIndex <= parsedAtoms.count else {
                    continue
                }
                // TODO: Parse single, double bonds.
                let newBond = Bond(
                    strength: .single,
                    start: parsedAtoms[firstAtomIndex - 1].location,
                    end: parsedAtoms[secondAtomIndex - 1].location)
                parsedBonds.append(newBond)
            }
        }

        guard parsedAtoms.count > 0 else {
            throw PDBFileError.emptyFile
        }
        self.atoms = parsedAtoms
        self.bonds = parsedBonds
        self.centerOfMass = statistics.calculatedCenterOfMass(atomCount: parsedAtoms.count)
        self.minimumLimits = statistics.minimumLimits
        self.maximumLimits = statistics.maximumLimits
        self.suggestedScaleFactor = statistics.calculatedScaleFactor()
    }
}
