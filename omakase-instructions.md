# Omakase Instructions: Paw Time judge-facing launch page

> 2026-09-26. Scope authorized by `$omakase` after review of https://paw-time-launch.vercel.app/.
> Follow Phase 0 read-back before implementation. This is a local implementation and review, not a publication task.

## Premises

| # | Premise | Verification | If false |
|---|---|---|---|
| P1 | Work in `/Users/eiyuto/dev/paw-time-lp`, branch `yuto/launch-judges`, based on `c9ff6ac`. Initially clean. Other worktrees are occupied by game integration and Insights work. | `git status --short --branch`; `git rev-parse --short HEAD`; `git worktree list` | Protect other work and stop dependent edits. |
| P2 | `apps/marketing` is the monorepo's static public site. Its checked-in three-prototype content predates the live one-game LP. | README application table; `apps/marketing/index.html:119-193`; live HTML at the supplied URL | Do not replace unrelated application code. |
| P3 | Node v24.17.0 can check scripts. Current EN/JA inline JS parses; local assets are missing three old promo videos per locale. There is no marketing build/test task. | Baseline below | Record unrelated differences; do not hide regressions. |
| P4 | The game has a three-minute demo on its title screen, but no verified locale/direct-three-minute-demo URL. `?demo=1` is a scene switcher, not that route. | `apps/worker/scripts/screen_title.gd:153`; `scripts/demo_switch.gd:4-23`; `scripts/main.gd:54-100` | Keep the existing game URL and explain its actual entrance. Do not invent URL behavior. |
| P5 | Live EN and JA trailers/screenshots exist outside the checked-in marketing files. Public asset source is the supplied LP only. Game impact, customer traction and payment readiness are not verified. | Live EN/JA HTML and media GET; compare source metadata; README status | Keep outcomes as hypotheses and business model as proposed. Never invent results. |

## Out-of-scope

- Game logic, rewards, sleep rules, saved games, onboarding and locale implementation in `apps/worker`.
- API, authentication, billing, database, telemetry or privacy-policy changes; other apps and shared packages.
- Deploying, publishing, pushing, PR creation, merging, external messages or production writes.
- Changing business policy, inventing customer quotes/metrics, claiming recruiting accuracy or health improvement.
- Existing `refactor-instructions.md`, other worktrees, original research repository, member directories.

## Objective

Before hackathon judging, let a first-time English-speaking reviewer understand who Paw Time serves, see the actual game, and distinguish the prototype from its proposed business and unvalidated impact.
Use the existing characters, night-world palette and actual footage with a more focused hierarchy. Visual choices serve comprehension and product character; general cleanup and unrelated redesign are not goals.

## Project Understanding

- What: static EN landing page with JA equivalent and `/en/` redirect; links to a separately deployed Godot browser game.
- Entry points: `apps/marketing/index.html`, `ja/index.html`, `en/index.html`.
- Modules: inline CSS and inline 30-character filter script today; public imagery in `img/`; videos referenced but absent locally.
- Data flow: page content and character cards are static; no submission or user data handling is required.
- External dependencies: Google Fonts, browser-game URL, GitHub source, existing public video assets. No new service.

## Behaviors To Preserve

- EN root, working JA switch and `/en/` redirect. Verify via HTTP and browser.
- Recognizable Paw Time characters, existing 30-character collection and group filtering.
- Actual game link `https://paw-time-play.vercel.app/`; sample-job disclosure, real screenshots, existing EN/JA 44-second trailer.
- Honest distinction between game rewards and wages; all prototype outcomes remain unvalidated.
- Basic content/navigation works without JS; new interactive controls remain keyboard accessible.

## Non-Negotiables

- No source edits before read-back. Only this instructions file is written during A–B.
- Edit only `apps/marketing` plus this document. No pre-existing local changes to protect in this isolated worktree.
- Preserve accepted assets; import missing media only from the user-supplied public LP. Do not generate replacement character art.
- No unsupported claims about English startup, direct demo entry, health/retention results, real job offers or paying customers.
- Do not edit PROPOSE items. No main push, force push, merge, deployment or external communication.
- Share CSS and behavior across locales; avoid framework/dependency changes.

## Stop And Ask Conditions

