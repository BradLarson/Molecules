import MetalKit

final class MoleculeRenderer {
    let molecule: MolecularStructure

    var moleculeVertexBuffer: MTLBuffer!
    var moleculeImpostorSpaceCoordinateBuffer: MTLBuffer!
    var moleculeIndexBuffer: MTLBuffer!
    var moleculeIndexBufferCount: Int!

    init(molecule: MolecularStructure) {
        self.molecule = molecule
        initializeMoleculeBuffers()
    }

    func initializeMoleculeBuffers() {
        var moleculeIndices: [UInt16] = []
        var moleculeVertices: [Float] = []
        var moleculeImpostorSpaceCoordinates: [Float] = []

        var currentIndex: UInt16 = 0
        // TODO: Loop through all atoms.
        appendOctagonVertices(
            position: Coordinate(x: 0.0, y: 0.0, z: 0.0),
            currentIndex: &currentIndex,
            indices: &moleculeIndices,
            vertices: &moleculeVertices,
            impostorSpaceCoordinates: &moleculeImpostorSpaceCoordinates)

        moleculeIndexBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: moleculeIndices,
                                                                           length: moleculeIndices.count * MemoryLayout<UInt16>.size,
                                                                           options: [])!
        moleculeIndexBuffer.label = "Sphere index buffer"
        moleculeIndexBufferCount = moleculeIndices.count

        // const device packed_float3 *position [[buffer(0)]],
        moleculeVertexBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: moleculeVertices,
                                                                            length: moleculeVertices.count * MemoryLayout<Float>.size,
                                                                            options: [])!
        moleculeVertexBuffer.label = "Sphere vertex buffer"


        // const device packed_float2 *inputImpostorSpaceCoordinate [[buffer(1)]],
        moleculeImpostorSpaceCoordinateBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: moleculeImpostorSpaceCoordinates,
                                                                                             length: moleculeImpostorSpaceCoordinates.count * MemoryLayout<Float>.size,
                                                                                             options: [])!
        moleculeImpostorSpaceCoordinateBuffer.label = "Sphere impostor space buffer"


        // TODO: Complete cylinder impostors.

        print("Number of atoms to initialize: \(molecule.atoms.count)")
    }

    func renderMoleculeFrame(buffer: MTLCommandBuffer, renderPass: MTLRenderPassDescriptor) {
//        let renderPass = MTLRenderPassDescriptor()
//        renderPass.colorAttachments[0].texture = output
        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(1, 0, 0, 1)
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].loadAction = .clear

        guard let renderEncoder = buffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            fatalError("Could not create render encoder")
        }
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setRenderPipelineState(sharedMetalRenderingDevice.sphereRaytracingPipelineState)

        renderEncoder.setVertexBuffer(moleculeVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(moleculeImpostorSpaceCoordinateBuffer, offset: 0, index: 1)

        let vertexUniforms = sphereVertexUniforms()
        let vertexUniformBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: vertexUniforms,
                                                                               length: vertexUniforms.count * MemoryLayout<Float>.size,
                                                                               options: [])!
        renderEncoder.setVertexBuffer(vertexUniformBuffer, offset: 0, index: 3)

        let fragmentUniforms = sphereFragmentUniforms()
        let fragmentUniformBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: fragmentUniforms,
                                                                                 length: fragmentUniforms.count * MemoryLayout<Float>.size,
                                                                                 options: [])!
        renderEncoder.setFragmentBuffer(fragmentUniformBuffer, offset: 0, index: 1)


        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: moleculeIndexBufferCount, indexType: .uint16, indexBuffer: moleculeIndexBuffer, indexBufferOffset: 0)

        renderEncoder.endEncoding()
    }

    func sphereVertexUniforms() -> [Float] {
//        float3x3 modelViewProjMatrix;
//        float4x4 orthographicMatrix;
//        float sphereRadius;
//        float3 translation;
        let modelViewProjMatrix = Matrix3x3.identity
        let orthographicMatrix = Matrix4x4.identity
        let sphereRadius: Float = 1.0
        let translation: (Float, Float, Float) = (0.0, 0.0, 0.0)

        return modelViewProjMatrix.toFloatArray() + orthographicMatrix.toFloatArray() + [sphereRadius, 0.0, 0.0, 0.0, translation.0, translation.1, translation.2, 0.0]
    }

    func sphereFragmentUniforms() -> [Float] {
//        float3 sphereColor;
//        float3x3 inverseModelViewProjMatrix;
        let sphereColor: (Float, Float, Float) = (0.0, 1.0, 0.0)
        let inverseModelViewProjMatrix = Matrix3x3.identity

        return [sphereColor.0, sphereColor.1, sphereColor.2, 0.0] + inverseModelViewProjMatrix.toFloatArray()
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
