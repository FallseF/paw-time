# Paw Time launch page

Static English landing page, Japanese equivalent at `/ja/`, and legacy English alias `/en/`.
No build step, package installation, credentials, or API is required.

```sh
node apps/marketing/verify.mjs
python3 -m http.server 4179 --bind 127.0.0.1 --directory apps/marketing
```

Open http://127.0.0.1:4179/. Check that port 4179 is available before starting the server.

## Editing

- `index.html` and `ja/index.html`: equivalent English/Japanese content.
- `site.css`: shared presentation and responsive layouts.
- `site.js`: trailer dialog, motion-aware background video, character filters.
- `verify.mjs`: checks references, media, IDs, locale routes, script syntax and the preserved collection.
- `/en/` redirects to English. Game links use the existing browser build without unsupported language/demo parameters.

The three-minute route and language toggle are **inside the game**. Starting that route can replace saved game progress after the game's confirmation; this page does not start or reset it automatically.

## Content boundaries

Jobs are sample listings. The business model is a proposal. User retention, wellbeing, hiring outcomes and paying-customer traction have not been validated by this LP. Source/architecture/data links point to the public monorepo.

The gallery retains all 30 existing portraits and group filters. It presents names and themes, rather than an unlock checklist that can incentivize sleep deprivation or extra work. Underlying game rules are unchanged.

## Assets

Original character portraits remain unchanged. Screenshots (`img/shot_*.webp`), locale-specific posters and the two 44-second trailers were recovered on 2026-09-26 from the team's existing public LP at https://paw-time-launch.vercel.app/ using the paths declared in its English/Japanese HTML. They are actual product assets, not generated replacements. Videos are included to make this directory independently reproducible. Do not revert to the missing legacy `promo_*.mp4` references.

Google Fonts supplies Nunito (display), DM Sans (body) and Zen Maru Gothic (Japanese fallback). System sans-serif is used when fonts cannot load.

## Browser verification

Check both languages, desktop/intermediate/mobile layouts, collection disclosure and filters, modal open/close and Escape focus return, video playback/pausing, and horizontal overflow. Reduced-motion users see the poster until choosing playback. Without JavaScript, the inline trailer has native controls and the native disclosure makes the full collection accessible.

## Deployment

Published on 2026-09-27 after the user's explicit deployment request.

- Project: `eiyutos-projects/paw-time-launch`.
- Public English page: https://paw-time-launch.vercel.app/.
- Public Japanese page: https://paw-time-launch.vercel.app/ja/.
- Deployed source: `0dfb476` (LP implementation: `e6ab97f`).
- Deployment: `dpl_D6e5JjKBT5TaaQXTxfnjX9Rdu4dL`.

Deploy from this directory, whose Vercel project root is `.`. Confirm the linked project before deploying. Use `vercel deploy --prod --skip-domain`, wait for `READY`, verify the deployment with `vercel curl`, and then promote that same deployment. `.vercelignore` excludes development notes, the verifier, environment files and Godot import metadata.

The production HTML for all three routes, CSS and JavaScript matched local source byte for byte. Both videos returned HTTP 200 with the expected type and size. Desktop presentation, English video playback and Escape/focus return were checked in the public browser. The additional production mobile/language-click check was interrupted by browser automation timeouts; the responsive and bilingual local checks above remain the available UI evidence.