- Actual concurrent changes conflict with the chosen files and cannot be safely separated.
- A necessary change would affect game save data, authentication, billing, APIs, DB or business policy.
- A required asset cannot be recovered from the authorized public LP and no honest existing fallback exists.
- Baseline-passing behavior breaks and its cause remains unknown after focused investigation.
- If a proposed rule change is desired (low-sleep character or overtime penalty), obtain an explicit separate decision.

## Baseline Commands

Executed in this worktree before implementation:

| Command / audit | Observed result |
|---|---|
| `git status --short --branch` | clean `yuto/launch-judges...upstream/main` |
| `git diff --check` | pass, exit 0 |
| `node --version` | v24.17.0 |
| Python extraction of inline scripts, piped into `node --check -` | EN and JA pass, exit 0 each |
| Python audit of HTML IDs and local src/poster references | 0 duplicate IDs; missing `video/promo_a.mp4`, `promo_b.mp4`, `promo_c.mp4` in EN and JA |
| Public EN/JA HTTP reads | 200; EN 24,234 bytes, JA 26,241 bytes; current trailers/screenshots identified |
| `lsof -nP -iTCP:4179 -sTCP:LISTEN` | no listener (exit 1), port available |

The missing legacy videos are pre-existing. Phase 1 must supply a reproducible static verifier and restore the currently published media used by the revised page. No monorepo API/game checks are relevant to this static-only patch.

## Course

- Event/audience: Recruit Holdings Innovation Cup judging; international product/business/engineering reviewers.
- Four lenses: (1) live EN LP and game entrance reviewed, JA and legacy `/en/` checked; (2) predicted questions are who benefits, why a game, where proof and working demo are; (3) no user-named benchmark, not applicable; (4) live page has sample jobs, 30-character list, actual footage and a locale-dependent game title; no evidence of real impact supplied.

| Rank | Request | Confidence × cost | Why a judge asks | Disposition |
|---|---|---|---|---|
| 1 | Explain user/problem/value immediately | high × small change | Hero leads with unfamiliar nets/orbs | GO D1 |
| 2 | Show one cohesive game and a short path to footage | high × small change | Checked-in site still advertises three prototypes; live LP has lengthy repeated feature sections | GO D1/D2 |
| 3 | Make the local LP/media reproducible | high × small change | Current repo would regress the public LP and has missing videos | GO D0 |
| 4 | Separate demo, proposal and evidence | high × small change | Employers paying and broad benefit claims are presented as facts without validation | GO D3 |
| 5 | Keep the collection without making it the main pitch | high × small change | 30 cards precede business and architecture information | GO D2 |
| 6 | Change incentives / force English game startup | medium × game implementation | Reward design and game locale are outside the LP | PROPOSE |

- Quick wins: audience-first copy; prominent video and game links; clearer sample/validation labels; compact expandable collection; English/source navigation.
- Proposal for later discussion: test whether people return between shifts, and whether time-pressure users find the rest mechanic supportive. Show participant count and observed results, not synthetic success metrics.
- False positives: Japanese startup was observed in one browser with saved progress; universal default behavior was not established. Longer work does increase some coins before the cap, so only the cap/fixed-net claims can be made precisely. No proof of impact or paid adoption is available.

## Debt Map

### D0: Stale source and absent media — GO
- Evidence: `apps/marketing/index.html:165-193`, `README.md:1`, missing-asset baseline; live LP differs.
- Impact/risk: marketing only, low. Bring actual live screenshots/trailers into this module and document static serving.
- Verification: all local assets resolve; EN/JA video metadata/playback; source and license/provenance recorded in README.

### D1: Value and reviewer navigation are obscured — GO
- Evidence: `apps/marketing/index.html:119-127`, `:155-160`, `:234-237`.
- Impact/risk: static content/layout, low. Introduce a value-led hero, clear audience/problem, source link and three-scene game explanation.
- Verification: 1440/1024/390/360 layouts, all navigation targets, honest English copy and JA parity.

### D2: Long feature/catalog flow and weak media access — GO
- Evidence: `apps/marketing/index.html:165-205`, `:242-263`; live LP's trailer begins far below hero.
- Impact/risk: marketing interactions, low. Put trailer in accessible modal with inline fallback; three featured characters and expandable full collection; keep group filters.
- Verification: video opens/closes/pauses; Escape and focus return; keyboard filters; no-JS content fallback; reduced-motion behavior; no horizontal overflow.

