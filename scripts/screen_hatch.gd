extends Control
## 朝、光る玉が割れる。1個ずつ震えて、光があふれて、おばけが現れる。

var main

var vp: SubViewport
var cam: Camera3D
var world: Node3D
var orbs: Array = []
var index := 0
var current_obake: Obake3D
var font_bold: FontFile
var font_black: FontFile
var card: PanelContainer
var card_title: Label
var card_sub: Label
var card_desc: Label
var badge: Label
var next_btn: Button
var header: Label
var flash: ColorRect
var burst: CPUParticles3D
var rays: MeshInstance3D
var sfx := {}
var busy := false
var skip_btn: Button
var btn_row: HBoxContainer
var rare_tease := false


func _update_header() -> void:
	var n := orbs.size()
	header.text = "朝のお迎え %d / %d%s" % [mini(index, n), n, "　虹色がまじってる" if rare_tease and index < n else ""]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	font_bold = load("res://assets/fonts/ZenMaruGothic-Bold.ttf")
	font_black = load("res://assets/fonts/ZenMaruGothic-Black.ttf")
	_build_world()
	_build_ui()
	for n in ["hatch", "sparkle", "chime", "levelup", "fanfare"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/sfx/%s.wav" % n)
		add_child(p)
		sfx[n] = p
	var n_orbs: int = GameState.hatched.size()
	for i in n_orbs:
		var h: Dictionary = GameState.hatched[i]
		var t: String = GameState.info(h.id).type
		var kind: String = "rainbow" if h.get("rare", false) or h.get("kind", "") == "rainbow" else h.get("kind", "normal")
		if kind == "school" or kind == "heavy":
			kind = "normal"
		var o := Orb3D.new().setup({"type": t if GameState.TYPE_COLOR.has(t) else "rare", "kind": kind})
		o.caught = true
		o.halo_mat.albedo_color.a = 0.08
		o.light.light_energy = 0.5
		var per_row := 6
		var row := i / per_row
		var in_row := mini(per_row, n_orbs - row * per_row)
		o.position = Vector3((i % per_row - (in_row - 1) / 2.0) * 0.34, 0.36 + row * 0.26, 0.2 - row * 0.3)
		o.halo.visible = false
		world.add_child(o)
		orbs.append(o)
	var rares := GameState.hatched.filter(func(h): return h.get("rare", false)).size()
	rare_tease = rares > 0
	_update_header()
	next_btn.text = "玉をひらく"
	if n_orbs >= 3:
		skip_btn = Button.new()
		skip_btn.text = "まとめて"
		skip_btn.focus_mode = Control.FOCUS_NONE
		skip_btn.custom_minimum_size = Vector2(96, 50)
		skip_btn.add_theme_font_override("font", font_bold)
		skip_btn.add_theme_font_size_override("font_size", 15)
		for k in ["normal", "hover", "pressed"]:
			skip_btn.add_theme_stylebox_override(k, _pill(Color(1, 1, 1, 0.85), 19))
		skip_btn.add_theme_color_override("font_color", Color("5b4a3a"))
		skip_btn.add_theme_color_override("font_hover_color", Color("5b4a3a"))
		skip_btn.pressed.connect(_open_all)
		btn_row.add_child(skip_btn)


func _build_world() -> void:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2a2233")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9a8b8")
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.6
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 40, 0)
	sun.light_color = Color("ffc98f")
	sun.light_energy = 0.45
	sun.shadow_enabled = true
	world.add_child(sun)

	cam = Camera3D.new()
	cam.position = Vector3(0, 1.35, 3.1)
	cam.fov = 48
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.45, 0))

	# 床と壁
	var floor_m := MeshInstance3D.new()
	var fp := PlaneMesh.new()
	fp.size = Vector2(10, 10)
	floor_m.mesh = fp
	floor_m.material_override = Obake3D.toon(Color("a87250"), 0.05)
	world.add_child(floor_m)
	var wall := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(10, 5, 0.1)
	wall.mesh = wm
	wall.position = Vector3(0, 2.5, -1.4)
	wall.material_override = Obake3D.toon(Color("c9a78a"), 0.05)
	world.add_child(wall)
	# 朝日の窓
	var win := MeshInstance3D.new()
	var wq := QuadMesh.new()
	wq.size = Vector2(1.4, 1.1)
	win.mesh = wq
	win.position = Vector3(-0.9, 1.7, -1.34)
	var wmat := StandardMaterial3D.new()
	wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wmat.albedo_color = Color("ffd9a0")
	wmat.emission_enabled = true
	wmat.emission = Color("ffb870")
	wmat.emission_energy_multiplier = 1.0
	win.material_override = wmat
	world.add_child(win)
	for x in [-0.9]:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 1.1, 0.02)
		bar.mesh = bm
		bar.position = Vector3(x, 1.7, -1.32)
		bar.material_override = Obake3D.toon(Color("6b4a3a"), 0.05)
		world.add_child(bar)
	# 光の筋
	rays = MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(1.2, 0.01, 3.0)
	rays.mesh = rb
	rays.position = Vector3(-0.4, 0.9, 0.0)
	rays.rotation = Vector3(0.5, 0.35, 0)
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rmat.albedo_color = Color(1.0, 0.8, 0.55, 0.06)
	rays.material_override = rmat
	rays.visible = false
	world.add_child(rays)
	# 座布団
	var cushion := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1.9, 0.16, 1.1)
	cushion.mesh = cm
	cushion.position = Vector3(0, 0.08, 0.2)
	cushion.material_override = Obake3D.toon(Color("c9454a"), 0.2)
	world.add_child(cushion)
	var cushion2 := MeshInstance3D.new()
	var cm2 := BoxMesh.new()
	cm2.size = Vector3(1.8, 0.04, 1.0)
	cushion2.mesh = cm2
	cushion2.position = Vector3(0, 0.18, 0.2)
	cushion2.material_override = Obake3D.toon(Color("dd5a5e"), 0.2)
	world.add_child(cushion2)

	burst = CPUParticles3D.new()
	burst.emitting = false
	burst.one_shot = true
	burst.amount = 60
	burst.lifetime = 1.3
	burst.explosiveness = 1.0
	burst.spread = 180
	burst.initial_velocity_min = 1.2
	burst.initial_velocity_max = 2.8
	burst.gravity = Vector3(0, -1.2, 0)
	var bmesh := SphereMesh.new()
	bmesh.radius = 0.03
	bmesh.height = 0.06
	burst.mesh = bmesh
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color("fff2a8")
	gm.emission_enabled = true
	gm.emission = Color("fff2a8")
	gm.emission_energy_multiplier = 3.0
	burst.material_override = gm
	world.add_child(burst)


