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

The app also expects CocoaPods dependencies to be installed, so build from:

- `ItIsToasted/ItIsToasted.xcworkspace`

not the standalone `.xcodeproj`.

## Local model files

The Gemma GGUF model files are local-only and are intentionally excluded from git.

Current model defaults used by the app:

- primary model filename: `google_gemma-4-E2B-it-Q4_K_S.gguf`
- projection model filename: `mmproj-google_gemma-4-E2B-it-f16.gguf`

For real iPhone testing, copy them into:

- `ItIsToasted/ItIsToasted/Models/google_gemma-4-E2B-it-Q4_K_S.gguf`
- `ItIsToasted/ItIsToasted/Models/mmproj-google_gemma-4-E2B-it-f16.gguf`

Current development/simulator source files on this machine:

- `/Users/zhian/Downloads/bartowski/google_gemma-4-E2B-it-GGUF/google_gemma-4-E2B-it-Q4_K_S.gguf`
- `/Users/zhian/Downloads/bartowski/google_gemma-4-E2B-it-GGUF/mmproj-google_gemma-4-E2B-it-f16.gguf`

Important behavior:

- the iPhone app cannot read your Mac download folder directly
- for a real phone run, the files must exist under `ItIsToasted/ItIsToasted/Models/`
- the app is currently coded to use these exact filenames

## Repro steps

1. Install CocoaPods dependencies for `ItIsToasted/`.
2. Download the official `llama.cpp` iOS XCFramework and place it at `ItIsToasted/ItIsToasted/ThirdParty/llama.xcframework`.
3. Copy the two Gemma GGUF model files into `ItIsToasted/ItIsToasted/Models/` using the exact filenames above.
4. Open `ItIsToasted/ItIsToasted.xcworkspace`.
5. Build and run the `ItIsToasted` scheme.
