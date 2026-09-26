# Paw Time API

ワーカーアプリと採用企業アプリの共通APIです。求人、応募、採用判断、勤怠、評価とゲーム報酬を同じ業務トランザクションから扱います。

## 現在の実装

最初の垂直スライスを確認するため、保存先は `MemoryStore` です。開発用の企業コンテキストとして次のヘッダーを要求します。

```text
x-organization-id: org-komorebi
x-actor-id: member-demo
```

このヘッダーは認証ではありません。本番では認証トークンから組織と操作者を解決し、リクエストから渡された組織IDを信用しないでください。

## エンドポイント

- `GET /health`
- `GET /v1/worker/jobs`
- `POST /v1/worker/applications`
- `GET /v1/worker/shifts`
- `GET|POST /v1/business/jobs`
- `GET /v1/business/applications`
- `GET /v1/business/shifts`
- `POST /v1/business/applications/:id/decision`
- `POST /v1/business/shifts/:id/attendance`
- `GET /v1/business/shifts/:id/attendance-summary`
- `POST /v1/business/evaluations`
- `GET /v1/business/world`

通信仕様の正本は `packages/api-contracts`、永続化スキーマは `infra/database/migrations` です。
