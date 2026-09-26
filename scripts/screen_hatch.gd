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
var deck_btn: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	font_bold = load("res://assets/fonts/ZenMaruGothic-Bold.ttf")
	font_black = load("res://assets/fonts/ZenMaruGothic-Black.ttf")
	_build_world()
	_build_ui()
	Kit.music("c_calm_loop")
	for n in ["hatch", "sparkle", "chime"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/sfx/%s.wav" % n)
		add_child(p)
		sfx[n] = p
	var n_orbs: int = GameState.hatched.size()
	for i in n_orbs:
		var h: Dictionary = GameState.hatched[i]
		var t: String = GameState.info(h.id).type
		var o := Orb3D.new().setup({"type": t if GameState.TYPE_COLOR.has(t) else "rare", "rare": h.id == "kirari", "weight": 0.3})
		o.caught = true
		o.halo_mat.albedo_color.a = 0.08
		o.light.light_energy = 0.5
		o.position = Vector3((i - (n_orbs - 1) / 2.0) * 0.42, 0.42, 0.2)
		world.add_child(o)
		orbs.append(o)
	header.text = "朝だ。光る玉が %d 個" % n_orbs
	next_btn.text = "玉をひらく"


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
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 40, 0)
	sun.light_color = Color("ffc98f")
	sun.light_energy = 0.6
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
	wall.material_override = Obake3D.toon(Color("e8d3bd"), 0.05)
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
	next_btn.position = Vector2(80, 576)
	next_btn.size = Vector2(200, 50)
	next_btn.add_theme_font_override("font", font_black)
	next_btn.add_theme_font_size_override("font_size", 18)
	for k in ["normal", "hover", "pressed"]:
		next_btn.add_theme_stylebox_override(k, _pill(Color("ff8a5b"), 25))
	next_btn.add_theme_color_override("font_color", Color.WHITE)
	next_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	next_btn.pressed.connect(_next)
	add_child(next_btn)

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
		main.go("morning")
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
	if h.id == "kirari":
		sfx["sparkle"].play()
	Input.vibrate_handheld(60)
	burst.position = orb.position
	burst.restart()
	burst.emitting = true
	orb.queue_free()
	current_obake = Obake3D.make(h.id)
	current_obake.position = Vector3(0, 0.55, 0.3)
	current_obake.scale = Vector3.ONE * 0.05
	world.add_child(current_obake)
	var tw3 := create_tween()
	tw3.tween_property(current_obake, "scale", Vector3.ONE * 0.5, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await tw3.finished
	sfx["chime"].play()
	var sp: Dictionary = GameState.info(h.id)
	card_title.text = sp.name
	badge.get_parent().visible = h.is_new
	card_sub.text = ("レア ・ %s" % sp.group) if Rares.is_rare(h.id) else ("Lv%d ・ %s" % [h.level, _type_label(sp.type)])
	var u: Dictionary = DefData.unit(h.id)
	card_desc.text = sp.desc
	if not u.is_empty():
		card_desc.text += "\n戦いでは：" + (u.skill if u.has("skill") else "%s。%s" % [u.role, u.line])
	# 新しい仲間が編成に入っていなければ、ここで入れられる（いっぱいなら最後の一体と入れかえ）
	if deck_btn:
		deck_btn.queue_free()
		deck_btn = null
	if not u.is_empty() and not h.id in GameState.deck:
		var last: String = GameState.deck[GameState.deck.size() - 1] if GameState.deck.size() >= GameState.DECK_MAX else ""
		deck_btn = Kit.button(("%sと入れかえて編成する" % GameState.info(last).name) if last != "" else "編成に入れる", Color("8b7bff"), func():
			if last != "":
				GameState.toggle_deck(last)
			GameState.toggle_deck(h.id)
			deck_btn.disabled = true
			deck_btn.text = "編成に入れた", Color.WHITE, 36, 13)
		card.get_child(0).add_child(deck_btn)
	card.size = Vector2(312, 0)
	await get_tree().process_frame
	var final_y: float = 566.0 - card.get_combined_minimum_size().y
	card.position.y = final_y + 30
	var tw4 := create_tween().set_parallel()
	tw4.tween_property(card, "modulate:a", 1.0, 0.25)
	tw4.tween_property(card, "position:y", final_y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	index += 1
	next_btn.text = "つぎの玉" if index < orbs.size() else "今日をはじめる"
	next_btn.disabled = false
	busy = false


func _type_label(t: String) -> String:
	return {"register": "レジの経験", "dish": "皿洗いの経験", "hall": "ホールの経験", "kitchen": "キッチンの経験", "stock": "品出しの経験", "night": "夜ふかし", "rare": "はじめての経験", "sleep": "よく眠った朝"}.get(t, "")


func _flash(a: float) -> void:
	flash.modulate.a = a
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.5)


func demo_open() -> void:
	_next()
