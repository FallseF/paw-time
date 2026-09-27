extends Control
## おばけすくい。夜の川べりで、水面をただよう光る玉をポイですくう。
## 押している間だけポイが水に入り、離すとすくい上げる。
## ポイの枚数＝その日に働いた分。速く動かすほど、重い玉ほど破れやすい。

var main

const WATER_RX := 2.7
const WATER_RZ := 2.2
const POI_R := 0.3
## 玉が泳いでいい、画面の中の水面（上は岸の石、下はポイの選択バーの上まで）
const ORB_SAFE := Rect2(30, 300, 300, 222)
## 水面に、いつも少なくともこれだけの玉（すくったら足す。ポイがある間）
const MIN_ON_SCREEN := 3
## 新しい玉は、ポイの陰（宙のポイ〜水面の当たりの輪）・指の下・手の見本の下には浮かべない（画面の px）
const ORB_PX := 18.0 # 玉の画面の上の大きさ（半径くらい）
const THUMB_PX := 110.0 # 指（スマホ）は、ポイの水面の点から下へ、これくらいをかくす
const THUMB_R := 34.0
## ポイが動ける画面の水面（上は岸の石の手前、下はポイの選択バーの上）。池の奥は石と木にかくれるので、そこへは行かない
const POI_AREA := Rect2(50, 330, 260, 190)
## 今夜は、いつも終わる：
##   今夜の玉の数（はじめの玉 + 足す玉。ポイの本数 × NET_SCOOPS まで）に届いたら、玉は足さない
##   1 本のポイですくえるのは NET_SCOOPS 個まで（破れなくても、くたくたになる）
##   NIGHT_SEC 秒（すくっている時間）を過ぎたら、残りの玉は川へ流れていって、まとめへ
const NET_SCOOPS := 3
const BUDGET_EXTRA := 4
const NIGHT_SEC := 90.0

var vp: SubViewport
var cam: Camera3D
var cam_base: Transform3D
var world: Node3D
var water_mat: ShaderMaterial
var poi: Node3D
var poi_film_mat: StandardMaterial3D
var film_peek := 0.0 # 0〜1：宙のポイの下に玉がかくれている間、網を透かす
var poi_rim: MeshInstance3D
var orbs: Array = []
var total_tonight := 0
var caught_count := 0

var poi_type := ""
var durability := 1.0
var dura_by := {} # ポイの種類ごとの残り（切りかえても回復しない）
var perfect_streak := 0
var tag_n := -1
var rim_col := Color.WHITE
var pressed := false
var last_ground := Vector3.ZERO
## ポイの動き：指（マウス）の点 aim を、ばねのように追いかける（ScoopAssist.follow）。水の中では近くの玉へ、そっと寄る
var aim := Vector3(0, 0, 1.2)
var poi_vel := Vector2.ZERO
var press_ms := 0 # 押した時刻（タップの判定）
var press_at := Vector2.ZERO
var auto_orb: Orb3D = null # タップした玉（ポイがすべっていって、すくう）
var auto_t := 0.0
var guide: MeshInstance3D # 水面のポイの輪（すくえる広さ）
var guide_mat: StandardMaterial3D
var shade: MeshInstance3D # 持ち上げているときの、水面の影
var target_ring: MeshInstance3D # すくえる玉の、光る輪
var target_mat: StandardMaterial3D
var now_label: Label3D # 「いま！」
var peek_ring: MeshInstance3D # 宙のポイの下にかくれた玉の、ポイごしに見える光る輪
var peek_mat: StandardMaterial3D
var touch_input := false # 指で遊んでいる（指の下にも玉を浮かべない）
var busy := false
var ripple_t := 10.0
var night_budget := 0 # 今夜、水面に出る玉の数の上限
var net_scoops := {} # ポイの種類ごとの、今夜すくった数
var night_t := 0.0 # すくっている時間（まとめ・演出の間は数えない）
var want_home := false # すくっている途中に「帰る」を押した（終わったら帰る）

var font_bold: FontFile
var font_black: FontFile
var jar_row: HBoxContainer
var poi_label: Label
var dura_bar: ProgressBar
var hint: Label
var tip: Label
var banner: Label
var net_bar: HBoxContainer
var flash: ColorRect
var drops: CPUParticles3D
var stars: CPUParticles3D
var sfx := {}
var ambience: AudioStreamPlayer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	font_bold = load("res://assets/fonts/ZenMaruGothic-Bold.ttf")
	font_black = load("res://assets/fonts/ZenMaruGothic-Black.ttf")
	_build_world()
	_build_ui()
	_build_audio()
	# 休みの日のポイ 1 本（島の夜のカードを通らずに来たときも）
	if not Onboarding.at("scoop"):
		GameState.grant_rest_net()
	# はじめての夜（Onboarding）は、ゆっくりで逃げない玉が 3 つ（はじめの 1 つは必ずおばネコ）
	var list := Onboarding.tutorial_orbs() if Onboarding.at("scoop") else GameState.tonight_orbs()
	if DemoRoute.active:
		list = DemoRoute.scoop_orbs() # 3 分デモ：おばネコの玉がひとつ（中身は特別なレア）
	total_tonight = list.size()
	night_budget = list.size() if _fixed_night() else maxi(list.size(), mini(list.size() + BUDGET_EXTRA, _nets_left() * NET_SCOOPS))
	touch_input = DisplayServer.is_touchscreen_available()
	for d in list:
		_spawn_orb(d)
	_pick_poi()
	_clear_hand_path()
	_refresh_ui()
	_show_hand()
	# 今夜の川の様子を、はじめに知らせる
	var kind := GameState.night_kind()
	if kind != "" and GameState.day >= 1:
		var kt: Array = GameState.NIGHT_KIND_TEXT[kind]
		await get_tree().create_timer(0.5).timeout
		var pn := PanelContainer.new()
		pn.add_theme_stylebox_override("panel", _pill(Color(0.06, 0.08, 0.2, 0.8), 20))
		pn.position = Vector2(60, 190)
		pn.size = Vector2(240, 0)
		pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pn)
		var vv := VBoxContainer.new()
		pn.add_child(vv)
		vv.add_child(_text(kt[0], 22, Color("fff2a8"), font_black))
		vv.add_child(_text(kt[1], 14, Color("e8ecff")))
		var tw := create_tween()
		tw.tween_interval(2.4)
		tw.tween_property(pn, "modulate:a", 0.0, 0.5)
		tw.tween_callback(pn.queue_free)


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
	View3D.fit(box, vp)
	world = Node3D.new()
	vp.add_child(world)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b1026")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a4a8a")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 1.2
	env.glow_strength = 1.2
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, -30, 0)
	moon.light_color = Color("9fb4ff")
	moon.light_energy = 0.35
	world.add_child(moon)

	cam = Camera3D.new()
	cam.position = Vector3(0, 2.6, 4.6)
	cam.fov = 50
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.2, -1.1))
	cam_base = cam.transform

	# 岸（草地）
	var bank := MeshInstance3D.new()
	var bp := PlaneMesh.new()
	bp.size = Vector2(30, 30)
	bank.mesh = bp
	bank.position = Vector3(0, -0.02, 0)
	bank.material_override = Obake3D.toon(Color("1f3b2e"), 0.05)
	world.add_child(bank)

	# 水面（楕円の池）
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

	# 縁の石
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

	# 草むら
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
		g.material_override = Obake3D.toon(Color("2f5a3c"), 0.1)
		world.add_child(g)

	# 夜空：月と星
	var moon_m := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 0.9
	mm.height = 1.8
	moon_m.mesh = mm
	moon_m.material_override = _glow_mat(Color("fff1c8"), 2.2)
	moon_m.position = Vector3(4.5, 7.5, -16)
	world.add_child(moon_m)
	var sky_stars := CPUParticles3D.new()
	sky_stars.amount = 120
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
	# 遠くの木立
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
		tr.material_override = Obake3D.toon(Color("132a26"), 0.05)
		world.add_child(tr)

	# 灯籠
	for p in [Vector3(-2.2, 0, -1.6), Vector3(2.3, 0, -2.2)]:
		_lantern(Vector3(p.x * 1.35, 0, p.z * 1.3))

	# ほたる
	var flies := CPUParticles3D.new()
	flies.amount = 140 if GameState.night_kind() == "fireflies" else 50
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
	world.add_child(flies)

	# しぶきと星
	drops = _burst(Color("cfe8ff"), 24, 0.7, Vector3(0, -6, 0), 1.2, 2.4)
	stars = _burst(Color("fff2a8"), 40, 1.1, Vector3(0, -1.5, 0), 1.0, 2.2)

	# 雨・雪の夜は、川べりにも降る
	var wt: String = GameState.today().weather
	if wt == "雨" or wt == "雷" or wt == "雪":
		var snow := wt == "雪"
		var rp := CPUParticles3D.new()
		rp.amount = 70 if snow else 140
		rp.lifetime = 5.0 if snow else 1.1
		rp.preprocess = rp.lifetime
		rp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		rp.emission_box_extents = Vector3(4, 0.2, 3.5)
		rp.position = Vector3(0, 4.5, 0)
		rp.direction = Vector3.DOWN
		rp.spread = 40 if snow else 4
		rp.gravity = Vector3(0, -0.3 if snow else -9.0, 0)
		rp.initial_velocity_min = 0.3 if snow else 2.0
		rp.initial_velocity_max = 0.6 if snow else 3.0
		var rm: Mesh
		if snow:
			var sm2 := SphereMesh.new()
			sm2.radius = 0.03
			sm2.height = 0.06
			rm = sm2
		else:
			var bm2 := BoxMesh.new()
			bm2.size = Vector3(0.01, 0.2, 0.01)
			rm = bm2
		rp.mesh = rm
		var rmat := StandardMaterial3D.new()
		rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		rmat.albedo_color = Color(1, 1, 1, 0.85) if snow else Color(0.75, 0.85, 1.0, 0.45)
		rp.material_override = rmat
		world.add_child(rp)

	poi = _make_poi()
	world.add_child(poi)
	poi.position = Vector3(0, 0.45, 1.2)
	_build_guides()


