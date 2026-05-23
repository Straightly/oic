import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ToastMonitorViewModel()

    var body: some View {
        VStack(spacing: 12) {
            CameraPreview(session: viewModel.camera.session)
                .overlay(alignment: .topLeading) {
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
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 10) {
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
                    Text(viewModel.gemmaRuntimeStatusText)
                        .font(.subheadline)
                    Text("Expected model bundle path: \(viewModel.gemmaExpectedModelPath)")
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
                    Text("Readiness threshold")
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

            Spacer()
        }
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
}
