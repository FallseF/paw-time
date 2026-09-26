extends Control
## タイトル。夜の水面に玉がただよい、おばけが顔を出す。つづきから／はじめから。

var main

var font_bold: FontFile
var font_black: FontFile
var world: Node3D
var orbs: Array = []
var _t := 0.0
var confirm: Control


func _ready() -> void:
	font_bold = load("res://assets/fonts/ZenMaruGothic-Bold.ttf")
	font_black = load("res://assets/fonts/ZenMaruGothic-Black.ttf")
	_build_world()
	var title := _text("おばけの休憩室", 38, Color("fff6e8"), font_black)
	title.add_theme_color_override("font_outline_color", Color("0b1026"))
	title.add_theme_constant_override("outline_size", 12)
	title.position = Vector2(0, 92)
	title.size = Vector2(360, 56)
	add_child(title)
	var sub := _text("すくって、かえして、あつめる", 16, Color("ffe7a8"))
	sub.position = Vector2(0, 148)
	sub.size = Vector2(360, 26)
	add_child(sub)
	var tag := _text("働いた日は、ポイが増える。\nよく寝た朝は、玉がよくかえる。", 13, Color(1, 1, 1, 0.7))
	tag.position = Vector2(0, 180)
	tag.size = Vector2(360, 44)
	add_child(tag)

	var v := VBoxContainer.new()
	v.position = Vector2(50, 450)
	v.size = Vector2(260, 160)
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var has_save: bool = GameState.has_save() and GameState.records.nights > 0
	if has_save:
		var info := _text("図鑑 %d/%d ・ %s" % [GameState.seen.size(), GameState.ALL.size(), GameState.title_name()], 13, Color(1, 1, 1, 0.75))
		v.add_child(info)
		v.add_child(_button("つづきから（第%d週 %s曜）" % [GameState.week_no(), GameState.dow()], Color("ff8a5b"), _continue))
		v.add_child(_button("はじめから", Color(1, 1, 1, 0.9), _ask_reset, Color("5b6fc2")))
	else:
		v.add_child(_button("はじめる", Color("ff8a5b"), _continue))
	var demo := _button("デモ：3週間すすめた状態で遊ぶ", Color(1, 1, 1, 0.14), _demo, Color(1, 1, 1, 0.8))
	demo.custom_minimum_size = Vector2(0, 36)
	demo.add_theme_font_size_override("font_size", 12)
	v.add_child(demo)


func _build_world() -> void:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b1026")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("5a6aaa")
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 1.1
	env.glow_hdr_threshold = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -30, 0)
	sun.light_color = Color("c8d4ff")
	sun.light_energy = 0.5
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.6, 4.2)
	cam.fov = 48
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.3, 0))
	var water := MeshInstance3D.new()
	var wp := PlaneMesh.new()
	wp.size = Vector2(40, 40)
	water.mesh = wp
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/water.gdshader")
	water.material_override = wm
	world.add_child(water)
	var moon := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 1.4
	mm.height = 2.8
	moon.mesh = mm
	var mmat := StandardMaterial3D.new()
	mmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mmat.albedo_color = Color("fff1c8")
	mmat.emission_enabled = true
	mmat.emission = Color("fff1c8")
	mmat.emission_energy_multiplier = 1.6
	moon.material_override = mmat
	moon.position = Vector3(3.2, 6.5, -14)
	world.add_child(moon)
	var stars := CPUParticles3D.new()
	stars.amount = 160
	stars.lifetime = 100.0
	stars.preprocess = 100.0
	stars.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	stars.emission_box_extents = Vector3(18, 6, 1)
	stars.position = Vector3(0, 6, -16)
	stars.gravity = Vector3.ZERO
	stars.initial_velocity_max = 0.0
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.07
	stars.mesh = sm
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.albedo_color = Color("dfe6ff")
	stars.material_override = smat
	world.add_child(stars)
	var ids := ["receipt", "bubble", "tray"]
	for i in 3:
		var o := Obake3D.make(ids[i])
		o.scale = Vector3.ONE * 0.5
		o.position = Vector3((i - 1) * 0.9, -0.05, 0.3 - absf(i - 1) * 0.4)
		o.rotation.y = (1 - i) * 0.3
		world.add_child(o)
	var types := ["register", "dish", "hall", "kitchen", "stock", "rare"]
	for i in 7:
		var t: String = types[i % types.size()]
		var ob := Orb3D.new().setup({"type": t, "kind": "rainbow" if t == "rare" else "normal"})
		ob.position = Vector3(randf_range(-1.8, 1.8), 0, randf_range(-1.2, 1.4))
		world.add_child(ob)
		orbs.append(ob)


func _process(delta: float) -> void:
	_t += delta
	for i in orbs.size():
		var o: Orb3D = orbs[i]
		o.position.x += sin(_t * 0.4 + i) * 0.1 * delta
		o.position.z += cos(_t * 0.3 + i * 2.0) * 0.1 * delta


func _text(t: String, size: int, color := Color.WHITE, font: FontFile = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font if font else font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _pill(bg: Color, radius := 24) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	return s


func _button(t: String, bg: Color, cb: Callable, fg := Color.WHITE) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_override("font", font_black)
	b.add_theme_font_size_override("font_size", 17)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, _pill(bg if k != "pressed" else bg.darkened(0.1)))
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.pressed.connect(cb)
	return b


func _continue() -> void:
	# 朝の玉をまだ開けていなければ、朝から
	if GameState.phase == "morning" and GameState.hatched.size() > 0:
		main.go("hatch")
	else:
		main.go("room")


func _ask_reset() -> void:
	if confirm:
		return
	confirm = PanelContainer.new()
	confirm.add_theme_stylebox_override("panel", _pill(Color(1, 0.98, 0.95, 0.97)))
	confirm.position = Vector2(30, 250)
	confirm.size = Vector2(300, 0)
	add_child(confirm)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	confirm.add_child(v)
	v.add_child(_text("図鑑もポイも、最初からになる", 15, Color("2a2233")))
	v.add_child(_button("はじめからにする", Color("e85a4f"), func():
		GameState.wipe_save()
		main.go("room")))
	v.add_child(_button("やめる", Color(1, 1, 1), func():
		confirm.queue_free()
		confirm = null, Color("5b6fc2")))


func _demo() -> void:
	# デモはセーブを上書きしない（本当の進み具合はそのまま残る）
	GameState.demo_mode = true
	GameState.reset()
	GameState.fast_forward(20)
	main.go("room")
