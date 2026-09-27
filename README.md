# Paw Time

短期・スキマバイトで働くワーカーと採用企業をつなぎ、双方の体験にゲーミフィケーションを組み込むモノレポです。

**はじめての人は [docs/onboarding.md](docs/onboarding.md) から。** 公開中のURL、触り方、手元での動かし方、作業のルールを1ページにまとめています。

## アプリケーション

| パス | 対象 | 役割 |
|---|---|---|
| `apps/worker` | ワーカー | 求人、応募、シフト、レビュー、おばネコと島のゲーム体験（Godot） |
| `apps/employer` | 採用企業 | 求人掲載、応募者選考、勤怠、評価、企業の家（Next.js） |
| `apps/api` | 両方 | 求人・応募・シフト・勤怠・評価・報酬の共通API |
| `apps/marketing` | 一般公開 | プロダクト紹介ページ |
| `apps/insights` | 提携先・審査員 | 利用データの集計ダッシュボード（Recruit view）とプライバシー告知。詳細は `docs/architecture/insights.md` |

共通仕様は `packages/api-contracts`、ゲームコンテンツ定義は `packages/game-catalog`、データベース変更は `infra/database/migrations` で管理します。

## 開発

### ワーカーアプリ

```sh
godot --path apps/worker
```

Web書き出し:

```sh
godot --headless --path apps/worker --export-release "Web" build/web/index.html
```

### 採用企業アプリとAPI

```sh
pnpm install
pnpm dev
```

- 採用企業アプリ: `http://localhost:3000`
- API: `http://localhost:8787`

個別に起動する場合:

```sh
pnpm dev:employer
pnpm dev:api
```

現在のAPIは画面と契約を結合して確認するためのインメモリ実装です。再起動するとデータは初期化されます。本番保存用の初期スキーマは `infra/database/migrations` にあり、次の段階でPostgreSQLアダプターと認証を接続します。

## 設計上の境界

- UIはワーカー向けと採用企業向けで分離する。
- 求人、応募、採用、勤怠、評価、報酬イベントはAPIを正本とする。
- ゲーム報酬はクライアントの自己申告ではなく、APIが業務イベントから付与する。
- 企業データは必ず `organization_id` で分離する。
- 勤怠の修正と採用・評価の変更は監査ログへ残す。
- GodotとTypeScriptの実装コードを無理に共有せず、API契約と宣言的なゲーム定義を共有する。

詳しい構成は [アーキテクチャ](docs/architecture/monorepo.md)、既存ワーカーアプリの仕様は [ワーカーアプリREADME](apps/worker/README.md) を参照してください。3分ピッチの背景・課題に使う調査結果と出典は [ピッチ用の調査メモ](docs/pitch-evidence.md) にまとめています。
