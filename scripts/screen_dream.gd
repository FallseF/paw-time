extends Control
## 夢：羊かぞえ。よく眠った夜（リズムが整っているとき）だけ見る夢。
## おばけが柵を跳びこえる。ちょうど柵の上に来たときにタップすると「かぞえた」。
## たまに羊じゃないおばけがまぎれる（それはかぞえない）。かぞえた数だけスヤリの玉と庭のめぐみ。

var main

const TOTAL := 12
const SPEED := 1.9
const ARC := 0.75

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var sheep: Array = [] # {o, x, counted, fake, done}
var spawned := 0
var spawn_t := 1.6
var count := 0
var combo := 0
var running := false
var finished := false
var counter: Label
var hint: Label
var pop: Label
var burst: CPUParticles3D
var beat_t := 0.0
var fence: Node3D


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_world()
	_build_ui()
	Kit.play(self, "dream", 1.0, -6)
	await get_tree().create_timer(1.4).timeout
	running = true
	var tw := create_tween()
	tw.tween_property(hint, "modulate:a", 0.55, 0.6)


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
	env.background_color = Color("2d2350")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d8c8ff")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.glow_intensity = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-30, 20, 0)
	sun.light_color = Color("ffe0f0")
	sun.light_energy = 0.55
	world.add_child(sun)
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.position = Vector3(0, 1.3, 5.6)
	cam.fov = 60
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.6, 0))

	# 雲の丘
	var hill := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 6.0
	hm.height = 3.0
	hill.mesh = hm
	hill.position = Vector3(0, -1.45, -1.0)
	hill.material_override = Obake3D.toon(Color("b9a7e8"), 0.3)
	world.add_child(hill)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 9:
		var c := MeshInstance3D.new()
		var cm := SphereMesh.new()
		var r := rng.randf_range(0.5, 1.0)
		cm.radius = r
		cm.height = r * 1.2
		c.mesh = cm
		c.material_override = Obake3D.toon(Color("f4eeff"), 0.4)
		c.position = Vector3(rng.randf_range(-5, 5), rng.randf_range(1.2, 2.4), rng.randf_range(-9, -6))
		c.scale = Vector3(1.8, 0.8, 1)
		world.add_child(c)
	var moon := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 0.5
	mm.height = 1.0
	moon.mesh = mm
	moon.material_override = Kit.glow(Color("fff1c8"), 2.2)
	moon.position = Vector3(-2.2, 3.3, -4)
	world.add_child(moon)
	var stars := CPUParticles3D.new()
	stars.amount = 80
	stars.lifetime = 100.0
	stars.preprocess = 100.0
	stars.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	stars.emission_box_extents = Vector3(8, 3, 0.5)
	stars.position = Vector3(0, 3.5, -7)
	stars.gravity = Vector3.ZERO
	stars.initial_velocity_max = 0.0
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.06
	stars.mesh = sm
	stars.material_override = Kit.glow(Color("fff6d8"), 3.0)
	world.add_child(stars)

	# 柵
	fence = Node3D.new()
	world.add_child(fence)
	for x in [-0.35, 0.35]:
		var p := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.1, 0.75, 0.1)
		p.mesh = b
		p.position = Vector3(x, 0.37, 0)
		p.material_override = Obake3D.toon(Color("a87250"), 0.1)
		fence.add_child(p)
	for y in [0.3, 0.6]:
		var r := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.9, 0.08, 0.06)
		r.mesh = b
		r.position = Vector3(0, y, 0.06)
		r.material_override = Obake3D.toon(Color("c99468"), 0.1)
		fence.add_child(r)

	burst = CPUParticles3D.new()
	burst.emitting = false
	burst.one_shot = true
	burst.amount = 30
	burst.lifetime = 0.9
	burst.explosiveness = 1.0
	burst.spread = 180
	burst.initial_velocity_min = 1.0
	burst.initial_velocity_max = 2.2
	burst.gravity = Vector3(0, -1.5, 0)
	var bm := SphereMesh.new()
	bm.radius = 0.03
	bm.height = 0.06
	burst.mesh = bm
	burst.material_override = Kit.glow(Color("fff2a8"), 3.0)
	world.add_child(burst)


