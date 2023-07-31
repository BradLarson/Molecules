import XCTest
@testable import Molecules

func assertEqual(_ lhs: Matrix4x4, _ rhs: Matrix4x4, accuracy: Float, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertEqual(lhs.m11, rhs.m11, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(lhs.m12, rhs.m12, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(lhs.m13, rhs.m13, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(lhs.m14, rhs.m14, accuracy: accuracy, file: file, line: line)

    XCTAssertEqual(lhs.m21, rhs.m21, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(lhs.m22, rhs.m22, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(lhs.m23, rhs.m23, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(lhs.m24, rhs.m24, accuracy: accuracy, file: file, line: line)

    XCTAssertEqual(lhs.m31, rhs.m31, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(lhs.m32, rhs.m32, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(lhs.m33, rhs.m33, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(lhs.m34, rhs.m34, accuracy: accuracy, file: file, line: line)

    XCTAssertEqual(lhs.m41, rhs.m41, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(lhs.m42, rhs.m42, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(lhs.m43, rhs.m43, accuracy: accuracy, file: file, line: line)
    XCTAssertEqual(lhs.m44, rhs.m44, accuracy: accuracy, file: file, line: line)
}


final class MatrixTests: XCTestCase {

    func testRotation() {
        let startingMatrix = Matrix4x4(rowMajorValues: [
            0.25, 0.5, 0.75, 1.0,
            1.25, 1.5, 1.75, 1.0,
            2.25, 2.5, 2.75, 1.0,
            1.00, 1.0, 1.00, 1.0])
        let rotatedX = startingMatrix.rotated(angle: 1.0, x: 1.0, y: 0.0, z: 0.0)
        assertEqual(rotatedX, Matrix4x4(rowMajorValues: [
            0.25, 0.5, 0.75, 1.0,
            2.568687598152942, 2.9141309208219512, 3.25957424349096, 1.3817732906760363,
            0.1638414571934439, 0.08854928745850477, 0.013257117723565415, -0.30116867893975674,
            1.0,  1.0, 1.0,  1.0
        ]), accuracy: 0.001)

        let rotatedY = startingMatrix.rotated(angle: 1.0, x: 0.0, y: 1.0, z: 0.0)
        assertEqual(rotatedY, Matrix4x4(rowMajorValues: [
            -1.7582341393507321, -1.8335263090856715, -1.9088184788206108, -0.30116867893975674,
             1.25, 1.5, 1.75, 1.0,
             1.4260479344052888, 1.7714912570742976, 2.1169345797433063, 1.3817732906760363,
             1.0, 1.0, 1.0, 1.0
        ]), accuracy: 0.001)

        let rotatedZ = startingMatrix.rotated(angle: 1.0, x: 0.0, y: 0.0, z: 1.0)
        assertEqual(rotatedZ, Matrix4x4(rowMajorValues: [
            1.1869143074769055, 1.5323576301459145, 1.8778009528149235, 1.3817732906760363,
            0.4650101361332006, 0.3897179663982614, 0.31442579666332227, -0.30116867893975674,
            2.25, 2.5, 2.75, 1.0,
            1.0, 1.0, 1.0, 1.0
        ]), accuracy: 0.001)

        let rotatedXYZ = startingMatrix.rotated(angle: 1.0, x: 1.0, y: 1.0, z: 1.0)
        assertEqual(rotatedXYZ, Matrix4x4(rowMajorValues: [
            0.22387419453776192, 0.4738741945377618, 0.7238741945377618, 1.0,
            2.2216469991881973, 2.4716469991881977, 2.7216469991881973, 1.0,
            1.3044788062740413, 1.5544788062740413, 1.8044788062740413, 1.0,
            1.0, 1.0, 1.0, 1.0
        ]), accuracy: 0.001)
    }

    func testRotationFromTouch() {
    }

    func testScale() {
        let startingMatrix = Matrix4x4(rowMajorValues: [
            0.25, 0.5, 0.75, 1.0,
            1.25, 1.5, 1.75, 1.0,
            2.25, 2.5, 2.75, 1.0,
            1.00, 1.0, 1.00, 1.0])
        let scaled = startingMatrix.scaled(x: 2.0, y: 3.0, z: 4.0)
        assertEqual(scaled, Matrix4x4(rowMajorValues: [
            0.5,  1.0,  1.5,  2.0,
            3.75, 4.5,  5.25, 3.0,
            9.0,  10.0, 11.0, 4.0,
            1.0,  1.0,  1.0,  1.0
        ]), accuracy: 0.001)
    }

    func testScaleFromTouch() {
        let startingMatrix = Matrix4x4(rowMajorValues: [
            1.0, 1.0, 1.0, 1.0,
            1.0, 1.0, 1.0, 1.0,
            1.0, 1.0, 1.0, 1.0,
            1.0, 1.0, 1.0, 1.0])
        let scaled = startingMatrix.scaledFromTouch(scale: 0.5)
        assertEqual(scaled, Matrix4x4(rowMajorValues: [
            0.5, 0.5, 0.5, 0.5,
            0.5, 0.5, 0.5, 0.5,
            0.5, 0.5, 0.5, 0.5,
            1.0, 1.0, 1.0, 1.0
        ]), accuracy: 0.001)
    }

    func testTranslationFromTouch() {
        let identity = Matrix4x4.identity
        let initialTranslation = Coordinate(x: 1.0, y: 2.0, z: 3.0)
        let translated = identity.translatedFromTouch(currentTranslation: initialTranslation, x: 100.0, y: 50.0, backingWidth: 400.0)
        XCTAssertEqual(translated.x, 1.5, accuracy: 0.01)
        XCTAssertEqual(translated.y, 2.25, accuracy: 0.01)

        let scaled = identity.scaled(x: 0.25, y: 0.25, z: 0.25)
        let translated2 = scaled.translatedFromTouch(currentTranslation: initialTranslation, x: 100.0, y: 50.0, backingWidth: 400.0)
        XCTAssertEqual(translated2.x, 3.0, accuracy: 0.01)
        XCTAssertEqual(translated2.y, 3.0, accuracy: 0.01)
    }

    func testInversion() {
        let startingMatrix = Matrix4x4(rowMajorValues: [
            0.25, 0.5, 0.75, 0.0,
            1.25, 1.5, 1.75, 0.0,
            2.25, 2.5, 2.75, 0.0,
            0.00, 0.0, 0.00, 1.0])
        let inverted = startingMatrix.inverted()
        assertEqual(inverted, Matrix4x4(rowMajorValues: [
            0.25, 1.25, 2.25, 0.0,
            0.5,  1.5,  2.5,  0.0,
            0.75, 1.75, 2.75, 0.0,
            0.00, 0.0,  0.0,  1.0
        ]), accuracy: 0.001)
    }

    func testMultiplication() {
        let identity = Matrix4x4.identity
        let multipliedIdentity = identity * identity
        assertEqual(multipliedIdentity, identity, accuracy: 0.001)

        let startingMatrix = Matrix4x4(rowMajorValues: [
            0.25, 0.5, 0.75, 1.0,
            1.25, 1.5, 1.75, 1.0,
            2.25, 2.5, 2.75, 1.0,
            1.00, 1.0, 1.00, 1.0])

        let squaredMatrix = startingMatrix * startingMatrix
        assertEqual(squaredMatrix, Matrix4x4(rowMajorValues: [
            3.375,  3.75,  4.125,  2.5,
            7.125,  8.25,  9.375,  5.5,
            10.875, 12.75, 14.625, 8.5,
            4.75,   5.5,   6.25,   4.0
        ]), accuracy: 0.001)
    }
}
