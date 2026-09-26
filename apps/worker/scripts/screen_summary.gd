extends Control
## 1週間のまとめ。

var main


func _ready() -> void:
	add_child(UI.background("bg_room"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var p := UI.panel(box)
	p.position = Vector2(16, 60)
	p.size = Vector2(328, 420)
	add_child(p)
	box.add_child(UI.label("1週間おつかれさま", 24))
	box.add_child(UI.label("出会ったおばけ %d / %d 種類" % [GameState.seen.size(), GameState.ALL.size()], 16))
	box.add_child(UI.label("金曜の大ピーク：%s" % ("乗り切った" if GameState.battle_won else "回しきれなかった"), 16))
	var row := HFlowContainer.new()
	for o in GameState.owned:
		row.add_child(ObakeView.new().setup(o.id, 2))
	box.add_child(row)
	box.add_child(UI.label("働いた分だけ網は増える。でも、寝ないと網は振れない。\n一番強いのは、いろんな仕事をして、ちゃんと寝る人。", 14))
	box.add_child(UI.button("もう1週間あそぶ", func():
		GameState.reset()
		main.go("morning")))
