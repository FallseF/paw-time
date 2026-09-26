extends Control
## 3D の捕獲。網を指で持ち上げて、おばけに向けてスワイプで投げる。
## 縮む輪の中に当てるほど捕まりやすい。網がかかると3回揺れて、結果が出る。

var main

const REST_SCREEN := Vector2(180, 560)
const NET_DEPTH := 2.3
const GRAVITY := 5.5
const RING_PERIOD := 1.8

var vp: SubViewport
var cam: Camera3D
var world: Node3D
var obake: Obake3D
var obake_home := Vector3(0, 0.75, 0)
var net: Node3D
var net_vel := Vector3.ZERO
var state := "aim" # aim / drag / flying / capture / result
var drag_points: Array = [] # [pos, time]
var ring_t := 0.0
var overlay: Control
var name_pill: Label
var hint: Label
var stamina_pill: Label
var net_btn: Button
var banner: Label
var flash: ColorRect
var selected_net := ""
var font_bold: FontFile
var font_black: FontFile
var hop_timer := 2.5
var particles: CPUParticles3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	font_bold = load("res://assets/fonts/ZenMaruGothic-Bold.ttf")
	font_black = load("res://assets/fonts/ZenMaruGothic-Black.ttf")
	_build_world()
	_build_ui()
	_pick_net()
	_spawn(_pick_species())
	_reset_net()


