# OIC Watcher Inference Contract

## Purpose

Define the smallest app-facing inference contract that lets OIC act like a "watch it for me" visual agent even before the final model path is settled.

This contract is intentionally small enough to support:

- the current toast watcher
- the current cat-door watcher fallback
- future Gemma-driven watcher specifications

## Core idea

OIC should separate:

1. `watcher specification`
2. `frame observation`
3. `frame interpretation`
4. `event decision`
5. `user alert`

For the current submission, the contract only needs to support one live camera scene at a time.

## Watcher specification

A watcher specification tells the app what to watch and what events matter.

Minimum fields:

```json
{
  "watcher_id": "cat-door-v0",
  "title": "Back Door Cat Watcher",
  "prompt": "Watch the back door and tell me whether my cat went out or came home.",
  "scene_target": "back_door",
  "mode": "baseline_scene_monitor",
  "labels": ["out", "in", "none", "uncertain"],
  "baseline_assets": [],
  "notes": "Current version has doorway baseline coverage only."
}
```

## App input

For each observed frame, the app should be able to hand the local watcher this minimal input:

```json
{
  "watcher_id": "cat-door-v0",
  "frame_id": "frame-0001",
  "timestamp": "2026-05-22T10:15:00-07:00",
  "image_source": "live_camera",
  "image_path": "optional/local/path.jpg",
  "scene_hint": "back_door"
}
```

## App output

The local watcher should return a compact, app-friendly interpretation:

```json
{
  "watcher_id": "cat-door-v0",
  "frame_id": "frame-0001",
  "scene_status": "baseline_match",
  "label": "none",
  "confidence": 0.82,
  "alert": false,
  "reason": "Observed frame matches the known doorway baseline; no event-worthy change detected."
}
```

## Required output fields

- `scene_status`
  - one of `baseline_match`, `change_detected`, `invalid_view`, `unknown`
- `label`
  - one of the watcher labels
- `confidence`
  - floating point score from 0 to 1
- `alert`
  - whether the app should notify the user
- `reason`
  - short explanation suitable for logs or debug UI

## Minimal local inference loop

This is the smallest loop needed for the current demo:

1. Load watcher specification.
2. Accept or capture a frame.
3. Check whether the scene matches the expected target well enough to proceed.
4. If the scene is invalid:
   - return `scene_status = invalid_view`
   - return `label = uncertain`
   - do not claim a cat event
5. If the scene is valid and matches baseline:
   - return `scene_status = baseline_match`
   - return `label = none`
6. If the scene is valid but differs meaningfully from baseline:
   - return `scene_status = change_detected`
   - return the best current label
   - if the model is not confident, use `uncertain`
7. Trigger an alert only when:
   - confidence is above the chosen threshold
   - and the event is not `none`

## Current cat-door fallback behavior

Because current captured data only includes the doorway baseline image and not actual cat transitions, `cat-door-v0` should currently support:

- target scene identification
- baseline match recognition
- invalid-scene detection
- unknown / uncertain fallback

It should **not** pretend full `out` / `in` classification is already proven.

## Current toast behavior

The same contract can support the toast watcher with a different watcher specification:

- `scene_target = toaster`
- labels like `not_ready`, `close`, `ready`, `uncertain`

This is important for the submission because it shows OIC as one watcher system with multiple tasks.

## Alerting policy

Current rule:

- `alert = true` only for confident, non-neutral results
- for cat-door v0, neutral is `none`
- for toast, neutral is `not_ready`

## Logging

Every watcher result should be loggable as a compact event row:

```json
{
  "timestamp": "2026-05-22T10:15:00-07:00",
  "watcher_id": "cat-door-v0",
  "frame_id": "frame-0001",
  "scene_status": "baseline_match",
  "label": "none",
  "confidence": 0.82,
  "alert": false
}
```

## Why this completes the current milestone

`M21-03` is about the simplest inference loop that can support the demo.

Given the current repo state, the most important thing to lock is not the final model implementation but the boundary between:

- promptable watcher setup
- local observation
- local decision
- app alerting

That boundary is now defined well enough to build or test manually.
