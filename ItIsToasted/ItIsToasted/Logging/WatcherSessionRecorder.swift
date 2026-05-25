import CoreImage
import CoreVideo
import Foundation
import UIKit

final class WatcherSessionRecorder {
    struct Config {
        var frameSaveIntervalSeconds: TimeInterval = 1.0
        var maxSavedFrames: Int = 600
        var jpegQuality: CGFloat = 0.72
        var maxImageDimension: CGFloat = 900
    }

    private let config: Config
    private let sessionStart: Date
    private let sessionId: String
    private let watcherSpec: WatcherSpec
    private let threshold: Double
    private let runtimeDisplayName: String

    private let writerQueue = DispatchQueue(label: "watcher.session.recorder.queue")
    private let ciContext = CIContext()

    private let directoryURL: URL
    private let framesDirectoryURL: URL
    private let eventsURL: URL
    private let resultsURL: URL

    private var eventsHandle: FileHandle?
    private var resultsHandle: FileHandle?
    private var lastFrameSavedAt: Date?
    private var savedFrameCount: Int = 0

    init(
        watcherSpec: WatcherSpec,
        runtimeDisplayName: String,
        threshold: Double,
        config: Config = Config()
    ) throws {
        self.watcherSpec = watcherSpec
        self.runtimeDisplayName = runtimeDisplayName
        self.threshold = threshold
        self.config = config
        self.sessionStart = Date()
        self.sessionId = WatcherSessionRecorder.makeSessionId(start: sessionStart, watcherID: watcherSpec.watcherID)

        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sessionsRoot = root.appendingPathComponent("ItIsToasted", isDirectory: true)
            .appendingPathComponent("WatcherSessions", isDirectory: true)
        self.directoryURL = sessionsRoot.appendingPathComponent(sessionId, isDirectory: true)
        self.framesDirectoryURL = directoryURL.appendingPathComponent("frames", isDirectory: true)
        self.eventsURL = directoryURL.appendingPathComponent("events.csv", isDirectory: false)
        self.resultsURL = directoryURL.appendingPathComponent("watcher_results.csv", isDirectory: false)

        try FileManager.default.createDirectory(at: framesDirectoryURL, withIntermediateDirectories: true)
        try writeMetadata()
        try openFiles()
    }

    var directoryPath: String {
        directoryURL.path
    }

    func stop() {
        writerQueue.sync {
            eventsHandle?.closeFile()
            resultsHandle?.closeFile()
            eventsHandle = nil
            resultsHandle = nil
        }
    }

    func recordEvent(at timestamp: Date, name: String, details: String? = nil) {
        writerQueue.async { [weak self] in
            guard let self else { return }
            guard let eventsHandle = self.eventsHandle else { return }
            let line = self.makeEventLine(timestamp: timestamp, name: name, details: details)
            if let data = line.data(using: .utf8) {
                eventsHandle.write(data)
            }
        }
    }

    func recordFrame(
        at timestamp: Date,
        watcher: WatcherAnalysis,
        pixelBuffer: CVPixelBuffer
    ) {
        writerQueue.async { [weak self, pixelBuffer] in
            guard let self else { return }
            self.appendWatcherResultLocked(timestamp: timestamp, watcher: watcher)
            if self.shouldSaveFrameLocked(at: timestamp) {
                self.saveFrameLocked(at: timestamp, watcher: watcher, pixelBuffer: pixelBuffer)
            }
        }
    }

    private func openFiles() throws {
        FileManager.default.createFile(atPath: eventsURL.path, contents: nil)
        FileManager.default.createFile(atPath: resultsURL.path, contents: nil)

        eventsHandle = try FileHandle(forWritingTo: eventsURL)
        resultsHandle = try FileHandle(forWritingTo: resultsURL)

        let eventsHeader = "timestamp_iso8601,seconds_since_start,event,details\n"
        eventsHandle?.write(eventsHeader.data(using: .utf8)!)

        let resultsHeader = "timestamp_iso8601,seconds_since_start,scene_status,label,confidence,should_alert,reason\n"
        resultsHandle?.write(resultsHeader.data(using: .utf8)!)
    }

