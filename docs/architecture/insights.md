# Insights（利用データと Recruit view）

## 目的

1. プロダクト分析：ワーカーのゲームで何が使われ、何が使われていないかを知る。
2. 集計した利用状況を示す：求人アプリは仕事を探す時にしか開かれないのに対し、Paw Time は仕事のない日にも開かれることを、提携先や審査員に集計値で見せる。
3. パイロットで検証する指標と仮説を、先に形にしておく。

個人を評価したり、お店に個人のデータを渡したりする目的には使わない。

## 構成

```text
apps/worker (Godot)  ── Telemetry.track() ──▶ POST /v1/telemetry/events ─▶ TelemetryStore
                                                                             │
apps/insights（静的サイト） ◀── GET /v1/insights/{metrics,feed} ◀── 集計 ────┘
```

| 場所 | 役割 |
|---|---|
| `packages/api-contracts/src/telemetry.ts` | イベント種別・props の許可リスト（zod）、Insights レスポンスのスキーマ |
| `apps/api/src/modules/telemetry` | 受信・検証・レート制限・CORS・保存アダプター |
| `apps/api/src/modules/insights` | 集計（5未満の抑制）、Live now フィード、12週パイロットの合成データ |
| `apps/insights` | Recruit view ダッシュボード（`/`）とプライバシー告知（`/privacy`）。会話タグ（社内）と「お店に見えるもの」の節を含む |
| `apps/worker/scripts/platform/telemetry.gd` | ゲーム側のクライアント。組み込み先は同じ場所の `TELEMETRY_INTEGRATION.md` |
| `infra/database/migrations/0002_telemetry.sql` | Postgres に移すときの追記型テーブル |

保存先は `TelemetryStore` で差し替える。`BLOB_READ_WRITE_TOKEN` があれば Vercel Blob（private）、なければメモリ。`PostgresTelemetryStore` は任意のドライバーの `query(text, params)` を受け取るので、Neon・Supabase・pg のどれでも `setTelemetryStore()` で差し込める（実DBでの動作確認はまだ）。

## データ最小化

- 識別子は端末で作るランダムな `install_id`（UUID v4）だけ。アカウント・ワーカーIDとは結び付けない。
- props は enum・小さな整数・真偽値だけ。サーバーは未知のイベント種別・未知の props・範囲外の値・自由記述を拒否する。
- 場所はゲーム内の見本の店ID（`JobListings.LIST`）まで。実在の住所や端末の位置は扱わない。
- 1バッチ最大50件・16KB。install_id ごとに毎分12バッチ、IP ごとに毎分120リクエストまで（インスタンス単位のベストエフォート）。
- IP アドレスはレート制限に一時的に使うだけで、イベントと一緒には保存しない。
- ゲームの設定でオフにできる（`Telemetry.set_enabled(false)`）。`OBAKE_NOSAVE` / `OBAKE_NOTELEMETRY` の環境では何も送らない。
- 本人の依頼で install_id 単位に削除できる（`DELETE /v1/telemetry/events`、ゲーム内の「利用データを削除」）。

### 集めないもの

氏名、連絡先、アカウントID、写真、入力した文章、位置情報、睡眠時刻、健康情報、端末ID、広告ID。

## 会話データ（Chat data）

ワーカーが猫おばけと交わす会話は、社内（マッチングとプロダクト改善）で使い、その一部だけを集計値としてお店に提供する。このデモでは、会話の文章そのものは端末から出さない。

### 取り出すもの

- ゲームが端末上で、会話を決まったタグに変換する。サーバーに届くのはタグだけ（`packages/api-contracts/src/telemetry.ts` の `TELEMETRY_CHAT_TOPICS`）。
  - 困りごと：`break_hard` `yelled_at` `pay_late` `unclear_instructions` `too_busy`
  - 本人の気持ち：`nervous_new_role`
  - よかったこと：`liked_team` `liked_customers`
  - 働き方の希望：`want_more_hours` `want_fewer_hours` `prefer_backstage` `prefer_customer_facing`
- イベントは5種類。どれも enum だけで、自由記述の props は持てない（未知の props は拒否）。

| イベント | props | 用途 |
|---|---|---|
| `chat_open` | `kind: me\|shop` | 自分の猫／お店の猫との会話を開いた |
| `chat_signal` | `topic`、`private_mode: false`（必須）、`shop_id`（任意） | 社内のみ |
| `anon_issue_sent` | `tag`（困りごとの5種のみ）、`shop_id`（必須） | 本人が「お店に匿名で伝える」に同意した時だけ送る |
| `faq_auto_answered` | `topic: dress\|entrance\|break` | お店の猫が勤務前の質問に自動で答えた |
| `shop_message_sent` | `kind: late\|swap\|thanks\|question` | お店への定型メッセージ |

### 同意と「ないしょモード」

- 最初の会話の前に、何を取り出し、何に使い、お店に何が届くかを示して同意をとる（ゲーム側の実装は未着手）。
- 「ないしょモード」（英語 UI では Just between us）の会話は、`chat_open` も含めて何も送らない。サーバーは `private_mode: true` の `chat_signal` と、`private_mode` を明示しない `chat_signal` を拒否する。
- 通常の利用データと同じく、設定でオフにでき、install_id 単位で削除できる。

### 社内での使い方

