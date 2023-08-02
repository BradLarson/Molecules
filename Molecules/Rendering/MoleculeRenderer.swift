import MetalKit

enum MoleculeVisualizationStyle {
    case spacefilling
    case ballAndStick
}

final class MoleculeRenderer {
    let molecule: MolecularStructure
    let visualizationStyle: MoleculeVisualizationStyle

    var sphereVertexBuffers: [Atom.Element: MTLBuffer] = [:]
    var sphereImpostorSpaceCoordinateBuffers: [Atom.Element: MTLBuffer] = [:]
    var sphereAmbientOcclusionTextureOffsetBuffers: [Atom.Element: MTLBuffer] = [:]
    var sphereIndexBuffers: [Atom.Element: MTLBuffer] = [:]
    var sphereIndexBufferCounts: [Atom.Element: Int] = [:]

    var cylinderVertexBuffer: MTLBuffer?
    var cylinderDirectionBuffer: MTLBuffer?
    var cylinderImpostorSpaceCoordinateBuffer: MTLBuffer?
    var cylinderIndexBuffer: MTLBuffer?
    var cylinderIndexBufferCount: Int = 0

    let ambientOcclusionTextureWidth = 1024
    var sphereAmbientOcclusionTexture: MTLTexture!
    var normalizedAOTexturePatchWidth: Float = 0.0

    let lowerScaleLimit: Float = -100.0
    let upperScaleLimit: Float = 100.0

    var currentScale: Float = 1.0
    var currentTranslation: Coordinate = .zero
    var modelViewProjMatrix = Matrix4x4(rowMajorValues: [
        0.402560, 0.094840, 0.910469, 0.000000,
        0.913984,-0.096835,-0.394028, 0.000000,
        0.050796, 0.990772,-0.125664, 0.000000,
        0.000000, 0.000000, 0.000000, 1.000000])

    init(molecule: MolecularStructure, visualizationStyle: MoleculeVisualizationStyle) {
        self.molecule = molecule
        self.visualizationStyle = visualizationStyle
        initializeMoleculeBuffers()
        prepareAmbientOcclusionTexture()
    }

