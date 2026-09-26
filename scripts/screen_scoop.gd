extends Control
## おばけすくい（Variant A の中心）。夜の川べりで、ただよう光る玉をポイですくう。
## 押している間だけポイが水に入り、離すとすくい上げる。
## ・速く動かすほどポイは弱る（そっと動かすのが腕）。入れた瞬間の波で、真上の玉は逃げる
## ・玉の性格：素直／群れ（まとめてすくえる）／人見知り（速いポイから逃げる）／跳ねる／重い／虹（少しだけ浮かぶ）
## ・やぶれずに続けてすくうとコンボ。ていねい（そっと・真ん中）だと玉に★がつき、朝よく育つ

var main

const WATER_RX := 2.7
const WATER_RZ := 2.2
const POI_R := 0.3
const SUBMERGE_TIME := 0.25
const GENTLE_SPEED := 0.9 # これより遅ければ「そっと」
const MAX_ORBS := 9

var vp: SubViewport
var cam: Camera3D
var cam_base: Transform3D
var world: Node3D
var water_mat: ShaderMaterial
var poi: Node3D
var poi_film_mat: StandardMaterial3D
var poi_rim: MeshInstance3D
var inner_ring: MeshInstance3D
var inner_ring_mat: StandardMaterial3D
var orbs: Array = []
var mods: Dictionary
var supply := 0
var spawn_t := 3.0
var rainbow_left := 0
var rainbow_t := -1.0
var rainbow_done_combo := false
var thunder_t := 9.0
var telegraph: CPUParticles3D
var telegraph_pos := Vector3.ZERO
var telegraph_left := 0.0
var partner_node: Obake3D

# ポイ
var selected := "paper"
var parked := {} # 持ち替えて置いた、使いかけのポイ {id: 丈夫さ}
# 練習（その夜のポイを使い切ったあと）：紙のポイは使い放題、玉は持ち帰れない
var practice := false
var pool: Dictionary
var caught: Array
var in_hand := false
var used := false
var durability := 1.0
var dura_max := 1.0
var pressed := false
var submerge := 0.0
var dip_time := 0.0
var gentle_time := 0.0
var poi_target := Vector3.ZERO
var poi_speed := 0.0
var prev_poi := Vector3.ZERO
var busy := false
var ripple_t := 10.0
var radius := POI_R

# 今夜の成績
var combo := 0
var best_combo := 0
var count := 0
var clean_count := 0
var rainbow_count := 0
var gold_count := 0
var multi_count := 0
var ended := false
var title_before := 0
var tut_step := -1
var goal: Dictionary
var goal_done := false
var goal_label: Label
var tip_pill: PanelContainer
var tip_label: Label
var tip_queue: Array = []
var tip_t := 0.0
const KIND_TIPS := {
	"school": "青は群れ。重ねて、まとめてすくえる",
	"shy": "紫は人見知り。速いポイからは逃げる",
	"jumper": "橙はときどき跳ねる。着水を待とう",
	"heavy": "茶は重い。真ん中で、元気なポイで",
	"rainbow": "虹の玉は少しだけ。待っているレアを連れてくる",
	"gold": "金の玉は祭りの玉。朝、かけらになる",
}

# 自動ですくう（バランス確認・デモ動画用）
var auto := false
var auto_skill := 0.8
var auto_state := "idle"
var auto_t := 0.8
var auto_target: Orb3D
var auto_cursor: Panel

var font_bold: FontFile
var font_black: FontFile
var jar_row: HBoxContainer
var count_label: Label
var combo_label: Label
var combo_sub: Label
var dura_bar: Control
var dura_fill: ColorRect
var dura_cost: ColorRect
var dura_back: ColorRect
var hint: Label
var banner: Label
var tray: HBoxContainer
var flash: ColorRect
var cond_pill: PanelContainer
var tut_ring: Panel
var drops: CPUParticles3D
var scraps: CPUParticles3D
var stars: CPUParticles3D
var sfx := {}
var ambience: AudioStreamPlayer
var float_layer: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	font_bold = load("res://assets/fonts/ZenMaruGothic-Bold.ttf")
	font_black = load("res://assets/fonts/ZenMaruGothic-Black.ttf")
	practice = GameState.practice
	pool = {"paper": 999} if practice else GameState.pois
	caught = [] if practice else GameState.orbs
	mods = GameState.night_mods()
	supply = mods.supply
	rainbow_left = mods.rainbow_max
	if randf() < mods.rainbow:
		rainbow_t = randf_range(10.0, 30.0)
	radius = POI_R * GameState.poi_radius_mult()
	var gift := 0 if practice else GameState.festival_gift()
	goal = {} if practice else GameState.night_goal()
	_build_world()
	_build_ui()
	_build_audio()
	var first := 5 if not mods.festival else 7
	if GameState.records.nights == 0 and not practice:
		first = 4
		tut_step = 0
	for i in first:
		_spawn_orb(true)
	_pick_default_poi()
	_refresh_ui()
	_show_conditions()
	if tut_step == 0:
		_tut_show()
	if gift > 0:
		_float_text("祭りのふるまい：紙のポイ ×%d" % gift, Vector2(180, 300), Color("ffb35c"))


