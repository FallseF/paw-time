# Paw Time（Godot 版・Variant B）

夜の庭で、おばけたちと暮らす。働いた日も休んだ日も、毎日の暮らしで庭が育つ。働きすぎを止めるのは、猫が疲れることだけ（眠りの記録は使わない）。
シフトの日は、仕事の種類のポイと、その店にちなんだ飾りが庭に届く（ブースト。長く働いても増えない）。
シフトは自分で入れる・求人で受ける。夜にすくった玉は、次の朝にかえる（「朝へ」で夜が明ける）。

## 動かす

```
godot --path ~/dev/obake-godot-b                          # タイトルから
OBAKE_START=garden OBAKE_FF=21 godot --path .             # 3週間すすめた庭から（早送り）
OBAKE_START=evening OBAKE_FF=14 godot --path .            # 2週目の夜から
OBAKE_START=moon OBAKE_FF=6 godot --path .                # 満月の夜
OBAKE_DEMO=play OBAKE_DAYS=14 godot --path .              # 自動で14日遊ぶ（OBAKE_MODE=solo でひとり）
godot --headless --path . -s tests/sim_b.gd               # バランスのシミュレーション
./promo/make_promo.sh                                     # 宣伝動画を撮り直す → promo/promo.mp4
```

`OBAKE_NOSAVE=1` で保存しない。セーブは `user://obake_b_save.json`。

## 1日の流れ

1. 朝：光る玉がかえる（新顔・レアは一体ずつ、いつもの子はまとめて）→ 庭が育つ → きのうのまとめ（めぐみ）
2. 昼：シフト（ポイと飾り）／おてつだい（ひとりのとき）／休む
3. 夜：今夜ともす飾りを選んで、川べりでおばけすくい（日曜は満月の夜）
4. 朝へ：入力は無い。夜が明けて、玉がかえる

## おさらいとスキルの記録（feature/skills）

- **おさらい（Practice）**：レジ・皿洗い・ホール・キッチン・品出しの 1〜3 分の練習。相棒のおばネコが小さな職場で一緒にやる（`scripts/screen_practice.gd`、中身は `scripts/practice_*.gd`、問題は `PracticeData`）。どの店でも通じる一般的な技能だけで、特定の店の手順は入れない。
- **スキルの記録（My skills / Skill passport）**：★1〜★3 の段をクリアするとバッジ。本物のシフトは 1 回＝経験 1（時間は数えない）。`user://skills.json` に保存し、店を移っても残る。島の「My skills」から開く。求人カードに自分のバッジと「2 分のおさらい、する？」（任意）が出る。
- **決まり**：おさらいはいつでも任意で、お店が求めるものではない。罰・急かすタイマー・他人との順位はない。ごほうびは段をはじめてクリアしたときだけ（★1 は制服、★2・★3 はポイ 1 本）で、肉球コインは出さない。
- **法の注記**：お店が命じる事前研修は労働時間にあたり、賃金の支払いが要る。だからここは、自分のために任意で練習する一般的な技能だけにしている。
- 確かめる：`OBAKE_NOSAVE=1 godot --headless --path . -s tests/test_skills.gd`。撮る：`OBAKE_START=practice OBAKE_PRACTICE=register OBAKE_SKILLS=register:1:3 godot --path .`
