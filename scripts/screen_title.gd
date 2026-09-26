extends Control
## タイトル。つづきから／はじめから（記録とつなぐ・ゲームだけ）。

var main
var vp: SubViewport
var obs: Array = []
var _t := 0.0
var confirm: Control


func _ready() -> void:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	var w := Node3D.new()
	vp.add_child(w)
	var rig := Look.apply(w, "title", Color("141a3a"), false, false)
	var cam := Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.position = Vector3(0, 1.2, 6.0)
	cam.fov = 44
	w.add_child(cam)
	cam.look_at(Vector3(0, 0.2, 0))
	var ground := MeshInstance3D.new()
	var gp := CylinderMesh.new()
	gp.top_radius = 2.6
	gp.bottom_radius = 2.6
	gp.height = 0.1
	ground.mesh = gp
	ground.position = Vector3(0, -0.55, 0)
	ground.material_override = Obake3D.toon(Color("4f7a4a"), 0.1)
	w.add_child(ground)
	var moon := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 0.7
	mm.height = 1.4
	moon.mesh = mm
	moon.material_override = Kit.glow(Color("fff1c8"), 2.0)
	moon.position = Vector3(2.2, 2.2, -5)
	w.add_child(moon)
	var ids := ["nemuri", "receipt", "lantern"]
	for i in ids.size():
		var o := Obake3D.new().setup(ids[i])
		o.position = Vector3((i - 1) * 1.15, -0.5, 0)
		o.scale = Vector3.ONE * 0.75
		o.rotation.y = (1 - i) * 0.35
		w.add_child(o)
		obs.append(o)
	var flies := CPUParticles3D.new()
	flies.amount = 30
	flies.lifetime = 6.0
	flies.preprocess = 6.0
	flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flies.emission_box_extents = Vector3(3, 1.5, 1.5)
	flies.gravity = Vector3.ZERO
	flies.initial_velocity_max = 0.1
	flies.spread = 180
	var fm := SphereMesh.new()
	fm.radius = 0.02
	fm.height = 0.04
	flies.mesh = fm
	flies.material_override = Kit.glow(Color("d8ff9a"), 4.0)
	flies.position = Vector3(0, 0.8, 0)
	w.add_child(flies)

	var lb := Button.new()
	lb.flat = true
	lb.text = "日本語" if Kit.is_en() else "EN"
	lb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	lb.add_theme_font_override("font", Kit.bold())
	lb.add_theme_font_size_override("font_size", 14)
	lb.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	lb.position = Vector2(270, 10)
	lb.size = Vector2(80, 32)
	lb.pressed.connect(func():
		Kit.save_lang("ja" if Kit.is_en() else "en")
		main.go("title", true))
	add_child(lb)
	var t1 := Kit.text("Paw Time", 44, Color("fff6e8"), true, HORIZONTAL_ALIGNMENT_CENTER)
	t1.add_theme_color_override("font_outline_color", Color("0b1026"))
	t1.add_theme_constant_override("outline_size", 10)
	t1.position = Vector2(0, 56)
	t1.size = Vector2(360, 50)
	add_child(t1)
	var t2 := Kit.text("ねこおばけと、夜の庭", 16, Color("c9bdf5"), false, HORIZONTAL_ALIGNMENT_CENTER)
	t2.position = Vector2(0, 122)
	t2.size = Vector2(360, 24)
	add_child(t2)
	var t3 := Kit.text("よく眠ると、庭が育つ", 13, Color(1, 1, 1, 0.7), false, HORIZONTAL_ALIGNMENT_CENTER)
	t3.position = Vector2(0, 150)
	t3.size = Vector2(360, 20)
	add_child(t3)

	var v := VBoxContainer.new()
	v.position = Vector2(40, 430)
	v.size = Vector2(280, 0)
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	if GameState.has_save():
		var b := Kit.button("つづきから", Color("ff8a5b"), _continue)
		v.add_child(b)
		var peek := _peek()
		if peek != "":
			v.add_child(Kit.text(peek, 12, Color(1, 1, 1, 0.75), false, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Kit.button("はじめる（見本の記録つき）", Color("8b7bff") if not GameState.has_save() else Color("6a5bd6"), func(): _new("data"), Color.WHITE, 46, 15))
	v.add_child(Kit.button("記録なしで、はじめる", Color(1, 1, 1, 0.92), func(): _new("solo"), Color("4a3f52"), 42, 14))
	var n := Kit.text("記録なしでも、毎晩あそべます", 12, Color(1, 1, 1, 0.55), false, HORIZONTAL_ALIGNMENT_CENTER)
	var vb := Button.new()
	vb.flat = true
	vb.text = "島のコードで、おでかけ"
	vb.add_theme_font_override("font", Kit.bold())
	vb.add_theme_font_size_override("font_size", 13)
	vb.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	vb.pressed.connect(_ask_code)
	v.add_child(n)
	v.add_child(vb)


func _process(delta: float) -> void:
	_t += delta


func _continue() -> void:
	if GameState.load_game():
		# 途中で閉じた朝の続きから
		if GameState.dream_pending:
			main.go("dream")
		elif not GameState.hatched.is_empty():
			main.go("hatch")
		else:
			main.go(Onboarding.resume_screen()) # はじめての流れの途中なら、その続きから


func _new(mode: String) -> void:
	if GameState.has_save() and confirm == null:
		_confirm(mode)
		return
	GameState.reset(mode)
	GameState.save()
	_begin()


## はじめての人は、まずマイおばけ猫の診断から（終わると島へ）
func _begin() -> void:
	main.go("quiz" if GameState.my_obake.is_empty() else Onboarding.resume_screen())


func _confirm(mode: String) -> void:
	confirm = Control.new()
	confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(confirm)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color("fffaf2"), 22, 0.2, Vector2(18, 16)))
	p.position = Vector2(30, 230)
	p.size = Vector2(300, 0)
	confirm.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(Kit.text("はじめからにする？", 18, Color("2a2233"), true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Kit.wrap(Kit.text("いまの庭と図鑑は消えます", 13, Color("6a5f70"), false, HORIZONTAL_ALIGNMENT_CENTER)))
	v.add_child(Kit.button("はじめから", Color("e85a4f"), func():
		GameState.reset(mode)
		GameState.save()
		_begin()))
	v.add_child(Kit.button("やめる", Color(1, 1, 1, 0.9), func():
		confirm.queue_free()
		confirm = null, Color("4a3f52"), 40, 14))


## セーブの中身をのぞいて、どこまで進んだかを一行で
func _peek() -> String:
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.READ)
	if f == null:
		return ""
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return ""
	var dd := int(d.get("day", 0))
	var lv := int(d.get("garden_level", 0))
	var seen: Dictionary = d.get("seen", {})
	return tr("%d週目 %s曜日 ・ 庭 Lv%d ・ 図鑑 %d") % [dd / 7 + 1, tr(GameState.WEEKDAYS[dd % 7]), lv + 1, seen.size()]


