import CoreVideo
import Foundation

final class ToastPipeline {
    private let detector = ToastReadinessDetector()

    func reset() {
        detector.reset()
    }

    func analyze(pixelBuffer: CVPixelBuffer, threshold: Double) -> ToastFrameAnalysis {
        detector.analyze(pixelBuffer: pixelBuffer, threshold: threshold)
    }
}
