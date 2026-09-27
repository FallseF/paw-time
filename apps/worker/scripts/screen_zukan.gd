extends Control
## 図鑑（コレクション）。ふつうのおばけは 3D の棚、レア 30 体はカード。
## まだ会っていないレアは、影と一文のヒントだけ見せる。

var main

const GROUPS := ["休み", "はじめて", "時間帯", "天気", "つながり", "リズム"]
const NORMAL := ["receipt", "bubble", "tray", "pan", "box", "lantern"]

var font_bold: FontFile
var font_black: FontFile
var detail: Control


func _ready() -> void:
	font_bold = load("res://assets/fonts/ZenMaruGothic-Bold.ttf")
	font_black = load("res://assets/fonts/ZenMaruGothic-Black.ttf")
	var bg := ColorRect.new()
	bg.color = Color("f6efe6")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 見出し
	var head := HBoxContainer.new()
	head.position = Vector2(16, 14)
	head.size = Vector2(328, 44)
	head.add_theme_constant_override("separation", 10)
	add_child(head)
	var rare_have := 0
	for r in Rares.LIST:
		if GameState.seen.has(r.id):
			rare_have += 1
	head.add_child(_text("図鑑", 26, Color("2a2233"), font_black))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	head.add_child(_text(tr("レア %d / %d") % [rare_have, Rares.LIST.size()], 15, Color("8a5bd6")))
	var back := Button.new()
	back.text = "もどる"
	back.add_theme_font_override("font", font_bold)
	back.add_theme_font_size_override("font_size", 14)
	for k in ["normal", "hover", "pressed"]:
		back.add_theme_stylebox_override(k, _pill(Color.WHITE, 18))
	back.add_theme_color_override("font_color", Color("2a2233"))
	back.add_theme_color_override("font_hover_color", Color("2a2233"))
	back.pressed.connect(func(): main.go("garden"))
	head.add_child(back)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 66)
	scroll.size = Vector2(360, 574)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(scroll)
	add_child(scroll)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(360, 0)
	col.add_theme_constant_override("separation", 12)
	scroll.add_child(col)

	col.add_child(_section("ふつうのおばけ"))
	col.add_child(_shelf())
	var hint_n := _text("チョウチンは満月の夜に来る", 11, Color("9a8e98"))
	hint_n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(hint_n)
	col.add_child(_section("庭の育ち"))
	col.add_child(_garden_list())
	for g in GROUPS:
		col.add_child(_section(tr("レア ・ ") + tr(g)))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 12)
		m.add_theme_constant_override("margin_right", 12)
		m.add_child(grid)
		col.add_child(m)
		for r in Rares.LIST:
			if r.group == g:
				grid.add_child(_card(r))
	var tm := MarginContainer.new()
	tm.add_theme_constant_override("margin_left", 90)
	tm.add_theme_constant_override("margin_right", 90)
	tm.add_theme_constant_override("margin_top", 10)
	tm.add_child(Kit.button("タイトルへ（保存ずみ）", Color(1, 1, 1, 0.9), func():
		GameState.save()
		main.go("title"), Color("8a7a88"), 36, 12))
	col.add_child(tm)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 30)
	col.add_child(pad)


func _pill(bg: Color, radius := 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.shadow_color = Color(Tokens.SHADOW, 0.08)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 2)
	return s


func _text(t: String, size: int, color := Color("2a2233"), font: FontFile = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font if font else font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _section(t: String) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_top", 6)
	m.add_child(_text(t, 15, Color("8a7a88")))
	return m


## ふつうのおばけ 5 体を並べた 3D の棚
func _shelf() -> Control:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(360, 130)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	View3D.fit(box, vp)
	var w := Node3D.new()
	vp.add_child(w)
	Look.apply(w, "studio", Color(0, 0, 0, 0), true)
	var cam := Camera3D.new()
	cam.fov = 30
	w.add_child(cam)
	cam.look_at_from_position(Vector3(0, 0.9, 5.8), Vector3(0, 0.62, 0))
	for i in NORMAL.size():
		var id: String = NORMAL[i]
		var pos := Vector3((i - 3) * 1.0, 0, 0)
		if GameState.seen.has(id):
			var o := Obake3D.new().setup(id)
			o.position = pos
			o.scale = Vector3.ONE * 0.7
			w.add_child(o)
		else:
			var q := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.35
			sm.height = 0.7
			q.mesh = sm
			var m := Obake3D.flat(Color(0.2, 0.15, 0.25, 0.18))
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			q.material_override = m
			q.position = pos + Vector3(0, 0.4, 0)
			w.add_child(q)
	var v := VBoxContainer.new()
	v.add_child(box)
	var names := HBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 0)
	for id in NORMAL:
		var nm: String = tr(GameState.info(id).name) if GameState.seen.has(id) else "？？？"
		for o in GameState.owned:
			if o.id == id:
				nm += "\nLv%d" % o.level
		var l := _text(nm, 10, Color("6a5f70"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(49, 30)
		names.add_child(l)
	v.add_child(names)
	return v


## 庭の段と、仕事の飾り
func _garden_list() -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _pill(Color.WHITE, 16))
	m.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var L: int = GameState.garden_level
	for i in GameState.GARDEN.size():
		var st: Dictionary = GameState.GARDEN[i]
		var done := i <= L
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(_text("●" if done else "○", 12, Color("7fbf6a") if done else Color("c9bfc6")))
		var name_l := _text(tr(st.name) if done else (tr("？？？（めぐみ %d）") % st.need if i == L + 1 else "？？？"), 13, Color("2a2233") if done else Color("9a8e98"), font_black if done else null)
		row.add_child(name_l)
		v.add_child(row)
	v.add_child(_text(tr("めぐみ %d ・ 満月の夜 %d 回 ・ 星見草 %d 輪") % [GameState.growth, GameState.moon_nights, GameState.dream_flowers], 12, Color("6a5f70")))
	v.add_child(_text("仕事の飾り", 13, Color("8a7a88")))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 4)
	for r in ["register", "hall", "dish", "kitchen", "stock"]:
		var lv: int = GameState.deco_level(r)
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", _pill(Color("f3ecff") if lv > 0 else Color("f1ebe4"), 12))
		var t: String = tr(GameState.DECOS[r].name) if lv > 0 else "？？？（%s）" % tr(GameState.ROLE_LABEL[r])
		if lv == 2:
			t += " ★"
		chip.add_child(_text(t, 11, Color("4a3f52") if lv > 0 else Color("a89ea6")))
		flow.add_child(chip)
	if GameState.decos.get("mask", 0) > 0:
		var chip2 := PanelContainer.new()
		chip2.add_theme_stylebox_override("panel", _pill(Color("fff0e0"), 12))
		chip2.add_child(_text("夜店のお面屋", 11, Color("b0643a")))
		flow.add_child(chip2)
	v.add_child(flow)
	return m


