@preconcurrency import AVFoundation
import Foundation

final class CameraSession: NSObject {
    enum CameraSessionError: Error {
        case permissionDenied
        case noVideoDevice
        case cannotAddInput
        case cannotAddOutput
    }

    let session = AVCaptureSession()

    var discardLateFrames: Bool = true {
        didSet { videoOutput.alwaysDiscardsLateVideoFrames = discardLateFrames }
    }

    var onFrame: ((CVPixelBuffer) -> Void)?

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoOutputQueue = DispatchQueue(label: "camera.video.output.queue")

    private let videoOutput = AVCaptureVideoDataOutput()
    private var isConfigured = false

    func start() async throws {
        try await requestPermissionIfNeeded()

        if !isConfigured {
            try configure()
            isConfigured = true
        }

        sessionQueue.async { [session] in
            if !session.isRunning {
                session.startRunning()
            }
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func requestPermissionIfNeeded() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted { throw CameraSessionError.permissionDenied }
        default:
            throw CameraSessionError.permissionDenied
        }
    }

    private func configure() throws {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            session.commitConfiguration()
            throw CameraSessionError.noVideoDevice
        }

        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            device.unlockForConfiguration()
        } catch {}

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraSessionError.cannotAddInput
        }
        session.addInput(input)

        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = discardLateFrames
        videoOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)

        guard session.canAddOutput(videoOutput) else {
            session.commitConfiguration()
            throw CameraSessionError.cannotAddOutput
        }
        session.addOutput(videoOutput)

        if let connection = videoOutput.connection(with: .video) {
            if #available(iOS 17.0, *) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
            } else if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }

        session.commitConfiguration()
    }
}

extension CameraSession.CameraSessionError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Camera permission denied. Enable Camera access for ItIsToasted in Settings."
        case .noVideoDevice:
            return "No camera device available (this can happen on the iOS Simulator)."
        case .cannotAddInput:
            return "Unable to configure camera input."
        case .cannotAddOutput:
            return "Unable to configure camera output."
        }
    }
}

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        onFrame?(pixelBuffer)
    }
}
