import Foundation
import MetalKit
import SwiftUI

class MetalRenderView: MTKView {
    
    var moleculeRenderer: MoleculeRenderer!

    var rotationGestureRecognizer: UIPanGestureRecognizer!
    var scaleGestureRecognizer: UIPinchGestureRecognizer!
    var panGestureRecognizer: UIPanGestureRecognizer!
    var lastTranslation = CGPoint.zero
    var lastScale: CGFloat = 1.0
    // TODO: Communicate change in autorotation upwards to SwiftUI.
    var autoRotating: Bool = true

    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: sharedMetalRenderingDevice.device)
        
        commonInit()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        
        commonInit()
    }
    
    private func commonInit() {
        // Configure all touch interactions for the molecule rendering.
        self.rotationGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(rotated))
        self.addGestureRecognizer(self.rotationGestureRecognizer)
        self.scaleGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(scaled))
        self.addGestureRecognizer(self.scaleGestureRecognizer)
        self.panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(panned))
        self.panGestureRecognizer.minimumNumberOfTouches = 2
        self.addGestureRecognizer(self.panGestureRecognizer)

        self.framebufferOnly = true
        self.autoResizeDrawable = true
        self.depthStencilPixelFormat = .depth32Float
        self.device = sharedMetalRenderingDevice.device
        
        self.enableSetNeedsDisplay = true
        self.isPaused = true
    }
    
    override func draw(_ rect:CGRect) {
        guard let drawable = self.currentDrawable else {
            print("No drawable")
            return
        }
        guard let moleculeRenderer = moleculeRenderer else {
            print("No molecule renderer")
            return
        }
        if let commandBuffer = sharedMetalRenderingDevice.commandQueue.makeCommandBuffer(),
           let renderPass = self.currentRenderPassDescriptor {
            moleculeRenderer.renderMoleculeFrame(width: self.frame.width, height: self.frame.height, buffer: commandBuffer, renderPass: renderPass)
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

// MARK: -
// MARK: Gesture recognition

extension MetalRenderView {
    @objc func rotated(_ sender: UIPanGestureRecognizer) {
        self.autoRotating = false
        let currentTranslation = sender.translation(in: self)
        if sender.state == .began {
            lastTranslation = CGPoint.zero
        }
        moleculeRenderer.rotateFromTouch(
            x: Float(lastTranslation.x - currentTranslation.x),
            y: Float(lastTranslation.y - currentTranslation.y))
        lastTranslation = currentTranslation
        self.setNeedsDisplay()
    }

    @objc func scaled(_ sender: UIPinchGestureRecognizer) {
        self.autoRotating = false
        let currentScale = sender.scale
        if sender.state == .began {
            lastScale = 1.0
        }
        guard lastScale >= 0.01 else {
            lastScale = currentScale
            return
        }
        moleculeRenderer.scaleFromTouch(scale: Float(currentScale / lastScale))
        lastScale = currentScale
        self.setNeedsDisplay()
    }

    @objc func panned(_ sender: UIPanGestureRecognizer) {
        self.autoRotating = false
        let currentTranslation = sender.translation(in: self)
        if sender.state == .began {
            lastTranslation = CGPoint.zero
        }
        moleculeRenderer.translateFromTouch(
            x: Float(currentTranslation.x - lastTranslation.x),
            y: Float(lastTranslation.y - currentTranslation.y),
            backingWidth: Float(self.frame.width)
        )
        lastTranslation = currentTranslation
        self.setNeedsDisplay()
    }
}

// MARK: -
// MARK: SwiftUI bridging.

struct MetalView: UIViewRepresentable {
    @Binding var molecule: MolecularStructure
    @Binding var autorotate: Bool
    
    init(molecule: Binding<MolecularStructure>, autorotate: Binding<Bool>) {
        self._molecule = molecule
        self._autorotate = autorotate
    }
    
    func makeUIView(context: Context) -> MetalRenderView {
        let view = MetalRenderView(frame: .zero, device: nil)
        view.moleculeRenderer = MoleculeRenderer(molecule: molecule)
        return view
    }
    
    func updateUIView(_ uiView: MetalRenderView, context: Context) {
        // TODO: Enable or disable the autorotation loop.
        uiView.autoRotating = autorotate
        print("Autorotate: \(autorotate)")
        print("updating view")
    }
    
    func dismantleUIView(_ uiView: MetalRenderView, coordinator: Coordinator) {
        print("dismantling view")
        // TODO: Handle removing the view
    }
}

// MARK: -
// MARK: Metal rendering.

extension MTLCommandBuffer {
    func clear(texture: MTLTexture, with color: MTLClearColor) {
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = texture
        renderPass.colorAttachments[0].clearColor = color
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].loadAction = .clear

        guard let renderEncoder = self.makeRenderCommandEncoder(descriptor: renderPass) else {
            fatalError("Could not create render encoder")
        }
        renderEncoder.endEncoding()
    }
}