extends Control
## おでかけの移動の場面（3〜5 秒・とばせる）：自分のおばけ猫が乗り物に乗って、夜の海を渡り、友だちの島へ。
## 乗り物は見た目だけ（どれも同じ 4.2 秒で着く）。着いたら、いつものおでかけの画面（garden）へ。
## 行き先は GameState.visit（島のコードを読んだもの）。乗り物は Vehicles.current()。

var main
const DURATION := 4.2

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var vehicle: Node3D
var spinners: Array = []
var wake: Array = []
var _t := 0.0
var _done := false
var fly := false
var title: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
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
	var rig := Look.apply(world, "island_night", Color("1d2760"), false, false)
	var env: Environment = rig.env
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_hdr_threshold = 0.9
	env.glow_enabled = false
	env.background_energy_multiplier = 1.0
	_build_sea()
	var vid := OS.get_environment("OBAKE_VEHICLE") if OS.get_environment("OBAKE_VEHICLE") != "" else Vehicles.current()
	fly = Vehicles.info(vid).get("fly", false)
	vehicle = VehicleProps.build_vehicle(vid)
	world.add_child(vehicle)
	for n in vehicle.find_children("*", "Node3D", true, false):
		if n.has_meta("spin"):
			spinners.append(n)
	VehicleProps.seat(vehicle, _rider(), 0.42)
	cam = Camera3D.new()
	cam.fov = 34
	world.add_child(cam)
	_build_ui()
	_place(0.0)


## 自分の島のあるじ（マイおばけ猫がいればその子）
func _rider() -> Node3D:
	var h: String = GameState.host()
	var ob: Obake3D
	if h == "my" and not GameState.my_obake.is_empty():
		ob = Outfit.make("my") # 保存した見た目（とくべつな印）と、着ている服
	else:
		ob = Outfit.make(h if h != "my" else "receipt")
	ob.bob = false
	ob.contact_shadow = false
	return ob


func _build_sea() -> void:
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 40)
	sea.mesh = pm
	var sm := Obake3D.skin(Color("1c3f7a"), 0.0, null, 0.3, 0.0, false, 0.6).duplicate() as ShaderMaterial
	sm.set_shader_parameter("sheen_gloss", 60.0)
	sea.material_override = sm
	world.add_child(sea)
	# 月と、海に映る月の道
	var moon := MeshInstance3D.new()
	moon.mesh = IslandProps.new().sph(1.1)
	moon.material_override = Kit.glow(Color("fff1c8"), 1.8)
	moon.position = Vector3(2.0, 7.0, -22.0)
	world.add_child(moon)
	for i in 14:
		var g := MeshInstance3D.new()
		var q := PlaneMesh.new()
		q.size = Vector2(randf_range(0.6, 1.6), 0.08)
		g.mesh = q
		g.material_override = Kit.glow(Color("fff1c8"), 0.6 + randf() * 0.6)
		g.position = Vector3(2.0 + randf_range(-0.6, 0.6), 0.01, -20.0 + i * 1.3)
		world.add_child(g)
	var stars := CPUParticles3D.new()
	stars.amount = 90
	stars.lifetime = 100.0
	stars.preprocess = 100.0
	stars.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	stars.emission_box_extents = Vector3(24, 5, 1)
	stars.position = Vector3(0, 9, -24)
	stars.gravity = Vector3.ZERO
	stars.initial_velocity_max = 0.0
	var stm := SphereMesh.new()
	stm.radius = 0.05
	stm.height = 0.1
	stars.mesh = stm
	stars.material_override = Kit.glow(Color("dfe6ff"), 2.0)
	world.add_child(stars)
	# 出発の島（左）と、行き先の島（右）：地形を小さくして、灯りをともす
	# 出発は自分の島の段と広げた陸、行き先はコードに入っていた段と広げた陸（前は平たい段 0 の板だった）
	for side in [-1.0, 1.0]:
		var lvl: int = GameState.garden_level if side < 0 else int(GameState.visit.get("level", 0))
		var exps: Array = IslandKit.expansions() if side < 0 else GameState.visit.get("expansions", [])
		var isl := _island_model(IslandKit.stage_for(lvl), exps)
		isl.scale = Vector3.ONE * 0.55
		isl.position = Vector3(side * 8.2, 0.14 * 0.55, -1.5) # 島の画面と同じく、波打ちぎわが海面に来る高さ
		world.add_child(isl)
		for k in 3:
			var lamp := IslandProps.build("paper_lantern" if side < 0 else "street_lamp")
			lamp.position = isl.position + Vector3(-1.0 + k * 1.0, 0, 1.2 - k * 0.4)
			world.add_child(lamp)
			for l in lamp.find_children("*", "OmniLight3D", true, false):
				(l as OmniLight3D).light_energy = 1.4
		var tree := IslandProps.build("tree_palm" if side > 0 else "tree_round")
		tree.position = isl.position + Vector3(0.6, 0, -0.6)
		world.add_child(tree)
		if side > 0:
			var lh := IslandProps.build("lighthouse")
			lh.position = isl.position + Vector3(-1.2, 0, -0.9)
			lh.scale = Vector3.ONE * 0.8
			world.add_child(lh)
			for l in lh.find_children("*", "OmniLight3D", true, false):
				(l as OmniLight3D).light_energy = 2.0


