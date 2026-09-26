extends Control
## 店を回す。困りごとが持ち場に出てくるので、おばけを選んで持ち場をタップして置く。
## 置いたおばけは、そこの困りごとを片づける。つかれたら休憩室の隅で休んで、同じ持ち場に戻る。
## 待ちきれない困りごと（赤）が店の「余裕」を減らす。閉店まで余裕を残せば勝ち。計算は ShopSim。

var main

const VIEW_H := 506.0
const JOB_COLOR := {"register": Color("ffc23d"), "dish": Color("5fc4ff"), "hall": Color("a98bff"), "kitchen": Color("ff7a45"), "stock": Color("e8b878"), "": Color("ff8fb1")}

var sim: ShopSim
var si := 0
var st := 0
var shop: Dictionary
var stage: Dictionary
var boost: Dictionary
var auto := false
var demo := false
var paused := false
var ended := false
var speed := 1
var acc := 0.0
var _t := 0.0

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var shake := 0.0
var cam_base := Vector3.ZERO
var rings := {} # 持ち場 → 床の輪
var views := {} # おばけ uid → {root, ob, t}
var bubbles := {} # 困りごと uid → Control
var props := {} # 困りごと uid → 持ち場に置く小さな3Dの小物
var chips := {} # 持ち場 → ボタン
var burst: CPUParticles3D

var time_bar: ProgressBar
var time_lbl: Label
var yoyu_bar: ProgressBar
var yoyu_lbl: Label
var cards: Array = []
var selected := -1
var hint: PanelContainer
var hint_label: Label
var hint_key := ""
var banner: Label
var flash: ColorRect
var overlay: Control
var tag_layer: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	demo = OS.get_environment("OBAKE_DEMO") != ""
	auto = demo or OS.get_environment("OBAKE_AUTO") != ""
	if OS.get_environment("OBAKE_SPEED") != "":
		speed = int(OS.get_environment("OBAKE_SPEED"))
	var pb: Dictionary = GameState.pending_battle
	si = int(pb.get("shop", 0))
	st = int(pb.get("stage", 0))
	shop = DefData.shop(si)
	stage = ShopData.stage(si, st)
	boost = GameState.battle_boost(shop.id)
	sim = ShopSim.new()
	sim.setup(si, st, GameState.deck_for_battle(), boost, GameState.lap)
	_build_world()
	_build_ui()
	Kit.music("c_battle_loop")
	var ids: Array = []
	for c in sim.crew:
		ids.append(c.id)
	Kit.make_portraits(ids)
	_intro()


# ---------- 店の床 ----------

func _build_world() -> void:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.size = Vector2(360, 640)
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
	env.background_color = Color(shop.sky).lerp(Color("2a2233"), 0.25)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff1e0")
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 25, 0)
	sun.light_energy = 0.7
	sun.light_color = Color("fff0dc")
	sun.shadow_enabled = true
	world.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 42
	world.add_child(cam)
	cam_base = Vector3(0, 15.5, 9.0)
	cam.position = cam_base
	cam.look_at_from_position(cam_base, Vector3(0, 0, 0.9))

	var floor_c := Color(shop.floor).lightened(0.25)
	_box(Vector3(8.0, 0.2, 10.0), Vector3(0, -0.1, 0), floor_c)
	for i in 9:
		_box(Vector3(8.0, 0.005, 0.03), Vector3(0, 0.001, -4.5 + i * 1.1), floor_c.darkened(0.08))
	# 壁（奥と左右は低く）
	_box(Vector3(8.2, 1.6, 0.25), Vector3(0, 0.8, -5.0), Color("efe0cc"))
	_box(Vector3(0.25, 0.8, 10.0), Vector3(-4.1, 0.4, 0), Color("e6d3bb"))
	_box(Vector3(0.25, 0.8, 10.0), Vector3(4.1, 0.4, 0), Color("e6d3bb"))
	_box(Vector3(8.2, 0.12, 0.3), Vector3(0, 1.62, -5.0), Color(shop.color))
	# 入口（左の壁）
	_box(Vector3(0.3, 0.9, 1.2), Vector3(-4.1, 0.45, 2.6), Color("7a5238"))
	# 休憩室の隅：ラグと座布団
	var rug := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 1.3
	rm.bottom_radius = 1.3
	rm.height = 0.02
	rug.mesh = rm
	rug.scale = Vector3(1.3, 1, 0.7)
	rug.position = Vector3(ShopData.BREAK_POS.x, 0.01, ShopData.BREAK_POS.y + 0.2)
	rug.material_override = Obake3D.toon(Color("8fd1a8"), 0.05)
	world.add_child(rug)
	_box(Vector3(0.5, 0.08, 0.5), Vector3(ShopData.BREAK_POS.x + 1.1, 0.04, ShopData.BREAK_POS.y + 0.1), Color("c9454a"))
	_box(Vector3(0.5, 0.08, 0.5), Vector3(ShopData.BREAK_POS.x - 1.1, 0.04, ShopData.BREAK_POS.y + 0.1), Color("5b6fc2"))
	var cup := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.09
	cm.bottom_radius = 0.08
	cm.height = 0.16
	cup.mesh = cm
	cup.position = Vector3(ShopData.BREAK_POS.x + 0.6, 0.08, ShopData.BREAK_POS.y + 0.5)
	cup.material_override = Obake3D.toon(Color("f4f1ea"), 0.2)
	world.add_child(cup)

	for sid in ShopData.STATIONS:
		_build_station(sid, sid in sim.stations)

	burst = CPUParticles3D.new()
	burst.emitting = false
	burst.one_shot = true
	burst.amount = 16
	burst.lifetime = 0.6
	burst.explosiveness = 1.0
	burst.spread = 180
	burst.initial_velocity_min = 1.0
	burst.initial_velocity_max = 2.2
	burst.gravity = Vector3(0, -3, 0)
	burst.local_coords = false
	var bm := SphereMesh.new()
	bm.radius = 0.05
	bm.height = 0.1
	burst.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("fff2a8")
	burst.material_override = mat
	world.add_child(burst)