# ---------- 3D の世界 ----------

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
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("3b4fb0")
	sm.sky_horizon_color = Color("ffb08a")
	sm.ground_horizon_color = Color("e9a07e")
	sm.ground_bottom_color = Color("3a4a5a")
	sm.sun_angle_max = 10.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = false
	env.glow_enabled = false
	env.fog_enabled = true
	env.fog_light_color = Color("ffb08a")
	env.fog_density = 0.012
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 35, 0)
	sun.light_color = Color("fff0e0")
	sun.light_energy = 0.55
	sun.shadow_enabled = true
	world.add_child(sun)

	cam = Camera3D.new()
	cam.position = Vector3(0, 1.25, 3.4)
	cam.fov = 55
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.95, 0))

	# 地面（夕方の公園）
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("4f9a4a")
	gm.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	ground.material_override = gm
	world.add_child(ground)
	# 足元の円（おばけの立ち位置）
	var pad := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.6
	disc.bottom_radius = 0.6
	disc.height = 0.01
	pad.mesh = disc
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(1, 1, 1, 0.14)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pad.material_override = pm
	pad.position = Vector3(0, 0.01, 0)
	world.add_child(pad)

	# 木と街灯
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 26:
		var x := rng.randf_range(-12, 12)
		var z := rng.randf_range(-16, -3)
		if absf(x) < 2.0 and z > -5:
			continue
		_tree(Vector3(x, 0, z), rng.randf_range(0.8, 1.6))
	for x in [-3.2, 3.4]:
		_lamp(Vector3(x, 0, -2.5))

	# ほたる
	var flies := CPUParticles3D.new()
	flies.amount = 40
	flies.lifetime = 6.0
	flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flies.emission_box_extents = Vector3(5, 1.2, 4)
	flies.position = Vector3(0, 1.4, -3)
	flies.gravity = Vector3(0, 0.05, 0)
	flies.initial_velocity_min = 0.05
	flies.initial_velocity_max = 0.2
	flies.direction = Vector3(0, 1, 0)
	flies.spread = 180
	var fm := SphereMesh.new()
	fm.radius = 0.025
	fm.height = 0.05
	flies.mesh = fm
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.albedo_color = Color("fff2a8")
	fmat.emission_enabled = true
	fmat.emission = Color("fff2a8")
	fmat.emission_energy_multiplier = 3.0
	flies.material_override = fmat
	world.add_child(flies)

	# 捕まえたときの星
	particles = CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = 30
	particles.lifetime = 0.9
	particles.explosiveness = 1.0
	particles.direction = Vector3(0, 1, 0)
	particles.spread = 180
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 3.0
	particles.gravity = Vector3(0, -3, 0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2
	var pmesh := SphereMesh.new()
	pmesh.radius = 0.04
	pmesh.height = 0.08
	particles.mesh = pmesh
	particles.material_override = fmat
	world.add_child(particles)

	net = _make_net()
	world.add_child(net)


func _tree(at: Vector3, s: float) -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.08 * s
	trunk.bottom_radius = 0.12 * s
	trunk.height = 0.8 * s
	var t := MeshInstance3D.new()
	t.mesh = trunk
	t.material_override = Obake3D.toon(Color("8a5a3a"), 0.1)
	t.position = at + Vector3(0, 0.4 * s, 0)
	world.add_child(t)
	var crown := SphereMesh.new()
	crown.radius = 0.6 * s
	crown.height = 1.1 * s
	var c := MeshInstance3D.new()
	c.mesh = crown
	c.material_override = Obake3D.toon(Color("4f8a5b").lerp(Color("6aa86a"), randf()), 0.3)
	c.position = at + Vector3(0, 1.2 * s, 0)
	world.add_child(c)


func _lamp(at: Vector3) -> void:
	var pole := CylinderMesh.new()
	pole.top_radius = 0.04
	pole.bottom_radius = 0.05
	pole.height = 2.6
	var p := MeshInstance3D.new()
	p.mesh = pole
	p.material_override = Obake3D.toon(Color("3a3440"), 0.1)
	p.position = at + Vector3(0, 1.3, 0)
	world.add_child(p)
	var bulb := SphereMesh.new()
	bulb.radius = 0.16
	bulb.height = 0.32
	var b := MeshInstance3D.new()
	b.mesh = bulb
	b.material_override = Obake3D.toon(Color("ffe3a0"), 0.2, 3.0)
	b.position = at + Vector3(0, 2.65, 0)
	world.add_child(b)
	var light := OmniLight3D.new()
	light.light_color = Color("ffcf8a")
	light.light_energy = 1.6
	light.omni_range = 4.0
	light.position = at + Vector3(0, 2.5, 0)
	world.add_child(light)


func _make_net() -> Node3D:
	var n := Node3D.new()
	var rim := TorusMesh.new()
	rim.inner_radius = 0.2
	rim.outer_radius = 0.24
	var r := MeshInstance3D.new()
	r.mesh = rim
	r.name = "Rim"
	r.rotation_degrees = Vector3(90, 0, 0)
	n.add_child(r)
	var film := CylinderMesh.new()
	film.top_radius = 0.21
	film.bottom_radius = 0.21
	film.height = 0.005
	var f := MeshInstance3D.new()
	f.mesh = film
	f.rotation_degrees = Vector3(90, 0, 0)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1, 1, 1, 0.35)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	f.material_override = fm
	n.add_child(f)
	var handle := CylinderMesh.new()
	handle.top_radius = 0.025
	handle.bottom_radius = 0.03
	handle.height = 0.4
	var h := MeshInstance3D.new()
	h.mesh = handle
	h.material_override = Obake3D.toon(Color("b07a4a"), 0.1)
	h.position = Vector3(0, -0.42, 0)
	n.add_child(h)
	return n


func _net_color(id: String) -> Color:
	return {"receipt": Color("f4f1ea"), "bubble": Color("8fd3ff"), "tray": Color("c9b6ff"), "pan": Color("ff9e6b"), "box": Color("e0b27a"), "kira": Color("ffd84d")}.get(id, Color.WHITE)


func _paint_net() -> void:
	var rim: MeshInstance3D = net.get_node("Rim")
	rim.material_override = Obake3D.toon(_net_color(selected_net), 0.5, 0.8 if selected_net == "kira" else 0.0)


# ---------- UI ----------

func _pill(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(22)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.18)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	return s


