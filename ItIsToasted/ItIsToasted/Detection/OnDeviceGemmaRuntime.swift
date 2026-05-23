import Foundation

#if canImport(MediaPipeTasksGenAI)
import MediaPipeTasksGenAI
#endif

struct GemmaRuntimeStatus {
    let dependencyLinked: Bool
    let modelBundled: Bool
    let modelPath: String?

    var summary: String {
        if !dependencyLinked {
            return "Gemma runtime dependency not linked yet. Run CocoaPods install first."
        }

        if !modelBundled {
            return "Gemma runtime linked, but the bundled model file is missing."
        }

        return "Gemma runtime linked and model file found."
    }
}

enum OnDeviceGemmaRuntimeError: LocalizedError {
    case dependencyMissing
    case modelMissing(expectedPath: String)
    case initializationFailed(String)
    case inferenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .dependencyMissing:
            return "MediaPipeTasksGenAI is not linked in the app yet."
        case .modelMissing(let expectedPath):
            return "Gemma model file not found at \(expectedPath)."
        case .initializationFailed(let message):
            return "Gemma runtime failed to initialize: \(message)"
        case .inferenceFailed(let message):
            return "Gemma runtime inference failed: \(message)"
        }
    }
}

final class OnDeviceGemmaRuntime {
    static let modelDirectory = "Models"
    static let modelFilename = "gemma-phone-local"
    static let modelExtension = "bin"

    var expectedBundledModelPath: String {
        "\(Self.modelDirectory)/\(Self.modelFilename).\(Self.modelExtension)"
    }

    func status() -> GemmaRuntimeStatus {
        let modelPath = Self.bundledModelPath()
        return GemmaRuntimeStatus(
            dependencyLinked: Self.isDependencyLinked,
            modelBundled: modelPath != nil,
            modelPath: modelPath
        )
    }

    func generateSmokeTestResponse(for watcherSpec: WatcherSpec) throws -> String {
        guard Self.isDependencyLinked else {
            throw OnDeviceGemmaRuntimeError.dependencyMissing
        }

        guard let modelPath = Self.bundledModelPath() else {
            throw OnDeviceGemmaRuntimeError.modelMissing(expectedPath: expectedBundledModelPath)
        }

        #if canImport(MediaPipeTasksGenAI)
        let options = LlmInference.Options(modelPath: modelPath)
        options.maxTokens = 96

        let prompt = """
        You are helping configure a local watcher in the OIC iPhone app.
        Summarize this watcher request in one short sentence and list the most important labels.

        Watcher title: \(watcherSpec.title)
        Watcher prompt: \(watcherSpec.prompt)
        Scene target: \(watcherSpec.sceneTarget)
        Labels: \(watcherSpec.labels.joined(separator: ", "))
        Notes: \(watcherSpec.notes)
        """

        do {
            let inference = try LlmInference(options: options)
            return try inference.generateResponse(inputText: prompt)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            throw OnDeviceGemmaRuntimeError.inferenceFailed(message)
        }
        #else
        throw OnDeviceGemmaRuntimeError.dependencyMissing
        #endif
    }

    private static func bundledModelPath() -> String? {
        Bundle.main.path(
            forResource: modelFilename,
            ofType: modelExtension,
            inDirectory: modelDirectory
        )
    }

    private static var isDependencyLinked: Bool {
        #if canImport(MediaPipeTasksGenAI)
        return true
        #else
        return false
        #endif
    }
}
