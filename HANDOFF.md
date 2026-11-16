# TintTube handoff

Milestone 5 is complete. Gameplay baseline is commit `10280f0` on `main`. TintTube is an offline-first portrait water-sort game built with Godot 4.7.2 Standard and the Compatibility renderer. [README.md](README.md) covers setup, [TASKS.md](TASKS.md) tracks the roadmap, and [DEVELOPMENT_LOG.md](DEVELOPMENT_LOG.md) records verification.

## Git workflow for every coding task

After every coding task, verify the changes, commit the files for that task, and push the commit to GitHub before reporting completion. The owner has already requested this as the default workflow for this repository, including work started in a new chat. The existing Windows checkout is `C:\Users\ASUS\Desktop\tinttube-color-sort`. The remote is `origin` (`https://github.com/09rakib/tinttube-color-sort.git`) and the target branch is `main`.

Run these PowerShell commands from the checkout. Use the existing checkout when available. For a fresh checkout, run `git clone https://github.com/09rakib/tinttube-color-sort.git` and enter the resulting directory.

```powershell
Set-Location 'C:\Users\ASUS\Desktop\tinttube-color-sort'
git status --short --branch
git remote -v
git fetch origin
```

Verify the current branch and check for existing work before editing. If `main` is behind and the checkout is clean, update it with `git pull --ff-only origin main`. Preserve existing edits. After making the changes and running the relevant checks, use the following sequence. Replace the example paths and commit message with the actual files and a description of the task. Check each command before proceeding.

```powershell
git diff --check
git add -- scripts/gameplay/game_board.gd tests/run_core_tests.gd
git diff --cached --check
git diff --cached --stat
git commit -m 'Describe the verified change'
git push origin main
git status --short --branch
git rev-parse HEAD origin/main
```

Matching hashes in the final command confirm that the local commit and `origin/main` agree. Report the commit hash or GitHub commit link. If the push fails, surface the reason and preserve the local commit. Resolve any divergence before retrying and avoid force-pushing `main`. Keep generated builds, local tooling, and signing credentials outside the commit.

## What works

- The campaign has 1,000 solver-verified puzzles, sequential unlocks, replay, undo, restart, and star ratings. Hard starts at level 36, and Expert starts at level 101. Each board from level 36 onward starts with two empty tubes. Super Hard levels end in 7 and require five matching layers per tube.
- Daily Challenge generates and verifies a puzzle from the device’s local date. The first clear earns 40 coins, and replays can improve the best result. Switching to Daily keeps the active campaign attempt in memory.
- The wallet starts at 100 coins. A first campaign clear earns 20, and the first three-star result for that level earns 10 more. Confirmed hints cost 50 coins once the solver finds a valid move. Shop purchases use game coins.
- The glass artwork uses translucent rims, reflections, and softly colored animated water. Every fifth level covers the hidden layers with gold `?` markers until a pour exposes them. Optional color names sit below the tubes. Settings also include reduced motion, music, sound effects, and vibration.

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

## Milestone 6 in progress

The optional rewarded offer is wired to Poing AdMob 5.1.0 in Android debug builds. It uses Google's demo unit and awards 20 coins once on the SDK's earned callback. The offline build runs without the addon. [Android QA](ANDROID_QA.md) covers the build commands, device checks, and the Google Play Billing interface. Cosmetics still use the in-game wallet.

The Android emulator loaded and displayed a demo ad, awarded 20 coins once, and retained the balance after relaunch. Finish the region-specific consent form and the remaining device regressions. Milestone 7 still needs the final Android application ID, Play Console access, and the upload key before exporting and validating a signed AAB.
