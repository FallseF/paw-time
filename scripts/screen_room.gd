extends Control
## 休憩室（1日の起点）。朝の報告を見て、シフトに行き、ポイをもらって、夜の川べりへ。
## 集めたおばけが床をのんびり歩き回る。

var main

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var walkers: Array = []
## おばけの居場所（前・中・奥に、ずらして並べる。0 は相棒）
const WIDE_RARES := ["hyakki", "wataridori", "shuumatsu"]
const HOMES := [Vector3(-1.3, 0, 0.45), Vector3(0.1, 0, 0.2), Vector3(1.5, 0, -0.1), Vector3(-0.55, 0, -0.35), Vector3(0.6, 0, -0.4), Vector3(-1.95, 0, -1.1), Vector3(-0.95, 0, -1.25), Vector3(0.05, 0, -1.2), Vector3(1.0, 0, -1.3), Vector3(1.95, 0, -1.05)]
var font_bold: FontFile
var font_black: FontFile
var poi_row: HFlowContainer
var card_title: Label
var card_body: Label
var actions: VBoxContainer
var report: PanelContainer
var card: PanelContainer
var quest_btn: Button
var quest_panel: Control
var poi_panel: PanelContainer


func _ready() -> void:
	font_bold = load("res://assets/fonts/ZenMaruGothic-Bold.ttf")
	font_black = load("res://assets/fonts/ZenMaruGothic-Black.ttf")
	_build_world()
	_build_ui()
	_render()
	GameState.changed.connect(_render)
	if GameState.phase == "morning" and GameState.morning_report.size() > 0:
		_show_report()
	else:
		_partner_says()
	if GameState.phase == "morning":
		GameState.phase = "room"
		GameState.save_game() # 朝を見終えたことを残す（開き直しても朝をくり返さない）


# ---------- 3D の休憩室 ----------