    func initializeMoleculeBuffers() {
        final class BufferComponents {
            var vertices: [Float] = []
            var indices: [UInt16] = []
            var impostorSpaceCoordinates: [Float] = []
            var ambientOcclusionTextureOffsets: [Float] = []
            var index: UInt16 = 0
        }
        var sphereComponents: [Atom.Element: BufferComponents] = [:]
        let moleculeScaleFactor = molecule.overallScaleFactor
        let centerOfMass = molecule.centerOfMass

        normalizedAOTexturePatchWidth = 1.0 / ceil(sqrt(Float(molecule.atoms.count)));

        var currentAmbientOcclusionTextureOffset: (Float, Float) = (normalizedAOTexturePatchWidth / 2.0, normalizedAOTexturePatchWidth / 2.0)

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
                normalizedAOTexturePatchWidth: normalizedAOTexturePatchWidth,
                currentAmbientOcclusionTextureOffset: &currentAmbientOcclusionTextureOffset,
                ambientOcclusionTextureOffsets: &elementComponents.ambientOcclusionTextureOffsets,
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

            let elementAmbientOcclusionTextureOffsetBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: elementComponents.ambientOcclusionTextureOffsets,
                                                                                                          length: elementComponents.ambientOcclusionTextureOffsets.count * MemoryLayout<Float>.size,
                                                                                                          options: [])!
            elementAmbientOcclusionTextureOffsetBuffer.label = "Sphere ambient occlusion texture offset buffer: \(element)"
            sphereAmbientOcclusionTextureOffsetBuffers[element] = elementAmbientOcclusionTextureOffsetBuffer
        }

        // If bonds are visible, populate all of them in a single buffer.
        if visualizationStyle == .ballAndStick, molecule.bonds.count > 0 {
            var cylinderVertices: [Float] = []
            var cylinderDirections: [Float] = []
            var cylinderIndices: [UInt16] = []
            var cylinderImpostorSpaceCoordinates: [Float] = []
            var cylinderIndex: UInt16 = 0

            for bond in molecule.bonds {
                appendRectangularBondVertices(
                    start: (bond.start - centerOfMass) * moleculeScaleFactor,
                    end: (bond.end - centerOfMass) * moleculeScaleFactor,
                    currentIndex: &cylinderIndex,
                    indices: &cylinderIndices,
                    vertices: &cylinderVertices,
                    directions: &cylinderDirections,
                    impostorSpaceCoordinates: &cylinderImpostorSpaceCoordinates)
            }

            cylinderIndexBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: cylinderIndices,
                                                                               length: cylinderIndices.count * MemoryLayout<UInt16>.size,
                                                                               options: [])!
            cylinderIndexBuffer?.label = "Cylinder index buffer"
            cylinderIndexBufferCount = cylinderIndices.count

            cylinderVertexBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: cylinderVertices,
                                                                                length: cylinderVertices.count * MemoryLayout<Float>.size,
                                                                                options: [])!
            cylinderVertexBuffer?.label = "Cylinder vertex buffer"

            cylinderDirectionBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: cylinderDirections,
                                                                                   length: cylinderDirections.count * MemoryLayout<Float>.size,
                                                                                   options: [])!
            cylinderDirectionBuffer?.label = "Cylinder direction buffer"

            cylinderImpostorSpaceCoordinateBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: cylinderImpostorSpaceCoordinates,
                                                                                                 length: cylinderImpostorSpaceCoordinates.count * MemoryLayout<Float>.size,
                                                                                                 options: [])!
            cylinderImpostorSpaceCoordinateBuffer?.label = "Cylinder impostor space buffer"
        }
    }

    let ambientOcclusionSamplingAngles: [(Float, Float)] = [
        (0.0, 0.0),
        (.pi / 2.0, 0.0),
        (.pi, 0.0),
        (3.0 * .pi / 2.0, 0.0),
        (0.0, .pi / 2.0),
        (0.0, 3.0 * .pi / 2.0),

        (.pi / 4.0, .pi / 4.0),
        (3.0 * .pi / 4.0, .pi / 4.0),
        (5.0 * .pi / 4.0, .pi / 4.0),
        (7.0 * .pi / 4.0, .pi / 4.0),

        (.pi / 4.0, 7.0 * .pi / 4.0),
        (3.0 * .pi / 4.0, 7.0 * .pi / 4.0),
        (5.0 * .pi / 4.0, 7.0 * .pi / 4.0),
        (7.0 * .pi / 4.0, 7.0 * .pi / 4.0),

        (.pi / 4.0, 0.0),
        (3.0 * .pi / 4.0, 0.0),
        (5.0 * .pi / 4.0, 0.0),
        (7.0 * .pi / 4.0, 0.0),

        (0.0, .pi / 4.0),
        (0.0, 3.0 * .pi / 4.0),
        (0.0, 5.0 * .pi / 4.0),
        (0.0, 7.0 * .pi / 4.0),
    ]

    func prepareAmbientOcclusionTexture() {
        // Initialize the ambient occlusion texture.
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                         width: ambientOcclusionTextureWidth,
                                                                         height: ambientOcclusionTextureWidth,
                                                                         mipmapped: false)
        textureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]

        guard let newTexture = sharedMetalRenderingDevice.device.makeTexture(descriptor: textureDescriptor) else {
            fatalError("Could not create ambient occlusion texture of size: (\(ambientOcclusionTextureWidth), \(ambientOcclusionTextureWidth))")
        }
        sphereAmbientOcclusionTexture = newTexture
        sphereAmbientOcclusionTexture.label = "Ambient occlustion texture"

        // TODO: Extend ambient occlusion to ball-and-stick rendering modes.
        if visualizationStyle == .ballAndStick {
            // Set the ambient lighting texture to all-white for uniform illumination.
            if let commandBuffer = sharedMetalRenderingDevice.commandQueue.makeCommandBuffer() {
                commandBuffer.clear(texture: sphereAmbientOcclusionTexture, with: MTLClearColorMake(1.0, 1.0, 1.0, 1.0))
                commandBuffer.commit()
            }

            return
        }

        guard let commandBuffer = sharedMetalRenderingDevice.commandQueue.makeCommandBuffer() else { return }
        commandBuffer.clear(texture: sphereAmbientOcclusionTexture, with: MTLClearColorMake(0.0, 0.0, 0.0, 0.0))
        let sphereDepthTextureWidth = 1024

        let intensityFactor: Float = 0.5 / Float(ambientOcclusionSamplingAngles.count)