    private func appendWatcherResultLocked(timestamp: Date, watcher: WatcherAnalysis) {
        guard let resultsHandle else { return }
        let iso = WatcherSessionRecorder.iso8601.string(from: timestamp)
        let seconds = timestamp.timeIntervalSince(sessionStart)
        let safeReason = sanitize(watcher.reason)
        let line = "\(iso),\(String(format: "%.3f", seconds)),\(sceneStatusString(watcher.sceneStatus)),\(watcher.label),\(String(format: "%.5f", watcher.confidence)),\(watcher.shouldAlert),\(safeReason)\n"
        if let data = line.data(using: .utf8) {
            resultsHandle.write(data)
        }
    }

    private func shouldSaveFrameLocked(at timestamp: Date) -> Bool {
        if savedFrameCount >= config.maxSavedFrames {
            return false
        }
        guard let lastFrameSavedAt else { return true }
        return timestamp.timeIntervalSince(lastFrameSavedAt) >= config.frameSaveIntervalSeconds
    }

    private func saveFrameLocked(at timestamp: Date, watcher: WatcherAnalysis, pixelBuffer: CVPixelBuffer) {
        guard let cgImage = makeCGImage(pixelBuffer: pixelBuffer) else { return }
        guard let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: config.jpegQuality) else { return }

        let isoShort = WatcherSessionRecorder.iso8601Short.string(from: timestamp)
        let confidence = String(format: "%.3f", watcher.confidence)
        let filename = String(format: "frame_%05d_%@_%@_%@.jpg", savedFrameCount, isoShort, watcher.label, confidence)

        let url = framesDirectoryURL.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: [.atomic])
            savedFrameCount += 1
            lastFrameSavedAt = timestamp
        } catch {}
    }

    private func makeCGImage(pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = ciImage.extent
        let scale = min(1.0, config.maxImageDimension / max(extent.width, extent.height))
        let scaled = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return ciContext.createCGImage(scaled, from: scaled.extent)
    }

    private func writeMetadata() throws {
        let metadataURL = directoryURL.appendingPathComponent("session.json", isDirectory: false)
        let metadata = SessionMetadata(
            sessionId: sessionId,
            startedAt: WatcherSessionRecorder.iso8601.string(from: sessionStart),
            watcherID: watcherSpec.watcherID,
            watcherTitle: watcherSpec.title,
            watcherPrompt: watcherSpec.prompt,
            runtimeDisplayName: runtimeDisplayName,
            threshold: threshold,
            deviceName: UIDevice.current.name,
            systemVersion: UIDevice.current.systemVersion
        )
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: metadataURL, options: [.atomic])
    }

    private func makeEventLine(timestamp: Date, name: String, details: String?) -> String {
        let iso = WatcherSessionRecorder.iso8601.string(from: timestamp)
        let seconds = timestamp.timeIntervalSince(sessionStart)
        return "\(iso),\(String(format: "%.3f", seconds)),\(name),\(sanitize(details ?? ""))\n"
    }

    private func sanitize(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
    }

    private func sceneStatusString(_ status: WatcherSceneStatus) -> String {
        switch status {
        case .baselineMatch:
            return "baseline_match"
        case .changeDetected:
            return "change_detected"
        case .invalidView:
            return "invalid_view"
        case .unknown:
            return "unknown"
        }
    }

    private struct SessionMetadata: Codable {
        let sessionId: String
        let startedAt: String
        let watcherID: String
        let watcherTitle: String
        let watcherPrompt: String
        let runtimeDisplayName: String
        let threshold: Double
        let deviceName: String
        let systemVersion: String
    }

    private static func makeSessionId(start: Date, watcherID: String) -> String {
        let timestamp = iso8601Short.string(from: start)
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
        return "\(watcherID)_\(timestamp)"
    }

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601Short: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return formatter
    }()
}
