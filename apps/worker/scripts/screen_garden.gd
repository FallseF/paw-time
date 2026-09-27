extends Control
## 夜の庭（1日の起点）。休憩室の縁側の前に、小さな庭がある。
## 庭は毎日の暮らし（働いた日・休んだ日・夜のすくい・めあて）で育ち、仕事の日は店にちなんだ飾りが届く。おばけたちは庭で思い思いに過ごす。
## 朝：きのうのまとめ → 庭の変化。昼：シフト（ブースト）か休み。夜：川べりへ（満月の夜は月見）→ 朝へ。

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
var garden_bar: ProgressBar
var garden_label: Label
var poi_row: HBoxContainer
var card: PanelContainer
var card_box: VBoxContainer
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
	# 仕事さがし・はじめての流れ（島の説明／見つけた仕事の知らせ／毎日の求人と評価）の重ね画面。入口はこの1行だけ
	add_child(JobDesk.new())
	add_child(ChatHub.new()) # チャット（相棒をタップ →「話す」）。入口はこの1行だけ
	night = 1.0 if GameState.phase == "evening" else 0.0
	if OS.get_environment("OBAKE_NIGHT") != "":
		night = float(OS.get_environment("OBAKE_NIGHT")) # 確認用：0 昼 / 0.5 夕方 / 1 夜
	_apply_time(night)
	if night > 0.5:
		_light_deco()
	_refresh_hud()
	if GameState.phase == "morning":
		_show_morning()
	else:
		_show_card()
	_reveal_outfits()


## 届いた服（仕事・休み・おでかけ・図鑑の条件、光る玉の中身）を、ひとつずつ見せる
func _reveal_outfits() -> void:
	if OS.get_environment("OBAKE_NO_REVEAL") != "": # 確認用の撮影で、島だけを撮るとき
		return
	var list: Array = GameState.new_outfits.duplicate()
	GameState.new_outfits.clear()
	list.append_array(Wardrobe.check_unlocks())
	if list.is_empty():
		return
	await get_tree().create_timer(1.2).timeout
	for id in list:
		# 朝の庭の見せ場・知らせ（めあて・庭が育った）が終わってから、ひとつずつ
		while is_inside_tree() and (busy or Toasts.busy()):
			await get_tree().create_timer(0.3).timeout
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
	View3D.fit(box, vp)
	world = Node3D.new()
	vp.add_child(world)

	var rig := Look.apply(world, "island", Color("e9d6c2"), false, true)
	env = rig.env
	sun = rig.key

	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	# 島が広がるほど、少し引いて全体を入れる
	cam.position = Vector3(0, 7.2, 7.4) * lerpf(1.0, 1.28, clampf(_L() / 10.0, 0, 1))
	cam.fov = 52
	cam.v_offset = -1.6
	world.add_child(cam)
	# 小島・広げた陸まで入るよう、寄り先をずらして引く
	var fit := _land_fit()
	cam.position = cam.position * float(fit.scale) + fit.shift
	cam.look_at(Vector3(0, 0.0, -0.4) + fit.shift)
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
	# 庭が満開になったあとも、めぐみ 80 ごとに星見草が一輪ふえる
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
	# 島の置き物キット（買って置いた物。おでかけ中は、コードに入っていた物）
	for pl in (V.get("kit", []) if _vis() else IslandKit.placed):
		_build_kit(pl)
	_park_vehicle()

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
			var tag := Kit.label3d("NEW " + tr(GameState.info(o.id).name), 30, Color("ffe27a"))
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


## 庭の見た目の段（おでかけ先はコードの値。自分の島は、いつも元気な庭）
func _T() -> int:
	return int(V.tier) if _vis() else 2


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
var sea_mesh: MeshInstance3D
var terrain: MeshInstance3D
var terrain_stage := -1
var sea_mat: StandardMaterial3D