# ---------- 世界 ----------

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
	env.background_color = Color("0b1026") if not mods.dark else Color("05070f")
	if mods.snow:
		env.background_color = Color("1a2238")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a4a8a")
	env.ambient_light_energy = 0.5 if not mods.dark else 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 1.2
	env.glow_strength = 1.2
	env.glow_bloom = 0.25
	env.glow_hdr_threshold = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, -30, 0)
	moon.light_color = Color("9fb4ff")
	moon.light_energy = 0.35 if not mods.dark else 0.12
	world.add_child(moon)

	cam = Camera3D.new()
	cam.position = Vector3(0, 2.6, 4.6)
	cam.fov = 50
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.2, -1.1))
	cam_base = cam.transform

	var bank := MeshInstance3D.new()
	var bp := PlaneMesh.new()
	bp.size = Vector2(30, 30)
	bank.mesh = bp
	bank.position = Vector3(0, -0.02, 0)
	bank.material_override = Obake3D.toon(Color("1f3b2e") if not mods.snow else Color("c9d4e6"), 0.05)
	world.add_child(bank)

	var water := MeshInstance3D.new()
	var wp := PlaneMesh.new()
	wp.size = Vector2(WATER_RX * 2.0, WATER_RZ * 2.0)
	wp.subdivide_width = 8
	wp.subdivide_depth = 8
	water.mesh = wp
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	water.material_override = water_mat
	world.add_child(water)

	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 34:
		var a := TAU * i / 34.0
		var r := 1.0 + rng.randf_range(-0.03, 0.05)
		var st := MeshInstance3D.new()
		var sm := SphereMesh.new()
		var size := rng.randf_range(0.18, 0.3)
		sm.radius = size
		sm.height = size * 1.1
		st.mesh = sm
		st.scale = Vector3(1.3, 0.55, 1.0)
		st.position = Vector3(cos(a) * WATER_RX * r, 0.02, sin(a) * WATER_RZ * r)
		st.rotation.y = rng.randf() * TAU
		st.material_override = Obake3D.toon(Color("5d6a86").lerp(Color("7a86a0"), rng.randf()), 0.2)
		world.add_child(st)

	for i in 40:
		var a := rng.randf() * TAU
		var r := rng.randf_range(1.15, 1.8)
		var g := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.06
		cm.height = rng.randf_range(0.25, 0.5)
		g.mesh = cm
		g.position = Vector3(cos(a) * WATER_RX * r, cm.height * 0.5, sin(a) * WATER_RZ * r)
		g.rotation.z = rng.randf_range(-0.3, 0.3)
		g.material_override = Obake3D.toon(Color("2f5a3c") if not mods.snow else Color("dfe8f5"), 0.1)
		world.add_child(g)

	# 夜空：月（満月は大きく、新月は無し）と星
	var moon_name: String = GameState.today().moon
	if moon_name != "新月":
		var moon_m := MeshInstance3D.new()
		var mm := SphereMesh.new()
		mm.radius = 1.3 if moon_name == "満月" else 0.8
		mm.height = mm.radius * 2.0
		moon_m.mesh = mm
		moon_m.material_override = _glow_mat(Color("fff1c8"), 2.6 if moon_name == "満月" else 1.8)
		moon_m.position = Vector3(4.5, 7.5, -16)
		world.add_child(moon_m)
		if moon_name == "半月":
			var shade := MeshInstance3D.new()
			var shm := SphereMesh.new()
			shm.radius = 0.82
			shm.height = 1.64
			shade.mesh = shm
			shade.material_override = Obake3D.flat(env.background_color)
			shade.position = moon_m.position + Vector3(0.7, 0.1, 0.5)
			world.add_child(shade)
	var sky_stars := CPUParticles3D.new()
	sky_stars.amount = 120 if not mods.dark else 220
	sky_stars.lifetime = 100.0
	sky_stars.preprocess = 100.0
	sky_stars.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sky_stars.emission_box_extents = Vector3(22, 6, 1)
	sky_stars.position = Vector3(0, 9, -18)
	sky_stars.gravity = Vector3.ZERO
	sky_stars.initial_velocity_max = 0.0
	var stm := SphereMesh.new()
	stm.radius = 0.04
	stm.height = 0.08
	sky_stars.mesh = stm
	sky_stars.material_override = _glow_mat(Color("dfe6ff"), 2.0)
	world.add_child(sky_stars)
	for i in 16:
		var tx := -10.0 + i * 1.35 + rng.randf_range(-0.3, 0.3)
		var tz := rng.randf_range(-9, -6)
		var tr := MeshInstance3D.new()
		var tm := SphereMesh.new()
		var ts := rng.randf_range(0.9, 1.5)
		tm.radius = ts
		tm.height = ts * 2.2
		tr.mesh = tm
		tr.position = Vector3(tx, ts * 0.9, tz)
		tr.material_override = Obake3D.toon(Color("132a26") if not mods.snow else Color("5b6a84"), 0.05)
		world.add_child(tr)

	for p in [Vector3(-2.2, 0, -1.6), Vector3(2.3, 0, -2.2)]:
		_lantern(Vector3(p.x * 1.35, 0, p.z * 1.3))
	if mods.festival:
		_festival_deco()

	var flies := CPUParticles3D.new()
	flies.amount = 50
	flies.lifetime = 7.0
	flies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flies.emission_box_extents = Vector3(4, 0.6, 3)
	flies.position = Vector3(0, 0.8, -0.5)
	flies.gravity = Vector3.ZERO
	flies.initial_velocity_min = 0.03
	flies.initial_velocity_max = 0.12
	flies.spread = 180
	var fm := SphereMesh.new()
	fm.radius = 0.018
	fm.height = 0.036
	flies.mesh = fm
	flies.material_override = _glow_mat(Color("d8ff9a"), 4.0)
	if not mods.snow and not mods.rain:
		world.add_child(flies)

	if mods.rain or mods.snow:
		var fall := CPUParticles3D.new()
		fall.amount = 420 if mods.rain else 180
		fall.lifetime = 0.9 if mods.rain else 5.0
		fall.preprocess = 5.0
		fall.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		fall.emission_box_extents = Vector3(3.5, 0.2, 2.6)
		fall.position = Vector3(0, 3.2, -1.2)
		fall.direction = Vector3(0, -1, 0)
		fall.spread = 5 if mods.rain else 30
		fall.gravity = Vector3(0, -9 if mods.rain else -0.4, 0)
		fall.initial_velocity_min = 3.0 if mods.rain else 0.3
		fall.initial_velocity_max = 4.0 if mods.rain else 0.6
		var drop_mesh: Mesh
		if mods.rain:
			var bm := BoxMesh.new()
			bm.size = Vector3(0.006, 0.12, 0.006)
			drop_mesh = bm
		else:
			var sm2 := SphereMesh.new()
			sm2.radius = 0.025
			sm2.height = 0.05
			drop_mesh = sm2
		fall.mesh = drop_mesh
		var fm2 := _glow_mat(Color(0.66, 0.78, 1.0, 0.45) if mods.rain else Color("ffffff"), 0.6)
		fm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fall.material_override = fm2
		# 雨は水面に小さな波紋を立てる（見た目だけ）
		if mods.rain:
			water_mat.set_shader_parameter("glint", Color(0.8, 0.85, 1.0))
		world.add_child(fall)

	drops = _burst(Color("cfe8ff"), 24, 0.7, Vector3(0, -6, 0), 1.2, 2.4)
	scraps = _burst(Color("fff6e8"), 14, 0.9, Vector3(0, -3, 0), 0.4, 1.2)
	var scrap_mesh := BoxMesh.new()
	scrap_mesh.size = Vector3(0.05, 0.004, 0.035)
	scraps.mesh = scrap_mesh
	scraps.angular_velocity_min = -360
	scraps.angular_velocity_max = 360
	stars = _burst(Color("fff2a8"), 40, 1.1, Vector3(0, -1.5, 0), 1.0, 2.2)
	telegraph = CPUParticles3D.new()
	telegraph.emitting = false
	telegraph.amount = 18
	telegraph.lifetime = 0.9
	telegraph.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	telegraph.emission_sphere_radius = 0.2
	telegraph.direction = Vector3(0, 1, 0)
	telegraph.spread = 15
	telegraph.gravity = Vector3.ZERO
	telegraph.initial_velocity_min = 0.2
	telegraph.initial_velocity_max = 0.45
	var tbm := SphereMesh.new()
	tbm.radius = 0.03
	tbm.height = 0.06
	telegraph.mesh = tbm
	telegraph.material_override = _glow_mat(Color("e8f6ff"), 2.0)
	world.add_child(telegraph)

	# 相棒は、奥の岸で見守る
	if GameState.owned.has(GameState.partner):
		partner_node = Obake3D.make(GameState.partner)
		partner_node.set_level(GameState.level_of(GameState.partner))
		partner_node.scale = Vector3.ONE * 0.42
		partner_node.position = Vector3(-1.05, 0, -2.45)
		partner_node.rotation.y = 0.35
		world.add_child(partner_node)

	poi = _make_poi()
	world.add_child(poi)
	poi.position = Vector3(0, 0.45, 1.2)
	poi_target = poi.position
	prev_poi = poi.position


func _festival_deco() -> void:
	# 紅白の提灯をつないだ綱
	for row in 1:
		var z := -3.1
		for i in 13:
			var x := -3.0 + i * 0.5
			var l := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.09
			sm.height = 0.22
			l.mesh = sm
			var sag := 0.2 * sin(PI * float(i) / 12.0)
			l.position = Vector3(x, 1.25 - sag, z)
			l.material_override = _glow_mat(Color("ff6b5b") if i % 2 == 0 else Color("fff1dc"), 1.8)
			world.add_child(l)
	var ol := OmniLight3D.new()
	ol.light_color = Color("ff9a6b")
	ol.light_energy = 1.2
	ol.omni_range = 5.0
	ol.position = Vector3(0, 2.2, -2.2)
	world.add_child(ol)


func _glow_mat(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m


func _burst(c: Color, amount: int, life: float, grav: Vector3, vmin: float, vmax: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector3(0, 1, 0)
	p.spread = 70
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = grav
	var m := SphereMesh.new()
	m.radius = 0.025
	m.height = 0.05
	p.mesh = m
	p.material_override = _glow_mat(c, 2.5)
	world.add_child(p)
	return p


func _lantern(at: Vector3) -> void:
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.28, 0.9, 0.28)
	base.mesh = bm
	base.position = at + Vector3(0, 0.45, 0)
	base.material_override = Obake3D.toon(Color("6b6f7e"), 0.1)
	world.add_child(base)
	var lamp := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.36, 0.34, 0.36)
	lamp.mesh = lm
	lamp.position = at + Vector3(0, 1.07, 0)
	lamp.material_override = _glow_mat(Color("ffcf7a"), 2.6)
	world.add_child(lamp)
	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.0
	rm.bottom_radius = 0.34
	rm.height = 0.22
	rm.radial_segments = 4
	roof.mesh = rm
	roof.position = at + Vector3(0, 1.35, 0)
	roof.material_override = Obake3D.toon(Color("4a4e5c"), 0.1)
	world.add_child(roof)
	var l := OmniLight3D.new()
	l.light_color = Color("ffc070")
	l.light_energy = 2.2
	l.omni_range = 3.2
	l.position = at + Vector3(0, 1.1, 0)
	world.add_child(l)


func _make_poi() -> Node3D:
	var n := Node3D.new()
	var s := radius / POI_R
	poi_rim = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = POI_R - 0.025
	t.outer_radius = POI_R + 0.02
	poi_rim.mesh = t
	poi_rim.scale = Vector3(s, 1, s)
	n.add_child(poi_rim)
	var film := MeshInstance3D.new()
	var f := CylinderMesh.new()
	f.top_radius = POI_R - 0.01
	f.bottom_radius = POI_R - 0.01
	f.height = 0.004
	film.mesh = f
	film.scale = Vector3(s, 1, s)
	poi_film_mat = StandardMaterial3D.new()
	poi_film_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	poi_film_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	poi_film_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	poi_film_mat.albedo_color = Color(1, 1, 1, 0.45)
	film.material_override = poi_film_mat
	n.add_child(film)
	# 真ん中の目じるし（ここに乗せてすくうと★）
	inner_ring = MeshInstance3D.new()
	var it := TorusMesh.new()
	it.inner_radius = POI_R * 0.6 - 0.006
	it.outer_radius = POI_R * 0.6 + 0.006
	inner_ring.mesh = it
	inner_ring.scale = Vector3(s, 1, s)
	inner_ring_mat = StandardMaterial3D.new()
	inner_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	inner_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	inner_ring_mat.albedo_color = Color(1, 1, 1, 0.35)
	inner_ring.material_override = inner_ring_mat
	n.add_child(inner_ring)
	var handle := MeshInstance3D.new()
	var h := BoxMesh.new()
	h.size = Vector3(0.06, 0.03, 0.4)
	handle.mesh = h
	handle.position = Vector3(0.12, 0.05, radius + 0.19)
	handle.rotation = Vector3(-0.35, -0.4, 0)
	handle.material_override = Obake3D.toon(Color("e85a4f"), 0.2)
	n.add_child(handle)
	return n


