import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ToastMonitorViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                previewSection

                VStack(alignment: .leading, spacing: 10) {
                    Picker("Watcher", selection: $viewModel.selectedWatcher) {
                        ForEach(ToastMonitorViewModel.WatcherSelection.allCases) { watcher in
                            Text(watcher.displayName).tag(watcher)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(viewModel.isMonitoring)
                    .onChange(of: viewModel.selectedWatcher) {
                        viewModel.watcherSelectionChanged()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(viewModel.watcherTitle)
                            .font(.headline)
                        Text(viewModel.watcherPrompt)
                            .font(.subheadline)
                        Text(viewModel.runtimeDisplayName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(viewModel.runtimePathSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Labels: \(viewModel.watcherLabelsText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Gemma runtime")
                            .font(.headline)
                        Text(viewModel.gemmaRuntimeChoiceText)
                            .font(.subheadline)
                        Text(viewModel.gemmaRuntimeStatusText)
                            .font(.subheadline)
                        Text("Primary model path: \(viewModel.gemmaPrimaryModelPathText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Projector path: \(viewModel.gemmaProjectorModelPathText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Button(viewModel.gemmaSmokeTestButtonTitle) {
                                viewModel.runGemmaSmokeTest()
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.gemmaIsRunning)

                            Button("Refresh Gemma status") {
                                viewModel.refreshGemmaRuntimeStatus()
                            }
                            .buttonStyle(.bordered)
                        }

                        if let response = viewModel.gemmaLastResponse {
                            Text(response)
                                .font(.caption)
                        }

                        if let error = viewModel.gemmaLastError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    HStack {
                        Text(viewModel.thresholdTitle)
                        Spacer()
                        Text(String(format: "%.2f", viewModel.threshold))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $viewModel.threshold, in: 0.0...1.0, step: 0.01)
                        .disabled(viewModel.isMonitoring)

                    HStack {
                        Toggle("Discard late frames", isOn: $viewModel.discardLateFrames)
                        Spacer()
                    }
                    .font(.subheadline)
                    .disabled(viewModel.isMonitoring)

                    HStack {
                        Toggle("Save iteration data", isOn: $viewModel.saveIterationData)
                        Spacer()
                    }
                    .font(.subheadline)
                    .disabled(viewModel.isMonitoring)

                    if let watcherReason = viewModel.watcherReasonText {
                        Text(watcherReason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !viewModel.watcherTracePathText.isEmpty {
                        Text("Trace path: \(viewModel.watcherTracePathText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        Button(viewModel.isMonitoring ? "Stop" : "Start") {
                            viewModel.toggleMonitoring()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Test alert") {
                            viewModel.testAlert()
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .alert("Camera Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        if viewModel.isMonitoring {
            CameraPreview(session: viewModel.camera.session)
                .frame(height: 280)
                .overlay(alignment: .topLeading) {
                    statusBadge
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
        } else {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
                .frame(height: 180)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "video.slash")
                            .font(.system(size: 28))
                            .foregroundStyle(.secondary)
                        Text("Camera preview is off")
                            .font(.headline)
                        Text("Press Start to begin watching and open the camera.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(20)
                }
                .overlay(alignment: .topLeading) {
                    statusBadge
                }
                .padding(.horizontal)
        }
    }

    private var statusBadge: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.statusText)
                .font(.headline)
            if let score = viewModel.lastScore {
                Text(String(format: "Score: %.3f", score))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(10)
    }
}