func _build_world() -> void:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = UI.msaa()
	box.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)

	# 時間で部屋の光が変わる：朝は白っぽく、仕事のあとは夕方、すくったあとは夜
	var tod := "morning"
	if GameState.phase == "scooped":
		tod = "night"
	elif GameState.worked_today:
		tod = "evening"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = {"morning": Color("efe4d6"), "evening": Color("e9c7a8"), "night": Color("3a3550")}[tod]
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ffe9d6") if tod != "night" else Color("8a90c8")
	env.ambient_light_energy = 0.35 if tod != "night" else 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_color = {"morning": Color("fff4e0"), "evening": Color("ffb27a"), "night": Color("8f9bd6")}[tod]
	sun.light_energy = {"morning": 0.65, "evening": 0.6, "night": 0.35}[tod]
	sun.shadow_enabled = true
	world.add_child(sun)

	cam = Camera3D.new()
	cam.position = Vector3(0, 4.4, 7.4)
	cam.fov = 38
	cam.v_offset = -0.42
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.3, -0.6))

	_box(Vector3(12, 0.1, 12), Vector3(0, -0.05, 0), Color("b98258"))
	# 床板の目地
	for i in 12:
		_box(Vector3(12, 0.005, 0.02), Vector3(0, 0.001, -5.5 + i), Color("a06e48"))
	_box(Vector3(12, 5, 0.2), Vector3(0, 2.5, -2.6), Color("efe0cc"))
	_box(Vector3(12, 0.9, 0.22), Vector3(0, 0.45, -2.5), Color("c99468"))
	# 窓（夕方）
	var win := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.1)
	win.mesh = q
	win.position = Vector3(-1.6, 2.0, -2.48)
	var wm := StandardMaterial3D.new()
	wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wm.albedo_color = {"morning": Color("cfeaff"), "evening": Color("ffb070"), "night": Color("1c2350")}[tod]
	win.material_override = wm
	world.add_child(win)
	_box(Vector3(1.75, 0.08, 0.06), Vector3(-1.6, 1.43, -2.44), Color("7a5238"))
	_box(Vector3(0.06, 1.1, 0.06), Vector3(-1.6, 2.0, -2.44), Color("7a5238"))
	# シフト表
	_box(Vector3(1.0, 0.8, 0.04), Vector3(0.9, 2.0, -2.46), Color("fffaf2"))
	for i in 4:
		_box(Vector3(0.25, 0.06, 0.01), Vector3(0.6 + (i % 2) * 0.4, 2.2 - i * 0.14, -2.43), [Color("ff9e6b"), Color("5fc4ff"), Color("7bdc6b"), Color("a98bff")][i])
	# ロッカー
	_box(Vector3(1.0, 2.0, 0.6), Vector3(2.4, 1.0, -2.1), Color("7fa6c9"))
	_box(Vector3(0.02, 1.9, 0.01), Vector3(2.4, 1.0, -1.79), Color("56789a"))
	# ちゃぶ台と座布団
	var table := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.75
	tm.bottom_radius = 0.75
	tm.height = 0.08
	table.mesh = tm
	table.position = Vector3(-2.1, 0.42, -1.5)
	table.material_override = Obake3D.toon(Color("8a5a3a"), 0.1)
	world.add_child(table)
	_box(Vector3(0.08, 0.4, 0.08), Vector3(-2.1, 0.2, -1.5), Color("6b4430"))
	var cup := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.08
	cm.bottom_radius = 0.07
	cm.height = 0.14
	cup.mesh = cm
	cup.position = Vector3(-1.9, 0.53, -1.6)
	cup.material_override = Obake3D.toon(Color("f4f1ea"), 0.2)
	world.add_child(cup)
	_box(Vector3(0.8, 0.1, 0.8), Vector3(1.9, 0.05, -0.9), Color("c9454a"))

	_build_decor()
	# おばけたち
	var ids: Array = GameState.owned.keys()
	# 相棒 → 新しく会った子（5体まで） → ふつうのおばけ → そのほか
	ids.sort_custom(func(a, b): return _met_day(a) > _met_day(b))
	var order: Array = []
	# マイおばけ猫は、いつも休憩室にいる（相棒なら一番前）
	if not GameState.my_obake.is_empty():
		order.append("my")
	if ids.has(GameState.partner):
		order.append(GameState.partner)
	if GameState.partner == "my":
		order.erase("my")
		order.push_front("my")
	for id in ids.slice(0, 5):
		if not order.has(id):
			order.append(id)
	for id in GameState.NORMAL_IDS:
		if ids.has(id) and not order.has(id):
			order.append(id)
	for id in ids:
		if not order.has(id):
			order.append(id)
	ids = order
	for i in min(ids.size(), 10):
		var id: String = ids[i]
		var ob: Obake3D
		if id == "my":
			ob = Obake3D.make_custom(GameState.my_obake.look)
		else:
			ob = Obake3D.make(id)
			ob.set_level(GameState.level_of(id))
		# レアは3Dで少し大きいので小さめに。横に広い子（行列・渡り鳥・週末）はさらに小さく
		var sc := 0.62
		if Rares.is_rare(id):
			sc = 0.42 if id in WIDE_RARES else 0.5
		ob.scale = Vector3.ONE * sc
		if i == 0:
			ob.scale *= 1.05 # 相棒は少し大きく、前に
		# まだ少ないうちは、まんなかから並べる
		var slot: int = i
		if ids.size() <= 3:
			slot = [1, 3, 4][i]
		if id == "my" and GameState.partner == "my":
			slot = 1 if ids.size() <= 3 else 0
		var home: Vector3 = HOMES[slot] + Vector3(randf_range(-0.15, 0.15), 0, randf_range(-0.1, 0.1))
		ob.position = home
		world.add_child(ob)
		walkers.append({"o": ob, "target": ob.position, "wait": randf_range(0.5, 3.0), "home": home})


