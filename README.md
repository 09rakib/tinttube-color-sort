# TintTube Color Sort

TintTube is an offline-first, portrait color-sort puzzle for Android. The native Godot project includes 50 solver-verified puzzles across Tutorial, Easy, and Medium. The browser prototype remains available as a visual reference for the remaining screens.

## Run the Godot game

1. Install the standard, non-.NET edition of [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/).
2. Import `project.godot` in the project manager and press **F5** after the first import.
3. Choose **Play** for the furthest unlocked level or **Continue** to reopen the last selected level. Tap or click a filled tube, then choose an empty tube or one with the same top color and room. Complete a puzzle to unlock the next one. Open **Levels** to see your stars and replay unlocked puzzles.

Levels are stored bottom-to-top in `data/levels/core_levels.json` with their shortest solution length. The move counter tracks successful pours in the current attempt, with undone moves removed from the count.

Progress saves automatically when you complete or change levels, buy or equip a cosmetic, or change a setting. It keeps completions, unlocked levels, best move counts, and your wallet. Reopening a level starts a fresh attempt. Versioned progress lives in alternating `user://tinttube-progress.*.json` files, with the previous valid save available if the latest one is damaged.

The wallet starts with 100 coins. A first clear earns 20 coins, and the first three-star clear of that level adds 10. Three stars require matching the shortest solution, and two stars allow up to three extra moves. A confirmed hint costs 50 coins once the solver finds a valid next move. Shop cosmetics are earned with game coins and can be equipped again for free.

The selected tube lifts, legal pours animate the transfer, and invalid targets shake. Board controls become available again when the pour finishes. A resize or application pause settles the active move and restores the tube positions. The pour cue blends TintTube's original sound with an edited excerpt of [Pouring liquid in a cup by OxidVideos](https://pixabay.com/sound-effects/film-special-effects-pouring-liquid-in-a-cup-386762/). The remaining cues are original, synthesized WAV files.

## Verify the native build locally

Run these commands from the repository root with Godot on your PATH. On Windows, use the downloaded `_console.exe` executable in place of `godot` for terminal output.

```sh
godot --headless --path . --editor --import
godot --headless --path . --quit-after 5
godot --headless --path . --script res://tests/run_core_tests.gd
```

The test runner solves and replays all 50 boards, validates their recorded move targets, and tests progression, save recovery, and the native gameplay controls. It exits with code 1 if a check fails.

## Android export

Install the export templates that match the Godot version, then configure Java and the Android SDK using the [Godot Android export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html). To try a debug APK, create an Android export preset, include `data/levels/*.json` in the non-resource file filter, and export to `build/`. Portrait orientation is set in the project. Device testing, the final application ID, and the signed AAB are release milestones.

## Open the Stitch reference

Run `python -m http.server 8080 --bind 127.0.0.1` from the repository root and open the [browser prototype](http://127.0.0.1:8080/). The HTML, styles, and prototype interactions are separate from the native game. After changing Tailwind classes in the reference, run `npm ci` and `npm run build:css`.

See [TASKS.md](TASKS.md) for milestone status and [DEVELOPMENT_LOG.md](DEVELOPMENT_LOG.md) for verification results.