func _text(t: String, size: int, color := Color("2e222f"), font: FontFile = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font if font else font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _build_ui() -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)

	var top := HBoxContainer.new()
	top.position = Vector2(14, 16)
	top.size = Vector2(332, 44)
	top.clip_contents = true
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	var run := Button.new()
	run.text = "✕"
	run.custom_minimum_size = Vector2(44, 44)
	run.add_theme_font_override("font", font_bold)
	run.add_theme_font_size_override("font_size", 18)
	for k in ["normal", "hover", "pressed"]:
		run.add_theme_stylebox_override(k, _pill(Color(1, 1, 1, 0.85)))
	run.add_theme_color_override("font_color", Color("2e222f"))
	run.pressed.connect(func(): main.go("sleep"))
	top.add_child(run)
	var np := PanelContainer.new()
	np.add_theme_stylebox_override("panel", _pill(Color(1, 1, 1, 0.9)))
	np.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_pill = _text("", 15)
	name_pill.clip_text = true
	np.add_child(name_pill)
	top.add_child(np)
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", _pill(Color("2e222f", 0.75)))
	stamina_pill = _text("", 15, Color("ffe27a"))
	sp.add_child(stamina_pill)
	top.add_child(sp)

	hint = _text("網を上にはじいて投げる", 15, Color.WHITE)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	hint.add_theme_constant_override("outline_size", 5)
	hint.position = Vector2(0, 430)
	hint.size = Vector2(360, 24)
	add_child(hint)

	net_btn = Button.new()
	net_btn.position = Vector2(284, 560)
	net_btn.size = Vector2(62, 62)
	net_btn.add_theme_font_override("font", font_bold)
	net_btn.add_theme_font_size_override("font_size", 13)
	net_btn.add_theme_color_override("font_color", Color("2e222f"))
	net_btn.pressed.connect(_cycle_net)
	add_child(net_btn)

	banner = _text("", 40, Color.WHITE, font_black)
	banner.add_theme_color_override("font_outline_color", Color("2e222f"))
	banner.add_theme_constant_override("outline_size", 10)
	banner.position = Vector2(0, 170)
	banner.size = Vector2(360, 120)
	banner.pivot_offset = Vector2(180, 60)
	banner.modulate.a = 0.0
	add_child(banner)

	flash = ColorRect.new()
	flash.color = Color.WHITE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate.a = 0.0
	add_child(flash)


func _refresh_ui() -> void:
	var sp: Dictionary = GameState.info(obake.species)
	var good := ""
	for nid in GameState.NETS:
		if GameState.NETS[nid].type == sp.type:
			good = "・%sが効く" % GameState.NETS[nid].name
	name_pill.text = "%s  %s" % [sp.name, good.trim_prefix("・")]
	stamina_pill.text = "⚡%d" % GameState.stamina
	var n: int = GameState.nets.get(selected_net, 0)
	net_btn.text = "\n\n\n%s\n×%d" % [GameState.NETS[selected_net].name.replace("網", ""), n] if selected_net != "" else "網なし"
	var st := _pill(_net_color(selected_net) if selected_net != "" else Color("cccccc"))
	st.set_corner_radius_all(31)
	for k in ["normal", "hover", "pressed"]:
		net_btn.add_theme_stylebox_override(k, st)
	if selected_net != "":
		_paint_net()


func _pick_net() -> void:
	selected_net = ""
	for id in GameState.nets:
		if GameState.nets[id] > 0:
			selected_net = id
			break


func _cycle_net() -> void:
	var ids: Array = GameState.NETS.keys()
	var start := ids.find(selected_net)
	for i in range(1, ids.size() + 1):
		var id: String = ids[(start + i) % ids.size()]
		if GameState.nets.get(id, 0) > 0:
			selected_net = id
			break
	_refresh_ui()


# ---------- おばけ ----------

func _pick_species() -> String:
	var r := randf()
	return ["receipt", "bubble", "tray", "pan", "box"].pick_random()


