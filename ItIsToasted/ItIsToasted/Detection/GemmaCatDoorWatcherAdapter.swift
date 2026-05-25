import CoreVideo
import Foundation

final class GemmaCatDoorWatcherAdapter: PhoneLocalWatcherRuntime {
    let catDoorSpec: CatDoorWatcherSpec
    var spec: WatcherSpec { catDoorSpec.base }
    let runtimeDisplayName = "Phone-local Gemma GGUF watcher path"
    let runtimePathSummary = "Uses the on-device GGUF Gemma runtime for model startup validation and records captured frames, but does not pretend first-frame image-conditioned inference works until a GGUF-compatible multimodal iOS API is actually available in the app."

    private let gemmaRuntime = OnDeviceGemmaRuntime()
    private var startupValidationSummary: String?
    private var startupValidationError: String?
    private var didSeeFirstFrame = false
    private var firstFrameDimensions: String?

    init(spec: CatDoorWatcherSpec = .default) {
        self.catDoorSpec = spec
    }

    func reset() {
        startupValidationSummary = nil
        startupValidationError = nil
        didSeeFirstFrame = false
        firstFrameDimensions = nil
    }

    func startSession() throws {
        startupValidationError = nil
        startupValidationSummary = try gemmaRuntime.generateSmokeTestResponse(for: spec)
    }

    func analyze(pixelBuffer: CVPixelBuffer, threshold: Double) -> ToastWatcherFrameResult {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        if !didSeeFirstFrame {
            didSeeFirstFrame = true
            firstFrameDimensions = "\(width)x\(height)"
        }

        if let startupValidationError {
            return ToastWatcherFrameResult(
                watcher: WatcherAnalysis(
                    sceneStatus: .unknown,
                    label: "uncertain",
                    confidence: 0,
                    shouldAlert: false,
                    reason: "Gemma GGUF runtime startup failed before frame interpretation: \(startupValidationError)"
                ),
                toast: nil
            )
        }

        let reason: String
        if let firstFrameDimensions {
            reason = """
            First frame captured at \(firstFrameDimensions) and recorded, and the GGUF Gemma runtime started successfully. \
            This app does not currently include a GGUF-compatible multimodal iOS API that can ingest the frame into Gemma directly, \
            so no image-conditioned cat-door inference was attempted.
            """
        } else {
            reason = """
            GGUF Gemma runtime started successfully, but no captured frame has been recorded yet.
            """
        }

        return ToastWatcherFrameResult(
            watcher: WatcherAnalysis(
                sceneStatus: .unknown,
                label: "uncertain",
                confidence: max(0.01, min(0.99, threshold)),
                shouldAlert: false,
                reason: reason.replacingOccurrences(of: "\n", with: " ")
            ),
            toast: nil
        )
    }
}