func _pill(bg: Color, radius := 20) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 4)
	return s


func _text(t: String, size: int, color := Color("2a2233"), font: FontFile = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font if font else font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	return l


func _build_ui() -> void:
	header = _text("", 20, Color("fff6e8"), font_black)
	header.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
	header.add_theme_constant_override("outline_size", 6)
	header.position = Vector2(0, 30)
	header.size = Vector2(360, 40)
	add_child(header)

	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _pill(Color(1, 0.98, 0.95, 0.96), 24))
	card.position = Vector2(24, 400)
	card.size = Vector2(312, 140)
	card.modulate.a = 0.0
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	badge = _text("NEW", 13, Color("ffffff"), font_black)
	badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	var bp := PanelContainer.new()
	bp.add_theme_stylebox_override("panel", _pill(Color("ff6b5b"), 10))
	bp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bp.add_child(badge)
	v.add_child(bp)
	card_title = _text("", 28, Color("2a2233"), font_black)
	v.add_child(card_title)
	card_sub = _text("", 14, Color("8a7a88"))
	v.add_child(card_sub)
	card_desc = _text("", 14, Color("4a3f52"))
	v.add_child(card_desc)

	next_btn = Button.new()
	btn_row = HBoxContainer.new()
	btn_row.position = Vector2(16, 574)
	btn_row.size = Vector2(328, 50)
	btn_row.add_theme_constant_override("separation", 8)
	add_child(btn_row)
	next_btn.custom_minimum_size = Vector2(0, 50)
	next_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_btn.focus_mode = Control.FOCUS_NONE
	next_btn.add_theme_font_override("font", font_black)
	next_btn.add_theme_font_size_override("font_size", 18)
	for k in ["normal", "hover", "pressed"]:
		next_btn.add_theme_stylebox_override(k, _pill(Color("ff8a5b"), 25))
	next_btn.add_theme_stylebox_override("disabled", _pill(Color(1.0, 0.54, 0.36, 0.45), 25))
	next_btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.8))
	next_btn.add_theme_color_override("font_color", Color.WHITE)
	next_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	next_btn.pressed.connect(_next)
	btn_row.add_child(next_btn)

	flash = ColorRect.new()
	flash.color = Color("fff6d8")
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate.a = 0.0
	add_child(flash)


