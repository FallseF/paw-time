# Paw Time

**Worked a shift? More nets. Slept well? Your orbs hatch.**

A game for people who work. Your real shifts and sleep become boosts in a cozy cat-obake (cat-ghost) collecting game — and working longer hours never pays more. Built by Team Dry Grape for the Recruit Innovation Cup 2026.

- Launch page (EN / JA): https://obake-breakroom-launch.vercel.app
- Playable prototypes (browser):
  - A — Scoop & Collect: https://obake-breakroom-a-scoop.vercel.app
  - B — Sleep Rhythm (build & share your island): https://obake-breakroom-b-sleep.vercel.app
  - C — Run the Shop: https://obake-breakroom-c-defense.vercel.app

## Core loop
1. **Day — shift:** you get nets (poi) matching your kind of work. Same amount however long you work.
2. **Night — obake scooping:** gently scoop glowing glass orbs from a riverside pond.
3. **Sleep:** length and regularity decide how strong tomorrow's nets are and how well orbs hatch.
4. **Morning — hatch:** orbs crack open one by one and a cat-obake is born.
5. **Always — collection:** 5 common + 30 rare cat-obake. Rares come from how you live (a rainy shift, a full-moon night, a real rest after a busy stretch), never from sheer hours.

## Repository layout
| Branch | What it is |
|---|---|
| `main` (this) | Shared base: engine code, AAA character look, glass orbs, cat-obake, personality quiz, launch page (`apps/marketing/`) |
| `feature/variant-a` | Prototype A — scoop mastery & collection |
| `feature/variant-b` | Prototype B — sleep rhythm, island building & sharing |
| `feature/variant-c` | Prototype C — run the shop |
| `feature/aaa-look` | Character look: Blender-built body, character/eye/outline shaders, 3-point lighting |
| `feature/my-obake-quiz` | "My Obake-Cat" personality quiz (16 types, share card) |
| `feature/paw-cat`, `feature/rare-3d` | Cat-obake parts, 30 rares as 3D models |

Each variant branch has a `REPORT.md` (how to play, balance notes, strengths/weaknesses).

## Run
- Godot **4.7.2** (renderer: GL Compatibility; web-exportable).
- `godot --path .` to play. Useful env vars: `OBAKE_START=<screen>`, `OBAKE_SHOT=...`, `OBAKE_SHOT_PATH=...` (see `scripts/main.gd`).
- Web build: `godot --headless --path . --export-release "Web" build/web/index.html` (preset in `export_presets.cfg` on variant branches).
- Character body meshes: `tools/blender/build_cat_obake.py` (Blender 5.2, `--background --python`).

## Team
Keigo Oyama, Yuto Aoki, Risa Koyanagi — Team Dry Grape.
