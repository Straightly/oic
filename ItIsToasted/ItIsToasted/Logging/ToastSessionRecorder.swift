import CoreImage
import CoreVideo
import Foundation
import UIKit

final class ToastSessionRecorder {
    struct Config {
        var frameSaveIntervalSeconds: TimeInterval = 1.0
        var maxSavedFrames: Int = 600
        var jpegQuality: CGFloat = 0.72
        var maxImageDimension: CGFloat = 900
    }

    private let config: Config
    private let sessionStart: Date
    private let sessionId: String
    private let threshold: Double

    private let writerQueue = DispatchQueue(label: "toast.session.recorder.queue")
    private let ciContext = CIContext()

    private let directoryURL: URL
    private let framesDirectoryURL: URL
    private let telemetryURL: URL
    private let eventsURL: URL

    private var telemetryHandle: FileHandle?
    private var eventsHandle: FileHandle?

    private var lastFrameSavedAt: Date?
    private var savedFrameCount: Int = 0
    private var pendingTelemetryData = Data()

    init(threshold: Double, config: Config = Config()) throws {
        self.threshold = threshold
        self.config = config
        self.sessionStart = Date()
        self.sessionId = ToastSessionRecorder.makeSessionId(start: sessionStart)

        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sessionsRoot = root.appendingPathComponent("ItIsToasted", isDirectory: true)
            .appendingPathComponent("Sessions", isDirectory: true)
        self.directoryURL = sessionsRoot.appendingPathComponent(sessionId, isDirectory: true)
        self.framesDirectoryURL = directoryURL.appendingPathComponent("frames", isDirectory: true)
        self.telemetryURL = directoryURL.appendingPathComponent("telemetry.csv", isDirectory: false)
        self.eventsURL = directoryURL.appendingPathComponent("events.csv", isDirectory: false)

        try FileManager.default.createDirectory(at: framesDirectoryURL, withIntermediateDirectories: true)
        try writeMetadata()
        try openFiles()
    }

    func stop() {
        writerQueue.sync {
            flushTelemetryLocked()
            telemetryHandle?.closeFile()
            eventsHandle?.closeFile()
            telemetryHandle = nil
            eventsHandle = nil
        }
    }

    func recordFrame(at timestamp: Date, analysis: ToastFrameAnalysis, pixelBuffer: CVPixelBuffer) {
        writerQueue.async { [weak self, pixelBuffer] in
            guard let self else {
                return
            }

            self.appendTelemetryLocked(timestamp: timestamp, analysis: analysis)

            if self.shouldSaveFrameLocked(at: timestamp) {
                self.saveFrameLocked(at: timestamp, analysis: analysis, pixelBuffer: pixelBuffer)
            }

            if self.pendingTelemetryData.count > 32_000 {
                self.flushTelemetryLocked()
            }
        }
    }

    func recordEvent(at timestamp: Date, name: String, details: String? = nil) {
        writerQueue.async { [weak self] in
            guard let self else { return }
            guard let eventsHandle = self.eventsHandle else { return }
            let iso = ToastSessionRecorder.iso8601.string(from: timestamp)
            let seconds = timestamp.timeIntervalSince(self.sessionStart)
            let safeDetails = (details ?? "").replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
            let line = "\(iso),\(String(format: "%.3f", seconds)),\(name),\(safeDetails)\n"
            if let data = line.data(using: .utf8) {
                eventsHandle.write(data)
            }
        }
    }

    private func openFiles() throws {
        FileManager.default.createFile(atPath: telemetryURL.path, contents: nil)
        FileManager.default.createFile(atPath: eventsURL.path, contents: nil)

        telemetryHandle = try FileHandle(forWritingTo: telemetryURL)
        eventsHandle = try FileHandle(forWritingTo: eventsURL)

        let telemetryHeader = "timestamp_iso8601,seconds_since_start,score,state,mean_brightness,mean_redness,sample_count,roi_min_x,roi_min_y,roi_max_x,roi_max_y\n"
        telemetryHandle?.write(telemetryHeader.data(using: .utf8)!)

        let eventsHeader = "timestamp_iso8601,seconds_since_start,event,details\n"
        eventsHandle?.write(eventsHeader.data(using: .utf8)!)
    }

    private func appendTelemetryLocked(timestamp: Date, analysis: ToastFrameAnalysis) {
        let iso = ToastSessionRecorder.iso8601.string(from: timestamp)
        let seconds = timestamp.timeIntervalSince(sessionStart)

        let readiness = analysis.readiness
        let state = ToastSessionRecorder.stateString(readiness.state)

        let score = String(format: "%.5f", readiness.score)

        if let features = analysis.features {
            let mb = String(format: "%.5f", features.meanBrightness)
            let mr = String(format: "%.5f", features.meanRedness)
            let line =
                "\(iso),\(String(format: "%.3f", seconds)),\(score),\(state),\(mb),\(mr),\(features.sampleCount),\(features.roi.minX),\(features.roi.minY),\(features.roi.maxX),\(features.roi.maxY)\n"
            pendingTelemetryData.append(line.data(using: .utf8)!)
        } else {
            let line = "\(iso),\(String(format: "%.3f", seconds)),\(score),\(state),,,,,,,\n"
            pendingTelemetryData.append(line.data(using: .utf8)!)
        }
    }

    private func flushTelemetryLocked() {
        guard let telemetryHandle else { return }
        guard !pendingTelemetryData.isEmpty else { return }
        telemetryHandle.write(pendingTelemetryData)
        pendingTelemetryData.removeAll(keepingCapacity: true)
    }

    private func shouldSaveFrameLocked(at timestamp: Date) -> Bool {
        if savedFrameCount >= config.maxSavedFrames {
            return false
        }
        guard let lastFrameSavedAt else { return true }
        return timestamp.timeIntervalSince(lastFrameSavedAt) >= config.frameSaveIntervalSeconds
    }

    private func saveFrameLocked(at timestamp: Date, analysis: ToastFrameAnalysis, pixelBuffer: CVPixelBuffer) {
        guard let cgImage = makeCGImage(pixelBuffer: pixelBuffer) else { return }
        guard let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: config.jpegQuality) else { return }

        let isoShort = ToastSessionRecorder.iso8601Short.string(from: timestamp)
        let state = ToastSessionRecorder.stateString(analysis.readiness.state)
        let score = String(format: "%.3f", analysis.readiness.score)
        let filename = String(format: "frame_%05d_%@_%@_%@.jpg", savedFrameCount, isoShort, state, score)

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
            startedAt: ToastSessionRecorder.iso8601.string(from: sessionStart),
            threshold: threshold,
            deviceName: UIDevice.current.name,
            systemVersion: UIDevice.current.systemVersion
        )
        let data = try JSONEncoder().encode(metadata)
        try data.write(to: metadataURL, options: [.atomic])
    }

    private struct SessionMetadata: Codable {
        let sessionId: String
        let startedAt: String
        let threshold: Double
        let deviceName: String
        let systemVersion: String
    }

    private static func makeSessionId(start: Date) -> String {
        iso8601Short.string(from: start).replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "")
    }

    private static func stateString(_ state: ToastReadiness.State) -> String {
        switch state {
        case .unknown: return "unknown"
        case .notReady: return "not_ready"
        case .close: return "close"
        case .ready: return "ready"
        case .overdone: return "overdone"
        }
    }

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601Short: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        return f
    }()
}