func _next() -> void:
	if busy:
		return
	if index >= orbs.size():
		main.go("room")
		return
	busy = true
	next_btn.disabled = true
	var tw0 := create_tween()
	tw0.tween_property(card, "modulate:a", 0.0, 0.15)
	if current_obake:
		tw0.parallel().tween_property(current_obake, "position:x", -3.0, 0.3)
	await tw0.finished
	if current_obake:
		current_obake.queue_free()
		current_obake = null
	var orb: Orb3D = orbs[index]
	var h: Dictionary = GameState.hatched[index]
	# 玉が前に出て、震える
	var tw := create_tween()
	tw.tween_property(orb, "position", Vector3(0, 0.75, 0.6), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	for i in 3:
		var amp := 0.03 + i * 0.03
		var tw2 := create_tween()
		tw2.tween_property(orb, "position:x", amp, 0.06)
		tw2.tween_property(orb, "position:x", -amp, 0.08)
		tw2.tween_property(orb, "position:x", 0.0, 0.06)
		tw2.parallel().tween_property(orb, "scale", Vector3.ONE * (1.0 + i * 0.25), 0.2)
		await tw2.finished
		await get_tree().create_timer(0.25 - i * 0.05).timeout
	# 割れる
	_flash(0.9)
	sfx["hatch"].play()
	if h.get("rare", false) or h.get("kind", "") == "rainbow":
		sfx["sparkle"].play()
	Input.vibrate_handheld(60)
	burst.position = orb.position
	burst.restart()
	burst.emitting = true
	orb.queue_free()
	current_obake = Obake3D.make(h.id)
	current_obake.set_level(h.get("before", 1) if h.get("leveled", false) else h.level)
	current_obake.position = Vector3(0, 0.55, 0.3)
	current_obake.scale = Vector3.ONE * 0.05
	world.add_child(current_obake)
	var tw3 := create_tween()
	tw3.tween_property(current_obake, "scale", Vector3.ONE * 0.5, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await tw3.finished
	var rare: bool = h.get("rare", false)
	sfx["fanfare" if rare or h.is_new else "chime"].play()
	var sp: Dictionary = GameState.info(h.id)
	card_title.text = sp.name
	badge.get_parent().visible = h.is_new
	var stars := "★".repeat(h.get("quality", 0)) + "☆".repeat(3 - h.get("quality", 0))
	if rare:
		card_sub.text = ("虹の玉から！ レア ・ %s" if h.get("from_rainbow", false) else "レア ・ %s") % sp.group
	else:
		card_sub.text = "Lv%d ・ %s  %s" % [h.level, _type_label(sp.type), stars]
	var extra := ""
	if h.get("leveled", false):
		extra = "Lv%d → Lv%d に育った！見た目も変わる" % [h.before, h.level]
	elif h.get("shard", "") != "":
		extra = "%sのかけら +1（工房で使える）" % GameState.SHARD_LABEL[h.shard]
	if h.get("kind", "") == "rainbow" and not rare:
		extra += ("\n" if extra != "" else "") + "虹の玉：大きく育ち、虹のかけら +1"
	card_desc.text = sp.desc + ("\n" + extra if extra != "" else "")
	card.position.y = 430
	var tw4 := create_tween().set_parallel()
	tw4.tween_property(card, "modulate:a", 1.0, 0.25)
	tw4.tween_property(card, "position:y", 390.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if rare:
		_stamp("レア！" if not h.get("from_rainbow", false) else "虹から、レア！")
	if h.get("leveled", false):
		await get_tree().create_timer(0.5).timeout
		sfx["levelup"].play()
		_flash(0.4)
		burst.position = current_obake.position + Vector3(0, 0.3, 0)
		burst.restart()
		burst.emitting = true
		current_obake.set_level(h.level)
		var bump := create_tween()
		bump.tween_property(current_obake, "scale", Vector3.ONE * 0.62, 0.15)
		bump.tween_property(current_obake, "scale", Vector3.ONE * 0.5, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	index += 1
	next_btn.text = "つぎの玉" if index < orbs.size() else "今日をはじめる"
	_update_header()
	if skip_btn:
		skip_btn.visible = orbs.size() - index >= 2
	next_btn.disabled = false
	busy = false


## レアのときの、はんこ
func _stamp(t: String) -> void:
	var l := _text(t, 34, Color("e8483f"), font_black)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_color_override("font_outline_color", Color("fff6e8"))
	l.add_theme_constant_override("outline_size", 10)
	l.position = Vector2(0, 96)
	l.size = Vector2(360, 50)
	l.pivot_offset = Vector2(180, 25)
	l.rotation = -0.12
	l.scale = Vector2(2.2, 2.2)
	l.modulate.a = 0.0
	add_child(l)
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 1.0, 0.12)
	var tw2 := create_tween()
	tw2.tween_interval(1.8)
	tw2.tween_property(l, "modulate:a", 0.0, 0.4)
	tw2.tween_callback(l.queue_free)


## 残りをまとめてひらいて、一覧で見せる
func _open_all() -> void:
	if busy:
		return
	busy = true
	next_btn.visible = false
	if skip_btn:
		skip_btn.visible = false
	card.modulate.a = 0.0
	if current_obake:
		current_obake.queue_free()
	_flash(0.9)
	sfx["hatch"].play()
	burst.position = Vector3(0, 0.5, 0.3)
	burst.restart()
	burst.emitting = true
	for o in orbs:
		if is_instance_valid(o):
			o.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.07, 0.12, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _pill(Color(1, 0.98, 0.95, 0.97), 24))
	p.position = Vector2(20, 90)
	p.size = Vector2(320, 0)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(_text("けさ かえったおばけ", 20, Color("2a2233"), font_black))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	var lvups := 0
	# 同じおばけはまとめて「×数」で（何十個あっても画面に収まるように）
	var agg := {}
	var order: Array = []
	for i in range(index, GameState.hatched.size()):
		var h: Dictionary = GameState.hatched[i]
		if not agg.has(h.id):
			agg[h.id] = {"n": 0, "new": false, "lv": 0, "rare": h.get("rare", false)}
			order.append(h.id)
		var a: Dictionary = agg[h.id]
		a.n += 1
		a.new = a.new or h.is_new
		if h.get("leveled", false):
			a.lv = max(a.lv, h.level)
	for id in order:
		var a: Dictionary = agg[id]
		var tag := ""
		if a.rare:
			tag = " レア!"
		elif a.new:
			tag = " NEW"
		elif a.lv > 0:
			tag = " Lv%d↑" % a.lv
			lvups += 1
		var l := _text("● %s%s%s" % [GameState.info(id).name, (" ×%d" % a.n) if a.n > 1 else "", tag], 14, Color("e85a4f") if a.new else Color("2a2233"))
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.custom_minimum_size = Vector2(145, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		grid.add_child(l)
	if lvups > 0:
		sfx["levelup"].play()
	var b := Button.new()
	b.text = "今日をはじめる"
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_override("font", font_black)
	b.add_theme_font_size_override("font_size", 18)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, _pill(Color("ff8a5b"), 24))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.pressed.connect(func(): main.go("room"))
	v.add_child(b)
	index = orbs.size()


func _type_label(t: String) -> String:
	return {"register": "レジの経験", "dish": "皿洗いの経験", "hall": "ホールの経験", "kitchen": "キッチンの経験", "stock": "品出しの経験", "night": "夜ふかし", "rare": "虹の玉", "sleep": "よく眠った朝"}.get(t, "")


func _flash(a: float) -> void:
	flash.modulate.a = a
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.5)


func demo_open() -> void:
	_next()