## 工房で作ったかざり
func _build_decor() -> void:
	var d: Dictionary = GameState.decor
	if d.has("chochin"):
		for x in [-1.0, 1.2]:
			var l := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.22
			sm.height = 0.5
			l.mesh = sm
			l.position = Vector3(x, 1.5, -2.1)
			l.material_override = Obake3D.toon(Color("e8483f"), 0.2, 0.8)
			world.add_child(l)
			_box(Vector3(0.02, 1.4, 0.02), Vector3(x, 2.4, -2.1), Color("3a2a2a"))
			var ol := OmniLight3D.new()
			ol.light_color = Color("ff9a6b")
			ol.light_energy = 0.8
			ol.omni_range = 2.5
			ol.position = Vector3(x, 1.7, -1.8)
			world.add_child(ol)
	if d.has("plant"):
		var pot := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.22
		cm.bottom_radius = 0.16
		cm.height = 0.35
		pot.mesh = cm
		pot.position = Vector3(-2.6, 0.18, -1.9)
		pot.material_override = Obake3D.toon(Color("c7744a"), 0.1)
		world.add_child(pot)
		for i in 5:
			var leaf := MeshInstance3D.new()
			var lm := SphereMesh.new()
			lm.radius = 0.2
			lm.height = 0.4
			leaf.mesh = lm
			leaf.position = Vector3(-2.6 + cos(i * 1.3) * 0.15, 0.55 + i * 0.12, -1.9 + sin(i * 1.3) * 0.15)
			leaf.material_override = Obake3D.toon(Color("5f9e5a"), 0.2)
			world.add_child(leaf)
	if d.has("bowl"):
		var bowl := MeshInstance3D.new()
		var bm := SphereMesh.new()
		bm.radius = 0.25
		bm.height = 0.45
		bowl.mesh = bm
		_box(Vector3(0.7, 0.06, 0.35), Vector3(1.9, 1.05, -2.3), Color("8a5a3a"))
		bowl.position = Vector3(1.9, 1.3, -2.3)
		var gm := StandardMaterial3D.new()
		gm.albedo_color = Color(0.7, 0.9, 1.0, 0.35)
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bowl.material_override = gm
		world.add_child(bowl)
		var orb := MeshInstance3D.new()
		var om := SphereMesh.new()
		om.radius = 0.07
		om.height = 0.14
		orb.mesh = om
		orb.position = bowl.position
		var em := StandardMaterial3D.new()
		em.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		em.albedo_color = Color("fff2a8")
		orb.material_override = em
		world.add_child(orb)
	if d.has("poster"):
		_box(Vector3(0.6, 0.7, 0.03), Vector3(0.1, 1.45, -2.47), Color("2b3478"))
		_box(Vector3(0.3, 0.3, 0.01), Vector3(0.1, 1.55, -2.45), Color("fff1c8"))
		_box(Vector3(0.44, 0.06, 0.01), Vector3(0.1, 1.24, -2.45), Color("ffc23d"))
	if d.has("kotatsu"):
		_box(Vector3(1.2, 0.08, 1.2), Vector3(0.9, 0.42, -1.2), Color("8a5a3a"))
		_box(Vector3(1.4, 0.36, 1.4), Vector3(0.9, 0.2, -1.2), Color("d9554f"))
		var mikan := MeshInstance3D.new()
		var mm := SphereMesh.new()
		mm.radius = 0.08
		mm.height = 0.14
		mikan.mesh = mm
		mikan.position = Vector3(0.8, 0.52, -1.1)
		mikan.material_override = Obake3D.toon(Color("ff9a2a"), 0.2)
		world.add_child(mikan)
	if d.has("dango"):
		_box(Vector3(0.4, 0.1, 0.4), Vector3(-2.0, 0.5, -1.4), Color("c9a06b"))
		for i in 3:
			var dg := MeshInstance3D.new()
			var dm := SphereMesh.new()
			dm.radius = 0.09
			dm.height = 0.18
			dg.mesh = dm
			dg.position = Vector3(-2.08 + i * 0.08, 0.63 + (0.12 if i == 1 else 0.0), -1.4)
			dg.material_override = Obake3D.toon(Color("fbf6ea"), 0.3)
			world.add_child(dg)


