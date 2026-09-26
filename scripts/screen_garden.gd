extends Control
## 夜の庭（1日の起点）。休憩室の縁側の前に、小さな庭がある。
## 庭はリズム（眠りの整い）で育ち、仕事の日は店にちなんだ飾りが届く。おばけたちは庭で思い思いに過ごす。
## 朝：昨夜の眠りのまとめ → 庭の変化。昼：シフト（ブースト）か休み。夜：川べりへ（満月の夜は月見）。

var main

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var cam_home: Transform3D
var env: Environment
var sun: DirectionalLight3D
var walkers: Array = []
var spots: Array = [] # {pos, act}
var items := {} # 庭の部品 name → Node3D
var lamp_lights: Array = []
var flowers: Array = []
var fireflies: CPUParticles3D
var burst: CPUParticles3D
var night := 0.0 # 0 = 朝 / 1 = 夜

var top_day: Label
var rhythm_bar: ProgressBar
var rhythm_label: Label
var garden_bar: ProgressBar
var garden_label: Label
var poi_row: HBoxContainer
var card: PanelContainer
var card_box: VBoxContainer
var toast: PanelContainer
var goals_btn: Button
var goals_panel: PanelContainer
var busy := false
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_world()
	_build_ui()
	night = 1.0 if GameState.phase == "evening" else 0.0
	_apply_time(night)
	if night > 0.5:
		_light_deco()
	_refresh_hud()
	if GameState.phase == "morning":
		_show_morning()
	else:
		_show_card()


# ---------- 3D の庭 ----------

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

	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 30, 0)
	sun.shadow_enabled = true
	world.add_child(sun)

	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.position = Vector3(0, 7.2, 7.4)
	cam.fov = 52
	cam.v_offset = -1.6
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.0, -0.4))
	cam_home = cam.transform

	var L: int = GameState.garden_seen_level
	var t: int = GameState.tier()
	# 地面：さびしい土 → 芝
	var ground_c := Color("8d7b68") if L < 1 else _grass_color()
	_box(Vector3(16, 0.1, 16), Vector3(0, -0.05, 0), ground_c)
	if L >= 1:
		_grass_tufts()
	# 小石
	var rr := RandomNumberGenerator.new()
	rr.seed = 17
	for i in 10:
		var st := _ball(rr.randf_range(0.07, 0.14), Color("9a948c"))
		st.scale = Vector3(1.3, 0.6, 1.0)
		st.position = Vector3(rr.randf_range(-3.4, 3.4), 0.03, rr.randf_range(-2.2, 2.8))
		world.add_child(st)
	# 石の小道
	for i in 6:
		var st := _cyl(0.22, 0.04, Color("b8b0a4"))
		st.position = Vector3(0.2 + sin(i * 0.9) * 0.25, 0.02, 2.4 - i * 0.75)
		st.scale = Vector3(1.2, 1, 0.9)
		world.add_child(st)

	_build_house()
	_build_lantern(Vector3(2.4, 0, -1.6), L >= 3)
	if L >= 2:
		_build_flowerbed(Vector3(-2.1, 0, 0.6), L, t)
	if L >= 5:
		_build_pond(Vector3(1.3, 0, 0.9))
	if L >= 6:
		_build_bench(Vector3(-0.9, 0, -1.55))
	if L >= 7:
		_build_tree(Vector3(-3.0, 0, -1.9), Color("f5b7c8"), "sakura")
	if L >= 9:
		_build_moon_deck(Vector3(2.9, 0, 1.9))
	if L >= 10:
		_build_tree(Vector3(3.2, 0, -2.6), Color("b9a7ff"), "dream")
	# 庭が満開になったあとも、めぐみ 80 ごとに夢見草が一輪ふえる
	var extra_f: int = maxi(0, (GameState.growth - GameState.GARDEN[-1].need) / 80) if L >= GameState.GARDEN.size() - 1 else 0
	for i in mini(GameState.dream_flowers + extra_f, 40):
		var f := _dream_flower(Vector3(-3.3 + (i % 8) * 0.35, 0, 2.6 + (i / 8) * 0.25))
		world.add_child(f)
	_build_next_stake(L)
	# 仕事の飾り
	for role in GameState.decos:
		var lv: int = GameState.deco_level(role)
		if lv > 0:
			_build_deco(role, lv)

	# 夜の灯り（ほたる）
	fireflies = CPUParticles3D.new()
	fireflies.amount = 12 + (40 if L >= 8 else 0) + t * 8
	fireflies.lifetime = 7.0
	fireflies.preprocess = 7.0
	fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fireflies.emission_box_extents = Vector3(3.8, 0.7, 3)
	fireflies.position = Vector3(0, 0.9, 0)
	fireflies.gravity = Vector3.ZERO
	fireflies.initial_velocity_min = 0.03
	fireflies.initial_velocity_max = 0.12
	fireflies.spread = 180
	var fm := SphereMesh.new()
	fm.radius = 0.02
	fm.height = 0.04
	fireflies.mesh = fm
	fireflies.material_override = Kit.glow(Color("d8ff9a"), 4.0)
	world.add_child(fireflies)

	_weather(GameState.today().weather)

	burst = CPUParticles3D.new()
	burst.emitting = false
	burst.one_shot = true
	burst.amount = 50
	burst.lifetime = 1.2
	burst.explosiveness = 1.0
	burst.spread = 180
	burst.direction = Vector3.UP
	burst.initial_velocity_min = 1.0
	burst.initial_velocity_max = 2.6
	burst.gravity = Vector3(0, -2.0, 0)
	var bm := SphereMesh.new()
	bm.radius = 0.035
	bm.height = 0.07
	burst.mesh = bm
	burst.material_override = Kit.glow(Color("fff2a8"), 3.0)
	world.add_child(burst)

	# おばけたち（最大 14 体まで庭に出る）
	# 新しく来た子を優先して、14 体まで
	for o in GameState.owned.slice(-14):
		var ob := Obake3D.make(o.id)
		ob.scale = Vector3.ONE * (0.5 + min(o.level, 6) * 0.02)
		ob.position = Vector3(randf_range(-2.4, 2.4), 0, randf_range(-1.2, 1.8))
		world.add_child(ob)
		var w := {"o": ob, "id": o.id, "target": ob.position, "wait": randf_range(0.5, 3.0), "act": "", "emote": null}
		# けさ来た子は、縁側から出てくる
		if GameState.newcomers.has(o.id):
			ob.position = Vector3(randf_range(-1.0, 0.6), 0.3, -2.9)
			w.target = Vector3(randf_range(-1.2, 1.2), 0, randf_range(0.2, 1.4))
			w.wait = 0.8 + GameState.newcomers.find(o.id) * 0.6
			var tag := Kit.label3d("NEW " + GameState.info(o.id).name, 30, Color("ffe27a"))
			tag.position = Vector3(0, 1.9, 0)
			ob.add_child(tag)
			var tw := tag.create_tween()
			tw.tween_interval(7.0)
			tw.tween_property(tag, "modulate:a", 0.0, 0.8)
			tw.tween_callback(tag.queue_free)
		walkers.append(w)
	GameState.newcomers = []


## 芝の色（リズムが低いと、少し枯れた色）
func _grass_color() -> Color:
	return Color("7d8a58").lerp(Color("5f9150"), GameState.tier() / 3.0)