func _rand_in_pond(scale := 0.6) -> Vector3:
	var a := randf() * TAU
	var r := sqrt(randf()) * scale
	return Vector3(cos(a) * WATER_RX * r, 0.0, sin(a) * WATER_RZ * r - 0.3)


func _visible_count() -> int:
	var n := 0
	for o in orbs:
		if not o.caught:
			n += 1
	return n


## 玉をひとつ流す（群れなら3つ）。initial は最初から池にいる分
func _spawn_orb(initial := false) -> void:
	if supply <= 0:
		return
	supply -= 1
	var t := GameState.next_orb_type(randf())
	var kind := GameState.orb_kind_for(t)
	if mods.festival and randf() < 0.3:
		kind = "gold"
		t = "gold"
	var at := _rand_in_pond(0.6) if initial else Vector3(randf_range(-1.6, 1.6), 0, -WATER_RZ * 0.75)
	if kind == "school":
		var leader := _add_orb({"type": t, "kind": kind}, at)
		for i in 2:
			var m := _add_orb({"type": t, "kind": kind}, at + Vector3(randf_range(-0.2, 0.2), 0, randf_range(-0.2, 0.2)))
			m.leader = leader
			m.offset = Vector3(cos(i * PI + 0.5), 0, sin(i * PI + 0.5)) * 0.2
	else:
		_add_orb({"type": t, "kind": kind}, at)
	if not initial:
		_ripple(at)
		_play("splash", 1.4, -10)


func _add_orb(d: Dictionary, at: Vector3) -> Orb3D:
	var o := Orb3D.new().setup(d)
	o.position = at
	if GameState.records.nights == 0:
		o.vel *= 0.5
	world.add_child(o)
	orbs.append(o)
	if not d.kind in ["rainbow"]:
		o.scale *= 0.2
		create_tween().tween_property(o, "scale", Vector3.ONE * Orb3D.KIND_SIZE.get(d.kind, 1.0), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return o


func _start_rainbow() -> void:
	if telegraph_left > 0.0:
		return
	telegraph_pos = _rand_in_pond(0.5)
	telegraph.position = telegraph_pos
	telegraph.emitting = true
	telegraph_left = 2.0
	_play("bubble", 1.0)
	_banner_small("泡が…？", Color("dff4ff"))


func _surface_rainbow() -> void:
	telegraph.emitting = false
	var o := _add_orb({"type": "rare", "kind": "rainbow"}, telegraph_pos)
	o.life = 7.0 + (0.8 * GameState.partner_level() if GameState.partner == "pan" else 0.0)
	o.position.y = -0.4
	create_tween().tween_property(o, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_ripple(telegraph_pos)
	_play("sparkle")
	_banner("虹の玉！", Color("fff2a8"))


# ---------- UI ----------

func _pill(bg: Color, radius_px := 22) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius_px)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 2)
	return s


func _text(t: String, size: int, color := Color.WHITE, font: FontFile = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font if font else font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_ui() -> void:
	var s := GameState.today()
	var top := HBoxContainer.new()
	top.position = Vector2(12, 12)
	top.size = Vector2(336, 40)
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	var jp := PanelContainer.new()
	jp.add_theme_stylebox_override("panel", _pill(Color(0.06, 0.08, 0.2, 0.72)))
	jp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var jv := HBoxContainer.new()
	jv.add_theme_constant_override("separation", 6)
	count_label = _text("", 14, Color("e8ecff"))
	jv.add_child(count_label)
	jar_row = HBoxContainer.new()
	jar_row.add_theme_constant_override("separation", 3)
	jv.add_child(jar_row)
	jp.add_child(jv)
	top.add_child(jp)
	var home := Button.new()
	home.text = "帰る"
	home.add_theme_font_override("font", font_bold)
	home.add_theme_font_size_override("font_size", 14)
	for k in ["normal", "hover", "pressed"]:
		home.add_theme_stylebox_override(k, _pill(Color(1, 1, 1, 0.9)))
	home.add_theme_color_override("font_color", Color("1a1f3a"))
	home.add_theme_color_override("font_hover_color", Color("1a1f3a"))
	home.pressed.connect(func(): _end_night("帰り道"))
	var help := Button.new()
	help.text = "？"
	help.focus_mode = Control.FOCUS_NONE
	help.custom_minimum_size = Vector2(40, 0)
	help.add_theme_font_override("font", font_black)
	help.add_theme_font_size_override("font_size", 16)
	for k in ["normal", "hover", "pressed"]:
		help.add_theme_stylebox_override(k, _pill(Color(1, 1, 1, 0.9)))
	help.add_theme_color_override("font_color", Color("1a1f3a"))
	help.add_theme_color_override("font_hover_color", Color("1a1f3a"))
	help.pressed.connect(_show_help)
	top.add_child(help)
	top.add_child(home)

	var sub := _text("%s曜の夜 ・ %s%s" % [s.day, s.weather, ("・" + s.moon) if s.moon != "" else ""], 12, Color(1, 1, 1, 0.6))
	sub.position = Vector2(20, 56)
	sub.size = Vector2(160, 18)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(sub)

	var gp := PanelContainer.new()
	gp.add_theme_stylebox_override("panel", _pill(Color(0.06, 0.08, 0.2, 0.72), 14))
	gp.position = Vector2(12, 440)
	gp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_label = _text("", 13, Color("ffe7a8"))
	gp.add_child(goal_label)
	add_child(gp)

	tip_pill = PanelContainer.new()
	tip_pill.add_theme_stylebox_override("panel", _pill(Color(1, 0.98, 0.93, 0.95), 16))
	tip_pill.position = Vector2(20, 140)
	tip_pill.size = Vector2(320, 0)
	tip_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tip_pill.modulate.a = 0.0
	tip_label = _text("", 14, Color("2a2233"))
	tip_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	tip_pill.add_child(tip_label)
	add_child(tip_pill)

	combo_label = _text("", 34, Color("fff2a8"), font_black)
	combo_label.add_theme_color_override("font_outline_color", Color("0b1026"))
	combo_label.add_theme_constant_override("outline_size", 8)
	combo_label.position = Vector2(220, 52)
	combo_label.size = Vector2(128, 40)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_label.pivot_offset = Vector2(110, 20)
	add_child(combo_label)
	combo_sub = _text("", 12, Color(1, 1, 1, 0.75))
	combo_sub.position = Vector2(220, 90)
	combo_sub.size = Vector2(128, 16)
	combo_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(combo_sub)

	cond_pill = PanelContainer.new()
	cond_pill.add_theme_stylebox_override("panel", _pill(Color(0.06, 0.08, 0.2, 0.8), 16))
	cond_pill.position = Vector2(14, 80)
	cond_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 0)
	cond_pill.add_child(cv)
	for line in mods.label:
		var l := _text(line, 13, Color("ffe7a8"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		cv.add_child(l)
	# 今夜のブースト（働いた・よく寝た）を、はっきり見せる
	var boosts: Array = []
	if GameState.worked_today:
		boosts.append("働いた分のポイ +%d" % GameState.WORK_POI_CAP)
	if GameState.strength > 1.0:
		boosts.append("よく寝たポイ ×%.2f" % GameState.strength)
	elif GameState.strength < 1.0:
		boosts.append("寝不足のポイ ×%.2f" % GameState.strength)
	if boosts.size() > 0:
		var bl := _text("・".join(boosts), 13, Color("b8ffcf") if GameState.strength >= 1.0 else Color("ffb3a8"))
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		cv.add_child(bl)
	add_child(cond_pill)


	float_layer = Control.new()
	float_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(float_layer)

	hint = _text("", 14, Color(1, 1, 1, 0.9))
	hint.add_theme_color_override("font_outline_color", Color("0b1026"))
	hint.add_theme_constant_override("outline_size", 5)
	hint.position = Vector2(0, 486)
	hint.size = Vector2(360, 22)
	add_child(hint)

	# ポイの丈夫さ（予想される負担も重ねて見せる）
	dura_bar = Control.new()
	dura_bar.position = Vector2(40, 514)
	dura_bar.size = Vector2(280, 12)
	dura_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dura_bar)
	var dl := _text("ポイの丈夫さ", 11, Color(1, 1, 1, 0.7))
	dl.position = Vector2(0, -15)
	dl.size = Vector2(120, 14)
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	dura_bar.add_child(dl)
	dura_back = ColorRect.new()
	dura_back.color = Color(1, 1, 1, 0.18)
	dura_back.size = Vector2(280, 12)
	dura_bar.add_child(dura_back)
	dura_fill = ColorRect.new()
	dura_fill.size = Vector2(280, 12)
	dura_bar.add_child(dura_fill)
	dura_cost = ColorRect.new()
	dura_cost.color = Color(1, 0.35, 0.3, 0.75)
	dura_cost.size = Vector2(0, 12)
	dura_bar.add_child(dura_cost)

	var tray_bg := PanelContainer.new()
	tray_bg.add_theme_stylebox_override("panel", _pill(Color(0.05, 0.07, 0.17, 0.82), 20))
	tray_bg.position = Vector2(8, 538)
	tray_bg.size = Vector2(344, 92)
	add_child(tray_bg)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(320, 80)
	tray_bg.add_child(sc)
	tray = HBoxContainer.new()
	tray.add_theme_constant_override("separation", 6)
	sc.add_child(tray)

	banner = _text("", 36, Color.WHITE, font_black)
	banner.add_theme_color_override("font_outline_color", Color("0b1026"))
	banner.add_theme_constant_override("outline_size", 10)
	banner.position = Vector2(0, 190)
	banner.size = Vector2(360, 120)
	banner.pivot_offset = Vector2(180, 60)
	banner.modulate.a = 0.0
	add_child(banner)

	tut_ring = Panel.new()
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(1, 1, 1, 0.15)
	rs.border_color = Color.WHITE
	rs.set_border_width_all(3)
	rs.set_corner_radius_all(26)
	tut_ring.add_theme_stylebox_override("panel", rs)
	tut_ring.size = Vector2(52, 52)
	tut_ring.pivot_offset = Vector2(26, 26)
	tut_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tut_ring.visible = false
	add_child(tut_ring)

	flash = ColorRect.new()
	flash.color = Color("fff6d8")
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate.a = 0.0
	add_child(flash)


func _build_audio() -> void:
	for n in ["splash", "lift", "chime", "tear", "sparkle", "bubble", "pop", "thunder", "combo", "fanfare"]:
		var p := AudioStreamPlayer.new()
		var path := "res://assets/sfx/%s.wav" % n
		if ResourceLoader.exists(path):
			p.stream = load(path)
		add_child(p)
		sfx[n] = p
	ambience = AudioStreamPlayer.new()
	var loop_name := "festival_loop" if mods.festival and ResourceLoader.exists("res://assets/sfx/festival_loop.wav") else "river_loop"
	var loop: AudioStreamWAV = load("res://assets/sfx/%s.wav" % loop_name)
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = loop.data.size() / 2
	ambience.stream = loop
	ambience.volume_db = -8 if loop_name == "river_loop" else -6
	add_child(ambience)
	ambience.play()


func _play(n: String, pitch := 1.0, vol := 0.0) -> void:
	var p: AudioStreamPlayer = sfx.get(n)
	if p == null or p.stream == null:
		return
	p.pitch_scale = pitch
	p.volume_db = vol
	p.play()


func _poi_color(pid: String) -> Color:
	if not GameState.POI.has(pid):
		return Color("888888")
	return Color(GameState.POI[pid].color)


func _refresh_ui() -> void:
	for c in jar_row.get_children():
		c.queue_free()
	var shown: Array = caught.slice(-8)
	for o in shown:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(12, 12)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(6)
		sb.bg_color = GameState.TYPE_COLOR.get(o.type, Color.WHITE) if o.kind != "rainbow" else Color.from_hsv(randf(), 0.4, 1.0)
		if o.quality >= 2:
			sb.border_color = Color.WHITE
			sb.set_border_width_all(2)
		dot.add_theme_stylebox_override("panel", sb)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		jar_row.add_child(dot)
	count_label.text = "すくった %d" % count
	if goal_label:
		_update_goal()
	combo_label.text = ("%d" % combo) if combo >= 2 else ""
	combo_sub.text = "コンボ" if combo >= 2 else ("最高 %d" % best_combo if best_combo >= 2 else "")
	# ポイの丈夫さ
	var frac := clampf(durability / max(dura_max, 0.01), 0.0, 1.0) if in_hand else (1.0 if pool.get(selected, 0) > 0 else 0.0)
	dura_fill.size.x = 280.0 * frac
	dura_fill.color = Color("7bdc6b") if frac > 0.5 else (Color("ffd23f") if frac > 0.25 else Color("ff6b5b"))
	poi_film_mat.albedo_color = Color(1, 1, 1, 0.12 + 0.45 * frac)
	poi_rim.material_override = Obake3D.toon(_poi_color(selected), 0.4, 0.4)
	# ポイの棚
	for c in tray.get_children():
		c.queue_free()
	for pid in GameState.POI_ORDER:
		var n: int = pool.get(pid, 0)
		var here: bool = (in_hand and pid == selected) or parked.has(pid)
		if n <= 0 and not here:
			continue
		tray.add_child(_chip(pid, n, pid == selected))


func _chip(pid: String, n: int, sel: bool) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(62, 76)
	b.focus_mode = Control.FOCUS_NONE
	var col := _poi_color(pid)
	var st := _pill(col if sel else Color(col.r, col.g, col.b, 0.28), 16)
	st.shadow_size = 0
	if sel:
		st.border_color = Color.WHITE
		st.set_border_width_all(3)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, st)
	b.add_theme_font_override("font", font_black)
	b.add_theme_font_size_override("font_size", 13)
	var fg := Color("1a1f3a") if sel else Color("e8ecff")
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	var hand := "\n手に" if (in_hand and pid == selected) else ("\n使いかけ" if parked.has(pid) else "")
	b.text = "%s\n×%d%s" % [GameState.POI[pid].short, n, hand]
	b.pressed.connect(_select_poi.bind(pid))
	return b


