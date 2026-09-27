# はじめての人へ（Paw Time）

新しく入った人が、ここだけ読めば触り始められるようにまとめたページです。最終更新 2026-09-27。

## 1. まず触る（10分）

| 何を | どこで | ポイント |
|---|---|---|
| ゲーム本体 | https://paw-time-play.vercel.app | スマホで開くのがおすすめ。英語版はサンフランシスコとドル、右上の「日本語」で日本とyen |
| 3分デモ | タイトル画面の「3-minute demo」 | 審査員向けの通しの流れ。最後はリクルート向け画面へつながる |
| 見本の切り替え | https://paw-time-play.vercel.app/?demo=1 | 勤務中・勤務後などの状態をボタンで切り替えられる |
| リクルート向け画面 | https://paw-time-insights.vercel.app | 行動データのデータベース型ビュー（数字は合成データ） |
| お店向け管理画面 | https://paw-time-employer.vercel.app | 求人・応募者・シフト・チャット・レビューと島（見本データ） |
| 紹介ページ | https://paw-time-launch.vercel.app（[日本語](https://paw-time-launch.vercel.app/ja/)） | プロダクトの1枚紹介 |
| API | https://paw-time-api.vercel.app/health | 動いているかの確認 |

## 2. 何を作っているか（1分）

- 対象は短期・スキマバイトで働く人。おばねこ（猫のおばけ）が求人を届け、シフト中は一緒に働き、働きすぎると疲れて「一緒に帰ろ」と止める。
- 夜はポイで光る玉をすくい、朝に孵化する。中身は材料・服・たまにレアのおばねこ。島を育てて友達やお店の島へ行ける。
- 売りは行動データ。応募の前（興味）、勤務中（働けるか）、勤務後（合っていたか、また来るか）を、求人アプリが見えない形で見られる。
- 守ること: 長く働いても得をしない。賃金には触らない。課金は見た目の買い切りだけ。お店に個人の点数を渡さない（5人以上の集計だけ）。チャットの文は端末から出さない。

ピッチ原稿は [docs/pitch.md](pitch.md)、数字の出典は [docs/pitch-evidence.md](pitch-evidence.md)、ゲームの仕様は [apps/worker/README.md](../apps/worker/README.md)。

## 3. リポジトリの地図

| パス | 中身 | 技術 |
|---|---|---|
| `apps/worker` | ゲーム本体 | Godot 4.7.2（GL Compatibility / WebGL2）、GDScript |
| `apps/api` | 共通API | Hono + zod（Vercel） |
| `apps/employer` | お店向け管理画面 | Next.js 15 |
| `apps/insights` | リクルート向け画面 | TypeScript + Chart.js |
| `apps/marketing` | 紹介ページ | 静的HTML |
| `packages/` | API契約・お店コンソールのルールなど | TypeScript |

## 4. 手元で動かす

```sh
# ゲーム（Godot 4.7.2 が必要）
godot --path apps/worker

# ゲームのテスト（例）
OBAKE_NOSAVE=1 godot --headless --path apps/worker -s tests/test_review3.gd
OBAKE_NOSAVE=1 godot --headless --path apps/worker tests/test_lang_sweep.tscn --quit-after 4000

# Web 書き出し（Godot の Web 書き出しテンプレートが必要）
godot --headless --path apps/worker --export-release "Web" build/web/index.html

# お店向け画面・API
pnpm install
pnpm dev            # employer: http://localhost:3000 / api: http://localhost:8787
pnpm test && pnpm typecheck
```

- 文言は `apps/worker/i18n/strings.csv`（英語・日本語）で管理し、コードでは `tr()` を通す。CSV を変えたら `godot --headless --path apps/worker --import` で翻訳ファイルを作り直す。
- 日本語と英語が混ざっていないかは `tests/test_lang_sweep.tscn` が見張っている。

## 5. 作業のルール

- `main` へ直接 push しない。force push しない。ブランチ → PR → テストを通してからマージ。
- ブランチ名は `<名前>/<作業>`（例 `yuto/hud-polish`）。
- APIキー・トークン・`.env`・個人情報はコミットしない。
- 公開サイトは Vercel（eiyutos-projects）。ゲームは main から書き出したものを出し、本番の `index.pck` のハッシュがローカルと同じか確かめる。デプロイは青木に声をかける。
- このリポジトリは **公開（public）**。誰でも読めるので、秘密・個人情報・未公開の資料は絶対に入れない。書き込み権限の追加は GitHub のオーナー（大山）から。

## 6. 困ったら

- 仕様や決まったことの経緯: [apps/worker/README.md](../apps/worker/README.md)、[docs/architecture/monorepo.md](architecture/monorepo.md)
- 分からないことはチームの Slack で聞く。