//        let intensityFactor: Float = 1.0
        for (theta, phi) in ambientOcclusionSamplingAngles {
            var rotationMatrix = Matrix4x4.identity.rotated(angle: theta, x: 1.0, y: 0.0, z: 0.0)
            rotationMatrix = rotationMatrix.rotated(angle: phi, x: 0.0, y: 1.0, z: 0.0)

            let depthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                                  width: sphereDepthTextureWidth,
                                                                                  height: sphereDepthTextureWidth,
                                                                                  mipmapped: false)
            depthTextureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
            guard let depthTexture = sharedMetalRenderingDevice.device.makeTexture(descriptor: depthTextureDescriptor) else {
                fatalError("Could not create depth texture of size: (\(sphereDepthTextureWidth), \(sphereDepthTextureWidth))")
            }
            depthTexture.label = "Depth texture"

            renderDepthTexture(targetModelViewProjMatrix: rotationMatrix, buffer: commandBuffer, depthTexture: depthTexture)
            renderAmbientOcclusion(targetModelViewProjMatrix: rotationMatrix, buffer: commandBuffer, depthTexture: depthTexture, intensityFactor: intensityFactor)

            rotationMatrix = Matrix4x4.identity.rotated(angle: theta + (.pi / 8.0), x: 1.0, y: 0.0, z: 0.0)
            rotationMatrix = rotationMatrix.rotated(angle: phi + (.pi / 8.0), x: 0.0, y: 1.0, z: 0.0)

            renderDepthTexture(targetModelViewProjMatrix: rotationMatrix, buffer: commandBuffer, depthTexture: depthTexture)
            renderAmbientOcclusion(targetModelViewProjMatrix: rotationMatrix, buffer: commandBuffer, depthTexture: depthTexture, intensityFactor: intensityFactor)
        }

        commandBuffer.commit()
    }

    func renderDepthTexture(targetModelViewProjMatrix: Matrix4x4, buffer: MTLCommandBuffer, depthTexture: MTLTexture) {
        let orthographicMatrix = orthographicMatrix(left: -1.0, right: 1.0, bottom: Float(-1.0 * 1024 / 1024), top: Float(1024 / 1024), near: -1.0, far: 1.0)

        let depthStencilDescriptor1 = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float,
                                                                               width: 1024,
                                                                               height: 1024,
                                                                               mipmapped: false)
        depthStencilDescriptor1.storageMode = .private
        depthStencilDescriptor1.usage = [.renderTarget, .shaderRead, .shaderWrite]
        guard let depthStencil = sharedMetalRenderingDevice.device.makeTexture(descriptor: depthStencilDescriptor1) else {
            fatalError("Could not create depth stencil texture)")
        }
        depthStencil.label = "Depth stencil"

        let renderPass = MTLRenderPassDescriptor()
        renderPass.depthAttachment.texture = depthStencil
        renderPass.colorAttachments[0].texture = depthTexture
        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1)
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].loadAction = .clear

        guard let renderEncoder = buffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            fatalError("Could not create render encoder")
        }
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setRenderPipelineState(sharedMetalRenderingDevice.sphereDepthPipelineState)

        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .lessEqual
        depthStencilDescriptor.isDepthWriteEnabled = true
        let depthStencilState = sharedMetalRenderingDevice.device.makeDepthStencilState(descriptor: depthStencilDescriptor)
        renderEncoder.setDepthStencilState(depthStencilState)

        let atomRadiusScaleFactor: Float
        switch visualizationStyle {
        case .spacefilling: atomRadiusScaleFactor = 1.0
        case .ballAndStick: atomRadiusScaleFactor = 0.35
        }

        let moleculeScaleFactor = molecule.overallScaleFactor

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
            let vertexUniforms = sphereDepthVertexUniforms(modelViewProjMatrix: targetModelViewProjMatrix,
                                                           orthographicMatrix: orthographicMatrix,
                                                           sphereRadius: element.vanderWaalsRadius * moleculeScaleFactor * atomRadiusScaleFactor,
                                                           translation: Coordinate(x: 0.0, y: 0.0, z: 0.0))
            let vertexUniformBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: vertexUniforms,
                                                                                   length: vertexUniforms.count * MemoryLayout<Float>.size,
                                                                                   options: [])!
            renderEncoder.setVertexBuffer(vertexUniformBuffer, offset: 0, index: 3)

            // Setting sphere fragment buffers.
            let fragmentUniforms = sphereDepthFragmentUniforms(inverseModelViewProjMatrix: targetModelViewProjMatrix.inverted(),
                                                               ambientOcclusionTextureWidth: normalizedAOTexturePatchWidth)
            let fragmentUniformBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: fragmentUniforms,
                                                                                     length: fragmentUniforms.count * MemoryLayout<Float>.size,
                                                                                     options: [])!
            renderEncoder.setFragmentBuffer(fragmentUniformBuffer, offset: 0, index: 1)

            // Draw all spheres for an element.
            renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: sphereIndexBufferCount, indexType: .uint16, indexBuffer: sphereIndexBuffer, indexBufferOffset: 0)
        }
        renderEncoder.endEncoding()
    }

    func renderAmbientOcclusion(targetModelViewProjMatrix: Matrix4x4, buffer: MTLCommandBuffer, depthTexture: MTLTexture, intensityFactor: Float) {
        let orthographicMatrix = orthographicMatrix(left: -1.0, right: 1.0, bottom: Float(-1.0 * 1024 / 1024), top: Float(1024 / 1024), near: -1.0, far: 1.0)

        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = sphereAmbientOcclusionTexture
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].loadAction = .load

        guard let renderEncoder = buffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            fatalError("Could not create render encoder")
        }
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setRenderPipelineState(sharedMetalRenderingDevice.sphereAmbientOcclusionPipelineState)

        let atomRadiusScaleFactor: Float
        switch visualizationStyle {
        case .spacefilling: atomRadiusScaleFactor = 1.0
        case .ballAndStick: atomRadiusScaleFactor = 0.35
        }

        let moleculeScaleFactor = molecule.overallScaleFactor

        for element in Atom.Element.allCases {
            guard let sphereIndexBuffer = sphereIndexBuffers[element],
                  let sphereIndexBufferCount = sphereIndexBufferCounts[element],
                  let sphereVertexBuffer = sphereVertexBuffers[element],
                  let sphereImpostorSpaceCoordinateBuffer = sphereImpostorSpaceCoordinateBuffers[element],
                  let sphereAmbientOcclusionTextureOffsetBuffer = sphereAmbientOcclusionTextureOffsetBuffers[element] else {
                continue
            }

            // Setting sphere vertex buffers.
            renderEncoder.setVertexBuffer(sphereVertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(sphereImpostorSpaceCoordinateBuffer, offset: 0, index: 1)
            renderEncoder.setVertexBuffer(sphereAmbientOcclusionTextureOffsetBuffer, offset: 0, index: 2)
            let vertexUniforms = sphereAmbientOcclusionVertexUniforms(modelViewProjMatrix: targetModelViewProjMatrix,
                                                                      orthographicMatrix: orthographicMatrix,
                                                                      sphereRadius: element.vanderWaalsRadius * moleculeScaleFactor * atomRadiusScaleFactor,
                                                                      ambientOcclusionTexturePatchWidth: normalizedAOTexturePatchWidth)
            let vertexUniformBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: vertexUniforms,
                                                                                   length: vertexUniforms.count * MemoryLayout<Float>.size,
                                                                                   options: [])!
            renderEncoder.setVertexBuffer(vertexUniformBuffer, offset: 0, index: 3)

            // Setting sphere fragment buffers.
            let fragmentUniforms = sphereAmbientOcclusionFragmentUniforms(modelViewProjMatrix: targetModelViewProjMatrix,
                                                                          inverseModelViewProjMatrix: targetModelViewProjMatrix.inverted(),
                                                                          intensityFactor: intensityFactor)
            let fragmentUniformBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: fragmentUniforms,
                                                                                     length: fragmentUniforms.count * MemoryLayout<Float>.size,
                                                                                     options: [])!
            renderEncoder.setFragmentBuffer(fragmentUniformBuffer, offset: 0, index: 1)
            renderEncoder.setFragmentTexture(depthTexture, index: 0)

            // Draw all spheres for an element.
            renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: sphereIndexBufferCount, indexType: .uint16, indexBuffer: sphereIndexBuffer, indexBufferOffset: 0)
        }
        renderEncoder.endEncoding()

    }

    func renderMoleculeFrame(width: CGFloat, height: CGFloat, buffer: MTLCommandBuffer, renderPass: MTLRenderPassDescriptor) {
        let sphereDepthTextureWidth = 1024
        let depthTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,
                                                                              width: sphereDepthTextureWidth,
                                                                              height: sphereDepthTextureWidth,
                                                                              mipmapped: false)
        depthTextureDescriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        guard let depthTexture = sharedMetalRenderingDevice.device.makeTexture(descriptor: depthTextureDescriptor) else {
            fatalError("Could not create depth texture of size: (\(sphereDepthTextureWidth), \(sphereDepthTextureWidth))")
        }
        depthTexture.label = "Depth texture"