func _box(size: Vector3, pos: Vector3, c: Color, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = Obake3D.toon(c, 0.05)
	(parent if parent else world).add_child(m)
	return m


func _cyl(r: float, h: float, pos: Vector3, c: Color, parent: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	m.mesh = cm
	m.position = pos
	m.material_override = Obake3D.toon(c, 0.05)
	parent.add_child(m)
	return m


func _build_station(sid: String, active: bool) -> void:
	var d: Dictionary = ShopData.STATIONS[sid]
	var n := Node3D.new()
	n.position = Vector3(d.pos.x, 0, d.pos.y)
	world.add_child(n)
	var dim := 1.0 if active else 0.55
	match sid:
		"register":
			_box(Vector3(1.5, 0.8, 0.7), Vector3(0, 0.4, -0.55), Color("d9a86c") * dim, n)
			_box(Vector3(0.5, 0.3, 0.4), Vector3(0.2, 0.95, -0.55), Color("4a4a52") * dim, n)
			_box(Vector3(0.36, 0.2, 0.05), Vector3(0.2, 1.2, -0.72), Color("8fe0d8") * dim, n)
		"tables":
			for p in [Vector3(-0.8, 0, -0.5), Vector3(0.8, 0, 0.1)]:
				_cyl(0.45, 0.07, p + Vector3(0, 0.6, 0), Color("b98258") * dim, n)
				_cyl(0.07, 0.6, p + Vector3(0, 0.3, 0), Color("7a5238") * dim, n)
				for q in [Vector3(0.6, 0, 0), Vector3(-0.6, 0, 0)]:
					_cyl(0.18, 0.35, p + q + Vector3(0, 0.18, 0), Color(shop.color).lightened(0.2) * dim, n)
		"kitchen":
			_box(Vector3(1.6, 0.8, 0.8), Vector3(0, 0.4, -0.6), Color("c8ced6") * dim, n)
			_cyl(0.2, 0.03, Vector3(-0.35, 0.82, -0.6), Color("2e222f"), n)
			_cyl(0.2, 0.03, Vector3(0.35, 0.82, -0.6), Color("2e222f"), n)
			_cyl(0.18, 0.28, Vector3(0.35, 0.97, -0.6), Color("f07a3a") * dim, n)
		"sink":
			_box(Vector3(1.5, 0.8, 0.8), Vector3(0, 0.4, -0.6), Color("e8eef2") * dim, n)
			_box(Vector3(0.8, 0.06, 0.5), Vector3(0, 0.81, -0.6), Color("5fc4ff") * dim, n)
		"shelf":
			_box(Vector3(1.3, 1.5, 0.45), Vector3(0, 0.75, -0.55), Color("a07650") * dim, n)
			for k in 3:
				_box(Vector3(0.3, 0.25, 0.3), Vector3(-0.35 + k * 0.35, 0.3 + (k % 2) * 0.5, -0.4), Color("d9a86c") * dim, n)
	# 置き場所の輪（選んだときに光る）
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.75
	tm.outer_radius = 0.85
	ring.mesh = tm
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(JOB_COLOR[d.job], 0.0)
	ring.material_override = rmat
	ring.position = Vector3(d.pos.x, 0.03, d.pos.y + 0.25)
	ring.scale = Vector3(1, 0.2, 0.75)
	world.add_child(ring)
	rings[sid] = ring


# ---------- 画面 ----------

func _build_ui() -> void:
	var tap := Control.new()
	tap.position = Vector2(0, 60)
	tap.size = Vector2(360, VIEW_H - 60)
	tap.mouse_filter = Control.MOUSE_FILTER_STOP
	tap.gui_input.connect(_on_floor_input)
	add_child(tap)

	tag_layer = Control.new()
	tag_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	tag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tag_layer)

	# 上：一時停止、閉店までの時間、店の余裕（3つだけ）
	var top := HBoxContainer.new()
	top.position = Vector2(8, 8)
	top.size = Vector2(344, 44)
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	var pause := Kit.button("||", Color(1, 1, 1, 0.92), _pause, Kit.INK, 40, 15)
	pause.custom_minimum_size = Vector2(44, 40)
	top.add_child(pause)
	top.add_child(_meter("閉店まで", Color("8b7bff")))
	top.add_child(_meter("店の余裕", Color("7bdc6b")))

	# 持ち場の名札（押しても置ける）
	for sid in sim.stations:
		var b := Button.new()
		b.text = ShopData.STATIONS[sid].name
		b.add_theme_font_override("font", Kit.font_black)
		b.add_theme_font_size_override("font_size", 12)
		for k in ["normal", "hover", "pressed", "focus"]:
			var s := Kit.pill(Color(1, 1, 1, 0.85), 12, 0.1)
			s.content_margin_top = 2
			s.content_margin_bottom = 2
			s.content_margin_left = 8
			s.content_margin_right = 8
			if k == "focus":
				s.bg_color = Color(0, 0, 0, 0)
			b.add_theme_stylebox_override(k, s)
		b.add_theme_color_override("font_color", Kit.INK)
		b.add_theme_color_override("font_hover_color", Kit.INK)
		b.pressed.connect(func(): _to_station(sid))
		add_child(b)
		chips[sid] = b

	# 下：おばけのカード
	var panel := Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Kit.CREAM
	ps.corner_radius_top_left = 22
	ps.corner_radius_top_right = 22
	ps.shadow_color = Color(0, 0, 0, 0.2)
	ps.shadow_size = 10
	panel.add_theme_stylebox_override("panel", ps)
	panel.position = Vector2(0, VIEW_H)
	panel.size = Vector2(360, 640 - VIEW_H)
	add_child(panel)
	var row := HBoxContainer.new()
	row.position = Vector2(8, VIEW_H + 12)
	row.size = Vector2(344, 110)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	var n := sim.crew.size()
	var w := clampf((344.0 - 6.0 * (n - 1)) / maxf(1, n), 44.0, 84.0)
	for i in n:
		var c := _card(i, w)
		row.add_child(c)
		cards.append(c)

	hint = PanelContainer.new()
	hint.add_theme_stylebox_override("panel", Kit.pill(Kit.INK, 16, 0.3))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label = Kit.text("", 14, Color.WHITE, true)
	hint.add_child(hint_label)
	hint.visible = false
	add_child(hint)

	banner = Kit.text("", 32, Color.WHITE, true)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_color_override("font_outline_color", Kit.INK)
	banner.add_theme_constant_override("outline_size", 12)
	banner.position = Vector2(0, 190)
	banner.size = Vector2(360, 100)
	banner.pivot_offset = Vector2(180, 50)
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)

	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate.a = 0.0
	add_child(flash)


