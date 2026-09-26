# マイおばけ猫 診断 — 組み込み手順

はじめて起動したときに 12 問の診断をして、プレイヤー自身の猫おばけ（相棒）を決める。
結果は 1080x1350 のカード画像と短い文面でシェアできる。

**英語が既定**。画面・カード・シェア文の文字はすべて `i18n/quiz.csv`（列 `keys,en,ja`）にあり、
`QuizData.t()`（中身は `TranslationServer.translate()`）で引く。日本語は `QuizData.locale = "ja"` か `OBAKE_LANG=ja` で切り替える。

## 1. コピーするファイル

| ファイル | 役割 |
|---|---|
| `scripts/quiz_data.gd` (`QuizData`) | 12 問・4 軸・16 タイプの中身（仕事・相性・見た目）、採点 `score()`、シェア文 `share_text()`、差し色 `tone()`、言語 `setup_i18n()` / `t()` |
| `i18n/quiz.csv`（と `.import`・`quiz.en.translation`・`quiz.ja.translation`） | 文字の正本（英語・日本語）。文言を直すのはここだけ |
| `scripts/quiz_result.gd` (`QuizResult`) | 結果を `user://my_obake.json` に保存・読み込み（ゲーム本体のセーブとは別ファイル） |
| `scripts/my_obake3d.gd` (`MyObake3D`) | 見た目の辞書（色・持ち物・しぐさ）から猫おばけを組む。`Obake3D` を継承 |
| `scripts/quiz_card.gd` (`QuizCard`) | シェアカードの描画 `render()` と保存 `deliver()`（web はダウンロード） |
| `scripts/screen_quiz.gd` | 画面：はじめに → 12 問 → 玉が割れて結果 → シェア |
| `tests/test_quiz.gd` | 採点・16 タイプ・持ち物・フォントの字・保存のテスト（任意） |
| `tests/render_quiz_cards.gd` | 16 枚のカードと一覧を撮る（任意） |

`.gd.uid` も一緒にコピーする。`class_name` を使っているので、コピー後に一度
`godot --headless --path . --import` を通す（CSV から `.translation` もここで作り直される）。
翻訳は `QuizData.setup_i18n()` がコードから読み込むので、`project.godot` の翻訳一覧に登録しなくてよい。

前提として、variant 側に次があること（master にはある）。

- `scripts/obake3d.gd` の `Obake3D`（`ghost()` / `face()` / `toon()` / `_mesh()` / `_sphere()` / `eyes` / `body` / `_t` / `bob`）
- `scripts/orb_model.gd` の `OrbModel`（`setup()` / `set_energy()` / `core_mat` / `shell_mat` / `light`）
- `scripts/look.gd` の `Look.apply()`（光は `studio` のプリセットを使う）と、AAA 版の `Obake3D`（`skin()` / `prop()` / `_box()` / `_cyl()` / `_torus()`）
- `assets/fonts/ZenMaruGothic-Bold.ttf` と `-Black.ttf`
- `assets/sfx/hatch.wav` `sparkle.wav` `chime.wav` `lift.wav`
- autoload の `GameState`

## 2. 小さな追加（3 か所）

**GameState**（autoload）に相棒の入れ物を足す。週のやり直しでは消さない。

```gdscript
var my_obake := {}  # {type_id, look, answers, axes}

func _ready() -> void:
	# …既存の処理のあと
	my_obake = QuizResult.load_result()

func set_my_obake(result: Dictionary) -> void:
	my_obake = result.duplicate(true)
	QuizResult.save(my_obake)
	changed.emit()  # signal が無い variant なら省く
```

本体のセーブ（variant-a/c の `SAVE_KEYS` など）に `my_obake` を入れてもよいが、
`user://my_obake.json` が正本なので必須ではない。入れる場合もロード時は `QuizResult.load_result()` を優先する。

**Obake3D**（任意）: `make()` の下に入口を足しておくと、呼ぶ側が `MyObake3D` を知らなくて済む。

```gdscript
static func make_custom(look: Dictionary) -> Obake3D:
	return MyObake3D.new().setup_look(look)
```

**main.gd**: 画面表に `"quiz": preload("res://scripts/screen_quiz.gd")` を足す。

## 3. 初回の流れ（タイトル → 診断 → ゲーム）

`screen_quiz.gd` は `main` と `next_screen` を持つ。`main.go()` が `current.set("main", self)` する作りならそのまま動く。

タイトルの「はじめる」を次のように分ける。

```gdscript
func _on_start() -> void:
	if GameState.my_obake.is_empty():
		main.go("quiz")      # 診断が終わると next_screen（既定 "morning"）へ進む
	else:
		main.go("room")
```

進み先を変えたい場合は、`main.go()` の中で画面を作った直後に指定する。

```gdscript
current = SCREENS[screen_name].new()
if screen_name == "quiz":
	current.next_screen = "room"   # variant の最初の画面名
```

`main` を使わずに埋め込む場合は、`finished(result)` シグナルを受け取って自分で次へ進める
（その場合 `main` は null のままにしておく）。

もう一度診断する導線（設定画面など）を作るときは、単に `main.go("quiz")` を呼ぶ。
結果は「この子と はじめる」を押した時点で上書きされる。

## 4. マイおばけ猫を相棒として出す

