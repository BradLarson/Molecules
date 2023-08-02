import XCTest
@testable import Molecules

final class XYZFileTests: XCTestCase {
    
    func testLoadSampleMolecule() throws {
        let fileData = try Bundle(for: XYZFileTests.self).loadData(forResource: "SampleMolecule", withExtension: ".xyz")

        let sampleMolecule = try XYZFile(data: fileData)
        XCTAssertEqual(sampleMolecule.atoms.count, 47)
        XCTAssertEqual(sampleMolecule.bonds.count, 0)
    }
}
