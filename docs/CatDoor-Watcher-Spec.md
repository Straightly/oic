# Cat-Door Watcher Spec

## Watcher ID

`cat-door-v0`

## User prompt

`Watch the back door and tell me whether my cat went out or came home.`

## Submission role

This watcher is the real-world headline use case for the Gemma 4 submission.

For the current submission, it is intentionally scoped as:

- a real watcher concept
- a real monitored scene
- a real personal problem
- an incomplete event dataset

That means the watcher should be honest about what it currently proves.

## Current available evidence

- one captured image of the doorway in the open-door state
- no reliable captured sequence yet of the cat going out
- no reliable captured sequence yet of the cat coming in

## Scene target

The watcher is responsible for the doorway area only.

Expected scene:

- back door visible
- doorway framing relatively stable
- camera placement mostly fixed

## Labels

- `out`
- `in`
- `none`
- `uncertain`

## Current operational meaning of labels

### `none`

Use when:

- the observed frame matches the known baseline doorway scene
- no event-worthy change is confidently detected

### `uncertain`

Use when:

- the scene is partially blocked
- framing changes too much
- lighting changes too much
- the model cannot confidently determine whether an event occurred

### `out`

Reserved for future use once cat-transition evidence exists.

### `in`

Reserved for future use once cat-transition evidence exists.

## Current minimum success criteria

The watcher can be considered minimally useful for the current submission if it can:

1. accept the natural-language watch request
2. target the doorway scene
3. preserve the intended event labels
4. recognize the captured doorway baseline as `none`
5. avoid falsely claiming `in` or `out` without evidence

## Current failure conditions

The watcher should return `uncertain` if:

- the door scene is not visible enough
- the camera view is too different from the baseline framing
- the frame quality is too poor
- the local watcher cannot make a reliable decision

## Planned next milestone

Once cat-transition images or short clips are available, extend the watcher to:

1. distinguish baseline doorway vs eventful doorway
2. distinguish inward vs outward motion
3. add temporal reasoning across a short frame window
4. log `out` / `in` events with timestamps

## Submission framing note

In the DEV submission, this watcher should be presented as:

- the stronger product story
- the more realistic reason for using a visual model
- the part of OIC that still needs more captured evidence

That is a strength if stated honestly, because it shows the project is solving a real problem rather than staging a perfect artificial benchmark.