func _meter(title: String, col: Color) -> Control:
	var p := PanelContainer.new()
	var s := Kit.pill(Color(1, 1, 1, 0.92), 16, 0.1)
	s.content_margin_top = 4
	s.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", s)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	var l := Kit.text(title, 11, Kit.SUB, true)
	v.add_child(l)
	var b := Kit.bar(1.0, col, Color(0, 0, 0, 0.08), 8)
	v.add_child(b)
	p.add_child(v)
	if title == "閉店まで":
		time_bar = b
		time_lbl = l
	else:
		yoyu_bar = b
		yoyu_lbl = l
	return p


func _card(i: int, w: float) -> Button:
	var c: Dictionary = sim.crew[i]
	var b := Button.new()
	b.custom_minimum_size = Vector2(w, 100)
	b.clip_contents = true
	var job: String = c.job
	for k in ["normal", "hover", "pressed", "focus"]:
		var s := Kit.pill(Color.WHITE, 16, 0.1)
		s.border_color = JOB_COLOR.get(job, Color("ff8fb1"))
		s.set_border_width_all(3)
		if k == "focus":
			s.bg_color = Color(0, 0, 0, 0)
			s.set_border_width_all(0)
			s.shadow_size = 0
		b.add_theme_stylebox_override(k, s)
	var pic := TextureRect.new()
	pic.name = "pic"
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.position = Vector2(4, 6)
	pic.size = Vector2(w - 8, 58)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.texture = Kit.portrait(c.id)
	b.add_child(pic)
	var name_l := Kit.text("あいぼう" if c.id == "my" else GameState.info(c.id).name, 10 if w < 70 else 11, Kit.INK, true)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.position = Vector2(0, 64)
	name_l.size = Vector2(w, 16)
	name_l.clip_text = true
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(name_l)
	var bar := Kit.bar(1.0, Color("7bdc6b"), Color(0, 0, 0, 0.08), 6)
	bar.name = "stamina"
	bar.position = Vector2(8, 84)
	bar.size = Vector2(w - 16, 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(bar)
	var st_l := Kit.text("", 11, Color("5b6fc2"), true)
	st_l.name = "state"
	st_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st_l.position = Vector2(0, 4)
	st_l.size = Vector2(w, 16)
	st_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(st_l)
	b.pressed.connect(func(): _select(i))
	return b


func _select(i: int) -> void:
	if ended or paused:
		return
	Kit.sfx("c_tap")
	selected = -1 if selected == i else i
	if selected >= 0:
		Kit.pop(cards[i], 1.08)
		_hide_hint("t_pick")
		if not GameState.tutorial.has("t_place"):
			var c: Dictionary = sim.crew[i]
			var own := ""
			for sid in sim.stations:
				if ShopData.STATIONS[sid].job == c.job:
					own = sid
			_show_hint("t_place", "%sをタップ" % ShopData.STATIONS[own if own != "" else sim.stations[0]].name, chips[own if own != "" else sim.stations[0]])


func _to_station(sid: String) -> void:
	if ended or paused:
		return
	if selected < 0:
		Kit.sfx("c_deny")
		_show_hint("t_pick_again", "先に、下のおばけを選ぶ", cards[0], false)
		return
	var c: Dictionary = sim.crew[selected]
	if sim.assign(selected, sid):
		Kit.sfx("c_pop", randf_range(0.95, 1.1))
		_hide_hint("t_place")
		_hide_hint("t_pick_again")
		if c.help != "" and not GameState.tutorial.has("t_help_" + c.id):
			GameState.tutorial["t_help_" + c.id] = true
			_callout(c.id)
		selected = -1


func _on_floor_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	var at: Vector2 = ev.position + Vector2(0, 60) # 押した場所（画面の座標）
	var from := cam.project_ray_origin(at)
	var dir := cam.project_ray_normal(at)
	if absf(dir.y) < 1e-4:
		return
	var p := from + dir * (-from.y / dir.y)
	var best := ""
	var bd := 1.8
	for sid in sim.stations:
		var d: float = Vector2(p.x, p.z).distance_to(ShopData.STATIONS[sid].pos)
		if d < bd:
			bd = d
			best = sid
	if best != "":
		_to_station(best)


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.keycode
		if k >= KEY_1 and k <= KEY_7 and k - KEY_1 < sim.crew.size():
			_select(k - KEY_1)
		elif k == KEY_ESCAPE:
			_pause()


# ---------- 毎フレーム ----------

func _process(delta: float) -> void:
	_t += delta
	if not paused and not ended:
		if auto:
			sim.ai_step(delta * speed, 0.8)
		acc += delta * speed
		var dt := 1.0 / 30.0
		var steps := 0
		while acc >= dt and steps < 8 * speed:
			sim.tick(dt)
			acc -= dt
			steps += 1
		_handle(sim.pop_events())
	_sync(delta)
	shake = maxf(0.0, shake - delta * 2.5)
	cam.position = cam_base + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * shake * 0.15
	_refresh()


func _refresh() -> void:
	time_bar.value = 1.0 - sim.progress()
	time_lbl.text = "閉店まで %d秒" % int(ceil(sim.duration - sim.t))
	yoyu_bar.value = sim.yoyu / sim.yoyu_max
	var low := sim.yoyu / sim.yoyu_max < 0.35
	yoyu_lbl.add_theme_color_override("font_color", Color("e85a4f") if low else Kit.SUB)
	for i in cards.size():
		var b: Button = cards[i]
		var c: Dictionary = sim.crew[i]
		var bar: ProgressBar = b.get_node("stamina")
		bar.value = c.stamina / c.stamina_max
		var sl: Label = b.get_node("state")
		sl.text = {"rest": "休けい中", "walk_break": "休けいへ", "idle": ""}.get(c.state, ShopData.STATIONS[c.station].name if c.station != "" else "")
		b.modulate = Color(0.85, 0.85, 0.9) if c.state in ["rest", "walk_break"] else Color.WHITE
		b.position.y = -8.0 if i == selected else 0.0
		var pic: TextureRect = b.get_node("pic")
		if pic.texture == null:
			pic.texture = Kit.portrait(c.id)
	# 名札と輪
	for sid in chips:
		var chip: Button = chips[sid]
		var d: Dictionary = ShopData.STATIONS[sid]
		var sp := cam.unproject_position(Vector3(d.pos.x, 0.0, d.pos.y + 0.15))
		chip.reset_size()
		chip.position = sp - Vector2(chip.size.x / 2, chip.size.y / 2)
		var ring: MeshInstance3D = rings[sid]
		var m: StandardMaterial3D = ring.material_override
		var job_ok: bool = selected >= 0 and (sim.crew[selected].job == d.job or sim.crew[selected].help != "")
		m.albedo_color.a = (0.55 + 0.35 * sin(_t * 7.0)) if selected >= 0 and job_ok else (0.25 if selected >= 0 else 0.0)
	# 困りごとの吹き出し
	var per := {}
	for tr in sim.troubles:
		if not bubbles.has(tr.uid):
			continue
		var bub: Control = bubbles[tr.uid]
		var k: int = per.get(tr.station, 0)
		per[tr.station] = k + 1
		var d2: Dictionary = ShopData.STATIONS[tr.station]
		var sp2 := cam.unproject_position(Vector3(d2.pos.x, 1.4, d2.pos.y - 0.4))
		var n_here: int = sim.count_at(tr.station)
		bub.position = bub.position.lerp(sp2 + Vector2(-18 + (k - (n_here - 1) / 2.0) * 38, -64), 0.3)
		bub.set_meta("frac", clampf(tr.patience / tr.max_patience, 0.0, 1.0))
		bub.set_meta("work", clampf(tr.left / tr.work, 0.0, 1.0))
		bub.set_meta("late", tr.late)
		bub.queue_redraw()
	_update_hint()


func _sync(delta: float) -> void:
	for uid in props:
		var pr: Node3D = props[uid]
		for j in 3:
			var p2 := pr.get_node_or_null("puff%d" % j)
			if p2:
				p2.position.y = 0.62 + j * 0.1 + sin(_t * 6.0 + j) * 0.03
	for c in sim.crew:
		if not views.has(c.uid):
			var root := Node3D.new()
			var ob := Obake3D.make(c.id)
			ob.scale = Vector3.ONE * 0.7
			ob.bob = false
			root.add_child(ob)
			root.position = Vector3(c.x, 0, c.z)
			world.add_child(root)
			views[c.uid] = {"root": root, "ob": ob, "t": randf() * TAU, "zz": null}
		var v: Dictionary = views[c.uid]
		var root2: Node3D = v.root
		var ob2: Obake3D = v.ob
		v.t += delta
		var to := Vector3(c.x, 0, c.z)
		if c.state in ["work", "rest", "idle"]:
			to += Vector3((c.uid % 3 - 1) * 0.45, 0, 0.55 + (c.uid % 2) * 0.2)
		var moving: bool = c.state in ["walk", "walk_break"]
		if moving:
			var d := to - root2.position
			if d.length() > 0.01:
				ob2.rotation.y = lerp_angle(ob2.rotation.y, atan2(d.x, d.z), minf(1.0, 10.0 * delta))
			var ph := fmod(v.t * 3.2, 1.0)
			var up := sin(ph * PI)
			ob2.position.y = up * 0.18
			var sq := 1.0 - clampf(up * 3.0, 0.0, 1.0)
			ob2.scale = Vector3.ONE * 0.7 * Vector3(1.0 + 0.14 * sq, 1.0 - 0.16 * sq + 0.06 * up, 1.0)
		elif c.state == "work":
			ob2.rotation.y = lerp_angle(ob2.rotation.y, PI, minf(1.0, 6.0 * delta))
			var busy := sim.count_at(c.station) > 0
			var w := sin(v.t * (9.0 if busy else 2.0))
			ob2.position.y = maxf(0.0, w) * (0.08 if busy else 0.02)
			ob2.scale = Vector3.ONE * 0.7 * Vector3(1.0 + 0.04 * w, 1.0 - 0.05 * w, 1.0)
		else:
			ob2.rotation.y = lerp_angle(ob2.rotation.y, 0.0, minf(1.0, 4.0 * delta))
			ob2.position.y = 0.0
			ob2.scale = Vector3.ONE * 0.7 * Vector3(1.05, 0.92 if c.state == "rest" else 1.0, 1.0)
		root2.position = root2.position.lerp(to, minf(1.0, 12.0 * delta))
		# 休けい中の Zz（2D）
		if c.state == "rest" and v.zz == null:
			var z := Kit.text("Zz", 14, Color("8b7bff"), true)
			z.add_theme_color_override("font_outline_color", Color.WHITE)
			z.add_theme_constant_override("outline_size", 5)
			z.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tag_layer.add_child(z)
			v.zz = z
		elif c.state != "rest" and v.zz != null:
			v.zz.queue_free()
			v.zz = null
		if v.zz != null:
			var zl: Label = v.zz
			zl.position = cam.unproject_position(root2.position + Vector3(0, 1.0, 0)) + Vector2(4, -10 + sin(v.t * 3.0) * 3)


# ---------- できごと ----------

func _handle(evs: Array) -> void:
	for ev in evs:
		match ev.type:
			"trouble":
				_make_bubble(ev.uid, ev.kind, ev.station)
				_make_prop(ev.uid, ev.kind, ev.station)
				if not demo:
					GameState.enemies_seen[ev.kind] = true
				Kit.sfx("c_pop", 1.5, -8)
			"solved":
				if props.has(ev.uid):
					var pr: Node3D = props[ev.uid]
					props.erase(ev.uid)
					var tp := pr.create_tween()
					tp.tween_property(pr, "scale", Vector3(1.3, 0.1, 1.3), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
					tp.tween_callback(pr.queue_free)
				if bubbles.has(ev.uid):
					var b: Control = bubbles[ev.uid]
					bubbles.erase(ev.uid)
					var tw := b.create_tween()
					tw.tween_property(b, "scale", Vector2(1.4, 1.4), 0.12)
					tw.parallel().tween_property(b, "modulate:a", 0.0, 0.2)
					tw.tween_callback(b.queue_free)
					_popup("片づいた", b.position + Vector2(10, -6), Color("7bdc6b"))
				var d: Dictionary = ShopData.STATIONS[ev.station]
				burst.position = Vector3(d.pos.x, 0.8, d.pos.y)
				burst.restart()
				burst.emitting = true
				Kit.sfx("c_coin", randf_range(0.95, 1.15), -6)
			"late":
				Kit.sfx("c_deny", 0.8, -8)
				if not GameState.tutorial.has("t_late"):
					var tr := _trouble(ev.uid)
					if not tr.is_empty():
						_show_hint("t_late", "赤いのは、余裕を減らす", chips[tr.station])
			"overflow":
				shake = 0.6
				_flash(0.15, Color("ff6b5b"))
				Kit.sfx("c_crash", 1.0, -6)
				var d3: Dictionary = ShopData.STATIONS[ev.station]
				_popup("あふれた！", cam.unproject_position(Vector3(d3.pos.x, 1.4, d3.pos.y)), Color("ff6b5b"))
			"tired":
				Kit.sfx("c_whoosh", 0.7, -6)
				if not GameState.tutorial.has("t_tired"):
					_show_hint("t_tired", "つかれたら、休んで戻る", cards[_crew_index(ev.uid)])
			"rested":
				pass
			"sweep":
				_flash(0.2, Color("fff6c0"))
				Kit.sfx("c_zap", 1.2, -4)
				shake = 0.3
			"surge_warn":
				_banner("どっと来る！", Color("ff8a5b"))
				Kit.sfx("c_drum", 1.3, -4)
			"win":
				_end(true)
			"lose":
				_end(false)


func _trouble(uid: int) -> Dictionary:
	for tr in sim.troubles:
		if tr.uid == uid:
			return tr
	return {}


func _crew_index(uid: int) -> int:
	for i in sim.crew.size():
		if sim.crew[i].uid == uid:
			return i
	return 0


## 困りごとの小物（トゥーンの3D）。行列は小さなお客さん、洗い物は皿の山、品切れは空の箱…
func _make_prop(uid: int, kind: String, sid: String) -> void:
	var d: Dictionary = ShopData.STATIONS[sid]
	var k := 0
	for tr in sim.troubles:
		if tr.station == sid and tr.uid != uid:
			k += 1
	var n := Node3D.new()
	var on_top := kind in ["chuumon", "araimono"]
	var base := Vector3(d.pos.x, 0.0, d.pos.y)
	if on_top:
		n.position = base + Vector3(-0.5 + (k % 4) * 0.35, 0.82, -0.55)
	else:
		n.position = base + Vector3(-0.9 + (k % 4) * 0.6, 0.0, 0.8)
	world.add_child(n)
	match kind:
		"gyouretsu":
			for i in 3:
				_customer(n, Vector3(i * 0.2 - 0.2, 0, i * 0.12), Color("9fb0c8").lerp(Color("c8a8b8"), i / 2.0), 0.8)
		"kakekomi":
			var c := _customer(n, Vector3.ZERO, Color("7fb8ff"), 0.9)
			c.rotation.z = -0.35
		"iraira":
			_customer(n, Vector3.ZERO, Color("c8b0a8"), 0.85)
			for j in 3:
				var puff := _prop_sphere(n, 0.06 + j * 0.02, Vector3(0.05 * j, 0.62 + j * 0.1, 0), Color("ff6b5b"))
				puff.name = "puff%d" % j
		"mizu":
			var pud := _cyl(0.3, 0.02, Vector3(0, 0.012, 0), Color("8fd0ff"), n)
			pud.scale = Vector3(1.3, 1, 0.8)
			_prop_sphere(n, 0.05, Vector3(0.28, 0.05, 0.12), Color("8fd0ff"))
			_cyl(0.08, 0.14, Vector3(-0.3, 0.07, -0.1), Color("f4f1ea"), n).rotation.z = 1.4
		"denwa":
			_box(Vector3(0.28, 0.16, 0.2), Vector3(0, 0.08, 0), Color("e85a4f"), n)
			var hs := _cyl(0.04, 0.3, Vector3(0, 0.22, 0), Color("2e222f"), n)
			hs.rotation.z = PI / 2
		"chuumon":
			for i in 3:
				var t := _box(Vector3(0.18, 0.01, 0.26), Vector3(0, 0.02 + i * 0.03, 0), Color("fffaf2"), n)
				t.rotation.y = (i - 1) * 0.35
			_box(Vector3(0.06, 0.03, 0.03), Vector3(0.0, 0.12, -0.1), Color("ffd23f"), n)
		"araimono":
			for i in 4:
				_cyl(0.16 - i * 0.01, 0.04, Vector3(0, 0.02 + i * 0.05, 0), Color("f4f7fa"), n)
			_prop_sphere(n, 0.05, Vector3(0.12, 0.25, 0.05), Color("cfeeff"))
			_prop_sphere(n, 0.04, Vector3(-0.1, 0.28, 0.0), Color("cfeeff"))
		"shinagire":
			_box(Vector3(0.4, 0.03, 0.3), Vector3(0, 0.015, 0), Color("d9a86c"), n)
			for q in [[Vector3(0.4, 0.2, 0.03), Vector3(0, 0.1, 0.14)], [Vector3(0.4, 0.2, 0.03), Vector3(0, 0.1, -0.14)], [Vector3(0.03, 0.2, 0.3), Vector3(0.19, 0.1, 0)], [Vector3(0.03, 0.2, 0.3), Vector3(-0.19, 0.1, 0)]]:
				_box(q[0], q[1], Color("d9a86c"), n)
			_box(Vector3(0.1, 0.06, 0.01), Vector3(0.12, 0.2, 0.16), Color("e85a4f"), n)
		"wasuremono":
			var um := _cyl(0.02, 0.5, Vector3(0, 0.12, 0), Color("5b6fc2"), n)
			um.rotation.z = 1.2
			_box(Vector3(0.18, 0.14, 0.1), Vector3(0.18, 0.07, 0.1), Color("ffd23f"), n)
	n.scale = Vector3(1.4, 0.1, 1.4)
	n.create_tween().tween_property(n, "scale", Vector3.ONE * 1.4, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	props[uid] = n


## 小さなお客さん（丸い頭と胴だけ。顔は描かない）
func _customer(parent: Node3D, at: Vector3, col: Color, s := 1.0) -> Node3D:
	var c := Node3D.new()
	c.position = at
	c.scale = Vector3.ONE * s
	parent.add_child(c)
	var body := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 0.14
	cm.height = 0.36
	body.mesh = cm
	body.position = Vector3(0, 0.18, 0)
	body.material_override = Obake3D.toon(col, 0.1)
	c.add_child(body)
	_prop_sphere(c, 0.12, Vector3(0, 0.46, 0), Color("f3dcc8"))
	return c


func _prop_sphere(parent: Node3D, r: float, pos: Vector3, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2
	sm.radial_segments = 12
	sm.rings = 6
	m.mesh = sm
	m.position = pos
	m.material_override = Obake3D.toon(col, 0.1)
	parent.add_child(m)
	return m


func _make_bubble(uid: int, kind: String, sid: String) -> void:
	var b := Control.new()
	b.size = Vector2(36, 36)
	b.pivot_offset = Vector2(18, 18)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.set_meta("icon", ShopData.TROUBLES[kind].icon)
	b.set_meta("frac", 1.0)
	b.set_meta("work", 1.0)
	b.set_meta("late", false)
	b.draw.connect(func(): _draw_bubble(b))
	var d: Dictionary = ShopData.STATIONS[sid]
	b.position = cam.unproject_position(Vector3(d.pos.x, 1.0, d.pos.y)) - Vector2(18, 60)
	b.scale = Vector2(0.2, 0.2)
	tag_layer.add_child(b)
	b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bubbles[uid] = b


func _draw_bubble(b: Control) -> void:
	var c := Vector2(18, 18)
	var late: bool = b.get_meta("late")
	var frac: float = b.get_meta("frac")
	var bg := Color("ffe3df") if late else Color.WHITE
	if late and sin(_t * 10.0) > 0:
		bg = Color("ffb3a8")
	b.draw_circle(c + Vector2(0, 2), 17, Color(0, 0, 0, 0.18))
	b.draw_circle(c, 17, bg)
	var col := Color("7bdc6b") if frac > 0.5 else (Color("ffc23d") if frac > 0.25 else Color("ff6b5b"))
	if late:
		col = Color("e85a4f")
		frac = 1.0
	b.draw_arc(c, 15, -PI / 2, -PI / 2 + TAU * frac, 32, col, 3.5, true)
	# 片づき具合：下からたまる
	var w: float = b.get_meta("work")
	if w < 0.999:
		b.draw_arc(c, 11, PI / 2 - PI * (1.0 - w), PI / 2 + PI * (1.0 - w), 24, Color(0.48, 0.86, 0.42, 0.35), 5.0)
	var icon: String = b.get_meta("icon")
	var fs := 13 if icon.length() <= 1 else 11
	var tw := Kit.font_black.get_string_size(icon, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	b.draw_string(Kit.font_black, Vector2(c.x - tw / 2, c.y + fs * 0.38), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Kit.INK)


func _popup(t: String, at: Vector2, c: Color) -> void:
	var l := Kit.text(t, 14, c, true)
	l.add_theme_color_override("font_outline_color", Kit.INK)
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = at
	tag_layer.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", at.y - 26, 0.6)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.3)
	tw.tween_callback(l.queue_free)


func _banner(t: String, c: Color) -> void:
	banner.text = t
	banner.add_theme_color_override("font_color", c)
	banner.modulate.a = 1.0
	banner.scale = Vector2(0.4, 0.4)
	var tw := banner.create_tween()
	tw.tween_property(banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.0)
	tw.tween_property(banner, "modulate:a", 0.0, 0.4)


func _flash(a: float, c := Color.WHITE) -> void:
	flash.color = c
	flash.modulate.a = a
	flash.create_tween().tween_property(flash, "modulate:a", 0.0, 0.35)


## レアを置いたとき：名前とお手伝いをひと言
func _callout(id: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.96), 16, 0.2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.add_child(Kit.text(GameState.info(id).name, 15, Kit.INK, true))
	var help: String = ShopData.help_of(id)
	var l := Kit.text(ShopData.HELP_TEXT.get(help, ""), 11, Kit.SUB)
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.custom_minimum_size = Vector2(260, 0)
	v.add_child(l)
	p.add_child(v)
	p.position = Vector2(-320, 64)
	add_child(p)
	var tw := p.create_tween()
	tw.tween_property(p, "position:x", 14.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


# ---------- 案内（いちどにひとつ） ----------

var hint_target: Control
var hint_time := 0.0


func _show_hint(key: String, text: String, target: Control, once := true) -> void:
	if demo or (once and GameState.tutorial.has(key)):
		return
	if hint.visible and hint_key != key:
		return
	if once:
		GameState.tutorial[key] = true
	hint_key = key
	hint_label.text = text
	hint_target = target
	hint_time = 0.0
	hint.visible = true


func _hide_hint(key: String) -> void:
	if hint_key == key:
		hint.visible = false
		hint_key = ""


func _update_hint() -> void:
	if not hint.visible or hint_target == null or not is_instance_valid(hint_target):
		return
	hint_time += get_process_delta_time()
	if hint_time > 6.0 and hint_key != "t_pick":
		_hide_hint(hint_key)
		return
	hint.reset_size()
	var r := hint_target.get_global_rect()
	var y := r.position.y - hint.size.y - 8 + sin(_t * 6.0) * 3.0
	hint.position = Vector2(clampf(r.get_center().x - hint.size.x / 2, 8, 352 - hint.size.x), maxf(56, y))


# ---------- 進行 ----------

func _intro() -> void:
	var num := ("%d-%d " % [si + 1, st + 1]) if not stage.get("rush", false) else ""
	_banner(num + DefData.stage(si, st).name, Color("ffd23f"))
	Kit.sfx("c_bell", 1.2, -6)
	await get_tree().create_timer(1.4).timeout
	if cards.size() > 0 and not ended:
		_show_hint("t_pick", "おばけを選んで", cards[0])


func _pause() -> void:
	if ended or paused:
		return
	paused = true
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.15, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Kit.CREAM, 24))
	p.position = Vector2(40, 170)
	p.size = Vector2(280, 0)
	overlay.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var t := Kit.text("ひと休み", 22, Kit.INK, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var tip := Kit.text(stage.tip, 13, Kit.SUB)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tip)
	v.add_child(Kit.button("つづける", Kit.ACCENT, func():
		paused = false
		overlay.queue_free()
		overlay = null))
	var sb := Kit.button("はやさ ×%d" % speed, Color.WHITE, func(): pass, Kit.INK, 40, 14)
	sb.pressed.connect(func():
		speed = 2 if speed == 1 else 1
		sb.text = "はやさ ×%d" % speed)
	v.add_child(sb)
	v.add_child(Kit.button("あきらめて帰る", Color("b0a4b8"), func():
		overlay.queue_free()
		overlay = null
		paused = false
		retreated = true
		sim.yoyu = 0
		sim.tick(0.0)
		_handle(sim.pop_events()), Color.WHITE, 40, 14))


var retreated := false


func _end(won: bool) -> void:
	if ended:
		return
	ended = true
	hint.visible = false
	selected = -1
	Kit.music("")
	var stars := sim.stars()
	var stats := {"time": sim.t, "kills": sim.solved, "deployed": sim.crew.size(), "base": sim.yoyu / sim.yoyu_max, "stars": stars, "retreat": retreated}
	var r: Dictionary = GameState.record_battle(si, st, won, stats) if not demo else {"won": won, "coins": 0, "first": false, "orb": false, "lap_up": false, "stats": stats}
	if won:
		Kit.sfx("c_fanfare")
		_flash(0.6)
		_banner("閉店！", Color("ffd23f"))
	else:
		Kit.sfx("c_lose")
		shake = 1.0
		_banner("店が\nパンクした…", Color("b9c4ff"))
	await get_tree().create_timer(1.6).timeout
	if demo:
		return
	_result(r, stars)


func _result(r: Dictionary, stars: int) -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.15, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var p := PanelContainer.new()
	var ps := Kit.pill(Kit.CREAM, 26)
	ps.content_margin_top = 18
	ps.content_margin_bottom = 18
	ps.content_margin_left = 18
	ps.content_margin_right = 18
	p.add_theme_stylebox_override("panel", ps)
	p.position = Vector2(30, 150)
	p.size = Vector2(300, 0)
	overlay.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var won: bool = r.won
	var t := Kit.text("おつかれさま！" if won else "店がパンクした…", 24, Kit.INK, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if won:
		var sl := Kit.text("★".repeat(stars) + "☆".repeat(3 - stars), 34, Color("e8a317"), true)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sl)
	if r.coins > 0:
		var cl := Kit.text("まかない +%d" % r.coins, 20, Color("e8792f"), true)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cl)
		Kit.sfx("c_coin", 1.1)
	# ひと言だけ（いちばん大事なもの）
	var note := ""
	if won and r.get("join", "") != "":
		note = "%sが仲間になった" % GameState.info(r.join).name
	elif won and r.orb:
		note = "虹色の玉をもらった"
	elif won and r.lap_up:
		note = "%d周目がひらいた" % GameState.best_lap
	elif not won:
		note = stage.tip
	if note != "":
		var nl := Kit.text(note, 14, Color("8b7bff"), true)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(nl)
	var to_room: bool = won and GameState.day == 0 and not GameState.scooped_tonight and GameState.total_battles >= 2
	var primary := "休憩室へ" if to_room else ("つぎへ" if won else "もう一回")
	if won and r.lap_up:
		primary = "%d周目へ" % GameState.best_lap
	v.add_child(Kit.button(primary, Kit.ACCENT, func():
		if won and r.lap_up:
			GameState.lap = GameState.best_lap
			GameState.save_game()
		if not won:
			main.go("defense")
			return
		GameState.set_meta("open_next", r.first)
		main.go("room" if to_room else "map")))
	var second := "地図へ" if not won else "もう一回"
	v.add_child(Kit.button(second, Color("b0a4b8"), func(): main.go("map" if not won else "defense"), Color.WHITE, 40, 14))
	p.scale = Vector2(0.85, 0.85)
	p.pivot_offset = Vector2(150, 120)
	p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func demo_rush() -> void:
	auto = true
	speed = 2
