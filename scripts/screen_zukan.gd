extends Control
## 図鑑。捕まえた種類だけが埋まる。

var main
var desc: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = UI.CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var head := HBoxContainer.new()
	head.position = Vector2(12, 10)
	head.size = Vector2(336, 36)
	add_child(head)
	head.add_child(UI.label("図鑑  %d / %d" % [GameState.seen.size(), GameState.SPECIES.size()], 22, UI.INK, HORIZONTAL_ALIGNMENT_LEFT, false))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(UI.button("もどる", func(): main.go("room"), true))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(12, 60)
	grid.size = Vector2(336, 380)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	add_child(grid)
	for id in GameState.SPECIES:
		var found: bool = GameState.seen.has(id)
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(92, 104)
		var p := UI.panel(cell)
		var v := ObakeView.new().setup(id, 2, found)
		if not found:
			v.modulate = Color(0, 0, 0, 0.35)
		var c := CenterContainer.new()
		c.add_child(v)
		cell.add_child(c)
		cell.add_child(UI.label(GameState.SPECIES[id].name if found else "？？？", 13, UI.INK, HORIZONTAL_ALIGNMENT_CENTER))
		var lv := ""
		for o in GameState.owned:
			if o.id == id:
				lv = "Lv%d" % o.level
		cell.add_child(UI.label(lv, 12, UI.GRAY, HORIZONTAL_ALIGNMENT_CENTER))
		p.gui_input.connect(func(e):
			if e is InputEventMouseButton and e.pressed:
				desc.text = ("%s：%s" % [GameState.SPECIES[id].name, GameState.SPECIES[id].desc]) if found else "まだ会っていない。どんな経験をすれば出会える？")
		grid.add_child(p)

	desc = UI.label("おばけをタップすると説明が出る", 14)
	var dp := UI.panel(desc)
	dp.position = Vector2(12, 548)
	dp.size = Vector2(336, 80)
	add_child(dp)