### D3: Claims lack prototype/status boundaries — GO
- Evidence: `apps/marketing/index.html:158-159`, `:214-229`, `:237`; `README.md` in-memory API note; `apps/worker/scripts/screen_title.gd:153`.
- Impact/risk: copy only, low. Explain fixed nets/capped coins precisely, not wages; label business as proposed and impact as untested. Link actual architecture/source. Do not imply purchases or jobs are live.
- Verification: trace claims to source/current public demo; no fabricated metrics, privacy guarantees or unsupported demo links.

### P1: Incentive changes and direct English game route — PROPOSE
- Low-sleep unlocks, overtime penalties and saved-language behavior require game/product decisions. Do not alter them as part of LP work.

## Implementation Phases

### Phase 0: Read-back
Recheck P1–P5 and baseline. Announce scope and touched files: this document; marketing EN/JA HTML; shared `site.css`/`site.js`; `verify.mjs`; README; published screenshots/posters/trailers. No changes elsewhere.

### Phase 1: Reproducible assets and verification
D0: recover media needed by the revised LP; implement dependency-free static validation; retain provenance. No legacy media referenced in the final page.

### Phase 2: Content, visual hierarchy and interactions
D1–D3: build EN and JA pages with shared styles/behavior; retain `/en/` redirect; three clear scenes, actual trailer, expandable collection, grounded technical/status section and source link.
Design: midnight #141a3a, slate #283862, moon #f5edb6, sky #bcdde8, tangerine #fa9870, cool paper #f7f8f5. Rounded display type plus readable body. One memorable hero scene built with existing game footage/characters; quiet surrounding layout, no repeated decorative card grid.

### Phase 3: Verify and self-review
Run static verifier and diff check. Serve locally on port 4179. Inspect desktop, intermediate and mobile screenshots; test language links, collection and filters, video/focus, no-JS basics. Reset viewport overrides. Record actual outcomes in this document and README where useful. Commit only local scoped changes if all checks pass.

### Final Phase: Proposals only
Report P1 and proposed user validation. Do not implement product-rule changes or publish the result.

## Verification Requirements

- `node apps/marketing/verify.mjs`: syntax, IDs, relative links/media, internal anchors, media presence and locale routes.
- `git diff --check` and final changed-file scope audit.
- Local HTTP EN, JA, `/en/`, CSS, JS and media all return successfully.
- Browser: no overflow at 1440, 1024, 390, 360; all 30 characters available; group filters work; modal media plays and pauses on close; keyboard close/focus return; EN/JA links; no runtime errors.
- Restore browser viewport; keep the local preview available for user review. No public deployment.

## Reporting Format

Report completed phases, changed files/commit, read-back result, exact verification results, local preview and instructions links. Include remaining PROPOSE items and false-positive correction. Record detail here so the chat handoff stays concise. Explain the no-deploy boundary using the invoked skill's instruction.

### Completion record — 2026-09-27

**Phase 0 read-back:** P1 matches (isolated `yuto/launch-judges` at `c9ff6ac`; only this new instruction was untracked). P2 matches (marketing is a static module, with source older than the public LP). P3 matches (Node v24.17.0; both inline scripts parse; the same three legacy videos are missing). P4 matches (title-screen demo and language controls exist; no supported direct English three-minute route was found). P5 matches (both published trailers and required screenshots recovered successfully; no outcome/traction evidence supplied). There was no baseline discrepancy. Objective: make the product and evidence understandable to a first-time international judge. Out-of-scope: game rules, saves, platform services, business-policy decisions and publication. Touched-file plan was marketing HTML, shared CSS/JS, verifier, README, public media and this document; no unrelated files changed. No unresolved scope interpretation required approval.

**Implementation:** D0–D3 completed. EN and JA share styling and interactions. The page now explains its audience, shows three stages of the game, offers the actual trailer in a native dialog, provides prototype/business/validation status and links to the public source. The 30-character collection is preserved behind a native disclosure. Missing live media is included locally. Daily coin limits are described precisely without implying limits on wages. At narrow widths, the status table uses vertically arranged rows.

**Final commands/results:**