//        renderDepthTexture(buffer: buffer, depthTexture: depthTexture)
//        renderAmbientOcclusion(buffer: buffer, depthTexture: depthTexture, intensityFactor: 1.0)


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

        let atomRadiusScaleFactor: Float
        switch visualizationStyle {
        case .spacefilling: atomRadiusScaleFactor = 1.0
        case .ballAndStick: atomRadiusScaleFactor = 0.35
        }

        let moleculeScaleFactor = molecule.overallScaleFactor * currentScale

        // TODO: Generalize iterating over all atoms for the multiple render pass variants.
        for element in Atom.Element.allCases {
            guard let sphereIndexBuffer = sphereIndexBuffers[element],
                  let sphereIndexBufferCount = sphereIndexBufferCounts[element],
                  let sphereVertexBuffer = sphereVertexBuffers[element],
                  let sphereImpostorSpaceCoordinateBuffer = sphereImpostorSpaceCoordinateBuffers[element],
                  let sphereAmbientOcclusionTextureOffsetBuffer = sphereAmbientOcclusionTextureOffsetBuffers[element] else {
                continue
            }

            // Setting sphere vertex buffers.
            renderEncoder.setVertexBuffer(sphereVertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(sphereImpostorSpaceCoordinateBuffer, offset: 0, index: 1)
            renderEncoder.setVertexBuffer(sphereAmbientOcclusionTextureOffsetBuffer, offset: 0, index: 2)
            let vertexUniforms = sphereVertexUniforms(modelViewProjMatrix: modelViewProjMatrix,
                                                      orthographicMatrix: orthographicMatrix,
                                                      sphereRadius: element.vanderWaalsRadius * moleculeScaleFactor * atomRadiusScaleFactor,
                                                      translation: currentTranslation)
            let vertexUniformBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: vertexUniforms,
                                                                                   length: vertexUniforms.count * MemoryLayout<Float>.size,
                                                                                   options: [])!
            renderEncoder.setVertexBuffer(vertexUniformBuffer, offset: 0, index: 3)

            // Setting sphere fragment buffers.
            let fragmentUniforms = sphereFragmentUniforms(sphereColor: element.color,
                                                          inverseModelViewProjMatrix: modelViewProjMatrix.inverted(),
                                                          ambientOcclusionTextureWidth: normalizedAOTexturePatchWidth)
            let fragmentUniformBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: fragmentUniforms,
                                                                                     length: fragmentUniforms.count * MemoryLayout<Float>.size,
                                                                                     options: [])!
            renderEncoder.setFragmentBuffer(fragmentUniformBuffer, offset: 0, index: 1)
            renderEncoder.setFragmentTexture(sphereAmbientOcclusionTexture, index: 0)

            // Draw all spheres for an element.
            renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: sphereIndexBufferCount, indexType: .uint16, indexBuffer: sphereIndexBuffer, indexBufferOffset: 0)
        }

        if visualizationStyle == .ballAndStick, molecule.bonds.count > 0 {
            renderEncoder.setRenderPipelineState(sharedMetalRenderingDevice.cylinderRaytracingPipelineState)

            // Setting cylinder vertex buffers.
            let bondRadius: Float = 1.0
            let bondRadiusScaleFactor: Float = 0.15
            let bondColor = Atom.Element.Color(0.75, 0.75, 0.75)
            renderEncoder.setVertexBuffer(cylinderVertexBuffer, offset: 0, index: 0)
            renderEncoder.setVertexBuffer(cylinderDirectionBuffer, offset: 0, index: 1)
            renderEncoder.setVertexBuffer(cylinderImpostorSpaceCoordinateBuffer, offset: 0, index: 2)
            let vertexUniforms = cylinderVertexUniforms(modelViewProjMatrix: modelViewProjMatrix,
                                                        orthographicMatrix: orthographicMatrix,
                                                        cylinderRadius: bondRadius * moleculeScaleFactor * bondRadiusScaleFactor,
                                                        translation: currentTranslation)
            let vertexUniformBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: vertexUniforms,
                                                                                   length: vertexUniforms.count * MemoryLayout<Float>.size,
                                                                                   options: [])!
            renderEncoder.setVertexBuffer(vertexUniformBuffer, offset: 0, index: 4)

            // Setting cylinder fragment buffers.
            let fragmentUniforms = cylinderFragmentUniforms(cylinderColor: bondColor,
                                                            inverseModelViewProjMatrix: modelViewProjMatrix.inverted())
            let fragmentUniformBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: fragmentUniforms,
                                                                                     length: fragmentUniforms.count * MemoryLayout<Float>.size,
                                                                                     options: [])!
            renderEncoder.setFragmentBuffer(fragmentUniformBuffer, offset: 0, index: 1)

            // Draw all cylinders for bonds.
            if let cylinderIndexBuffer = cylinderIndexBuffer {
                renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: cylinderIndexBufferCount, indexType: .uint16, indexBuffer: cylinderIndexBuffer, indexBufferOffset: 0)
            }
        }

        renderEncoder.endEncoding()
    }

    func sphereVertexUniforms(modelViewProjMatrix: Matrix4x4, orthographicMatrix: Matrix4x4, sphereRadius: Float, translation: Coordinate) -> [Float] {
        return modelViewProjMatrix.toFloatArray() + orthographicMatrix.toFloatArray() + [sphereRadius, 0.0, 0.0, 0.0, translation.x, translation.y, translation.z, 0.0]
    }

    func sphereFragmentUniforms(sphereColor: Atom.Element.Color, inverseModelViewProjMatrix: Matrix4x4, ambientOcclusionTextureWidth: Float) -> [Float] {
        return [sphereColor.red, sphereColor.green, sphereColor.blue, 0.0] + inverseModelViewProjMatrix.toFloatArray() + [ambientOcclusionTextureWidth, 0.0, 0.0, 0.0]
    }

    func cylinderVertexUniforms(modelViewProjMatrix: Matrix4x4, orthographicMatrix: Matrix4x4, cylinderRadius: Float, translation: Coordinate) -> [Float] {
        return modelViewProjMatrix.toFloatArray() + orthographicMatrix.toFloatArray() + [cylinderRadius, 0.0, 0.0, 0.0, translation.x, translation.y, translation.z, 0.0]
    }

    func cylinderFragmentUniforms(cylinderColor: Atom.Element.Color, inverseModelViewProjMatrix: Matrix4x4) -> [Float] {
        return [cylinderColor.red, cylinderColor.green, cylinderColor.blue, 0.0] + inverseModelViewProjMatrix.toFloatArray()
    }

    func sphereDepthVertexUniforms(modelViewProjMatrix: Matrix4x4, orthographicMatrix: Matrix4x4, sphereRadius: Float, translation: Coordinate) -> [Float] {
        return modelViewProjMatrix.toFloatArray() + orthographicMatrix.toFloatArray() + [sphereRadius, 0.0, 0.0, 0.0, translation.x, translation.y, translation.z, 0.0]
    }

    func sphereDepthFragmentUniforms(inverseModelViewProjMatrix: Matrix4x4, ambientOcclusionTextureWidth: Float) -> [Float] {
        return inverseModelViewProjMatrix.toFloatArray() + [ambientOcclusionTextureWidth, 0.0, 0.0, 0.0]
    }

    func sphereAmbientOcclusionVertexUniforms(modelViewProjMatrix: Matrix4x4, orthographicMatrix: Matrix4x4, sphereRadius: Float, ambientOcclusionTexturePatchWidth: Float) -> [Float] {
        return modelViewProjMatrix.toFloatArray() + orthographicMatrix.toFloatArray() + [sphereRadius] + [ambientOcclusionTexturePatchWidth, 0.0, 0.0]
    }

    func sphereAmbientOcclusionFragmentUniforms(modelViewProjMatrix: Matrix4x4, inverseModelViewProjMatrix: Matrix4x4, intensityFactor: Float) -> [Float] {
        return modelViewProjMatrix.toFloatArray() + inverseModelViewProjMatrix.toFloatArray() + [intensityFactor, 0.0, 0.0, 0.0]
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
    normalizedAOTexturePatchWidth: Float,
    currentAmbientOcclusionTextureOffset: inout (Float, Float),
    ambientOcclusionTextureOffsets: inout [Float],
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
        currentIndex + 3, currentIndex + 1, currentIndex + 7,
    ]
    indices += octagonIndices

    currentIndex += 8

    for _ in 0..<8 {
        ambientOcclusionTextureOffsets.append(currentAmbientOcclusionTextureOffset.0)
        ambientOcclusionTextureOffsets.append(currentAmbientOcclusionTextureOffset.1)
    }

    var newOffsetInX = currentAmbientOcclusionTextureOffset.0 + normalizedAOTexturePatchWidth
    var newOffsetInY = currentAmbientOcclusionTextureOffset.1
    if newOffsetInX > (1.0 - (normalizedAOTexturePatchWidth * 0.15)) {
        newOffsetInX = normalizedAOTexturePatchWidth / 2.0
        newOffsetInY += normalizedAOTexturePatchWidth
    }
    currentAmbientOcclusionTextureOffset = (newOffsetInX, newOffsetInY)
}

