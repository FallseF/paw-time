extends Control
## 図鑑（コレクション）。ふつうのおばけは 3D の棚、レア 30 体はカード。
## まだ会っていないレアは、影と一文のヒントだけ見せる。

var main

const GROUPS := ["睡眠", "はじめて", "時間帯", "天気", "つながり", "リズム"]
const NORMAL := ["receipt", "bubble", "tray", "pan", "box"]

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
	head.add_child(_text("%d / %d" % [GameState.seen.size(), GameState.ALL.size()], 16, Color("8a5bd6"), font_black))
	var back := Button.new()
	back.text = "もどる"
	back.add_theme_font_override("font", font_bold)
	back.add_theme_font_size_override("font_size", 14)
	for k in ["normal", "hover", "pressed"]:
		back.add_theme_stylebox_override(k, _pill(Color.WHITE, 18))
	back.add_theme_color_override("font_color", Color("2a2233"))
	back.add_theme_color_override("font_hover_color", Color("2a2233"))
	back.pressed.connect(func(): main.go("room"))
	head.add_child(back)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0, 66)
	scroll.size = Vector2(360, 574)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(348, 0)
	col.add_theme_constant_override("separation", 12)
	scroll.add_child(col)

	col.add_child(_records())
	for key in GameState.claimable():
		col.add_child(_claim_row(key))
	col.add_child(_next_milestone())
	col.add_child(_group_head("ふつう", "ふつうのおばけ"))
	col.add_child(_shelf())
	for g in GROUPS:
		col.add_child(_group_head(g, "レア ・ " + g))
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
	s.shadow_color = Color(0, 0, 0, 0.08)
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
	var w := Node3D.new()
	vp.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff1e0")
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	sun.light_energy = 0.6
	w.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.8, 5.0)
	cam.fov = 30
	w.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0.45, 0))
	for i in NORMAL.size():
		var id: String = NORMAL[i]
		var pos := Vector3((i - 2) * 1.05, 0, 0)
		if GameState.seen.has(id):
			var o := Obake3D.new().setup(id)
			o.set_level(GameState.level_of(id))
			o.position = pos
			o.scale = Vector3.ONE * 0.8
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
		var l := _text(("%s\nLv%d" % [GameState.info(id).name, GameState.level_of(id)]) if GameState.seen.has(id) else "？？？", 11, Color("6a5f70"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(66, 18)
		names.add_child(l)
	v.add_child(names)
	return v


func _records() -> Control:
	var r: Dictionary = GameState.records
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _pill(Color("2a2233"), 18))
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	for pair in [["すくった玉", r.total], ["最高コンボ", r.best_combo], ["虹の玉", r.rainbow], ["夜", r.nights]]:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -2)
		var n := _text(str(pair[1]), 20, Color("ffe27a"), font_black)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(n)
		var l := _text(pair[0], 10, Color(1, 1, 1, 0.7))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		h.add_child(v)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 2)
	var tl := _text("称号：" + GameState.title_name(), 15, Color("e8603c"), font_black)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(tl)
	outer.add_child(p)
	var nt := _text(GameState.next_title_text(), 11, Color("9a8e98"))
	nt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(nt)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_child(outer)
	return m


func _claim_row(key: String) -> Control:
	var label: String = ("「%s」をそろえた" % key.substr(2)) if key.begins_with("g:") else ("%s種類に出会った" % key.substr(2))
	var rw: Dictionary = GameState.GROUP_REWARD[key.substr(2)] if key.begins_with("g:") else GameState.milestone_reward(int(key.substr(2)))
	var p := PanelContainer.new()
	var st := _pill(Color("fff3c4"), 18)
	st.border_color = Color("ffb35c")
	st.set_border_width_all(2)
	p.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_text(label, 14, Color("2a2233"), font_black))
	var d := _text(GameState.reward_text(rw), 11, Color("6a5f70"))
	d.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(d)
	h.add_child(v)
	var b := Button.new()
	b.text = "受け取る"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(84, 40)
	b.add_theme_font_override("font", font_black)
	b.add_theme_font_size_override("font_size", 14)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, _pill(Color("ff8a5b"), 20))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		var got := GameState.claim(key)
		if got.is_empty():
			return
		_play("fanfare")
		b.text = "受け取った"
		b.disabled = true
		var tw := create_tween()
		tw.tween_property(p, "modulate", Color(1.2, 1.2, 1.0), 0.15)
		tw.tween_property(p, "modulate", Color(1, 1, 1, 0.6), 0.4))
	h.add_child(b)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_child(p)
	return m


func _next_milestone() -> Control:
	var n: int = GameState.seen.size()
	var next := 0
	for mlt in GameState.MILESTONES:
		if n < mlt:
			next = mlt
			break
	var t := "つぎのごほうびまで あと %d 種類" % (next - n) if next > 0 else "すべての節目のごほうびを受け取った"
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 18)
	m.add_child(_text(t, 12, Color("b07a3a")))
	return m


func _group_head(g: String, title: String) -> Control:
	var pr: Vector2i = GameState.group_progress(g)
	var done := pr.x >= pr.y
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_right", 18)
	m.add_theme_constant_override("margin_top", 8)
	m.add_child(h)
	var medal := Panel.new()
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color("ffc93d") if done else Color(0, 0, 0, 0.08)
	ms.border_color = Color("2a2233") if done else Color(0, 0, 0, 0.15)
	ms.set_border_width_all(2)
	ms.set_corner_radius_all(10)
	medal.add_theme_stylebox_override("panel", ms)
	medal.custom_minimum_size = Vector2(20, 20)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(medal)
	var l := _text(title, 15, Color("2a2233") if done else Color("8a7a88"), font_black if done else null)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	h.add_child(l)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(60, 8)
	bar.max_value = pr.y
	bar.value = pr.x
	bar.show_percentage = false
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.1)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color("ffb35c") if done else Color("8b7bff")
	fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	h.add_child(bar)
	h.add_child(_text("%d/%d" % [pr.x, pr.y], 13, Color("8a7a88")))
	return m


func _play(n: String) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = load("res://assets/sfx/%s.wav" % n)
	add_child(p)
	p.play()


func _card_texture(id: String) -> Texture2D:
	# 図鑑のカードは小さいので、縮小ずみの絵を使う（線がとぎれないように）
	var thumb := "res://assets/gen/rares_thumb/%s.png" % id
	if ResourceLoader.exists(thumb):
		return load(thumb)
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
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(78, 78)
		if not found:
			tr.modulate = Color(0.15, 0.12, 0.2, 0.35)
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
	hint.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	hint.custom_minimum_size = Vector2(84, 0)
	v.add_child(hint)
	p.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_show_detail(r))
	return p


func _show_detail(r: Dictionary) -> void:
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
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(220, 220)
		if not found:
			tr.modulate = Color(0.15, 0.12, 0.2, 0.35)
		v.add_child(tr)
	var n := _text(r.name if found else "？？？", 26, Color("2a2233"), font_black)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	var g := _text("レア ・ " + r.group, 13, Color(r.look.c2).darkened(0.2))
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(g)
	var d := _text(r.desc if found else "ヒント：" + r.hint, 15, Color("4a3f52"))
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(d)