## 島：海・砂浜・芝の円と、うしろの丘（休憩室が建つ）
func _build_land(L: int, ground_c: Color) -> void:
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400) # 引いたカメラでも、画面の下の端と水平線まで海が届くように
	sea.mesh = pm
	sea_mat = StandardMaterial3D.new()
	sea_mat.albedo_color = Color("4fa8bd")
	sea_mat.roughness = 0.4
	if ResourceLoader.exists(IslandProps.GLB % "terrain_s0"):
		# 地形があるときは、浅瀬の砂が透けて見える海にする
		sea_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sea_mat.albedo_color = Color(0.2, 0.62, 0.74, 0.72)
		sea_mat.metallic_specular = 0.6
		sea_mat.roughness = 0.25
	sea.material_override = sea_mat
	sea.position.y = -0.14
	world.add_child(sea)
	sea_mesh = sea
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
	# Blender 製の地形（砂浜・崖・小島）があれば、それを使う。円の芝と砂・うしろの台は隠す
	if _build_terrain(L):
		land_grass.visible = false
		land_sand.visible = false
		for c in world.get_children():
			if c is MeshInstance3D and c != sea_mesh and c.position.z < -4.0:
				c.visible = false
		for id in _expansion_list():
			_build_expansion(id, false)
		return
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
	if terrain:
		var st := IslandKit.stage_for(L)
		if st != terrain_stage:
			_build_terrain(L)
			terrain.scale = Vector3(0.92, 1, 0.92)
			create_tween().tween_property(terrain, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
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
			Outfit.dress(host_node, V.get("outfits", {}).get("my", {}))
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
			nm = QuizData.type_name(tid2)
		if not _vis() and GameState.my_obake.get("special", "") != "":
			nm = SpecialObake.pet_name() # とくべつな子は呼び名で
	var l := Kit.label3d(nm, 34, Color("ffe27a"))
	l.pixel_size = 0.009
	l.no_depth_test = true
	l.render_priority = 20
	l.outline_render_priority = 19
	l.position = Vector3(0, 1.9 if not Rares.is_rare(id) else 2.5, 0)
	host_node.add_child(l)


## 島の大きさ（段が上がるほど、岸がひろがる）
func _island_r(L: int) -> float:
	if terrain:
		return IslandKit.STAGES[IslandKit.stage_for(L)].radius - 0.25
	return 3.6 + L * 0.13


func _inside(p: Vector3, margin := 0.3) -> bool:
	if terrain:
		# 段 2 の小島・広げた陸と小島も、島の中
		for c in IslandKit.land_circles(IslandKit.stage_for(_L()), _expansion_list()).slice(1):
			if Vector2(p.x - c.x, p.z - c.y).length() < c.z - margin:
				return true
	return Vector2(p.x, p.z).length() < _island_r(_L()) - margin or p.z < -2.4


## 地形（段ごとの島の形）。ファイルが無ければ false
func _build_terrain(L: int) -> bool:
	var st := IslandKit.stage_for(L)
	var mesh := IslandProps.glb("terrain_s%d" % st) if ResourceLoader.exists(IslandProps.GLB % ("terrain_s%d" % st)) else null
	if mesh == null:
		return false
	if terrain == null:
		terrain = MeshInstance3D.new()
		terrain.name = "terrain"
		var m := Obake3D.skin(Color.WHITE, 0.0, null, 0.06, 0.0, false, 0.02).duplicate() as ShaderMaterial
		m.set_shader_parameter("vertex_albedo", 1.0)
		m.set_shader_parameter("ground_mottle", 0.07)
		m.set_shader_parameter("top_light", 0.0)
		terrain.material_override = m
		world.add_child(terrain)
	terrain.mesh = mesh
	terrain_stage = st
	_update_seabed(mesh)
	return true


var seabed: MeshInstance3D


## 透ける海の下の、深い海の底。地形のいちばん深い所と同じ頂点色・同じ材質の大きな板にして、
## 地形の四角い端（前はここが暗い四角に見えていた）と見分けがつかないようにする
func _update_seabed(mesh: Mesh) -> void:
	var arr := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var c: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	if v.is_empty() or c.size() != v.size():
		return
	var lo := 0
	for i in v.size():
		if v[i].y < v[lo].y:
			lo = i
	var col: Color = c[lo]
	var y: float = v[lo].y - 0.004
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 200.0
	var corners := [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_color(col)
		st.set_normal(Vector3.UP)
		st.add_vertex(corners[idx])
	if seabed == null:
		seabed = MeshInstance3D.new()
		seabed.name = "seabed"
		world.add_child(seabed)
	seabed.mesh = st.commit()
	seabed.material_override = terrain.material_override
	seabed.position.y = y


# ---------- プレイヤーが広げた陸・小島 ----------

var exp_nodes := {}


func _expansion_list() -> Array:
	return V.get("expansions", []) if _vis() else IslandKit.expansions()


## 広げた陸（または小島と橋）を置く。animate なら海からせり上がり、おばけがよろこぶ
func _build_expansion(id: String, animate: bool) -> void:
	var R: float = IslandKit.STAGES[IslandKit.stage_for(_L())].radius
	var sh := IslandKit.expansion_shape(id, R)
	if sh.is_empty() or terrain == null:
		return
	var g := Node3D.new()
	g.name = "exp_" + id
	world.add_child(g)
	exp_nodes[id] = g
	var land := MeshInstance3D.new()
	land.mesh = IslandProps.land_lobe(sh.r, IslandKit.EXPANSIONS.find(IslandKit.expansion(id)))
	land.material_override = terrain.material_override
	land.position = Vector3(sh.center.x, -0.004, sh.center.z)
	g.add_child(land)
	if sh.has("bridge_from"):
		var from: Vector3 = sh.bridge_from
		var to: Vector3 = sh.bridge_to
		var br := IslandProps.build("bridge_islet")
		br.position = (from + to) * 0.5
		br.rotation.y = -atan2(to.z - from.z, to.x - from.x)
		br.scale = Vector3(from.distance_to(to) / 2.4, 1, 1)
		g.add_child(br)
	# 小さな飾り：陸のふちに岩と草
	var r2 := RandomNumberGenerator.new()
	r2.seed = hash(id)
	for k in 3:
		var a := r2.randf() * TAU
		var rk := MeshInstance3D.new()
		rk.mesh = IslandProps.glb("rock")
		rk.material_override = Obake3D.prop(Color("b9b3ad").darkened(r2.randf() * 0.15))
		rk.position = Vector3(sh.center.x + cos(a) * (sh.r + 0.1), -0.1, sh.center.z + sin(a) * (sh.r + 0.1))
		rk.scale = Vector3.ONE * r2.randf_range(0.2, 0.32)
		g.add_child(rk)
	if not animate:
		return
	g.position.y = -0.9
	var tw := create_tween()
	tw.tween_property(g, "position:y", 0.0, 1.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	burst.position = Vector3(sh.center.x, 0.2, sh.center.z)
	burst.amount = 40
	burst.restart()
	burst.emitting = true
	Kit.play(self, "chime", 0.9)
	# 近くのおばけ（あるじも）が跳ねてよろこぶ
	var cheer: Array = walkers.map(func(w): return w.o)
	if host_node:
		cheer.append(host_node)
	for ob in cheer:
		if not is_instance_valid(ob):
			continue
		var t2 := create_tween()
		t2.tween_interval(randf_range(0.3, 0.8))
		t2.tween_property(ob, "position:y", 0.45, 0.16)
		t2.tween_property(ob, "position:y", 0.0, 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		var l := Kit.label3d("♪", 40, Color("fff6a8"))
		l.position = Vector3(0.3, 1.6, 0)
		ob.add_child(l)
		var t3 := l.create_tween()
		t3.tween_interval(1.6)
		t3.tween_property(l, "modulate:a", 0.0, 0.5)
		t3.tween_callback(l.queue_free)


## 島全体（地形の段・小島・広げた陸）が入るよう、カメラの寄り先と引き具合を決める {shift, scale}
func _land_fit() -> Dictionary:
	if not ResourceLoader.exists(IslandProps.GLB % "terrain_s0"):
		return {"shift": Vector3.ZERO, "scale": 1.0}
	var st := IslandKit.stage_for(_L())
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for c in IslandKit.land_circles(st, _expansion_list()):
		mn = Vector2(minf(mn.x, c.x - c.z), minf(mn.y, c.y - c.z))
		mx = Vector2(maxf(mx.x, c.x + c.z), maxf(mx.y, c.y + c.z))
	var w := mx.x - mn.x
	var front := mx.y
	var shift := Vector3((mn.x + mx.x) * 0.5, 0, 0)
	var scale := maxf(1.0, maxf(w / 9.6, (front + 3.0) / 8.0))
	return {"shift": shift, "scale": scale}


## 段が上がるほど、ひと目で分かる変化：道の灯り（段の数だけ）・生け垣・野の花・夜空の色
func _build_dressing(L: int) -> void:
	if items.has("dressing"):
		items.dressing.queue_free()
		items.erase("dressing")
		lamp_lights = lamp_lights.filter(func(l): return is_instance_valid(l) and not l.is_queued_for_deletion() and not l.has_meta("dressing"))
	var g := _group("dressing", Vector3.ZERO)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	# 道の灯り：段が上がると、小道の両側に並ぶ（夜に灯る）。置き物キットで自分で飾れるので、自動はひかえめに（最大 4 本）
	for i in mini(L, 4):
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
	var n_hedge := 0 if L < 3 else (2 if L < 6 else (3 if L < 9 else 4)) # 島が読みやすいよう、ひかえめに
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
	var n_flower := 0 if L < 4 else (12 if L < 8 else 24)
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
	# 夜空の色：段が上がるほど、深い紫に（満開で、ほんのり星の色）
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
	var names := {1: "芝", 2: "花壇", 3: "灯り", 4: "花", 5: "池", 6: "縁台", 7: "桜", 8: "ほたる", 9: "月見台", 10: "星見の木"}
	var l := Kit.label3d(tr("%s\n予定地") % tr(names.get(nx, "")), 44, Color("4a3f52"))
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
		var tag := Kit.label3d(tr(store).split(" ")[-1] if not Kit.is_en() else tr(store).split(" ")[0], 30, Color("fff6e8"))
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

var kit_spinners: Array = []


## 買って置いた物をひとつ組む。名前は "kit:<番号>"。住人の行き先もいっしょに動く
func _build_kit(pl: Dictionary) -> Node3D:
	var id: String = pl.id
	var it := IslandKit.item(id)
	if it.is_empty():
		return null
	var nm := "kit:%d" % int(pl.u)
	var home := Vector3(float(pl.x), 0, float(pl.z))
	var g := _group(nm, home)
	g.rotation.y = int(pl.get("r", 0)) * PI / 4.0
	g.set_meta("kit_id", id)
	g.set_meta("kit_u", int(pl.u))
	var body := IslandProps.build(id)
	g.add_child(body)
	for l in body.find_children("*", "OmniLight3D", true, false):
		lamp_lights.append(l)
		l.light_energy = lerpf(0.0, 1.2, night)
	for n in body.find_children("*", "Node3D", true, false):
		if n.has_meta("spin"):
			kit_spinners.append(n)
	for sp in it.spots:
		_spot({"pos": home + Vector3(sp[0], sp[1], sp[2]), "act": sp[3]})
	return g


var crickets: AudioStreamPlayer
var island_rig := {}


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
	# 空：水平線の上は空の色（昼は水色、夕方は茜、夜は紺）。前は昼に砂色の帯が出ていた
	var day_bg := Color("bfe4f4")
	var eve_bg := Color("f2b99c")
	env.background_color = day_bg.lerp(eve_bg, clampf(n * 2.0, 0.0, 1.0)).lerp(night_sky, clampf(n * 2.0 - 1.0, 0.0, 1.0))
	if sea_mat:
		var a := sea_mat.albedo_color.a
		sea_mat.albedo_color = (Color(0.2, 0.62, 0.74) if a < 1.0 else Color("4fa8bd")).lerp(Color("1a2a52"), n)
		sea_mat.albedo_color.a = a
	# 昼 → 夕方 → 夜 の光（Look の island_day / island_evening / island_night を混ぜる）
	if island_rig.is_empty():
		island_rig = Look.island_rig(world)
	Look.island_time(island_rig, env, sun, n)
	lamp_lights = lamp_lights.filter(func(l): return is_instance_valid(l) and not l.is_queued_for_deletion())
	for l in lamp_lights:
		l.light_energy = lerpf(0.0, 1.0, n) if l.has_meta("dressing") or l.has_meta("kit_lamp") else lerpf(0.4, 1.8, n)
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

var _clock_t := 0.0


func _process(delta: float) -> void:
	_t += delta
	_sync_expand()
	_sync_hud()
	# 実際の時計：夕方になった・朝が来た（30 秒ごと。自分の島、はじめての流れのあと）
	_clock_t += delta
	if _clock_t > 30.0:
		_clock_t = 0.0
		if not _vis() and not busy and not editing and Onboarding.at("done") and OS.get_environment("OBAKE_START") == "":
			var ph: String = GameState.phase
			if GameState.sync_clock() or GameState.phase != ph:
				main.go("garden")
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
	for sp in kit_spinners:
		if is_instance_valid(sp):
			sp.rotation.z += delta * float(sp.get_meta("spin"))
	if parked and is_instance_valid(parked) and parked.name != "helicopter":
		parked.position.y = float(parked.get_meta("base_y")) + sin(_t * 1.6) * 0.025
		parked.rotation.z = sin(_t * 1.1) * 0.03
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
		var sp := View3D.unproject(cam, ob.global_position + Vector3(0, 0.35, 0))
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


const LINES_DAY := ["花がのびた", "朝の空気がすき", "庭がきらきらしてる", "今日は、なにもしなくていい気がする", "花が下を見ている。こっちも見ている", "お茶にしよう"]
const LINES_OWN := {
	"receipt": ["レシート、のびた", "合計は、言えない", "…ピッ"],
	"bubble": ["ぷく", "割れた。平気", "洗ったら、減った"],
	"tray": ["お盆は落とさない", "中身は知らない", "…（バランス中）"],
	"pan": ["じゅう", "さわらないで。あつくはない", "油の音がすき"],
	"box": ["箱から出ない", "住所はここ", "中は広い（ことにしている）"],
	"lantern": ["夜はこれから", "明るいでしょ", "…消さないで"],
}
const LINES_NIGHT := ["川べり、行く？", "虫の声", "月がきれい", "今夜は、なにがすくえるかな"]


func _line_for(id: String) -> String:
	if Rares.is_rare(id):
		return ["……", "…", "（じっとこっちを見ている）", "……（うなずく）"].pick_random()
	if LINES_OWN.has(id) and randf() < 0.45:
		return LINES_OWN[id].pick_random()
	if night > 0.5 and randf() < 0.4:
		return LINES_NIGHT.pick_random()
	return LINES_DAY.pick_random()


# ---------- UI ----------

## マイスキル（スキルの記録）への小さな札。左の列、キセカエの下（キセカエが無い日はその場所）
func _skills_pill() -> void:
	if _vis():
		return
	var y := 98 if (GameState.day >= 1 or not Wardrobe.fresh.is_empty()) else 58
	var sk := Kit.button(tr("SK_PILL"), Color(1, 1, 1, 0.92), func(): main.go("skills"), Color("3f8a55"), 32, 13)
	sk.position = Vector2(12, y)
	sk.size = Vector2(0, 32)
	add_child(sk)
	hud_pill(sk)


var hud_pills: Array = [] # 上の段の札（キセカエ・マイスキル・しごと・話す）。くわしく・めあてを開いたら、重なる札はしまう


## 上の段の札として登録する（しごと・話すの札は、重ね画面の係から）
func hud_pill(b: Control) -> void:
	hud_pills.append(b)


## 島の段のくわしく（庭 Lv / ポイ）・めあての欄を開いている間は、それに重なる札をしまう（閉じたら戻す）
func _sync_hud() -> void:
	var covers: Array = []
	if meters and meters.visible:
		covers.append(meters.get_global_rect())
	if goals_panel and is_instance_valid(goals_panel):
		covers.append(goals_panel.get_global_rect())
	hud_pills = hud_pills.filter(func(b): return is_instance_valid(b) and not b.is_queued_for_deletion())
	for b in hud_pills:
		var r: Rect2 = b.get_global_rect()
		var covered: bool = covers.any(func(c): return c.intersects(r))
		if covered != b.get_meta("hud_covered", false):
			b.set_meta("hud_covered", covered)
			b.visible = not covered


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
	# キセカエ（2日目から、または新しい服が届いたら）。上の3つとは別に、左下の小さな札
	if (GameState.day >= 1 or not Wardrobe.fresh.is_empty()) and not _vis():
		var wd := Kit.button(tr("Wardrobe") + ("  NEW" if not Wardrobe.fresh.is_empty() else ""), Color(1, 1, 1, 0.92), func(): main.go("wardrobe"), Color("ff8a5b"), 32, 13)
		wd.position = Vector2(12, 58)
		wd.size = Vector2(0, 32)
		add_child(wd)
		hud_pill(wd)
	_skills_pill()
	var zk := Kit.button("図鑑", Color(1, 1, 1, 0.92), func(): main.go("zukan"), Color("8a5bd6"), 38, 15)
	zk.custom_minimum_size.x = 64
	top.add_child(zk)
	flow_label = RichTextLabel.new() # 使わない（互換のため）
	flow_label.visible = false
	add_child(flow_label)

	# くわしく（島の段の札をタップしたときだけ）
	meters = PanelContainer.new()
	meters.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.95), 18, 0.12, Vector2(12, 8)))
	meters.position = Vector2(12, 58)
	meters.size = Vector2(336, 0)
	meters.visible = false
	add_child(meters)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 4)
	meters.add_child(mv)
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
	# 中身の高さが遅れて決まっても（Web）、そのつど縮めて下にそろえ直す
	Kit.keep_fit(card, func():
		card.size.y = 0
		card.position.y = 626 - card.size.y
		_place_handle())


