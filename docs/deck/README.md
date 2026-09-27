# ピッチのスライド（ソース）

- 公開版（正本の表示先）: https://claude.ai/artifact/5Z1bK7jBSxp43aS6KSGkGz（Claude の Slides Artifact）
- 大会テンプレ（hackathon template simple ver.）の8章 + 3者の得 + 付録。1920×1080、スライドごとに `slides/<id>.html` の `<section>` 1つ。順番は `deck.json` の `order`。
- スピーカーノート（`<aside>`）は物語仕立ての原稿（英語で話す文 + 日本語の意味）。同じ内容を `docs/pitch.md` に置いている。
- 画像・GIF は Artifact のアセット（`/_blob/<id>`）。どのファイルかは `assets.json`（id → 元のファイル名）。GIF の元は `apps/worker` のプレイ録画。
- `tools/`: スライドを組み立てる Python（`gen3.py`、`notes.py`）と、手元で1枚ずつ PNG に描いてはみ出しを数える `render.mjs`（Playwright）。スクリプト内のパスは作業時のもの。

更新するときは Artifact 側を正本として編集し、変えたスライドをここにもコピーしてコミットする。