## 水面の目じるし：ポイの輪（すくえる広さ）・持ち上げているときの影・すくえる玉の光る輪・「いま！」
func _build_guides() -> void:
	guide = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 1.0
	t.rings = 48
	guide.mesh = t
	guide_mat = StandardMaterial3D.new()
	guide_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	guide_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	guide_mat.albedo_color = Color(1, 1, 1, 0.35)
	guide.material_override = guide_mat
	guide.scale = Vector3(1, 0.02, 1) * _hit_r()
	world.add_child(guide)
	shade = MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = POI_R * 0.95
	c.bottom_radius = POI_R * 0.95
	c.height = 0.002
	shade.mesh = c
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0.02, 0.04, 0.12, 0.35)
	shade.material_override = sm
	world.add_child(shade)
	target_ring = MeshInstance3D.new()
	var tt := TorusMesh.new()
	tt.inner_radius = 0.2
	tt.outer_radius = 0.25
	target_ring.mesh = tt
	target_mat = _glow_mat(Color.WHITE, 1.6)
	target_ring.material_override = target_mat
	target_ring.visible = false
	world.add_child(target_ring)
	peek_ring = MeshInstance3D.new()
	var pt := TorusMesh.new()
	pt.inner_radius = 0.19
	pt.outer_radius = 0.24
	peek_ring.mesh = pt
	peek_mat = _glow_mat(Color(1, 1, 1, 0.7), 1.2)
	peek_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	peek_mat.no_depth_test = true # ポイの網の上に描く
	peek_mat.render_priority = 5
	peek_ring.material_override = peek_mat
	peek_ring.visible = false
	world.add_child(peek_ring)
	now_label = Kit.label3d(tr("SCOOP_NOW"), 44, Color("ffe27a"))
	now_label.pixel_size = 0.004
	now_label.no_depth_test = true
	now_label.render_priority = 10
	now_label.visible = false
	world.add_child(now_label)


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
	poi_rim = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = POI_R - 0.025
	t.outer_radius = POI_R + 0.015
	poi_rim.mesh = t
	n.add_child(poi_rim)
	var film := MeshInstance3D.new()
	var f := CylinderMesh.new()
	f.top_radius = POI_R - 0.01
	f.bottom_radius = POI_R - 0.01
	f.height = 0.004
	film.mesh = f
	poi_film_mat = StandardMaterial3D.new()
	poi_film_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	poi_film_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	poi_film_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	poi_film_mat.albedo_color = Color(1, 1, 1, 0.45)
	film.material_override = poi_film_mat
	n.add_child(film)
	var handle := MeshInstance3D.new()
	var h := BoxMesh.new()
	h.size = Vector3(0.06, 0.03, 0.34)
	handle.mesh = h
	handle.position = Vector3(0.12, 0.05, POI_R + 0.17)
	handle.rotation = Vector3(-0.35, -0.4, 0)
	handle.material_override = Obake3D.toon(Color("e85a4f"), 0.2)
	n.add_child(handle)
	return n


func _spawn_orb(d: Dictionary) -> void:
	var o := Orb3D.new().setup(d)
	_place_orb(o)
	world.add_child(o)
	orbs.append(o)
	_orb_tag(o)


## 画面の中の水面に置く（見えない所から始めない）。ポイの陰・指の下・手の見本の下はよけて、なるべくほかの玉とも重ならない、空いた水面をえらぶ
func _place_orb(o: Orb3D) -> void:
	var avoid := _spawn_avoid(o)
	var soft: Array = []
	for ob in orbs:
		if ob != o and is_instance_valid(ob):
			var sp := View3D.unproject(cam, ob.position)
			soft.append([sp, sp, ORB_PX * 1.5])
	var pts: Array = []
	var cands: Array = []
	for i in 60:
		var a := randf() * TAU
		var p := Vector3(cos(a) * WATER_RX * 0.6 * randf(), 0.0, sin(a) * WATER_RZ * 0.6 * randf())
		var sp := View3D.unproject(cam, p)
		if ORB_SAFE.has_point(sp):
			pts.append(p)
			cands.append(sp)
	var k := ScoopAssist.pick_spawn(cands, avoid, soft)
	o.position = pts[k] if k >= 0 else Vector3(0, 0, 0.2)


## 新しい玉が、必ずよける所（画面の上のカプセル [a, b, 半径]）：ポイの陰・指の下・手の見本（その玉が見本の玉でなければ）
func _spawn_avoid(o: Orb3D = null) -> Array:
	var w := Vector3(poi.position.x, 0.0, poi.position.z)
	var ws := View3D.unproject(cam, w)
	var hr := View3D.unproject(cam, w + Vector3(_hit_r(), 0, 0)).distance_to(ws)
	# 宙のポイ（持ち上げているとき）から、水面の当たりの輪まで
	var out: Array = [[View3D.unproject(cam, poi.position), ws, hr + ORB_PX]]
	if touch_input:
		out.append([ws, ws + Vector2(0, THUMB_PX), THUMB_R + ORB_PX])
	if hand_orb != null and is_instance_valid(hand_orb) and orbs.has(hand_orb) and hand_orb != o:
		out.append(_hand_zone(hand_orb))
	return out


const ORB_TAG := {"register": "ピッと動いて、止まる", "dish": "ふわふわ。逃げない", "hall": "まっすぐ滑って逃げる", "kitchen": "はねる", "stock": "重い。動かない", "rare": "輪をかいて泳ぐ"}


## その色の玉にはじめて会ったときだけ、玉の上に性格をひとこと
func _orb_tag(o: Orb3D) -> void:
	if Onboarding.at("scoop"):
		return # はじめての夜は、相棒の説明（コーチ）だけ。玉の上のひとことは次の夜から
	var ck: String = o.data.get("content", {}).get("kind", "obake")
	if ck != "obake" and not GameState.tut.has("hint_" + ck):
		GameState.tut["hint_" + ck] = true
		tag_n += 1
		var hl := Kit.label3d(tr({"material": "中に、島の材料", "cloth": "中に、服", "vehicle": "中に、乗り物"}.get(ck, "中に、島の材料")), 30, Color("fff2a8"))
		hl.pixel_size = 0.0035
		hl.position = Vector3(0, 0.5, 0)
		hl.visible = false
		o.add_child(hl)
		var tw0 := create_tween()
		tw0.tween_interval(0.8 + tag_n * 2.4)
		tw0.tween_callback(func(): if is_instance_valid(hl): hl.visible = true)
		tw0.tween_interval(2.3)
		tw0.tween_callback(func(): if is_instance_valid(hl): hl.queue_free())
		return
	var t: String = o.data.type
	if not ORB_TAG.has(t) or GameState.tut.has("orb_" + t) or GameState.day < 1:
		return
	GameState.tut["orb_" + t] = true
	tag_n += 1
	var l := Kit.label3d(ORB_TAG[t], 30, GameState.TYPE_COLOR.get(t, Color.WHITE).lightened(0.3))
	l.pixel_size = 0.0035
	l.position = Vector3(0, 0.5, 0)
	l.visible = false
	o.add_child(l)
	# ひとつずつ順番に出す（重ならないように）
	var tw := create_tween()
	tw.tween_interval(0.8 + tag_n * 2.4)
	tw.tween_callback(func(): if is_instance_valid(l): l.visible = true)
	tw.tween_interval(2.3)
	tw.tween_callback(func(): if is_instance_valid(l): l.queue_free())


