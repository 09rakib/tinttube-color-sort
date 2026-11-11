# TintTube Color Sort

A mobile-first UI prototype built from the Google Stitch export. It includes home, splash, level selection, gameplay, two pouring previews, daily challenge, shop, settings, and the level-complete screen.

## Open the prototype

From the repository root, run `python -m http.server 8080 --bind 127.0.0.1` and open [TintTube](http://127.0.0.1:8080/). The checked-in styles and fonts are served locally, so the preview runs without an internet connection. Open [the splash screen](http://127.0.0.1:8080/splash.html) to see the loading transition.

Select **Play** to open the level list. In gameplay, open the preview menu to see the pouring states and the level-complete screen. The board, scores, balances, and shop catalog use sample data. Puzzle rules, rewards, purchases, and audio playback are planned for a later phase.

## Update the styles

Screen markup lives in the HTML files at the repository root. Shared UI styles and behavior live in `assets/ui.css` and `assets/ui.js`. After changing Tailwind classes or design tokens, run `npm ci` and `npm run build:css` to regenerate `assets/tailwind.css`.
