Paw Time のランディングページ（静的 HTML。ビルドなし）。このフォルダが正本。

- `index.html`（英語・サンフランシスコ／ドル）、`ja/index.html`（日本語・円）、`en/`（ルートへの転送）
- `img/shot_*_{en,ja}.webp`：apps/worker を Godot で撮った画面（`OBAKE_START` / `OBAKE_SHOT`、720x1280 → 450x800）
- `video/title_{en,ja}.mp4`：タイトル画面 6 秒（`godot --write-movie`、540x960 H.264）。`video/special_*.mp4`：特別なおばネコの孵化動画（720 幅 H.264）
- `img/rares/`：apps/worker/assets/gen/rares3d から切り出し（256px webp）

デプロイ: このフォルダを Vercel プロジェクト paw-time-launch にリンクしたコピーから `vercel deploy --prod --yes --scope eiyutos-projects`（.vercel はコミットしない）
