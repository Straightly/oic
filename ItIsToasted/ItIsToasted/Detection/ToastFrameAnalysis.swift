import Foundation

struct ToastROI {
    let minX: Int
    let maxX: Int
    let minY: Int
    let maxY: Int
}

struct ToastFrameFeatures {
    let meanBrightness: Double
    let meanRedness: Double
    let sampleCount: Int
    let roi: ToastROI
}

struct ToastFrameAnalysis {
    let readiness: ToastReadiness
    let features: ToastFrameFeatures?
}