func _grass_tufts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 70:
		var p := Vector3(rng.randf_range(-3.6, 3.6), 0, rng.randf_range(-2.6, 2.8))
		var g := _cone(0.05, rng.randf_range(0.12, 0.22), Color("5d8c4a").lerp(Color("88c070"), rng.randf()))
		g.position = p + Vector3(0, 0.08, 0)
		world.add_child(g)
		g.scale = Vector3.ONE * 0.01
		create_tween().tween_property(g, "scale", Vector3.ONE, 0.5).set_delay(rng.randf() * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


var thunder_t := 0.0
var weather := ""


## 今日の天気：雨・雪・雷
func _weather(w: String) -> void:
	weather = w
	if w not in ["雨", "雪", "雷"]:
		return
	var p := CPUParticles3D.new()
	p.amount = 160 if w != "雪" else 90
	p.lifetime = 1.2 if w != "雪" else 5.0
	p.preprocess = p.lifetime
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(5, 0.2, 4)
	p.position = Vector3(0, 5, 0)
	p.direction = Vector3.DOWN
	p.spread = 5 if w != "雪" else 40
	p.gravity = Vector3(0, -9 if w != "雪" else -0.3, 0)
	p.initial_velocity_min = 2.0 if w != "雪" else 0.3
	p.initial_velocity_max = 3.0 if w != "雪" else 0.6
	var m: Mesh
	if w == "雪":
		var sm := SphereMesh.new()
		sm.radius = 0.035
		sm.height = 0.07
		m = sm
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.012, 0.22, 0.012)
		m = bm
	p.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.8, 0.88, 1.0, 0.55) if w != "雪" else Color(1, 1, 1, 0.9)
	p.material_override = mat
	world.add_child(p)


func _mat(c: Color) -> StandardMaterial3D:
	return Obake3D.toon(c, 0.08)