func _goal_progress() -> int:
	match goal.get("id", ""):
		"count":
			return count
		"combo":
			return best_combo
		"clean":
			return clean_count
		"multi":
			return multi_count
		"type":
			return caught.filter(func(o): return o.type == goal.type).size()
	return 0


func _update_goal() -> void:
	if goal.is_empty():
		goal_label.text = "練習（玉は持ち帰れない）"
		return
	var p := mini(_goal_progress(), goal.n)
	goal_label.text = "おだい：%s  %d/%d%s" % [goal.text, p, goal.n, "  達成！" if goal_done else ""]
	if not goal_done and p >= goal.n:
		goal_done = true
		GameState.grant(goal.reward)
		goal_label.text = "おだい：%s  達成！" % goal.text
		_play("fanfare", 1.1, -3)
		_float_text("おだい達成！ " + GameState.reward_text(goal.reward), Vector2(180, 400), Color("ffe27a"), 16)


func _tip(kind: String) -> void:
	var key: String = "kind_" + kind
	if GameState.tut.has(key) or auto:
		return
	GameState.tut[key] = true
	tip_queue.append(KIND_TIPS[kind])


func _pick_default_poi() -> void:
	if pool.get(selected, 0) > 0 or parked.has(selected):
		return
	# 仕事のポイ → 紙 → 工房のポイ の順に
	for pid in parked:
		selected = pid
		return
	for pid in ["receipt", "bubble", "tray", "pan", "box", "paper", "double", "lure", "kira", "akari"]:
		if pool.get(pid, 0) > 0:
			selected = pid
			return
	selected = ""


func _select_poi(pid: String) -> void:
	if busy or pressed or pid == selected:
		return
	if in_hand and used:
		# 使いかけは、丈夫さを持ち越したまま脇に置く（持ち替えで回復はしない）
		parked[selected] = durability
		_toast("使いかけは脇に置いた。戻せば続きから")
	elif in_hand:
		pool[selected] += 1
	in_hand = false
	used = false
	selected = pid
	_play("pop", 1.2, -6)
	_refresh_ui()
	_show_poi_desc()


func _show_poi_desc() -> void:
	if selected == "":
		return
	hint.text = GameState.POI[selected].desc


func _take_poi() -> bool:
	if in_hand:
		return true
	if parked.has(selected):
		# 脇に置いた使いかけから使う
		durability = parked[selected]
		parked.erase(selected)
		dura_max = GameState.poi_durability_max() * (1.9 if selected == "double" else 1.0) * (1.3 if GameState.records.nights == 0 else 1.0)
		in_hand = true
		used = true
		_refresh_ui()
		return true
	if selected == "" or pool.get(selected, 0) <= 0:
		_pick_default_poi()
		if selected == "":
			return false
	pool[selected] -= 1
	in_hand = true
	used = false
	dura_max = GameState.poi_durability_max()
	if selected == "double":
		dura_max *= 1.9
	if GameState.records.nights == 0:
		dura_max *= 1.3 # はじめての夜はやさしく
	durability = dura_max
	if selected == "akari" and rainbow_left >= 0:
		_start_rainbow()
	_refresh_ui()
	return true


# ---------- 入力 ----------

func _ground(p: Vector2) -> Vector3:
	var from := cam.project_ray_origin(p)
	var dir := cam.project_ray_normal(p)
	if absf(dir.y) < 1e-4:
		return poi_target
	var t := -from.y / dir.y
	var g := from + dir * t
	var e := Vector2(g.x / WATER_RX, g.z / WATER_RZ)
	if e.length() > 0.92:
		e = e.normalized() * 0.92
		g = Vector3(e.x * WATER_RX, 0, e.y * WATER_RZ)
	return g


func _gui_input(event: InputEvent) -> void:
	if busy or ended:
		return
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
	if (pos.y < 110 or pos.y > 530) and not pressed:
		return
	var g := _ground(pos)
	if down:
		_press(g)
	elif motion:
		poi_target = Vector3(g.x, poi_target.y, g.z)
	elif up and pressed:
		_release()


