# TintTube Color Sort

TintTube is an offline-first, portrait color-sort puzzle for Android. The native Godot project currently includes five playable tutorial puzzles. The browser prototype remains available as a visual reference for the remaining screens.

## Run the Godot game

1. Install the standard, non-.NET edition of [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/).
2. Import `project.godot` in the project manager and press **F5** after the first import.
3. Pick a sample level. Tap or click a filled tube, then choose an empty tube or one with the same top color and room. Undo and Restart are available below the board. Solving the puzzle opens the next sample.

Levels are stored bottom-to-top in `data/levels/core_levels.json`. The move counter tracks successful pours since the start of the current attempt, with undone moves removed from the count. The sample picker keeps all five boards available for testing. The current milestone holds progress in memory during the session.

## Verify the native build locally

Run these commands from the repository root with Godot on your PATH. On Windows, use the downloaded `_console.exe` executable in place of `godot` for terminal output.

```sh
godot --headless --path . --editor --import
godot --headless --path . --quit-after 5
godot --headless --path . --script res://tests/run_core_tests.gd
```

The test runner validates the rules, replays a solution for each sample, and sends pointer input to the native gameplay scene. It exits with code 1 if a check fails.

## Android export

Install the export templates that match the Godot version, then configure Java and the Android SDK using the [Godot Android export guide](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html). To try a debug APK, create an Android export preset, include `data/levels/*.json` in the non-resource file filter, and export to `build/`. Portrait orientation is set in the project. Device testing, the final application ID, and the signed AAB are release milestones.

## Open the Stitch reference

Run `python -m http.server 8080 --bind 127.0.0.1` from the repository root and open the [browser prototype](http://127.0.0.1:8080/). The HTML, styles, and prototype interactions are separate from the native game. After changing Tailwind classes in the reference, run `npm ci` and `npm run build:css`.

See [TASKS.md](TASKS.md) for milestone status and [DEVELOPMENT_LOG.md](DEVELOPMENT_LOG.md) for verification results.
