import MetalKit

let sharedMetalRenderingDevice = MetalRenderingDevice()

/// The MetalRenderingDevice is shared across all Metal rendering, setting up the Metal device
/// and all shaders once for the lifetime of the application.
class MetalRenderingDevice {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let shaderLibrary: MTLLibrary
    let sphereRaytracingDescriptor: MTLRenderPipelineDescriptor
    let sphereRaytracingPipelineState: MTLRenderPipelineState
    let cylinderRaytracingDescriptor: MTLRenderPipelineDescriptor
    let cylinderRaytracingPipelineState: MTLRenderPipelineState

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
            fatalError("Could not load library")
        }

        // Create the render pipeline state for the sphere raytracing shader.
        guard let sphereVertexFunction = self.shaderLibrary.makeFunction(name: "sphereRaytracingVertex") else {
            fatalError("Sphere raytracing: could not load vertex function sphereRaytracingVertex")
        }

        guard let sphereFragmentFunction = self.shaderLibrary.makeFunction(name: "sphereRaytracingFragment") else {
            fatalError("Sphere raytracing: could not load fragment function sphereRaytracingFragment")
        }

        self.sphereRaytracingDescriptor = MTLRenderPipelineDescriptor()
        self.sphereRaytracingDescriptor.depthAttachmentPixelFormat = .depth32Float
        self.sphereRaytracingDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        self.sphereRaytracingDescriptor.rasterSampleCount = 1
        self.sphereRaytracingDescriptor.vertexFunction = sphereVertexFunction
        self.sphereRaytracingDescriptor.fragmentFunction = sphereFragmentFunction

        do {
            self.sphereRaytracingPipelineState = try self.device.makeRenderPipelineState(descriptor: self.sphereRaytracingDescriptor)
        } catch {
            // TODO: Examine the potential error cases here.
            fatalError("Unable to create sphere raytracing render pipeline state with error: \(error)")
        }

        // Create the render pipeline state for the cylinder raytracing shader.
        guard let cylinderVertexFunction = self.shaderLibrary.makeFunction(name: "cylinderRaytracingVertex") else {
            fatalError("Cylinder raytracing: could not load vertex function cylinderRaytracingVertex")
        }

        guard let cylinderFragmentFunction = self.shaderLibrary.makeFunction(name: "cylinderRaytracingFragment") else {
            fatalError("Cylinder raytracing: could not load fragment function cylinderRaytracingFragment")
        }

        self.cylinderRaytracingDescriptor = MTLRenderPipelineDescriptor()
        self.cylinderRaytracingDescriptor.depthAttachmentPixelFormat = .depth32Float
        self.cylinderRaytracingDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        self.cylinderRaytracingDescriptor.rasterSampleCount = 1
        self.cylinderRaytracingDescriptor.vertexFunction = cylinderVertexFunction
        self.cylinderRaytracingDescriptor.fragmentFunction = cylinderFragmentFunction

        do {
            self.cylinderRaytracingPipelineState = try self.device.makeRenderPipelineState(descriptor: self.cylinderRaytracingDescriptor)
        } catch {
            // TODO: Examine the potential error cases here.
            fatalError("Unable to create cylinder raytracing render pipeline state with error: \(error)")
        }

    }
}