func _press(g: Vector3) -> void:
	if not _take_poi():
		_banner("ポイがない", Color("ffb3a8"))
		_end_night("ポイを使い切った")
		return
	pressed = true
	used = true
	submerge = SUBMERGE_TIME
	dip_time = 0.0
	gentle_time = 0.0
	poi.position = Vector3(g.x, 0.3, g.z)
	poi_target = Vector3(g.x, -0.04, g.z)
	prev_poi = poi.position
	_ripple(g)
	_play("splash", randf_range(0.9, 1.1))
	# 入れた瞬間の波で、真上の玉は逃げる（だから少し離れて入れて、そっと寄せる）
	for o: Orb3D in orbs:
		if not o.catchable():
			continue
		var away: Vector3 = o.position - g
		away.y = 0
		var d := away.length()
		if d < radius * 1.6:
			o.vel += (away.normalized() if d > 0.01 else Vector3(1, 0, 0)) * (0.9 - d)
	if tut_step == 0:
		tut_step = 1
		_tut_show()
	elif tut_step < 0:
		hint.text = "玉の下へ、そっと"


func _release() -> void:
	pressed = false
	if submerge > 0.0:
		# 入れてすぐ離しても、すくえない
		poi_target.y = 0.45
		durability -= 0.03
		_toast("はやすぎ")
		_refresh_ui()
		return
	_lift()


func _ripple(g: Vector3) -> void:
	ripple_t = 0.0
	water_mat.set_shader_parameter("ripple_pos", g)


# ---------- すくい上げ ----------

func _orbs_over_poi() -> Array:
	var out: Array = []
	for o: Orb3D in orbs:
		if not o.catchable():
			continue
		var d := Vector2(o.position.x - poi.position.x, o.position.z - poi.position.z).length()
		if d < radius + 0.04:
			out.append(o)
	return out


func _cost_of(list: Array) -> float:
	var cost := 0.0
	var ptype: String = GameState.POI[selected].type if selected != "" else ""
	for o: Orb3D in list:
		var m := 1.0
		if ptype == o.data.type:
			m = 0.6
		elif ptype == "rare" and o.kind == "rainbow":
			m = 0.3
		if o.kind == "heavy" and GameState.partner == "tray":
			m *= 1.0 - 0.08 * GameState.partner_level()
		# ふちに近い玉ほど、紙に負担がかかる（真ん中ですくうのが腕）
		var d := Vector2(o.position.x - poi.position.x, o.position.z - poi.position.z).length() / radius
		m *= 1.0 + 0.9 * d * d
		cost += o.weight() * m
	if tut_step >= 0:
		return 0.05
	# 長く水に入れているほど紙がふやける
	return cost * (1.0 + minf(dip_time * 0.04, 0.5)) * mods.drain


