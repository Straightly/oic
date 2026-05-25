# OIC

OIC ("Oh, I See") is a local visual-watching project. The current iOS app lives in `ItIsToasted/` and is being extended from toast monitoring toward promptable on-device watchers such as cat-door monitoring.

## Repo layout

- `ItIsToasted/`: iOS app workspace and source
- `Runs/`: captured run artifacts and experiment output

## Build requirement

The iOS app currently depends on a locally installed third-party runtime that is **not checked into git**:

- required path: `ItIsToasted/ItIsToasted/ThirdParty/llama.xcframework`

Before building the app, download the official `llama.cpp` iOS XCFramework release and place `llama.xcframework` at that path.

Current runtime used by this repo:

- runtime: `llama.cpp` iOS XCFramework
- local install path: `ItIsToasted/ItIsToasted/ThirdParty/llama.xcframework`
- source release family: official `ggml-org/llama.cpp` XCFramework release artifact

The app no longer depends on CocoaPods Gemma inference packages. The active local model path is the vendored `llama.cpp` XCFramework plus local GGUF files.

## Local model files

The Gemma GGUF model files are local-only and are intentionally excluded from git.

Current model defaults used by the app:

- primary model filename: `google_gemma-4-E2B-it-Q4_K_S.gguf`
- projection model filename: `mmproj-google_gemma-4-E2B-it-f16.gguf`

Canonical runtime location:

- the app Documents folder under `Models/`
- the app expects the files in:
  - `Documents/Models/google_gemma-4-E2B-it-Q4_K_S.gguf`
  - `Documents/Models/mmproj-google_gemma-4-E2B-it-f16.gguf`

Current development/simulator source files on this machine:

- `/Users/zhian/Downloads/bartowski/google_gemma-4-E2B-it-GGUF/google_gemma-4-E2B-it-Q4_K_S.gguf`
- `/Users/zhian/Downloads/bartowski/google_gemma-4-E2B-it-GGUF/mmproj-google_gemma-4-E2B-it-f16.gguf`

Important behavior:

- the iPhone app cannot read your Mac download folder directly
- do not keep the `.gguf` files under `ItIsToasted/ItIsToasted/Models/`, because Xcode will bundle them into the app and make the build enormous
- instead, copy the files into the app’s Documents area as a separate operation
- if Finder only lets you drop files onto the app root, that is okay: the app will move the expected `.gguf` files from the Documents root into `Documents/Models/` when you use `Refresh Gemma status` or `Test Gemma runtime`
- the app is currently coded to use these exact filenames

## Repro steps

1. Install CocoaPods dependencies for `ItIsToasted/`.
2. Download the official `llama.cpp` iOS XCFramework and place it at `ItIsToasted/ItIsToasted/ThirdParty/llama.xcframework`.
3. Open `ItIsToasted/ItIsToasted.xcworkspace`.
4. Build and run the app once so its Documents container exists.
5. Use Finder/iPhone file sharing to copy the two GGUF files into the app.
6. If Finder only accepts drops on the app root, drop them there.
7. Launch the app and use `Refresh Gemma status` or `Test Gemma runtime`; the app will move the files into `Documents/Models/` before checking them.

## Current cat-door limitation

The cat-door watcher currently uses the GGUF Gemma runtime for startup validation and frame capture tracing only.

- it does **not** currently perform true image-conditioned Gemma inference on captured door frames
- the earlier first-frame multimodal experimentation was removed because it did not match the GGUF assets used by this repo
- the next valid multimodal step must use a real GGUF-compatible iOS API for image ingestion
