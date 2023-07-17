/// Despite the name, this handles both amino acid residues and nucleic acid residues as present
/// in PDB files.
enum AminoAcidResidue: String {
    // Amino acids
    case glycine = "GLY"
    case alanine = "ALA"
    case valine = "VAL"
    case leucine = "LEU"
    case isoleucine = "ILE"
    case serine = "SER"
    case cysteine = "CYS"
    case threonine = "THR"
    case methionine = "MET"
    case proline = "PRO"
    case phenylalanine = "PHE"
    case tyrosine = "TYR"
    case tryptophan = "TRP"
    case histidine = "HIS"
    case lysine = "LYS"
    case arginine = "ARG"
    case asparticAcid = "ASP"
    case glutamicAcid = "GLU"
    case asparagine = "ASN"
    case glutamine = "GLN"

    // RNA
    case adenine = "A"
    case cytosine = "C"
    case guanine = "G"
    case uracil = "U"

    // DNA
    case deoxyadenine = "DA"
    case deoxycytosine = "DC"
    case deoxyguanine = "DG"
    case deoxythymine = "DT"
}

extension AminoAcidResidue {
    func bonds(residueAtoms: inout [String: Atom], previousTerminalAtom: inout Atom?) -> [Bond] {
        var residueBonds: [Bond] = []

        func addBond(from: String, to: String) {
            if let firstAtom = residueAtoms[from],
               let secondAtom = residueAtoms[to] {
                residueBonds.append(Bond(strength: .single, start: firstAtom.location, end: secondAtom.location))
            }
        }

        // First, common bonds for groupings of residues.
        switch self {
        // Amino acids
        case .glycine, .alanine, .valine, .leucine, .isoleucine, .serine, .cysteine, .threonine,
                .methionine, .proline, .phenylalanine, .tyrosine, .tryptophan, .histidine, .lysine,
                .arginine, .asparticAcid, .glutamicAcid, .asparagine, .glutamine:
            addBond(from: "N", to: "CA")
            addBond(from: "CA", to: "C")
            addBond(from: "C", to: "O")

            // Add the peptide bond.
            if let terminalAtom = previousTerminalAtom,
               let secondAtom = residueAtoms["N"] {
                residueBonds.append(Bond(strength: .single, start: terminalAtom.location, end: secondAtom.location))
            }
            previousTerminalAtom = residueAtoms["C"]

        // RNA
        case .adenine, .cytosine, .guanine, .uracil:
            addBond(from: "C2'", to: "O2'")

        // DNA
        case .deoxyadenine, .deoxycytosine, .deoxyguanine, .deoxythymine:
            // P -> O3' (Starts from 3' end, so no P in first nucleotide).
            addBond(from: "P", to: "OP1")
            addBond(from: "P", to: "OP2")
            addBond(from: "P", to: "O5'")
            addBond(from: "O5'", to: "C5'")
            addBond(from: "C5'", to: "C4'")
            addBond(from: "C4'", to: "O4'")
            addBond(from: "C4'", to: "C3'")
            addBond(from: "C3'", to: "O3'")
            addBond(from: "O4'", to: "C1'")
            addBond(from: "C3'", to: "C2'")
            addBond(from: "C2'", to: "C1'")

            // Link the nucleotides together.
            if let terminalAtom = previousTerminalAtom,
               let secondAtom = residueAtoms["P"] {
                residueBonds.append(Bond(strength: .single, start: terminalAtom.location, end: secondAtom.location))
            }
            previousTerminalAtom = residueAtoms["O3'"]
        }

        // Then, all residue-specific bonds.
        switch self {
            // Amino acids
        case .alanine:
            addBond(from: "CA", to: "CB")
        case .valine:
            addBond(from: "CA", to: "CB")
            addBond(from: "CB", to: "CG1")
            addBond(from: "CB", to: "CG2")
        case .leucine:
            addBond(from: "CA", to: "CB")
            addBond(from: "CB", to: "CG")
            addBond(from: "CG", to: "CD1")
            addBond(from: "CG", to: "CD2")
        case .isoleucine:
            addBond(from: "CA", to: "CB")
            addBond(from: "CB", to: "CG1")
            addBond(from: "CB", to: "CG2")
            addBond(from: "CG1", to: "CD1")
        case .serine:
            addBond(from: "CA", to: "CB")
            addBond(from: "CB", to: "OG")
        case .cysteine:
            addBond(from: "CA", to: "CB")
            addBond(from: "CB", to: "SG")
        case .threonine:
            addBond(from: "CA", to: "CB")
            addBond(from: "CB", to: "OG1")
            addBond(from: "CB", to: "CG2")
        case .methionine:
            addBond(from: "CA", to: "CB")
            addBond(from: "CB", to: "CG")
            addBond(from: "CG", to: "SD")
            addBond(from: "SD", to: "CE")
        case .proline:
            addBond(from: "CA", to: "CB")
            addBond(from: "CB", to: "CG")
            addBond(from: "CG", to: "CD")
            addBond(from: "CD", to: "N")
        case .phenylalanine:
            addBond(from: "CA", to: "CB")
            addBond(from: "CB", to: "CG")
            addBond(from: "CG", to: "CD1")
            addBond(from: "CG", to: "CD2")
            addBond(from: "CD1", to: "CE1")
            addBond(from: "CD2", to: "CE2")
            addBond(from: "CE1", to: "CZ")
            addBond(from: "CE2", to: "CZ")
        case .tyrosine:
            addBond(from: "CA", to: "CB")
            addBond(from: "CB", to: "CG")
            addBond(from: "CG", to: "CD1")
            addBond(from: "CG", to: "CD2")
            addBond(from: "CD1", to: "CE1")
            addBond(from: "CD2", to: "CE2")
            addBond(from: "CE1", to: "CZ")
            addBond(from: "CE2", to: "CZ")
            addBond(from: "CZ", to: "OH")
        case .tryptophan:
            addBond(from: "CA", to: "CB")
            addBond(from: "CB", to: "CG")
            addBond(from: "CG", to: "CD1")
            addBond(from: "CG", to: "CD2")
            addBond(from: "CD1", to: "NE1")
            addBond(from: "CD2", to: "CE2")
            addBond(from: "NE1", to: "CE2")
            addBond(from: "CE2", to: "CZ2")
            addBond(from: "CZ2", to: "CH2")
            addBond(from: "CH2", to: "CZ3")
            addBond(from: "CZ3", to: "CE3")
            addBond(from: "CE3", to: "CD2")
        case .histidine:
            addBond(from: "CA", to: "CB")
            addBond(from: "CB", to: "CG")
            addBond(from: "CG", to: "ND1")
            addBond(from: "CG", to: "CD2")
            addBond(from: "ND1", to: "CE1")
            addBond(from: "CD2", to: "NE2")
            addBond(from: "CE1", to: "NE2")
        case .lysine:
            addBond(from: "CA", to: "CB")
            addBond(from: "CB", to: "CG")
            addBond(from: "CG", to: "CD")
            addBond(from: "CD", to: "CE")
            addBond(from: "CE", to: "NZ")
        case .arginine:
            addBond(from: "CA", to: "CB")
            addBond(from: "CB", to: "CG")
            addBond(from: "CG", to: "CD")
            addBond(from: "CD", to: "NE")
            addBond(from: "NE", to: "CZ")
            addBond(from: "CZ", to: "NH1")
            addBond(from: "CZ", to: "NH2")
        case .asparticAcid:
            addBond(from: "CA", to: "CB")
            addBond(from: "CB", to: "CG")
            addBond(from: "CG", to: "OD1")
            addBond(from: "CG", to: "OD2")
        case .glutamicAcid:
            addBond(from: "CA", to: "CB")
            addBond(from: "CB", to: "CG")
            addBond(from: "CG", to: "CD")
            addBond(from: "CD", to: "OE1")
            addBond(from: "CD", to: "OE2")
        case .asparagine:
            addBond(from: "CA", to: "CB")
            addBond(from: "CB", to: "CG")
            addBond(from: "CG", to: "OD1")
            addBond(from: "CG", to: "ND2")
        case .glutamine:
            addBond(from: "CA", to: "CB")
            addBond(from: "CB", to: "CG")
            addBond(from: "CG", to: "CD")
            addBond(from: "CD", to: "OE1")
            addBond(from: "CD", to: "NE2")
        case .glycine:
            break

        // Nucleic acids
        case .adenine, .deoxyadenine:
            addBond(from: "C1'", to: "N9")
            addBond(from: "N9", to: "C4")
            addBond(from: "C4", to: "N3")
            addBond(from: "N3", to: "C2")
            addBond(from: "C2", to: "N1")
            addBond(from: "N1", to: "C6")
            addBond(from: "C6", to: "N6")
            addBond(from: "C6", to: "C5")
            addBond(from: "C5", to: "C4")
            addBond(from: "C5", to: "N7")
            addBond(from: "N7", to: "C8")
            addBond(from: "C8", to: "N9")
        case .cytosine, .deoxycytosine:
            addBond(from: "C1'", to: "N1")
            addBond(from: "N1", to: "C2")
            addBond(from: "C2", to: "O2")
            addBond(from: "C2", to: "N3")
            addBond(from: "N3", to: "C4")
            addBond(from: "C4", to: "N4")
            addBond(from: "C4", to: "C5")
            addBond(from: "C5", to: "C6")
            addBond(from: "C6", to: "N1")
        case .guanine, .deoxyguanine:
            addBond(from: "C1'", to: "N9")
            addBond(from: "N9", to: "C4")
            addBond(from: "C4", to: "N3")
            addBond(from: "N3", to: "C2")
            addBond(from: "C2", to: "N2")
            addBond(from: "C2", to: "N1")
            addBond(from: "N1", to: "C6")
            addBond(from: "C6", to: "O6")
            addBond(from: "C6", to: "C5")
            addBond(from: "C5", to: "C4")
            addBond(from: "C5", to: "N7")
            addBond(from: "N7", to: "C8")
            addBond(from: "C8", to: "N9")
        case .deoxythymine:
            addBond(from: "C5", to: "C7")
        case .uracil:
            addBond(from: "C1'", to: "N1")
            addBond(from: "N1", to: "C2")
            addBond(from: "C2", to: "O2")
            addBond(from: "C2", to: "N3")
            addBond(from: "N3", to: "C4")
            addBond(from: "C4", to: "O4")
            addBond(from: "C4", to: "C5")
            addBond(from: "C5", to: "C6")
            addBond(from: "C6", to: "N1")
        }
        residueAtoms.removeAll(keepingCapacity: true)
        return residueBonds
    }
}