```text
node apps/marketing/verify.mjs
CHECK index.html: anchors, assets, language, accessibility references, 30 companions
CHECK ja/index.html: anchors, assets, language, accessibility references, 30 companions
CHECK en/index.html: English alias
PASS: 3 routes, script syntax, 42 local files, both trailers and reduced-motion styles

git diff --check
(no output; exit 0)
```

**Browser evidence:** English layouts inspected at 1440, 1024, 390 and 360 pixels; Japanese at 1440, 390 and 360. Document scroll width equaled viewport width at each checked size. Both trailers played with readyState 4; English duration was 44.266667 seconds. Opening the modal paused the hero. Escape closed it, paused the trailer, removed the body scroll lock and restored focus to the triggering link. Japanese video also opened and closed correctly. Collection expansion showed 30 cards, Sleep showed 6, All restored 30. English/Japanese links and `/en/` → `/` redirect worked. No browser error/warning logs were recorded. Image aspect ratios were corrected during visual review. Temporary viewport overrides were reset; final English preview is at the normal 1512-pixel viewport.

**Verification limits:** No-JS fallback and reduced-motion behavior were checked in static HTML/CSS/JS, not by changing browser/OS settings. The game itself was not rebuilt or exhaustively tested, because this patch only changes the LP. Public game language and the direct three-minute route remain outside scope.

**Proposal / false positives:** Low-sleep rewards and overtime penalties remain game-design proposals. Japanese game startup in the first audit was one observed environment, not proof of a universal default. No improved sleep, hiring accuracy, reduced overtime or real customer traction was fabricated. A worker pilot remains the next proposed source of evidence.

**Handoff:** Local preview at http://127.0.0.1:4179/ (JA: `/ja/`). The serving process is intentionally left running for review. Worktree `/Users/eiyuto/dev/paw-time-lp`, branch `yuto/launch-judges`. No push, PR, merge, deployment, external message or production write was performed, following omakase's prohibition on publication/deployment.

### Authorized deployment follow-up — 2026-09-27

The user subsequently requested “一応Vercelデプロイ”, authorizing deployment of the completed LP. This supersedes the original no-publication boundary for this follow-up only.

- Verified existing project `eiyutos-projects/paw-time-launch`, ID `prj_hahqsqEpuziQa0FnCLVqodxekHwM`, with root directory `.` and framework Other. The production EN/JA hashes still matched the original audit. Three new upstream commits affected Insights, with no marketing changes.
- Linked only `apps/marketing`. Removed the transient `.env.local` token file generated by the CLI without reading its value. Kept `.env*` ignored and added `.vercelignore` for development-only files and Godot import metadata. Dry run selected 53 static files and excluded environment files.
- Static verifier and diff checks passed. Deployed source commit `0dfb476` includes the LP implementation `e6ab97f` and deployment-file exclusions.
- Created production deployment with `--skip-domain`, observed `readyState: READY`, compared protected-deployment HTML/CSS/JS and an image byte for byte with local source, and checked both MP4 headers. Promoted the same deployment after those checks.
- Live deployment: `dpl_D6e5JjKBT5TaaQXTxfnjX9Rdu4dL`, https://paw-time-launch-qdgo4tqmj-eiyutos-projects.vercel.app/.
- Public routes: https://paw-time-launch.vercel.app/ and https://paw-time-launch.vercel.app/ja/. Inspecting the public domain resolved to the new READY deployment. All three HTML routes, CSS and JS returned public HTTP 200 and matched local files; both MP4s returned 200 with the expected MIME type and size. README, verifier and a sample Godot import file returned 404 as intended.
- Browser evidence: public English desktop screenshot at 1512px, document width 1512px; actual English video reached 0:44/0:44; Escape closed the modal and focus returned to its trigger. The later Japanese-navigation/mobile-check call timed out, and subsequent tab/state recovery also timed out. Production mobile/language-click checks and temporary viewport reset could not be confirmed. Local bilingual/responsive verification remains recorded above; do not claim the production checks passed.
- Previous production deployment retained: `dpl_8MqijZJvGmtdrwhY7VRjD3ECV5Qs`, https://paw-time-launch-7slt294ly-eiyutos-projects.vercel.app/.
- No Git push/merge, game/API deployment, external message, or database change was performed.