func _met_day(id: String) -> int:
	var v = GameState.seen.get(id, 0)
	return v if typeof(v) == TYPE_INT else 0


func _box(size: Vector3, pos: Vector3, c: Color) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = Obake3D.toon(c, 0.05)
	world.add_child(m)


func _process(delta: float) -> void:
	# 重なりすぎないように、近いおばけどうしは少し離れる
	for i in walkers.size():
		for j in range(i + 1, walkers.size()):
			var a: Obake3D = walkers[i].o
			var b: Obake3D = walkers[j].o
			var d := Vector3(a.position.x - b.position.x, 0, a.position.z - b.position.z)
			var l := d.length()
			var want := 0.7
			if a.species in WIDE_RARES or b.species in WIDE_RARES:
				want = 1.05 # 横に広い子のまわりは、少しあける
			if l < want and l > 0.001:
				var push := d / l * (want - l) * 1.5 * delta
				a.position += push
				b.position -= push
	for w in walkers:
		var ob: Obake3D = w.o
		ob.position.x = clampf(ob.position.x, -2.2, 2.2)
		ob.position.z = clampf(ob.position.z, -1.9, 1.0)
		w.wait -= delta
		if w.wait > 0:
			continue
		var to: Vector3 = w.target
		var d := to - ob.position
		if d.length() < 0.05:
			var hm: Vector3 = w.home
			w.target = hm + Vector3(randf_range(-0.35, 0.35), 0, randf_range(-0.25, 0.25))
			w.target.x = clampf(w.target.x, -2.1, 2.1)
			w.target.z = clampf(w.target.z, -1.8, 0.9)
			w.wait = randf_range(1.0, 4.0)
			continue
		ob.position += d.normalized() * min(d.length(), 0.5 * delta)
		ob.rotation.y = lerp_angle(ob.rotation.y, atan2(d.x, d.z), 5.0 * delta)


# ---------- おばけをタップ ----------

func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	else:
		return
	var best: Dictionary = {}
	var best_d := 46.0
	for w in walkers:
		var ob: Obake3D = w.o
		var p := cam.unproject_position(ob.global_position + Vector3(0, 0.35, 0))
		var d := p.distance_to(pos)
		if d < best_d:
			best_d = d
			best = w
	if best.is_empty():
		return
	var ob: Obake3D = best.o
	best.wait = 1.5
	var tw := create_tween()
	tw.tween_property(ob, "position:y", 0.45, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ob, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	ob.rotation.y = atan2(cam.global_position.x - ob.global_position.x, cam.global_position.z - ob.global_position.z)
	_play_sfx("pop")
	var id: String = ob.species
	var info: Dictionary = GameState.info(id)
	var line: String = info.name
	if id == "my":
		line = "マイおばけ猫" + ("（相棒）" if GameState.partner == "my" else "")
	elif GameState.SPECIES.has(id):
		line += "  Lv%d" % GameState.level_of(id)
		if GameState.partner == id:
			line += "（相棒）"
	else:
		line += "  レア・" + String(info.get("group", ""))
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", _pill(Color(1, 1, 1, 0.95), 16))
	bubble.add_child(_text(line, 14, Color("2a2233"), font_black))
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubble)
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var p2 := cam.unproject_position(ob.global_position + Vector3(0, 1.0, 0))
	bubble.position = Vector2(clampf(p2.x - bubble.size.x / 2, 8, 352 - bubble.size.x), p2.y - 44)
	var tw2 := create_tween()
	tw2.tween_interval(1.4)
	tw2.tween_property(bubble, "modulate:a", 0.0, 0.3)
	tw2.tween_callback(bubble.queue_free)


# ---------- UI ----------

func _pill(bg: Color, radius := 20) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.14)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	return s


func _text(t: String, size: int, color := Color("2a2233"), font: FontFile = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font if font else font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _button(t: String, bg: Color, cb: Callable, fg := Color.WHITE) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_override("font", font_black)
	b.add_theme_font_size_override("font_size", 17)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, _pill(bg if k != "pressed" else bg.darkened(0.1), 25))
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.pressed.connect(cb)
	return b


