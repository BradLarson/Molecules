import Foundation
import MetalKit
import SwiftUI

public class MetalRenderView: MTKView {
    
    var molecule: MolecularStructure!
    var moleculeVertexBuffer: MTLBuffer!
    var moleculeImpostorSpaceCoordinateBuffer: MTLBuffer!
    var moleculeIndexBuffer: MTLBuffer!

    public override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: sharedMetalRenderingDevice.device)
        
        commonInit()
    }
    
    public required init(coder: NSCoder) {
        super.init(coder: coder)
        
        commonInit()
    }
    
    private func commonInit() {
        framebufferOnly = false
        autoResizeDrawable = true
        
        self.device = sharedMetalRenderingDevice.device
        
        enableSetNeedsDisplay = true
        isPaused = true
    }
    
    public override func draw(_ rect:CGRect) {
        print("Draw")
        guard let drawable = self.currentDrawable else {
            print("No drawable")
            return
        }
        let commandBuffer = sharedMetalRenderingDevice.commandQueue.makeCommandBuffer()
        let rpd = self.currentRenderPassDescriptor
        rpd?.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 1.0, 0.0, 1.0)
        rpd?.colorAttachments[0].loadAction = .clear
        rpd?.colorAttachments[0].storeAction = .store
        let re = commandBuffer?.makeRenderCommandEncoder(descriptor: rpd!)
        re?.endEncoding()
        commandBuffer?.present(drawable)
        commandBuffer?.commit()
    }
}

struct MetalView: UIViewRepresentable {
    @Binding var molecule: MolecularStructure
    
    init(molecule: Binding<MolecularStructure>) {
        self._molecule = molecule
    }
    
    func makeUIView(context: Context) -> MetalRenderView {
        let view = MetalRenderView(frame: .zero, device: nil)
        view.molecule = molecule
        view.initializeMoleculeBuffers()
        return view
    }
    
    func updateUIView(_ uiView: MetalRenderView, context: Context) {
        print("updating view")
    }
    
    func dismantleUIView(_ uiView: MetalRenderView, coordinator: Coordinator) {
        print("dismantling view")
        // TODO: Handle removing the view
    }
}

extension MetalRenderView {
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

        // const device packed_float3 *position [[buffer(0)]],
        moleculeVertexBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: moleculeVertices,
                                                                            length: moleculeVertices.count * MemoryLayout<Float>.size,
                                                                            options: [])!


        // const device packed_float2 *inputImpostorSpaceCoordinate [[buffer(1)]],
        moleculeImpostorSpaceCoordinateBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: moleculeImpostorSpaceCoordinates,
                                                                            length: moleculeImpostorSpaceCoordinates.count * MemoryLayout<Float>.size,
                                                                            options: [])!


        // TODO: Complete cylinder impostors.

        print("Number of atoms to initialize: \(molecule.atoms.count)")
    }
    
    func renderMoleculeFrame() {
        
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
        currentIndex + 2, currentIndex, currentIndex + 3,
        currentIndex + 2, currentIndex + 3, currentIndex + 4,
        currentIndex, currentIndex + 2, currentIndex + 5,
        currentIndex + 1, currentIndex, currentIndex + 6,
        currentIndex + 3, currentIndex + 1, currentIndex + 7
    ]
    indices += octagonIndices

    currentIndex += 8
}