```gdscript
# 3D：休憩室や相棒の表示枠に置く
if not GameState.my_obake.is_empty():
	var me := MyObake3D.new().setup_look(GameState.my_obake.look)
	me.scale = Vector3.ONE * 0.62   # 休憩室のおばけと同じ縮尺
	world.add_child(me)
```

- 名前や説明は `QuizData.TYPES[GameState.my_obake.type_id]`（`name` / `line` / `en_name` / `en_line` / `job` / `match`）。
- `job` は `register / dish / hall / kitchen / stock`。variant の「仕事の種類」と同じ ID なので、
  相棒ボーナス（例: 向いてる仕事のシフトで網が 1 本増える）に使える。
- variant-a の `partner`（捕まえたおばけの ID）とは別物。相棒枠を 1 つにしたいなら、
  `partner == "my"` を「マイおばけ猫」として扱い、表示だけ `MyObake3D` に差し替えるのが一番小さい。
- 撮影用に動きを止めたいときは `me.hold_still()`。
- `MyObake3D` は体・顔を `ghost()` / `face()`、持ち物の材質を `prop()`、形を `_box()` / `_cyl()` / `_torus()` で作るので、
  Obake3D の見た目を変えるとそのまま追従する。持ち物の位置は Blender 製の体（頭 ≈ 半径 0.5・中心 y=0.5、頭頂 y≈1.02、
  耳先 x±0.33・y≈1.11、裾は y0.1〜0.2 で半径≈0.56）に合わせてある。体の形を大きく変えたら 16 枚のカードを撮り直して確かめる。
- 3D の舞台には `Look.apply(world, "studio", 背景色)` を使うと、図鑑やカードと同じ光になる。

## 5. シェア

- `QuizCard.render(host, result)` は await が要る（SubViewport を数フレーム描いて撮る）。
- `QuizCard.deliver(image, type_id)`: web（`OS.has_feature("web")`）では `JavaScriptBridge.download_buffer` で PNG をダウンロード、
  それ以外は `user://paw_time_my_obake_<TYPE>.png` に保存してフルパスを返す。
- シェア文は `QuizData.share_text(type_id)` を `DisplayServer.clipboard_set()` でコピー。URL は `QuizData.SITE_URL`。
- カードもシェア文も、その時の言語（既定は英語）で作られる。

## 6. 確かめ方

```sh
godot --headless --path . --import
godot --headless --path . -s tests/test_quiz.gd                # 採点・16 タイプ・字・保存
OBAKE_START=quiz godot --path .                                 # 画面を触る
OBAKE_START=quiz OBAKE_QUIZ_AUTO=ABBAABBAABBA OBAKE_SHOT=wait6 \
  OBAKE_SHOT_PATH=/tmp/q.png godot --path . --resolution 360x640 --quit-after 30000
godot --path . --resolution 360x640 -s tests/render_quiz_cards.gd   # ui_review/quiz_cards/en と /ja
OBAKE_LANG=ja OBAKE_START=quiz godot --path .                   # 日本語で確かめる
```

- `OBAKE_QUIZ_AUTO` は A/B を 12 個まで。12 個そろうと結果の演出まで進む（約 4 秒）。途中までならその問題で止まる。
- 任意のタイプの答えは `QuizData.answers_for("IFMY")`。問題の並びは 軸0,1,2,3 の繰り返し。
- `OBAKE_SHOT=wait6,call:open_share,wait2` でシェア画面を撮れる。

## 7. タイプ一覧

名前と一言の英語・日本語は `i18n/quiz.csv` の `QUIZ_T_<ID>_NAME` / `_LINE`。

| ID | 名前（日本語） | 仕事 | 持ち物 | しぐさ | 相性 |
|---|---|---|---|---|---|
| OPHK | ホールの司令塔 | hall | headphones | scan | IPHY |
| OPHY | 常連さんの記憶係 | register | bell | sway | IPHK |
| OPMK | 棚の整列隊長 | stock | cap | hop | IPMY |
| OPMY | まかないの達人 | kitchen | bandana | wiggle | IPMK |
| OFHK | 笑顔のレジ番長 | register | flower | bounce | IFHY |
| OFHY | 休憩室のムードメーカー | hall | bow | twirl | IFHK |
| OFMK | 新メニュー研究員 | kitchen | chef_hat | nod | IFMY |
| OFMY | のんびり発明家 | stock | glasses | float | IFMK |
| IPHK | シフト表の守り神 | register | name_tag | scan | OPHY |
| IPHY | 聞き上手のおばけ | hall | scarf | nod | OPHK |
| IPMK | 深夜のひとり職人 | dish | headband | wiggle | OPMY |
| IPMY | 在庫の番人 | stock | apron | float | OPMK |
| IFHK | 気配り忍者 | hall | star_pin | hop | OFHY |
| IFHY | そばにいる癒やし係 | dish | leaf | sway | OFHK |
| IFMK | こだわりの仕込み番 | kitchen | beret | bob | OFMY |
| IFMY | おやすみ上手 | stock | towel | doze | OFMK |

軸: O 外へ Out / I 内へ In、P 段取り Plan / F ひらめき Spark、H 人 People / M モノ Things、K きっちり Tidy / Y ゆったり Easy。
結果画面とカードの棒は、各軸 3 問のうち前の極を選んだ割合（0 / 33 / 67 / 100%）を、多い側から見た値で出す。
相性は「外へ↔内へ」「きっちり↔ゆったり」を入れ替えた相手（相互）。
