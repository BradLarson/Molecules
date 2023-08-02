import XCTest
@testable import Molecules

final class SDFFileTests: XCTestCase {
    
    func testLoadHeme() throws {
        let fileData = try Bundle.main.loadData(forResource: "Heme", withExtension: ".sdf")
        
        let heme = try SDFFile(data: fileData)
        XCTAssertEqual(heme.atoms.count, 43)
        XCTAssertEqual(heme.bonds.count, 50)
    }
        
    func testLoadC60() throws {
        let fileData = try Bundle.main.loadData(forResource: "Buckminsterfullerene", withExtension: ".sdf")

        let buckminsterfullerene = try SDFFile(data: fileData)
        XCTAssertEqual(buckminsterfullerene.atoms.count, 60)
        XCTAssertEqual(buckminsterfullerene.bonds.count, 90)
    }
}