func _build_ui() -> void:
	var t := Kit.text("夢の中", 14, Color(1, 1, 1, 0.6), false, HORIZONTAL_ALIGNMENT_CENTER)
	t.position = Vector2(0, 26)
	t.size = Vector2(360, 20)
	add_child(t)
	counter = Kit.text("0 ひき", 44, Color("fff6e8"), true, HORIZONTAL_ALIGNMENT_CENTER)
	counter.add_theme_color_override("font_outline_color", Color("2d2350"))
	counter.add_theme_constant_override("outline_size", 10)
	counter.position = Vector2(0, 48)
	counter.size = Vector2(360, 60)
	counter.pivot_offset = Vector2(180, 30)
	add_child(counter)
	var sub := Kit.text("羊をかぞえる夢", 16, Color("e8e2ff"), true, HORIZONTAL_ALIGNMENT_CENTER)
	sub.position = Vector2(0, 108)
	sub.size = Vector2(360, 24)
	add_child(sub)
	hint = Kit.text("柵の真上に来たら、タップ", 18, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	hint.add_theme_color_override("font_outline_color", Color("2d2350"))
	hint.add_theme_constant_override("outline_size", 8)
	hint.position = Vector2(0, 560)
	hint.size = Vector2(360, 30)
	add_child(hint)
	pop = Kit.text("", 30, Color("fff2a8"), true, HORIZONTAL_ALIGNMENT_CENTER)
	pop.add_theme_color_override("font_outline_color", Color("2d2350"))
	pop.add_theme_constant_override("outline_size", 10)
	pop.position = Vector2(0, 170)
	pop.size = Vector2(360, 50)
	pop.pivot_offset = Vector2(180, 25)
	pop.modulate.a = 0.0
	add_child(pop)


func _spawn() -> void:
	# 5 匹目と 9 匹目は、羊じゃないおばけ（歩いて柵をくぐる）
	var fake := spawned == 4 or spawned == 8
	var id: String = "nemuri" if not fake else ["box", "lantern"][spawned % 2]
	var o := Obake3D.new().setup(id)
	o.scale = Vector3.ONE * 0.45
	o.position = Vector3(-3.4, 0, 0.3)
	o.rotation.y = PI / 2
	world.add_child(o)
	sheep.append({"o": o, "x": -3.4, "counted": false, "fake": fake, "missed": false})
	spawned += 1


func _process(delta: float) -> void:
	if not running or finished:
		return
	spawn_t -= delta
	if spawn_t <= 0 and spawned < TOTAL:
		_spawn()
		spawn_t = lerpf(1.5, 1.0, float(spawned) / TOTAL)
	# 小さな拍（オルゴールの刻み）
	beat_t -= delta
	if beat_t <= 0:
		beat_t = 0.5
	for s in sheep:
		var o: Obake3D = s.o
		if not is_instance_valid(o):
			continue
		var sp := SPEED * (0.6 if s.fake else 1.0)
		s.x += sp * delta
		o.position.x = s.x
		if not s.fake and not s.missed:
			var ax: float = absf(s.x)
			if ax < ARC:
				var k: float = 1.0 - (ax / ARC) * (ax / ARC)
				o.position.y = k * 1.05
			else:
				o.position.y = 0.0
		elif s.fake:
			o.position.y = 0.0
			o.position.z = 0.9 # 柵の手前をとぼとぼ
		if s.x > 0.8 and not s.counted and not s.fake and not s.missed:
			s.missed = true
			combo = 0
		if s.x > 3.6:
			o.queue_free()
	sheep = sheep.filter(func(s): return is_instance_valid(s.o))
	if spawned >= TOTAL and sheep.is_empty():
		_finish()


func _gui_input(event: InputEvent) -> void:
	if not running or finished:
		return
	var tap: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if not tap:
		return
	_tap()


func _tap() -> void:
	# 柵にいちばん近い、まだかぞえていないもの
	var best = null
	var bd := 9.0
	for s in sheep:
		if s.counted or s.missed:
			continue
		var d: float = absf(s.x)
		if d < bd:
			bd = d
			best = s
	if best == null or bd > 0.6:
		return
	var o: Obake3D = best.o
	if best.fake:
		best.counted = true
		_pop("それは羊じゃない", Color("ffb3a8"))
		Kit.play(self, "tap", 0.6)
		var tw := create_tween()
		tw.tween_property(o, "rotation:y", 0.0, 0.2)
		tw.tween_interval(0.4)
		tw.tween_property(o, "rotation:y", PI / 2, 0.2)
		combo = 0
		return
	best.counted = true
	if bd < 0.2:
		count += 1
		combo += 1
		_pop("ぴったり" if combo < 3 else "ぴったり ×%d" % combo, Color("fff2a8"))
		Kit.play(self, "chime", 0.9 + min(combo, 8) * 0.06, -4)
		burst.position = o.position + Vector3(0, 0.4, 0)
		burst.restart()
		burst.emitting = true
		var tw := create_tween()
		tw.tween_property(o.body, "rotation:x", TAU, 0.4).as_relative()
	elif bd < 0.45:
		count += 1
		combo = 0
		_pop("かぞえた", Color("e8e2ff"))
		Kit.play(self, "pop", 1.1)
	else:
		best.missed = true
		combo = 0
		_pop("はやい…", Color("ffb3a8"))
		Kit.play(self, "tap", 0.7)
		return
	counter.text = "%d ひき" % count
	counter.scale = Vector2(1.25, 1.25)
	create_tween().tween_property(counter, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)


func _pop(t: String, c: Color) -> void:
	pop.text = t
	pop.add_theme_color_override("font_color", c)
	pop.modulate.a = 1.0
	pop.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(pop, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.35)
	tw.tween_property(pop, "modulate:a", 0.0, 0.25)


func _finish() -> void:
	if finished:
		return
	finished = true
	var res := GameState.finish_dream(count)
	Kit.play(self, "hatch", 0.9)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color(1, 0.98, 1, 0.95), 24, 0.25, Vector2(18, 16)))
	p.position = Vector2(30, 230)
	p.size = Vector2(300, 0)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(Kit.text("%d ひき かぞえた" % count, 24, Color("2a2233"), true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Kit.text("スヤリの玉 ×%d" % res.orbs, 16, Color("6a5bd6"), true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Kit.text("庭のめぐみ +%d" % res.growth, 15, Color("3f7d4f"), true, HORIZONTAL_ALIGNMENT_CENTER))
	if res.flower:
		v.add_child(Kit.wrap(Kit.text("ぜんぶかぞえた。庭に夢見草が一輪咲く", 13, Color("8a5bd6"), false, HORIZONTAL_ALIGNMENT_CENTER)))
	v.add_child(Kit.button("目をさます", Color("ff8a5b"), func(): main.go("hatch")))
	p.pivot_offset = Vector2(150, 120)
	p.scale = Vector2(0.7, 0.7)
	create_tween().tween_property(p, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 自動操作（宣伝・確認用）：柵の上に来たら自分でタップする
var auto := false


func demo_auto() -> void:
	auto = true


func _physics_process(_d: float) -> void:
	if not auto or not running or finished:
		return
	for s in sheep:
		if not s.counted and not s.missed and not s.fake and absf(s.x) < 0.08:
			_tap()