func _build_ui() -> void:
	var s := GameState.today()
	var top := HBoxContainer.new()
	top.position = Vector2(12, 14)
	top.size = Vector2(336, 44)
	top.add_theme_constant_override("separation", 6)
	add_child(top)
	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", _pill(Color(1, 1, 1, 0.92), 22))
	dp.add_child(_text("第%d週 %s曜日" % [GameState.week_no(), s.day], 16, Color("2a2233"), font_black))
	top.add_child(dp)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var hb := _button("？", Color(1, 1, 1, 0.92), _show_boost_help, Color("5b6fc2"))
	hb.custom_minimum_size = Vector2(40, 44)
	hb.visible = GameState.unlocked("help")
	top.add_child(hb)
	var ws := _button("工房", Color(1, 1, 1, 0.92), func(): main.go("workshop"), Color("d9774a"))
	ws.custom_minimum_size = Vector2(62, 44)
	ws.visible = GameState.unlocked("workshop") # 仕組みは少しずつ見せる
	top.add_child(ws)
	if GameState.next_unlock_text().begins_with("工房で"):
		var wdot := _dot(Color("ff5b5b"))
		wdot.position = Vector2(50, -2)
		ws.add_child(wdot)
	var zk := _button("図鑑", Color(1, 1, 1, 0.92), func(): main.go("zukan"), Color("8a5bd6"))
	zk.custom_minimum_size = Vector2(62, 44)
	zk.visible = GameState.unlocked("zukan")
	top.add_child(zk)
	if GameState.claimable().size() > 0 or GameState.seen.size() > int(GameState.tut.get("zukan_seen", 1)):
		var dot := _dot(Color("ff5b5b"))
		dot.position = Vector2(50, -2)
		zk.add_child(dot)

	var pp := PanelContainer.new()
	poi_panel = pp
	pp.add_theme_stylebox_override("panel", _pill(Color(1, 1, 1, 0.85), 18))
	pp.position = Vector2(12, 66)
	pp.visible = false # ポイは川べりの棚で見る（休憩室では出さない）
	add_child(pp)
	pp.size = Vector2(336, 0)
	poi_row = HFlowContainer.new()
	poi_row.add_theme_constant_override("h_separation", 5)
	poi_row.add_theme_constant_override("v_separation", 0)
	pp.add_child(poi_row)

	quest_btn = Button.new()
	quest_btn.focus_mode = Control.FOCUS_NONE
	quest_btn.position = Vector2(12, 112)
	quest_btn.add_theme_font_override("font", font_black)
	quest_btn.add_theme_font_size_override("font_size", 13)
	for k in ["normal", "hover", "pressed"]:
		quest_btn.add_theme_stylebox_override(k, _pill(Color(0.16, 0.13, 0.22, 0.85), 16))
	quest_btn.add_theme_color_override("font_color", Color("ffe27a"))
	quest_btn.add_theme_color_override("font_hover_color", Color("ffe27a"))
	quest_btn.pressed.connect(_show_quests)
	add_child(quest_btn)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _pill(Color(1, 0.99, 0.97, 0.97), 24))
	card.position = Vector2(12, 400)
	card.size = Vector2(336, 0)
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	card_title = _text("", 19, Color("2a2233"), font_black)
	v.add_child(card_title)
	card_body = _text("", 13, Color("6a5f70"))
	card_body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	card_body.custom_minimum_size = Vector2(300, 0)
	v.add_child(card_body)
	actions = VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	v.add_child(actions)


