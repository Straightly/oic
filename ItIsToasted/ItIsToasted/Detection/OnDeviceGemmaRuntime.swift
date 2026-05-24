import Foundation

#if canImport(llama)
import llama
#endif

struct GemmaRuntimeStatus {
    let runtimeChoice: String
    let dependencyLinked: Bool
    let primaryModelPresent: Bool
    let projectorModelPresent: Bool
    let primaryModelPath: String?
    let projectorModelPath: String?

    var summary: String {
        if !dependencyLinked {
            return "Chosen GGUF runtime is not linked yet. Add the llama.cpp XCFramework to the app project."
        }

        if !primaryModelPresent {
            return "GGUF runtime linked, but the primary model file is missing."
        }

        if !projectorModelPresent {
            return "GGUF runtime linked, but the multimodal projection file is missing."
        }

        return "GGUF runtime linked and both model files are available."
    }
}

enum OnDeviceGemmaRuntimeError: LocalizedError {
    case dependencyMissing(runtimeName: String)
    case primaryModelMissing(expectedPath: String)
    case projectorModelMissing(expectedPath: String)
    case runtimeNotImplemented(String)
    case inferenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .dependencyMissing(let runtimeName):
            return "\(runtimeName) is not linked in the app yet."
        case .primaryModelMissing(let expectedPath):
            return "Gemma primary model file not found at \(expectedPath)."
        case .projectorModelMissing(let expectedPath):
            return "Gemma multimodal projection file not found at \(expectedPath)."
        case .runtimeNotImplemented(let message):
            return message
        case .inferenceFailed(let message):
            return "Gemma runtime inference failed: \(message)"
        }
    }
}

final class OnDeviceGemmaRuntime {
    static let runtimeDisplayName = "llama.cpp iOS XCFramework (GGUF)"
    static let bundledModelDirectory = "Models"
    static let developmentModelDirectory = "/Users/zhian/Downloads/bartowski/google_gemma-4-E2B-it-GGUF"
    static let primaryModelFilename = "google_gemma-4-E2B-it-Q4_K_S"
    static let primaryModelExtension = "gguf"
    static let projectorModelFilename = "mmproj-google_gemma-4-E2B-it-f16"
    static let projectorModelExtension = "gguf"

    var runtimeChoice: String {
        Self.runtimeDisplayName
    }

    var expectedPrimaryModelPath: String {
        Self.expectedPrimaryModelLocationDescription
    }

    var expectedProjectorModelPath: String {
        Self.expectedProjectorModelLocationDescription
    }

    func status() -> GemmaRuntimeStatus {
        let primaryModelPath = Self.resolvedPrimaryModelPath()
        let projectorModelPath = Self.resolvedProjectorModelPath()
        return GemmaRuntimeStatus(
            runtimeChoice: runtimeChoice,
            dependencyLinked: Self.isDependencyLinked,
            primaryModelPresent: primaryModelPath != nil,
            projectorModelPresent: projectorModelPath != nil,
            primaryModelPath: primaryModelPath,
            projectorModelPath: projectorModelPath
        )
    }