- Recruit view の「What workers tell their cat」カード：話題の分布（5人未満の話題は非表示）、働き方の希望を話した人の受諾率と全体の比較（仮説として表示）、お店の猫の自動回答と定型メッセージの件数。
- 用途はマッチング（希望に合う仕事を先に出す）とプロダクト改善に限る。個人の評価には使わない。
- Live now フィードでは、`chat_signal` と `anon_issue_sent` は「起きた」ことだけを示し、話題・タグ・店舗は出さない。

### お店に提供するもの

Recruit view の「What a shop would see」節が、採用企業に渡す内容の見本になっている。

- 本人が同意して送った `anon_issue_sent` を、店舗×タグで数える。別々のワーカーが5人以上になったタグだけを出す。同じ人が何度送っても1人と数える。
- よかったこと（`liked_team` / `liked_customers`）を、同じく5人以上の時だけ出す。
- 期間全体の合計だけで、日時は週単位の期間ラベルまで。5人未満のタグは `null` ではなく項目ごと出さない（1〜2人が声を上げたこと自体を悟らせないため）。

### やらないこと

- 会話の文章をお店に渡すこと。このデモでは会話の文章を端末から送ること自体をしない。
- 誰が言ったか、正確にいつ言ったかをお店に渡すこと。働き方の希望や5人未満の話題をお店に渡すこと。
- 要配慮個人情報にあたる話題（健康・病歴、信条、犯罪歴など）をタグにすること。こうした情報を取得するには、個人情報保護法20条2項により本人の事前の同意が必要になるため、タグの一覧から外している。タグを追加する時は、この観点で見直す。

## 集計のしきい値

- ダッシュボードとレスポンスは集計値だけ。セルの裏付けが5インストール未満なら `null` にして「—」と表示する（`INSIGHTS_K_MIN = 5`）。
- 店舗別の「勤務のあと」シグナルは、その店で勤務を終えたワーカーが5人未満の店舗を行ごと非表示にする。
- Live now フィードは直近30分の匿名イベント（種別・許可した props・相対時刻）だけを返し、install_id は返さない。審査員が自分の操作が数秒で出ることを確かめるためのもので、件数は少ない。
- 合成データ（`mode=simulated`）は乱数シード付きのモデルで生成し、レスポンスの `synthetic: true`、ダッシュボードの全カードと全グラフに「合成データ」と表示する。実データとして見せない。

## 見出しの指標

- **仕事探し以外で開いた日の割合**：利用日（`app_open` のあった install×日）のうち、`day_type` が `off`（シフト予約あり・今日は勤務なし）か `no_shift` の日の割合。あわせて、その日に求人カードを1枚も開かなかった割合も出す。
- 「一般的な求人アプリ」との比較は、引用できる公開データが見つかるまで載せない。

## 勤務のあとのシグナル（仮説）

誰も書き残さないが、次の行動に表れるシグナル。店舗ごとに集計し、パイロットで検証する仮説として扱う。結論としては使わない。

| シグナル | 仮説 | 検証方法 |
|---|---|---|
| 勤務の翌日にアプリを開いた率 − 同じワーカーのふだんの率（勤務日を除く） | 下がる店は相性が悪い | リピート率（同じ人・同じ店）、お店側の無断欠勤 |
| 勤務後3日以内にその店の島を再訪した率 | 愛着がある | おさそいの受諾、その店への再応募 |
| その店のおさそいを2回以上見送った人の割合 | 口に出さない「NO」 | 明示的なレビュー、インタビューでの離脱理由 |
| 勤務あたりのレビュー回答率 | 関わりの強さ | 星の評価、リピート率 |

ライブデータでこれを出すため、`job_*`・`shift_*`・`review_submitted` に `shop_id`、`app_open` に `hours_since_last_shift_end`（`none|lt24|24to72|gt72`）を持たせている。合成データでは店ごとの「雰囲気」を隠れ変数にして、翌日の再訪・島の再訪・おさそいの受諾・レビュー率・残業の起こりやすさに効かせている。会話タグも同じ雰囲気から生成する（雰囲気が悪い店ほど困りごと、良い店ほど「よかった」が増える）。会話は別の乱数列で作るので、会話を足しても他の合成値は変わらない。

## パイロットで測るもの（提案）

3〜5店舗・4週間。DAU/MAU、充足率、無断欠勤率、リピート率、レビュー回答率。成功基準（DAU/MAU 0.30 以上、充足率 80% 以上、無断欠勤 5% 以下、リピート率 40% 以上、レビュー回答率 60% 以上）は提案であり、実績ではない。充足率・無断欠勤・リピート率はお店側のシフトと勤怠（`apps/api` の Shifts / Attendance）から算出する。

## デプロイ

- API：Vercel プロジェクト `paw-time-api`（Root Directory `apps/api`）。`BLOB_READ_WRITE_TOKEN` は Vercel の環境変数だけに置く。
- ダッシュボード：Vercel プロジェクト `paw-time-insights`（Root Directory `apps/insights`）。`/v1/*` を API に rewrite するので同一オリジンで動く。
- CORS はゲームの `https://paw-time-play.vercel.app`（公開版）と旧URL `https://obake-breakroom-b-sleep.vercel.app`、localhost を許可。追加は `TELEMETRY_ALLOWED_ORIGINS`（カンマ区切り）。