func _refresh_hud() -> void:
	top_day.text = GameState.day_label()
	# 島の段（タップで、庭の育ちと手もちのポイ）
	rhythm_chip.text = tr("島 Lv%d") % (GameState.garden_level + 1)
	for k in ["normal", "hover", "pressed", "focus"]:
		rhythm_chip.add_theme_stylebox_override(k, Kit.pill(Color(1, 1, 1, 0.92), 19, 0.14, Vector2(12, 4)))
	rhythm_chip.add_theme_color_override("font_color", Color("3f7d4f"))
	rhythm_chip.add_theme_color_override("font_hover_color", Color("3f7d4f"))
	var cur: int = {"morning": 0, "day": 1, "evening": 2}.get(GameState.phase, 1)
	var steps := ["朝", "昼", "夜"]
	var out := []
	for i in steps.size():
		if i == cur:
			out.append("[b][color=#ff8a5b]%s[/color][/b]" % steps[i])
		else:
			out.append("[color=#8a7a88]%s[/color]" % steps[i])
	flow_label.text = "[color=#c9bfc6]・[/color]".join(out)
	goals_btn.text = tr("めあて %d/3 ▼") % GameState.goals_done()
	if goals_panel:
		_toggle_goals()
		_toggle_goals()
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
	_place_expand()
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