func _spawn(id: String) -> void:
	if obake:
		obake.queue_free()
	obake = Obake3D.new().setup(id)
	obake.position = obake_home
	obake.rotation.y = 0
	obake.scale = Vector3.ONE * 0.01
	world.add_child(obake)
	var tw := create_tween()
	tw.tween_property(obake, "scale", Vector3.ONE * 0.62, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ring_t = 0.0
	hop_timer = randf_range(2.0, 3.5)
	_refresh_ui()


# ---------- 入力：網を持ってスワイプ ----------

func _reset_net() -> void:
	state = "aim"
	net.visible = selected_net != ""
	net.position = cam.project_position(REST_SCREEN, NET_DEPTH)
	net.rotation = Vector3.ZERO
	net.scale = Vector3.ONE * 0.75
	hint.text = "網を上にはじいて投げる" if selected_net != "" else "網がない。シフトで網をもらおう"


func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var down := false
	var up := false
	var motion := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		down = event.pressed
		up = not event.pressed
	elif event is InputEventScreenTouch:
		pos = event.position
		down = event.pressed
		up = not event.pressed
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		pos = event.position
		motion = true
	else:
		return

	if state == "aim" and down and pos.distance_to(REST_SCREEN) < 90:
		if GameState.stamina <= 0:
			_banner("元気切れ… 寝よう", Color("ffb3a8"))
			return
		if selected_net == "" or GameState.nets.get(selected_net, 0) <= 0:
			_banner("網がない", Color("ffb3a8"))
			return
		state = "drag"
		drag_points = [[pos, Time.get_ticks_msec() / 1000.0]]
	elif state == "drag" and motion:
		drag_points.append([pos, Time.get_ticks_msec() / 1000.0])
		if drag_points.size() > 8:
			drag_points.pop_front()
		net.position = cam.project_position(pos, NET_DEPTH)
		net.rotation.z = clampf((pos.x - REST_SCREEN.x) * 0.004, -0.5, 0.5)
	elif state == "drag" and up:
		_throw(pos)


func _throw(pos: Vector2) -> void:
	drag_points.append([pos, Time.get_ticks_msec() / 1000.0])
	var a: Array = drag_points[0]
	var b: Array = drag_points[-1]
	var dt: float = max(0.016, b[1] - a[1])
	var v: Vector2 = (b[0] - a[0]) / dt
	if v.y > -350:
		# 弱い／下向き：網を戻す
		var tw := create_tween()
		tw.tween_property(net, "position", cam.project_position(REST_SCREEN, NET_DEPTH), 0.2)
		state = "aim"
		return
	GameState.use_net(selected_net)
	_refresh_ui()
	var power := clampf(-v.y / 1400.0, 0.45, 1.3)
	net_vel = Vector3(v.x * 0.0022, 2.3 * power + 0.6, -5.2 * power - 0.6)
	state = "flying"
	hint.text = ""


# ---------- 毎フレーム ----------

func _process(delta: float) -> void:
	ring_t = fmod(ring_t + delta, RING_PERIOD)
	if state == "flying":
		net_vel.y -= GRAVITY * delta
		net.position += net_vel * delta
		net.rotation.x -= delta * 6.0
		if net.position.z <= obake.position.z + 0.1:
			_check_hit()
		elif net.position.y < -0.5:
			_miss("はずれ…")
	elif state in ["aim", "drag"]:
		hop_timer -= delta
		if hop_timer <= 0:
			_hop()
	overlay.queue_redraw()


func _hop() -> void:
	hop_timer = randf_range(1.8, 3.2)
	var to := obake_home + Vector3(randf_range(-0.7, 0.7), randf_range(0, 0.35), 0)
	var tw := create_tween()
	tw.tween_property(obake, "position", to, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _ring_ratio() -> float:
	# 1.0 → 0.3 に縮んで、また戻る
	return lerpf(1.0, 0.3, ring_t / RING_PERIOD)


func _obake_screen() -> Array:
	var c: Vector3 = obake.position + Vector3(0, 0.36, 0)
	var sc := cam.unproject_position(c)
	var edge := cam.unproject_position(c + Vector3(0.36, 0, 0))
	return [sc, sc.distance_to(edge)]


func _chance_color(chance: float) -> Color:
	if chance > 0.5:
		return Color("7bdc6b")
	if chance > 0.25:
		return Color("ffd23f")
	return Color("ff6b5b")


func _draw_overlay() -> void:
	if not obake or state in ["capture", "result"]:
		return
	var o := _obake_screen()
	var c: Vector2 = o[0]
	var r: float = o[1] * 1.25
	overlay.draw_arc(c, r, 0, TAU, 64, Color(1, 1, 1, 0.9), 3.0, true)
	var base := GameState.catch_chance(obake.species, selected_net, 1.0) if selected_net != "" else 0.0
	overlay.draw_arc(c, r * _ring_ratio(), 0, TAU, 64, _chance_color(base), 4.0, true)


func _check_hit() -> void:
	var o := _obake_screen()
	var c: Vector2 = o[0]
	var body_r: float = o[1]
	var p := cam.unproject_position(net.position)
	var d := p.distance_to(c)
	if d > body_r * 1.35:
		_miss("おしい！")
		return
	var ratio := _ring_ratio()
	var ring_r: float = body_r * 1.25 * ratio
	var timing := 1.0
	var words := ""
	if d <= ring_r:
		if ratio < 0.5:
			timing = 1.8
			words = "すばらしい！"
		elif ratio < 0.8:
			timing = 1.4
			words = "いいね！"
		else:
			timing = 1.15
			words = "ナイス！"
	_capture(timing, words)


func _miss(words: String) -> void:
	state = "result"
	_banner(words, Color.WHITE)
	var tw := create_tween()
	tw.tween_property(net, "scale", Vector3.ZERO, 0.25)
	await tw.finished
	_after_turn()


# ---------- 捕獲の演出 ----------

func _capture(timing: float, words: String) -> void:
	state = "capture"
	var chance := GameState.catch_chance(obake.species, selected_net, timing)
	if words != "":
		_banner(words, Color("fff2a8"))
	var target: Vector3 = obake.position + Vector3(0, 0.36, 0)
	var tw := create_tween().set_parallel()
	tw.tween_property(net, "position", target, 0.12)
	tw.tween_property(net, "rotation", Vector3.ZERO, 0.12)
	await tw.finished
	_flash(0.6)
	obake.bob = false
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(obake, "scale", Vector3.ONE * 0.05, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw2.tween_property(obake, "position", target, 0.3)
	tw2.tween_property(net, "scale", Vector3.ONE * 1.3, 0.15)
	await tw2.finished
	obake.visible = false
	# 地面に落ちてはねる
	var ground_pos := Vector3(target.x, 0.26, target.z + 0.3)
	var tw3 := create_tween()
	tw3.tween_property(net, "position", ground_pos, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw3.parallel().tween_property(net, "scale", Vector3.ONE, 0.35)
	await tw3.finished
	# 3回揺れる
	var per_shake := pow(chance, 1.0 / 3.0)
	for i in 3:
		await get_tree().create_timer(0.45).timeout
		var tw4 := create_tween()
		tw4.tween_property(net, "rotation:z", 0.4, 0.12)
		tw4.tween_property(net, "rotation:z", -0.4, 0.18)
		tw4.tween_property(net, "rotation:z", 0.0, 0.12)
		await tw4.finished
		if randf() > per_shake:
			_escape(ground_pos)
			return
	_caught(ground_pos)


func _escape(at: Vector3) -> void:
	state = "result"
	_flash(0.4)
	obake.visible = true
	obake.position = at
	obake.bob = true
	var tw := create_tween().set_parallel()
	tw.tween_property(obake, "scale", Vector3.ONE * 0.62, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(obake, "position", obake_home, 0.4)
	tw.tween_property(net, "scale", Vector3.ZERO, 0.2)
	_banner("出てきちゃった！", Color("ffb3a8"))
	await tw.finished
	_after_turn()


func _caught(at: Vector3) -> void:
	state = "result"
	var is_new := GameState.add_obake(obake.species)
	particles.position = at
	particles.restart()
	particles.emitting = true
	_banner("つかまえた！\n%s%s" % [GameState.info(obake.species).name, "  NEW" if is_new else ""], Color("fff2a8"))
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(net, "scale", Vector3.ZERO, 0.3)
	await tw.finished
	await get_tree().create_timer(0.8).timeout
	_spawn(_pick_species())
	_after_turn()


func _after_turn() -> void:
	if GameState.nets.get(selected_net, 0) <= 0:
		_pick_net()
	_refresh_ui()
	_reset_net()


func _banner(text: String, color: Color) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.modulate.a = 1.0
	banner.scale = Vector2(0.4, 0.4)
	var tw := create_tween()
	tw.tween_property(banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(banner, "modulate:a", 0.0, 0.3)


func _flash(a: float) -> void:
	flash.modulate.a = a
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.3)


# ---------- 確認用 ----------

func demo_throw() -> void:
	# 網を投げて、輪の中に当たる直前の状態を作る
	state = "flying"
	net.position = obake.position + Vector3(0.05, 0.4, 0.9)
	net_vel = Vector3(0, 0.6, -3.0)
	ring_t = RING_PERIOD * 0.7
