import Foundation
import MetalKit
import SwiftUI

public class MetalRenderView: MTKView {
    
    var molecule: MolecularStructure!
    var moleculeVertexBuffer: MTLBuffer!
    
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
        let moleculeVertices: [Float] = [
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0
        ]
        
        // const device packed_float3 *position [[buffer(0)]],
        let vertexBuffer = sharedMetalRenderingDevice.device.makeBuffer(bytes: moleculeVertices,
                                                                        length: moleculeVertices.count * MemoryLayout<Float>.size,
                                                                        options: [])!

        // const device packed_float2 *inputImpostorSpaceCoordinate [[buffer(1)]],
        let moleculeVertices: [Float] = [
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0,
            0.0, 0.0, 0.0
        ]

//        constant SphereRaytracingVertexUniform& uniform [[buffer(3)]],
        print("Number of atoms to initialize: \(molecule.atoms.count)")
    }
    
    func renderMoleculeFrame() {
        
    }
}
