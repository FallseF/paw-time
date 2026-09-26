extends Control
## 休憩室。今日のシフトに行き、網をもらう。捕まえたおばけが床を歩き回る。

var main
var walkers: Array = []
var nets_row: HBoxContainer
var info: Label
var actions: VBoxContainer


func _ready() -> void:
	add_child(UI.background("bg_room"))
	for o in GameState.owned:
		var v := ObakeView.new().setup(o.id, 2)
		v.position = Vector2(randf_range(10, 290), randf_range(420, 520))
		add_child(v)
		walkers.append({"v": v, "vx": randf_range(-18, 18)})

	var top := VBoxContainer.new()
	top.position = Vector2(12, 10)
	top.size = Vector2(336, 150)
	top.add_theme_constant_override("separation", 6)
	add_child(top)
	var s: Dictionary = GameState.today()
	var head := HBoxContainer.new()
	head.add_child(UI.label("%s曜日 ・ 休憩室" % s.day, 20, UI.INK, HORIZONTAL_ALIGNMENT_LEFT, false))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var zukan := UI.button("図鑑", func(): main.go("zukan"), true)
	zukan.custom_minimum_size = Vector2(64, 32)
	head.add_child(zukan)
	top.add_child(head)
	nets_row = HBoxContainer.new()
	nets_row.add_theme_constant_override("separation", 2)
	top.add_child(UI.panel(nets_row))

	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 8)
	var p := UI.panel(card)
	p.position = Vector2(12, 250)
	p.size = Vector2(336, 150)
	add_child(p)
	info = UI.label("", 15)
	card.add_child(info)
	actions = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	card.add_child(actions)
	_render()
	GameState.changed.connect(_render)


func _render() -> void:
	for c in nets_row.get_children():
		c.queue_free()
	nets_row.add_child(UI.label("網 ", 14, UI.INK, HORIZONTAL_ALIGNMENT_LEFT, false))
	for id in GameState.NETS:
		nets_row.add_child(UI.icon("res://assets/sprites/net_%s.png" % id, 24))
		nets_row.add_child(UI.label("%d " % GameState.nets[id], 14, UI.INK, HORIZONTAL_ALIGNMENT_LEFT, false))
	nets_row.add_child(UI.label("振れる%d" % GameState.stamina, 14, UI.RED, HORIZONTAL_ALIGNMENT_LEFT, false))

	for c in actions.get_children():
		c.queue_free()
	var s: Dictionary = GameState.today()
	match GameState.phase:
		"morning", "room":
			if s.role == "":
				info.text = "今日は休み。網はもらえないけど、散歩でおばけは探せる"
				actions.add_child(UI.button("散歩に出る", func(): _after_shift()))
			else:
				info.text = "今日のシフト：%s\n%sの%s %d時間%s" % [s.store, s.band, GameState.ROLE_LABEL[s.role], s.hours, "（はじめて）" if s.first else ""]
				actions.add_child(UI.button("シフトに行く", _do_shift))
		"shift_done":
			if GameState.day == GameState.BATTLE_DAY and not GameState.battle_won:
				actions.add_child(UI.button("金曜の大ピークに入る", func(): main.go("battle")))
			actions.add_child(UI.button("帰り道で網を振る", func(): main.go("catch")))


func _do_shift() -> void:
	var got := GameState.finish_shift()
	info.text = "おつかれさま！網をもらった\n" + "\n".join(got)
	_after_shift()


func _after_shift() -> void:
	GameState.phase = "shift_done"
	GameState.changed.emit()
	for c in actions.get_children():
		c.queue_free()
	if GameState.day == GameState.BATTLE_DAY and not GameState.battle_won:
		actions.add_child(UI.button("金曜の大ピークに入る", func(): main.go("battle")))
	actions.add_child(UI.button("帰り道で網を振る", func(): main.go("catch")))


func _process(delta: float) -> void:
	for w in walkers:
		var v: ObakeView = w.v
		v.position.x += w.vx * delta
		if v.position.x < 0 or v.position.x > 296:
			w.vx *= -1
