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
var sky_moon: MeshInstance3D
var night_sky := Color("141a3a")
var sky_stars: CPUParticles3D

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
var rhythm_chip: Button
var meters: PanelContainer
var flow_label: RichTextLabel
var goals_panel: PanelContainer
var busy := false
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	V = GameState.visit
	_build_world()
	_build_ui()
	if _vis():
		_start_visit()
		return
	night = 1.0 if GameState.phase == "evening" else 0.0
	_apply_time(night)
	if night > 0.5:
		_light_deco()
	_refresh_hud()
	if GameState.phase == "morning":
		_show_morning()
	else:
		_show_card()
	_reveal_outfits()


## 届いた服（仕事・眠り・図鑑の条件、光る玉の中身）を、ひとつずつ見せる
func _reveal_outfits() -> void:
	var list: Array = GameState.new_outfits.duplicate()
	GameState.new_outfits.clear()
	list.append_array(Wardrobe.check_unlocks())
	if list.is_empty():
		return
	await get_tree().create_timer(1.2).timeout
	for id in list:
		if not is_inside_tree():
			return
		var r := OutfitReveal.open(self, id, GameState.host())
		await r.closed


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
	# 島が広がるほど、少し引いて全体を入れる
	cam.position = Vector3(0, 7.2, 7.4) * lerpf(1.0, 1.28, clampf(_L() / 10.0, 0, 1))
	cam.fov = 52
	cam.v_offset = -1.6
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.0, -0.4))
	cam_home = cam.transform

	var L: int = _L()
	var t: int = _T()
	# 地面：さびしい土 → 芝
	var ground_c := Color("8d7b68") if L < 1 else _grass_color()
	_build_land(L, ground_c)
	if L >= 1:
		_grass_tufts()
	# 小石
	var rr := RandomNumberGenerator.new()
	rr.seed = 17
	for i in 10:
		var st := _ball(rr.randf_range(0.07, 0.14), Color("9a948c"))
		st.scale = Vector3(1.3, 0.6, 1.0)
		st.position = Vector3(rr.randf_range(-3.4, 3.4), 0.03, rr.randf_range(-2.2, 2.8))
		if not _inside(st.position):
			st.free()
			continue
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
	for i in (0 if _vis() else mini(GameState.dream_flowers + extra_f, 40)):
		var f := _dream_flower(Vector3(-3.3 + (i % 8) * 0.35, 0, 2.6 + (i / 8) * 0.25))
		world.add_child(f)
	_build_next_stake(L)
	_build_dressing(L)
	# 仕事の飾り
	var dd := _decos()
	for role in dd:
		_build_deco(role, dd[role])

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

	if not _vis():
		_weather(GameState.today().weather)
		_season_fx(GameState.season(), GameState.today().weather)

	# 夜空の月と星（夜だけ見える）
	sky_moon = _ball(0.45, Color("fff1c8"), Kit.glow(Color("fff1c8"), 1.6))
	sky_moon.position = Vector3(3.3, 1.9, -6.5)
	world.add_child(sky_moon)
	sky_stars = CPUParticles3D.new()
	sky_stars.amount = 60
	sky_stars.lifetime = 100.0
	sky_stars.preprocess = 100.0
	sky_stars.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	sky_stars.emission_box_extents = Vector3(8, 1.2, 0.5)
	sky_stars.position = Vector3(0, 3.4, -8)
	sky_stars.gravity = Vector3.ZERO
	sky_stars.initial_velocity_max = 0.0
	var stm := SphereMesh.new()
	stm.radius = 0.03
	stm.height = 0.06
	sky_stars.mesh = stm
	sky_stars.material_override = Kit.glow(Color("dfe6ff"), 2.0)
	world.add_child(sky_stars)

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
	# 新しく来た子を優先して、18 体まで
	var res: Array = []
	if _vis():
		for id in V.residents:
			res.append({"id": id, "level": 3})
	else:
		res = GameState.owned.slice(-18)
	var host_id: String = V.host if _vis() else GameState.host()
	_build_host(host_id)
	for o in res:
		if o.id == host_id:
			continue
		var ob := Outfit.make(o.id, _vis_outfit(o.id))
		ob.scale = Vector3.ONE * (0.5 + min(o.level, 6) * 0.02)
		if Rares.is_rare(o.id):
			# レアは少し大きい作りなので、庭では小さめに（横に広い子はさらに）
			ob.scale = Vector3.ONE * (0.34 if o.id in ["hyakki", "wataridori", "shuumatsu"] else 0.42)
		ob.position = _edge_point()
		world.add_child(ob)
		var w := {"o": ob, "id": o.id, "target": ob.position, "wait": randf_range(0.5, 3.0), "act": "", "emote": null}
		# けさ来た子は、縁側から出てくる
		if not _vis() and GameState.newcomers.has(o.id):
			ob.position = Vector3(randf_range(-1.0, 0.6), 0.3, -2.9)
			w.target = Vector3(randf_range(-2.2, 2.0), 0, randf_range(-2.4, -1.9)) # 縁側の前に並ぶ
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
	return Color("7d8a58").lerp(Color("5f9150"), _T() / 3.0)


func _grass_tufts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 70:
		var p := Vector3(rng.randf_range(-3.6, 3.6), 0, rng.randf_range(-2.6, 2.8))
		var g := _cone(0.05, rng.randf_range(0.12, 0.22), Color("5d8c4a").lerp(Color("88c070"), rng.randf()))
		g.position = p + Vector3(0, 0.08, 0)
		if not _inside(p, 0.2):
			g.free()
			continue
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


## 季節の気配：秋は落ち葉、春は花びら（晴れの日だけ、ゆっくり）
func _season_fx(sea: String, w: String) -> void:
	if w != "晴" or sea not in ["秋", "春"]:
		return
	var p := CPUParticles3D.new()
	p.amount = 26
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(4, 0.2, 3)
	p.position = Vector3(0, 3.2, 0)
	p.direction = Vector3(1, -0.3, 0)
	p.spread = 30
	p.gravity = Vector3(0.1, -0.25, 0)
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.3
	p.angular_velocity_min = -120
	p.angular_velocity_max = 120
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.1)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color("e8904a") if sea == "秋" else Color("ffc4d6")
	p.material_override = m
	p.color_ramp = null
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
	if items.has(name) and is_instance_valid(items[name]) and not items[name].is_queued_for_deletion():
		items[name].queue_free()
	var n := Node3D.new()
	n.position = pos
	n.set_meta("home", pos)
	var l: Dictionary = _lay().get(name, {})
	if l.has("x"):
		n.position = Vector3(float(l.x), pos.y, float(l.z))
	n.rotation.y = int(l.get("r", 0)) * PI / 4.0
	if GameState.ISLAND_ITEMS.has(name):
		n.visible = V.items.has(name) if _vis() else not l.get("h", false)
	world.add_child(n)
	items[name] = n
	_cur_group = name
	return n


# ---------- 島（おでかけ中は、読んだコードの島を出す） ----------

var V := {} # おでかけ先の島（空なら自分の島）
var _cur_group := ""


func _vis() -> bool:
	return not V.is_empty()


func _lay() -> Dictionary:
	return V.layout if _vis() else GameState.layout


func _L() -> int:
	return int(V.level) if _vis() else GameState.garden_seen_level


func _T() -> int:
	return int(V.tier) if _vis() else GameState.tier()