## カードの絵。3D で撮った assets/gen/rares3d/<id>.png を優先する（無ければ古い平たい絵）
func _card_texture(id: String) -> Texture2D:
	var path := RareObake3D.art_path(id)
	return load(path) if path != "" else null


func _card(r: Dictionary) -> Control:
	var found: bool = GameState.seen.has(r.id)
	var c1 := Color(r.look.c1)
	var c2 := Color(r.look.c2)
	var p := PanelContainer.new()
	var st := _pill(Color.WHITE if found else Color("ece4da"), 14)
	st.border_color = c2 if found else Color(0, 0, 0, 0)
	st.set_border_width_all(2 if found else 0)
	p.add_theme_stylebox_override("panel", st)
	st.content_margin_left = 6
	st.content_margin_right = 6
	p.custom_minimum_size = Vector2(100, 138)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var tex := _card_texture(r.id)
	var art: Control
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(78, 78)
		if not found:
			tr.modulate = Color(0.1, 0.08, 0.14, 0.55)
		art = tr
	else:
		var dot := Panel.new()
		var ds := StyleBoxFlat.new()
		ds.set_corner_radius_all(36)
		ds.bg_color = c1 if found else Color(0, 0, 0, 0.12)
		ds.border_color = c2
		ds.set_border_width_all(3 if found else 0)
		dot.add_theme_stylebox_override("panel", ds)
		dot.custom_minimum_size = Vector2(72, 72)
		art = dot
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(art)
	v.add_child(center)
	var name_l := _text(r.name if found else "？？？", 13, Color("2a2233") if found else Color("9a8e98"), font_black)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	var hint := _text(r.desc if found else r.hint, 10, Color("7a6f7c"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(84, 0)
	v.add_child(hint)
	# 指を離したときに開く（なぞってスクロールしただけなら開かない）
	p.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				p.set_meta("press_at", e.global_position)
			elif p.has_meta("press_at") and (e.global_position - p.get_meta("press_at")).length() < 14.0:
				p.remove_meta("press_at")
				_show_detail(r))
	return p


func _show_detail(r: Dictionary) -> void:
	Kit.play(self, "open")
	if not GameState.seen.has(r.id):
		GameState.goal("zukan")
	if detail:
		detail.queue_free()
	var found: bool = GameState.seen.has(r.id)
	detail = Control.new()
	detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(detail)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.15, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			detail.queue_free()
			detail = null)
	detail.add_child(dim)
	var p := PanelContainer.new()
	var st := _pill(Color.WHITE, 24)
	st.content_margin_top = 18
	st.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", st)
	p.position = Vector2(30, 110)
	p.size = Vector2(300, 400)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var tex := _card_texture(r.id)
	if tex:
		var tr := TextureRect.new()
		tr.texture = tex
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(220, 220)
		if not found:
			tr.modulate = Color(0.1, 0.08, 0.14, 0.55)
		v.add_child(tr)
	var n := _text(r.name if found else "？？？", 26, Color("2a2233"), font_black)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var g := _text(tr("レア ・ ") + tr(r.group), 13, Color(r.look.c2).darkened(0.2))
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(g)
	var d := _text(tr(r.desc) if found else tr("ヒント：") + tr(r.hint), 15, Color("4a3f52"))
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(d)


func demo_detail() -> void:
	_show_detail(Rares.LIST[3])


func demo_bottom() -> void:
	for c in get_children():
		if c is ScrollContainer:
			c.scroll_vertical = 99999