func _dot(c: Color) -> Panel:
	var p := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(7)
	p.add_theme_stylebox_override("panel", s)
	p.custom_minimum_size = Vector2(14, 14)
	p.size = Vector2(14, 14)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _render() -> void:
	var qs := GameState.week_quests()
	var done := 0
	for q in qs:
		if GameState.claimed.has(q.key):
			done += 1
	var ready := GameState.quests_claimable()
	quest_btn.text = ("おねがい：%dつ受け取れる" % ready) if ready > 0 else ("今週のおねがい %d/3" % done)
	quest_btn.visible = GameState.unlocked("quests")
	_place_quest_btn()
	for c in poi_row.get_children():
		c.queue_free()
	poi_row.add_child(_text("ポイ", 12, Color("8a7a88")))
	# 紙・色・特別の3つにまとめて見せる（くわしくは川べりの棚で）
	var groups := [["紙", ["paper"], Color("f4efe6")], ["色", ["receipt", "bubble", "tray", "pan", "box"], Color("5fc4ff")], ["特別", ["kira", "lure", "double", "akari"], Color("fff2a8")]]
	for g in groups:
		var n := 0
		for id in g[1]:
			n += GameState.pois.get(id, 0)
		if n <= 0:
			continue
		poi_row.add_child(_dot(g[2].darkened(0.08)))
		poi_row.add_child(_text("%s %d" % [g[0], n], 12))
	if GameState.total_pois() == 0:
		poi_row.add_child(_text("なし", 12, Color("8a7a88")))
	if GameState.strength != 1.0:
		poi_row.add_child(_text("強さ×%.2f" % GameState.strength, 12, Color("8b7bff")))

	for c in actions.get_children():
		c.queue_free()
	var s: Dictionary = GameState.today()
	var fest := GameState.is_festival()
	# カードは「題・一行・ボタン」だけ。くわしいことは「？」や各画面へ
	if GameState.phase == "scooped":
		card_title.text = "今夜は %dこ すくった" % GameState.tonight.get("count", 0)
		card_body.text = "寝ると、玉が朝にかえる"
		actions.add_child(_button("寝る", Color("8b7bff"), func(): main.go("sleep")))
		_fit_card()
		return
	var night_label := "夜の川べりへ" if not fest else "大すくい祭りへ"
	var night_col := Color("5b6fc2") if not fest else Color("e8603c")
	if not GameState.unlocked("shift"):
		# はじめての日：やることはひとつ
		card_title.text = "夜の川べりへ"
		card_body.text = "光る玉を、ポイですくおう"
		actions.add_child(_button("すくいに行く", night_col, func(): main.go("catch")))
	elif s.role != "" and not GameState.worked_today:
		card_title.text = "今日は%sのシフト" % GameState.ROLE_LABEL[s.role]
		var first: bool = not GameState.stores_seen.has(s.store) or not GameState.roles_seen.has(s.role)
		card_body.text = "働くと 色のポイ+%d%s" % [GameState.work_poi_count(s.hours), "・きらきら+1" if first else ""]
		actions.add_child(_button("シフトに行く", Color("ff8a5b"), _do_shift))
		var skip := _button("働かずに川へ", Color(1, 1, 1, 1), func(): main.go("catch"), night_col)
		skip.custom_minimum_size = Vector2(0, 38)
		skip.add_theme_font_size_override("font_size", 14)
		actions.add_child(skip)
	else:
		if GameState.worked_today:
			card_title.text = "おつかれさま"
			card_body.text = _got_text if _got_text != "" else "色のポイは、同じ色の玉を寄せる"
		else:
			card_title.text = "今日はお休み"
			card_body.text = "紙のポイで、川へ行ける"
		if fest:
			card_body.text = "今夜は大すくい祭り"
		actions.add_child(_button(night_label, night_col, func(): main.go("catch")))
	_fit_card()


func _fit_card() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if not is_instance_valid(card):
		return
	card.reset_size()
	card.size.x = 336
	card.position.y = 628.0 - card.size.y


var _got_text := ""