## 手元で試すとき：島のコード（または URL）を貼って、おでかけ
func _ask_code() -> void:
	if confirm:
		confirm.queue_free()
	confirm = Control.new()
	confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(confirm)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color("fffaf2"), 22, 0.2, Vector2(18, 16)))
	p.position = Vector2(24, 200)
	p.size = Vector2(312, 0)
	confirm.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(Kit.text("島のコード", 18, Color("2a2233"), true, HORIZONTAL_ALIGNMENT_CENTER))
	var le := LineEdit.new()
	le.placeholder_text = "コードかリンクを貼る"
	var st := Kit.pill(Color("f3ecff"), 12, 0.0, Vector2(10, 8))
	le.add_theme_stylebox_override("normal", st)
	le.add_theme_stylebox_override("focus", st)
	le.add_theme_color_override("font_color", Color("2a2233"))
	le.add_theme_color_override("font_placeholder_color", Color("a89ea6"))
	le.add_theme_font_override("font", Kit.bold())
	le.add_theme_font_size_override("font_size", 13)
	v.add_child(le)
	var msg := Kit.text("", 12, Color("c0473b"), false, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(msg)
	v.add_child(Kit.button("おでかけする", Color("ff8a5b"), func():
		var d := GameState.decode_island(le.text)
		if d.is_empty():
			msg.text = "コードが読めなかった"
			return
		if GameState.has_save():
			GameState.load_game()
		d.code = le.text.strip_edges()
		GameState.visit = d
		main.go("garden")))
	v.add_child(Kit.button("やめる", Color(1, 1, 1, 0.9), func():
		confirm.queue_free()
		confirm = null, Color("4a3f52"), 40, 14))


func _new_data() -> void:
	_new("data")