func _decos() -> Dictionary:
	if _vis():
		return V.decos
	var d := {}
	for role in GameState.decos:
		var lv: int = GameState.deco_level(role)
		if lv > 0:
			d[role] = lv
	return d


func _deco_lv(role: String) -> int:
	return int(_decos().get(role, 0))


## 住人の行き先。物を動かしたら、いっしょに動く
func _spot(d: Dictionary) -> void:
	var g: Node3D = items.get(_cur_group)
	if g and is_instance_valid(g):
		if not g.visible:
			return
		var home: Vector3 = g.get_meta("home", g.position)
		d.group = _cur_group
		d.local = d.pos - home
		d.pos = g.position + Basis(Vector3.UP, g.rotation.y) * d.local
	spots.append(d)


func _move_spots(name: String) -> void:
	var g: Node3D = items.get(name)
	for sp in spots:
		if sp.get("group", "") == name:
			sp.pos = g.position + Basis(Vector3.UP, g.rotation.y) * sp.local


var land_grass: MeshInstance3D
var land_sand: MeshInstance3D
var sea_mat: StandardMaterial3D


## 島：海・砂浜・芝の円と、うしろの丘（休憩室が建つ）
func _build_land(L: int, ground_c: Color) -> void:
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	sea.mesh = pm
	sea_mat = StandardMaterial3D.new()
	sea_mat.albedo_color = Color("4fa8bd")
	sea_mat.roughness = 0.4
	sea.material_override = sea_mat
	sea.position.y = -0.14
	world.add_child(sea)
	land_sand = _cyl(1.0, 0.12, Color("e8d3a8"))
	land_sand.position.y = -0.1
	world.add_child(land_sand)
	land_grass = _cyl(1.0, 0.1, ground_c)
	land_grass.position.y = -0.05
	world.add_child(land_grass)
	_box(Vector3(14, 0.1, 5), Vector3(0, -0.05, -5.0), ground_c).name = "hill"
	_box(Vector3(14.6, 0.12, 5.2), Vector3(0, -0.1, -5.0), Color("e8d3a8"))
	var r := _island_r(L)
	land_grass.scale = Vector3(r, 1, r)
	land_sand.scale = Vector3(r + 0.45, 1, r + 0.45)
	# 波打ちぎわの白い輪
	for i in 40:
		var a := TAU * i / 40.0
		if sin(a) < -0.55:
			continue
		var f := _ball(0.07, Color("f4fbff"), Obake3D.flat(Color("f4fbff")))
		f.scale = Vector3(2.2, 0.25, 1.0)
		f.rotation.y = -a + PI / 2
		f.position = Vector3(cos(a) * (r + 0.55), -0.09, sin(a) * (r + 0.55))
		f.name = "foam"
		f.set_meta("a", a)
		world.add_child(f)


