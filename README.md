# Paw Time（Godot 版・Variant B「眠りのリズム」）

夜の庭で、おばけたちと暮らす。いつも同じころに、よく眠ると「リズム」が満ちて、庭が育つ。
シフトの日は、仕事の種類のポイと、その店にちなんだ飾りが庭に届く（ブースト。長く働いても増えない）。
記録がなくても（ゲームだけで遊ぶ）毎晩遊べる。記録とつなぐ（見本データ）と、シフトと睡眠記録が入って、もっとにぎやかになる。

## 動かす

```
godot --path ~/dev/obake-godot-b                          # タイトルから
OBAKE_START=garden OBAKE_FF=21 godot --path .             # 3週間すすめた庭から（早送り）
OBAKE_START=evening OBAKE_FF=14 godot --path .            # 2週目の夜から
OBAKE_START=dream OBAKE_DREAM=stars godot --path .        # 夢（星ひろい。sheep で羊かぞえ）
OBAKE_START=moon OBAKE_FF=6 godot --path .                # 満月の夜
OBAKE_DEMO=play OBAKE_DAYS=14 godot --path .              # 自動で14日遊ぶ（OBAKE_MODE=solo でひとり）
godot --headless --path . -s tests/sim_b.gd               # バランスのシミュレーション
./promo/make_promo.sh                                     # 宣伝動画を撮り直す → promo/promo.mp4
```

`OBAKE_NOSAVE=1` で保存しない。セーブは `user://obake_b_save.json`。

## 1日の流れ

1. 朝：光る玉がかえる（新顔・レアは一体ずつ、いつもの子はまとめて）→ 庭が育つ → ゆうべの眠りのまとめ
2. 昼：シフト（ポイと飾り）／おてつだい（ひとりのとき）／休む
3. 夜：今夜ともす飾りを選んで、川べりでおばけすくい（日曜は満月の夜）
4. 寝る：過ごし方を選ぶ（記録どおり・早め・いつも・もうひと回り・夜店）。リズムが整った夜は夢（羊かぞえ／星ひろい）
