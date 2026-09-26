extends Control
## 満月の夜（週に一度、日曜の夜）。この一週間のよく眠れた夜の数だけ、月見の灯りがともる。
## 灯りを自分でタップしてともすと、その数だけ月が満ちていく。4 つ以上で満月（ツキミが来る・虹の玉）。

var main

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var moon: MeshInstance3D
var shade: MeshInstance3D
var moon_light: OmniLight3D
var lanterns: Array = [] # {node, lamp, good, lit, light}
var lit := 0
var good_total := 0
var header: Label
var hint: Label
var done := false
var burst: CPUParticles3D
var obs: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_world()
	header = Kit.text("満月の夜", 26, Color("fff6e8"), true, HORIZONTAL_ALIGNMENT_CENTER)
	header.add_theme_color_override("font_outline_color", Color("0b1026"))
	header.add_theme_constant_override("outline_size", 10)
	header.position = Vector2(0, 26)
	header.size = Vector2(360, 40)
	add_child(header)
	hint = Kit.wrap(Kit.text("よく眠れた夜の灯りを、タップしてともそう", 15, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER))
	hint.add_theme_color_override("font_outline_color", Color("0b1026"))
	hint.add_theme_constant_override("outline_size", 8)
	hint.position = Vector2(20, 70)
	hint.size = Vector2(320, 50)
	add_child(hint)
	var days := Kit.text("月　火　水　木　金　土", 12, Color(1, 1, 1, 0.5), false, HORIZONTAL_ALIGNMENT_CENTER)
	days.position = Vector2(0, 470)
	days.size = Vector2(360, 20)
	add_child(days)
	if good_total == 0:
		hint.text = "今週は、よく眠れた夜がなかった…"
		await get_tree().create_timer(1.5).timeout
		_finish()


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
	env.background_color = Color("0e1330")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("4a5498")
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.glow_intensity = 1.0
	env.glow_hdr_threshold = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 160, 0)
	sun.light_color = Color("aab8ff")
	sun.light_energy = 0.6
	world.add_child(sun)
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.position = Vector3(0, 2.0, 6.4)
	cam.fov = 58
	world.add_child(cam)
	cam.look_at(Vector3(0, 1.6, 0))

	var g := MeshInstance3D.new()
	var gm := PlaneMesh.new()
	gm.size = Vector2(30, 30)
	g.mesh = gm
	g.material_override = Obake3D.toon(Color("2f4a3a"), 0.05)
	world.add_child(g)
	# すすき
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 30:
		var s := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.03
		cm.height = rng.randf_range(0.6, 1.1)
		s.mesh = cm
		s.material_override = Obake3D.toon(Color("c9b36b"), 0.2)
		s.position = Vector3(rng.randf_range(-4, 4), cm.height / 2, rng.randf_range(-2.5, -1.2))
		s.rotation.z = rng.randf_range(-0.3, 0.3)
		world.add_child(s)

	# 月（影の球をずらして、満ち欠けを作る）
	moon = MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 1.0
	mm.height = 2.0
	moon.mesh = mm
	moon.material_override = Kit.glow(Color("fff1c8"), 2.4)
	moon.position = Vector3(0, 4.4, -6)
	world.add_child(moon)
	shade = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.02
	sm.height = 2.04
	shade.mesh = sm
	shade.material_override = Kit.glow(Color("0e1330"), 0.0)
	shade.position = moon.position + Vector3(-0.3, 0, 0.5)
	world.add_child(shade)
	moon_light = OmniLight3D.new()
	moon_light.light_color = Color("fff1c8")
	moon_light.light_energy = 0.0
	moon_light.omni_range = 12
	moon_light.position = Vector3(0, 3, 1)
	world.add_child(moon_light)

	# 6 つの灯り（直近 6 夜）
	var goods: Array = GameState.moon_lanterns()
	for i in 6:
		var n := Node3D.new()
		var a := lerpf(-2.6, 2.6, i / 5.0)
		n.position = Vector3(a, 0, 0.6 - absf(a) * 0.25)
		world.add_child(n)
		var post := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.14, 0.6, 0.14)
		post.mesh = pb
		post.position.y = 0.3
		post.material_override = Obake3D.toon(Color("6b6f7e"), 0.1)
		n.add_child(post)
		var lamp := MeshInstance3D.new()
		var lb := BoxMesh.new()
		lb.size = Vector3(0.3, 0.3, 0.3)
		lamp.mesh = lb
		lamp.position.y = 0.75
		var good: bool = goods[i]
		lamp.material_override = Obake3D.toon(Color("8a7a60") if good else Color("4a4658"), 0.2)
		n.add_child(lamp)
		var l := OmniLight3D.new()
		l.light_color = Color("ffc070")
		l.light_energy = 0.0
		l.omni_range = 2.0
		l.position.y = 0.8
		n.add_child(l)
		lanterns.append({"node": n, "lamp": lamp, "good": good, "lit": false, "light": l})
		if good:
			good_total += 1
			var tw := n.create_tween().set_loops()
			tw.tween_property(lamp, "scale", Vector3.ONE * 1.12, 0.5).set_trans(Tween.TRANS_SINE)
			tw.tween_property(lamp, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_SINE)
			lanterns[-1]["pulse"] = tw
	# 仲間のおばけ（最大 8 体）
	var ids: Array = []
	for o in GameState.owned:
		ids.append(o.id)
	ids.shuffle()
	for i in min(8, ids.size()):
		var o := Obake3D.make(ids[i])
		o.scale = Vector3.ONE * 0.42
		o.position = Vector3(lerpf(-1.8, 1.8, i / 7.0) if ids.size() > 1 else 0.0, 0, 1.8 + (i % 2) * 0.35)
		o.rotation.y = PI # 月を見上げる（背中をこちらに）
		world.add_child(o)
		obs.append(o)

	burst = CPUParticles3D.new()
	burst.emitting = false
	burst.one_shot = true
	burst.amount = 80
	burst.lifetime = 1.8
	burst.explosiveness = 0.9
	burst.spread = 180
	burst.initial_velocity_min = 1.5
	burst.initial_velocity_max = 3.2
	burst.gravity = Vector3(0, -0.8, 0)
	var bm := SphereMesh.new()
	bm.radius = 0.04
	bm.height = 0.08
	burst.mesh = bm
	burst.material_override = Kit.glow(Color("fff2a8"), 3.0)
	world.add_child(burst)
	_set_phase(0.0)