func _box(size: Vector3, pos: Vector3, c: Color, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = _mat(c)
	(parent if parent else world).add_child(m)
	return m


func _cyl(r: float, h: float, c: Color, top := -1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r if top < 0 else top
	cm.bottom_radius = r
	cm.height = h
	m.mesh = cm
	m.material_override = _mat(c)
	return m


func _cone(r: float, h: float, c: Color) -> MeshInstance3D:
	return _cyl(r, h, c, 0.0)


func _ball(r: float, c: Color, mat: Material = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = 16
	s.rings = 8
	m.mesh = s
	m.material_override = mat if mat else _mat(c)
	return m


func _group(name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	world.add_child(n)
	items[name] = n
	return n


const STAGE_SPOT := {1: Vector3(0.9, 0, 1.3), 2: Vector3(-2.1, 0, 0.6), 3: Vector3(2.4, 0, -1.2), 4: Vector3(-2.1, 0, 1.1), 5: Vector3(1.3, 0, 0.9), 6: Vector3(-0.9, 0, -1.4), 7: Vector3(-3.0, 0, -1.6), 8: Vector3(0, 0, 0.4), 9: Vector3(2.9, 0, 1.9), 10: Vector3(3.2, 0, -2.3)}


## 次に育つ場所に、立て札（「予定地」）
func _build_next_stake(L: int) -> void:
	if items.has("stake"):
		items.stake.queue_free()
		items.erase("stake")
	var nx := L + 1
	if nx >= GameState.GARDEN.size():
		return
	var g := _group("stake", STAGE_SPOT.get(nx, Vector3.ZERO) + Vector3(0.3, 0, 0.3))
	var post := _box(Vector3(0.06, 0.7, 0.06), Vector3(0, 0.35, 0), Color("a87250"), g)
	post.name = "post"
	_box(Vector3(1.0, 0.62, 0.04), Vector3(0, 0.85, 0), Color("f4e6cc"), g)
	var names := {1: "芝", 2: "花壇", 3: "灯り", 4: "花", 5: "池", 6: "縁台", 7: "桜", 8: "ほたる", 9: "月見台", 10: "夢見の木"}
	var l := Kit.label3d("%s\n予定地" % names.get(nx, ""), 44, Color("4a3f52"))
	l.outline_size = 0
	l.pixel_size = 0.0055
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.no_depth_test = false
	l.position = Vector3(0, 0.85, 0.03)
	g.add_child(l)


func _build_house() -> void:
	var h := _group("house", Vector3(0, 0, -3.3))
	_box(Vector3(6.4, 1.7, 0.3), Vector3(0, 0.85, -0.2), Color("efe0cc"), h)
	_box(Vector3(6.4, 0.3, 1.2), Vector3(0, 0.15, 0.4), Color("a87250"), h) # 縁側
	for x in [-3.0, 3.0]:
		_box(Vector3(0.14, 1.8, 0.14), Vector3(x, 0.9, 0.9), Color("7a5238"), h)
	var roof := _box(Vector3(7.0, 0.16, 1.4), Vector3(0, 1.85, 0.25), Color("4a4e66"), h)
	roof.rotation.x = -0.25
	# 障子（夜は灯る）
	var shoji := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.4, 1.0)
	shoji.mesh = q
	shoji.position = Vector3(-0.6, 0.85, -0.04)
	shoji.material_override = Kit.glow(Color("fff3d6"), 0.3)
	h.add_child(shoji)
	items["shoji"] = shoji
	for i in 4:
		_box(Vector3(0.04, 1.0, 0.02), Vector3(-1.8 + i * 0.8, 0.85, -0.02), Color("8a6a4e"), h)
	_box(Vector3(2.4, 0.04, 0.02), Vector3(-0.6, 0.85, -0.02), Color("8a6a4e"), h)
	# 休憩室の看板
	var sign := Kit.label3d("休憩室", 40, Color("fff6e8"))
	sign.position = Vector3(1.6, 1.15, 0.0)
	sign.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sign.no_depth_test = false
	h.add_child(sign)
	spots.append({"pos": Vector3(-1.5, 0.3, -2.8), "act": "sit"})
	spots.append({"pos": Vector3(0.6, 0.3, -2.8), "act": "sleep"})


func _build_lantern(at: Vector3, lit: bool) -> void:
	var g := _group("lantern", at)
	_box(Vector3(0.26, 0.8, 0.26), Vector3(0, 0.4, 0), Color("8a8e9c"), g)
	var lamp := _box(Vector3(0.36, 0.32, 0.36), Vector3(0, 0.96, 0), Color("6b6f7e"), g)
	if lit:
		lamp.material_override = Kit.glow(Color("ffcf7a"), 2.4)
		var l := OmniLight3D.new()
		l.light_color = Color("ffc070")
		l.light_energy = 1.8
		l.omni_range = 3.0
		l.position = Vector3(0, 1.0, 0)
		g.add_child(l)
		lamp_lights.append(l)
	var roof := _cyl(0.32, 0.2, Color("4a4e5c"), 0.0)
	roof.mesh.radial_segments = 4
	roof.position = Vector3(0, 1.22, 0)
	g.add_child(roof)
	spots.append({"pos": at + Vector3(-0.5, 0, 0.4), "act": "look"})


func _build_flowerbed(at: Vector3, L: int, t: int) -> void:
	var g := _group("flowerbed", at)
	_box(Vector3(1.6, 0.16, 1.0), Vector3(0, 0.08, 0), Color("8a5a3a"), g)
	_box(Vector3(1.45, 0.05, 0.85), Vector3(0, 0.16, 0), Color("5a3e2c"), g)
	var cols := [Color("ff8fb1"), Color("ffd36b"), Color("9fb4ff"), Color("ffffff"), Color("ff9e6b")]
	for i in 8:
		var f := Node3D.new()
		f.position = Vector3(-0.6 + (i % 4) * 0.4, 0.18, -0.2 + (i / 4) * 0.4)
		g.add_child(f)
		var stem := _cyl(0.02, 0.3, Color("4f8a3b"))
		stem.position.y = 0.15
		f.add_child(stem)
		var leaf := _ball(0.06, Color("6fb35a"))
		leaf.scale = Vector3(1.4, 0.4, 0.8)
		leaf.position = Vector3(0.05, 0.1, 0)
		f.add_child(leaf)
		if L >= 4:
			var head := Node3D.new()
			head.position.y = 0.32
			f.add_child(head)
			var c: Color = cols[i % cols.size()]
			for k in 5:
				var a := TAU * k / 5.0
				var p := _ball(0.06, c)
				p.position = Vector3(cos(a) * 0.06, 0, sin(a) * 0.06)
				p.scale = Vector3(1, 0.5, 1)
				head.add_child(p)
			head.add_child(_ball(0.04, Color("ffe27a")))
		# リズムが低いと、しおれる
		f.rotation.z = [0.6, 0.3, 0.08, 0.0][t] * (1 if i % 2 == 0 else -1)
		f.scale = Vector3.ONE * [0.75, 0.9, 1.0, 1.12][t]
		flowers.append(f)
	spots.append({"pos": at + Vector3(0.1, 0, 0.8), "act": "water"})


func _build_pond(at: Vector3) -> void:
	var g := _group("pond", at)
	var water := _cyl(0.9, 0.02, Color("2f5d8a"))
	water.scale = Vector3(1.3, 1, 0.8)
	water.position.y = 0.02
	g.add_child(water)
	var mrefl := _cyl(0.16, 0.01, Color("fff1c8"))
	mrefl.material_override = Kit.glow(Color("fff1c8"), 1.2)
	mrefl.position = Vector3(0.3, 0.035, -0.1)
	g.add_child(mrefl)
	items["moon_reflect"] = mrefl
	for i in 12:
		var a := TAU * i / 12.0
		var s := _ball(0.13, Color("8e96a8"))
		s.scale = Vector3(1.3, 0.6, 1)
		s.position = Vector3(cos(a) * 1.17, 0.04, sin(a) * 0.72)
		g.add_child(s)
	spots.append({"pos": at + Vector3(0, 0.02, 0), "act": "swim"})


func _build_bench(at: Vector3) -> void:
	var g := _group("bench", at)
	_box(Vector3(1.6, 0.08, 0.6), Vector3(0, 0.4, 0), Color("c9454a"), g)
	for x in [-0.7, 0.7]:
		_box(Vector3(0.08, 0.4, 0.5), Vector3(x, 0.2, 0), Color("6b4430"), g)
	spots.append({"pos": at + Vector3(-0.4, 0.44, 0), "act": "sit"})
	spots.append({"pos": at + Vector3(0.4, 0.44, 0), "act": "sit"})


func _build_tree(at: Vector3, leaf: Color, name: String) -> void:
	var g := _group(name, at)
	var trunk := _cyl(0.16, 1.4, Color("6b4430"), 0.1)
	trunk.position.y = 0.7
	g.add_child(trunk)
	var rng := RandomNumberGenerator.new()
	rng.seed = name.hash()
	for i in 6:
		var b := _ball(rng.randf_range(0.45, 0.65), leaf)
		if name == "dream":
			b.material_override = Obake3D.toon(leaf, 0.3, 0.6)
		b.position = Vector3(rng.randf_range(-0.5, 0.5), 1.55 + rng.randf_range(-0.2, 0.35), rng.randf_range(-0.4, 0.4))
		g.add_child(b)
	if name == "dream":
		var l := OmniLight3D.new()
		l.light_color = leaf
		l.light_energy = 1.5
		l.omni_range = 3.5
		l.position = Vector3(0, 1.6, 0.5)
		g.add_child(l)
		lamp_lights.append(l)
	spots.append({"pos": at + Vector3(0.6, 0, 0.5), "act": "sleep"})


func _build_moon_deck(at: Vector3) -> void:
	var g := _group("moondeck", at)
	_box(Vector3(1.2, 0.2, 1.2), Vector3(0, 0.1, 0), Color("d9b98a"), g)
	var dango := Node3D.new()
	dango.position = Vector3(0, 0.22, 0)
	g.add_child(dango)
	var plate := _cyl(0.2, 0.03, Color("f4f1ea"))
	dango.add_child(plate)
	for p in [Vector3(-0.07, 0.07, 0), Vector3(0.07, 0.07, 0), Vector3(0, 0.07, 0.07), Vector3(0, 0.17, 0.02)]:
		var d := _ball(0.07, Color("fffaf0"))
		d.position = p
		dango.add_child(d)
	var s := _cyl(0.02, 0.8, Color("c9b36b"))
	s.position = Vector3(0.4, 0.6, -0.3)
	s.rotation.z = 0.2
	g.add_child(s)
	spots.append({"pos": at + Vector3(0, 0.2, 0.25), "act": "look"})


func _dream_flower(at: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = at
	var stem := _cyl(0.015, 0.25, Color("4f8a3b"))
	stem.position.y = 0.12
	n.add_child(stem)
	var b := _ball(0.07, Color("c9bdf5"), Kit.glow(Color("c9bdf5"), 1.6))
	b.position.y = 0.27
	n.add_child(b)
	return n


func _build_deco(role: String, lv: int) -> void:
	_build_deco_body(role, lv)
	# 店の名札
	var key := "deco_" + role
	var store: String = GameState.deco_store.get(role, "")
	if items.has(key) and store != "":
		var tag := Kit.label3d(store.split(" ")[-1], 30, Color("fff6e8"))
		tag.pixel_size = 0.007
		tag.position = Vector3(0, 0.3, 0.6)
		tag.no_depth_test = false
		items[key].add_child(tag)


func _build_deco_body(role: String, lv: int) -> void:
	match role:
		"register":
			var g := _group("deco_register", Vector3(-1.4, 0, 1.9))
			var pole := _cyl(0.03, 1.3, Color("f4f1ea"))
			pole.position.y = 0.65
			g.add_child(pole)
			var um := _cyl(0.8, 0.3, Color("ff9e6b"), 0.05)
			um.position.y = 1.35
			g.add_child(um)
			var tb := _cyl(0.35, 0.05, Color("f4f1ea"))
			tb.position.y = 0.5
			g.add_child(tb)
			var cup := _cyl(0.06, 0.1, Color("ffffff"))
			cup.position = Vector3(0.1, 0.57, 0)
			g.add_child(cup)
			if lv >= 2:
				var um2 := _cyl(0.5, 0.08, Color("fff2a8"), 0.3)
				um2.position.y = 1.2
				g.add_child(um2)
				var cake := _cyl(0.08, 0.08, Color("ffd1e0"))
				cake.position = Vector3(-0.12, 0.56, 0.05)
				g.add_child(cake)
			spots.append({"pos": Vector3(-1.9, 0, 1.9), "act": "tea"})
		"hall":
			var g := _group("deco_hall", Vector3(0, 0, -1.9))
			for x in [-2.6, 2.6]:
				var p := _cyl(0.04, 1.9, Color("6b4430"))
				p.position = Vector3(x, 0.95, 0)
				g.add_child(p)
			var n := 5 if lv < 2 else 8
			for i in n:
				var x := -2.2 + i * 4.4 / (n - 1)
				var c := _ball(0.13, Color("e85a4f"), Kit.glow(Color("ff6b5b"), 1.2))
				c.scale = Vector3(1, 1.3, 1)
				c.position = Vector3(x, 1.72 - sin(PI * i / (n - 1)) * 0.2, 0)
				g.add_child(c)
			var l := OmniLight3D.new()
			l.light_color = Color("ff8a6b")
			l.light_energy = 1.2
			l.omni_range = 3.0
			l.position = Vector3(0, 1.5, 0.4)
			g.add_child(l)
			lamp_lights.append(l)
		"dish":
			var g := _group("deco_dish", Vector3(0.9, 0, 2.5))
			var tub := _cyl(0.42, 0.26, Color("9fb8c9"), 0.48)
			tub.position.y = 0.13
			g.add_child(tub)
			var w := _cyl(0.4, 0.02, Color("bfe6ff"))
			w.position.y = 0.25
			g.add_child(w)
			for i in (4 if lv < 2 else 9):
				var b := _ball(0.07 + randf() * 0.05, Color("f4fbff"))
				b.position = Vector3(randf_range(-0.28, 0.28), 0.28 + randf() * 0.08, randf_range(-0.28, 0.28))
				g.add_child(b)
			spots.append({"pos": Vector3(0.9, 0.12, 2.5), "act": "swim"})
		"kitchen":
			var g := _group("deco_kitchen", Vector3(2.8, 0, -0.1))
			_box(Vector3(0.9, 0.6, 0.6), Vector3(0, 0.3, 0), Color("a87250"), g)
			var pot := _cyl(0.24, 0.18, Color("4a4a52"))
			pot.position.y = 0.7
			g.add_child(pot)
			var steam := CPUParticles3D.new()
			steam.amount = 10
			steam.lifetime = 2.0
			steam.direction = Vector3.UP
			steam.spread = 12
			steam.initial_velocity_min = 0.2
			steam.initial_velocity_max = 0.35
			steam.gravity = Vector3.ZERO
			steam.scale_amount_min = 0.6
			steam.scale_amount_max = 1.4
			var sm := SphereMesh.new()
			sm.radius = 0.06
			sm.height = 0.12
			steam.mesh = sm
			var smat := StandardMaterial3D.new()
			smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			smat.albedo_color = Color(1, 1, 1, 0.35)
			steam.material_override = smat
			steam.position.y = 0.8
			g.add_child(steam)
			if lv >= 2:
				var noren := _box(Vector3(1.0, 0.3, 0.02), Vector3(0, 1.3, 0.3), Color("3b4a8c"), g)
				noren.name = "noren"
				for x in [-0.45, 0.45]:
					var p := _cyl(0.03, 1.4, Color("6b4430"))
					p.position = Vector3(x, 0.7, 0.3)
					g.add_child(p)
			spots.append({"pos": Vector3(2.8, 0, 0.5), "act": "eat"})
		"stock":
			var g := _group("deco_stock", Vector3(-3.0, 0, 0.0))
			var n := 3 if lv < 2 else 6
			for i in n:
				var b := _box(Vector3(0.5, 0.36, 0.45), Vector3((i % 3) * 0.45 - 0.45, 0.18 + (i / 3) * 0.36, randf_range(-0.05, 0.05)), Color("d9a86c"), g)
				b.rotation.y = randf_range(-0.15, 0.15)
			spots.append({"pos": Vector3(-3.0, 0, 0.6), "act": "hide"})


# ---------- 時間帯 ----------

var crickets: AudioStreamPlayer


func _apply_time(n: float) -> void:
	night = n
	if crickets == null:
		crickets = AudioStreamPlayer.new()
		var loop: AudioStreamWAV = load("res://assets/sfx/crickets.wav")
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_end = loop.data.size() / 2
		crickets.stream = loop
		add_child(crickets)
		crickets.play()
	crickets.volume_db = lerpf(-60.0, -14.0, n)
	var day_bg := Color("f3d9c4").lerp(Color("cfe3ef"), 0.3)
	env.background_color = day_bg.lerp(Color("141a3a"), n)
	env.ambient_light_color = Color("ffe9d6").lerp(Color("5a64a8"), n)
	env.ambient_light_energy = lerpf(0.4, 0.55, n)
	sun.light_color = Color("ffe0bf").lerp(Color("9fb4ff"), n)
	sun.light_energy = lerpf(0.75, 0.3, n)
	lamp_lights = lamp_lights.filter(func(l): return is_instance_valid(l) and not l.is_queued_for_deletion())
	for l in lamp_lights:
		l.light_energy = lerpf(0.4, 1.8, n)
	if fireflies:
		fireflies.visible = n > 0.4
	if items.has("shoji"):
		(items.shoji.material_override as StandardMaterial3D).emission_energy_multiplier = lerpf(0.2, 1.6, n)


func _tween_night(to: float, dur := 1.4) -> void:
	var tw := create_tween()
	tw.tween_method(_apply_time, night, to, dur).set_trans(Tween.TRANS_SINE)
	await tw.finished


# ---------- おばけの暮らし ----------

func _process(delta: float) -> void:
	_t += delta
	if weather == "雷":
		thunder_t -= delta
		if thunder_t <= 0:
			thunder_t = randf_range(5.0, 9.0)
			var bg := env.background_color
			env.background_color = Color("fff6d8")
			sun.light_energy += 1.5
			Kit.play(self, "tear", 0.35, -8)
			var tw := create_tween()
			tw.tween_interval(0.08)
			tw.tween_callback(func():
				env.background_color = bg
				_apply_time(night))
	for f in flowers:
		f.rotation.x = sin(_t * 1.3 + f.position.x * 3.0) * 0.06
	for w in walkers:
		var ob: Obake3D = w.o
		if not is_instance_valid(ob):
			continue
		w.wait -= delta
		if w.wait > 0:
			if w.act == "sleep":
				ob.rotation.z = lerp_angle(ob.rotation.z, 1.2, 3.0 * delta)
			continue
		if w.act != "":
			_end_act(w)
		var to: Vector3 = w.target
		var d := to - ob.position
		d.y = 0
		if d.length() < 0.06:
			ob.position.y = to.y
			_start_act(w)
			continue
		ob.position.y = move_toward(ob.position.y, 0.0, delta)
		ob.position += d.normalized() * min(d.length(), 0.55 * delta)
		ob.rotation.y = lerp_angle(ob.rotation.y, atan2(d.x, d.z), 5.0 * delta)


func _start_act(w: Dictionary) -> void:
	var act: String = w.get("next_act", "")
	w.act = act
	w.wait = randf_range(2.0, 5.0) if act == "" else randf_range(4.0, 8.0)
	var ob: Obake3D = w.o
	var mark: String = {"sleep": "Zz", "tea": "♪", "swim": "〜", "eat": "ほふ", "look": "…", "water": "♪", "sit": "", "hide": "…"}.get(act, "")
	if act == "sit" or act == "tea":
		ob.rotation.y = 0.0
	if mark != "":
		var l := Kit.label3d(mark, 40, Color("fff6e8"))
		l.position = Vector3(0.3, 1.5, 0)
		ob.add_child(l)
		w.emote = l
	# 次の行き先
	var go_spot := randf() < 0.6 and spots.size() > 0
	if go_spot:
		var sp: Dictionary = spots.pick_random()
		w.target = sp.pos + Vector3(randf_range(-0.12, 0.12), 0, randf_range(-0.12, 0.12))
		w.next_act = sp.act
	else:
		w.target = Vector3(randf_range(-2.6, 2.6), 0, randf_range(-1.2, 2.2))
		w.next_act = ""


func _end_act(w: Dictionary) -> void:
	w.act = ""
	var ob: Obake3D = w.o
	ob.rotation.z = 0.0
	if w.emote and is_instance_valid(w.emote):
		w.emote.queue_free()
	w.emote = null


## 庭のおばけをタップすると、跳ねてひとこと
func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var pos: Vector2 = event.position
	if pos.y < 110 or (card and card.get_global_rect().has_point(pos)):
		return
	var best = null
	var bd := 42.0
	for w in walkers:
		var ob: Obake3D = w.o
		var sp := cam.unproject_position(ob.global_position + Vector3(0, 0.35, 0))
		var d := sp.distance_to(pos)
		if d < bd:
			bd = d
			best = w
	if best == null:
		return
	var o: Obake3D = best.o
	Kit.play(self, "pop", randf_range(0.9, 1.2))
	var tw := create_tween()
	tw.tween_property(o, "position:y", o.position.y + 0.5, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(o, "position:y", o.position.y, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	GameState.goal("talk")
	var l := Kit.label3d(_line_for(best.id), 34, Color("fff6e8"))
	l.position = Vector3(0, 1.9, 0)
	o.add_child(l)
	var tw2 := create_tween()
	tw2.tween_interval(1.6)
	tw2.tween_property(l, "modulate:a", 0.0, 0.4)
	tw2.tween_callback(l.queue_free)


func _line_for(id: String) -> String:
	var t := GameState.tier()
	var common: Array = [["…ねむい", "昨日、何時にねた？", "庭がしょんぼりしてる"], ["まあまあの夜だった", "今夜は早めに", "…ふわぁ"], ["いい夜だった", "花がのびた", "朝の空気がすき"], ["ぐっすり", "庭がきらきらしてる", "夢で羊をかぞえた"]][t]
	var own := {"receipt": "レシート、のびた", "bubble": "ぷく", "tray": "お盆は落とさない", "pan": "じゅう", "box": "箱から出ない", "nemuri": "zzz…", "lantern": "夜はこれから"}
	if own.has(id) and randf() < 0.4:
		return own[id]
	if Rares.is_rare(id) and randf() < 0.5:
		return "……"
	return common.pick_random()


# ---------- UI ----------

func _build_ui() -> void:
	var top := HBoxContainer.new()
	top.position = Vector2(12, 12)
	top.size = Vector2(336, 40)
	top.add_theme_constant_override("separation", 6)
	add_child(top)
	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.92), 20, 0.14, Vector2(12, 6)))
	top_day = Kit.text(GameState.day_label(), 15, Color("2a2233"), true)
	dp.add_child(top_day)
	top.add_child(dp)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var zk := Kit.button("図鑑", Color(1, 1, 1, 0.92), func(): main.go("zukan"), Color("8a5bd6"), 38, 15)
	zk.custom_minimum_size.x = 64
	top.add_child(zk)

	# リズムと庭のメーター
	var meters := PanelContainer.new()
	meters.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.88), 18, 0.12, Vector2(12, 6)))
	meters.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_toggle_diary())
	meters.position = Vector2(12, 58)
	meters.size = Vector2(336, 0)
	add_child(meters)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 2)
	meters.add_child(mv)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	r1.add_child(Kit.text("リズム", 12, Color("8a7a88")))
	rhythm_bar = Kit.bar(0, Color("9fb4ff"), 150, 10)
	r1.add_child(rhythm_bar)
	rhythm_label = Kit.text("", 13, Color("2a2233"), true)
	r1.add_child(rhythm_label)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r1.add_child(sp2)
	r1.add_child(Kit.text("日記 ▸", 11, Color("8a5bd6")))
	mv.add_child(r1)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 8)
	r2.add_child(Kit.text("庭　　", 12, Color("8a7a88")))
	garden_bar = Kit.bar(0, Color("8fd18a"), 150, 10)
	r2.add_child(garden_bar)
	garden_label = Kit.text("", 12, Color("4a3f52"))
	r2.add_child(garden_label)
	mv.add_child(r2)
	poi_row = HBoxContainer.new()
	poi_row.add_theme_constant_override("separation", 6)
	mv.add_child(poi_row)

	goals_btn = Button.new()
	goals_btn.position = Vector2(236, 142)
	goals_btn.size = Vector2(112, 30)
	goals_btn.add_theme_font_override("font", Kit.black())
	goals_btn.add_theme_font_size_override("font_size", 12)
	for k in ["normal", "hover", "pressed", "focus"]:
		goals_btn.add_theme_stylebox_override(k, Kit.pill(Color("fff6d8"), 15, 0.12, Vector2(8, 3)))
	goals_btn.add_theme_color_override("font_color", Color("8a5a10"))
	goals_btn.add_theme_color_override("font_hover_color", Color("8a5a10"))
	goals_btn.pressed.connect(_toggle_goals)
	add_child(goals_btn)
	GameState.goal_completed.connect(func(_t, _a): _refresh_hud())

	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", Kit.pill(Color(1, 0.99, 0.97, 0.96), 24, 0.18, Vector2(16, 14)))
	card.position = Vector2(14, 420)
	card.size = Vector2(332, 200)
	add_child(card)
	card_box = VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 8)
	card.add_child(card_box)


