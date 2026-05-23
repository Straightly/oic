import Foundation

struct WatcherSpec: Sendable {
    let watcherID: String
    let title: String
    let prompt: String
    let sceneTarget: String
    let labels: [String]
    let notes: String
}