# ---------- UI ----------

func _pill(bg: Color, radius := 22) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	s.shadow_color = Color(Tokens.SHADOW, 0.3)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	return s


func _text(t: String, size: int, color := Color.WHITE, font: FontFile = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font if font else font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _build_ui() -> void:
	var top := VBoxContainer.new()
	top.position = Vector2(16, 18)
	top.size = Vector2(328, 90)
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	top.add_child(row)
	var jp := PanelContainer.new()
	jp.add_theme_stylebox_override("panel", _pill(Color(0.06, 0.08, 0.2, 0.7)))
	jp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var jv := HBoxContainer.new()
	jv.add_theme_constant_override("separation", 6)
	jv.add_child(_text("今夜のすくい", 14, Color("e8ecff")))
	jar_row = HBoxContainer.new()
	jar_row.add_theme_constant_override("separation", 4)
	jv.add_child(jar_row)
	jp.add_child(jv)
	row.add_child(jp)
	var home := Button.new()
	home.text = "帰る"
	home.add_theme_font_override("font", font_bold)
	home.add_theme_font_size_override("font_size", 14)
	for k in ["normal", "hover", "pressed"]:
		home.add_theme_stylebox_override(k, _pill(Color(1, 1, 1, 0.9)))
	home.add_theme_color_override("font_color", Color("1a1f3a"))
	home.add_theme_color_override("font_hover_color", Color("1a1f3a"))
	home.pressed.connect(_finish)
	row.add_child(home)

	var pp := PanelContainer.new()
	pp.add_theme_stylebox_override("panel", _pill(Color(0.06, 0.08, 0.2, 0.7)))
	pp.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 8)
	poi_label = _text("", 14, Color("e8ecff"))
	ph.add_child(poi_label)
	dura_bar = ProgressBar.new()
	dura_bar.custom_minimum_size = Vector2(110, 10)
	dura_bar.show_percentage = false
	dura_bar.max_value = 1.0
	dura_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.2)
	bg.set_corner_radius_all(5)
	dura_bar.add_theme_stylebox_override("background", bg)
	ph.add_child(dura_bar)

	pp.add_child(ph)
	top.add_child(pp)

	hint = _text("押して、玉の下へ → 離す", 14, Color(1, 1, 1, 0.85))
	tip = _text("縁が金色で離すと、ぴったり", 12, Color("c9bdf5"))
	tip.position = Vector2(0, 116)
	tip.size = Vector2(360, 20)
	add_child(tip)
	# はじめての夜は、下のヒントひとつだけ
	tip.visible = GameState.day >= 1
	hint.position = Vector2(0, 596)
	hint.size = Vector2(360, 24)
	add_child(hint)

	# ポイの選択バー（下に横並び。大きく押せる）
	var bar_bg := PanelContainer.new()
	bar_bg.add_theme_stylebox_override("panel", _pill(Color(0.06, 0.08, 0.2, 0.72), 20))
	bar_bg.position = Vector2(10, 530)
	bar_bg.size = Vector2(340, 62)
	add_child(bar_bg)
	var bar_sc := ScrollContainer.new()
	bar_sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bar_sc.custom_minimum_size = Vector2(322, 50)
	bar_bg.add_child(bar_sc)
	net_bar = HBoxContainer.new()
	net_bar.add_theme_constant_override("separation", 6)
	bar_sc.add_child(net_bar)

	banner = _text("", 36, Color.WHITE, font_black)
	banner.add_theme_color_override("font_outline_color", Color("0b1026"))
	banner.add_theme_constant_override("outline_size", 10)
	banner.position = Vector2(0, 200)
	banner.size = Vector2(360, 120)
	banner.pivot_offset = Vector2(180, 60)
	banner.modulate.a = 0.0
	add_child(banner)

	flash = ColorRect.new()
	flash.color = Color("fff6d8")
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate.a = 0.0
	add_child(flash)


