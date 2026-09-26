# Night brief — おばけの休憩室（3 variants, deadline 07:00 PDT）

You are one of three agents building the same game in parallel, each with a slightly different system design (your variant is described at the end). The owner (青木悠登, "カシラ") is asleep. At 07:00 PDT he will play all three builds, audit strengths/weaknesses, and merge the best parts. Work autonomously until the deadline. Never stop early because "it works" — keep raising the quality bar.

## The quality bar (the whole point)
The game must be worth playing ON ITS OWN — not an "AI-made demo". Someone should want to open it daily for fun, and then feel "I want to work my shift / sleep well because it boosts my game". Real-life work and sleep are BOOST ITEMS, not requirements: the game must be fun and progressable without them, and noticeably better with them.

Concretely the build must have:
- A clear core loop you want to repeat, meaningful choices with visible consequences, short-term goals (today) and long-term goals (collection, upgrades, story/weekly events).
- Juice: responsive input, tweens, particles, screen shake where earned, sound on every meaningful action, satisfying reward moments.
- First-run onboarding that teaches by doing (no walls of text), no dead ends, no placeholder text, consistent UI, readable Japanese.
- Save/load (user://), multi-week play (not only the 1 sample week): simulate/generate days so the game continues; a "demo fast-forward" is fine for the audit.
- Balance pass: play it yourself via scripts, tune numbers, write down the reasoning.

## What exists (read the code first)
Godot 4.7.2, renderer GL Compatibility (must stay web-exportable), portrait 360x640 base.
- scripts/game_state.gd (autoload GameState): week data WEEK (sample), nets=poi counts, sleep(), orbs → hatch, rares via Rares.check, info(id), ALL.
- scripts/rares.gd: 30 rare obake with conditions (sleep / firsts / time band / weather / connections / rhythm), max 2 per night, hint text shown before discovery.
- scripts/screen_scoop.gd: おばけすくい (night riverside, glowing orbs, tearing poi, slow-mo lift, sfx). scripts/screen_hatch.gd: morning orb hatching. scripts/screen_sleep.gd, screen_room.gd (3D breakroom hub), screen_zukan.gd (collection), screen_catch3d.gd (old GO-like throw — do NOT use, owner said it is too Pokémon GO), screen_battle.gd (old pixel 2D — outdated look, redo or remove).
- scripts/obake3d.gd: normal obake = toon 3D with black outline (owner LIKES these; keep this look). `Obake3D.make(id)` returns RareObake3D for rares.
- scripts/rare_obake3d.gd: rares are flat 2D art standing in 3D like paper puppets.
- assets/gen/rares/*.png: rare art in "にゃんこ大戦争 (The Battle Cats)" deadpan absurd style — white bodies, thick black ink line, tiny dot eyes, line mouth, 1–2 flat accents. Codex is still drawing the rest into /Users/eiyuto/dev/obake-godot/assets/gen/rares/ (the master checkout). Copy new files from there into your worktree whenever you need them (they are all named <rare id>.png).
- tools/gen_sfx.py (synthesised sfx), tools/gen_art.py (old pixel art, obsolete).

## Art & tone rules (owner's decisions — do not violate)
- Normal obake: the current 3D toon look with outline. Rares: Battle Cats deadpan absurd flat art. NEVER glossy, sparkly, big-eyed, "AI-cute", fawning. Humour from silhouettes and deadpan, not from begging cuteness.
- The catch mechanic must NOT resemble Pokémon GO throwing. おばけすくい (goldfish-scooping) is the owner's choice.
- UI: rounded Zen Maru Gothic fonts (assets/fonts), clean modern pills/cards; no pixel UI.
- Never make "working more hours" the best strategy. Rewards come from variety, rest, rhythm, connections. Sleep must matter.

## How to verify (do this constantly)
- After adding a class_name script: `godot --headless --path . --import` (refreshes the class cache).
- Parse check: `godot --headless --path . --quit-after 60 2>&1 | grep -E "SCRIPT ERROR|Parse Error|SHADER ERROR"` must be empty.
- Screenshots: main.gd supports env vars. `OBAKE_START=<screen>` starts on a screen (`hatch` seeds orbs, `OBAKE_RARE=<id>` forces a rare hatch). `OBAKE_SHOT="step,step,..."` where a step is a screen name, `waitN`, or `call:<method on current screen>`; `OBAKE_SHOT_PATH=/abs/path.png`. Run windowed: `godot --path . --resolution 360x640 --quit-after 30000`. Look at every screenshot you take (Read the PNG) and fix what looks wrong. Slow-mo (Engine.time_scale) slows timers, so give generous --quit-after.
- Headless logic sims like tests/sim_week.gd: `godot --headless --path . -s tests/<file>.gd`. Write your own sims for balance.

## Codex (use it)
Codex CLI 0.156.1 is installed and can generate images and review code. ALWAYS close stdin or it hangs:
- Review/opinion: `codex exec --sandbox read-only -C <your worktree> "<question>" < /dev/null > /tmp/<name>.log 2>&1`
- Images/edits: `codex exec --sandbox workspace-write -C <your worktree> "<task>" < /dev/null > /tmp/<name>.log 2>&1`
Run long Codex jobs in the background and keep working. Ask Codex for a design critique of your loop at least twice during the night (early and around 04:30) and act on the good points. For any new art, give Codex the style rules above explicitly.

## Git
Work ONLY inside your own worktree directory and branch. Commit often with clear Japanese messages (end each message with:
Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>). Never touch master, the other worktrees, or merge anything. Never force-push (there is no remote).

## Timeline (PDT)
- Now → 06:10: build, play, tune, polish. Commit at least every 45 minutes.
- 06:10 feature freeze. 06:10 → 06:45: make a 30–45 s portrait promo video (see below).
- By 06:50: write REPORT.md at your worktree root: what the variant is, how to play (commands), what is fun, what is weak, known bugs, balance notes, what the owner should steal for the merge. Commit.

## Promo video (広告動画)
Add an autopilot/demo mode (e.g. env OBAKE_DEMO=1) that plays the best moments automatically (scoop success in slow-mo, morning hatch of a rare, collection/zukan, your variant's signature moment). Record with Godot Movie Maker: `godot --path . --resolution 720x1280 --write-movie promo/raw.avi --fixed-fps 30 --quit-after <frames>` then use ffmpeg (/opt/homebrew/bin/ffmpeg) to make promo/promo.mp4 (H.264, 30 fps, 720x1280), with short Japanese title cards (drawtext with fontfile=assets/fonts/ZenMaruGothic-Black.ttf), a catchy hook in the first 2 seconds, and the tagline idea "働いた日は、ポイが増える。よく寝た朝は、玉がかえる。" (you may improve it). Add simple synthesized music/sfx if you can. Check the result by extracting a few frames with ffmpeg and looking at them.

## If you get stuck
Do not wait for humans. Pick the most reasonable option, note it in REPORT.md, continue.
