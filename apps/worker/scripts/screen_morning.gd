extends Control
## 朝。寝ている間に起きたこと（仕掛けの結果、おばけの成長）を1行ずつ見せる。

var main


func _ready() -> void:
	add_child(UI.background("bg_room"))
	var sun := ColorRect.new()
	sun.color = Color(1.0, 0.85, 0.55, 0.22)
	sun.set_anchors_preset(Control.PRESET_FULL_RECT)
	sun.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sun)

	var box := VBoxContainer.new()
	box.position = Vector2(16, 24)
	box.size = Vector2(328, 300)
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var s: Dictionary = GameState.today()
	box.add_child(UI.label("%s曜日の朝" % s.day, 28))
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 6)
	box.add_child(UI.panel(lines))
	for i in GameState.morning_report.size():
		var l := UI.label("・" + GameState.morning_report[i], 15)
		l.modulate.a = 0.0
		lines.add_child(l)
		var tw := create_tween()
		tw.tween_interval(0.35 + i * 0.55)
		tw.tween_property(l, "modulate:a", 1.0, 0.3)

	var floor_row := HBoxContainer.new()
	floor_row.position = Vector2(8, 440)
	floor_row.size = Vector2(344, 110)
	floor_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(floor_row)
	for o in GameState.owned.slice(0, 5):
		floor_row.add_child(ObakeView.new().setup(o.id, 2))

	var go_btn := UI.button("今日をはじめる", func(): main.go("room"))
	go_btn.position = Vector2(60, 574)
	go_btn.size = Vector2(240, 44)
	add_child(go_btn)
