import XCTest
@testable import Molecules

final class RenderingTests: XCTestCase {

    func testOctagonCoordinates() {
        var currentIndex: UInt16 = 0
        var indices: [UInt16] = []
        var vertices: [Float] = []
        var impostorSpaceCoordinates: [Float] = []

        let position = Coordinate(x: -1.0, y: 2.0, z: 3.0)

        appendOctagonVertices(
            position: position,
            currentIndex: &currentIndex,
            indices: &indices,
            vertices: &vertices,
            impostorSpaceCoordinates: &impostorSpaceCoordinates)

        XCTAssertEqual(currentIndex, 8)
        XCTAssertEqual(indices.count, 18)
        XCTAssertEqual(vertices.count, 24)
        XCTAssertEqual(impostorSpaceCoordinates.count, 16)

        appendOctagonVertices(
            position: position,
            currentIndex: &currentIndex,
            indices: &indices,
            vertices: &vertices,
            impostorSpaceCoordinates: &impostorSpaceCoordinates)

        XCTAssertEqual(currentIndex, 16)
        XCTAssertEqual(indices.count, 36)
        XCTAssertEqual(vertices.count, 48)
        XCTAssertEqual(impostorSpaceCoordinates.count, 32)

        XCTAssertEqual(vertices[3], 1.0)
        XCTAssertEqual(vertices[4], 2.0)
        XCTAssertEqual(vertices[5], 3.0)
    }
}