func _grow_land(L: int) -> void:
	var r := _island_r(L)
	var tw := create_tween().set_parallel()
	tw.tween_property(land_grass, "scale", Vector3(r, 1, r), 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(land_sand, "scale", Vector3(r + 0.45, 1, r + 0.45), 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for c in world.get_children():
		if c.name.begins_with("foam") and c.has_meta("a"):
			var a: float = c.get_meta("a")
			tw.tween_property(c, "position", Vector3(cos(a) * (r + 0.55), -0.09, sin(a) * (r + 0.55)), 0.8)


var host_node: Obake3D


## 島のあるじ（縁側の前で出むかえる）。マイおばけ猫が決まったら GameState.host_id に入れるだけでよい
## おでかけ先の島では、その島のコードに入っていた服を着せる。自分の島なら自分の服
func _vis_outfit(id: String):
	if not _vis():
		return null
	return V.get("outfits", {}).get(id, {})


func _build_host(id: String) -> void:
	if host_node and is_instance_valid(host_node):
		host_node.queue_free()
	if id == "my":
		var tid: String = V.get("my_type", "") if _vis() else GameState.my_obake.get("type_id", "")
		host_node = Obake3D.make_custom(QuizData.TYPES[tid].look) if QuizData.TYPES.has(tid) else Obake3D.make("receipt")
		if not _vis():
			host_node.queue_free()
			host_node = Outfit.make("my")
		else:
			var vo: Dictionary = V.get("outfits", {}).get("my", {})
			var t := WardrobeData.tint(vo.get("tint", ""))
			if t.c != "" and QuizData.TYPES.has(tid):
				var lk: Dictionary = QuizData.TYPES[tid].look.duplicate()
				lk["color"] = t.c
				host_node.queue_free()
				host_node = Obake3D.make_custom(lk)
			Outfit.dress(host_node, vo)
	else:
		host_node = Outfit.make(id, _vis_outfit(id))
	host_node.scale = Vector3.ONE * (0.6 if Rares.is_rare(id) else 0.82)
	host_node.position = Vector3(0.9, 0, -1.9)
	world.add_child(host_node)
	# あるじの札（いつも手前に描く）
	var nm := "あるじ"
	if id == "my":
		var tid2: String = V.get("my_type", "") if _vis() else GameState.my_obake.get("type_id", "")
		if QuizData.TYPES.has(tid2):
			nm = QuizData.TYPES[tid2].name
	var l := Kit.label3d(nm, 34, Color("ffe27a"))
	l.pixel_size = 0.009
	l.no_depth_test = true
	l.render_priority = 20
	l.outline_render_priority = 19
	l.position = Vector3(0, 1.9 if not Rares.is_rare(id) else 2.5, 0)
	host_node.add_child(l)


## 島の大きさ（段が上がるほど、岸がひろがる）
func _island_r(L: int) -> float:
	return 3.6 + L * 0.13


func _inside(p: Vector3, margin := 0.3) -> bool:
	return Vector2(p.x, p.z).length() < _island_r(_L()) - margin or p.z < -2.4


## 段が上がるほど、ひと目で分かる変化：道の灯り（段の数だけ）・生け垣・野の花・夜空の色
func _build_dressing(L: int) -> void:
	if items.has("dressing"):
		items.dressing.queue_free()
		items.erase("dressing")
		lamp_lights = lamp_lights.filter(func(l): return is_instance_valid(l) and not l.is_queued_for_deletion() and not l.has_meta("dressing"))
	var g := _group("dressing", Vector3.ZERO)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# 道の灯り：段の数だけ、小道の両側に並ぶ（夜に灯る）
	for i in L:
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := 2.7 - (i / 2) * 0.62
		var at := Vector3(0.2 + side * 0.75, 0, z)
		var post := _box(Vector3(0.1, 0.32, 0.1), at + Vector3(0, 0.16, 0), Color("9a948c"), g)
		post.name = "lamp_post"
		var bulb := _ball(0.07, Color("ffe7a8"), Kit.glow(Color("ffd98a"), 2.0))
		bulb.position = at + Vector3(0, 0.38, 0)
		g.add_child(bulb)
		if i % 3 == 0:
			var l := OmniLight3D.new()
			l.light_color = Color("ffc98a")
			l.omni_range = 1.4
			l.light_energy = 1.0
			l.position = at + Vector3(0, 0.45, 0)
			l.set_meta("dressing", true)
			g.add_child(l)
			lamp_lights.append(l)
	# 生け垣：庭の両脇に、段が上がるほど奥から手前へのびる
	var n_hedge := 0 if L < 2 else (3 if L < 5 else (5 if L < 8 else 7))
	for side in [-1.0, 1.0]:
		for k in n_hedge:
			var b := _ball(rng.randf_range(0.3, 0.42), Color("5a8a4a").lerp(Color("3f6d3a"), L / 10.0))
			b.scale = Vector3(0.9, 0.85, 1.2)
			b.position = Vector3(side * rng.randf_range(3.7, 4.0), 0.24, -2.4 + k * 0.85)
			g.add_child(b)
			if L >= 8 and k % 2 == 0:
				var f := _ball(0.07, Color("ffd1e0"))
				f.position = b.position + Vector3(-side * 0.2, 0.25, 0.15)
				g.add_child(f)
	# 野の花：芝のあちこちに（段 4 から、8 で倍）
	var n_flower := 0 if L < 4 else (26 if L < 8 else 56)
	var cols := [Color("ffd36b"), Color("ffffff"), Color("ff9fb8"), Color("b9a7ff")]
	for i in n_flower:
		var p := Vector3(rng.randf_range(-3.6, 3.6), 0.05, rng.randf_range(-2.4, 3.0))
		if absf(p.x - 0.2) < 0.9:
			continue
		var f := _ball(0.045, cols[i % cols.size()])
		f.position = p
		g.add_child(f)
	# 庭の住人（にゃんこ大戦争のノリの紙人形）：かかし（花壇）・おじぞう（縁台）・ねぶくろ（月見台）
	if L >= 2:
		_paper("kakashi", Vector3(-2.5, 0, 2.0), 1.3, g)
	if L >= 6:
		_paper("jizo", Vector3(3.2, 0, -1.2), 0.9, g)
	if L >= 9:
		_paper("nebukuro", Vector3(1.6, 0, 2.9), 1.0, g)
	# 桟橋（段 4）と灯台（段 8）
	if L >= 4:
		var r := _island_r(L)
		var dir := Vector3(0.93, 0, 0.36).normalized()
		for k in 7:
			var at := dir * (r - 0.4 + k * 0.42)
			var plank := _box(Vector3(0.7, 0.06, 0.36), at + Vector3(0, 0.02, 0), Color("b07a4a"), g)
			plank.rotation.y = atan2(dir.x, dir.z)
			if k % 2 == 0:
				for sx in [-0.3, 0.3]:
					var post := _cyl(0.04, 0.4, Color("7a4e32"))
					post.position = at + Basis(Vector3.UP, atan2(dir.x, dir.z)) * Vector3(sx, -0.1, 0)
					g.add_child(post)
	if L >= 8:
		var lh := Vector3(3.6, 0, -2.9)
		var tower := _cyl(0.3, 1.6, Color("fffaf2"), 0.22)
		tower.position = lh + Vector3(0, 0.8, 0)
		g.add_child(tower)
		for k in 2:
			var band := _cyl(0.29 - k * 0.04, 0.2, Color("e8505b"))
			band.position = lh + Vector3(0, 0.45 + k * 0.6, 0)
			g.add_child(band)
		var lamp := _ball(0.18, Color("ffe7a8"), Kit.glow(Color("ffe08a"), 2.4))
		lamp.position = lh + Vector3(0, 1.75, 0)
		g.add_child(lamp)
		var roof := _cyl(0.26, 0.24, Color("e8505b"), 0.0)
		roof.position = lh + Vector3(0, 2.0, 0)
		g.add_child(roof)
		var ll := OmniLight3D.new()
		ll.light_color = Color("ffe08a")
		ll.omni_range = 3.5
		ll.position = lh + Vector3(0, 1.8, 0.3)
		ll.set_meta("dressing", true)
		g.add_child(ll)
		lamp_lights.append(ll)
	# 夜空の色：段が上がるほど、深い紫に（満開で、ほんのり夢の色）
	night_sky = Color("141a3a").lerp(Color("2a1f4f"), L / 10.0)


## 庭の住人（トゥーンの 3D）：かかし・おじぞう・ねぶくろ。ふつうのおばけと同じ体と顔で組む
func _paper(name: String, at: Vector3, h: float, _parent: Node3D) -> void:
	var gr := _group("res_" + name, at)
	var o := Obake3D.new()
	o.bob = false
	gr.add_child(o)
	match name:
		"kakashi":
			# 一本足のかかし：棒の上に白いおばけ、麦わら帽子、横木の腕
			var pole := _cyl(0.035, 0.7, Color("8a5a3a"))
			pole.position.y = 0.35
			o.add_child(pole)
			var arm := _box(Vector3(1.0, 0.06, 0.06), Vector3(0, 0.95, 0), Color("8a5a3a"), o)
			arm.name = "arm"
			var g := o.ghost(Color("f6f2ea"), 0.6)
			g.position.y = 0.62
			o.add_child(g)
			var brim := _cyl(0.42, 0.04, Color("e8c45a"))
			brim.position.y = 1.2
			o.add_child(brim)
			var crown := _cyl(0.2, 0.18, Color("e8c45a"), 0.16)
			crown.position.y = 1.3
			o.add_child(crown)
		"jizo":
			# 目を閉じて座る、灰色のおばけ。赤い前かけ
			var g := o.ghost(Color("b8b4ad"), 0.55, 0.0, Obake3D.INK, true)
			o.add_child(g)
			var bib := _cyl(0.2, 0.05, Color("e8505b"), 0.3)
			bib.position = Vector3(0, 0.22, 0.12)
			bib.rotation.x = 0.35
			o.add_child(bib)
			var base := _cyl(0.36, 0.08, Color("8e96a8"))
			base.position.y = 0.0
			o.add_child(base)
		"nebukuro":
			# 寝袋にくるまって横になったおばけ（顔だけ出ている）
			var bag := MeshInstance3D.new()
			var cap := CapsuleMesh.new()
			cap.radius = 0.22
			cap.height = 1.0
			bag.mesh = cap
			bag.material_override = _mat(Color("2f3f8a"))
			bag.rotation.z = PI / 2
			bag.position = Vector3(0.15, 0.22, 0)
			o.add_child(bag)
			var head := MeshInstance3D.new()
			head.mesh = _ball(0.2, Color.WHITE).mesh
			head.material_override = _mat(Color("f6f2ea"))
			head.position = Vector3(-0.38, 0.26, 0.02)
			o.add_child(head)
			var f := o.face(Vector3(-0.38, 0.26, 0.02), 0.4, Obake3D.INK, true)
			f.rotation.y = -0.5
			o.add_child(f)
			var z := Kit.label3d("z", 34, Color("e8e2ff"))
			z.position = Vector3(-0.3, 0.7, 0)
			o.add_child(z)
	o.scale = Vector3.ONE * (h / 1.3)


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
	_spot({"pos": Vector3(-1.5, 0.3, -2.8), "act": "sit"})
	_spot({"pos": Vector3(0.6, 0.3, -2.8), "act": "sleep"})


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
	_spot({"pos": at + Vector3(-0.5, 0, 0.4), "act": "look"})


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
	_spot({"pos": at + Vector3(0.1, 0, 0.8), "act": "water"})


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
	_spot({"pos": at + Vector3(0, 0.02, 0), "act": "swim"})


func _build_bench(at: Vector3) -> void:
	var g := _group("bench", at)
	_box(Vector3(1.6, 0.08, 0.6), Vector3(0, 0.4, 0), Color("c9454a"), g)
	for x in [-0.7, 0.7]:
		_box(Vector3(0.08, 0.4, 0.5), Vector3(x, 0.2, 0), Color("6b4430"), g)
	_spot({"pos": at + Vector3(-0.4, 0.44, 0), "act": "sit"})
	_spot({"pos": at + Vector3(0.4, 0.44, 0), "act": "sit"})


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
	_spot({"pos": at + Vector3(0.6, 0, 0.5), "act": "sleep"})


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
	_spot({"pos": at + Vector3(0, 0.2, 0.25), "act": "look"})


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
	if items.has(key) and store != "" and store != "手作り" and not _vis():
		var tag := Kit.label3d(store.split(" ")[-1], 30, Color("fff6e8"))
		tag.pixel_size = 0.007
		tag.position = Vector3(0, 0.3, 0.6)
		tag.no_depth_test = false
		items[key].add_child(tag)


func _build_deco_body(role: String, lv: int) -> void:
	match role:
		"mask":
			var g := _group("deco_mask", Vector3(-2.6, 0, 2.3))
			_box(Vector3(1.1, 0.7, 0.3), Vector3(0, 0.35, 0), Color("c9454a"), g)
			_box(Vector3(1.2, 0.08, 0.5), Vector3(0, 1.1, 0), Color("3b4a8c"), g)
			for x in [-0.35, 0.35]:
				_box(Vector3(0.05, 1.1, 0.05), Vector3(x * 1.5, 0.55, 0.2), Color("6b4430"), g)
			for i in 3:
				var m := _cyl(0.14, 0.03, Color("fffaf0"))
				m.rotation.x = PI / 2
				m.position = Vector3(-0.35 + i * 0.35, 0.85, 0.2)
				g.add_child(m)
				for ex in [-0.05, 0.05]:
					var e := _ball(0.015, Color("2e222f"), Obake3D.flat(Color("2e222f")))
					e.position = Vector3(-0.35 + i * 0.35 + ex, 0.88, 0.23)
					g.add_child(e)
			var l := OmniLight3D.new()
			l.light_color = Color("ffb35c")
			l.light_energy = 1.0
			l.omni_range = 2.0
			l.position = Vector3(0, 1.0, 0.5)
			g.add_child(l)
			lamp_lights.append(l)
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
			_spot({"pos": Vector3(-1.9, 0, 1.9), "act": "tea"})
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
			_spot({"pos": Vector3(0.9, 0.12, 2.5), "act": "swim"})
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
			_spot({"pos": Vector3(2.8, 0, 0.5), "act": "eat"})
		"stock":
			var g := _group("deco_stock", Vector3(-3.0, 0, 0.0))
			var n := 3 if lv < 2 else 6
			for i in n:
				var b := _box(Vector3(0.5, 0.36, 0.45), Vector3((i % 3) * 0.45 - 0.45, 0.18 + (i / 3) * 0.36, randf_range(-0.05, 0.05)), Color("d9a86c"), g)
				b.rotation.y = randf_range(-0.15, 0.15)
			_spot({"pos": Vector3(-3.0, 0, 0.6), "act": "hide"})


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
	env.background_color = day_bg.lerp(night_sky, n)
	if sea_mat:
		sea_mat.albedo_color = Color("4fa8bd").lerp(Color("1a2a52"), n)
	env.ambient_light_color = Color("ffe9d6").lerp(Color("5a64a8"), n)
	env.ambient_light_energy = lerpf(0.4, 0.55, n)
	sun.light_color = Color("ffe0bf").lerp(Color("9fb4ff"), n)
	sun.light_energy = lerpf(0.75, 0.3, n)
	lamp_lights = lamp_lights.filter(func(l): return is_instance_valid(l) and not l.is_queued_for_deletion())
	for l in lamp_lights:
		l.light_energy = lerpf(0.0, 1.0, n) if l.has_meta("dressing") else lerpf(0.4, 1.8, n)
	if fireflies:
		fireflies.visible = n > 0.4
	if sky_moon:
		sky_moon.visible = n > 0.5 and GameState.today().weather == "晴"
		sky_stars.visible = sky_moon.visible
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
	var sp: Dictionary = spots.pick_random() if go_spot else {}
	# まんなかは広く空けておく（まんなかへ向かう子は3体まで）
	if go_spot and _is_center(sp.pos) and _center_count() >= 3:
		go_spot = false
	if go_spot:
		w.target = sp.pos + Vector3(randf_range(-0.12, 0.12), 0, randf_range(-0.12, 0.12))
		w.next_act = sp.act
	else:
		w.target = _edge_point()
		w.next_act = ""


func _end_act(w: Dictionary) -> void:
	w.act = ""
	var ob: Obake3D = w.o
	ob.rotation.z = 0.0
	if w.emote and is_instance_valid(w.emote):
		w.emote.queue_free()
	w.emote = null


## まんなか（小道と池のまわり）を空けた、庭のふちか縁側の一点
func _edge_point() -> Vector3:
	if randf() < 0.25:
		return Vector3(randf_range(-2.6, 2.4), 0, randf_range(-2.7, -2.3)) # 縁側の前
	for k in 8:
		var side := -1.0 if randf() < 0.5 else 1.0
		var p := Vector3(side * randf_range(1.6, 3.3), 0, randf_range(-1.6, 2.6))
		if _inside(p, 0.5):
			return p
	return Vector3(randf_range(-2.0, 2.0), 0, randf_range(-2.0, -1.0))


func _is_center(p: Vector3) -> bool:
	return absf(p.x - 0.2) < 1.4 and p.z > -1.8 and p.z < 2.4


func _center_count() -> int:
	var n := 0
	for w in walkers:
		if _is_center(w.target):
			n += 1
	return n


## 庭のおばけをタップすると、跳ねてひとこと
var orbit := 0.0
var cam_v := -1.6


## 庭をよこになぞると、ぐるっと少し回して見られる
func _gui_input(event: InputEvent) -> void:
	if editing:
		_edit_input(event)
		return
	if (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT)) or event is InputEventScreenDrag:
		if busy:
			return
		orbit = clampf(orbit - event.relative.x * 0.006, -0.6, 0.6)
		var t := cam_home
		t.origin = Basis(Vector3.UP, orbit) * cam_home.origin
		cam.transform = t.looking_at(Vector3(0, 0.0, -0.4), Vector3.UP)
		return
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


const LINES_TIER := [
	["…ねむい", "きのう、何時にねた？", "庭が、しょんぼりしてる", "花が下を見ている。こっちも見ている"],
	["まあまあの夜だった", "今夜は、早めに", "…ふわぁ", "いつもの時刻、覚えてる？"],
	["いい夜だった", "花がのびた", "朝の空気がすき", "リズム、悪くない"],
	["ぐっすり", "庭がきらきらしてる", "夢で羊をかぞえた。四ひきめで寝た", "今日は、なにもしなくていい気がする"],
]
const LINES_OWN := {
	"receipt": ["レシート、のびた", "合計は、言えない", "…ピッ"],
	"bubble": ["ぷく", "割れた。平気", "洗ったら、減った"],
	"tray": ["お盆は落とさない", "中身は知らない", "…（バランス中）"],
	"pan": ["じゅう", "さわらないで。あつくはない", "油の音がすき"],
	"box": ["箱から出ない", "住所はここ", "中は広い（ことにしている）"],
	"nemuri": ["zzz…", "…（寝ている）", "羊が一ぴき…"],
	"lantern": ["夜はこれから", "明るいけど、眠い", "…消さないで"],
}
const LINES_NIGHT := ["もう寝る？", "川べり、行く？", "虫の声", "今夜は何時に寝るの"]


func _line_for(id: String) -> String:
	var t := GameState.tier()
	if Rares.is_rare(id):
		return ["……", "…", "（じっとこっちを見ている）", "……（うなずく）"].pick_random()
	if LINES_OWN.has(id) and randf() < 0.45:
		return LINES_OWN[id].pick_random()
	if night > 0.5 and randf() < 0.4:
		return LINES_NIGHT.pick_random()
	return LINES_TIER[t].pick_random()


# ---------- UI ----------

func _build_ui() -> void:
	# いつも見えるのは3つだけ：曜日・リズム（ことば）・図鑑
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
	rhythm_chip = Button.new()
	rhythm_chip.custom_minimum_size = Vector2(0, 38)
	rhythm_chip.add_theme_font_override("font", Kit.black())
	rhythm_chip.add_theme_font_size_override("font_size", 14)
	rhythm_chip.pressed.connect(_toggle_meters)
	top.add_child(rhythm_chip)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	if GameState.day >= 1 or not Wardrobe.fresh.is_empty():
		var wd := Kit.button(tr("Wardrobe"), Color(1, 1, 1, 0.92), func(): main.go("wardrobe"), Color("ff8a5b"), 38, 13)
		wd.custom_minimum_size.x = 64
		top.add_child(wd)
	var zk := Kit.button("図鑑", Color(1, 1, 1, 0.92), func(): main.go("zukan"), Color("8a5bd6"), 38, 15)
	zk.custom_minimum_size.x = 64
	top.add_child(zk)
	flow_label = RichTextLabel.new() # 使わない（互換のため）
	flow_label.visible = false
	add_child(flow_label)

	# くわしく（リズムのことばをタップしたときだけ）
	meters = PanelContainer.new()
	meters.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.95), 18, 0.12, Vector2(12, 8)))
	meters.position = Vector2(12, 58)
	meters.size = Vector2(336, 0)
	meters.visible = false
	add_child(meters)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 4)
	meters.add_child(mv)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 8)
	r1.add_child(Kit.text("リズム", 12, Color("8a7a88")))
	rhythm_bar = Kit.bar(0, Color("9fb4ff"), 150, 10)
	r1.add_child(rhythm_bar)
	rhythm_label = Kit.text("", 13, Color("2a2233"), true)
	r1.add_child(rhythm_label)
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
	if GameState.day >= 3:
		var db := Kit.button("ねむり日記を見る", Color("f3ecff"), _toggle_diary, Color("6a5bd6"), 32, 13)
		mv.add_child(db)

	goals_btn = Button.new()
	goals_btn.position = Vector2(236, 58)
	goals_btn.visible = GameState.day >= 2 # めあては 2 日目から
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
	rhythm_chip.text = "眠り：%s" % GameState.tier_name()
	for k in ["normal", "hover", "pressed", "focus"]:
		rhythm_chip.add_theme_stylebox_override(k, Kit.pill(Color(1, 1, 1, 0.92), 19, 0.14, Vector2(12, 4)))
	rhythm_chip.add_theme_color_override("font_color", GameState.TIER_COLOR[GameState.tier()].darkened(0.35))
	rhythm_chip.add_theme_color_override("font_hover_color", GameState.TIER_COLOR[GameState.tier()].darkened(0.35))
	var cur: int = {"morning": 0, "day": 1, "evening": 2}.get(GameState.phase, 1)
	var steps := ["朝", "昼", "夜", "眠"]
	var out := []
	for i in steps.size():
		if i == cur:
			out.append("[b][color=#ff8a5b]%s[/color][/b]" % steps[i])
		else:
			out.append("[color=#8a7a88]%s[/color]" % steps[i])
	flow_label.text = "[color=#c9bfc6]・[/color]".join(out)
	goals_btn.text = "めあて %d/3 ▼" % GameState.goals_done()
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


