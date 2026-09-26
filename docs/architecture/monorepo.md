# モノレポ構成

Paw Timeは、ワーカーと採用企業の両方を利用者とする求人プラットフォームです。両者のUIとリリースは分離し、業務データと報酬判定は共通APIに集約します。

## 境界

```text
apps/worker   ─┐
               ├─ apps/api ─ PostgreSQL
apps/employer ─┘       │
                       └─ 業務イベントから双方のゲーム報酬を付与
```

### Worker

求人検索、応募、シフト確認、出退勤、企業レビューと、おばネコ・島の体験を担当します。現在のGodotプロジェクトを保持します。

### Employer

組織・店舗、求人、応募者選考、シフト、勤怠訂正、評価と、企業の家の体験を担当します。業務画面に適したWebアプリとして提供します。

### API

以下のモジュールを持つモジュラーモノリスとして開始します。

- Identity: ワーカー、企業メンバー、認証主体
- Organizations: 企業、店舗、権限
- Recruitment: 求人の作成、公開、終了
- Applications: 応募、採用、不採用、辞退
- Shifts: 確定シフト
- Attendance: 出勤、退勤、訂正履歴
- Evaluations: ワーカーと企業の相互評価
- Gamification: 報酬台帳、所持品、島と家
- Audit: 採用、勤怠、評価の変更履歴

当面は1つのAPIと1つのデータベースを利用します。各領域を別サービスに分割するのは、負荷や組織上の必要性が明確になってから行います。

## 正本

求人、応募、選考結果、シフト、勤怠、評価、報酬付与履歴はサーバーを正本とします。Godotの `user://` は表示用キャッシュやオフライン操作に限定します。

勤怠は現在値だけでなく追記型のイベントとして保存します。訂正時も元イベントを削除せず、訂正理由、変更者、変更日時を記録します。

## ゲーミフィケーション

ワーカーの島と企業の家は別の世界ですが、次の基盤を共有します。

- 安定したアイテムID
- レベルと経験値
- 所持品と配置
- 実績
- 二重付与を防止する報酬台帳
- 報酬を発生させた業務イベント

クライアントは演出を担当し、報酬付与条件の最終判定はAPIが担当します。カタログは `packages/game-catalog`、通信形式は `packages/api-contracts` で管理します。

## 採用から評価までの状態遷移

```text
job: draft → published → closed
application: applied → selected | rejected | withdrawn
shift: scheduled → checked_in → checked_out → completed
                         └──────→ no_show | disputed
evaluation: pending → submitted
```

「時間通りに来たか」は手入力の真偽値にせず、予定時刻と出勤イベントの時刻からサーバーが算出します。