    func generateSmokeTestResponse(for watcherSpec: WatcherSpec) throws -> String {
        guard Self.isDependencyLinked else {
            throw OnDeviceGemmaRuntimeError.dependencyMissing(runtimeName: runtimeChoice)
        }

        guard let primaryModelPath = Self.resolvedPrimaryModelPath() else {
            throw OnDeviceGemmaRuntimeError.primaryModelMissing(expectedPath: expectedPrimaryModelPath)
        }

        guard let projectorModelPath = Self.resolvedProjectorModelPath() else {
            throw OnDeviceGemmaRuntimeError.projectorModelMissing(expectedPath: expectedProjectorModelPath)
        }

        #if canImport(llama)
        _ = watcherSpec

        llama_backend_init()
        defer { llama_backend_free() }

        var modelParams = llama_model_default_params()
        modelParams.use_mmap = true

        guard let model = primaryModelPath.withCString({ llama_model_load_from_file($0, modelParams) }) else {
            throw OnDeviceGemmaRuntimeError.inferenceFailed("llama.cpp could not load the primary GGUF model.")
        }
        defer { llama_model_free(model) }

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = 512
        contextParams.n_batch = 512
        contextParams.n_ubatch = 512
        contextParams.n_seq_max = 1

        guard let context = llama_init_from_model(model, contextParams) else {
            throw OnDeviceGemmaRuntimeError.inferenceFailed("llama.cpp loaded the model but failed to initialize a context.")
        }
        defer { llama_free(context) }

        let runtimeContext = llama_n_ctx(context)
        let runtimeBatch = llama_n_batch(context)
        let trainedContext = llama_model_n_ctx_train(model)
        let vocab = llama_model_get_vocab(model)
        let vocabSize = vocab.map { llama_vocab_n_tokens($0) } ?? 0
        let hasEncoder = llama_model_has_encoder(model)
        let hasDecoder = llama_model_has_decoder(model)

        return """
        llama.cpp loaded the GGUF model successfully.
        runtime=\(runtimeChoice)
        train_ctx=\(trainedContext)
        runtime_ctx=\(runtimeContext)
        runtime_batch=\(runtimeBatch)
        vocab=\(vocabSize)
        has_encoder=\(hasEncoder)
        has_decoder=\(hasDecoder)
        primary_model=\(URL(fileURLWithPath: primaryModelPath).lastPathComponent)
        projector_model_detected=\(URL(fileURLWithPath: projectorModelPath).lastPathComponent)
        """
        #else
        let prompt = """
        Runtime: \(runtimeChoice)
        Watcher: \(watcherSpec.title)
        Primary model: \(primaryModelPath)
        Projection model: \(projectorModelPath)
        """
        throw OnDeviceGemmaRuntimeError.runtimeNotImplemented(
            "llama.cpp GGUF runtime is selected. Files are wired, but the framework still needs to be linked into the app before inference can run.\n\(prompt)"
        )
        #endif
    }

    private static func resolvedPrimaryModelPath() -> String? {
        if let bundledPath = Bundle.main.path(
            forResource: primaryModelFilename,
            ofType: primaryModelExtension,
            inDirectory: bundledModelDirectory
        ) {
            return bundledPath
        }

        if allowsDevelopmentModelDirectory,
           FileManager.default.fileExists(atPath: developmentPrimaryModelPath) {
            return developmentPrimaryModelPath
        }

        return nil
    }

    private static func resolvedProjectorModelPath() -> String? {
        if let bundledPath = Bundle.main.path(
            forResource: projectorModelFilename,
            ofType: projectorModelExtension,
            inDirectory: bundledModelDirectory
        ) {
            return bundledPath
        }

        if allowsDevelopmentModelDirectory,
           FileManager.default.fileExists(atPath: developmentProjectorModelPath) {
            return developmentProjectorModelPath
        }

        return nil
    }

    private static var developmentPrimaryModelPath: String {
        "\(developmentModelDirectory)/\(primaryModelFilename).\(primaryModelExtension)"
    }

    private static var developmentProjectorModelPath: String {
        "\(developmentModelDirectory)/\(projectorModelFilename).\(projectorModelExtension)"
    }

    private static var expectedPrimaryModelLocationDescription: String {
        if allowsDevelopmentModelDirectory {
            return developmentPrimaryModelPath
        }

        return "Bundle/\(bundledModelDirectory)/\(primaryModelFilename).\(primaryModelExtension)"
    }

    private static var expectedProjectorModelLocationDescription: String {
        if allowsDevelopmentModelDirectory {
            return developmentProjectorModelPath
        }

        return "Bundle/\(bundledModelDirectory)/\(projectorModelFilename).\(projectorModelExtension)"
    }

    private static var allowsDevelopmentModelDirectory: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    private static var isDependencyLinked: Bool {
        #if canImport(llama)
        return true
        #else
        return false
        #endif
    }
}
