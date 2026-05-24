import Foundation
import Combine
import AVFoundation
import Dispatch

@MainActor
final class ToastMonitorViewModel: ObservableObject {
    @Published var threshold: Double = 0.62
    @Published var discardLateFrames: Bool = true
    @Published var saveIterationData: Bool = true

    @Published private(set) var isMonitoring: Bool = false
    @Published private(set) var lastScore: Double?
    @Published private(set) var statusText: String = "Idle"
    @Published var errorMessage: String?
    @Published private(set) var gemmaRuntimeStatusText: String = "Gemma runtime not checked yet."
    @Published private(set) var gemmaRuntimeChoiceText: String = ""
    @Published private(set) var gemmaPrimaryModelPathText: String = ""
    @Published private(set) var gemmaProjectorModelPathText: String = ""
    @Published private(set) var gemmaLastResponse: String?
    @Published private(set) var gemmaLastError: String?
    @Published private(set) var gemmaIsRunning: Bool = false

    let camera = CameraSession()

    private let watcherRuntime: any PhoneLocalWatcherRuntime = ToastWatcherAdapter()
    private let gemmaRuntime = OnDeviceGemmaRuntime()
    private let reactor = ToastedReactor()
    private var recorder: ToastSessionRecorder?

    var watcherTitle: String { watcherRuntime.spec.title }
    var watcherPrompt: String { watcherRuntime.spec.prompt }
    var watcherLabelsText: String { watcherRuntime.spec.labels.joined(separator: ", ") }
    var runtimeDisplayName: String { watcherRuntime.runtimeDisplayName }
    var runtimePathSummary: String { watcherRuntime.runtimePathSummary }
    var gemmaSmokeTestButtonTitle: String { gemmaIsRunning ? "Running Gemma…" : "Test Gemma runtime" }

    func onAppear() {
        statusText = "Ready"
        refreshGemmaRuntimeStatus()
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
        let shouldRecord = saveIterationData
        do {
            recorder = shouldRecord ? try ToastSessionRecorder(threshold: thresholdForSession) : nil
        } catch {
            recorder = nil
        }

        camera.onFrame = { [weak self] pixelBuffer in
            let timestamp = Date()
            let result = watcherRuntime.analyze(pixelBuffer: pixelBuffer, threshold: thresholdForSession)
            self?.recorder?.recordFrame(at: timestamp, analysis: result.toast, pixelBuffer: pixelBuffer)
            Task { @MainActor in
                self?.apply(result: result, timestamp: timestamp)
            }
        }

        Task {
            do {
                try await camera.start()
                isMonitoring = true
                statusText = "Monitoring…"
                recorder?.recordEvent(at: Date(), name: "monitoring_started", details: "threshold=\(String(format: "%.3f", thresholdForSession))")
            } catch {
                isMonitoring = false
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                statusText = "Camera error"
                errorMessage = message
                recorder?.recordEvent(at: Date(), name: "camera_error", details: message)
                recorder?.stop()
                recorder = nil
            }
        }
    }

    private func stopMonitoring() {
        camera.stop()
        camera.onFrame = nil
        recorder?.stop()
        recorder = nil
        isMonitoring = false
        statusText = "Stopped"
    }

    private func apply(result: ToastWatcherFrameResult, timestamp: Date) {
        let readiness = result.toast.readiness
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
}
