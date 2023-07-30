import MetalKit

final class MoleculeRenderer {
    let molecule: MolecularStructure

    var sphereVertexBuffers: [Atom.Element: MTLBuffer] = [:]
    var sphereImpostorSpaceCoordinateBuffers: [Atom.Element: MTLBuffer] = [:]
    var sphereIndexBuffers: [Atom.Element: MTLBuffer] = [:]
    var sphereIndexBufferCounts: [Atom.Element: Int] = [:]
    let lowerScaleLimit: Float = -100.0
    let upperScaleLimit: Float = 100.0

    var currentScale: Float = 1.0
    var currentTranslation: Coordinate = .zero
    var modelViewProjMatrix = Matrix4x4(rowMajorValues: [
        0.402560, 0.094840, 0.910469, 0.000000,
        0.913984,-0.096835,-0.394028, 0.000000,
        0.050796, 0.990772,-0.125664, 0.000000,
        0.000000, 0.000000, 0.000000, 1.000000])

    init(molecule: MolecularStructure) {
        self.molecule = molecule
        initializeMoleculeBuffers()
    }

    func initializeMoleculeBuffers() {
        final class BufferComponents {
            var vertices: [Float] = []
            var indices: [UInt16] = []
            var impostorSpaceCoordinates: [Float] = []
            var index: UInt16 = 0
        }
        var sphereComponents: [Atom.Element: BufferComponents] = [:]
        let moleculeScaleFactor = molecule.overallScaleFactor
        let centerOfMass = molecule.centerOfMass

        // Read all atoms, split into elements, populate individual atomic element buffers.
        for atom in molecule.atoms {
            let elementComponents: BufferComponents
            if let retrievedComponents = sphereComponents[atom.element] {
                elementComponents = retrievedComponents
            } else {
                elementComponents = BufferComponents()
                sphereComponents[atom.element] = elementComponents
            }
            appendOctagonVertices(
                position: (atom.location - centerOfMass) * moleculeScaleFactor,
                currentIndex: &elementComponents.index,
                indices: &elementComponents.indices,
                vertices: &elementComponents.vertices,
                impostorSpaceCoordinates: &elementComponents.impostorSpaceCoordinates)
        }

        // Convert those local buffers into Metal buffers for each atomic element.
        for element in Atom.Element.allCases {
            guard let elementComponents = sphereComponents[element] else { continue }
            let elementIndexBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: elementComponents.indices,
                                                                                  length: elementComponents.indices.count * MemoryLayout<UInt16>.size,
                                                                                  options: [])!
            elementIndexBuffer.label = "Sphere index buffer: \(element)"
            let elementIndexBufferCount = elementComponents.indices.count
            sphereIndexBuffers[element] = elementIndexBuffer
            sphereIndexBufferCounts[element] = elementIndexBufferCount

            let elementVertexBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: elementComponents.vertices,
                                                                                   length: elementComponents.vertices.count * MemoryLayout<Float>.size,
                                                                                   options: [])!
            elementVertexBuffer.label = "Sphere vertex buffer: \(element)"
            sphereVertexBuffers[element] = elementVertexBuffer

            let elementImpostorSpaceCoordinateBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: elementComponents.impostorSpaceCoordinates,
                                                                                                    length: elementComponents.impostorSpaceCoordinates.count * MemoryLayout<Float>.size,
                                                                                                    options: [])!
            elementImpostorSpaceCoordinateBuffer.label = "Sphere impostor space buffer: \(element)"
            sphereImpostorSpaceCoordinateBuffers[element] = elementImpostorSpaceCoordinateBuffer
            print("Vertices: \(elementComponents.vertices.count) in element: \(element)")
        }

        // TODO: Loop through all bonds.

        print("Number of atoms to initialize: \(molecule.atoms.count)")
    }

    func renderMoleculeFrame(width: CGFloat, height: CGFloat, buffer: MTLCommandBuffer, renderPass: MTLRenderPassDescriptor) {
        let orthographicMatrix = orthographicMatrix(left: -1.0, right: 1.0, bottom: Float(-1.0 * height / width), top: Float(height / width), near: -1.0, far: 1.0)

        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0)
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].loadAction = .clear

        guard let renderEncoder = buffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            fatalError("Could not create render encoder")
        }
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setRenderPipelineState(sharedMetalRenderingDevice.sphereRaytracingPipelineState)

        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .lessEqual
        depthStencilDescriptor.isDepthWriteEnabled = true
        let depthStencilState = sharedMetalRenderingDevice.device.makeDepthStencilState(descriptor: depthStencilDescriptor)
        renderEncoder.setDepthStencilState(depthStencilState)

        let moleculeScaleFactor = molecule.overallScaleFactor * currentScale

        for element in Atom.Element.allCases {
            guard let sphereIndexBuffer = sphereIndexBuffers[element],
                  let sphereIndexBufferCount = sphereIndexBufferCounts[element],
                  let sphereVertexBuffer = sphereVertexBuffers[element],
                  let sphereImpostorSpaceCoordinateBuffer = sphereImpostorSpaceCoordinateBuffers[element] else {
                continue
            }

            // Setting sphere vertex buffers.
            renderEncoder.setVertexBuffer(sphereVertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(sphereImpostorSpaceCoordinateBuffer, offset: 0, index: 1)
            let vertexUniforms = sphereVertexUniforms(modelViewProjMatrix: modelViewProjMatrix,
                                                      orthographicMatrix: orthographicMatrix,
                                                      sphereRadius: element.vanderWaalsRadius * moleculeScaleFactor,
                                                      translation: currentTranslation)
            let vertexUniformBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: vertexUniforms,
                                                                                   length: vertexUniforms.count * MemoryLayout<Float>.size,
                                                                                   options: [])!
            renderEncoder.setVertexBuffer(vertexUniformBuffer, offset: 0, index: 3)

            // Setting sphere fragment buffers.
            let fragmentUniforms = sphereFragmentUniforms(sphereColor: element.color,
                                                          inverseModelViewProjMatrix: modelViewProjMatrix.inverted())
            let fragmentUniformBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: fragmentUniforms,
                                                                                     length: fragmentUniforms.count * MemoryLayout<Float>.size,
                                                                                     options: [])!
            renderEncoder.setFragmentBuffer(fragmentUniformBuffer, offset: 0, index: 1)

            // Draw all spheres for an element.
            renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: sphereIndexBufferCount, indexType: .uint16, indexBuffer: sphereIndexBuffer, indexBufferOffset: 0)
        }

        renderEncoder.endEncoding()
    }

    func sphereVertexUniforms(modelViewProjMatrix: Matrix4x4, orthographicMatrix: Matrix4x4, sphereRadius: Float, translation: Coordinate) -> [Float] {
        return modelViewProjMatrix.toFloatArray() + orthographicMatrix.toFloatArray() + [sphereRadius, 0.0, 0.0, 0.0, translation.x, translation.y, translation.z, 0.0]
    }

    func sphereFragmentUniforms(sphereColor: Atom.Element.Color, inverseModelViewProjMatrix: Matrix4x4) -> [Float] {
        return [sphereColor.red, sphereColor.green, sphereColor.blue, 0.0] + inverseModelViewProjMatrix.toFloatArray()
    }
}

// MARK: -
// MARK: Touch manipulation.

extension MoleculeRenderer {
    func rotateFromTouch(x: Float, y: Float) {
        let rotatedMatrix = modelViewProjMatrix.rotatedFromTouch(x: x, y: y)
        if ((rotatedMatrix.m11 >= lowerScaleLimit) && (rotatedMatrix.m11 <= upperScaleLimit)) {
            modelViewProjMatrix = rotatedMatrix
        }
    }

    func scaleFromTouch(scale: Float) {
        let scaledMatrix = modelViewProjMatrix.scaledFromTouch(scale: scale)

        if ((scaledMatrix.m11 >= lowerScaleLimit) && (scaledMatrix.m11 <= upperScaleLimit)) {
            modelViewProjMatrix = scaledMatrix
            currentScale = currentScale * scale
        }
    }

    func translateFromTouch(x: Float, y: Float, backingWidth: Float) {
        currentTranslation = modelViewProjMatrix.translatedFromTouch(currentTranslation: currentTranslation, x: x, y: y, backingWidth: backingWidth)
    }
}

func appendOctagonVertices(
    position: Coordinate,
    currentIndex: inout UInt16,
    indices: inout [UInt16],
    vertices: inout [Float],
    impostorSpaceCoordinates: inout [Float]
) {
    let vertex = [-position.x, position.y, position.z]
    for _ in 0..<8 {
        vertices.append(contentsOf: vertex)
    }

    let positiveSideComponent: Float = 1.0 - 2.0 / (sqrt(2.0) + 2.0)
    let negativeSideComponent: Float = -1.0 + 2.0 / (sqrt(2.0) + 2.0);
    let octagonPoints: [Float] = [
        negativeSideComponent, 1.0,
        -1.0, negativeSideComponent,
        1.0, positiveSideComponent,
        positiveSideComponent, -1.0,
        1.0, negativeSideComponent,
        positiveSideComponent, 1.0,
        -1.0, positiveSideComponent,
        negativeSideComponent, -1.0
    ]
    impostorSpaceCoordinates += octagonPoints

    // 123, 324, 345, 136, 217, 428
    let octagonIndices: [UInt16] = [
        currentIndex, currentIndex + 1, currentIndex + 2,
        currentIndex + 2, currentIndex + 1, currentIndex + 3,
        currentIndex + 2, currentIndex + 3, currentIndex + 4,
        currentIndex, currentIndex + 2, currentIndex + 5,
        currentIndex + 1, currentIndex, currentIndex + 6,
        currentIndex + 3, currentIndex + 1, currentIndex + 7
    ]
    indices += octagonIndices

    currentIndex += 8
}
