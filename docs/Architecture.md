# OIC Architecture

## Intent

OIC is no longer just an app folder. It is an umbrella repo with one existing app subproject and a parallel vision stack.

The structure is meant to support this loop:

1. Capture runs in the iPhone app.
2. Keep those runs raw and immutable in `Runs/`.
3. Curate training-ready datasets in `Vision/Datasets/`.
4. Improve detectors in `Vision/Baselines/` or `Vision/Training/`.
5. Store checkpoints and exported artifacts in `Vision/Models/`.
6. Package app-ready model outputs through `Vision/Deployment/`.
7. Integrate the chosen artifact back into `iOS/ItIsToasted/`.

## Subproject Roles

### `iOS/`

Owns the user-facing prototypes, camera capture, local inference hooks, and alerting behavior.

### `Runs/`

Owns raw sessions captured from experiments. Treat these as evidence and source material, not as the place to hand-edit training datasets.

### `Vision/Baselines/`

Owns non-neural detection logic and offline experiments that help answer whether a neural model is needed.

### `Vision/Datasets/`

Owns curated slices derived from raw runs: labels, manifests, split definitions, and processed assets.

### `Vision/Training/`

Owns fine-tuning, training, and experiment configuration for neural models.

### `Vision/Models/`

Owns checkpoints, exported models, model cards, and training reports.

### `Vision/Deployment/`

Owns the boundary between trained models and app-consumable artifacts such as Core ML exports.

### `Vision/Evaluation/`

Owns metrics, test sets, and repeatable quality checks.

## Boundaries That Matter

- Do not bury training notebooks or checkpoints inside `iOS/`.
- Do not overwrite raw `Runs/` data when creating labels or processed examples.
- Do not force all future use cases into toast-specific names inside the ML folders.
- Do not assume a neural model is required for every detection task.

## Recommended Evolution Path

### Stage 1

Keep improving the toast heuristic while collecting better runs.

### Stage 2

Curate the first labeled dataset from captured toast sessions.

### Stage 3

Fine-tune a small model for one narrow task:

- readiness classification
- toast-region detection
- change detection across a short time window

### Stage 4

Export the best candidate into an app-friendly artifact and compare it with the heuristic path.

### Stage 5

Generalize the structure for additional "things/changes" that OIC should detect.
