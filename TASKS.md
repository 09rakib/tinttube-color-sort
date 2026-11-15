# TintTube tasks

## Milestone 1 — Core Gameplay

- [x] Inspect the repository and use the Stitch screens as the visual reference.
- [x] Initialize the portrait Godot project and reusable tube scene.
- [x] Implement independent puzzle rules, tap controls, undo, restart, and win detection.
- [x] Add five sample levels and verify a solution path for each.
- [x] Run the native gameplay test suite and document the results.

## Milestone 2 — Visual Gameplay

- [x] Animate tube lifting, tilting, pouring, invalid moves, and victory reveal.
- [x] Keep the board and rendered liquid synchronized during animations.
- [x] Add original sound effects and polish input feedback.

## Milestone 3 — Level System

- [x] Implement the independent solver and replay solutions for 50 levels.
- [x] Build native level selection and sequential unlocking.
- [x] Implement versioned local saves for completion, best moves, and the current level.

## Milestone 4 — UI and Rewards

- [x] Build the native Home, Settings, and Shop screens.
- [x] Implement coins and star ratings.
- [x] Connect hints to the solver and coin balance.

## Milestone 5 — Daily Challenges and Accessibility

- [x] Add solver-verified daily generation, date-based rewards, and achievements.
- [x] Add optional tube color names and reduced motion.
- [x] Measure frame intervals in the Windows build.

## Next milestone — Monetization and QA

- [x] Select an Android AdMob plugin and connect the optional rewarded offer, consent, and wallet callbacks.
- [x] Define the Play Billing interface for future paid products.
- [x] Verify the rewarded demo ad and saved coins on Android after the UMP status update.
- [x] Verify offline ad failure and retry, touch pours, background and resume, Undo, Restart, and the Level 1 save on an Android emulator.
- [ ] Verify region-specific UMP forms with a configured test app and message.
- [ ] Finish Android regressions, including physical device vibration and frame pacing.

## Later milestones

- [x] 7 · Document Play Console and Android release checks.
- [ ] 7 · Set the final application ID, configure release export, and verify the signed AAB.

## Release dependencies

- Physical Android device testing. The QA build was verified with the Godot 4.7.2 export templates, Android SDK, and JDK 17.
- Final Android application ID and signing credentials before a signed release.
