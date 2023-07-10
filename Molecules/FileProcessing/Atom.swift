/// Individual atoms within a molecular structure, located in 3-D space.
struct Atom {
    enum Element {
        case carbon
        case hydrogen
        case oxygen
        case nitrogen
        case sulfur
        case phosphorous
        case iron
        case silicon
        case fluorine
        case chlorine
        case bromine
        case iodine
        case calcium
        case zinc
        case cadmium
        case sodium
        case magnesium
        case unknown
    }
    
    let element: Element
    let location: Coordinate
}

extension Atom.Element {
    init(code: String) {
        switch code.uppercased() {
        case "C": self = .carbon
        case "H": self = .hydrogen
        case "O": self = .oxygen
        case "N": self = .nitrogen
        case "S": self = .sulfur
        case "P": self = .phosphorous
        case "FE": self = .iron
        case "SI": self = .silicon
        case "F": self = .fluorine
        case "CL": self = .chlorine
        case "BR": self = .bromine
        case "I": self = .iodine
        case "CA": self = .calcium
        case "ZN": self = .zinc
        case "CD": self = .cadmium
        case "NA": self = .sodium
        case "MG": self = .magnesium
        default: self = .unknown
        }
    }
}
