# TintTube handoff

Milestone 5 is complete. Gameplay baseline is commit `10280f0` on `main`. TintTube is an offline-first portrait water-sort game built with Godot 4.7.2 Standard and the Compatibility renderer. [README.md](README.md) covers setup, [TASKS.md](TASKS.md) tracks the roadmap, and [DEVELOPMENT_LOG.md](DEVELOPMENT_LOG.md) records verification.

## What works

- The campaign has 50 solver-verified puzzles, sequential unlocks, replay, undo, restart, and star ratings.
- Daily Challenge generates and verifies a puzzle from the device’s local date. The first clear earns 40 coins, and replays can improve the best result. Switching to Daily keeps the active campaign attempt in memory.
- The wallet starts at 100 coins. A first campaign clear earns 20, and the first three-star result for that level earns 10 more. Confirmed hints cost 50 coins once the solver finds a valid move. Shop purchases use game coins.
- The glass artwork uses translucent rims, reflections, and softly colored animated water. Keep symbols out of the liquid. Optional color names sit below the tubes. Settings also include reduced motion, music, sound effects, and vibration.

## Where to make changes

| Area | Entry point |
| --- | --- |
| Game startup and navigation | [scenes/main.tscn](scenes/main.tscn), [scripts/gameplay/game_board.gd](scripts/gameplay/game_board.gd) |
| Puzzle rules, search, and daily generation | [game_rules.gd](scripts/gameplay/game_rules.gd), [puzzle_solver.gd](scripts/gameplay/puzzle_solver.gd), [daily_generator.gd](scripts/gameplay/daily_generator.gd) |
| Campaign data | [core_levels.json](data/levels/core_levels.json), with layers ordered bottom to top and a verified move target for each level |
| Home, Daily, Achievements, Shop, and Settings | [game_menu.gd](scripts/ui/game_menu.gd) |
| Tube artwork, pour motion, and audio | [tube.gd](scripts/ui/tube.gd), [pour_animation.gd](scripts/ui/pour_animation.gd), [audio_manager.gd](scripts/services/audio_manager.gd) |
| Wallet, rewards, and saves | [rewards.gd](scripts/services/rewards.gd), [player_progress.gd](scripts/services/player_progress.gd) |
| Regression suite | [run_core_tests.gd](tests/run_core_tests.gd) |

The save format is version 3 and reads versions 1 and 2. Progress alternates between two `user://tinttube-progress.*.json` slots and falls back to the previous valid slot. Keep wallet changes and their associated progress or purchase in the same save operation. A game restart keeps completion records, wallet, and preferences. It starts the selected puzzle from its initial board.

## Run and verify

Open `project.godot` with Godot 4.7.2 Standard and press **F5**. From the repository root, run the following commands. On Windows, use the Godot console executable if `godot` is unavailable on PATH.

```sh
godot --headless --path . --editor --import
godot --headless --path . --quit-after 5
godot --headless --path . --script res://tests/run_core_tests.gd
```

The Milestone 5 suite passed 3,053 checks. A Windows run on a GTX 1650 averaged 60 FPS in two 180-frame samples of Level 50 at 390 × 820, both idle and during pours. Android device performance and vibration still need verification.

The [local browser preview](http://127.0.0.1:8765/play.html?build=daily) works while the preview server is running. To rebuild on another machine, install the matching Godot Web export template, create a single-threaded Web preset, include `data/levels/*.json`, and export into `build/web/`. Serve that directory over HTTP. The root HTML files are the Stitch reference.

## Pick up at Milestone 6

1. Select a maintained Android AdMob integration compatible with Godot 4.7.2. Verify rewarded ads with test units, handle load and show failures, and award coins only after the provider’s reward callback. Keep the game playable offline and account for the provider’s consent requirements.
2. Define the Google Play Billing interface. Current shop items use the in-game wallet.
3. Run Android regressions for touch, navigation, vibration, pause and resume, saves, and ad failure paths. Follow the Android setup in [README.md](README.md).

Milestone 7 covers the final Android application ID, signed AAB, Play Console requirements, and release preparation. Signing credentials are a release input.
