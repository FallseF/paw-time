extends Control
## 夜のおわり。すくった玉は、次の朝にかえる（寝る時刻などの入力は無い）。
## 「朝へ」で GameState.end_night() → 玉があれば孵化、なければ朝の庭。
## あしたシフトがあれば、相棒の「あした 10:00・カフェ こもれび。また向こうでね！」（Reminders）

var main
var stars: Array = []
var _t := 0.0
var going := false


func _ready() -> void:
	var bg := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color("0b1026"))
	g.set_color(1, Color("3a2d5c"))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	bg.texture = gt
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	for i in 50:
		var s := ColorRect.new()
		s.size = Vector2.ONE * randf_range(1.5, 3.0)
		s.position = Vector2(randf() * 360, randf() * 260)
		s.color = Color(1, 1, 1, randf_range(0.3, 0.9))
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(s)
		stars.append([s, randf() * TAU])
	var moon := Panel.new()
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color("fff1c8")
	ms.set_corner_radius_all(28)
	ms.shadow_color = Color(1, 0.95, 0.8, 0.45)
	ms.shadow_size = 16
	moon.add_theme_stylebox_override("panel", ms)
	moon.position = Vector2(270, 40)
	moon.size = Vector2(56, 56)
	add_child(moon)

	var title := Kit.text("夜がふけていく", 24, Color("f3eeff"), true, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(0, 110)
	title.size = Vector2(360, 36)
	add_child(title)
	var n := GameState.orbs.size()
	var sub := Kit.text(tr("今夜の玉 %d 個。朝になったら、かえる") % n if n > 0 else tr("今夜はすくわなかった。朝はすぐ来る"), 14, Color(1, 1, 1, 0.75), false, HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(0, 150)
	sub.size = Vector2(360, 24)
	add_child(sub)
	# 今夜の玉（色の丸）
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.position = Vector2(0, 186)
	row.size = Vector2(360, 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for o in GameState.orbs.slice(0, 10):
		var dot := Panel.new()
		var ds := StyleBoxFlat.new()
		ds.bg_color = GameState.TYPE_COLOR.get(o.get("type", "any"), Color("f4f1ea"))
		ds.set_corner_radius_all(10)
		ds.shadow_color = Color(ds.bg_color, 0.6)
		ds.shadow_size = 6
		dot.add_theme_stylebox_override("panel", ds)
		dot.custom_minimum_size = Vector2(20, 20)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
	add_child(row)
	var cat := PartnerStage.new(Vector2(200, 190))
	cat.position = Vector2(80, 240)
	add_child(cat)

	var go := Kit.button("朝へ", Color("8b7bff"), _morning, Color.WHITE, 54, 20)
	go.position = Vector2(40, 560)
	go.size = Vector2(280, 54)
	add_child(go)
	Reminders.attach_night(self, 440) # あしたシフトがあれば、相棒のひとこと


func _process(delta: float) -> void:
	_t += delta
	for st in stars:
		(st[0] as ColorRect).modulate.a = 0.55 + 0.45 * sin(_t * 1.3 + st[1])


func _morning() -> void:
	if going:
		return
	going = true
	var light := ColorRect.new()
	light.color = Color("ffd9b0")
	light.set_anchors_preset(Control.PRESET_FULL_RECT)
	light.modulate.a = 0.0
	add_child(light)
	Kit.play(self, "chime", 0.8)
	var tw := create_tween()
	tw.tween_property(light, "modulate:a", 1.0, 0.8)
	await tw.finished
	GameState.end_night()
	main.go("hatch" if not GameState.hatched.is_empty() else "garden")


# ---------------------------------------------------------------- 確認用（OBAKE_SHOT の call:）

func demo_morning() -> void:
	_morning()