func _toggle_meters() -> void:
	Kit.play(self, "tap", 1.1)
	meters.visible = not meters.visible
	goals_btn.visible = GameState.day >= 2 and not meters.visible
	if goals_panel:
		_toggle_goals()


func _toggle_goals() -> void:
	if goals_panel:
		goals_panel.queue_free()
		goals_panel = null
		return
	goals_panel = PanelContainer.new()
	goals_panel.add_theme_stylebox_override("panel", Kit.pill(Color(1, 0.98, 0.9, 0.97), 16, 0.18, Vector2(12, 8)))
	goals_panel.position = Vector2(118, 92)
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
	_place_handle()
	# カードが低いときは、庭を画面のまんなかへ
	if not busy and not card_hidden:
		var k := clampf((card.size.y - 140.0) / 150.0, 0.0, 1.0)
		cam_v = lerpf(-0.7, -1.6, k)
		create_tween().tween_property(cam, "v_offset", cam_v, 0.4).set_trans(Tween.TRANS_SINE)


var handle: Button
var card_hidden := false


## カードをしまって、庭をひろく見る
func _place_handle() -> void:
	if GameState.day < 2:
		return
	if handle == null:
		handle = Button.new()
		handle.add_theme_font_override("font", Kit.black())
		handle.add_theme_font_size_override("font_size", 12)
		for k in ["normal", "hover", "pressed", "focus"]:
			handle.add_theme_stylebox_override(k, Kit.pill(Color(1, 1, 1, 0.95), 14, 0.15, Vector2(10, 3)))
		handle.add_theme_color_override("font_color", Color("6a5f70"))
		handle.add_theme_color_override("font_hover_color", Color("6a5f70"))
		handle.pressed.connect(_toggle_card)
		add_child(handle)
	if card_hidden:
		handle.text = "▲ カードを出す"
		handle.position = Vector2(126, 598)
	else:
		handle.text = "▼ しまう"
		handle.position = Vector2(card.position.x + card.size.x - 84, card.position.y - 14)
	handle.size = Vector2(0, 0)


