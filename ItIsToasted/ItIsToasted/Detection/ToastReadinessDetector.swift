import CoreVideo
import Foundation

struct ToastReadiness {
    enum State {
        case unknown
        case notReady
        case close
        case ready
        case overdone
    }

    let state: State
    let score: Double
}

final class ToastReadinessDetector {
    private var readyStreak: Int = 0

    func reset() {
        readyStreak = 0
    }

    func analyze(pixelBuffer: CVPixelBuffer, threshold: Double) -> ToastFrameAnalysis {
        guard let featuresAndScore = computeFeaturesAndScore(pixelBuffer: pixelBuffer) else {
            readyStreak = 0
            return ToastFrameAnalysis(readiness: ToastReadiness(state: .unknown, score: 0), features: nil)
        }

        let features = featuresAndScore.features
        let score = featuresAndScore.score

        if score >= min(1.0, max(0.0, threshold)) {
            readyStreak += 1
        } else {
            readyStreak = 0
        }

        if score >= 0.92 {
            return ToastFrameAnalysis(readiness: ToastReadiness(state: .overdone, score: score), features: features)
        }

        if readyStreak >= 8 {
            return ToastFrameAnalysis(readiness: ToastReadiness(state: .ready, score: score), features: features)
        }

        if score >= threshold * 0.92 {
            return ToastFrameAnalysis(readiness: ToastReadiness(state: .close, score: score), features: features)
        }

        return ToastFrameAnalysis(readiness: ToastReadiness(state: .notReady, score: score), features: features)
    }

    private struct FeaturesAndScore {
        let features: ToastFrameFeatures
        let score: Double
    }

    private func computeFeaturesAndScore(pixelBuffer: CVPixelBuffer) -> FeaturesAndScore? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        if width <= 0 || height <= 0 || bytesPerRow <= 0 {
            return nil
        }

        let roi = centeredROI(width: width, height: height)
        let step = max(4, min(16, min(roi.width, roi.height) / 60))

        var sumBrownish: Double = 0
        var sumBrightness: Double = 0
        var sumRedness: Double = 0
        var count: Double = 0

        for y in stride(from: roi.minY, to: roi.maxY, by: step) {
            let row = baseAddress.advanced(by: y * bytesPerRow)
            for x in stride(from: roi.minX, to: roi.maxX, by: step) {
                let pixel = row.advanced(by: x * 4)
                let b = Double(pixel.load(fromByteOffset: 0, as: UInt8.self))
                let g = Double(pixel.load(fromByteOffset: 1, as: UInt8.self))
                let r = Double(pixel.load(fromByteOffset: 2, as: UInt8.self))

                let brightness = (r + g + b) / (3.0 * 255.0)
                if brightness < 0.03 {
                    continue
                }

                let redness = r / max(1.0, (g + b) * 0.5)
                let brownish = (redness - 1.0) * 0.55 + (0.75 - brightness) * 0.45
                let clamped = min(1.0, max(0.0, brownish))

                sumBrownish += clamped
                sumBrightness += brightness
                sumRedness += redness
                count += 1
            }
        }

        if count < 50 {
            return nil
        }

        let meanBrightness = sumBrightness / count
        let meanRedness = sumRedness / count
        let score = sumBrownish / count

        let features = ToastFrameFeatures(
            meanBrightness: meanBrightness,
            meanRedness: meanRedness,
            sampleCount: Int(count),
            roi: ToastROI(minX: roi.minX, maxX: roi.maxX, minY: roi.minY, maxY: roi.maxY)
        )
        return FeaturesAndScore(features: features, score: score)
    }

    private func centeredROI(width: Int, height: Int) -> (minX: Int, maxX: Int, minY: Int, maxY: Int, width: Int, height: Int) {
        let roiWidth = max(32, Int(Double(width) * 0.55))
        let roiHeight = max(32, Int(Double(height) * 0.55))
        let minX = max(0, (width - roiWidth) / 2)
        let minY = max(0, (height - roiHeight) / 2)
        let maxX = min(width, minX + roiWidth)
        let maxY = min(height, minY + roiHeight)
        return (minX, maxX, minY, maxY, maxX - minX, maxY - minY)
    }
}
