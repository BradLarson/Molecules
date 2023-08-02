import Foundation
import MetalKit
import SwiftUI

protocol MetalRenderViewStatusDelegate: NSObject {
    func updateAutorotation(rotating: Bool)
}

class MetalRenderView: MTKView {
    
    var moleculeRenderer: MoleculeRenderer!

    var rotationGestureRecognizer: UIPanGestureRecognizer!
    var scaleGestureRecognizer: UIPinchGestureRecognizer!
    var panGestureRecognizer: UIPanGestureRecognizer!
    var lastTranslation = CGPoint.zero
    var lastScale: CGFloat = 1.0
    var autoRotating: Bool = true {
        didSet {
            autorotationDisplayLink.isPaused = !autoRotating
            if !autoRotating {
                statusDelegate?.updateAutorotation(rotating: false)
            }
        }
    }
    var autorotationDisplayLink: CADisplayLink!
    weak var statusDelegate: MetalRenderViewStatusDelegate?
    var hasPresented = false

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

        self.autorotationDisplayLink = CADisplayLink(
            target: self,
            selector: #selector(autorotationStep)
        )
        self.autorotationDisplayLink.add(to: .main, forMode: .default)
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

    @objc func autorotationStep(displaylink: CADisplayLink) {
        moleculeRenderer.rotateFromTouch(
            x: 1.0,
            y: 0.0)
        self.setNeedsDisplay()
    }

    // FIXME: I should set up a more elegant way of handing switchover of renderers.
    func pauseRendering() {
        autorotationDisplayLink.isPaused = true
    }

    func resumeRendering() {
        autorotationDisplayLink.isPaused = false
        self.autoRotating = true
    }

    deinit {
        autorotationDisplayLink.isPaused = true
        autorotationDisplayLink.invalidate()
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
    @Binding var visualizationStyle: MoleculeVisualizationStyle

    init(molecule: Binding<MolecularStructure>, autorotate: Binding<Bool>, visualizationStyle: Binding<MoleculeVisualizationStyle>) {
        self._molecule = molecule
        self._autorotate = autorotate
        self._visualizationStyle = visualizationStyle
    }
    
    func makeUIView(context: Context) -> MetalRenderView {
        let view = MetalRenderView(frame: .zero, device: nil)
        DispatchQueue.main.async {
            self.visualizationStyle = molecule.defaultVisualizationStyle
            view.hasPresented = true
        }

        view.moleculeRenderer = MoleculeRenderer(molecule: molecule, visualizationStyle: molecule.defaultVisualizationStyle)
        view.statusDelegate = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: MetalRenderView, context: Context) {
        if (visualizationStyle != uiView.moleculeRenderer.visualizationStyle) && uiView.hasPresented {
            uiView.pauseRendering()
            // Store and load previous render state.
            let previousScale = uiView.moleculeRenderer.currentScale
            var previousTranslation = uiView.moleculeRenderer.currentTranslation
            var previousModelViewProjMatrix = uiView.moleculeRenderer.modelViewProjMatrix

            uiView.moleculeRenderer = MoleculeRenderer(molecule: molecule, visualizationStyle: visualizationStyle)

            uiView.moleculeRenderer.currentScale = previousScale
            uiView.moleculeRenderer.currentTranslation = previousTranslation
            uiView.moleculeRenderer.modelViewProjMatrix = previousModelViewProjMatrix

            uiView.setNeedsDisplay()
            uiView.resumeRendering()
        } else {
            uiView.autoRotating = autorotate
        }
    }
    
    func dismantleUIView(_ uiView: MetalRenderView, coordinator: Coordinator) {
    }

    class Coordinator: NSObject, MetalRenderViewStatusDelegate {
        var parent: MetalView

        init(_ parent: MetalView) {
            self.parent = parent
        }

        func updateAutorotation(rotating: Bool) {
            DispatchQueue.main.async {
                self.parent.autorotate = rotating
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
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
