import Foundation

struct ToastWatcherSpec {
    let base: WatcherSpec

    static let `default` = ToastWatcherSpec(
        base: WatcherSpec(
            watcherID: "toast-readiness-v0",
            title: "Toast Watcher",
            prompt: "Watch the toaster and tell me when the toast is ready.",
            sceneTarget: "toaster",
            labels: ["not_ready", "close", "ready", "overdone", "uncertain"],
            notes: "Current watcher uses the existing toast readiness heuristic pipeline."
        )
    )
}