func _lift() -> void:
	busy = true
	var list := _orbs_over_poi()
	if list.is_empty():
		var tw := create_tween()
		tw.tween_property(poi, "position:y", 0.45, 0.2)
		poi_target.y = 0.45
		_play("lift")
		drops.position = poi.position
		drops.restart()
		drops.emitting = true
		await tw.finished
		durability -= 0.04 * mods.drain
		_toast("からぶり")
		if durability <= 0:
			_tear([])
			return
		_refresh_ui()
		busy = false
		return

	var cost := _cost_of(list)
	var will_hold := durability - cost > 0.0
	# ぎりぎり：まだ元気なポイで1つだけなら、すくえるが、そのあと紙が破れる
	var last_gasp := not will_hold and list.size() == 1 and durability >= dura_max * 0.5
	if last_gasp:
		will_hold = true
	var gentle := gentle_time >= 0.2
	var centered_ids := {}
	for o: Orb3D in list:
		o.caught = true
		orbs.erase(o)
		var d := Vector2(o.position.x - poi.position.x, o.position.z - poi.position.z).length()
		if d < radius * 0.6:
			centered_ids[o.get_instance_id()] = true
	var special := list.size() >= 2 or list.any(func(o): return o.kind in ["rainbow", "gold"])
	_play("lift", 0.8)
	# ふつうの1つは手早く、まとめて・虹・金はスローモーションで見せる
	Engine.time_scale = 0.35 if special else 1.0
	var lift_t := 0.35 if special else 0.22
	var cam_to := cam_base
	cam_to.origin = cam_base.origin.lerp(poi.position + Vector3(0, 1.6, 1.3), 0.45 if special else 0.12)
	var tw := create_tween().set_parallel()
	tw.tween_property(cam, "transform", cam_to.looking_at(poi.position, Vector3.UP), lift_t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(poi, "position:y", 0.55, lift_t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for i in list.size():
		var o: Orb3D = list[i]
		var off := Vector3((i - (list.size() - 1) / 2.0) * 0.12, 0, 0)
		tw.tween_property(o, "position", Vector3(poi.position.x, 0.58, poi.position.z) + off, lift_t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	poi_target.y = 0.55
	drops.position = poi.position
	drops.restart()
	drops.emitting = true
	await tw.finished
	if not will_hold:
		Engine.time_scale = 1.0
		for o: Orb3D in list:
			o.caught = false
			orbs.append(o)
		_tear(list)
		return
	durability = 0.0 if last_gasp else durability - cost
	# 決まった瞬間
	var n := list.size()
	combo += n
	best_combo = max(best_combo, combo)
	count += n
	var pos2d := cam.unproject_position(poi.position)
	var tags: Array = []
	for o: Orb3D in list:
		var q := 0
		if gentle:
			q += 1
		if centered_ids.has(o.get_instance_id()):
			q += 1
		if q >= 2:
			clean_count += 1
		if o.kind == "rainbow":
			rainbow_count += 1
		if o.kind == "gold":
			gold_count += 1
		caught.append({"type": o.data.type, "kind": o.kind, "quality": q})
	if gentle:
		tags.append("そっと")
	if not centered_ids.is_empty():
		tags.append("ど真ん中")
	if n >= 2:
		multi_count += 1
		tags.push_front("%dつまとめて！" % n)
	_flash(0.25 if not special else 0.4)
	_play("chime", 1.0 + minf(combo, 12) * 0.04)
	if combo >= 3:
		_play("combo", 1.0 + minf(combo, 12) * 0.05, -4)
	if special:
		_play("sparkle")
		_shake(0.12)
	Input.vibrate_handheld(30 if not special else 70)
	stars.position = list[0].position
	stars.restart()
	stars.emitting = true
	Engine.time_scale = 1.0
	var title := "すくった！"
	if list.any(func(o): return o.kind == "rainbow"):
		title = "虹の玉！"
	elif list.any(func(o): return o.kind == "gold"):
		title = "金の玉！"
	if special or combo in [3, 5, 8, 10, 15, 20]:
		_banner(title if special else "%dコンボ！" % combo, Color("fff2a8"))
	else:
		_float_text(title, pos2d + Vector2(0, -60), Color("fff2a8"), 22)
	if tags.size() > 0:
		_float_text("・".join(tags), pos2d + Vector2(0, -30), Color("b8ffcf"))
	_combo_pop()
	_partner_react(true)
	var tw2 := create_tween().set_parallel()
	var back_t := 0.45 if special else 0.3
	tw2.tween_property(cam, "transform", cam_base, back_t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for o: Orb3D in list:
		tw2.tween_property(o, "position", cam.project_position(Vector2(110, 30), 2.0), back_t + 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw2.tween_property(o, "scale", Vector3.ONE * 0.2, back_t + 0.05)
	await tw2.finished
	for o: Orb3D in list:
		o.queue_free()
	poi_target.y = 0.45
	_play("pop", 1.3, -8)
	var jar: Control = count_label.get_parent().get_parent()
	jar.pivot_offset = jar.size / 2
	jar.scale = Vector2(1.08, 1.08)
	create_tween().tween_property(jar, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if last_gasp:
		_refresh_ui() # おだいのごほうびを先に受け取ってから、次のポイを選ぶ
		_float_text("ぎりぎりセーフ！でも紙が…", Vector2(180, 300), Color("ffd6a8"), 18)
		await get_tree().create_timer(0.35).timeout
		_tear_after_catch()
		return
	_refresh_ui()
	busy = false
	_after_catch()


## ぎりぎりすくえたあとで、ポイだけが破れる（コンボは続く）
func _tear_after_catch() -> void:
	_play("tear")
	_emit_scraps()
	in_hand = false
	used = false
	var tw := create_tween()
	tw.tween_property(poi_film_mat, "albedo_color:a", 0.0, 0.2)
	await tw.finished
	_pick_default_poi()
	_refresh_ui()
	busy = false
	if selected == "":
		_end_night("ポイを使い切った")
	else:
		_after_catch()


func _after_catch() -> void:
	if tut_step >= 1:
		tut_step = -1
		tut_ring.visible = false
		GameState.tut["scoop"] = true
		hint.text = "できた！ゆっくり動かすほど、ポイは長持ち"
	else:
		hint.text = ""
	# コンボのごほうび
	if combo >= 5 and not rainbow_done_combo:
		rainbow_done_combo = true
		_float_text("5コンボ！虹の気配", Vector2(180, 150), Color("fff2a8"))
		await get_tree().create_timer(0.8).timeout
		_start_rainbow()
	if combo == 8 or combo == 9:
		_float_text("名人！", Vector2(180, 170), Color("ffd23f"))
	if mods.festival and count >= 12 and count - 1 < 12:
		_play("fanfare")
		_banner("祭り達成！", Color("ffb35c"))
	if _visible_count() == 0 and supply <= 0 and telegraph_left <= 0.0:
		await get_tree().create_timer(0.8).timeout
		_end_night("今夜の玉は、もうおしまい")


func _partner_react(happy: bool) -> void:
	if partner_node == null:
		return
	var tw := create_tween()
	if happy:
		tw.tween_property(partner_node, "position:y", 0.35, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(partner_node, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(partner_node, "rotation:z", 0.35, 0.15)
		tw.tween_interval(0.4)
		tw.tween_property(partner_node, "rotation:z", 0.0, 0.3)


func _emit_scraps() -> void:
	scraps.position = poi.position + Vector3(0, 0.05, 0)
	scraps.restart()
	scraps.emitting = true


func _tear(list: Array) -> void:
	busy = true
	_partner_react(false)
	_emit_scraps()
	pressed = false
	_play("tear")
	Input.vibrate_handheld(80)
	_shake(0.18)
	var kept := 0
	if GameState.partner == "receipt" and combo > 0:
		kept = int(combo * (0.3 + 0.1 * GameState.partner_level()))
	var lost := combo - kept
	var left_n: int = pool.get(selected, 0)
	var left_txt := "%s あと%d本" % [GameState.POI[selected].name, left_n] if selected != "" and GameState.POI.has(selected) else ""
	_banner("やぶれた…" if lost < 3 else "やぶれた…\n%dコンボ" % combo, Color("ffb3a8"))
	if left_txt != "":
		_float_text(left_txt, Vector2(180, 330), Color(1, 1, 1, 0.95), 16)
	combo = kept
	in_hand = false
	used = false
	var tw := create_tween().set_parallel()
	tw.tween_property(poi_film_mat, "albedo_color:a", 0.0, 0.2)
	tw.tween_property(cam, "transform", cam_base, 0.4)
	for o: Orb3D in list:
		tw.tween_property(o, "position", Vector3(o.position.x + randf_range(-0.2, 0.2), 0.0, o.position.z + randf_range(-0.2, 0.2)), 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tw.finished
	for o: Orb3D in list:
		_ripple(o.position)
	if list.size() > 0:
		_play("splash", 0.8)
	await get_tree().create_timer(0.5).timeout
	poi_target.y = 0.45
	_pick_default_poi()
	_refresh_ui()
	busy = false
	if selected == "":
		_end_night("ポイを使い切った")
	else:
		hint.text = "あたらしいポイ。こんどはそっと"


# ---------- 毎フレーム ----------

func _process(delta: float) -> void:
	ripple_t += delta
	water_mat.set_shader_parameter("ripple_t", ripple_t)
	if auto:
		_auto(delta)
	_update_poi(delta)
	_update_orbs(delta)
	_update_events(delta)
	_update_water_uniforms()
	if tut_ring.visible:
		tut_ring.scale = Vector2.ONE * (1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.008))
		if tut_step == 1 or tut_step == 0:
			_tut_follow()


func _update_poi(delta: float) -> void:
	if busy:
		return
	# 水に入れていない間は、ポイは見せない（押したところに現れる）
	poi.visible = pressed or auto
	var target := poi_target
	if pressed:
		if submerge > 0.0:
			submerge -= delta
		target.y = -0.04
	var before := poi.position
	poi.position = poi.position.lerp(target, minf(1.0, delta * 18.0))
	var v := Vector2(poi.position.x - before.x, poi.position.z - before.z).length() / maxf(delta, 0.001)
	poi_speed = lerpf(poi_speed, v, minf(1.0, delta * 10.0))
	if pressed and submerge <= 0.0:
		dip_time += delta
		if poi_speed < GENTLE_SPEED:
			gentle_time += delta
		else:
			gentle_time = 0.0
		# 速く動かすほど、紙が弱る（そっと動かせば、ほとんど減らない）
		var over := maxf(0.0, poi_speed - 0.8)
		var drain: float = (0.012 + minf(0.25 * over * over, 0.45)) * GameState.poi_gentle_mult() * mods.drain
		if tut_step >= 0:
			drain = 0.0 # はじめての1つめは、破れない
		durability -= drain * delta
		if durability <= 0.0:
			_tear([])
			return
		# 乗っている玉の重さを予告する
		var over_list := _orbs_over_poi()
		for o: Orb3D in orbs:
			o.highlight = over_list.has(o)
		# そっと＋真ん中がそろうと、内側の輪が金色になる（★の合図）
		var centered := false
		for o: Orb3D in over_list:
			if Vector2(o.position.x - poi.position.x, o.position.z - poi.position.z).length() < radius * 0.6:
				centered = true
		inner_ring_mat.albedo_color = Color(1, 0.85, 0.3, 0.95) if centered and gentle_time >= 0.2 else Color(1, 1, 1, 0.35)
		var c := _cost_of(over_list) if over_list.size() > 0 else 0.0
		var frac := clampf(durability / dura_max, 0.0, 1.0)
		var cf := clampf(c / dura_max, 0.0, frac)
		dura_cost.position.x = 280.0 * (frac - cf)
		dura_cost.size.x = 280.0 * cf
		var danger := c >= durability
		var gasp := danger and over_list.size() == 1 and durability >= dura_max * 0.5
		dura_cost.color = Color(1, 0.2, 0.2, 0.55 + 0.4 * absf(sin(Time.get_ticks_msec() * 0.012))) if danger else Color(1, 0.85, 0.4, 0.75)
		if gasp and not auto:
			hint.text = "ぎりぎり！すくえるけど、ポイは破れる"
		elif danger and not auto:
			hint.text = "重すぎる！このままだと、やぶれる"
		elif over_list.size() > 0 and tut_step < 0 and not auto:
			hint.text = "いま離せば、すくえる" if over_list.size() == 1 else "%dつ重なっている！" % over_list.size()
		dura_fill.size.x = 280.0 * frac
		dura_fill.color = Color("7bdc6b") if frac > 0.5 else (Color("ffd23f") if frac > 0.25 else Color("ff6b5b"))
		poi_film_mat.albedo_color.a = 0.12 + 0.45 * frac
		if tut_step == 1 and over_list.size() > 0:
			tut_step = 2
			_tut_show()
		elif tut_step == 2 and over_list.is_empty():
			tut_step = 1
			_tut_show()
	else:
		dura_cost.size.x = 0.0
		for o: Orb3D in orbs:
			o.highlight = false


func _update_orbs(delta: float) -> void:
	var ptype: String = GameState.POI[selected].type if selected != "" else ""
	var lure_r := 0.0
	if pressed and submerge <= 0.0:
		if ptype == "lure":
			lure_r = 1.9
		elif GameState.partner == "bubble":
			lure_r = 0.45 + 0.1 * GameState.partner_level()
	var spd_mult: float = mods.speed * (0.55 if GameState.records.nights == 0 else 1.0)
	if tut_step >= 0:
		spd_mult = 0.08 # 説明の間は、玉はほとんど動かない
	for o: Orb3D in orbs.duplicate():
		if o.caught:
			continue
		if o.sinking:
			continue
		# 虹の玉は、しばらくすると沈む
		if o.kind == "rainbow":
			o.life -= delta
			if o.life <= 0.0:
				_sink(o)
				continue
		# 跳ねる玉
		if o.air > 0.0:
			o.air -= delta
			var k := 1.0 - o.air / 0.8
			o.position.y = sin(PI * clampf(k, 0.0, 1.0)) * 0.55
			o.position += o.vel * delta
			if o.air <= 0.0:
				o.position.y = 0.0
				_ripple(o.position)
				_play("splash", 1.6, -12)
			continue
		if o.kind == "jumper":
			o.hop_timer -= delta
			if o.hop_timer <= 0.0:
				o.hop_timer = randf_range(3.0, 6.0)
				o.air = 0.8
				o.vel = Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))
				_ripple(o.position)
				continue
		var steer := Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)) * delta
		if o.leader and is_instance_valid(o.leader) and not o.leader.caught:
			var to: Vector3 = o.leader.position + o.offset - o.position
			to.y = 0
			steer += to * 2.2 * delta
		var limit := o.max_speed() * spd_mult
		if pressed:
			var away: Vector3 = o.position - poi.position
			away.y = 0
			var d := away.length()
			# 寄ってくる：同じ種類のポイ／よびこみポイ／アワワ
			if d > 0.05 and ((ptype == o.data.type and d < 1.3) or d < lure_r):
				steer -= away.normalized() * 0.5 * delta
				limit *= 1.2
			# 人見知りと虹は、速いポイから逃げる
			var shy_poi := (o.kind == "shy" and ptype != "hall") or (o.kind == "rainbow" and ptype != "rare")
			if shy_poi and d < 1.1 and poi_speed > GENTLE_SPEED * 0.8 and d > 0.001:
				steer += away.normalized() * 2.4 * delta
				limit *= 2.6
				o.alarmed = 0.4
			elif poi_speed > 2.2 and d < 0.8 and d > 0.001:
				steer += away.normalized() * 1.0 * delta
				limit *= 1.6
		o.vel = (o.vel + steer).limit_length(limit)
		o.position += o.vel * delta
		var e: Vector2 = Vector2(o.position.x / WATER_RX, (o.position.z + 0.2) / WATER_RZ)
		if e.length() > 0.78:
			o.vel -= Vector3(e.x, 0, e.y).normalized() * 6.0 * delta
		o.position.y = 0.0


func _sink(o: Orb3D) -> void:
	o.sinking = true
	var tw := create_tween()
	tw.tween_property(o, "position:y", -0.5, 0.8)
	tw.parallel().tween_property(o, "scale", Vector3.ONE * 0.3, 0.8)
	tw.tween_callback(func():
		orbs.erase(o)
		o.queue_free())
	_toast("虹の玉が沈んだ…またどこかで")
	# 一度だけ、もう一度浮かんでくる
	if rainbow_left > 0:
		rainbow_t = randf_range(8.0, 14.0)


func _update_events(delta: float) -> void:
	if ended:
		return
	# はじめて見る玉の性格は、一行で教える
	if tut_step < 0:
		for o: Orb3D in orbs:
			if KIND_TIPS.has(o.kind) and not GameState.tut.has("kind_" + o.kind):
				_tip(o.kind)
	tip_t -= delta
	if tip_t <= 0.0 and tip_queue.size() > 0 and not busy:
		tip_label.text = tip_queue.pop_front()
		tip_t = 3.6
		var tw := create_tween()
		tw.tween_property(tip_pill, "modulate:a", 1.0, 0.2)
		tw.tween_interval(3.0)
		tw.tween_property(tip_pill, "modulate:a", 0.0, 0.3)
	# 新しい玉が流れてくる
	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = randf_range(4.0, 7.0) if not mods.festival else randf_range(2.5, 4.0)
		if _visible_count() < MAX_ORBS and supply > 0:
			_spawn_orb()
	# 虹の玉
	if rainbow_t > 0.0:
		rainbow_t -= delta
		if rainbow_t <= 0.0 and rainbow_left > 0:
			rainbow_left -= 1
			_start_rainbow()
	if telegraph_left > 0.0:
		telegraph_left -= delta
		if telegraph_left <= 0.0:
			_surface_rainbow()
	# 雷：光るたびに玉が散る
	if mods.scatter:
		thunder_t -= delta
		if thunder_t <= 0.0:
			thunder_t = randf_range(9.0, 15.0)
			_flash(0.8)
			_play("thunder")
			_shake(0.25)
			for o: Orb3D in orbs:
				if o.catchable():
					var away: Vector3 = o.position - Vector3(0, 0, -0.3)
					away.y = 0
					o.vel += away.normalized() * 0.8
			_toast("ピカッ！玉が散った")
	if not busy and not in_hand and selected == "" and not ended:
		_end_night("ポイを使い切った")


func _update_water_uniforms() -> void:
	var ps: Array[Vector4] = []
	var cs: Array[Vector4] = []
	var list: Array = orbs.filter(func(o): return not o.caught)
	for i in 6:
		if i < list.size():
			var ob: Orb3D = list[i]
			var c: Color = ob.light.light_color
			ps.append(Vector4(ob.position.x, 0, ob.position.z, 1.0))
			cs.append(Vector4(c.r, c.g, c.b, 1))
		else:
			ps.append(Vector4(100, 0, 100, 0))
			cs.append(Vector4(0, 0, 0, 0))
	water_mat.set_shader_parameter("orb_pos", ps)
	water_mat.set_shader_parameter("orb_col", cs)


# ---------- 演出 ----------

func _banner(text: String, color: Color) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.modulate.a = 1.0
	banner.scale = Vector2(0.5, 0.5)
	var tw := create_tween()
	tw.tween_property(banner, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_property(banner, "modulate:a", 0.0, 0.3)


func _banner_small(text: String, color: Color) -> void:
	_float_text(text, Vector2(180, 240), color)


func _toast(text: String) -> void:
	_float_text(text, Vector2(180, 460), Color(1, 1, 1, 0.9), 14)


func _float_text(text: String, at: Vector2, color: Color, size := 18) -> void:
	var l := _text(text, size, color, font_black)
	l.add_theme_color_override("font_outline_color", Color("0b1026"))
	l.add_theme_constant_override("outline_size", 6)
	l.size = Vector2(300, 30)
	l.position = at - Vector2(150, 15)
	float_layer.add_child(l)
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 36, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


func _combo_pop() -> void:
	if combo < 2:
		return
	combo_label.scale = Vector2(1.6, 1.6)
	create_tween().tween_property(combo_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flash(a: float) -> void:
	flash.modulate.a = a
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.35)


func _shake(amount: float) -> void:
	var tw := create_tween()
	for i in 5:
		var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * amount * 40.0 * (1.0 - i / 5.0)
		tw.tween_property(self, "position", off, 0.04)
	tw.tween_property(self, "position", Vector2.ZERO, 0.04)


func _show_conditions() -> void:
	var tw := create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(cond_pill, "modulate:a", 0.0, 0.6)


# ---------- コツ ----------

func _show_help() -> void:
	if pressed or ended:
		return
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.1, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var card := PanelContainer.new()
	var st := _pill(Color(1, 0.98, 0.95, 0.97), 24)
	st.content_margin_left = 20
	st.content_margin_right = 20
	st.content_margin_top = 16
	st.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", st)
	card.position = Vector2(20, 110)
	card.size = Vector2(320, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	card.add_child(v)
	v.add_child(_text("すくいのコツ", 20, Color("2a2233"), font_black))
	for t in ["押すと水に入る。離すとすくう", "そっと動かすほど、ポイは長持ち", "玉の真上ではなく、少し手前から入れる", "内側の輪が金色のとき離すと★", "ゲージの黄色は乗った玉の重さ。赤は危ない", "同じ色のポイは、その色の玉を寄せて軽くする", "破らずに続けるとコンボ。5コンボで虹の玉"]:
		var l := _text("・" + t, 14, Color("4a3f52"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		l.custom_minimum_size = Vector2(280, 0)
		v.add_child(l)
	v.add_child(_text("タップで閉じる", 12, Color("9a8e98")))
	dim.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			layer.queue_free())


# ---------- チュートリアル（はじめての夜だけ） ----------

func _tut_show() -> void:
	tut_ring.visible = true
	match tut_step:
		0:
			hint.text = "玉のすこし手前を、押したままにする"
		1:
			hint.text = "押したまま、玉の真下へそっと動かす"
		2:
			hint.text = "いま！指を離して、すくい上げる"
			tut_ring.visible = false


func _tut_follow() -> void:
	# 池のまんなかに近い玉をねらう（手前すぎると説明の文字と重なる）
	var target: Orb3D = null
	var best := 1e9
	for o: Orb3D in orbs:
		if o.catchable():
			var d := Vector2(o.position.x, o.position.z + 0.6).length()
			if d < best:
				best = d
				target = o
	if target == null:
		return
	var p := cam.unproject_position(target.position + Vector3(0, 0, 0.5 if tut_step == 0 else 0.0))
	tut_ring.position = p - Vector2(26, 26)


# ---------- 夜のおわり ----------

func _end_night(reason: String) -> void:
	if ended:
		return
	ended = true
	pressed = false
	# すくい上げの途中なら、終わるのを待ってから記録する
	while busy:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	if in_hand and not used:
		pool[selected] += 1
	in_hand = false
	if practice:
		GameState.practice = false
		GameState.records["practice_best"] = max(GameState.records.get("practice_best", 0), best_combo)
		await get_tree().create_timer(0.4).timeout
		_show_result("練習おしまい", false)
		return
	var was_best: bool = best_combo > GameState.records.best_combo and best_combo >= 3
	title_before = GameState.title_index()
	GameState.record_scoop_night({"count": count, "best_combo": best_combo, "clean": clean_count, "rainbow": rainbow_count, "festival": mods.festival, "gold": gold_count})
	await get_tree().create_timer(0.4).timeout
	_show_result(reason, was_best)


func _show_result(reason: String, was_best: bool) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.1, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.6, 0.3)
	var card := PanelContainer.new()
	var st := _pill(Color(1, 0.98, 0.95, 0.97), 26)
	st.content_margin_left = 22
	st.content_margin_right = 22
	st.content_margin_top = 18
	st.content_margin_bottom = 18
	card.add_theme_stylebox_override("panel", st)
	card.position = Vector2(24, 150)
	card.size = Vector2(312, 0)
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	v.add_child(_text(reason, 13, Color("8a7a88")))
	v.add_child(_text("今夜のすくい", 22, Color("2a2233"), font_black))
	var big := _text("%d こ" % count, 44, Color("5b6fc2"), font_black)
	v.add_child(big)
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 4)
	for o in caught:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(18, 18)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(9)
		sb.bg_color = GameState.TYPE_COLOR.get(o.type, Color.WHITE) if o.kind != "rainbow" else Color("ffd6f5")
		if o.quality >= 2:
			sb.border_color = Color("2a2233")
			sb.set_border_width_all(2)
		dot.add_theme_stylebox_override("panel", sb)
		row.add_child(dot)
	v.add_child(row)
	var lines: Array = []
	var pv := "" if practice else _hatch_preview()
	if practice:
		lines.append("練習の最高コンボ %d" % GameState.records.get("practice_best", 0))
	if pv != "":
		lines.append(pv)
	lines.append("最高コンボ %d%s" % [best_combo, "  新記録！" if was_best else ""])
	if clean_count > 0:
		lines.append("ていねいな玉 %d（朝よく育つ）" % clean_count)
	if rainbow_count > 0:
		lines.append("虹の玉 %d" % rainbow_count)
	if mods.festival:
		lines.append("祭り %s" % ("達成！景品はレアの気配" if count >= 12 else "%d / 12" % count))
	elif goal_done:
		lines.append("おだい達成：%s" % GameState.reward_text(goal.reward))
	for line in lines:
		var ll := _text(line, 15, Color("4a3f52"))
		ll.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		ll.custom_minimum_size = Vector2(268, 0)
		v.add_child(ll)
	v.add_child(_text(_rank_text(), 14, Color("8b7bff")))
	if GameState.title_index() > title_before:
		var tl := _text("称号が「%s」になった！" % GameState.title_name(), 17, Color("e8603c"), font_black)
		v.add_child(tl)
	else:
		var nt := _text(GameState.next_title_text(), 11, Color("9a8e98"))
		nt.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		v.add_child(nt)
	var b := Button.new()
	b.text = "寝る準備へ"
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_override("font", font_black)
	b.add_theme_font_size_override("font_size", 18)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, _pill(Color("8b7bff"), 25))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.pressed.connect(func(): main.go("sleep"))
	v.add_child(b)
	# ポイを使い切ったあとも、もう少しすくいたい人へ
	var pr := Button.new()
	pr.text = "練習ですくう（玉は持ち帰れない）"
	pr.custom_minimum_size = Vector2(0, 40)
	pr.add_theme_font_override("font", font_bold)
	pr.add_theme_font_size_override("font_size", 14)
	for k in ["normal", "hover", "pressed"]:
		pr.add_theme_stylebox_override(k, _pill(Color(1, 1, 1, 1), 20))
	pr.add_theme_color_override("font_color", Color("5b6fc2"))
	pr.add_theme_color_override("font_hover_color", Color("5b6fc2"))
	pr.pressed.connect(func():
		GameState.practice = true
		main.go("catch"))
	v.add_child(pr)
	await get_tree().process_frame
	card.reset_size()
	card.size.x = 312
	card.position.y = clampf((640.0 - card.size.y) / 2.0, 8.0, 200.0)
	card.scale = Vector2(0.85, 0.85)
	card.pivot_offset = card.size / 2.0
	card.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.2)
	if was_best:
		_play("fanfare")
	else:
		_play("chime", 0.8)


## 朝なにがかえるか（種類ごと）と、Lvアップしそうな子
func _hatch_preview() -> String:
	var per := {}
	var xp := {}
	var school := 0
	var mystery := 0
	for o in caught:
		if o.kind in ["rainbow", "gold"]:
			mystery += 1
			continue
		if o.kind == "school":
			school += 1
			if school % 2 == 0:
				continue
		var sid: String = GameState.TYPE_SPECIES.get(o.type, "receipt")
		per[sid] = per.get(sid, 0) + 1
		xp[sid] = xp.get(sid, 0) + 4 + o.quality * 4 + (4 if GameState.owned.has(sid) else 0)
	if per.is_empty() and mystery == 0:
		return ""
	var parts: Array = []
	for sid in per:
		parts.append("%s×%d" % [GameState.info(sid).name, per[sid]])
	if mystery > 0:
		parts.append("？×%d" % mystery)
	var t := "朝かえる：" + "・".join(parts)
	for sid in xp:
		var own: Dictionary = GameState.owned.get(sid, {})
		if own.is_empty() or own.level >= GameState.MAX_LEVEL:
			continue
		if xp[sid] >= GameState.xp_to_next(own.level) - own.xp:
			t += "\n%sがLv%dになりそう" % [GameState.info(sid).name, own.level + 1]
			break
	return t


func _rank_text() -> String:
	if count == 0:
		return "今夜は見るだけ。明日はきっと"
	if best_combo >= 8:
		return "すくい名人の手つき"
	if best_combo >= 5:
		return "水面が、あなたを覚えはじめた"
	if count >= 4:
		return "いい夜だった"
	return "はじめの一歩"


# ---------- 自動ですくう ----------

func _auto_pick() -> Orb3D:
	var best: Orb3D = null
	var best_score := -1e9
	for o: Orb3D in orbs:
		if not o.catchable():
			continue
		var e := Vector2(o.position.x / WATER_RX, (o.position.z + 0.2) / WATER_RZ).length()
		var score := -Vector2(o.position.x - poi.position.x, o.position.z - poi.position.z).length() - e * 1.5
		if o.kind == "rainbow":
			score += 5.0
		elif o.kind == "gold":
			score += 2.0
		elif o.kind == "school":
			score += 0.8 * auto_skill
		elif o.kind == "heavy":
			score -= 0.6
		if score > best_score:
			best_score = score
			best = o
	return best


func _auto(delta: float) -> void:
	if ended or busy:
		return
	auto_t -= delta
	if auto_cursor:
		auto_cursor.visible = true
		auto_cursor.position = cam.unproject_position(poi.position) - Vector2(18, 18)
		auto_cursor.modulate.a = 1.0 if pressed else 0.45
	match auto_state:
		"idle":
			if auto_t > 0.0:
				return
			auto_target = _auto_pick()
			if auto_target == null:
				auto_t = 0.5
				if supply <= 0 and telegraph_left <= 0.0:
					_end_night("今夜の玉は、もうおしまい")
				return
			var entry := auto_target.position + Vector3(randf_range(-0.3, 0.3), 0, 1.0).normalized() * radius * 1.9
			var e := Vector2(entry.x / WATER_RX, entry.z / WATER_RZ)
			if e.length() > 0.9:
				entry = auto_target.position + Vector3(0, 0, -1) * radius * 1.9
			_press(Vector3(entry.x, 0, entry.z))
			if not pressed:
				return
			auto_state = "approach"
			auto_t = 7.0
		"approach":
			if not pressed:
				auto_state = "idle"
				auto_t = 0.6
				return
			if auto_target == null or not is_instance_valid(auto_target) or not auto_target.catchable():
				auto_target = _auto_pick()
				if auto_target == null:
					_release()
					auto_state = "idle"
					auto_t = 0.6
					return
			var to := Vector3(auto_target.position.x - poi_target.x, 0, auto_target.position.z - poi_target.z)
			var spd := lerpf(2.0, 0.78, auto_skill)
			var step := minf(to.length(), spd * delta)
			if to.length() > 0.001:
				poi_target += to.normalized() * step
			var need := lerpf(0.95, 0.35, auto_skill) * radius
			var over := _orbs_over_poi()
			var ok_gentle := gentle_time >= 0.22 or auto_skill < 0.5
			# 上手いなら、重すぎて破れそうなときは離さずに、ひとつだけ乗るところへずらす
			if auto_skill > 0.7 and over.size() > 1 and _cost_of(over) >= durability and auto_t > 1.5:
				poi_target += Vector3(to.x, 0, to.z).normalized() * 0.3 * delta
				return
			if (to.length() < need and ok_gentle and submerge <= 0.0) or auto_t <= 0.0:
				# 上手いほど、群れが重なるのを少し待つ
				if auto_skill > 0.7 and over.size() == 1 and over[0].kind == "school" and auto_t > 5.0:
					return
				_release()
				auto_state = "idle"
				auto_t = randf_range(0.5, 1.0)


# ---------- 確認・デモ用 ----------

func start_auto(skill: float) -> void:
	auto = true
	auto_skill = skill
	tut_step = -1
	tut_ring.visible = false
	auto_cursor = Panel.new()
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(1, 1, 1, 0.25)
	rs.border_color = Color.WHITE
	rs.set_border_width_all(3)
	rs.set_corner_radius_all(18)
	auto_cursor.add_theme_stylebox_override("panel", rs)
	auto_cursor.size = Vector2(36, 36)
	auto_cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(auto_cursor)


func demo_hold() -> void:
	# 1つ目の玉の真下にポイを入れた状態を作る
	var o: Orb3D = null
	for x: Orb3D in orbs:
		if x.catchable():
			o = x
			break
	if o == null:
		return
	_take_poi()
	o.vel = Vector3.ZERO
	o.set_process(false)
	pressed = true
	used = true
	submerge = 0.0
	gentle_time = 0.5
	poi.position = Vector3(o.position.x, -0.04, o.position.z)
	poi_target = poi.position
	_ripple(o.position)


func demo_lift() -> void:
	pressed = false
	_lift()


func demo_auto() -> void:
	start_auto(0.8)


func demo_rainbow() -> void:
	_start_rainbow()


func demo_end() -> void:
	_end_night("帰り道")


func demo_fill() -> void:
	for t in ["register", "dish", "hall", "kitchen", "stock", "dish", "hall"]:
		GameState.orbs.append({"type": t, "kind": GameState.orb_kind_for(t), "quality": 2})
	GameState.orbs.append({"type": "rare", "kind": "rainbow", "quality": 1})
	count = GameState.orbs.size()
	best_combo = 6
	clean_count = 5
	rainbow_count = 1