var expand_btn: Button


## 島を広げる札（いつも見える。カードの左上、カードをしまったら左下）。広げきったら出さない
func _place_expand() -> void:
	var show: bool = not _vis() and not editing and GameState.day >= 1 and IslandKit.expansions().size() < IslandKit.MAX_EXPANSIONS
	if expand_btn == null:
		if not show:
			return
		expand_btn = Kit.button(tr("EXPAND_PILL"), Color("e9f6e6"), _expand_from_pill, Color("3f7d4f"), 30, 12)
		add_child(expand_btn)
	expand_btn.visible = show and not overlay_open()
	expand_btn.size = Vector2(0, 30)
	expand_btn.position = Vector2(14, 598) if card_hidden or not card.visible else Vector2(card.position.x + 6, card.position.y - 14)


## 島の上に、何かが重なって開いているか（しごとのシート・求人カード・シフトの入力・チャット・カタログ・お知らせの箱・届いた服）。
## 開いている間は「＋ ひろげる」札を出さない（カードや見出しの上に札が乗ってしまうので）
func overlay_open() -> bool:
	for n in [catalog_ui, share_ui, raft_ui]:
		if n and is_instance_valid(n) and not n.is_queued_for_deletion():
			return true
	for c in get_children():
		if c is ScreenChat or c is OutfitReveal:
			return true
		if c is JobDesk and c.overlay_open():
			return true
	return false


## 毎フレーム：重ね画面が開いたら札を隠し、閉じたら戻す
func _sync_expand() -> void:
	if expand_btn == null:
		return
	var want: bool = not _vis() and not editing and GameState.day >= 1 and IslandKit.expansions().size() < IslandKit.MAX_EXPANSIONS
	var on := want and not overlay_open()
	if expand_btn.visible != on:
		expand_btn.visible = on


## 札から：島づくりに入って、広げられる場所のカードを開く（足りるところがあれば、そこを先に）
func _expand_from_pill() -> void:
	if busy or editing:
		return
	_enter_edit()
	await get_tree().create_timer(0.7).timeout
	var pick := ""
	for e in IslandKit.EXPANSIONS:
		if IslandKit.can_expand(e.id):
			if pick == "":
				pick = e.id
			if IslandKit.expansion_missing(e.id).is_empty():
				pick = e.id
				break
	if pick != "":
		_expand_card(pick)


## 材料がそろって広げられるようになったら、一度だけ知らせて札をゆらす（広げた数ごとに）
func _maybe_expand_nudge() -> void:
	if _vis() or expand_btn == null or not expand_btn.visible:
		return
	var key := "expand_nudge_%d" % IslandKit.expansions().size()
	if GameState.tut.has(key):
		return
	for e in IslandKit.EXPANSIONS:
		if IslandKit.can_expand(e.id) and IslandKit.expansion_missing(e.id).is_empty():
			GameState.tut[key] = true
			GameState.save()
			_toast(tr("KIT_UI_EXPAND"), tr("EXPAND_READY"))
			Kit.nudge(expand_btn)
			return


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
	if GameState.phase == "day" and _work_card():
		pass
	elif GameState.phase == "day":
		var reg := Reminders.morning() if GameState.skip_shift_day != GameState.day else {}
		if not reg.is_empty():
			# 今日の登録シフト（まだ始まっていない）：時刻と場所と地図。行ったら「仕事に行ってくる」
			card_box.add_child(Kit.text("今日のシフト", 18, Color("2a2233"), true))
			card_box.add_child(Kit.wrap(Kit.text("%s–%s ・ %s" % [Reminders.clock(reg.start), Reminders.clock(reg.end), String(reg.get("place", reg.get("store", "")))], 14, Color("6a5f70"), true)))
			card_box.add_child(_link(tr("JOB_MAP") + " ›", func(): OS.shell_open(JobListings.maps_url(reg))))
			card_box.add_child(Kit.button(tr("I'm going to work"), Color("ff8a5b"), func(): main.go("work")))
			card_box.add_child(_link("今日は休む", _rest))
		elif s.get("chore", false) and GameState.skip_shift_day != GameState.day and not GameState.shift_done_today:
			card_box.add_child(Kit.text("今日のおてつだい", 18, Color("2a2233"), true))
			card_box.add_child(Kit.text(GameState.CHORE_TEXT[s.role], 14, Color("6a5f70")))
			card_box.add_child(Kit.button("おてつだいする", Color("ff8a5b"), _do_shift))
			var row := HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_child(_link("今日はのんびりする", _rest))
			row.add_child(_link(tr("I'm going to work"), func(): main.go("work")))
			card_box.add_child(row)
		elif s.role != "" and GameState.skip_shift_day != GameState.day and not GameState.shift_done_today:
			card_box.add_child(Kit.text("今日のシフト", 18, Color("2a2233"), true))
			card_box.add_child(Kit.text(tr("%s・%s") % [tr(s.store), tr(GameState.ROLE_LABEL[s.role])], 14, Color("6a5f70")))
			card_box.add_child(Kit.text(tr("%sのシフト・%d時間") % [tr(s.band), int(s.hours)], 13, Color("6a5f70")))
			var sname: String = tr(s.store)
			card_box.add_child(_link(tr("JOB_MAP") + " ›", func(): OS.shell_open(JobListings.maps_url({"store": sname}))))
			if not GameState.tut.has("shift"):
				_guide("働くと、庭に飾りが届く")
			var b := Kit.button("シフトに行く", Color("ff8a5b"), _do_shift)
			card_box.add_child(b)
			card_box.add_child(_link("今日は休む", _rest))
			if not GameState.tut.has("shift"):
				Kit.nudge.call_deferred(b)
		else:
			card_box.add_child(Kit.text("夜の庭へ、ようこそ" if first else ("今日の仕事は、おしまい" if GameState.shift_done_today else "今日は休み"), 18, Color("2a2233"), true))
			card_box.add_child(Kit.text("毎日の暮らしで、庭が育つ" if first else "休みの日も、庭はちゃんと育つ", 14, Color("6a5f70")))
			# 夜は実際の時計で来る（夕方 5 時から、川べりへ）
			card_box.add_child(Kit.text("川べりは、夕方 5 時から", 14, Color("5b6fc2"), true))
			card_box.add_child(_link(tr("I'm going to work"), func(): main.go("work")))
			if GameState.day >= 2:
				card_box.add_child(_link("島をつくる・シェアする", _enter_edit))
			GameState.tut["first"] = true
	elif GameState.phase == "evening":
		if GameState.is_moon_night() and not GameState.scooped_tonight:
			card_box.add_child(Kit.text("今夜は満月の夜", 18, Color("2a2233"), true))
			card_box.add_child(Kit.text("川べりへ行った夜の数だけ、灯りがつく", 14, Color("6a5f70")))
			var b := Kit.button("月見をする", Color("5b4a9e"), func(): main.go("moon"))
			card_box.add_child(b)
			Kit.nudge.call_deferred(b)
		elif not GameState.scooped_tonight:
			card_box.add_child(Kit.text("夜になった", 18, Color("2a2233"), true))
			card_box.add_child(Kit.text("光る玉は、朝にかえる", 14, Color("6a5f70")))
			# 今夜のポイ：働いた日 2 本・休みの日 1 本（何時間でも同じ）
			GameState.grant_rest_net()
			var tn := GameState.tonight_nets()
			card_box.add_child(Kit.text(tr("今夜：ポイ %d 本（働いた日）") % tn if GameState.worked_today() else tr("今夜：ポイ 1 本（休みの日）"), 14, Color("5b6fc2"), true))
			if GameState.day >= 3:
				_deco_chips()
			var b := Kit.button("川べりで、おばけすくい", Color("5b6fc2"), func(): main.go("catch"))
			card_box.add_child(b)
			if not GameState.tut.has("scoop"):
				Kit.nudge.call_deferred(b)
			if GameState.can_gift() and GameState.day >= 4:
				var c: String = GameState.today().coworkers[0]
				card_box.add_child(_link(tr("%sにおすそわけ") % c, _gift))
			if GameState.day >= 2:
				card_box.add_child(_link("島をつくる・シェアする", _enter_edit))
		else:
			card_box.add_child(Kit.text("今夜のすくいは、おしまい", 18, Color("2a2233"), true))
			card_box.add_child(Kit.text(tr("玉を %d 個持ち帰った") % GameState.orbs.size(), 14, Color("6a5f70")))
			# 朝は実際の時計で来る（朝 5 時をすぎて開くと、玉がかえる）
			card_box.add_child(Kit.text("玉は、朝になったらかえる", 14, Color("8b7bff"), true))
			if GameState.day >= 2:
				card_box.add_child(_link("島をつくる・シェアする", _enter_edit))
	_card_fit()
	_pop_card()


