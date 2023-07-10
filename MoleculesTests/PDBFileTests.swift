import XCTest
@testable import Molecules

// TODO: Add a suite of test molecules that are only used in unit tests.

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
        XCTAssertEqual(dna.atoms.count, 206)
        // TODO: Reduce this to the actual number of bonds, once bidirectional bonds are corrected.
        XCTAssertEqual(dna.bonds.count, 556)
        for atom in dna.atoms {
            XCTAssert(atom.element != .unknown)
        }
    }
}