## 0 = 新月寄り、1 = 満月
func _set_phase(p: float) -> void:
	shade.position = moon.position + Vector3(lerpf(-0.9, -2.3, p), 0, 0.4)
	moon_light.light_energy = p * 1.6


func _gui_input(event: InputEvent) -> void:
	if done:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var pos: Vector2 = event.position
	for L in lanterns:
		if L.lit or not L.good:
			continue
		var sp := cam.unproject_position(L.lamp.global_position)
		if sp.distance_to(pos) < 40:
			_light(L)
			return


func _light(L: Dictionary) -> void:
	L.lit = true
	lit += 1
	if L.has("pulse"):
		L.pulse.kill()
	L.lamp.scale = Vector3.ONE
	L.lamp.material_override = Kit.glow(Color("ffcf7a"), 2.6)
	create_tween().tween_property(L.light, "light_energy", 1.8, 0.3)
	Kit.play(self, "bell", 0.9 + lit * 0.08)
	burst.position = L.lamp.global_position
	burst.amount = 30
	burst.restart()
	burst.emitting = true
	var tw := create_tween()
	tw.tween_method(_set_phase, (lit - 1) / 6.0 * 1.5, min(1.0, lit / 4.0), 0.6).set_trans(Tween.TRANS_SINE)
	if lit >= good_total:
		await tw.finished
		_finish()


func _finish() -> void:
	if done:
		return
	done = true
	var res := GameState.finish_moon(lit, 0)
	if res.won:
		hint.text = ""
		header.text = "満月！"
		Kit.play(self, "sparkle")
		Kit.play(self, "grow")
		burst.position = moon.global_position
		burst.amount = 80
		burst.restart()
		burst.emitting = true
		var tw := create_tween()
		tw.tween_method(_set_phase, 0.8, 1.0, 0.8)
		for o in obs:
			var t2: Tween = o.create_tween()
			t2.tween_interval(randf() * 0.4)
			t2.tween_property(o, "position:y", 0.5, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t2.tween_property(o, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	else:
		header.text = "月は、まだ半分"
		hint.text = "よく眠れた夜が4つあれば、満月になる"
	await get_tree().create_timer(1.2).timeout
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color(1, 0.99, 0.96, 0.95), 24, 0.25, Vector2(18, 14)))
	p.position = Vector2(30, 440)
	p.size = Vector2(300, 0)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(Kit.text("灯り %d / 6" % lit, 20, Color("2a2233"), true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Kit.text("月の玉 ×%d%s" % [res.orbs, "（虹の玉つき）" if res.won else ""], 15, Color("6a5bd6"), true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Kit.text("庭のめぐみ +%d" % res.growth, 14, Color("3f7d4f"), true, HORIZONTAL_ALIGNMENT_CENTER))
	if res.won:
		v.add_child(Kit.wrap(Kit.text("満月の朝には、めずらしいおばけが来るかもしれない", 12, Color("8a5bd6"), false, HORIZONTAL_ALIGNMENT_CENTER)))
	v.add_child(Kit.button("寝る", Color("8b7bff"), func(): main.go("sleep")))
	p.pivot_offset = Vector2(150, 80)
	p.scale = Vector2(0.7, 0.7)
	create_tween().tween_property(p, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func demo_light_all() -> void:
	for L in lanterns:
		if L.good and not L.lit:
			_light(L)
			await get_tree().create_timer(0.5).timeout