## While your cat-obake is at work (a registered shift, or you pressed "I'm going to work"),
## the day card shows that instead. Returns true if it drew the card.
func _work_card() -> bool:
	WorkTogether.sync()
	if not WorkTogether.active():
		return false
	var st := WorkTogether.status()
	card_box.add_child(Kit.text(tr("At work together"), 18, Color("2a2233"), true))
	card_box.add_child(Kit.text(WorkTogether.line(st), 14, Color("6a5f70")))
	card_box.add_child(Kit.button(tr("Peek at work"), Color("ff8a5b"), func(): main.go("work")))
	card_box.add_child(_link(tr("Back home"), func():
		var r := WorkTogether.stop()
		_toast(tr("Shift's over!"), tr("+%d Paw Coins") % r.get("coins", 0))
		_show_card()))
	return true


func _gift() -> void:
	var c := GameState.gift()
	var o: Dictionary = GameState.owned.pick_random()
	Kit.play(self, "pop", 1.1)
	_toast("おすそわけ", tr("%sに、%sを1体わたした（写しなので、庭の子はそのまま）") % [c, tr(GameState.info(o.id).name)])
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
	var s0: Dictionary = GameState.today()
	if not s0.get("chore", false) and s0.get("role", "") != "":
		var w := WorkTogether.credit_recorded(s0.role, float(s0.get("hours", 0)), s0.get("store", ""))
		if int(w.coins) > 0:
			got.push_front({"kind": "coins", "id": s0.role, "text": tr("Your cat-obake worked too: +%d Paw Coins") % w.coins})
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
		st.bg_color = GameState.TYPE_COLOR.get(GameState.NETS[g.id].type, Color.WHITE) if g.kind == "poi" else (Color("ffc93d") if g.kind == "coins" else Color("8fd18a"))
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
	# 夕方になっていれば夜へ。まだ昼なら、働き終えた昼のカード
	if GameState.real_phase() == "evening" or OS.get_environment("OBAKE_START") != "" or OS.get_environment("OBAKE_DEMO") in ["play", "promo"]:
		await _to_evening()
	else:
		card.modulate.a = 0.0
		_show_card()
	busy = false


## 今日のシフトを休む（夜は時計どおりに来る）
func _rest() -> void:
	if busy:
		return
	GameState.tut["first"] = true
	GameState.skip_shift_day = GameState.day
	GameState.save()
	card.modulate.a = 0.0
	_show_card()


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


## 小さな知らせ。ほかの知らせ（めあて達成など）と重ならないよう、順番に出す（Toasts）
func _toast(title: String, body: String) -> void:
	Toasts.push(tr(title), tr(body), "info")


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
	# それから、きのうのまとめを短く（めぐみの数と、そのわけ）
	_clear_card()
	card_box.add_child(Kit.text("おはよう", 19, Color("2a2233"), true))
	var why: Array = []
	if ln.get("worked", false):
		why.append(tr("働いた日"))
	if ln.get("river", false):
		why.append(tr("川べりの夜"))
	var gl := tr("庭のめぐみ +%d") % int(ln.get("growth_gain", 0))
	if not why.is_empty():
		gl += "（%s）" % "・".join(why)
	card_box.add_child(Kit.text(gl, 14, Color("3f7d4f"), true))
	if WorkTogether.still_tired():
		card_box.add_child(Kit.text("きのうの残業で、猫はまだ少し疲れている", 13, Color("b0643a")))
	elif GameState.day >= 4:
		var om := GameState.omen()
		if om != "" and om.length() <= 24:
			card_box.add_child(Kit.text(om, 12, Color("8a5bd6")))
	var btn := Kit.button("今日をはじめる", Color("ff8a5b"), _after_morning)
	card_box.add_child(btn)
	if GameState.day == 1:
		_guide("働いた日も休んだ日も、庭は育つ")
	elif GameState.day == 2:
		_guide("右上に「めあて」ができた")
	elif GameState.day == 3:
		_guide("島の段の札をタップで、くわしく")
	elif GameState.day == 5:
		_guide("庭をよこになぞると、見回せる")
	_card_fit()
	_pop_card()
	Kit.play(self, "chime", 0.9)


func _after_morning() -> void:
	if busy:
		return
	GameState.phase = "day"
	GameState.save()
	_refresh_hud()
	card.modulate.a = 0.0
	_show_card()
	# けさ材料が届いて、島を広げられるようになったら知らせる
	await get_tree().create_timer(0.8).timeout
	_maybe_expand_nudge()


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
			_build_flowerbed(Vector3(-2.1, 0, 0.6), level, _T())
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
	_toast(tr("庭が育った：%s") % tr(st.name), tr(st.desc))
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
	for k in items:
		if String(k).begins_with("kit:") and is_instance_valid(items[k]):
			out.append(k)
	return out


