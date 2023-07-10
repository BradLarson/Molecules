import Foundation

enum PDBFileError: Error {
    case emptyFile
    case missingResource
}

/// Parses a .pdb file in the format of the Protein Data Bank:
/// https://www.cgl.ucsf.edu/chimera/docs/UsersGuide/tutorials/pdbintro.html
struct PDBFile: MolecularStructure {
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

        var parsedAtoms: [Atom] = []
        var parsedBonds: [Bond] = []
        var globalAtomLookup: [Int: Atom] = [:]
        var statistics = MoleculeStatistics()

        let lines = fileContents.components(separatedBy: "\n")
        for line in lines {
            // Verify that we at least have a line identifier present.
            guard line.count >= 6 else { continue }

            let lineIdentifier = line.prefix(6).trimmingCharacters(in: .whitespacesAndNewlines)
            print("Identifier: |\(lineIdentifier)|")
            switch lineIdentifier {
            case "ATOM", "HETATM":
                // TODO: If ATOM, insert bonds for previous residue when switching residues.
                // Grab the X, Y, Z coordinates of the atom.
                guard line.count >= 54 else { continue }
                guard let xCoordinate = Float(line.whitespaceTrimmedString(from: 30, to: 38)),
                      let yCoordinate = Float(line.whitespaceTrimmedString(from: 38, to: 46)),
                      let zCoordinate = Float(line.whitespaceTrimmedString(from: 46, to: 54)) else {
                    continue
                }
                let atomCoordinate = Coordinate(x: xCoordinate, y: yCoordinate, z: zCoordinate)
                statistics.update(using: atomCoordinate)
                
                // Pull the atom's element, serial number, and identifiers within a residue.
                let atomSerialNumber = Int(line.whitespaceTrimmedString(from: 6, to: 12)) ?? -1
                
                let elementIdentifier: String
                if line.count < 78 {
                    elementIdentifier = line.whitespaceTrimmedString(from: 12, to: 14)
                    
                } else {
                    elementIdentifier = line.whitespaceTrimmedString(from: 76, to: 78)
                }
                let element = Atom.Element(code: elementIdentifier)
                let newAtom = Atom(element: element, location: atomCoordinate)
                parsedAtoms.append(newAtom)
                globalAtomLookup[atomSerialNumber] = newAtom
                
                print("Atom detected: \(newAtom)")
            case "TER": break
            case "CONECT":
                // TODO: Properly handle bidirectional bonds.
                guard line.count >= 11 else { continue }
                guard let firstAtomSerial = Int(line.whitespaceTrimmedString(from: 6, to: 11)),
                      firstAtomSerial > 0,
                      let firstAtom = globalAtomLookup[firstAtomSerial] else {
                    continue
                }
                guard line.count >= 16 else { continue }
                guard let secondAtomSerial = Int(line.whitespaceTrimmedString(from: 11, to: 16)),
                      secondAtomSerial > 0,
                      let secondAtom = globalAtomLookup[secondAtomSerial] else {
                    continue
                }
                let firstBond = Bond(strength: .single, start: firstAtom.location, end: secondAtom.location)
                parsedBonds.append(firstBond)
                print("Bond detected: \(firstBond)")
                guard line.count >= 21 else { continue }
                guard let thirdAtomSerial = Int(line.whitespaceTrimmedString(from: 16, to: 21)),
                      thirdAtomSerial > 0,
                      let thirdAtom = globalAtomLookup[thirdAtomSerial] else {
                    continue
                }
                let secondBond = Bond(strength: .single, start: firstAtom.location, end: thirdAtom.location)
                parsedBonds.append(secondBond)
                print("Bond detected: \(secondBond)")
                guard line.count >= 26 else { continue }
                guard let fourthAtomSerial = Int(line.whitespaceTrimmedString(from: 21, to: 26)),
                      fourthAtomSerial > 0,
                      let fourthAtom = globalAtomLookup[fourthAtomSerial] else {
                    continue
                }
                let thirdBond = Bond(strength: .single, start: firstAtom.location, end: fourthAtom.location)
                parsedBonds.append(thirdBond)
                print("Bond detected: \(thirdBond)")
                guard line.count >= 31 else { continue }
                guard let fifthAtomSerial = Int(line.whitespaceTrimmedString(from: 26, to: 31)),
                      fifthAtomSerial > 0,
                      let fifthAtom = globalAtomLookup[fifthAtomSerial] else {
                    continue
                }
                let fourthBond = Bond(strength: .single, start: firstAtom.location, end: fifthAtom.location)
                parsedBonds.append(fourthBond)
                print("Bond detected: \(fourthBond)")

            case "MODEL": break
            case "ENDMDL": break
            case "TITLE": break
            case "COMPND": break
            case "SOURCE": break
            case "AUTHOR": break
            case "JRNL": break
            case "SEQRES": break
            default: break
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

extension String {
    func whitespaceTrimmedString(from start: Int, to end: Int) -> String {
        let startIndex = self.index(self.startIndex, offsetBy: start)
        let endIndex = self.index(self.startIndex, offsetBy: end)
        return self[startIndex..<endIndex].trimmingCharacters(in: .whitespaces)
    }
}