func _toggle_card() -> void:
	Kit.play(self, "tap", 1.1)
	card_hidden = not card_hidden
	card.visible = not card_hidden
	_place_handle()
	var tw := create_tween().set_parallel()
	tw.tween_property(cam, "v_offset", -0.7 if card_hidden else cam_v, 0.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cam, "fov", 42.0 if card_hidden else 52.0, 0.4).set_trans(Tween.TRANS_SINE)


func _pop_card() -> void:
	if card_hidden:
		card_hidden = false
		card.visible = true
		cam.v_offset = cam_v
		cam.fov = 52.0
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
	var face := Kit.text("●", 16)
	face.text = "●"
	face.add_theme_color_override("font_color", Color("8b7bff"))
	row.add_child(face)
	var l := Kit.wrap(Kit.text(t, 13, Color("6a5bd6")))
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	card_box.add_child(row)


## 昼のカード（今日の予定）と、夜のカード
## ひかえめな2つ目の選択肢（文字だけのボタン）
func _link(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.add_theme_font_override("font", Kit.bold())
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color("8a7a88"))
	b.add_theme_color_override("font_hover_color", Color("6a5f70"))
	b.pressed.connect(func():
		Kit.play(self, "tap", 1.1)
		cb.call())
	return b


func _show_card() -> void:
	_clear_card()
	var s: Dictionary = GameState.today()
	var first := GameState.day == 0
	if GameState.phase == "day":
		if s.get("chore", false):
			card_box.add_child(Kit.text("今日のおてつだい", 18, Color("2a2233"), true))
			card_box.add_child(Kit.text(GameState.CHORE_TEXT[s.role], 14, Color("6a5f70")))
			card_box.add_child(Kit.button("おてつだいする", Color("ff8a5b"), _do_shift))
			card_box.add_child(_link("今日はのんびりする", _rest))
		elif s.role != "":
			card_box.add_child(Kit.text("今日のシフト", 18, Color("2a2233"), true))
			card_box.add_child(Kit.text("%s・%s" % [s.store, GameState.ROLE_LABEL[s.role]], 14, Color("6a5f70")))
			if not GameState.tut.has("shift"):
				_guide("働くと、庭に飾りが届く")
			var b := Kit.button("シフトに行く", Color("ff8a5b"), _do_shift)
			card_box.add_child(b)
			card_box.add_child(_link("今日は休む", _rest))
			if not GameState.tut.has("shift"):
				Kit.nudge.call_deferred(b)
		else:
			card_box.add_child(Kit.text("夜の庭へ、ようこそ" if first else "今日は休み", 18, Color("2a2233"), true))
			card_box.add_child(Kit.text("よく眠ると、庭が育つ" if first else "よく眠ると、おまけがつく", 14, Color("6a5f70")))
			var b := Kit.button("夕方まで、のんびり", Color("ff8a5b"), _rest)
			card_box.add_child(b)
			if GameState.day >= 2:
				card_box.add_child(_link("島をつくる・シェアする", _enter_edit))
			if first and not GameState.tut.has("first"):
				Kit.nudge.call_deferred(b)
	elif GameState.phase == "evening":
		if GameState.is_moon_night() and not GameState.scooped_tonight:
			card_box.add_child(Kit.text("今夜は満月の夜", 18, Color("2a2233"), true))
			card_box.add_child(Kit.text("よく眠れた夜の数だけ、灯りがつく", 14, Color("6a5f70")))
			var b := Kit.button("月見をする", Color("5b4a9e"), func(): main.go("moon"))
			card_box.add_child(b)
			Kit.nudge.call_deferred(b)
		elif not GameState.scooped_tonight:
			card_box.add_child(Kit.text("夜になった", 18, Color("2a2233"), true))
			card_box.add_child(Kit.text("光る玉は、朝にかえる", 14, Color("6a5f70")))
			if GameState.day >= 3:
				_deco_chips()
			var b := Kit.button("川べりで、おばけすくい", Color("5b6fc2"), func(): main.go("catch"))
			card_box.add_child(b)
			if not GameState.tut.has("scoop"):
				Kit.nudge.call_deferred(b)
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_child(_link("すくわずに寝る", func(): main.go("sleep")))
			if GameState.can_gift() and GameState.day >= 4:
				var c: String = GameState.today().coworkers[0]
				row.add_child(_link("%sにおすそわけ" % c, _gift))
			card_box.add_child(row)
			if GameState.day >= 2:
				card_box.add_child(_link("島をつくる・シェアする", _enter_edit))
		else:
			card_box.add_child(Kit.text("おやすみの時間", 18, Color("2a2233"), true))
			card_box.add_child(Kit.text("玉を %d 個持ち帰った" % GameState.orbs.size(), 14, Color("6a5f70")))
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
	card_box.add_child(Kit.text("ともした飾りの玉が、出やすい", 11, Color("8a7a88")))
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
	_refresh_hud()
	Kit.play(self, "night", 1.3, -10)
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
	orbit = 0.0
	var to := cam_home
	if mode == 1:
		to.origin = at + Vector3(0, 2.4, 4.4)
		to = to.looking_at(at + Vector3(0, 0.4, 0), Vector3.UP)
	var tw := create_tween().set_parallel()
	tw.tween_property(cam, "transform", to, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "v_offset", -0.4 if mode == 1 else cam_v, 0.7)
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
	if ln.is_empty():
		GameState.phase = "day"
		_show_card()
		return
	# まず、庭の変化を見せる
	busy = true
	card.modulate.a = 0.0
	await get_tree().create_timer(0.7).timeout
	while GameState.garden_seen_level < GameState.garden_level:
		GameState.garden_seen_level += 1
		var st: Dictionary = GameState.GARDEN[GameState.garden_seen_level]
		await _reveal_stage(GameState.garden_seen_level, st)
	GameState.save()
	_refresh_hud()
	busy = false
	# それから、ゆうべの眠りを短く
	_clear_card()
	card_box.add_child(Kit.text("おはよう。%s ねむった" % GameState.hm(ln.hours), 19, Color("2a2233"), true))
	# ひとことだけ：良ければ一言、足りなければいちばん大きい理由
	var worst = null
	for p in ln.parts:
		if p[1] < 0 and (worst == null or p[1] < worst[1]):
			worst = p
	if worst == null:
		var good_line: String = ["いい夜だった", "いつもどおり、ぐっすり", "庭もよく眠れたらしい"].pick_random() if ln.score >= 18 else "まあまあの夜だった"
		card_box.add_child(Kit.text(good_line, 14, Color("3f7d4f"), true))
	else:
		card_box.add_child(Kit.text("すこし残念：%s" % worst[0], 14, Color("c0473b"), true))
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	r.add_child(Kit.text("リズム", 14, Color("8a7a88")))
	var bar := Kit.bar(ln.rhythm_before / 100.0, GameState.TIER_COLOR[GameState.tier()], 130, 14)
	r.add_child(bar)
	var diff: float = ln.rhythm - ln.rhythm_before
	r.add_child(Kit.text("↑" if diff > 0 else ("↓" if diff < 0 else "→"), 16, Color("3f7d4f") if diff >= 0 else Color("c0473b"), true))
	r.add_child(Kit.text(GameState.tier_name(), 14, Color("4a3f52"), true))
	card_box.add_child(r)
	if ln.get("visitor", "") != "":
		card_box.add_child(Kit.text("チョウチンがついてきた", 13, Color("b0643a")))
	elif GameState.day >= 4:
		var om := GameState.omen()
		if om != "" and om.length() <= 24:
			card_box.add_child(Kit.text(om, 12, Color("8a5bd6")))
	var btn := Kit.button("今日をはじめる", Color("ff8a5b"), _after_morning)
	card_box.add_child(btn)
	if GameState.day == 1:
		_guide("同じころに寝ると、リズムが上がる")
	elif GameState.day == 2:
		_guide("右上に「めあて」ができた")
	elif GameState.day == 3:
		_guide("リズムのことばをタップで、くわしく")
	elif GameState.day == 5:
		_guide("庭をよこになぞると、見回せる")
	_card_fit()
	_pop_card()
	await get_tree().create_timer(0.4).timeout
	if not is_instance_valid(bar) or bar.is_queued_for_deletion():
		return
	Kit.play(self, "chime", 0.9)
	var tw := create_tween()
	tw.tween_property(bar, "value", ln.rhythm / 100.0, 0.9).set_trans(Tween.TRANS_SINE)


