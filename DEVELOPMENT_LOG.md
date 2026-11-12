# TintTube development log

## Milestone 1 · Core Gameplay

Initialized the Godot 4.7 project with a portrait canvas, responsive scaling, and a mobile safe-area handler. Added a reusable glass tube scene with liquid glyphs and a gameplay board with a sample picker, move counter, Undo, Restart, and victory controls.

The rules script owns board state, pours, deep undo snapshots, and win detection. The level catalog validates the five JSON boards before play. The Godot theme uses the Stitch palette and the bundled Nunito Sans font. The existing browser prototype remains available in the repository.

### Verification

- Godot 4.7.2 editor import and headless project boot completed.
- `godot --headless --path . --script res://tests/run_core_tests.gd` passed **179 checks with 0 failures**. This covered rejected moves, multi-layer pours, capacity limits, undo, restart, win detection, valid-move enumeration, verified solution replays for all five boards, and pointer input through the gameplay scene.
- Rendered Level 5 on Windows in Godot's Compatibility renderer at 390 × 820, 320 × 600, and 640 × 500. Checked that the board and action buttons fit and inspected the resulting frames.

### Remaining work

Milestone 2 covers animated pours, input locking during animations, and sound. The current run uses immediate pours and session-only state. Android touch, device safe areas, debug APK export, and performance on Android remain to be verified.
