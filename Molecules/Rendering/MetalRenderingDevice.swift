import MetalKit

let sharedMetalRenderingDevice = MetalRenderingDevice()

/// The MetalRenderingDevice is shared across all Metal rendering, setting up the Metal device
/// and all shaders once for the lifetime of the application.
class MetalRenderingDevice {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let shaderLibrary: MTLLibrary
    let sphereRaytracingPipelineState: MTLRenderPipelineState
    let cylinderRaytracingPipelineState: MTLRenderPipelineState
    let sphereDepthPipelineState: MTLRenderPipelineState
    let sphereAmbientOcclusionPipelineState: MTLRenderPipelineState

    init() {
        // Configure the Metal device and command queue.
        guard let device = MTLCreateSystemDefaultDevice() else {fatalError("Could not create Metal Device")}
        self.device = device
        
        guard let queue = self.device.makeCommandQueue() else {fatalError("Could not create command queue")}
        self.commandQueue = queue

        // Set up the shader library.
        do {
            let frameworkBundle = Bundle(for: MetalRenderingDevice.self)
            let metalLibraryPath = frameworkBundle.url(forResource: "default", withExtension: "metallib")!

            self.shaderLibrary = try device.makeLibrary(URL: metalLibraryPath)
        } catch {
            fatalError("Could not load library: \(error)")
        }

        do {
            self.sphereRaytracingPipelineState = try self.shaderLibrary.pipelineState(device: self.device, vertex: "sphereRaytracingVertex", fragment: "sphereRaytracingFragment")
            self.cylinderRaytracingPipelineState = try self.shaderLibrary.pipelineState(device: self.device, vertex: "cylinderRaytracingVertex", fragment: "cylinderRaytracingFragment")
            self.sphereDepthPipelineState = try self.shaderLibrary.pipelineState(device: self.device, vertex: "sphereDepthVertex", fragment: "sphereDepthFragment", blendOperation: .min)
            self.sphereAmbientOcclusionPipelineState = try self.shaderLibrary.pipelineState(device: self.device, vertex: "sphereAmbientOcclusionVertex", fragment: "sphereAmbientOcclusionFragment", enableDepth: false, blendOperation: .add)
        } catch {
            fatalError("Could not load shader function with error: \(error)")
        }
    }
}

extension MTLLibrary {
    func pipelineState(device: MTLDevice, vertex: String, fragment: String, enableDepth: Bool = true, blendOperation: MTLBlendOperation? = nil) throws -> MTLRenderPipelineState {
        guard let vertexFunction = self.makeFunction(name: vertex) else {
            fatalError("Could not load vertex function \(vertex)")
        }

        guard let fragmentFunction = self.makeFunction(name: fragment) else {
            fatalError("Could not load fragment function \(fragment)")
        }

        let descriptor = MTLRenderPipelineDescriptor()
        if enableDepth {
            descriptor.depthAttachmentPixelFormat = .depth32Float
        }

        if let blendOperation = blendOperation {
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].rgbBlendOperation = blendOperation
            descriptor.colorAttachments[0].alphaBlendOperation = blendOperation
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        }
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.rasterSampleCount = 1
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction

        return try device.makeRenderPipelineState(descriptor: descriptor)
    }
}