func _after_morning() -> void:
	if busy:
		return
	GameState.phase = "day"
	GameState.save()
	_refresh_hud()
	card.modulate.a = 0.0
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
			(land_grass.material_override as StandardMaterial3D).albedo_color = _grass_color()
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
	_build_dressing(level)
	_grow_land(level)
	_apply_time(night)
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


func demo_orbit() -> void:
	var m := InputEventMouseMotion.new()
	m.button_mask = MOUSE_BUTTON_MASK_LEFT
	m.relative = Vector2(-80, 0)
	_gui_input(m)


func demo_fps() -> void:
	print("[fps] ", Engine.get_frames_per_second(), " walkers=", walkers.size())


# ---------- 島をつくる（物を動かす・回す・しまう） ----------

var editing := false
var edit_ui: Control
var edit_name: Label
var sel := ""
var dragging := false
var sel_ring: MeshInstance3D
var edit_back: Control


func _movable_keys() -> Array:
	var out: Array = []
	for k in GameState.ISLAND_ITEMS:
		if items.has(k) and is_instance_valid(items[k]):
			out.append(k)
	return out


func _enter_edit() -> void:
	if busy:
		return
	editing = true
	card.visible = false
	if handle:
		handle.visible = false
	goals_btn.visible = false
	meters.visible = false
	var to := cam_home
	to.origin = Vector3(0, 10.5, 5.2)
	to = to.looking_at(Vector3(0, 0, 0.1), Vector3.UP)
	var tw := create_tween().set_parallel()
	tw.tween_property(cam, "transform", to, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_property(cam, "v_offset", -0.6, 0.6)
	sel_ring = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.55
	t.outer_radius = 0.65
	sel_ring.mesh = t
	sel_ring.material_override = Kit.glow(Color("ffe27a"), 1.5)
	sel_ring.visible = false
	world.add_child(sel_ring)
	_build_edit_ui()
	if not GameState.tut.has("edit"):
		GameState.tut["edit"] = true
		_toast("島をつくる", "物をドラッグで動かす。おばけも寄ってくる")


func _build_edit_ui() -> void:
	if edit_ui:
		edit_ui.queue_free()
	edit_ui = Control.new()
	edit_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	edit_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edit_ui)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color(1, 0.99, 0.97, 0.96), 22, 0.18, Vector2(14, 12)))
	p.position = Vector2(14, 470)
	p.size = Vector2(332, 0)
	edit_ui.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	edit_name = Kit.text("物をタップして、動かす", 15, Color("2a2233"), true, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(edit_name)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var rot := Kit.button("回す", Color("f3ecff"), _rotate_sel, Color("6a5bd6"), 38, 14)
	rot.custom_minimum_size.x = 96
	row.add_child(rot)
	var hide := Kit.button("しまう", Color("fde7e3"), _hide_sel, Color("c0473b"), 38, 14)
	hide.custom_minimum_size.x = 96
	row.add_child(hide)
	v.add_child(row)
	# しまった物（タップで島に戻す）
	var hidden: Array = []
	for k in _movable_keys():
		if not items[k].visible:
			hidden.append(k)
	if not hidden.is_empty():
		var fl := HFlowContainer.new()
		fl.add_theme_constant_override("h_separation", 6)
		for k in hidden:
			var key: String = k
			fl.add_child(_link("＋" + GameState.ITEM_NAME[key], func(): _unhide(key)))
		v.add_child(fl)
	v.add_child(Kit.button("できた", Color("ff8a5b"), _exit_edit))
	v.add_child(_link("島をシェアする", _share))
	await get_tree().process_frame
	p.size.y = 0
	await get_tree().process_frame
	p.position.y = 628 - p.size.y


func _edit_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		if event.pressed:
			if pos.y > 460 or pos.y < 60:
				return
			var best := ""
			var bd := 56.0
			for k in _movable_keys():
				var g: Node3D = items[k]
				if not g.visible:
					continue
				var d := cam.unproject_position(g.global_position + Vector3(0, 0.3, 0)).distance_to(pos)
				if d < bd:
					bd = d
					best = k
			if best != "":
				_select(best)
				dragging = true
		else:
			if dragging:
				dragging = false
				_drop()
	elif (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT)) and dragging and sel != "":
		var from := cam.project_ray_origin(event.position)
		var dir := cam.project_ray_normal(event.position)
		if absf(dir.y) < 1e-4:
			return
		var gp := from + dir * (-from.y / dir.y)
		gp = Vector3(snappedf(gp.x, 0.25), 0, snappedf(gp.z, 0.25))
		if not _inside(gp, 0.6) or gp.z < -2.3:
			return
		var g: Node3D = items[sel]
		g.position = Vector3(gp.x, g.position.y, gp.z)
		sel_ring.position = Vector3(gp.x, 0.05, gp.z)
		_move_spots(sel)


