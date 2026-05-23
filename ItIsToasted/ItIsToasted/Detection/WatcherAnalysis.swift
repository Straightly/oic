import Foundation

enum WatcherSceneStatus {
    case baselineMatch
    case changeDetected
    case invalidView
    case unknown
}

struct WatcherAnalysis {
    let sceneStatus: WatcherSceneStatus
    let label: String
    let confidence: Double
    let shouldAlert: Bool
    let reason: String
}
