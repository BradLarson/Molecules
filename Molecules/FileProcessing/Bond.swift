/// Bonds between atoms in a molecular structure.
struct Bond {
    enum Strength {
        case single
        case double
        case triple
    }
    
    let strength: Strength
    let start: Coordinate
    let end: Coordinate
}
