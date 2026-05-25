import Foundation
import Combine
import AVFoundation
import Dispatch

@MainActor
final class ToastMonitorViewModel: ObservableObject {
    enum WatcherSelection: String, CaseIterable, Identifiable {
        case toast
        case catDoor

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .toast:
                return "Toast"
            case .catDoor:
                return "Cat door"
            }
        }
    }

    @Published var threshold: Double = 0.62
    @Published var discardLateFrames: Bool = true
    @Published var saveIterationData: Bool = true
    @Published var selectedWatcher: WatcherSelection = .toast

    @Published private(set) var isMonitoring: Bool = false
    @Published private(set) var lastScore: Double?
    @Published private(set) var statusText: String = "Idle"
    @Published private(set) var watcherReasonText: String?
    @Published var errorMessage: String?
    @Published private(set) var gemmaRuntimeStatusText: String = "Gemma runtime not checked yet."
    @Published private(set) var gemmaRuntimeChoiceText: String = ""
    @Published private(set) var gemmaPrimaryModelPathText: String = ""
    @Published private(set) var gemmaProjectorModelPathText: String = ""
    @Published private(set) var gemmaLastResponse: String?
    @Published private(set) var gemmaLastError: String?
    @Published private(set) var gemmaIsRunning: Bool = false
    @Published private(set) var watcherTracePathText: String = ""

    let camera = CameraSession()

    private let toastWatcherRuntime = ToastWatcherAdapter()
    private let catDoorWatcherRuntime = GemmaCatDoorWatcherAdapter()
    private let gemmaRuntime = OnDeviceGemmaRuntime()
    private let reactor = ToastedReactor()
    private var recorder: ToastSessionRecorder?
    private var watcherRecorder: WatcherSessionRecorder?
    private var didRecordFirstFrame = false

    private var watcherRuntime: any PhoneLocalWatcherRuntime {
        switch selectedWatcher {
        case .toast:
            return toastWatcherRuntime
        case .catDoor:
            return catDoorWatcherRuntime
        }
    }

    var watcherTitle: String { watcherRuntime.spec.title }
    var watcherPrompt: String { watcherRuntime.spec.prompt }
    var watcherLabelsText: String { watcherRuntime.spec.labels.joined(separator: ", ") }
    var runtimeDisplayName: String { watcherRuntime.runtimeDisplayName }
    var runtimePathSummary: String { watcherRuntime.runtimePathSummary }
    var gemmaSmokeTestButtonTitle: String { gemmaIsRunning ? "Running Gemma…" : "Test Gemma runtime" }
    var thresholdTitle: String {
        switch selectedWatcher {
        case .toast:
            return "Readiness threshold"
        case .catDoor:
            return "Alert threshold"
        }
    }

    func onAppear() {
        statusText = "Ready"
        watcherReasonText = nil
        watcherTracePathText = ""
        primeGemmaRuntimeUI()
    }

    func onDisappear() {
        stopMonitoring()
    }

    func toggleMonitoring() {
        if isMonitoring {
            stopMonitoring()
        } else {
            startMonitoring()
        }
    }

    func testAlert() {
        reactor.announceToasted()
    }

    func watcherSelectionChanged() {
        guard !isMonitoring else { return }
        lastScore = nil
        watcherReasonText = nil
        statusText = "Ready"
        primeGemmaRuntimeUI()
    }

    func primeGemmaRuntimeUI() {
        gemmaIsRunning = false
        gemmaLastError = nil
        gemmaLastResponse = nil
        gemmaRuntimeChoiceText = gemmaRuntime.runtimeChoice
        gemmaRuntimeStatusText = "Gemma runtime not checked yet."
        gemmaPrimaryModelPathText = gemmaRuntime.expectedPrimaryModelPath
        gemmaProjectorModelPathText = gemmaRuntime.expectedProjectorModelPath
    }

    func refreshGemmaRuntimeStatus() {
        let status = gemmaRuntime.status()
        gemmaRuntimeChoiceText = status.runtimeChoice
        gemmaRuntimeStatusText = status.summary
        gemmaPrimaryModelPathText = status.primaryModelPath ?? gemmaRuntime.expectedPrimaryModelPath
        gemmaProjectorModelPathText = status.projectorModelPath ?? gemmaRuntime.expectedProjectorModelPath
    }

    func runGemmaSmokeTest() {
        guard !gemmaIsRunning else { return }

        gemmaIsRunning = true
        gemmaLastError = nil
        gemmaLastResponse = nil
        refreshGemmaRuntimeStatus()

        let watcherSpec = watcherRuntime.spec

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            do {
                let response = try OnDeviceGemmaRuntime().generateSmokeTestResponse(for: watcherSpec)
                DispatchQueue.main.async {
                    self.gemmaIsRunning = false
                    self.gemmaLastResponse = response
                    self.refreshGemmaRuntimeStatus()
                }
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                DispatchQueue.main.async {
                    self.gemmaIsRunning = false
                    self.gemmaLastError = message
                    self.refreshGemmaRuntimeStatus()
                }
            }
        }
    }

    private func startMonitoring() {
        watcherRuntime.reset()
        reactor.reset()

        errorMessage = nil
        watcherReasonText = nil
        watcherTracePathText = ""
        didRecordFirstFrame = false
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            statusText = "Requesting camera permission…"
        case .denied, .restricted:
            statusText = "Camera permission denied"
        default:
            statusText = "Starting camera…"
        }

        camera.discardLateFrames = discardLateFrames
        let thresholdForSession = threshold
        let watcherRuntime = watcherRuntime
        let shouldRecord = saveIterationData && selectedWatcher == .toast
        do {
            recorder = shouldRecord ? try ToastSessionRecorder(threshold: thresholdForSession) : nil
        } catch {
            recorder = nil
        }
        do {
            watcherRecorder = saveIterationData
                ? try WatcherSessionRecorder(
                    watcherSpec: watcherRuntime.spec,
                    runtimeDisplayName: watcherRuntime.runtimeDisplayName,
                    threshold: thresholdForSession
                )
                : nil
            watcherTracePathText = watcherRecorder?.directoryPath ?? ""
        } catch {
            watcherRecorder = nil
            watcherTracePathText = ""
        }
        watcherRecorder?.recordEvent(at: Date(), name: "session_prepare_started", details: "watcher=\(watcherRuntime.spec.watcherID)")

        camera.onFrame = { [weak self] pixelBuffer in
            let timestamp = Date()
            let result = watcherRuntime.analyze(pixelBuffer: pixelBuffer, threshold: thresholdForSession)
            if let toastAnalysis = result.toast {
                self?.recorder?.recordFrame(at: timestamp, analysis: toastAnalysis, pixelBuffer: pixelBuffer)
            }
            self?.watcherRecorder?.recordFrame(at: timestamp, watcher: result.watcher, pixelBuffer: pixelBuffer)
            if self?.didRecordFirstFrame == false {
                self?.didRecordFirstFrame = true
                self?.watcherRecorder?.recordEvent(
                    at: timestamp,
                    name: "first_frame_processed",
                    details: "label=\(result.watcher.label), confidence=\(String(format: "%.5f", result.watcher.confidence)), reason=\(result.watcher.reason)"
                )
            }
            Task { @MainActor in
                self?.apply(result: result, timestamp: timestamp)
            }
        }

        Task {
            do {
                statusText = selectedWatcher == .toast ? "Starting camera…" : "Preparing Gemma watcher…"
                watcherRecorder?.recordEvent(at: Date(), name: "watcher_runtime_prepare_started")
                try watcherRuntime.startSession()
                watcherRecorder?.recordEvent(at: Date(), name: "watcher_runtime_prepare_completed")
                watcherRecorder?.recordEvent(at: Date(), name: "camera_start_requested")
                try await camera.start()
                isMonitoring = true
                statusText = "Monitoring…"
                recorder?.recordEvent(at: Date(), name: "monitoring_started", details: "threshold=\(String(format: "%.3f", thresholdForSession))")
                watcherRecorder?.recordEvent(at: Date(), name: "monitoring_started", details: "threshold=\(String(format: "%.3f", thresholdForSession))")
            } catch {
                isMonitoring = false
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                statusText = "Camera error"
                errorMessage = message
                recorder?.recordEvent(at: Date(), name: "camera_error", details: message)
                watcherRecorder?.recordEvent(at: Date(), name: "camera_error", details: message)
                recorder?.stop()
                recorder = nil
                watcherRecorder?.stop()
                watcherRecorder = nil
            }
        }
    }

    private func stopMonitoring() {
        watcherRecorder?.recordEvent(at: Date(), name: "monitoring_stopped")
        camera.stop()
        camera.onFrame = nil
        recorder?.stop()
        recorder = nil
        watcherRecorder?.stop()
        watcherRecorder = nil
        isMonitoring = false
        statusText = "Stopped"
    }

    private func apply(result: ToastWatcherFrameResult, timestamp: Date) {
        watcherReasonText = result.watcher.reason

        if let toast = result.toast {
            applyToastResult(toast, timestamp: timestamp)
            return
        }

        applyWatcherResult(result.watcher, timestamp: timestamp)
    }

    private func applyToastResult(_ toast: ToastFrameAnalysis, timestamp: Date) {
        let readiness = toast.readiness
        lastScore = readiness.score

        switch readiness.state {
        case .unknown:
            statusText = "Unknown (lighting/ROI)"
        case .notReady:
            statusText = "Not ready"
        case .close:
            statusText = "Close"
        case .ready:
            statusText = "Ready"
            recorder?.recordEvent(at: timestamp, name: "toasted_announced", details: "score=\(String(format: "%.5f", readiness.score))")
            reactor.announceToasted()
        case .overdone:
            statusText = "Overdone"
        }
    }

    private func applyWatcherResult(_ watcher: WatcherAnalysis, timestamp: Date) {
        lastScore = watcher.confidence

        switch watcher.label {
        case "none":
            statusText = "No event"
        case "uncertain":
            statusText = "Uncertain"
        default:
            statusText = watcher.label.replacingOccurrences(of: "_", with: " ").capitalized
        }

        if watcher.shouldAlert {
            recorder?.recordEvent(at: timestamp, name: "watcher_alert", details: "label=\(watcher.label), confidence=\(String(format: "%.5f", watcher.confidence))")
            reactor.announceToasted()
        }
    }
}
