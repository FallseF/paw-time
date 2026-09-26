extends Control
## 寝る前。何時間寝るかと、仕掛ける網を決める。
## 本番ではスマホの睡眠記録から入る。見本では自分で選べる。

var main
var hours := 7
var trap := ""
var preview: Label
var hours_label: Label
var trap_row: HBoxContainer


func _ready() -> void:
	add_child(UI.background("bg_room"))
	var night := ColorRect.new()
	night.color = Color(0.1, 0.12, 0.3, 0.55)
	night.set_anchors_preset(Control.PRESET_FULL_RECT)
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var p := UI.panel(box)
	p.position = Vector2(16, 120)
	p.size = Vector2(328, 400)
	add_child(p)
	box.add_child(UI.label("おやすみの前に", 22))
	box.add_child(UI.label("本番ではスマホの睡眠記録から自動で入ります", 12, UI.GRAY))
	hours_label = UI.label("", 18)
	box.add_child(hours_label)
	var slider := HSlider.new()
	slider.min_value = 4
	slider.max_value = 9
	slider.step = 1
	slider.value = hours
	slider.custom_minimum_size = Vector2(0, 28)
	slider.value_changed.connect(func(v):
		hours = int(v)
		_update())
	box.add_child(slider)
	preview = UI.label("", 14)
	box.add_child(preview)
	box.add_child(UI.label("網を1本、仕掛けて寝る", 16))
	trap_row = HBoxContainer.new()
	box.add_child(trap_row)
	box.add_child(UI.button("おやすみ", _sleep))
	_build_traps()
	_update()


func _build_traps() -> void:
	for c in trap_row.get_children():
		c.queue_free()
	for id in GameState.NETS:
		if GameState.nets[id] <= 0:
			continue
		var b := Button.new()
		b.icon = load("res://assets/sprites/net_%s.png" % id)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(46, 46)
		b.add_theme_stylebox_override("normal", UI.box(UI.YELLOW if id == trap else UI.WHITE, UI.INK, 3 if id == trap else 2, 3))
		b.pressed.connect(func():
			trap = "" if trap == id else id
			_build_traps()
			_update())
		trap_row.add_child(b)
	if trap_row.get_child_count() == 0:
		trap_row.add_child(UI.label("網が残っていない", 14, UI.GRAY))


func _update() -> void:
	hours_label.text = "%d時間ねる" % hours
	var strength := 0.7 if hours < 6 else (1.0 if hours < 7 else 1.25)
	var hint := ""
	if hours >= 7:
		hint = "\nよく眠ると、仕掛けにネムリンがかかりやすい"
	elif hours <= 5:
		hint = "\n夜ふかしすると、ヨミセが寄ってくる。でも網は弱くなる"
	preview.text = "明日：網を振れる回数 %d、網の強さ ×%.2f\nおばけはみんな +%d 育つ%s" % [hours, strength, hours * 6, hint]


func _sleep() -> void:
	var zz := UI.label("Z z z …", 40, UI.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	zz.position = Vector2(0, 280)
	zz.size = Vector2(360, 80)
	var dark := ColorRect.new()
	dark.color = UI.INK
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.modulate.a = 0.0
	add_child(dark)
	add_child(zz)
	var tw := create_tween()
	tw.tween_property(dark, "modulate:a", 1.0, 0.5)
	tw.tween_interval(0.8)
	await tw.finished
	GameState.sleep(hours, trap)
	main.go("hatch" if GameState.hatched.size() > 0 else "morning")
