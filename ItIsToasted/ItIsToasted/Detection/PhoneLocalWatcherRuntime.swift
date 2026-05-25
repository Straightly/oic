import CoreVideo
import Foundation

protocol PhoneLocalWatcherRuntime {
    var spec: WatcherSpec { get }
    var runtimeDisplayName: String { get }
    var runtimePathSummary: String { get }

    func reset()
    func startSession() throws
    func analyze(pixelBuffer: CVPixelBuffer, threshold: Double) -> ToastWatcherFrameResult
}

extension PhoneLocalWatcherRuntime {
    func startSession() throws {}
}