func _select(k: String) -> void:
	sel = k
	Kit.play(self, "tap", 1.2)
	edit_name.text = GameState.ITEM_NAME.get(k, k)
	var g: Node3D = items[k]
	sel_ring.visible = true
	sel_ring.position = Vector3(g.position.x, 0.05, g.position.z)
	var tw := create_tween()
	tw.tween_property(g, "scale", Vector3.ONE * 1.12, 0.1)
	tw.tween_property(g, "scale", Vector3.ONE, 0.15)


func _save_item(k: String) -> void:
	var g: Node3D = items[k]
	var l: Dictionary = GameState.layout.get(k, {})
	l.x = snappedf(g.position.x, 0.05)
	l.z = snappedf(g.position.z, 0.05)
	l.r = int(round(fposmod(g.rotation.y, TAU) / (PI / 4.0))) % 8
	l.h = not g.visible
	GameState.layout[k] = l


func _drop() -> void:
	if sel == "":
		return
	_save_item(sel)
	Kit.play(self, "pop", 1.0)
	var g: Node3D = items[sel]
	burst.position = g.position + Vector3(0, 0.3, 0)
	burst.amount = 16
	burst.restart()
	burst.emitting = true
	# 近くのおばけが寄ってきて、よろこぶ
	for w in walkers:
		var ob: Obake3D = w.o
		if ob.position.distance_to(g.position) < 2.2:
			w.target = g.position + Vector3(randf_range(-0.6, 0.6), 0, randf_range(0.5, 0.8))
			w.next_act = "look"
			w.wait = 0.2
			var tw := create_tween()
			tw.tween_property(ob, "position:y", 0.35, 0.15)
			tw.tween_property(ob, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _rotate_sel() -> void:
	if sel == "":
		return
	var g: Node3D = items[sel]
	create_tween().tween_property(g, "rotation:y", g.rotation.y + PI / 4.0, 0.2).set_trans(Tween.TRANS_BACK)
	await get_tree().create_timer(0.22).timeout
	_move_spots(sel)
	_save_item(sel)


func _hide_sel() -> void:
	if sel == "":
		return
	items[sel].visible = false
	_save_item(sel)
	spots = spots.filter(func(sp): return sp.get("group", "") != sel)
	sel = ""
	sel_ring.visible = false
	_build_edit_ui()


func _unhide(k: String) -> void:
	var g: Node3D = items[k]
	g.visible = true
	g.position = Vector3(0.2, g.position.y, 0.6)
	_save_item(k)
	_build_edit_ui()
	_select(k)


func _exit_edit() -> void:
	editing = false
	GameState.save()
	main.go("garden")


# ---------- シェア ----------

var share_ui: Control


func _share() -> void:
	if GameState.nickname == "":
		_ask_name()
		return
	var code := GameState.island_code(_movable_keys())
	var url: String = GameState.SHARE_URL + code
	DisplayServer.clipboard_set(url)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""(function(u){ if (navigator.share) { navigator.share({title: 'Paw Time', text: 'わたしの島', url: u}).catch(function(){}); } else if (navigator.clipboard) { navigator.clipboard.writeText(u); } })('%s')""" % url)
	Kit.play(self, "chime", 1.1)
	_popup("島のコードをコピーした", "リンクを送ると、%sの島に遊びに来てもらえる" % GameState.nickname, code)


func _ask_name() -> void:
	var box := _popup("島の呼び名", "シェアしたとき、みんなに見える名前", "")
	var le := LineEdit.new()
	le.placeholder_text = "たとえば：みか"
	_style_edit(le)
	le.max_length = 10
	le.add_theme_font_override("font", Kit.bold())
	le.add_theme_font_size_override("font_size", 16)
	box.add_child(le)
	box.move_child(le, 2)
	box.add_child(Kit.button("これにする", Color("ff8a5b"), func():
		GameState.nickname = le.text.strip_edges() if le.text.strip_edges() != "" else "ななし"
		GameState.save()
		share_ui.queue_free()
		_share()))


func _style_edit(le: LineEdit) -> void:
	var st := Kit.pill(Color("f3ecff"), 12, 0.0, Vector2(10, 8))
	le.add_theme_stylebox_override("normal", st)
	le.add_theme_stylebox_override("focus", st)
	le.add_theme_stylebox_override("read_only", st)
	le.add_theme_color_override("font_color", Color("2a2233"))
	le.add_theme_color_override("font_uneditable_color", Color("4a3f52"))
	le.add_theme_color_override("font_placeholder_color", Color("a89ea6"))


## 小さなお知らせの箱。中の VBox を返す
func _popup(title: String, body: String, code: String) -> VBoxContainer:
	if share_ui and is_instance_valid(share_ui):
		share_ui.queue_free()
	share_ui = Control.new()
	share_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(share_ui)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.06, 0.14, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	share_ui.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color("fffaf2"), 22, 0.25, Vector2(18, 16)))
	p.position = Vector2(24, 170)
	p.size = Vector2(312, 0)
	share_ui.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(Kit.text(title, 18, Color("2a2233"), true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Kit.wrap(Kit.text(body, 13, Color("6a5f70"), false, HORIZONTAL_ALIGNMENT_CENTER)))
	if code != "":
		var le := LineEdit.new()
		le.text = code
		le.editable = false
		_style_edit(le)
		le.add_theme_font_override("font", Kit.bold())
		le.add_theme_font_size_override("font_size", 11)
		v.add_child(le)
		v.add_child(Kit.button("とじる", Color(1, 1, 1, 0.95), func(): share_ui.queue_free(), Color("6a5f70"), 40, 14))
	return v


# ---------- おでかけ（ほかの人の島を見る） ----------

var visit_card: PanelContainer


func _start_visit() -> void:
	# 上は「〇〇の島」と「かえる」だけ
	for c in get_children():
		if c is HBoxContainer:
			for k in c.get_children():
				k.visible = false
	goals_btn.visible = false
	var top := HBoxContainer.new()
	top.position = Vector2(12, 12)
	top.size = Vector2(336, 40)
	add_child(top)
	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.92), 20, 0.14, Vector2(12, 6)))
	dp.add_child(Kit.text("%sの島" % V.name, 15, Color("2a2233"), true))
	top.add_child(dp)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var back := Kit.button("かえる", Color(1, 1, 1, 0.92), _go_home, Color("8a5bd6"), 38, 15)
	back.custom_minimum_size.x = 72
	top.add_child(back)
	night = 0.0
	_apply_time(0.0)
	_clear_card()
	card_box.add_child(Kit.text("%sの島に、おでかけ" % V.name, 18, Color("2a2233"), true))
	card_box.add_child(Kit.text("おばけ %d 体・島 Lv%d" % [V.residents.size() + 1, int(V.level) + 1], 14, Color("6a5f70")))
	if not _left_here():
		card_box.add_child(Kit.button("おばけを1体、おいていく", Color("ff8a5b"), _pick_present))
	else:
		card_box.add_child(Kit.text("おみやげのおばけを、おいてきた", 14, Color("3f7d4f"), true))
	card_box.add_child(_link("自分の島にかえる", _go_home))
	_card_fit()
	_pop_card()


func _left_here() -> bool:
	for k in GameState.keepsakes:
		if k.get("code", "") == V.get("code", ""):
			return true
	return false


func _pick_present() -> void:
	_clear_card()
	card_box.add_child(Kit.text("どの子を、おいていく？", 16, Color("2a2233"), true))
	var fl := HFlowContainer.new()
	fl.add_theme_constant_override("h_separation", 6)
	fl.add_theme_constant_override("v_separation", 6)
	var shown := 0
	for o in GameState.owned:
		if shown >= 6:
			break
		shown += 1
		var id: String = o.id
		fl.add_child(Kit.button(GameState.info(id).name, Color("f3ecff"), func(): _leave(id), Color("4a3f52"), 36, 13))
	card_box.add_child(fl)
	card_box.add_child(_link("やめる", _start_visit_card))
	_card_fit()


func _start_visit_card() -> void:
	_clear_card()
	card_box.add_child(Kit.text("%sの島に、おでかけ" % V.name, 18, Color("2a2233"), true))
	card_box.add_child(Kit.button("おばけを1体、おいていく", Color("ff8a5b"), _pick_present))
	card_box.add_child(_link("自分の島にかえる", _go_home))
	_card_fit()


## おいていった子は、この島に立って、手紙のように記録に残る（サーバーなし：自分の端末に）
func _leave(id: String) -> void:
	GameState.keepsakes.append({"owner": V.name, "id": id, "day": GameState.day, "code": V.get("code", "")})
	GameState.gifted = true
	if GameState.has_save():
		GameState.save()
	var ob := Obake3D.make(id)
	ob.scale = Vector3.ONE * 0.5
	ob.position = Vector3(0.2, 0, 1.2)
	world.add_child(ob)
	walkers.append({"o": ob, "id": id, "target": Vector3(0.6, 0, -1.8), "wait": 1.0, "act": "", "emote": null})
	burst.position = ob.position + Vector3(0, 0.5, 0)
	burst.restart()
	burst.emitting = true
	Kit.play(self, "chime")
	_toast("おみやげ", "%sを、%sの島においてきた" % [GameState.info(id).name, V.name])
	_clear_card()
	card_box.add_child(Kit.text("%sが、島になじんだ" % GameState.info(id).name, 16, Color("3f7d4f"), true))
	card_box.add_child(Kit.button("自分の島にかえる", Color("ff8a5b"), _go_home))
	_card_fit()


func _go_home() -> void:
	GameState.visit = {}
	if OS.has_feature("web"):
		JavaScriptBridge.eval("history.replaceState(null, '', location.pathname)")
	if GameState.has_save() and GameState.load_game():
		main.go("garden")
	else:
		main.go("title")


func demo_edit() -> void:
	_enter_edit()


func demo_move() -> void:
	# 花壇を右へ動かして、回す
	var k: String = "flowerbed" if items.has("flowerbed") else _movable_keys()[0]
	_select(k)
	var g: Node3D = items[k]
	g.position = Vector3(1.5, g.position.y, 1.5)
	_move_spots(k)
	_drop()
	_rotate_sel()


func demo_share() -> void:
	_share()


func demo_name_share() -> void:
	GameState.nickname = "みか"
	_share()


func demo_leave() -> void:
	_leave(GameState.owned[0].id)