func appendRectangularBondVertices(
    start: Coordinate,
    end: Coordinate,
    currentIndex: inout UInt16,
    indices: inout [UInt16],
    vertices: inout [Float],
    directions: inout [Float],
    impostorSpaceCoordinates: inout [Float]
) {
    // TODO: Switch to using 32-bit indexing to expand geometry size.
    guard currentIndex < 65530 else { return }

    // Add the start and end points twice, to be displaced in the vertex shader.
    let startVertex = [-start.x, start.y, start.z]
    vertices.append(contentsOf: startVertex)
    vertices.append(contentsOf: startVertex)
    let endVertex = [-end.x, end.y, end.z]
    vertices.append(contentsOf: endVertex)
    vertices.append(contentsOf: endVertex)

    // The same bond direction is used by each vertex.
    let cylinderDirection = [start.x - end.x, end.y - start.y, end.z - start.z]
    for _ in 0..<4 {
        directions.append(contentsOf: cylinderDirection)
    }

    let cylinderImpostorCoordinates: [Float] = [
        -1.0, -1.0,
         1.0, -1.0,
        -1.0,  1.0,
         1.0,  1.0
    ]
    impostorSpaceCoordinates += cylinderImpostorCoordinates

    let cylinderIndices: [UInt16] = [
        currentIndex,
        currentIndex + 1,
        currentIndex + 2,
        currentIndex + 1,
        currentIndex + 3,
        currentIndex + 2
    ]
    indices.append(contentsOf: cylinderIndices)
    currentIndex += 4
}
