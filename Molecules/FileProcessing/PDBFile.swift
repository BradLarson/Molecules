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
    let metadata: MolecularMetadata?
    let structureCount: Int

    init(data: Data) throws {
        guard let fileContents = String(data: data, encoding: .utf8) else {
            throw PDBFileError.emptyFile
        }

        var parsedAtoms: [Atom] = []
        var parsedBonds: [Bond] = []
        var globalAtomLookup: [Int: Atom] = [:]
        var statistics = MoleculeStatistics()
        var currentResidue = 1
        var currentResidueType: AminoAcidResidue?
        var currentResidueAtoms: [String: Atom] = [:]
        var previousTerminalAtom: Atom?
        var stillCountingAtomsInFirstStructure = true
        var numberOfStructures = 1
        var title = ""
        var source = ""
        var compound = ""
        var authors = ""
        var journalReference = ""
        var sequence = ""

        let lines = fileContents.components(separatedBy: "\n")
        for line in lines {
            // Verify that we at least have a line identifier present.
            guard line.count >= 6 else { continue }

            let lineIdentifier = line.prefix(6).trimmingCharacters(in: .whitespacesAndNewlines)
            switch lineIdentifier {
            case "ATOM", "HETATM":
                guard stillCountingAtomsInFirstStructure else { continue }
                // At the start of a new residue, generate all bonds for the previous one.
                if lineIdentifier == "ATOM" {
                    guard line.count >= 27 else { continue }
                    if let residueIdentifier = Int(line.whitespaceTrimmedString(from: 22, to: 27)),
                       currentResidue != residueIdentifier {
                        if let residueBonds = currentResidueType?.bonds(
                            residueAtoms: &currentResidueAtoms,
                            previousTerminalAtom: &previousTerminalAtom) {
                            parsedBonds.append(contentsOf: residueBonds)
                        }
                        currentResidue = residueIdentifier
                        currentResidueType = AminoAcidResidue(rawValue: line.whitespaceTrimmedString(from: 17, to: 20))
                        if currentResidueType == nil {
                            print("Unknown residue: \(line.whitespaceTrimmedString(from: 17, to: 20))")
                        }
                    }
                } else {
                    // Throw out water oxygens from biomolecule structures.
                    if line.whitespaceTrimmedString(from: 17, to: 20) == "HOH" {
                        continue
                    }
                    if let residueBonds = currentResidueType?.bonds(
                        residueAtoms: &currentResidueAtoms,
                        previousTerminalAtom: &previousTerminalAtom) {
                        parsedBonds.append(contentsOf: residueBonds)
                    }
                    currentResidueType = nil
                }
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
                if lineIdentifier == "ATOM" {
                    currentResidueAtoms[line.whitespaceTrimmedString(from: 12, to: 16)] = newAtom
                }
                parsedAtoms.append(newAtom)
                globalAtomLookup[atomSerialNumber] = newAtom
            case "TER":
                if let residueBonds = currentResidueType?.bonds(
                    residueAtoms: &currentResidueAtoms,
                    previousTerminalAtom: &previousTerminalAtom) {
                    parsedBonds.append(contentsOf: residueBonds)
                }
                currentResidueType = nil
                break
            case "CONECT":
                guard stillCountingAtomsInFirstStructure else { continue }
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
                guard line.count >= 21 else { continue }
                guard let thirdAtomSerial = Int(line.whitespaceTrimmedString(from: 16, to: 21)),
                      thirdAtomSerial > 0,
                      let thirdAtom = globalAtomLookup[thirdAtomSerial] else {
                    continue
                }
                let secondBond = Bond(strength: .single, start: firstAtom.location, end: thirdAtom.location)
                parsedBonds.append(secondBond)
                guard line.count >= 26 else { continue }
                guard let fourthAtomSerial = Int(line.whitespaceTrimmedString(from: 21, to: 26)),
                      fourthAtomSerial > 0,
                      let fourthAtom = globalAtomLookup[fourthAtomSerial] else {
                    continue
                }
                let thirdBond = Bond(strength: .single, start: firstAtom.location, end: fourthAtom.location)
                parsedBonds.append(thirdBond)
                guard line.count >= 31 else { continue }
                guard let fifthAtomSerial = Int(line.whitespaceTrimmedString(from: 26, to: 31)),
                      fifthAtomSerial > 0,
                      let fifthAtom = globalAtomLookup[fifthAtomSerial] else {
                    continue
                }
                let fourthBond = Bond(strength: .single, start: firstAtom.location, end: fifthAtom.location)
                parsedBonds.append(fourthBond)

            case "MODEL":
                guard line.count >= 16 else { continue }
                guard let currentStructureNumber = Int(line.whitespaceTrimmedString(from: 12, to: 16)) else {
                    continue
                }
                numberOfStructures = max(numberOfStructures, currentStructureNumber)
            case "ENDMDL":
                stillCountingAtomsInFirstStructure = false
            case "TITLE":
                guard line.count >= 10 else { continue }
                let titleLine = line.dropFirst(10)
                title += titleLine
            case "COMPND":
                guard line.count >= 20 else { continue }
                let compoundIdentifier = line.whitespaceTrimmedString(from: 10, to: 20)
                if compoundIdentifier == "MOLECULE:" {
                    compound = String(line.dropFirst(20))
                }
            case "SOURCE":
                guard line.count >= 10 else { continue }
                let sourceLine = line.dropFirst(10)
                source += sourceLine
            case "AUTHOR":
                guard line.count >= 10 else { continue }
                let authorLine = line.dropFirst(10)
                authors += authorLine
            case "JRNL":
                guard line.count >= 18 else { continue }
                let journalIdentifier = line.whitespaceTrimmedString(from: 12, to: 16)
                switch journalIdentifier {
                case "REF", "REFN":
                    let journalReferenceLine = line.dropFirst(18)
                    journalReference += journalReferenceLine
                    // TODO: Do something else with these journal fields.
                case "AUTH": break
                case "TITL": break
                default: break
                }
            case "SEQRES":
                guard line.count >= 14 else { continue }
                let sequenceLine = line.dropFirst(14)
                sequence += sequenceLine
            default: break
            }
        }
        guard parsedAtoms.count > 0 else {
            throw PDBFileError.emptyFile
        }
        if let residueBonds = currentResidueType?.bonds(
            residueAtoms: &currentResidueAtoms,
            previousTerminalAtom: &previousTerminalAtom) {
            parsedBonds.append(contentsOf: residueBonds)
        }
        currentResidueType = nil
        self.structureCount = numberOfStructures
        self.atoms = parsedAtoms
        self.bonds = parsedBonds
        self.centerOfMass = statistics.calculatedCenterOfMass(atomCount: parsedAtoms.count)
        self.minimumLimits = statistics.minimumLimits
        self.maximumLimits = statistics.maximumLimits
        self.suggestedScaleFactor = statistics.calculatedScaleFactor()
        self.metadata = MolecularMetadata(
            title: title,
            compound: compound,
            authors: authors,
            source: source,
            journal: journalReference,
            sequence: sequence)
    }
}

extension String {
    func whitespaceTrimmedString(from start: Int, to end: Int) -> String {
        let startIndex = self.index(self.startIndex, offsetBy: start)
        let endIndex = self.index(self.startIndex, offsetBy: end)
        return self[startIndex..<endIndex].trimmingCharacters(in: .whitespaces)
    }
}