## 島の地形（段ごとの Blender の地形）と、広げた陸・小島。庭の画面と同じ材質
func _island_model(stage: int, exps: Array) -> Node3D:
	var root := Node3D.new()
	var m := Obake3D.skin(Color.WHITE, 0.0, null, 0.06, 0.0, false, 0.02).duplicate() as ShaderMaterial
	m.set_shader_parameter("vertex_albedo", 1.0)
	IslandProps.terrain_look(m)
	m.set_shader_parameter("top_light", 0.0)
	var t := MeshInstance3D.new()
	t.mesh = IslandProps.glb("terrain_s%d" % stage)
	t.material_override = m
	root.add_child(t)
	var R: float = IslandKit.STAGES[stage].radius
	for id in exps:
		if IslandKit.expansion(id).is_empty():
			continue
		var sh := IslandKit.expansion_shape(id, R)
		if sh.is_empty():
			continue
		var land := MeshInstance3D.new()
		land.mesh = IslandProps.land_lobe(sh.r, IslandKit.EXPANSIONS.find(IslandKit.expansion(id)))
		land.material_override = m
		land.position = Vector3(sh.center.x, -0.004, sh.center.z)
		root.add_child(land)
	return root


func _build_ui() -> void:
	var nm: String = GameState.visit.get("name", "?")
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.9), 20, 0.14, Vector2(14, 8)))
	top.position = Vector2(18, 22)
	add_child(top)
	title = Kit.text(tr("KIT_UI_TRAVEL") % nm, 15, Color("2a2233"), true)
	top.add_child(title)
	var skip := Kit.button(tr("KIT_UI_SKIP") + " ›", Color(1, 1, 1, 0.9), _finish, Color("6a5bd6"), 38, 14)
	skip.position = Vector2(254, 580)
	skip.size = Vector2(90, 38)
	add_child(skip)
	var note := Kit.text(Vehicles.name_of(vehicle.name), 13, Color("dfe6ff"), true)
	note.position = Vector2(20, 588)
	add_child(note)


## t = 0..1：左の島から右の島へ。飛ぶ乗り物は空の上を
func _place(t: float) -> void:
	var e := t * t * (3.0 - 2.0 * t)
	var x := lerpf(-6.2, 6.2, e)
	var y := 0.0
	if fly:
		y = sin(clampf(t, 0.0, 1.0) * PI) * 2.2 + 0.1
	else:
		y = sin(_t * 3.0) * 0.04
	vehicle.position = Vector3(x, y, 0.4)
	vehicle.rotation.z = (cos(t * PI) * 0.18 if fly else sin(_t * 2.2) * 0.05)
	vehicle.rotation.x = sin(_t * 1.7) * (0.02 if fly else 0.05)
	# 縦長の画面なので、乗り物を真ん中に、少し上から追いかける
	cam.position = Vector3(x - 1.2, 2.6 + y * 0.6, 9.5)
	cam.look_at(Vector3(x, 0.5 + y * 0.8, 0))


func _process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var t := clampf(_t / DURATION, 0.0, 1.0)
	_place(t)
	for sp in spinners:
		if is_instance_valid(sp):
			var ax: Vector3 = sp.get_meta("spin_axis")
			sp.rotate_object_local(ax.normalized(), delta * float(sp.get_meta("spin")))
	# 水の上の乗り物は、白い航跡を残す
	if not fly and fmod(_t, 0.08) < delta:
		var w := MeshInstance3D.new()
		w.mesh = IslandProps.new().sph(0.12)
		w.material_override = Obake3D.flat(Color(1, 1, 1, 0.8))
		w.scale = Vector3(1.4, 0.15, 0.8)
		w.position = vehicle.position + Vector3(-0.8, 0.0, randf_range(-0.2, 0.2))
		world.add_child(w)
		var tw := w.create_tween().set_parallel()
		tw.tween_property(w, "scale", Vector3(2.6, 0.05, 1.8), 1.2)
		tw.tween_property(w, "position:y", -0.08, 1.2)
		tw.chain().tween_callback(w.queue_free)
	if t >= 1.0:
		_arrive()


func _arrive() -> void:
	_done = true
	title.text = tr("KIT_UI_ARRIVE")
	var tw := create_tween()
	tw.tween_interval(0.6)
	tw.tween_callback(_finish)


func _finish() -> void:
	if main and not main.busy:
		# お店の島（GameState.visit.shop）なら、お店の島の画面へ
		main.go("shop_island" if GameState.visit.has("shop") else "garden")


## 確認用：途中の場面で止める（撮影）
func demo_pause_mid() -> void:
	_t = DURATION * 0.5
	_place(0.5)
	set_process(false)
