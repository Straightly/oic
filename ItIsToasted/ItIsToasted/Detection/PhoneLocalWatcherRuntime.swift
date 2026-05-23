import CoreVideo
import Foundation

protocol PhoneLocalWatcherRuntime {
    var spec: WatcherSpec { get }
    var runtimeDisplayName: String { get }
    var runtimePathSummary: String { get }

    func reset()
    func analyze(pixelBuffer: CVPixelBuffer, threshold: Double) -> ToastWatcherFrameResult
}