func _do_shift() -> void:
	var got := GameState.finish_shift()
	var parts: Array = []
	for g in got:
		parts.append("%s+%d" % [GameState.POI[g.poi].short, g.n])
	_got_text = "もらった：" + "・".join(parts)
	_play_sfx("chime")
	# もらったポイが、上のポイの棚へ飛んでいく
	for i in got.size():
		var g: Dictionary = got[i]
		var chip := PanelContainer.new()
		var st := _pill(Color(GameState.POI[g.poi].color), 16)
		chip.add_theme_stylebox_override("panel", st)
		chip.add_child(_text("+%d %s" % [g.n, GameState.POI[g.poi].short], 15, Color("2a2233"), font_black))
		chip.position = Vector2(110 + i * 20, 470)
		chip.modulate.a = 0.0
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(chip)
		var tw := create_tween()
		tw.tween_interval(0.15 * i)
		tw.tween_property(chip, "modulate:a", 1.0, 0.12)
		tw.tween_property(chip, "position", Vector2(60 + i * 60, 72), 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(chip, "modulate:a", 0.0, 0.2)
		tw.tween_callback(chip.queue_free)
	if is_instance_valid(poi_panel):
		poi_panel.pivot_offset = poi_panel.size / 2
		var bump := create_tween()
		bump.tween_interval(0.75)
		bump.tween_property(poi_panel, "scale", Vector2(1.06, 1.06), 0.1)
		bump.tween_property(poi_panel, "scale", Vector2.ONE, 0.2)
	GameState.save_game()
	_render()
	_pop_card()


func _play_sfx(n: String) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load("res://assets/sfx/%s.wav" % n)
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _pop_card() -> void:
	var card: Control = actions.get_parent().get_parent()
	card.pivot_offset = card.size / 2
	card.scale = Vector2(1.05, 1.05)
	create_tween().tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_report() -> void:
	report = PanelContainer.new()
	report.add_theme_stylebox_override("panel", _pill(Color(0.16, 0.13, 0.22, 0.92), 22))
	report.position = Vector2(16, 66)
	quest_btn.modulate.a = 0.0 # 報告のあいだは、ほかの表示を重ねない
	report.size = Vector2(328, 0)
	report.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(report)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	report.add_child(v)
	v.add_child(_text("けさのこと", 14, Color("ffe27a"), font_black))
	for line in GameState.morning_report:
		var l := _text("・" + line, 13, Color("f3eeff"))
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		l.custom_minimum_size = Vector2(296, 0)
		v.add_child(l)
	v.add_child(_text("タップで閉じる", 11, Color(1, 1, 1, 0.45)))
	report.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			_close_report())
	report.modulate.a = 0.0
	create_tween().tween_property(report, "modulate:a", 1.0, 0.3)
	var tw := create_tween()
	tw.tween_interval(9.0)
	tw.tween_callback(_close_report)


func _place_quest_btn() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if is_instance_valid(poi_panel):
		quest_btn.position.y = 66.0


## 仕事と睡眠が、どう効くか
func _show_boost_help() -> void:
	if quest_panel:
		quest_panel.queue_free()
	quest_panel = Control.new()
	quest_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(quest_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.15, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			quest_panel.queue_free()
			quest_panel = null)
	quest_panel.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _pill(Color(1, 0.99, 0.97, 0.98), 24))
	p.position = Vector2(16, 110)
	p.size = Vector2(328, 0)
	quest_panel.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(_text("ポイのもらい方", 19, Color("2a2233"), font_black))
	for pair in [["毎朝", "紙のポイ 2本（働かない日も）"], ["働いた日", "色のポイ 2本（何時間でも同じ）。はじめての店・仕事なら、きらきらポイも"], ["よく寝た朝", "ポイが ×1.2 強くなり、玉が★ひとつ育ってかえる（寝すぎは得しない）"], ["工房", "かぶったおばけのかけらで、ポイを作る・改良する"], ["レア", "いろんな働き方・休み方・眠り方、そして虹の玉で出会える"]]:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		row.add_child(_text(pair[0], 14, Color("e8603c"), font_black))
		var d := _text(pair[1], 13, Color("4a3f52"))
		d.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		d.custom_minimum_size = Vector2(296, 0)
		row.add_child(d)
		v.add_child(row)
	v.add_child(_text("タップで閉じる", 11, Color("9a8e98")))


