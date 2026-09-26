extends Control
## 休憩室（1日の起点）。朝の報告を見て、シフトに行き、ポイをもらって、夜の川べりへ。
## 集めたおばけが床をのんびり歩き回る。

var main

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var walkers: Array = []
var font_bold: FontFile
var font_black: FontFile
var poi_row: HBoxContainer
var card_title: Label
var card_body: Label
var actions: VBoxContainer
var report: PanelContainer


func _ready() -> void:
	font_bold = load("res://assets/fonts/ZenMaruGothic-Bold.ttf")
	font_black = load("res://assets/fonts/ZenMaruGothic-Black.ttf")
	_build_world()
	_build_ui()
	_render()
	GameState.changed.connect(_render)
	if GameState.phase == "morning" and GameState.morning_report.size() > 0:
		_show_report()
	if GameState.phase == "morning":
		GameState.phase = "room"


# ---------- 3D の休憩室 ----------

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

	Look.apply(world, "room", Color("e9d6c2"), false, true)

	cam = Camera3D.new()
	cam.position = Vector3(0, 5.2, 8.2)
	cam.fov = 34
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.6, -0.6))

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
	wm.albedo_color = Color("ffc98a")
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
	table.position = Vector3(-0.3, 0.42, 0.3)
	table.material_override = Obake3D.toon(Color("8a5a3a"), 0.1)
	world.add_child(table)
	_box(Vector3(0.08, 0.4, 0.08), Vector3(-0.3, 0.2, 0.3), Color("6b4430"))
	var cup := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.08
	cm.bottom_radius = 0.07
	cm.height = 0.14
	cup.mesh = cm
	cup.position = Vector3(-0.1, 0.53, 0.2)
	cup.material_override = Obake3D.toon(Color("f4f1ea"), 0.2)
	world.add_child(cup)
	_box(Vector3(0.8, 0.1, 0.8), Vector3(1.4, 0.05, 1.0), Color("c9454a"))

	# おばけたち
	var n := GameState.owned.size()
	for i in n:
		var o: Dictionary = GameState.owned[i]
		var ob := Obake3D.make(o.id)
		ob.scale = Vector3.ONE * 0.62
		ob.position = Vector3(randf_range(-2.2, 2.2), 0, randf_range(-1.9, 0.2))
		world.add_child(ob)
		walkers.append({"o": ob, "target": ob.position, "wait": randf_range(0.5, 3.0)})


func _box(size: Vector3, pos: Vector3, c: Color) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = Obake3D.toon(c, 0.05)
	world.add_child(m)


func _process(delta: float) -> void:
	for w in walkers:
		var ob: Obake3D = w.o
		w.wait -= delta
		if w.wait > 0:
			continue
		var to: Vector3 = w.target
		var d := to - ob.position
		if d.length() < 0.05:
			w.target = Vector3(randf_range(-2.2, 2.2), 0, randf_range(-1.9, 0.2))
			w.wait = randf_range(1.0, 4.0)
			continue
		ob.position += d.normalized() * min(d.length(), 0.5 * delta)
		ob.rotation.y = lerp_angle(ob.rotation.y, atan2(d.x, d.z), 5.0 * delta)


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
	var top := HBoxContainer.new()
	top.position = Vector2(14, 16)
	top.size = Vector2(332, 44)
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", _pill(Color(1, 1, 1, 0.92), 22))
	dp.add_child(_text("%s曜日の休憩室" % GameState.today().day, 16, Color("2a2233"), font_black))
	top.add_child(dp)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var zk := _button("図鑑", Color(1, 1, 1, 0.92), func(): main.go("zukan"), Color("8a5bd6"))
	zk.custom_minimum_size = Vector2(70, 40)
	top.add_child(zk)

	var pp := PanelContainer.new()
	pp.add_theme_stylebox_override("panel", _pill(Color(1, 1, 1, 0.85), 18))
	pp.position = Vector2(14, 68)
	add_child(pp)
	poi_row = HBoxContainer.new()
	poi_row.add_theme_constant_override("separation", 10)
	pp.add_child(poi_row)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _pill(Color(1, 0.99, 0.97, 0.96), 24))
	card.position = Vector2(16, 430)
	card.size = Vector2(328, 190)
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	card_title = _text("", 18, Color("2a2233"), font_black)
	v.add_child(card_title)
	card_body = _text("", 14, Color("6a5f70"))
	card_body.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
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
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


func _render() -> void:
	for c in poi_row.get_children():
		c.queue_free()
	poi_row.add_child(_text("ポイ", 13, Color("8a7a88")))
	var any := false
	for id in GameState.NETS:
		var n: int = GameState.nets[id]
		if n <= 0:
			continue
		any = true
		var t: String = GameState.NETS[id].type
		poi_row.add_child(_dot(GameState.TYPE_COLOR.get(t, Color("ffd84d"))))
		poi_row.add_child(_text("×%d" % n, 13))
	if not any:
		poi_row.add_child(_text("なし", 13, Color("8a7a88")))
	poi_row.add_child(_text("強さ ×%.2f" % GameState.net_strength, 13, Color("8b7bff")))

	for c in actions.get_children():
		c.queue_free()
	var s: Dictionary = GameState.today()
	if GameState.phase in ["morning", "room"]:
		if s.role == "":
			card_title.text = "今日は休み"
			card_body.text = "ポイはもらえない。残りのポイで、夜の川べりへ行ける"
			actions.add_child(_button("夜の川べりへ", Color("5b6fc2"), _after_shift))
		else:
			card_title.text = "今日のシフト"
			card_body.text = "%s ・ %sの%s %d時間%s\n天気：%s%s" % [s.store, s.band, GameState.ROLE_LABEL[s.role], s.hours, "（はじめて）" if s.first else "", s.weather, "　満月" if s.moon == "満月" else ""]
			actions.add_child(_button("シフトに行く", Color("ff8a5b"), _do_shift))
	elif GameState.phase == "shift_done":
		if GameState.day == GameState.BATTLE_DAY and not GameState.battle_won:
			actions.add_child(_button("金曜の大ピークへ", Color("e85a4f"), func(): main.go("battle")))
		if not GameState.scooped_tonight:
			actions.add_child(_button("夜の川べりで、おばけすくい", Color("5b6fc2"), func(): main.go("catch")))
		actions.add_child(_button("寝る", Color("8b7bff"), func(): main.go("sleep")))


func _do_shift() -> void:
	var got := GameState.finish_shift()
	GameState.phase = "shift_done"
	card_title.text = "おつかれさま！"
	card_body.text = "ポイをもらった：" + "、".join(got)
	GameState.changed.emit()
	card_title.text = "おつかれさま！"
	card_body.text = "ポイをもらった：" + "、".join(got)


func _after_shift() -> void:
	GameState.phase = "shift_done"
	card_title.text = "今夜はどうする？"
	card_body.text = ""
	GameState.changed.emit()


func _show_report() -> void:
	report = PanelContainer.new()
	report.add_theme_stylebox_override("panel", _pill(Color(0.16, 0.13, 0.22, 0.88), 22))
	report.position = Vector2(16, 110)
	report.size = Vector2(328, 0)
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
	var tw := create_tween()
	tw.tween_interval(5.0)
	tw.tween_property(report, "modulate:a", 0.0, 0.6)
	tw.tween_callback(report.queue_free)
