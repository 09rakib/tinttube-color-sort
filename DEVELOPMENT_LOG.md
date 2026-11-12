# TintTube development log

## Milestone 2 · Visual Gameplay

Added tube lift and tilt, a colored stream with synchronized liquid levels, invalid-target shake, and a victory reveal. The tube art moves independently of its touch target. Each legal pour commits once to the rules engine. The board keeps the tube controls, level picker, Undo, and Restart locked until the visual transfer settles. A resize or application pause finishes the committed move and restores the display.

Added an audio manager and five original, synthesized cues for button actions, tube selection, invalid moves, pouring, and victory.

### Verification

- Godot 4.7.2 imported the audio and booted the native project.
- The headless suite passed twice with **199 checks and 0 failures**. New checks cover rapid and queued input, matching fractional liquid changes, a multi-layer transfer interrupted by a resize, backgrounding, and audio playback triggers.
- Captured active pours on Levels 1, 2, and 5 in the Windows Compatibility renderer at 390 × 820 and 320 × 600. Inspected the tilt, stream placement, and visible fill.
- Verified all five WAV files have non-silent, unclipped mono PCM samples.

Android touch, audio, and real-device backgrounding remain to be verified. Milestone 3 adds the solver, level progression, and local saves.

## Milestone 1 · Core Gameplay

Initialized the Godot 4.7 project with a portrait canvas, responsive scaling, and a mobile safe-area handler. Added a reusable glass tube scene with liquid glyphs and a gameplay board with a sample picker, move counter, Undo, Restart, and victory controls.

The rules script owns board state, pours, deep undo snapshots, and win detection. The level catalog validates the five JSON boards before play. The Godot theme uses the Stitch palette and the bundled Nunito Sans font. The existing browser prototype remains available in the repository.

### Verification

- Godot 4.7.2 editor import and headless project boot completed.
- `godot --headless --path . --script res://tests/run_core_tests.gd` passed **179 checks with 0 failures**. This covered rejected moves, multi-layer pours, capacity limits, undo, restart, win detection, valid-move enumeration, verified solution replays for all five boards, and pointer input through the gameplay scene.
- Rendered Level 5 on Windows in Godot's Compatibility renderer at 390 × 820, 320 × 600, and 640 × 500. Checked that the board and action buttons fit and inspected the resulting frames.

### Remaining work

Milestone 1 used immediate pours and session-only state. Android touch, device safe areas, debug APK export, and performance on Android remained to be verified.
