import CoreVideo
import Foundation

struct ToastWatcherFrameResult {
    let watcher: WatcherAnalysis
    let toast: ToastFrameAnalysis
}

final class ToastWatcherAdapter: PhoneLocalWatcherRuntime {
    let toastSpec: ToastWatcherSpec
    var spec: WatcherSpec { toastSpec.base }
    let runtimeDisplayName = "Phone-local watcher path"
    let runtimePathSummary = "Runs fully in the app using the current local toast detector, with a watcher adapter ready for future on-device Gemma integration."

    private let pipeline = ToastPipeline()

    init(spec: ToastWatcherSpec = .default) {
        self.toastSpec = spec
    }

    func reset() {
        pipeline.reset()
    }

    func analyze(pixelBuffer: CVPixelBuffer, threshold: Double) -> ToastWatcherFrameResult {
        let toastAnalysis = pipeline.analyze(pixelBuffer: pixelBuffer, threshold: threshold)
        let watcherAnalysis = mapToWatcherAnalysis(toastAnalysis)
        return ToastWatcherFrameResult(watcher: watcherAnalysis, toast: toastAnalysis)
    }

    private func mapToWatcherAnalysis(_ analysis: ToastFrameAnalysis) -> WatcherAnalysis {
        let readiness = analysis.readiness

        switch readiness.state {
        case .unknown:
            return WatcherAnalysis(
                sceneStatus: .unknown,
                label: "uncertain",
                confidence: 0,
                shouldAlert: false,
                reason: "Watcher could not confidently interpret the current frame."
            )
        case .notReady:
            return WatcherAnalysis(
                sceneStatus: .baselineMatch,
                label: "not_ready",
                confidence: readiness.score,
                shouldAlert: false,
                reason: "Toast watcher sees a valid scene but the toast is not ready yet."
            )
        case .close:
            return WatcherAnalysis(
                sceneStatus: .changeDetected,
                label: "close",
                confidence: readiness.score,
                shouldAlert: false,
                reason: "Toast watcher sees meaningful browning progress and the toast is close."
            )
        case .ready:
            return WatcherAnalysis(
                sceneStatus: .changeDetected,
                label: "ready",
                confidence: readiness.score,
                shouldAlert: true,
                reason: "Toast watcher considers the toast ready."
            )
        case .overdone:
            return WatcherAnalysis(
                sceneStatus: .changeDetected,
                label: "overdone",
                confidence: readiness.score,
                shouldAlert: false,
                reason: "Toast watcher considers the toast overdone."
            )
        }
    }
}
