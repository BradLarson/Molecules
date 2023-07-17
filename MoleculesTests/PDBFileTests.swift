import XCTest
@testable import Molecules

final class PDBFileTests: XCTestCase {
    
    func testLoadCaffeine() throws {
        let fileData = try Bundle.main.loadData(forResource: "Caffeine", withExtension: ".pdb")
        
        let caffeine = try PDBFile(data: fileData)
        XCTAssertEqual(caffeine.atoms.count, 24)
        // TODO: Reduce this to the actual number of bonds, once bidirectional bonds are corrected.
        XCTAssertEqual(caffeine.bonds.count, 40)
        for atom in caffeine.atoms {
            XCTAssert(atom.element != .unknown)
        }

        let fileData2 = try Bundle(for: PDBFileTests.self).loadData(forResource: "Caffeine", withExtension: ".pdb.gz", compressed: true)
        let caffeineCompressed = try PDBFile(data: fileData2)
        XCTAssertEqual(caffeineCompressed.atoms.count, 24)
        // TODO: Reduce this to the actual number of bonds, once bidirectional bonds are corrected.
        XCTAssertEqual(caffeineCompressed.bonds.count, 40)
        for atom in caffeineCompressed.atoms {
            XCTAssert(atom.element != .unknown)
        }
    }
    
    func testLoadTheoreticalBearing() throws {
        let fileData = try Bundle.main.loadData(forResource: "TheoreticalBearing", withExtension: ".pdb")
        
        let theoreticalBearing = try PDBFile(data: fileData)
        XCTAssertEqual(theoreticalBearing.atoms.count, 206)
        // TODO: Reduce this to the actual number of bonds, once bidirectional bonds are corrected.
        XCTAssertEqual(theoreticalBearing.bonds.count, 556)
        for atom in theoreticalBearing.atoms {
            XCTAssert(atom.element != .unknown)
        }
    }
    
    func testLoadDNA() throws {
        let fileData = try Bundle.main.loadData(forResource: "DNA", withExtension: ".pdb")

        let dna = try PDBFile(data: fileData)
        XCTAssertEqual(dna.atoms.count, 486)
        XCTAssertEqual(dna.bonds.count, 490)
        for atom in dna.atoms {
            XCTAssert(atom.element != .unknown)
        }
        let metadata = try XCTUnwrap(dna.metadata)
        XCTAssertGreaterThan(metadata.title.count, 0)
        XCTAssertGreaterThan(metadata.compound.count, 0)
        XCTAssertGreaterThan(metadata.authors.count, 0)
        XCTAssertGreaterThan(metadata.source.count, 0)
        XCTAssertGreaterThan(metadata.journal.count, 0)
        XCTAssertGreaterThan(metadata.sequence.count, 0)
    }

    func testLoadRNA() throws {
        let fileData = try Bundle.main.loadData(forResource: "TransferRNA", withExtension: ".pdb")

        let rna = try PDBFile(data: fileData)
        XCTAssertEqual(rna.atoms.count, 1656)
        XCTAssertEqual(rna.bonds.count, 1467)
        for atom in rna.atoms {
            XCTAssert(atom.element != .unknown)
        }
        let metadata = try XCTUnwrap(rna.metadata)
        XCTAssertGreaterThan(metadata.title.count, 0)
        XCTAssertGreaterThan(metadata.compound.count, 0)
        XCTAssertGreaterThan(metadata.authors.count, 0)
        XCTAssertGreaterThan(metadata.source.count, 0)
        XCTAssertGreaterThan(metadata.journal.count, 0)
        XCTAssertGreaterThan(metadata.sequence.count, 0)
    }

    func testLoadInsulin() throws {
        let fileData = try Bundle.main.loadData(forResource: "Insulin", withExtension: ".pdb")

        let insulin = try PDBFile(data: fileData)
        XCTAssertEqual(insulin.atoms.count, 803)
        XCTAssertEqual(insulin.bonds.count, 815)
        for atom in insulin.atoms {
            XCTAssert(atom.element != .unknown)
        }
        let metadata = try XCTUnwrap(insulin.metadata)
        XCTAssertGreaterThan(metadata.title.count, 0)
        XCTAssertGreaterThan(metadata.compound.count, 0)
        XCTAssertGreaterThan(metadata.authors.count, 0)
        XCTAssertGreaterThan(metadata.source.count, 0)
        XCTAssertGreaterThan(metadata.journal.count, 0)
        XCTAssertGreaterThan(metadata.sequence.count, 0)
    }

    func testAminoAcidBonds() {
        let glycine = AminoAcidResidue.glycine
        var glycineAtoms = [
            "N": Atom(element: .nitrogen, location: Coordinate(x: 1.0, y: 2.0, z: 3.0)),
            "CA": Atom(element: .carbon, location: Coordinate(x: 2.0, y: 3.0, z: 4.0)),
            "C": Atom(element: .carbon, location: Coordinate(x: 3.0, y: 4.0, z: 5.0)),
            "O": Atom(element: .oxygen, location: Coordinate(x: 4.0, y: 5.0, z: 6.0)),
            ]
        var previousTerminalAtom: Atom?
        let bonds = glycine.bonds(residueAtoms: &glycineAtoms, previousTerminalAtom: &previousTerminalAtom)
        XCTAssertEqual(bonds.count, 3)
        XCTAssertEqual(glycineAtoms.count, 0)
        XCTAssertNotNil(previousTerminalAtom)
    }
}
