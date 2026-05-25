import Foundation

struct CatDoorWatcherSpec {
    let base: WatcherSpec

    static let `default` = CatDoorWatcherSpec(
        base: WatcherSpec(
            watcherID: "cat-door-v0",
            title: "Back Door Cat Watcher",
            prompt: "Watch the back door and tell me whether my cat went out or came home.",
            sceneTarget: "back_door",
            labels: ["out", "in", "none", "uncertain"],
            notes: "Current version validates the phone-local Gemma path honestly and keeps event claims conservative until more cat-transition evidence exists."
        )
    )
}
