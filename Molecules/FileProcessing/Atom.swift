/// Individual atoms within a molecular structure, located in 3-D space.
struct Atom {
    enum Element: CaseIterable, Hashable {
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

        struct Color {
            let red: Float
            let green: Float
            let blue: Float

            init (_ red: Float, _ green: Float, _ blue: Float) {
                self.red = red
                self.green = green
                self.blue = blue
            }
        }
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

extension Atom.Element {
    var vanderWaalsRadius: Float {
        switch self {
        case .carbon: return 1.55
        case .hydrogen: return 1.10
        case .oxygen: return 1.35
        case .nitrogen: return 1.40
        case .sulfur: return 1.81
        case .phosphorous: return 1.88
        case .iron: return 1.95
        case .silicon: return 1.50
        case .fluorine: return 1.47
        case .chlorine: return 1.75
        case .bromine: return 1.85
        case .iodine: return 1.75
        case .calcium: return 1.95
        case .zinc: return 1.15
        case .cadmium: return 1.75
        case .sodium: return 1.02
        case .magnesium: return 0.72
        case .unknown: return 1.50
        }
    }
}

extension Atom.Element {
    var color: Color {
        switch self {
        case .carbon: return Color(0.47, 0.47, 0.47)
        case .hydrogen: return Color(0.90, 0.90, 0.90)
        case .oxygen: return Color(0.94, 0.16, 0.16)
        case .nitrogen: return Color(0.19, 0.31, 0.97)
        case .sulfur: return Color(1.0, 1.0, 0.19)
        case .phosphorous: return Color(1.0, 0.5, 0.0)
        case .iron: return Color(0.88, 0.4, 0.2)
        case .silicon: return Color(0.78, 0.78, 0.35)
        case .fluorine: return Color(0.56, 0.88, 0.31)
        case .chlorine: return Color(0.12, 0.94, 0.12)
        case .bromine: return Color(0.65, 0.16, 0.16)
        case .iodine: return Color(0.58, 0.0, 0.58)
        case .calcium: return Color(0.25, 1.0, 0.0)
        case .zinc: return Color(0.49, 0.5, 0.69)
        case .cadmium: return Color(1.0, 0.85, 0.56)
        case .sodium: return Color(0.67, 0.36, 0.95)
        case .magnesium: return Color(0.54, 1.0, 0.0)
        case .unknown: return Color(0.0, 1.0, 0.0)
        }
    }
}