func _item_name(k: String) -> String:
	if k.begins_with("kit:"):
		return IslandKit.name_of(items[k].get_meta("kit_id"))
	return GameState.ITEM_NAME.get(k, k)


func _enter_edit() -> void:
	if busy:
		return
	editing = true
	card.visible = false
	if handle:
		handle.visible = false
	if expand_btn:
		expand_btn.visible = false
	goals_btn.visible = false
	meters.visible = false
	var to := cam_home
	var fit := _land_fit()
	to.origin = Vector3(0, 10.5, 5.2) * float(fit.scale) + fit.shift
	to = to.looking_at(Vector3(0, 0, 0.1) + fit.shift, Vector3.UP)
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
	_build_exp_markers()
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
	edit_name = Kit.text(tr("KIT_UI_TAP"), 15, Color("2a2233"), true, HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(edit_name)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var rot := Kit.button(tr("KIT_UI_ROTATE"), Color("f3ecff"), _rotate_sel, Color("6a5bd6"), 38, 14)
	rot.custom_minimum_size.x = 96
	row.add_child(rot)
	var hide := Kit.button(tr("KIT_UI_STORE"), Color("fde7e3"), _hide_sel, Color("c0473b"), 38, 14)
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
			fl.add_child(_link("＋" + tr(GameState.ITEM_NAME[key]), func(): _unhide(key)))
		v.add_child(fl)
	# しまってある置き物（タップで島に出す）
	if not IslandKit.stock.is_empty():
		var fl2 := HFlowContainer.new()
		fl2.add_theme_constant_override("h_separation", 6)
		for id in IslandKit.stock:
			var kid: String = id
			fl2.add_child(_link("＋%s ×%d" % [IslandKit.name_of(kid), int(IslandKit.stock[kid])], func(): _place_from_stock(kid)))
		v.add_child(fl2)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 8)
	var shop := Kit.button(tr("KIT_UI_SHOP"), Color("fff2c8"), _open_catalog, Color("9a6a1a"), 50, 16)
	shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(shop)
	var done := Kit.button(tr("KIT_UI_DONE"), Color("ff8a5b"), _exit_edit)
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row2.add_child(done)
	v.add_child(row2)
	v.add_child(_link("島をシェアする", _share))
	Kit.keep_fit(p, func():
		p.size.y = 0
		p.position.y = 628 - p.size.y)


func _edit_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		if event.pressed:
			if pos.y > 460 or pos.y < 60:
				return
			# 岸の「＋」（島を広げる）
			for mk in exp_markers:
				if is_instance_valid(mk.node) and View3D.unproject(cam, mk.node.global_position).distance_to(pos) < 34.0:
					_expand_card(mk.id)
					return
			var best := ""
			var bd := 56.0
			for k in _movable_keys():
				var g: Node3D = items[k]
				if not g.visible:
					continue
				var d := View3D.unproject(cam, g.global_position + Vector3(0, 0.3, 0)).distance_to(pos)
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
		var from := cam.project_ray_origin(View3D.to_vp(cam, event.position))
		var dir := cam.project_ray_normal(View3D.to_vp(cam, event.position))
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
	edit_name.text = _item_name(k)
	var g: Node3D = items[k]
	sel_ring.visible = true
	sel_ring.position = Vector3(g.position.x, 0.05, g.position.z)
	var tw := create_tween()
	tw.tween_property(g, "scale", Vector3.ONE * 1.12, 0.1)
	tw.tween_property(g, "scale", Vector3.ONE, 0.15)


func _save_item(k: String) -> void:
	var g: Node3D = items[k]
	if k.begins_with("kit:"):
		IslandKit.move(int(g.get_meta("kit_u")), g.position.x, g.position.z, int(round(fposmod(g.rotation.y, TAU) / (PI / 4.0))) % 8)
		return
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
	if sel.begins_with("kit:"):
		# 島から戻して、しまってある物へ
		IslandKit.store(int(items[sel].get_meta("kit_u")))
		items[sel].queue_free()
		items.erase(sel)
		spots = spots.filter(func(sp): return sp.get("group", "") != sel)
		sel = ""
		sel_ring.visible = false
		_build_edit_ui()
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


# ---------- 島を広げる（岸の「＋」） ----------

var exp_markers: Array = [] # {id, node}


func _build_exp_markers() -> void:
	for mk in exp_markers:
		if is_instance_valid(mk.node):
			mk.node.queue_free()
	exp_markers = []
	if terrain == null or _vis() or IslandKit.expansions().size() >= IslandKit.MAX_EXPANSIONS:
		return
	var R: float = IslandKit.STAGES[IslandKit.stage_for(_L())].radius
	for e in IslandKit.EXPANSIONS:
		if not IslandKit.can_expand(e.id):
			continue
		var a := deg_to_rad(float(e.angle))
		var dir := Vector3(cos(a), 0, sin(a))
		var n := Node3D.new()
		n.position = dir * (R + (0.75 if e.kind == "plot" else 2.0)) + Vector3(0, 0.08, 0)
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.26
		t.outer_radius = 0.34
		ring.mesh = t
		ring.material_override = Kit.glow(Color("fff2a8") if e.kind == "plot" else Color("a8e8ff"), 1.6)
		n.add_child(ring)
		var l := Kit.label3d("+", 64, Color("fffaf2"))
		l.position = Vector3(0, 0.35, 0)
		l.no_depth_test = true
		l.render_priority = 10
		n.add_child(l)
		world.add_child(n)
		exp_markers.append({"id": e.id, "node": n})


## 値段のカード → 決めると、海から陸がせり上がる
func _expand_card(id: String) -> void:
	var e := IslandKit.expansion(id)
	var body := tr("KIT_UI_EXPAND_ISLET") if e.kind == "islet" else tr("KIT_UI_EXPAND_PLOT")
	var v := _popup(tr("KIT_UI_EXPAND"), body, "")
	var c := IslandKit.expansion_cost(id)
	var miss := IslandKit.expansion_missing(id)
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 10)
	row.add_child(Kit.text(tr("COIN_HAVE_NEED") % [Wallet.balance(), int(c.coins)], 14, Color("c0473b") if miss.has("coins") else Color("b0643a"), true))
	for k in c.mats:
		row.add_child(Kit.text("%s %d/%d" % [tr("MAT_" + k), IslandKit.count(k), int(c.mats[k])], 14, Color("c0473b") if miss.has(k) else Color("3f7d4f"), true))
	v.add_child(row)
	v.add_child(Kit.text(tr("KIT_UI_EXPANSIONS") % [IslandKit.expansions().size(), IslandKit.MAX_EXPANSIONS], 11, Color("8a7a88"), false, HORIZONTAL_ALIGNMENT_CENTER))
	var go := Kit.button(tr("KIT_UI_EXPAND_GO"), Color("ff8a5b") if miss.is_empty() else Color("eee6dd"), func(): _do_expand(id), Color.WHITE if miss.is_empty() else Color("a89ea6"))
	go.disabled = not miss.is_empty()
	v.add_child(go)
	v.add_child(Kit.button(tr("KIT_UI_CLOSE"), Color(1, 1, 1, 0.95), func(): share_ui.queue_free(), Color("6a5f70"), 40, 14))