func _refresh_hud() -> void:
	top_day.text = GameState.day_label()
	goals_btn.text = "めあて %d/3 ▾" % GameState.goals_done()
	if goals_panel:
		_toggle_goals()
		_toggle_goals()
	var t := GameState.tier()
	rhythm_bar.value = GameState.rhythm / 100.0
	(rhythm_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = GameState.TIER_COLOR[t]
	rhythm_label.text = GameState.tier_name()
	var L: int = GameState.garden_level
	if L + 1 < GameState.GARDEN.size():
		var a: int = GameState.GARDEN[L].need
		var b: int = GameState.GARDEN[L + 1].need
		garden_bar.value = float(GameState.growth - a) / float(b - a)
		garden_label.text = "Lv%d" % (L + 1)
	else:
		garden_bar.value = 1.0
		garden_label.text = "満開"
	for c in poi_row.get_children():
		c.queue_free()
	poi_row.add_child(Kit.text("ポイ", 12, Color("8a7a88")))
	var shown := 0
	for id in GameState.NETS:
		var n: int = GameState.nets.get(id, 0)
		if n <= 0 or shown >= 4:
			continue
		shown += 1
		var t2: String = GameState.NETS[id].type
		var dot := Panel.new()
		var s := StyleBoxFlat.new()
		s.bg_color = GameState.TYPE_COLOR.get(t2, Color.WHITE)
		s.set_corner_radius_all(6)
		s.border_color = Color(0, 0, 0, 0.25)
		s.set_border_width_all(1)
		dot.add_theme_stylebox_override("panel", s)
		dot.custom_minimum_size = Vector2(12, 12)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		poi_row.add_child(dot)
		poi_row.add_child(Kit.text("×%d" % n, 12))
	var stp := Kit.text("破れにくさ ×%.2f" % GameState.poi_strength(), 12, Color("8b7bff"))
	poi_row.add_child(stp)


var diary: Control


## ねむり日記：直近 7 夜の寝た時刻と起きた時刻（リズムのメーターをタップ）
func _toggle_diary() -> void:
	if diary:
		diary.queue_free()
		diary = null
		return
	Kit.play(self, "tap", 1.1)
	diary = Control.new()
	diary.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(diary)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.06, 0.14, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_toggle_diary())
	diary.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color("fffaf2"), 22, 0.25, Vector2(16, 14)))
	p.position = Vector2(16, 120)
	p.size = Vector2(328, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diary.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(Kit.text("ねむり日記", 20, Color("2a2233"), true))
	v.add_child(Kit.text("リズム %d（%s）・ いつもの時刻 %s" % [int(GameState.rhythm), GameState.tier_name(), GameState.clock(GameState.usual_bed())], 13, Color("6a5f70")))
	var chart := Control.new()
	chart.custom_minimum_size = Vector2(296, 190)
	chart.draw.connect(func(): _draw_diary(chart))
	v.add_child(chart)
	v.add_child(Kit.wrap(Kit.text("緑の帯が「いつもの時刻」。帯の中で寝て、7〜9時間眠る夜が続くと、リズムが満ちる", 12, Color("6a5f70"))))
	var n := GameState.sleep_hist.size()
	var avg := 0.0
	for h in GameState.sleep_hist.slice(-7):
		avg += h
	if n > 0:
		v.add_child(Kit.text("この7夜の平均 %.1f 時間 ・ これまで %d 夜" % [avg / min(7, n), n], 13, Color("4a3f52"), true))


func _draw_diary(c: Control) -> void:
	var w := c.size.x
	var left := 36.0
	var span := 14.0 * 60.0
	var to_x := func(m: float) -> float: return left + clampf(m / span, 0, 1) * (w - left)
	var f := Kit.bold()
	var u := GameState.usual_bed() - 180
	var ux: float = to_x.call(u - 20)
	c.draw_rect(Rect2(ux, 0, float(to_x.call(u + 20)) - ux, 170), Color("8fe0a0", 0.3))
	for m in [0, 180, 360, 540, 720]:
		var x: float = to_x.call(m)
		c.draw_line(Vector2(x, 0), Vector2(x, 170), Color(0, 0, 0, 0.06))
		c.draw_string(f, Vector2(x - 12, 186), GameState.clock(m + 180), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("8a7a88"))
	var beds: Array = GameState.bed_hist.slice(-7)
	var hrs: Array = GameState.sleep_hist.slice(-7)
	var goods: Array = GameState.good_hist.slice(-7)
	var start_day := GameState.day - beds.size()
	for i in beds.size():
		var y := 6.0 + i * 23.0
		var bx: float = to_x.call(beds[i] - 180)
		var ex: float = to_x.call(beds[i] - 180 + hrs[i] * 60.0)
		var col := Color("9fb4ff") if goods[i] else (Color("ff9a4d") if beds[i] > GameState.LATE_LINE else Color("d8cfe0"))
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(6)
		c.draw_style_box(sb, Rect2(bx, y, ex - bx, 14))
		c.draw_string(f, Vector2(0, y + 12), GameState.WEEKDAYS[(start_day + i) % 7], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("4a3f52"))
		c.draw_string(f, Vector2(ex + 4, y + 12), "%.1f" % hrs[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("8a7a88"))
	if beds.is_empty():
		c.draw_string(f, Vector2(left, 90), "まだ記録がない。今夜から", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8a7a88"))


func _toggle_goals() -> void:
	if goals_panel:
		goals_panel.queue_free()
		goals_panel = null
		return
	goals_panel = PanelContainer.new()
	goals_panel.add_theme_stylebox_override("panel", Kit.pill(Color(1, 0.98, 0.9, 0.97), 16, 0.18, Vector2(12, 8)))
	goals_panel.position = Vector2(118, 176)
	goals_panel.size = Vector2(230, 0)
	add_child(goals_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	goals_panel.add_child(v)
	v.add_child(Kit.text("今日のめあて（1つ めぐみ+3）", 11, Color("8a7a88")))
	for g in GameState.goals:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(Kit.text("●" if g.done else "○", 12, Color("e0a030") if g.done else Color("b8aeb6")))
		row.add_child(Kit.wrap(Kit.text(g.text, 12, Color("4a3f52") if not g.done else Color("a89ea6"))))
		v.add_child(row)


func _clear_card() -> void:
	for c in card_box.get_children():
		c.queue_free()


func _card_fit() -> void:
	# 中身に合わせて、下にそろえる
	await get_tree().process_frame
	card.size.y = 0
	await get_tree().process_frame
	card.position.y = 626 - card.size.y


func _pop_card() -> void:
	card.pivot_offset = Vector2(166, 200)
	card.scale = Vector2(0.96, 0.96)
	card.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.18)


func _guide(t: String) -> void:
	# おばけのひとこと（チュートリアル）
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var face := Kit.text("👻", 16)
	face.text = "◉"
	face.add_theme_color_override("font_color", Color("8b7bff"))
	row.add_child(face)
	var l := Kit.wrap(Kit.text(t, 13, Color("6a5bd6")))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	card_box.add_child(row)


## 昼のカード（今日の予定）と、夜のカード
func _show_card() -> void:
	_clear_card()
	var s: Dictionary = GameState.today()
	if GameState.phase == "day":
		if s.get("chore", false):
			card_box.add_child(Kit.text("今日のおてつだい", 18, Color("2a2233"), true))
			card_box.add_child(Kit.wrap(Kit.text("%s（%sの経験になる）\n天気：%s" % [GameState.CHORE_TEXT[s.role], GameState.ROLE_LABEL[s.role], s.weather], 14, Color("6a5f70"))))
			if not GameState.tut.has("shift"):
				_guide("おてつだいで、その仕事のポイが1本。記録とつなぐと、本物のシフトで庭に飾りも届く")
			var b := Kit.button("おてつだいする", Color("ff8a5b"), _do_shift)
			card_box.add_child(b)
			card_box.add_child(Kit.button("今日はのんびりする", Color(1, 1, 1, 0.9), _rest, Color("6a5f70"), 40, 14))
		elif s.role != "":
			card_box.add_child(Kit.text("今日のシフト", 18, Color("2a2233"), true))
			card_box.add_child(Kit.wrap(Kit.text("%s ・ %sの%s（%d時間）\n天気：%s%s" % [s.store, s.band, GameState.ROLE_LABEL[s.role], s.hours, s.weather, "　はじめての経験" if s.first else ""], 14, Color("6a5f70"))))
			if not GameState.tut.has("shift"):
				_guide("働いた日は、仕事のポイと、庭の飾りが届く。長く働いても増えないよ")
			var b := Kit.button("シフトに行く", Color("ff8a5b"), _do_shift)
			card_box.add_child(b)
			card_box.add_child(Kit.button("今日は休む（夜まで庭で過ごす）", Color(1, 1, 1, 0.9), _rest, Color("6a5f70"), 40, 14))
			if not GameState.tut.has("shift"):
				Kit.nudge.call_deferred(b)
		else:
			var solo := GameState.mode == "solo"
			card_box.add_child(Kit.text("今日は休み" if not solo else "静かな一日", 18, Color("2a2233"), true))
			var body := "天気：%s。休みの日によく眠ると、リズムにおまけがつく" % s.weather
			if GameState.day == 0:
				body = "ここは、おばけたちの夜の庭。いつも同じころに、よく眠ると庭が育つ"
			card_box.add_child(Kit.wrap(Kit.text(body, 14, Color("6a5f70"))))
			if GameState.day == 0 and not GameState.tut.has("first"):
				_guide("おばけをタップすると、ひとこと話すよ。夜になったら川べりへ")
			var b := Kit.button("夕方まで、庭でのんびり", Color("ff8a5b"), _rest)
			card_box.add_child(b)
			if GameState.day == 0 and not GameState.tut.has("first"):
				Kit.nudge.call_deferred(b)
	elif GameState.phase == "evening":
		if GameState.is_moon_night() and not GameState.scooped_tonight:
			card_box.add_child(Kit.text("今夜は満月の夜", 18, Color("2a2233"), true))
			var lit := 0
			for g in GameState.moon_lanterns():
				if g:
					lit += 1
			card_box.add_child(Kit.wrap(Kit.text("この一週間、よく眠れた夜が %d 回。その数だけ、月見の灯りがともる" % lit, 14, Color("6a5f70"))))
			var b := Kit.button("月見をする", Color("5b4a9e"), func(): main.go("moon"))
			card_box.add_child(b)
			Kit.nudge.call_deferred(b)
		elif not GameState.scooped_tonight:
			card_box.add_child(Kit.text("夜になった", 18, Color("2a2233"), true))
			var left := 0
			for id in GameState.nets:
				left += GameState.nets[id]
			card_box.add_child(Kit.wrap(Kit.text("川べりで光る玉をすくおう。玉は朝にかえる（ポイ %d 本）" % left, 13, Color("6a5f70"))))
			_deco_chips()
			var b := Kit.button("夜の川べりで、おばけすくい", Color("5b6fc2"), func(): main.go("catch"))
			card_box.add_child(b)
			if not GameState.tut.has("scoop"):
				Kit.nudge.call_deferred(b)
			card_box.add_child(Kit.button("すくわずに、もう寝る", Color(1, 1, 1, 0.9), func(): main.go("sleep"), Color("6a5f70"), 40, 14))
			if GameState.can_gift():
				var c: String = GameState.today().coworkers[0]
				card_box.add_child(Kit.button("%sに、おばけをおすそわけ" % c, Color("fff1dc"), _gift, Color("b0643a"), 36, 13))
		else:
			card_box.add_child(Kit.text("おやすみの時間", 18, Color("2a2233"), true))
			card_box.add_child(Kit.wrap(Kit.text("玉を %d 個持ち帰った。寝る時刻で、明日の庭が変わる" % GameState.orbs.size(), 14, Color("6a5f70"))))
			card_box.add_child(Kit.button("寝る", Color("8b7bff"), func(): main.go("sleep")))
	_card_fit()
	_pop_card()


func _gift() -> void:
	var c := GameState.gift()
	var o: Dictionary = GameState.owned.pick_random()
	Kit.play(self, "pop", 1.1)
	_toast("おすそわけ", "%sに、%sを1体わたした（写しなので、庭の子はそのまま）" % [c, GameState.info(o.id).name])
	_show_card()


## 今夜ともす飾りを選ぶ。その仕事の玉が川べりに出やすくなる
func _deco_chips() -> void:
	var owned_roles: Array = []
	for r in ["register", "hall", "dish", "kitchen", "stock"]:
		if GameState.deco_level(r) > 0:
			owned_roles.append(r)
	if owned_roles.is_empty():
		return
	card_box.add_child(Kit.text("今夜ともす飾り：その仕事の玉が出やすい", 11, Color("8a7a88")))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	card_box.add_child(row)
	for r in owned_roles:
		var on: bool = GameState.lit_deco == r
		var c: Color = GameState.TYPE_COLOR[GameState.SPECIES[GameState.TYPE_SPECIES[r]].type]
		var b := Button.new()
		b.text = GameState.DECOS[r].name
		b.add_theme_font_override("font", Kit.bold())
		b.add_theme_font_size_override("font_size", 11)
		b.text = GameState.DECOS[r].get("short", GameState.DECOS[r].name)
		for k in ["normal", "hover", "pressed", "focus"]:
			var st := Kit.pill(c if on else Color(1, 1, 1, 1), 12, 0.06, Vector2(8, 3))
			st.border_color = c
			st.set_border_width_all(2)
			b.add_theme_stylebox_override(k, st)
		b.add_theme_color_override("font_color", Color("2a2233"))
		b.add_theme_color_override("font_hover_color", Color("2a2233"))
		var role: String = r
		b.pressed.connect(func():
			GameState.lit_deco = "" if GameState.lit_deco == role else role
			if GameState.lit_deco != "":
				GameState.goal("light")
			Kit.play(self, "bell", 1.2, -6)
			_light_deco()
			_show_card())
		row.add_child(b)


var deco_glow: OmniLight3D


func _light_deco() -> void:
	if deco_glow:
		deco_glow.queue_free()
		deco_glow = null
	var key := "deco_" + GameState.lit_deco
	if GameState.lit_deco == "" or not items.has(key):
		return
	deco_glow = OmniLight3D.new()
	deco_glow.light_color = GameState.TYPE_COLOR[GameState.SPECIES[GameState.TYPE_SPECIES[GameState.lit_deco]].type]
	deco_glow.light_energy = 3.0
	deco_glow.omni_range = 2.2
	deco_glow.position = Vector3(0, 1.2, 0.4)
	items[key].add_child(deco_glow)


func _do_shift() -> void:
	if busy:
		return
	busy = true
	GameState.tut["shift"] = true
	var got := GameState.finish_shift()
	_clear_card()
	card_box.add_child(Kit.text("おつかれさま！", 18, Color("2a2233"), true))
	_card_fit()
	_pop_card()
	Kit.play(self, "chime")
	for g in got:
		await get_tree().create_timer(0.35).timeout
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var dot := Panel.new()
		var st := StyleBoxFlat.new()
		st.set_corner_radius_all(8)
		st.bg_color = GameState.TYPE_COLOR.get(GameState.NETS[g.id].type, Color.WHITE) if g.kind == "poi" else Color("8fd18a")
		dot.add_theme_stylebox_override("panel", st)
		dot.custom_minimum_size = Vector2(16, 16)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dot)
		row.add_child(Kit.wrap(Kit.text(g.text, 14, Color("4a3f52"))))
		card_box.add_child(row)
		_card_fit()
		Kit.play(self, "pop", 1.0 + randf() * 0.2)
		_refresh_hud()
		if g.kind == "deco":
			await _reveal_deco(g.id)
	_card_fit()
	await get_tree().create_timer(0.6).timeout
	GameState.new_decos.erase(GameState.today().role)
	await _to_evening()
	busy = false


func _rest() -> void:
	if busy:
		return
	busy = true
	GameState.tut["first"] = true
	await _to_evening()
	busy = false


func _to_evening() -> void:
	GameState.phase = "evening"
	GameState.save()
	card.modulate.a = 0.0
	await _tween_night(1.0)
	_show_card()


## 飾りが庭に届く演出
func _reveal_deco(role: String) -> void:
	var key := "deco_" + role
	if items.has(key):
		items[key].queue_free()
		items.erase(key)
	_build_deco(role, GameState.deco_level(role))
	var n: Node3D = items.get(key)
	if n == null:
		return
	await _focus(n.global_position, 1)
	n.scale = Vector3.ONE * 0.05
	burst.position = n.global_position + Vector3(0, 0.6, 0)
	burst.restart()
	burst.emitting = true
	Kit.play(self, "grow")
	var tw := create_tween()
	tw.tween_property(n, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await tw.finished
	_toast(GameState.DECOS[role].name, GameState.DECOS[role].desc)
	await get_tree().create_timer(1.4).timeout
	await _focus(Vector3.ZERO, 0)


## カメラを寄せる（mode 1）/ 戻す（mode 0）
func _focus(at: Vector3, mode: int) -> void:
	var to := cam_home
	if mode == 1:
		to.origin = at + Vector3(0, 2.4, 4.4)
		to = to.looking_at(at + Vector3(0, 0.4, 0), Vector3.UP)
	var tw := create_tween().set_parallel()
	tw.tween_property(cam, "transform", to, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "v_offset", -0.4 if mode == 1 else -1.6, 0.7)
	await tw.finished


func _toast(title: String, body: String) -> void:
	if toast:
		toast.queue_free()
	toast = PanelContainer.new()
	toast.add_theme_stylebox_override("panel", Kit.pill(Color(0.16, 0.13, 0.26, 0.9), 20, 0.2, Vector2(16, 10)))
	toast.position = Vector2(30, 360)
	toast.size = Vector2(300, 0)
	add_child(toast)
	var v := VBoxContainer.new()
	toast.add_child(v)
	var t := Kit.text(title, 18, Color("ffe27a"), true, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(t)
	var b := Kit.wrap(Kit.text(body, 13, Color("f3eeff"), false, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(b)
	toast.pivot_offset = Vector2(150, 30)
	toast.scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(toast, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.2)
	tw.tween_property(toast, "modulate:a", 0.0, 0.4)
	var tt := toast
	tw.tween_callback(func(): if is_instance_valid(tt): tt.queue_free())


# ---------- 朝 ----------

func _show_morning() -> void:
	var ln: Dictionary = GameState.last_night
	_clear_card()
	card_box.add_child(Kit.text("ゆうべの眠り", 18, Color("2a2233"), true))
	if ln.is_empty():
		GameState.phase = "day"
		_show_card()
		return
	card_box.add_child(Kit.text("%s に寝て %s に起きた（%.1f時間）" % [GameState.clock(ln.bed), GameState.wake_clock(ln.wake), ln.hours], 14, Color("4a3f52")))
	var parts := HFlowContainer.new()
	parts.add_theme_constant_override("h_separation", 6)
	parts.add_theme_constant_override("v_separation", 4)
	for p in ln.parts:
		var pc := PanelContainer.new()
		var good: bool = p[1] >= 0
		pc.add_theme_stylebox_override("panel", Kit.pill(Color("e7f6e9") if good else Color("fde7e3"), 12, 0.0, Vector2(8, 3)))
		pc.add_child(Kit.text("%s %s%d" % [p[0], "+" if good else "", p[1]], 12, Color("3f7d4f") if good else Color("c0473b")))
		parts.add_child(pc)
	card_box.add_child(parts)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	r.add_child(Kit.text("リズム", 13, Color("8a7a88")))
	var bar := Kit.bar(ln.rhythm_before / 100.0, GameState.TIER_COLOR[GameState.tier()], 140, 12)
	r.add_child(bar)
	var diff: float = ln.rhythm - ln.rhythm_before
	r.add_child(Kit.text("%s%d" % ["+" if diff >= 0 else "", int(diff)], 15, Color("3f7d4f") if diff >= 0 else Color("c0473b"), true))
	card_box.add_child(r)
	card_box.add_child(Kit.text("庭のめぐみ +%d%s" % [ln.growth_gain, ("（夢で +%d）" % ln.dream) if ln.has("dream") else ""], 14, Color("3f7d4f"), true))
	var om := GameState.omen()
	if om != "":
		card_box.add_child(Kit.wrap(Kit.text("きざし：" + om, 12, Color("8a5bd6"))))
	if GameState.last_goals > 0:
		card_box.add_child(Kit.text("きのうのめあて %d/3 達成" % GameState.last_goals, 13, Color("b07a1a"), true))
	if ln.get("visitor", "") != "":
		card_box.add_child(Kit.wrap(Kit.text("夜ふかしの灯りに、チョウチンが寄ってきた。でも庭の花は少ししおれた", 13, Color("b0643a"))))
	var btn := Kit.button("庭を見る", Color("ff8a5b"), _after_morning)
	card_box.add_child(btn)
	if GameState.day == 1:
		_guide("同じころに寝て、7〜9時間眠るとリズムが上がる。リズムが高いほど庭がよく育つ")
	_card_fit()
	_pop_card()
	await get_tree().create_timer(0.4).timeout
	Kit.play(self, "chime", 0.9)
	var tw := create_tween()
	tw.tween_property(bar, "value", ln.rhythm / 100.0, 0.9).set_trans(Tween.TRANS_SINE)


func _after_morning() -> void:
	if busy:
		return
	busy = true
	card.modulate.a = 0.0
	# 庭が育った段を、ひとつずつ見せる
	while GameState.garden_seen_level < GameState.garden_level:
		GameState.garden_seen_level += 1
		var st: Dictionary = GameState.GARDEN[GameState.garden_seen_level]
		await _reveal_stage(GameState.garden_seen_level, st)
	GameState.phase = "day"
	GameState.save()
	_refresh_hud()
	busy = false
	_show_card()


func _reveal_stage(level: int, st: Dictionary) -> void:
	var key: String = {2: "flowerbed", 3: "lantern", 4: "flowerbed", 5: "pond", 6: "bench", 7: "sakura", 9: "moondeck", 10: "dream"}.get(level, "")
	var at := Vector3(0, 0, 0.5)
	if key != "" and items.has(key):
		at = items[key].global_position
	await _focus(at, 1)
	# 部品を作り直して、ぽんと出す
	match level:
		1:
			var g := _box(Vector3(16, 0.1, 16), Vector3(0, -0.049, 0), _grass_color())
			g.scale = Vector3(0.01, 1, 0.01)
			create_tween().tween_property(g, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_SINE)
			_grass_tufts()
		2, 4:
			if items.has("flowerbed"):
				items.flowerbed.queue_free()
				flowers.clear()
			_build_flowerbed(Vector3(-2.1, 0, 0.6), level, GameState.tier())
		3:
			items.lantern.queue_free()
			_build_lantern(Vector3(2.4, 0, -1.6), true)
			_apply_time(night)
		5:
			_build_pond(Vector3(1.3, 0, 0.9))
		6:
			_build_bench(Vector3(-0.9, 0, -1.55))
		7:
			_build_tree(Vector3(-3.0, 0, -1.9), Color("f5b7c8"), "sakura")
		8:
			fireflies.amount += 40
			fireflies.visible = true
		9:
			_build_moon_deck(Vector3(2.9, 0, 1.9))
		10:
			_build_tree(Vector3(3.2, 0, -2.6), Color("b9a7ff"), "dream")
	if key != "" and items.has(key):
		var n: Node3D = items[key]
		n.scale = Vector3.ONE * 0.05
		create_tween().tween_property(n, "scale", Vector3.ONE, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	burst.position = at + Vector3(0, 0.5, 0)
	burst.restart()
	burst.emitting = true
	_build_next_stake(level)
	Kit.play(self, "grow")
	Kit.shake(cam, 0.05, 0.3)
	_toast("庭が育った：%s" % st.name, st.desc)
	await get_tree().create_timer(2.0).timeout
	await _focus(Vector3.ZERO, 0)


# ---------- 確認用 ----------

func demo_shift() -> void:
	_do_shift()


func demo_rest() -> void:
	_rest()


func demo_morning() -> void:
	_after_morning()