func _build_audio() -> void:
	for n in ["splash", "lift", "chime", "tear", "sparkle"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/sfx/%s.wav" % n)
		add_child(p)
		sfx[n] = p
	ambience = AudioStreamPlayer.new()
	var loop: AudioStreamWAV = load("res://assets/sfx/river_loop.wav")
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = loop.data.size() / 2
	ambience.stream = loop
	ambience.volume_db = -8
	add_child(ambience)
	ambience.play()


func _play(n: String, pitch := 1.0) -> void:
	var p: AudioStreamPlayer = sfx[n]
	p.pitch_scale = pitch
	p.play()


func _refresh_ui() -> void:
	for c in jar_row.get_children():
		c.queue_free()
	for i in total_tonight:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(14, 14)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(7)
		if i < GameState.orbs.size():
			var o: Dictionary = GameState.orbs[i]
			sb.bg_color = GameState.TYPE_COLOR.get(o.type, Color.WHITE)
		else:
			sb.bg_color = Color(1, 1, 1, 0.22)
		dot.add_theme_stylebox_override("panel", sb)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		jar_row.add_child(dot)
	var left := 0
	for id in GameState.nets:
		left += GameState.nets[id]
	poi_label.text = tr("ポイ ×%d") % left
	dura_bar.value = durability if poi_type != "" else 0.0
	var fill := StyleBoxFlat.new()
	fill.set_corner_radius_all(5)
	fill.bg_color = Color("7bdc6b") if durability > 0.5 else (Color("ffd23f") if durability > 0.25 else Color("ff6b5b"))
	dura_bar.add_theme_stylebox_override("fill", fill)
	var col := Color("dddddd")
	var name := "なし"
	if poi_type != "":
		col = GameState.TYPE_COLOR.get(GameState.NETS[poi_type].type, Color("ffd84d"))
		name = tr(GameState.NETS[poi_type].get("short", "ポイ"))
	_refresh_net_bar()
	if poi_type != "":
		poi_rim.material_override = Obake3D.toon(col, 0.4, 0.4)
		rim_col = col
	poi_film_mat.albedo_color = Color(1, 1, 1, _film_alpha())


## 破れ具合のバーと膜だけ（毎フレーム呼んでも軽い）
func _refresh_dura() -> void:
	dura_bar.value = durability if poi_type != "" else 0.0
	var c := Color("7bdc6b") if durability > 0.5 else (Color("ffd23f") if durability > 0.25 else Color("ff6b5b"))
	var fill := dura_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill and fill.bg_color != c:
		fill.bg_color = c
	poi_film_mat.albedo_color = Color(1, 1, 1, _film_alpha())


func _pick_poi() -> void:
	poi_type = ""
	# 種類つきのポイを先に使う（今夜の仕事の玉に合う）
	for id in ["kira", "receipt", "bubble", "tray", "pan", "box", "plain"]:
		if GameState.nets.get(id, 0) > 0:
			poi_type = id
			break
	durability = dura_by.get(poi_type, 1.0)


## ポイを選ぶ（下のバー）。切りかえても、使いかけの破れ具合はそのまま
func _select_poi(id: String) -> void:
	if busy or pressed or id == poi_type or GameState.nets.get(id, 0) <= 0:
		return
	dura_by[poi_type] = durability
	poi_type = id
	durability = dura_by.get(id, 1.0)
	Kit.play(self, "tap", 1.1)
	_refresh_ui()


## 下のバー：持っているポイを種類ごとに（色・名前・本数）。選んでいるものは白い縁
func _refresh_net_bar() -> void:
	if net_bar == null:
		return
	for c in net_bar.get_children():
		c.queue_free()
	for id in GameState.NETS:
		var n: int = GameState.nets.get(id, 0)
		if n <= 0:
			continue
		var col: Color = GameState.TYPE_COLOR.get(GameState.NETS[id].type, Color("ffd84d"))
		var b := Button.new()
		b.custom_minimum_size = Vector2(86, 50)
		b.text = "%s\n×%d" % [tr(GameState.NETS[id].get("short", "ポイ")), n]
		b.add_theme_font_override("font", font_bold)
		b.add_theme_font_size_override("font_size", 12)
		for k in ["normal", "hover", "pressed", "focus"]:
			var st := _pill(col, 16)
			if id == poi_type:
				st.border_color = Color.WHITE
				st.set_border_width_all(3)
			else:
				st.bg_color = col.darkened(0.25)
			b.add_theme_stylebox_override(k, st)
		b.add_theme_color_override("font_color", Color("1a1f3a"))
		b.add_theme_color_override("font_hover_color", Color("1a1f3a"))
		b.add_theme_color_override("font_pressed_color", Color("1a1f3a"))
		var nid: String = id
		b.pressed.connect(func(): _select_poi(nid))
		net_bar.add_child(b)


# ---------- 入力 ----------

func _ground(p: Vector2) -> Vector3:
	p = p.clamp(POI_AREA.position, POI_AREA.end) # 池の奥（石と木の陰）・下のバーの陰へは行かない
	var from := cam.project_ray_origin(View3D.to_vp(cam, p))
	var dir := cam.project_ray_normal(View3D.to_vp(cam, p))
	if absf(dir.y) < 1e-4:
		return last_ground
	var t := -from.y / dir.y
	var g := from + dir * t
	# 池の外には出さない
	var e := Vector2(g.x / WATER_RX, g.z / WATER_RZ)
	if e.length() > 0.92:
		e = e.normalized() * 0.92
		g = Vector3(e.x * WATER_RX, 0, e.y * WATER_RZ)
	return g


## 押す → 水に入る（押した所へ）。押したまま動かす → ポイが、なめらかについてくる。離す → すくい上げる。
## さっと押して離した（タップ）のが玉のそばなら、ポイが玉まですべって、すくう。
## 一本の指は、マウスとして届く（emulate_mouse_from_touch）ので、指の知らせ（ScreenTouch/Drag）は使わない（二重に動かさない）
func _gui_input(event: InputEvent) -> void:
	if busy or auto_orb != null:
		return
	var pos := Vector2.ZERO
	var down := false
	var up := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		down = event.pressed
		up = not event.pressed
	elif event is InputEventMouseMotion:
		pos = event.position
	else:
		return
	if up:
		if pressed and event.is_canceled():
			_let_go() # 指の取り消し（電話・ジェスチャー）：タップとみなさず、そのまま持ち上げる
		elif pressed:
			pressed = false
			_release(pos)
		return
	if pos.y < 120:
		return
	var g := _ground(pos)
	if down:
		touch_input = event.device == InputEvent.DEVICE_ID_EMULATION or DisplayServer.is_touchscreen_available()
		if poi_type == "":
			_banner("ポイがない。今夜はおしまい", Color("ffb3a8"))
			return
		pressed = true
		press_ms = Time.get_ticks_msec()
		press_at = pos
		_hide_hand()
		last_ground = g
		aim = g
		# 押した所へ、そのまま入れる（そこから先は、なめらかに追いかける）
		poi.position = Vector3(g.x, -0.04, g.z)
		poi_vel = Vector2.ZERO
		_ripple(g)
		_play("splash", randf_range(0.9, 1.1))
		hint.text = "玉の下まで、そっと"
	else:
		aim = g
		last_ground = g


## 指（マウス）がゲームの外へ出た・ウィンドウから離れた：押したままにしない（ポイを持ち上げる）
func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_MOUSE_EXIT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_let_go()


func _let_go() -> void:
	if pressed and not busy and auto_orb == null:
		pressed = false
		_lift()


## 離した：タップで、近くに玉があり、まだ輪の中に入っていなければ、玉まですべらせる。それ以外は、すくい上げる
func _release(pos: Vector2) -> void:
	var held := (Time.get_ticks_msec() - press_ms) / 1000.0
	if ScoopAssist.is_tap(held, pos.distance_to(press_at)) and _in_range() == null:
		var scr: Array = []
		for o in orbs:
			scr.append(View3D.unproject(cam, o.position))
		var k := ScoopAssist.tap_pick(pos, scr)
		if k >= 0:
			auto_orb = orbs[k]
			auto_t = 0.0
			pressed = true # 水の中を、玉まですべる
			return
	_lift()


## すくえる輪（見えない当たり）の中の、いちばん近い玉（無ければ null）
func _in_range() -> Orb3D:
	var best: Orb3D = null
	var bd := _hit_r()
	for o in orbs:
		var d := Vector2(o.position.x - poi.position.x, o.position.z - poi.position.z).length()
		if d < bd:
			bd = d
			best = o
	return best


func _hit_r() -> float:
	return ScoopAssist.hit_radius(GameState.total_scooped, GameState.day)


func _wear() -> float:
	return ScoopAssist.wear_scale(GameState.total_scooped, GameState.day)


func _ripple(g: Vector3) -> void:
	ripple_t = 0.0
	water_mat.set_shader_parameter("ripple_pos", g)


# ---------- すくい上げ ----------

func _lift() -> void:
	busy = true
	auto_orb = null
	target_ring.visible = false
	now_label.visible = false
	var target: Orb3D = null
	var best := _hit_r()
	for o in orbs:
		var d := Vector2(o.position.x - poi.position.x, o.position.z - poi.position.z).length()
		if d < best:
			best = d
			target = o
	if target == null:
		var tw := create_tween()
		tw.tween_property(poi, "position:y", 0.45, 0.25)
		_play("lift")
		drops.position = poi.position
		drops.restart()
		drops.emitting = true
		await tw.finished
		perfect_streak = 0
		if GameState.tut.has("scoop") or GameState.total_scooped > 0:
			durability -= 0.03 / GameState.poi_strength() * _wear()
		if durability <= 0:
			_tear(null)
			return
		hint.text = "縁が光ったら、離す"
		_refresh_ui()
		busy = false
		return

	var pt: String = GameState.NETS[poi_type].type
	var match_mult := 1.0
	if pt == target.data.type:
		match_mult = 0.55 # 仕事の種類が合うポイは、その玉に強い
	elif pt != "any":
		match_mult = 0.85
	var cost: float = target.data.weight * match_mult / GameState.poi_strength() * _wear()
	# 玉の真下で離すと「ぴったり」：破れにくく、3回続くとめぐみ
	var perfect := best < POI_R * 0.4
	if perfect:
		cost *= 0.5
	var will_hold := durability - cost > 0.0
	# はじめての夜の最初の一玉は、かならずすくえる（やり方を覚えるため）
	if not GameState.tut.has("scoop") and GameState.total_scooped == 0:
		will_hold = true
		cost = minf(cost, durability * 0.5)
	target.caught = true
	orbs.erase(target)
	# スローモーションで持ち上げる
	_play("lift", 0.8)
	Engine.time_scale = 0.3
	var cam_to := cam_base
	cam_to.origin = cam_base.origin.lerp(poi.position + Vector3(0, 1.6, 1.3), 0.45)
	var tw := create_tween().set_parallel()
	tw.tween_property(cam, "transform", cam_to.looking_at(poi.position, Vector3.UP), 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(poi, "position:y", 0.55, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(target, "position", Vector3(poi.position.x, 0.58, poi.position.z), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	drops.position = poi.position
	drops.restart()
	drops.emitting = true
	await tw.finished
	if not will_hold:
		Engine.time_scale = 1.0
		target.caught = false
		_tear(target)
		return
	durability -= cost
	# 決まった瞬間
	_flash(0.5)
	Sfx.catch(self, perfect)
	if target.data.rare:
		_play("sparkle")
	Input.vibrate_handheld(40)
	stars.position = target.position
	stars.restart()
	stars.emitting = true
	Engine.time_scale = 1.0
	GameState.orbs.append({"type": target.data.type, "rare": target.data.rare, "content": target.data.get("content", {})})
	GameState.total_scooped += 1
	GameState.tonight_caught += 1
	if GameState.tonight_caught >= 3:
		GameState.goal("scoop3")
	if GameState.NETS[poi_type].type == target.data.type:
		GameState.goal("match")
	caught_count += 1
	net_scoops[poi_type] = int(net_scoops.get(poi_type, 0)) + 1
	_first_catch_cheer()
	if perfect:
		perfect_streak += 1
		var msg := "ぴったり！"
		if perfect_streak >= 3:
			msg = tr("ぴったり ×%d\nめぐみ +3") % perfect_streak
			GameState.growth += 3
			GameState._recalc_level()
		_banner(msg if not target.data.rare else msg + tr("\nふしぎな光…"), Color("ffe27a"))
		_play("sparkle")
	else:
		perfect_streak = 0
		_banner("すくった！" if not target.data.rare else "すくった！\nふしぎな光…", Color("fff2a8"))
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(cam, "transform", cam_base, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw2.tween_property(target, "position", cam.project_position(View3D.to_vp(cam, Vector2(120, 40)), 2.0), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw2.tween_property(target, "scale", Vector3.ONE * 0.3, 0.7)
	await tw2.finished
	target.queue_free()
	poi.position.y = 0.45
	_wear_out()
	_top_up()
	_refresh_ui()
	hint.text = "押して、玉の下へ → 離す"
	if orbs.is_empty() or poi_type == "" or caught_count >= night_budget:
		# 今夜はおしまい（待つ間も、もうすくわない）
		await get_tree().create_timer(0.6).timeout
		busy = false
		_drift_away()
		return
	busy = false


## 1 本のポイで NET_SCOOPS 個すくったら、そのポイはくたくた（破れなくても）。つぎのポイへ
func _wear_out() -> void:
	if _fixed_night() or poi_type == "" or int(net_scoops.get(poi_type, 0)) < NET_SCOOPS:
		return
	GameState.use_net(poi_type)
	net_scoops.erase(poi_type)
	dura_by.erase(poi_type)
	_pick_poi()
	_banner("ポイがくたくた。つぎのポイへ" if poi_type != "" else "ポイがくたくた", Color("ffe2b8"))


## 決まった玉だけの夜（はじめての夜・3 分デモ）。玉は足さず、ポイも時間も数えない
func _fixed_night() -> bool:
	return Onboarding.at("scoop") or DemoRoute.active


func _nets_left() -> int:
	var n := 0
	for id in GameState.nets:
		n += int(GameState.nets[id])
	return n


## 今夜はおしまい：残りの玉は、川へ流れていく。それから、まとめ
func _drift_away() -> void:
	if GameState.scooped_tonight:
		return
	pressed = false
	auto_orb = null
	_hide_hand()
	if not orbs.is_empty():
		busy = true
		_banner("のこりの玉は、川へ流れていった", Color("c9d2ff"))
		var tw := create_tween().set_parallel()
		for o: Orb3D in orbs:
			var away := Vector3(o.position.x, 0.0, o.position.z).normalized()
			if away == Vector3.ZERO:
				away = Vector3.RIGHT
			tw.tween_property(o, "position", o.position + away * 1.4, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
			tw.tween_property(o, "scale", Vector3.ONE * 0.05, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		await tw.finished
		for o in orbs:
			o.queue_free()
		orbs.clear()
		busy = false
	_finish()


func _tear(target: Orb3D) -> void:
	busy = true
	pressed = false
	perfect_streak = 0
	Sfx.catch_break()
	_play("tear")
	Input.vibrate_handheld(80)
	_banner("やぶれた…", Color("ffb3a8"))
	GameState.nets[poi_type] -= 1
	dura_by.erase(poi_type)
	var tw := create_tween().set_parallel()
	tw.tween_property(poi_film_mat, "albedo_color:a", 0.0, 0.2)
	tw.tween_property(cam, "transform", cam_base, 0.5)
	if target:
		tw.tween_property(target, "position", Vector3(target.position.x, 0.0, target.position.z), 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		orbs.append(target)
	await tw.finished
	if target:
		_ripple(target.position)
		_play("splash", 0.8)
	await get_tree().create_timer(0.6).timeout
	_pick_poi()
	poi.position.y = 0.45
	_refresh_ui()
	busy = false
	if poi_type == "":
		hint.text = "ポイを使い切った"
		await get_tree().create_timer(0.8).timeout
		_drift_away()
	else:
		hint.text = "新しいポイ。こんどはそっと"


# ---------- 毎フレーム ----------

## ポイの動き・目じるし・玉の動き（毎フレーム）
func _process(delta: float) -> void:
	ripple_t += delta
	# 「帰る」をすくっている途中に押していたら、終わったところで帰る。時間の目安を過ぎたら、今夜はおしまい
	if not busy and not GameState.scooped_tonight:
		if want_home:
			want_home = false
			_finish()
		elif not _fixed_night():
			night_t += delta
			if night_t >= NIGHT_SEC and auto_orb == null:
				_drift_away()
	if not busy:
		_move_poi(delta)
	_sync_guides(delta)
	_sync_hand(delta)
	# ポイの下に玉があると、縁が光る（真ん中なら金色）
	if pressed and not busy and poi_rim and poi_rim.material_override:
		var near := 99.0
		for o in orbs:
			near = minf(near, Vector2(o.position.x - poi.position.x, o.position.z - poi.position.z).length())
		var m := poi_rim.material_override as StandardMaterial3D
		if near < POI_R * 0.4:
			m.emission_enabled = true
			m.emission = Color("ffd23f")
			m.emission_energy_multiplier = 2.2
			hint.text = "ぴったり。いま離す！"
			hint.add_theme_color_override("font_color", Color("ffe27a"))
		elif near < _hit_r():
			m.emission_enabled = true
			m.emission = Color("ffffff")
			m.emission_energy_multiplier = 0.9
			hint.text = "いま離せば、すくえる"
			hint.add_theme_color_override("font_color", Color.WHITE)
		else:
			m.emission = rim_col
			m.emission_energy_multiplier = 0.4
			hint.text = "押したまま、玉の下へ"
			hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	water_mat.set_shader_parameter("ripple_t", ripple_t)
	var ps: Array[Vector4] = []
	var cs: Array[Vector4] = []
	for i in 6:
		if i < orbs.size():
			var ob: Orb3D = orbs[i]
			var c: Color = ob.light.light_color
			ps.append(Vector4(ob.position.x, 0, ob.position.z, 1.0))
			cs.append(Vector4(c.r, c.g, c.b, 1))
		else:
			ps.append(Vector4(100, 0, 100, 0))
			cs.append(Vector4(0, 0, 0, 0))
	water_mat.set_shader_parameter("orb_pos", ps)
	water_mat.set_shader_parameter("orb_col", cs)
	for o: Orb3D in orbs:
		if o.caught:
			continue
		# 玉にも性格がある（色＝仕事の種類）
		#  レジ：ピッと急に動いて止まる／泡：ふわふわ、あまり逃げない／お盆：まっすぐ滑る
		#  キッチン：小刻みにはねる／品出し：重くて、ほとんど動かない／虹：ゆっくり輪をかく
		var t: String = o.data.type
		var noise: float = {"hall": 0.15, "stock": 0.25, "dish": 0.8, "kitchen": 1.2}.get(t, 0.6)
		var flee: float = {"dish": 0.4, "stock": 0.1, "hall": 1.3, "register": 1.2}.get(t, 1.0)
		var vmax: float = {"stock": 0.45, "dish": 0.8, "hall": 1.25}.get(t, 1.0)
		var steer := Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)) * delta * noise
		if t == "rare":
			steer += Vector3(-o.position.z, 0, o.position.x).normalized() * 0.4 * delta
		# 水中でポイが近くにあると、少し逃げる（はじめのうちは、あまり逃げない。タップで向かっている玉は逃げない）
		if ScoopAssist.beginner(GameState.total_scooped, GameState.day):
			flee *= 0.5
		if pressed and o != auto_orb:
			var away: Vector3 = o.position - poi.position
			away.y = 0
			var d: float = away.length()
			if d < 0.7 and d > 0.001:
				steer += away.normalized() * (0.7 - d) * flee * delta
		var cap: float = 0.23 * vmax
		if o.data.get("easy", false):
			cap *= 0.3 # はじめての夜の玉
		if t == "register":
			var dt: float = o.get_meta("dash", randf() * 2.0) - delta
			if dt <= 0:
				dt = randf_range(1.4, 2.4)
				o.vel += Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * 0.5
			o.set_meta("dash", dt)
			cap *= 1.0 if dt > 1.1 else 2.2
			o.vel *= 1.0 - 1.5 * delta
		o.vel = (o.vel + steer).limit_length(cap)
		o.position += o.vel * delta
		if t == "kitchen":
			o.hop = absf(sin(ripple_t * 7.0 + o.position.x * 5.0)) * 0.07
		var e: Vector2 = Vector2(o.position.x / WATER_RX, o.position.z / WATER_RZ)
		if e.length() > 0.8:
			o.vel -= Vector3(e.x, 0, e.y).normalized() * 0.6 * delta * 10.0
		o.position.y = 0.0
		_keep_visible(o)


## ポイを動かす：指の点（水の中なら、近くの玉へ少し寄せた点）を、ばねで追いかける。速く動かすほど破れやすい
func _move_poi(delta: float) -> void:
	var tgt := Vector2(aim.x, aim.z)
	var smooth := 0.06
	if auto_orb != null:
		# タップした玉へ、すべっていく。真下に来たら（または少ししたら）すくい上げる
		if not is_instance_valid(auto_orb) or not orbs.has(auto_orb):
			auto_orb = null
			pressed = false
			return
		auto_t += delta
		tgt = Vector2(auto_orb.position.x, auto_orb.position.z)
		smooth = 0.12
		if Vector2(poi.position.x, poi.position.z).distance_to(tgt) < POI_R * 0.3 or auto_t > 0.9:
			pressed = false
			_lift()
			return
	elif pressed:
		var ops: Array = []
		for o in orbs:
			ops.append(Vector2(o.position.x, o.position.z))
		tgt = ScoopAssist.magnet(tgt, ops, ScoopAssist.MAGNET_R, ScoopAssist.magnet_strength(GameState.total_scooped, GameState.day))
	var r := ScoopAssist.follow(Vector2(poi.position.x, poi.position.z), tgt, poi_vel, smooth, delta)
	var p: Vector2 = r[0]
	poi_vel = r[1]
	var y := -0.04 if pressed else 0.45
	poi.position = Vector3(p.x, lerpf(poi.position.y, y, 1.0 - exp(-18.0 * delta)), p.y)
	if not pressed or auto_orb != null:
		return
	# 水の中で動かすと、少しずつ破れる（はじめのうちは、ほとんど破れない）
	durability -= (0.008 + poi_vel.length() * 0.012) * delta / GameState.poi_strength() * _wear()
	if durability <= 0:
		if not GameState.tut.has("scoop") and GameState.total_scooped == 0:
			durability = 0.3
		else:
			_tear(null)
			return
	_refresh_dura()


## 水面の目じるし：ポイの輪（押している間は明るく、玉が入ったら金色）・影・すくえる玉の輪・「いま！」
func _sync_guides(delta: float) -> void:
	if guide == null:
		return
	var hr := _hit_r()
	guide.position = Vector3(poi.position.x, 0.012, poi.position.z)
	guide.scale = Vector3(hr, 0.02, hr)
	shade.position = Vector3(poi.position.x, 0.008, poi.position.z)
	shade.visible = poi.position.y > 0.1 and poi_type != ""
	guide.visible = poi_type != ""
	var inr: Orb3D = _in_range() if pressed and not busy else null
	var col := Color(1, 1, 1, 0.22)
	if pressed:
		col = Color(1, 1, 1, 0.5)
	if inr != null:
		col = Color(1.0, 0.88, 0.4, 0.8)
	guide_mat.albedo_color = guide_mat.albedo_color.lerp(col, 1.0 - exp(-14.0 * delta))
	# 宙のポイの下に玉がかくれたら、網を透かして、玉のふちを光らせる（輪はそのまま）
	var hid := _hidden_orb()
	var kf := 1.0 - exp(-12.0 * delta)
	film_peek = lerpf(film_peek, 1.0 if hid else 0.0, kf)
	if not busy:
		poi_film_mat.albedo_color.a = _film_alpha()
	peek_ring.visible = hid != null
	if hid:
		var lc: Color = hid.light.light_color
		peek_mat.albedo_color = Color(lc.r, lc.g, lc.b, 0.75)
		peek_mat.emission = lc
		peek_ring.position = Vector3(hid.position.x, 0.12, hid.position.z)
		peek_ring.scale = Vector3.ONE * (1.0 + 0.06 * sin(ripple_t * 4.0))
	target_ring.visible = inr != null
	now_label.visible = inr != null and pressed and auto_orb == null
	if inr != null:
		var pulse := 1.0 + 0.12 * sin(ripple_t * 10.0)
		target_ring.position = Vector3(inr.position.x, 0.03, inr.position.z)
		target_ring.scale = Vector3.ONE * pulse
		var perfect := Vector2(inr.position.x - poi.position.x, inr.position.z - poi.position.z).length() < POI_R * 0.4
		target_mat.albedo_color = Color("ffd23f") if perfect else Color.WHITE
		target_mat.emission = target_mat.albedo_color
		now_label.position = Vector3(poi.position.x, 0.75, poi.position.z)
		now_label.scale = Vector3.ONE * (1.0 + 0.08 * sin(ripple_t * 12.0))


## ポイの網の濃さ（破れかけほど薄い。玉がかくれている間は、もっと透ける）
func _film_alpha() -> float:
	return (0.15 + 0.4 * durability) * (1.0 - 0.85 * film_peek)


## 宙に持ち上げたポイの陰に、画面の上でかくれている玉（無ければ null）
func _hidden_orb() -> Orb3D:
	if busy or poi.position.y < 0.1 or poi_type == "":
		return null
	var ps := View3D.unproject(cam, poi.position)
	var pr := View3D.unproject(cam, poi.position + Vector3(POI_R, 0, 0)).distance_to(ps) + ORB_PX * 0.5
	for o: Orb3D in orbs:
		if not o.caught and View3D.unproject(cam, o.position + Vector3(0, 0.12, 0)).distance_to(ps) < pr:
			return o
	return null


## 玉は画面の中の水面から出さない（出かけたら、池のまん中へ押しもどす）
func _keep_visible(o: Orb3D) -> void:
	var sp := View3D.unproject(cam, o.position)
	if ORB_SAFE.has_point(sp):
		return
	var home := Vector3(0, 0, 0.2)
	for i in 8:
		o.position = o.position.lerp(home, 0.15)
		if ORB_SAFE.has_point(View3D.unproject(cam, o.position)):
			break
	o.vel = (home - o.position).normalized() * 0.1


## 水面の玉が少なくなったら、今夜の玉を足す（空の水面を待たせない。ポイがあって、今夜の玉の数に届くまで）
func _top_up() -> void:
	if Onboarding.at("scoop") or poi_type == "" or DemoRoute.active:
		return
	# 今夜の玉の数（night_budget）に届いたら、もう足さない（あとは水面の玉をすくったら、おしまい）
	while orbs.size() < MIN_ON_SCREEN and total_tonight < night_budget:
		var more: Array = GameState.tonight_orbs()
		if more.is_empty():
			return
		_spawn_orb(more[0])
		total_tonight += 1


# ---------- 演出 ----------

func _banner(text: String, color: Color) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", color)
	banner.modulate.a = 1.0
	banner.scale = Vector2(0.5, 0.5)
	var tw := create_tween()
	tw.tween_property(banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(banner, "modulate:a", 0.0, 0.35)


func _flash(a: float) -> void:
	flash.modulate.a = a
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.35)


func _finish() -> void:
	if GameState.scooped_tonight:
		return
	if busy:
		want_home = true # すくっている途中なら、終わったところで（_process）
		return
	GameState.scooped_tonight = true
	Telemetry.track("scoop_night", {"orbs": mini(caught_count, 500)})
	if GameState.total_scooped > 0:
		GameState.tut["scoop"] = true
	Engine.time_scale = 1.0
	GameState.save()
	busy = true
	# 今夜のまとめ（静かに閉じる）
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _pill(Color(0.06, 0.08, 0.2, 0.9), 24))
	p.position = Vector2(40, 230)
	p.size = Vector2(280, 0)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(_text("今夜のすくい", 16, Color("c9d2ff")))
	v.add_child(_text(tr("1 個") if caught_count == 1 else tr("%d 個") % caught_count, 34, Color.WHITE, font_black))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	for o in GameState.orbs:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(16, 16)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(8)
		sb.bg_color = GameState.TYPE_COLOR.get(o.type, Color.WHITE)
		dot.add_theme_stylebox_override("panel", sb)
		row.add_child(dot)
	v.add_child(row)
	# はじめての夜は、朝を待たずに、ここからそのまま玉をあける（夜の場面は挟まない。Onboarding.next_after）
	var first := Onboarding.at("scoop")
	# ANYTIME（審査・試遊）：朝を待たずに、その場で玉をあける
	var open_now := first or (GameState.ANYTIME and caught_count > 0)
	v.add_child(_text(tr("ONB_NIGHT_OPEN_NOW") if open_now else ("玉は、朝になったらかえる" if caught_count > 0 else "今夜は、水の音だけ"), 13, Color(1, 1, 1, 0.7)))
	var go_next := func():
		if first:
			main.go(Onboarding.next_after("catch", "garden"))
		elif open_now:
			GameState.end_night()
			main.go("hatch" if not GameState.hatched.is_empty() else "garden")
		else:
			main.go("garden")
	var b := Kit.button(tr("ONB_NIGHT_OPEN") if open_now else "島へもどる", Color("8b7bff"), go_next, Color.WHITE, 46, 16)
	v.add_child(b)
	p.pivot_offset = Vector2(140, 100)
	p.scale = Vector2(0.8, 0.8)
	p.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(p, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.25)


## はじめてのすくい：指の動かし方を、半透明の手が 3 拍で見せる（おさえて → すべりこませて → はなす！）。
## 押すまでくり返し、押したらすぐ消える。はじめて玉をすくえたら「いいね！」、そのあと「玉をタップするだけでもOK」を一度だけ。
## 入力はじゃましない（mouse_filter = IGNORE）。玉の中身の説明（相棒の吹き出し）は上に、手は水面に出る
const HAND_BEATS := [1.0, 2.3, 3.2] # 拍の終わり（秒）
const HAND_CYCLE := 3.45
const HAND_CAPS := ["SCOOP_HAND_HOLD", "SCOOP_HAND_SLIDE", "SCOOP_HAND_RELEASE"]
var hand: Control
var hand_art: HandGhost
var hand_group: CanvasGroup # 手をまとめて透かす（重なった部分に、つなぎ目を出さない）
var hand_cap: Label
var hand_t := 0.0
var hand_idle := 0.0
var hand_orb: Orb3D


func _want_hand() -> bool:
	return poi_type != "" and not GameState.tut.has("scoop_hand") and GameState.total_scooped == 0 and not orbs.is_empty()


func _show_hand() -> void:
	if not _want_hand() or hand != null:
		return
	hand = Control.new()
	hand.set_anchors_preset(Control.PRESET_FULL_RECT)
	hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hand)
	hand_group = CanvasGroup.new()
	hand.add_child(hand_group)
	hand_art = HandGhost.new()
	hand_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand_art.size = HandGhost.BOX # CanvasGroup は子の大きさの中だけを描くので、絵の入る大きさにする
	hand_group.add_child(hand_art)
	hand_cap = _text("", 26, Color.WHITE, font_black)
	hand_cap.add_theme_color_override("font_outline_color", Color("0b1026"))
	hand_cap.add_theme_constant_override("outline_size", 10)
	hand_cap.position = Vector2(0, 232)
	hand_cap.size = Vector2(360, 40)
	hand_cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hand.add_child(hand_cap)
	hand_t = 0.0
	_sync_hand(0.0)


func _hide_hand() -> void:
	hand_idle = 0.0
	if hand and is_instance_valid(hand):
		hand.queue_free()
	hand = null


## 手の拍（毎フレーム）。はじめの玉の画面の位置へ向かう。すくう前に手を離して何もしないでいたら、また見せる
func _sync_hand(delta: float) -> void:
	# はじめてのすくいは、手の見本だけ（文字の説明は出さない）
	var show_text := not _want_hand()
	hint.visible = show_text
	tip.visible = show_text
	if hand == null:
		if not pressed and not busy and auto_orb == null and _want_hand():
			hand_idle += delta
			if hand_idle > 3.0:
				_show_hand()
		return
	if orbs.is_empty() or busy:
		hand.visible = false
		return
	hand.visible = true
	hand_t = fmod(hand_t + delta, HAND_CYCLE)
	if hand_orb == null or not is_instance_valid(hand_orb) or not orbs.has(hand_orb):
		_pick_hand_orb()
	var path := _hand_path(hand_orb)
	var a: Vector2 = path[0]
	var b: Vector2 = path[1]
	var t := hand_t
	var beat := 0 if t < HAND_BEATS[0] else (1 if t < HAND_BEATS[1] else (2 if t < HAND_BEATS[2] else 3))
	var at := a
	var press := 0.0
	var ring := -1.0
	var alpha := 1.0
	var lift := 0.0
	match beat:
		0: # おさえて：少し手前から、ふわっと来て、水を押す（指がしずみ、波紋がひろがる）
			var k := clampf(t / 0.35, 0.0, 1.0)
			at = a + Vector2(16, 20) * pow(1.0 - k, 3.0)
			alpha = ease(k, 0.4)
			press = ease(clampf((t - 0.3) / 0.3, 0.0, 1.0), -2.0)
			ring = clampf((t - 0.45) / 0.55, 0.0, 1.0) if t > 0.45 else -1.0
		1: # すべりこませて：押したまま、玉の下へ（ゆっくり出て、ゆっくり止まる）
			var k := (t - HAND_BEATS[0]) / (HAND_BEATS[1] - HAND_BEATS[0])
			at = a.lerp(b, ease(k, -2.2))
			press = 1.0
		2: # はなす！：指が上がる
			var k := (t - HAND_BEATS[1]) / (HAND_BEATS[2] - HAND_BEATS[1])
			at = b
			press = 1.0 - ease(clampf(k * 3.0, 0.0, 1.0), -2.0)
			lift = 26.0 * ease(clampf(k * 2.0, 0.0, 1.0), 0.4)
			alpha = 1.0 - ease(clampf((k - 0.6) / 0.4, 0.0, 1.0), 2.0)
			ring = clampf(k, 0.0, 1.0)
		3:
			alpha = 0.0
	hand_art.position = at - Vector2(0, lift) - HandGhost.TIP
	hand_art.press = press
	hand_art.ring = ring
	hand_art.lifting = beat == 2
	hand_group.modulate.a = alpha * 0.96
	hand_art.queue_redraw()
	# ことばは、水面の上の暗い所（まんなか）に大きく。ポイや玉と重ならないように
	hand_cap.text = tr(HAND_CAPS[mini(beat, 2)])
	hand_cap.modulate.a = alpha


## 見本にする玉：宙のポイの陰にならない玉（ポイからいちばん遠い玉）
func _pick_hand_orb() -> void:
	var ps := View3D.unproject(cam, poi.position)
	var bd := -1.0
	for ob in orbs:
		var d := View3D.unproject(cam, ob.position).distance_to(ps)
		if d > bd:
			bd = d
			hand_orb = ob


## 手の見本の道すじ：押しはじめる所 a → 玉 b（画面の点）
func _hand_path(o: Orb3D) -> Array:
	var b := View3D.unproject(cam, o.position) + Vector2(0, 10)
	var a := (b + Vector2(90, 56)).clamp(Vector2(60, 330), Vector2(300, 460))
	if a.distance_to(b) < 60.0:
		a = (b + Vector2(-90, 56)).clamp(Vector2(60, 330), Vector2(300, 460))
	return [a, b]


## 手の見本がかくす所（指先〜手のひら。a から b へ動く間ぜんぶ）：カプセル [a, b, 半径]
func _hand_zone(o: Orb3D) -> Array:
	var path := _hand_path(o)
	var body := Vector2(12, 28) # 指先から手のひらの真ん中へ
	return [path[0] + body, path[1] + body, 44.0 + ORB_PX]


## はじめてのすくい：手の見本とポイの陰には、ほかの玉を置かない（はじめの玉は、置いたあとで手の見本の玉を決めて、かさなる玉を置き直す）
func _clear_hand_path() -> void:
	if not _want_hand():
		return
	_pick_hand_orb()
	for o: Orb3D in orbs:
		if o == hand_orb:
			continue
		if ScoopAssist.clearance(View3D.unproject(cam, o.position), _spawn_avoid(o)) < 0.0:
			_place_orb(o)


## はじめて玉をすくえた：「いいね！」、つづけて「玉をタップするだけでもOK」（一度だけ）
func _first_catch_cheer() -> void:
	if GameState.tut.has("scoop_hand"):
		return
	GameState.tut["scoop_hand"] = true
	_hide_hand()
	var chip := _chip(tr("SCOOP_NICE"), Color("ffe27a"))
	var tw := chip.create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(chip, "modulate:a", 0.0, 0.25)
	tw.tween_callback(chip.queue_free)
	tw.tween_callback(func():
		if not is_inside_tree() or GameState.scooped_tonight:
			return
		var c2 := _chip(tr("SCOOP_TAP_HINT"), Color("e8ecff"))
		var t2 := c2.create_tween()
		t2.tween_interval(2.6)
		t2.tween_property(c2, "modulate:a", 0.0, 0.3)
		t2.tween_callback(c2.queue_free))


## 小さな知らせ（画面の上のほう、まんなか）。入力はじゃましない
func _chip(t: String, col: Color) -> PanelContainer:
	var pn := PanelContainer.new()
	pn.add_theme_stylebox_override("panel", _pill(Color(0.06, 0.08, 0.2, 0.82), 16))
	pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _text(t, 16, col, font_black)
	pn.add_child(l)
	add_child(pn)
	pn.reset_size()
	pn.position = Vector2(180 - pn.size.x * 0.5, 150)
	pn.pivot_offset = pn.size * 0.5
	pn.scale = Vector2(0.7, 0.7)
	pn.create_tween().tween_property(pn, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return pn


## 見本の手（指さし）。先の点（0, 0）が、水を押す所。まるい線の手を、ベクター（多角形の和）で描く（どの画面の細かさでも、ふちがなめらか）。
## クリーム色の手に、UI と同じ紺のやわらかな縁取り。右下に少し影、指にハイライト、袖口つき
class HandGhost extends Control:
	var press := 0.0 # 0〜1：押しこみ
	var ring := -1.0 # 0〜1：押した所の波紋（無ければ < 0）
	var lifting := false # はなす拍（上向きの矢じるし）

	const INK := Color(0.12, 0.14, 0.33, 0.9) # 縁（紺）
	const SKIN := Color(1.0, 0.975, 0.94) # 手（クリーム）
	const SHADE := Color(0.95, 0.86, 0.8) # 手の影
	const CUFF := Color(0.87, 0.85, 1.0) # 袖口（うすいラベンダー）
	const TILT := -0.32 # 手の傾き（右下から、玉へ指さす）
	const TIP := Vector2(80, 60) # 指先（水を押す所）の、この Control の中の位置
	const BOX := Vector2(200, 200) # 波紋・矢じるし・手が入る大きさ
	static var _shape := {}

	static func _circle(c: Vector2, r: float, n := 28) -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in n:
			var a := TAU * i / n
			out.append(c + Vector2(cos(a), sin(a)) * r)
		return out

	static func _capsule(a: Vector2, b: Vector2, r: float) -> PackedVector2Array:
		var pts := _circle(a, r)
		pts.append_array(_circle(b, r))
		var h := Geometry2D.convex_hull(pts)
		h.remove_at(h.size() - 1) # 閉じるための重複点
		return h

	static func _union(polys: Array) -> PackedVector2Array:
		var acc: PackedVector2Array = polys[0]
		for i in range(1, polys.size()):
			var m := Geometry2D.merge_polygons(acc, polys[i])
			for q in m:
				if not Geometry2D.is_polygon_clockwise(q) or m.size() == 1:
					acc = q
					break
		return acc

	static func _moved(poly: PackedVector2Array, d: Vector2) -> PackedVector2Array:
		var out := PackedVector2Array()
		for q in poly:
			out.append(q + d)
		return out

	## 手の形（いちど作って使い回す）。手のひらをこちらへ向けた、指さしの手：
	## 人さし指がまっすぐ上、にぎった 3 本の指が右に重なり、親指がその前を横切る
	static func shape() -> Dictionary:
		if not _shape.is_empty():
			return _shape
		var finger := _capsule(Vector2(0, 9.5), Vector2(0, 44), 9.5)
		var palm := _union([_capsule(Vector2(6, 54), Vector2(22, 58), 19.0), _capsule(Vector2(13, 70), Vector2(15, 77), 15.0)])
		var hand := _union([finger, palm])
		var curled: Array = []
		for c in [[Vector2(10, 40.5), Vector2(27, 42.5), 7.2], [Vector2(11, 53), Vector2(31, 54.5), 7.4], [Vector2(12, 65.5), Vector2(29, 66.5), 7.0]]:
			curled.append(_capsule(c[0], c[1], c[2]))
		var thumb := _capsule(Vector2(-12, 66), Vector2(9, 55), 8.0)
		var cuff := _capsule(Vector2(-2, 88), Vector2(32, 90), 9.5)
		var shade := Geometry2D.clip_polygons(hand, _moved(hand, Vector2(-4.5, -5.0)))
		var tshade := Geometry2D.clip_polygons(thumb, _moved(thumb, Vector2(-2.0, -3.0)))
		_shape = {"hand": hand, "curled": curled, "thumb": thumb, "cuff": cuff, "shade": shade, "tshade": tshade,
			"shadow": _moved(hand, Vector2(7, 9))}
		return _shape

	func _outline(poly: PackedVector2Array, w: float, col := INK) -> void:
		var loop := poly.duplicate()
		loop.append(poly[0])
		draw_polyline(loop, col, w, true)

	func _draw() -> void:
		var sh := shape()
		# 指先の水の波紋（水面なので、横にのびただ円）。押した所に、やわらかい光
		draw_set_transform(TIP + Vector2(0, 2), 0.0, Vector2(1.0, 0.42))
		if press > 0.0:
			draw_circle(Vector2.ZERO, 12.0, Color(1, 1, 1, 0.22 * press), true, -1.0, true)
		if ring >= 0.0:
			var e := 1.0 - pow(1.0 - ring, 2.0)
			draw_arc(Vector2.ZERO, 10.0 + e * 34.0, 0.0, TAU, 56, Color(1, 1, 1, (1.0 - ring) * 0.8), 2.6, true)
			if ring > 0.2:
				var e2 := 1.0 - pow(1.0 - (ring - 0.2) / 0.8, 2.0)
				draw_arc(Vector2.ZERO, 6.0 + e2 * 22.0, 0.0, TAU, 48, Color(1, 1, 1, (1.0 - ring) * 0.5), 1.8, true)
		draw_set_transform(TIP)
		# はなす拍：上向きの矢じるし（まるい先）
		if lifting:
			var c := Color(1, 0.93, 0.6, 0.95)
			draw_line(Vector2(-34, 10), Vector2(-34, -14), INK, 7.0, true)
			draw_line(Vector2(-34, 10), Vector2(-34, -14), c, 4.0, true)
			var head := PackedVector2Array([Vector2(-43, -10), Vector2(-25, -10), Vector2(-34, -24)])
			draw_colored_polygon(head, c)
			_outline(head, 2.0)
		# 手：押しこむと少し小さく、下へ
		var sc := 1.0 - press * 0.1
		draw_set_transform(TIP + Vector2(0, press * 3.0), TILT, Vector2(sc, sc))
		draw_colored_polygon(sh.shadow, Color(0.02, 0.03, 0.12, 0.16 * (1.0 - press * 0.5)))
		draw_colored_polygon(sh.cuff, CUFF)
		_outline(sh.cuff, 2.4)
		draw_colored_polygon(sh.hand, SKIN)
		for q in sh.shade:
			draw_colored_polygon(q, SHADE)
		draw_line(Vector2(-3.5, 12), Vector2(-3.5, 32), Color(1, 1, 1, 0.9), 3.0, true) # 指のハイライト
		_outline(sh.hand, 2.6)
		# にぎった指（上から順に重ねる）。下の縁に少し影
		for q: PackedVector2Array in sh.curled:
			draw_colored_polygon(q, SKIN)
			for d in Geometry2D.clip_polygons(q, _moved(q, Vector2(0, -2.5))):
				draw_colored_polygon(d, SHADE)
			_outline(q, 2.2)
		# 親指（手の前）
		draw_colored_polygon(sh.thumb, SKIN)
		for q in sh.tshade:
			draw_colored_polygon(q, SHADE)
		_outline(sh.thumb, 2.4)
		# 爪
		var nail := _capsule(Vector2(0, 6.0), Vector2(0, 9.0), 4.2)
		draw_colored_polygon(nail, Color(1.0, 0.86, 0.88))
		_outline(nail, 1.2, Color(INK.r, INK.g, INK.b, 0.4))
		draw_set_transform(Vector2.ZERO)


# ---------- 確認用 ----------

func demo_hold() -> void:
	# 1つ目の玉の真下にポイを入れた状態を作る
	if orbs.is_empty():
		return
	var o: Orb3D = orbs[0]
	o.vel = Vector3.ZERO
	o.set_process(false)
	pressed = true
	poi.position = Vector3(o.position.x, -0.04, o.position.z)
	aim = Vector3(o.position.x, 0, o.position.z)
	_ripple(o.position)


func demo_lift() -> void:
	pressed = false
	_lift()


## 確認用：本物の入力と同じ道筋で、1つ目の玉をすくう（押す→動かす→離す）
func demo_real() -> void:
	if orbs.is_empty():
		return
	var o: Orb3D = orbs[0]
	o.set_process(false)
	o.vel = Vector3.ZERO
	var sp := View3D.unproject(cam, o.global_position)
	var start := sp + Vector2(40, 30)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = start
	_gui_input(ev)
	for i in 10:
		await get_tree().process_frame
		var m := InputEventMouseMotion.new()
		m.position = start.lerp(sp, (i + 1) / 10.0)
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		_gui_input(m)
	await get_tree().create_timer(0.2).timeout
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = sp
	_gui_input(up)
	print("[demo_real] caught=", caught_count, " dura=", durability)


## 確認用：水の中で、ポイを玉のそばに入れておく
func demo_still() -> void:
	pressed = true
	poi.position = Vector3(0.0, -0.04, 0.2)
	aim = Vector3(0.0, 0, 0.2)


## 確認用：本物の入力と同じ道筋で、1つ目の玉をタップする（ポイがすべっていって、すくう）
func demo_tap() -> void:
	if orbs.is_empty():
		return
	var sp := View3D.unproject(cam, orbs[0].position)
	# 玉の少し横（ポイの輪の外。でも、タップで玉を拾える近さ）をタップ
	var at := sp + Vector2(48, 50)
	for off in [Vector2(48, 50), Vector2(-48, 50), Vector2(60, 40), Vector2(-60, 40), Vector2(0, 70), Vector2(70, 0), Vector2(-70, 0), Vector2(0, -70)]:
		var g := _ground(sp + off)
		var clear: bool = (sp + off).y > 130
		for o in orbs:
			clear = clear and Vector2(g.x - o.position.x, g.z - o.position.z).length() > _hit_r() * 1.1
		if clear:
			at = sp + off
			break
	for down in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = down
		ev.position = at
		_gui_input(ev)