func _do_expand(id: String) -> void:
	if not IslandKit.expand(id):
		return
	Telemetry.track("island_expand")
	if share_ui and is_instance_valid(share_ui):
		share_ui.queue_free()
	_build_expansion(id, true)
	_build_exp_markers()
	_toast(tr("KIT_UI_EXPAND"), tr("KIT_UI_EXPAND_DONE"))
	# 広がった島が入るよう、カメラを引きなおす
	await get_tree().create_timer(1.2).timeout
	var fit := _land_fit()
	var to := cam.transform
	to.origin = Vector3(0, 10.5, 5.2) * float(fit.scale) + fit.shift
	to = to.looking_at(Vector3(0, 0, 0.1) + fit.shift, Vector3.UP)
	create_tween().tween_property(cam, "transform", to, 0.8).set_trans(Tween.TRANS_SINE)


# ---------- 桟橋にとめた乗り物 ----------

var parked: Node3D


func _park_vehicle() -> void:
	if terrain == null:
		return
	var id: String = V.get("vehicle", "raft") if _vis() else Vehicles.current()
	parked = VehicleProps.build_vehicle(id)
	parked.scale = Vector3.ONE * 0.62
	var L := _L()
	var R: float = IslandKit.STAGES[IslandKit.stage_for(L)].radius
	var dir := Vector3(0.93, 0, 0.36).normalized()
	if Vehicles.info(id).get("fly", false) and id == "helicopter":
		# ヘリはうしろの丘の上に
		parked.position = Vector3(-4.6, 0.0, -3.4)
		parked.rotation.y = 0.4
	elif L >= 4:
		# 桟橋の先の横に、横づけ
		var side := Vector3(-dir.z, 0, dir.x)
		parked.position = dir * (_island_r(L) + 1.8) + side * 0.75 + Vector3(0, -0.1, 0)
		parked.rotation.y = -atan2(dir.z, dir.x)
	else:
		parked.position = Vector3(-2.4, -0.1, R + 1.1)
		parked.rotation.y = 0.3
	parked.set_meta("base_y", parked.position.y)
	world.add_child(parked)


## しまってある物を島のまんなか近くに出して、選ぶ
func _place_from_stock(id: String) -> void:
	var at := _free_spot()
	var pl := IslandKit.place(id, at.x, at.z, 0)
	if pl.is_empty():
		return
	var g := _build_kit(pl)
	_build_edit_ui()
	if g:
		burst.position = g.position + Vector3(0, 0.3, 0)
		burst.restart()
		burst.emitting = true
		Kit.play(self, "pop", 1.1)
		_select("kit:%d" % int(pl.u))


## 置き物どうしが重ならない、まんなか近くの空き
func _free_spot() -> Vector3:
	for ring in 12:
		for k in 8:
			var a := TAU * k / 8.0 + ring * 0.4
			var p := Vector3(0.2 + cos(a) * ring * 0.35, 0, 0.6 + sin(a) * ring * 0.3)
			p = Vector3(snappedf(p.x, 0.25), 0, snappedf(p.z, 0.25))
			if not _inside(p, 0.7) or p.z < -2.2:
				continue
			var ok := true
			for k2 in items:
				var g = items[k2]
				if String(k2).begins_with("kit:") and is_instance_valid(g) and g.position.distance_to(p) < 0.8:
					ok = false
					break
			if ok:
				return p
	return Vector3(0.2, 0, 0.6)


var catalog_ui: Control
var raft_ui: Control # いかだ（船着き場）から開く、行き先えらび


## カタログ：肉球コインと材料を見せ、買える物は「買う」、足りない分は赤で出す
func _open_catalog(tab := "items") -> void:
	if catalog_ui and is_instance_valid(catalog_ui):
		catalog_ui.queue_free()
	catalog_ui = Control.new()
	catalog_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(catalog_ui)
	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.06, 0.14, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	catalog_ui.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color("fffaf2"), 22, 0.25, Vector2(12, 12)))
	p.position = Vector2(10, 40)
	p.size = Vector2(340, 590)
	catalog_ui.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_child(Kit.text(tr("KIT_UI_SHOP"), 18, Color("2a2233"), true))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(Kit.text(tr("COIN_N") % Wallet.balance(), 15, Color("b0643a"), true))
	var close := Kit.button("×", Color(1, 1, 1, 0.9), func(): catalog_ui.queue_free(), Color("6a5f70"), 34, 16)
	close.custom_minimum_size.x = 40
	head.add_child(close)
	v.add_child(head)
	# 置き物 / 船着き場（乗り物）
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	for t in [["items", tr("KIT_UI_SHOP")], ["dock", tr("KIT_UI_GARAGE")]]:
		var key: String = t[0]
		var on := key == tab
		var b := Kit.button(t[1], Color("ff8a5b") if on else Color("f3ecff"), func(): _open_catalog(key), Color.WHITE if on else Color("6a5bd6"), 34, 13)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)
	v.add_child(tabs)
	# 材料（持っている数）
	var mrow := HFlowContainer.new()
	mrow.add_theme_constant_override("h_separation", 8)
	for k in IslandKit.MAT_ORDER:
		mrow.add_child(Kit.text("%s %d" % [tr("MAT_" + k), IslandKit.count(k)], 11, Color("6a5f70")))
	v.add_child(mrow)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	if tab == "dock":
		_dock_list(list)
		return
	var stage := IslandKit.stage_for(_L())
	for cat in IslandKit.CATS:
		list.add_child(Kit.text(tr("KIT_CAT_" + cat), 13, Color("8a7a88"), true))
		if cat == "premium":
			list.add_child(Kit.wrap(Kit.text(tr("KIT_UI_COSMETIC"), 11, Color("8a5bd6"))))
		for it in IslandKit.ITEMS:
			if it.cat == cat:
				list.add_child(_catalog_row(it, stage))


## 船着き場：乗り物を選ぶ・作る。見た目だけ（速さ・もらえる物は同じ）。有料は見本のストア
func _dock_list(list: VBoxContainer) -> void:
	list.add_child(Kit.wrap(Kit.text(tr("KIT_UI_VEH_NOTE"), 11, Color("6a5f70"))))
	for vd in Vehicles.LIST:
		var id: String = vd.id
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", Kit.pill(Color("f3ecff") if vd.get("premium", false) else Color.WHITE, 14, 0.0, Vector2(8, 6)))
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		row.add_child(h)
		var icon := TextureRect.new()
		var ip := "res://assets/gen/vehicles/%s.png" % id
		if ResourceLoader.exists(ip):
			icon.texture = load(ip)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(64, 56)
		h.add_child(icon)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		info.add_child(Kit.text(Vehicles.name_of(id), 14, Color("2a2233"), true))
		if vd.get("premium", false):
			# 「見本のストア（本当の支払いはありません）」は長いので折り返す（折り返さないと、行が画面の右へはみ出して × と「買う」が隠れる）
			info.add_child(Kit.wrap(Kit.text("¥%d · %s" % [int(vd.yen), tr("KIT_UI_MOCK")], 10, Color("8a5bd6"))))
			h.add_child(Kit.button(tr("KIT_UI_BUY"), Color("e9e2ff"), func(): _toast(Vehicles.name_of(id), tr("KIT_UI_MOCK")), Color("6a5bd6"), 34, 13))
		elif Vehicles.owned().has(id):
			var riding := Vehicles.current() == id
			info.add_child(Kit.text(tr("KIT_UI_RIDING") if riding else "", 11, Color("3f7d4f"), true))
			var rb := Kit.button(tr("KIT_UI_RIDE"), Color("ff8a5b") if not riding else Color("e2f3e6"), func(): _ride(id), Color.WHITE if not riding else Color("3f7d4f"), 34, 13)
			rb.disabled = riding
			h.add_child(rb)
		else:
			var miss := Vehicles.missing(id)
			var cost := HFlowContainer.new()
			cost.add_theme_constant_override("h_separation", 6)
			cost.add_child(Kit.text(tr("COIN_N") % int(vd.price), 11, Color("c0473b") if miss.has("coins") else Color("b0643a")))
			for k in vd.mats:
				cost.add_child(Kit.text("%s %d/%d" % [tr("MAT_" + k), IslandKit.count(k), int(vd.mats[k])], 11, Color("c0473b") if miss.has(k) else Color("3f7d4f")))
			info.add_child(cost)
			var can := miss.is_empty()
			var mb := Kit.button(tr("KIT_UI_MAKE"), Color("ff8a5b") if can else Color("eee6dd"), func(): _make_vehicle(id), Color.WHITE if can else Color("a89ea6"), 34, 13)
			mb.disabled = not can
			h.add_child(mb)
		list.add_child(row)


