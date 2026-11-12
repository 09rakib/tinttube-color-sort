# TintTube development log

## Milestone 5 · Daily Challenges and Accessibility

Added an offline puzzle for each local calendar date. A seeded shuffle supplies candidates, and the solver checks every accepted board against a 10–18 move target. The save keeps the approved board and completion history, and awards 40 coins on the first clear of each date. Switching to Daily preserves the current campaign attempt in memory. Achievements track milestones in both modes.

Added optional color names below the glass, full layer names for screen readers, and a reduced-motion setting. Hidden tubes stop updating their liquid surfaces.

The Godot suite passed 3,053 checks. It generated and replayed eight daily boards in 847 ms, checked same-date reproducibility, and covered migration and daily reward deduplication. In the Windows Compatibility renderer on a GTX 1650 at 390 × 820, two 180-frame samples of Level 50 averaged 60 FPS both idle and during pours. The 95th-percentile frame intervals were 16.9 ms idle and 17.0 ms during pours. Android device performance remains unmeasured.

## Milestone 4 · UI and Rewards

Added Home, Settings, and Shop to the native game. The shop equips themes and glass rims. Music, sound effects, and Android vibration have separate saved preferences.

The wallet earns coins on the first clear and on the first three-star result for each level. Older saves receive the starting wallet and the base reward for previously completed levels. Hint search runs in batches between frames and charges only after confirmation and a valid result.

The Godot suite passed 2,928 checks, including older save migration, replay rewards, shop persistence, failed purchases, and accepted hints. Home, Shop, Settings, and gameplay were checked in the Windows renderer at 390 × 820 and 320 × 600. Android vibration still needs on-device verification.

## Liquid rendering update

Removed symbols from the liquid and replaced the solid fills with a lighter palette, gradients, and gently moving surfaces. Matching layers render as a single body of water. Glass reflections, stream highlights, and a small splash reinforce the effect during a pour.

Refined the tubes using the bottle reference. The glass now has a recessed oval opening, visible headspace, a rounded base, and highlights that continue across the empty and filled parts of the tube.

Checked the idle and pouring states in Godot. The headless suite passed 2,914 checks with zero failures.

## Milestone 3 · Level System

Expanded the catalog from five to 50 puzzles. Kept the first five boards and selected 45 additional boards using a seeded shuffle, move-count filters, and checks for equivalent color and tube permutations. The tiers are Tutorial (1–10), Easy (11–30), and Medium (31–50).

Added a bounded breadth-first solver that shares the gameplay rules and deduplicates equivalent tube orders. The solver distinguishes an exhausted search from a search that hit its limit. Added the native scrollable level grid, sequential unlocking, and replay of completed levels.

Added versioned progress saves for the selected level and the best move counts of completed levels. The active slot stays intact during a write. The loader recovers from an interrupted or damaged write using the previous valid slot and preserves newer or unrecoverable saves for recovery.

### Verification

- Godot 4.7.2 imported and booted the project.
- The final headless suite passed **2,914 checks with 0 failures**. It solved all 50 boards and replayed every move through the gameplay rules. Each path preserved color totals and capacity and matched the shortest move count recorded in the catalog. The final Windows run took about 6.5 seconds for all 50 solves. The largest search expanded 6,167 states.
- Exercised sequential unlocks, replay, resume, partial writes, corrupted slots, a failed write followed by retry, and newer-schema protection.
- Inspected the fresh and progressed level grids and the eight-tube final board in the Windows Compatibility renderer at 390 × 820 and 320 × 600.

An in-progress attempt restarts from its initial board when reopening the game. Native coins, star ratings, and paid hints are planned for Milestone 4. Android device testing remains pending.

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