## 今週のおねがい（3つ。そろうと、おまけ）
func _show_quests() -> void:
	if quest_panel:
		quest_panel.queue_free()
	quest_panel = Control.new()
	quest_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(quest_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.15, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			quest_panel.queue_free()
			quest_panel = null)
	quest_panel.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _pill(Color(1, 0.99, 0.97, 0.98), 24))
	p.position = Vector2(16, 130)
	p.size = Vector2(328, 0)
	quest_panel.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(_text("第%d週のおねがい" % GameState.week_no(), 19, Color("2a2233"), font_black))
	var sub := _text("ひとつにつき 虹のかけら・きらきらポイ。3つそろうと、おまけ", 12, Color("8a7a88"))
	sub.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	sub.custom_minimum_size = Vector2(296, 0)
	v.add_child(sub)
	for q in GameState.week_quests():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var prog := mini(GameState.quest_progress(q), q.n)
		var qt := _text(q.text, 15, Color("2a2233"), font_black)
		qt.clip_text = true
		col.add_child(qt)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(0, 8)
		bar.max_value = q.n
		bar.value = prog
		bar.show_percentage = false
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.1)
		bg.set_corner_radius_all(4)
		var fg := StyleBoxFlat.new()
		fg.bg_color = Color("ffb35c")
		fg.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fg)
		col.add_child(bar)
		col.add_child(_text("%d / %d" % [prog, q.n], 11, Color("8a7a88")))
		row.add_child(col)
		if GameState.claimed.has(q.key):
			row.add_child(_text("受け取りずみ", 12, Color("b07a3a")))
		elif GameState.quest_done(q):
			var b := _button("受け取る", Color("ff8a5b"), func():
				var rw := GameState.claim_quest(q)
				if not rw.is_empty():
					_play_sfx("fanfare")
					_show_quests())
			b.custom_minimum_size = Vector2(92, 40)
			b.add_theme_font_size_override("font_size", 14)
			row.add_child(b)
		v.add_child(row)
	v.add_child(_text("タップで閉じる", 11, Color("9a8e98")))


## 相棒が真顔でひとこと
func _partner_says() -> void:
	if not GameState.unlocked("partner_line"):
		return
	var w: Dictionary = {}
	for x in walkers:
		if x.o.species == GameState.partner:
			w = x
	if w.is_empty():
		return
	var line := GameState.partner_line()
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", _pill(Color(1, 1, 1, 0.95), 16))
	var l := _text(line, 13, Color("2a2233"))
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.custom_minimum_size = Vector2(250, 0)
	bubble.add_child(l)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.modulate.a = 0.0
	add_child(bubble)
	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(bubble):
		return
	w.wait = 4.5
	var ob: Obake3D = w.o
	var p := cam.unproject_position(ob.global_position + Vector3(0, 1.0, 0))
	bubble.reset_size()
	bubble.position = Vector2(clampf(p.x - bubble.size.x / 2, 8, 352 - bubble.size.x), clampf(p.y - bubble.size.y - 6, 158, 330))
	var tw := create_tween()
	tw.tween_property(bubble, "modulate:a", 1.0, 0.25)
	tw.tween_interval(3.8)
	tw.tween_property(bubble, "modulate:a", 0.0, 0.4)
	tw.tween_callback(bubble.queue_free)


func _close_report() -> void:
	if report == null or not is_instance_valid(report):
		return
	var r := report
	report = null
	create_tween().tween_property(quest_btn, "modulate:a", 1.0, 0.3)
	var tw := create_tween()
	tw.tween_property(r, "modulate:a", 0.0, 0.3)
	tw.tween_callback(r.queue_free)
	_partner_says()


func demo_tap() -> void:
	if walkers.is_empty():
		return
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = cam.unproject_position(walkers[0].o.global_position + Vector3(0, 0.35, 0))
	_gui_input(e)


func demo_quests() -> void:
	_show_quests()
