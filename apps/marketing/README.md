Paw Time のランディングページ（静的 HTML。ビルドなし）。このフォルダが正本。

- `index.html`（英語・サンフランシスコ／ドル）、`ja/index.html`（日本語・円）、`en/`（ルートへの転送）
- `img/play_*_{en,ja}.webp`：apps/worker を Godot で撮った画面（`OBAKE_START` などの確認用フックとデモの切りかえ、720x1280 → 450x800）。英語は SF・ドル、日本語は日本・円
- `img/og_logo.jpg`・`img/poster_title3d_{en,ja}.jpg`：タイトル（3D ロゴ）の画面から
- `video/title3d_{en,ja}.mp4`：タイトル画面 6 秒（`godot --write-movie`、540x960 H.264）。`video/special_*.mp4`：特別なおばネコの孵化動画（720 幅 H.264）
- `img/rares/`：apps/worker/assets/gen/rares3d から切り出し（256px webp）

デプロイ: このフォルダを Vercel プロジェクト paw-time-launch にリンクしたコピーから `vercel deploy --prod --yes --scope eiyutos-projects`（.vercel はコミットしない）
