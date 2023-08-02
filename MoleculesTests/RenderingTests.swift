import XCTest
@testable import Molecules

final class RenderingTests: XCTestCase {

    func testOctagonCoordinates() {
        var currentIndex: UInt16 = 0
        var indices: [UInt16] = []
        var vertices: [Float] = []
        var impostorSpaceCoordinates: [Float] = []

        let position = Coordinate(x: -1.0, y: 2.0, z: 3.0)
        let normalizedAOTexturePatchWidth: Float = 0.25
        var currentAmbientOcclusionTextureOffset: (Float, Float) = (0.125, 0.125)
        var ambientOcclusionTextureOffsets: [Float] = []

        appendOctagonVertices(
            position: position,
            currentIndex: &currentIndex,
            indices: &indices,
            vertices: &vertices,
            normalizedAOTexturePatchWidth: normalizedAOTexturePatchWidth,
            currentAmbientOcclusionTextureOffset: &currentAmbientOcclusionTextureOffset,
            ambientOcclusionTextureOffsets: &ambientOcclusionTextureOffsets,
            impostorSpaceCoordinates: &impostorSpaceCoordinates)

        XCTAssertEqual(currentIndex, 8)
        XCTAssertEqual(indices.count, 18)
        XCTAssertEqual(vertices.count, 24)
        XCTAssertEqual(impostorSpaceCoordinates.count, 16)
        XCTAssertEqual(ambientOcclusionTextureOffsets.count, 16)
        XCTAssertEqual(currentAmbientOcclusionTextureOffset.0, 0.375)
        XCTAssertEqual(currentAmbientOcclusionTextureOffset.1, 0.125)

        appendOctagonVertices(
            position: position,
            currentIndex: &currentIndex,
            indices: &indices,
            vertices: &vertices,
            normalizedAOTexturePatchWidth: normalizedAOTexturePatchWidth,
            currentAmbientOcclusionTextureOffset: &currentAmbientOcclusionTextureOffset,
            ambientOcclusionTextureOffsets: &ambientOcclusionTextureOffsets,
            impostorSpaceCoordinates: &impostorSpaceCoordinates)

        XCTAssertEqual(currentIndex, 16)
        XCTAssertEqual(indices.count, 36)
        XCTAssertEqual(vertices.count, 48)
        XCTAssertEqual(impostorSpaceCoordinates.count, 32)
        XCTAssertEqual(ambientOcclusionTextureOffsets.count, 32)
        XCTAssertEqual(currentAmbientOcclusionTextureOffset.0, 0.625)
        XCTAssertEqual(currentAmbientOcclusionTextureOffset.1, 0.125)

        XCTAssertEqual(vertices[3], 1.0)
        XCTAssertEqual(vertices[4], 2.0)
        XCTAssertEqual(vertices[5], 3.0)
    }

    func testCylinderCoordinates() {
        var currentIndex: UInt16 = 0
        var indices: [UInt16] = []
        var vertices: [Float] = []
        var directions: [Float] = []
        var impostorSpaceCoordinates: [Float] = []

        let start = Coordinate(x: -1.0, y: 2.0, z: 3.0)
        let end = Coordinate(x: -1.0, y: 2.0, z: 3.0)

        appendRectangularBondVertices(
            start: start,
            end: end,
            currentIndex: &currentIndex,
            indices: &indices,
            vertices: &vertices,
            directions: &directions,
            impostorSpaceCoordinates: &impostorSpaceCoordinates
        )
        XCTAssertEqual(currentIndex, 4)
        XCTAssertEqual(indices.count, 6)
        XCTAssertEqual(vertices.count, 12)
        XCTAssertEqual(directions.count, 12)
        XCTAssertEqual(impostorSpaceCoordinates.count, 8)

        appendRectangularBondVertices(
            start: start,
            end: end,
            currentIndex: &currentIndex,
            indices: &indices,
            vertices: &vertices,
            directions: &directions,
            impostorSpaceCoordinates: &impostorSpaceCoordinates
        )
        XCTAssertEqual(currentIndex, 8)
        XCTAssertEqual(indices.count, 12)
        XCTAssertEqual(vertices.count, 24)
        XCTAssertEqual(directions.count, 24)
        XCTAssertEqual(impostorSpaceCoordinates.count, 16)
        XCTAssertEqual(indices[0], 0)
        XCTAssertEqual(indices[6], 4)

    }
}