func _ride(id: String) -> void:
	Vehicles.set_current(id)
	_repark()
	_open_catalog("dock")


func _make_vehicle(id: String) -> void:
	if Vehicles.buy(id):
		Kit.play(self, "chime", 1.2)
		_repark()
		_open_catalog("dock")


func _repark() -> void:
	if parked and is_instance_valid(parked):
		parked.queue_free()
	_park_vehicle()


func _catalog_row(it: Dictionary, stage: int) -> Control:
	var id: String = it.id
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", Kit.pill(Color("f3ecff") if it.get("premium", false) else Color.WHITE, 14, 0.0, Vector2(8, 6)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	row.add_child(h)
	var icon := TextureRect.new()
	var ip := "res://assets/gen/island_kit/%s.png" % id
	if ResourceLoader.exists(ip):
		icon.texture = load(ip)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(54, 54)
	h.add_child(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	h.add_child(info)
	info.add_child(Kit.text(IslandKit.name_of(id), 14, Color("2a2233"), true))
	var locked := not IslandKit.unlocked(id, stage)
	if it.get("premium", false):
		info.add_child(Kit.text("¥%d" % int(it.yen), 12, Color("8a5bd6"), true))
		h.add_child(Kit.button(tr("KIT_UI_BUY"), Color("e9e2ff"), func(): _toast(IslandKit.name_of(id), tr("KIT_UI_SOON")), Color("6a5bd6"), 34, 13))
		return row
	# 値段と材料：足りない物は赤
	var miss := IslandKit.missing(id)
	var cost := HFlowContainer.new()
	cost.add_theme_constant_override("h_separation", 6)
	cost.add_child(Kit.text(tr("COIN_N") % int(it.price), 11, Color("c0473b") if miss.has("coins") else Color("b0643a")))
	for k in it.mats:
		cost.add_child(Kit.text("%s %d/%d" % [tr("MAT_" + k), IslandKit.count(k), int(it.mats[k])], 11, Color("c0473b") if miss.has(k) else Color("3f7d4f")))
	info.add_child(cost)
	if locked:
		info.add_child(Kit.wrap(Kit.text(tr("KIT_UI_LOCKED"), 10, Color("a89ea6"))))
		return row
	var can := miss.is_empty()
	var b := Kit.button(tr("KIT_UI_BUY"), Color("ff8a5b") if can else Color("eee6dd"), func(): _buy(id), Color.WHITE if can else Color("a89ea6"), 34, 13)
	b.disabled = not can
	h.add_child(b)
	return row


func _buy(id: String) -> void:
	if not IslandKit.buy(id):
		return
	Kit.play(self, "chime", 1.2)
	catalog_ui.queue_free()
	_place_from_stock(id)
	_toast(IslandKit.name_of(id), tr("KIT_UI_BOUGHT"))


# ---------- シェア ----------

var share_ui: Control


func _share() -> void:
	if GameState.nickname == "":
		_ask_name()
		return
	Telemetry.track("island_share")
	var code := GameState.island_code(_movable_keys())
	var url: String = GameState.SHARE_URL + code
	DisplayServer.clipboard_set(url)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("""(function(u){ if (navigator.share) { navigator.share({title: 'Paw Time', text: 'My island', url: u}).catch(function(){}); } else if (navigator.clipboard) { navigator.clipboard.writeText(u); } })('%s')""" % url)
	Kit.play(self, "chime", 1.1)
	_popup("島のコードをコピーした", tr("リンクを送ると、%sの島に遊びに来てもらえる") % GameState.nickname, code)


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
	box.add_child(_link("やめる", func(): share_ui.queue_free())) # 名前を決めずに、島づくりへ戻る


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
	dp.add_child(Kit.text(tr("%sの島") % V.name, 15, Color("2a2233"), true))
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
	card_box.add_child(Kit.text(tr("%sの島に、おでかけ") % V.name, 18, Color("2a2233"), true))
	card_box.add_child(Kit.text(tr("おばけ %d 体・島 Lv%d") % [V.residents.size() + 1, int(V.level) + 1], 14, Color("6a5f70")))
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
	# 友だちの島へのおでかけを数える（レアのネムリン・キセカエのパジャマ）
	GameState.friend_visits += 1
	if GameState.has_save():
		GameState.save()
	_clear_card()
	card_box.add_child(Kit.text(tr("%sの島に、おでかけ") % V.name, 18, Color("2a2233"), true))
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
	_toast("おみやげ", tr("%sを、%sの島においてきた") % [tr(GameState.info(id).name), V.name])
	_clear_card()
	card_box.add_child(Kit.text(tr("%sが、島になじんだ") % tr(GameState.info(id).name), 16, Color("3f7d4f"), true))
	card_box.add_child(Kit.button("自分の島にかえる", Color("ff8a5b"), _go_home))
	_card_fit()


func _go_home() -> void:
	GameState.visit = {}
	if OS.has_feature("web"):
		JavaScriptBridge.eval("history.replaceState(null, '', location.pathname)")
	if GameState.has_save() and GameState.load_game():
		# はじめての人（シェアのリンクから来た・診断の前）は、診断から。途中なら、その続きから
		main.go(Onboarding.resume_screen())
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


## 確認用：画面の UI を隠して島だけを撮る
func demo_hide_ui() -> void:
	for c in get_children():
		if c is Control and not c is SubViewportContainer:
			c.visible = false


## 確認用：島をつくる → カタログを開く
func demo_catalog() -> void:
	_enter_edit()
	await get_tree().create_timer(0.7).timeout
	_open_catalog()



## 確認用：島をつくる → 岸の「＋」のカード（右手前の陸）
func demo_expand_card() -> void:
	_enter_edit()
	await get_tree().create_timer(0.7).timeout
	if IslandKit.can_expand("plot_left"):
		_expand_card("plot_left")
		return
	for e in IslandKit.EXPANSIONS:
		if IslandKit.can_expand(e.id):
			_expand_card(e.id)
			return


## 確認用：カードの「陸をあげる」を押したところ
func demo_do_expand() -> void:
	if IslandKit.can_expand("plot_left"):
		_do_expand("plot_left")
		return
	for e in IslandKit.EXPANSIONS:
		if IslandKit.can_expand(e.id):
			_do_expand(e.id)
			return


## 確認用：船着き場のタブ
func demo_dock() -> void:
	_enter_edit()
	await get_tree().create_timer(0.7).timeout
	_open_catalog("dock")
