extends Control
## ポイ工房。かぶったおばけから出た「かけら」で、ポイを改良したり、特別なポイを作る。
## 相棒（池のほとりで手伝うおばけ）もここで選ぶ。

var main

var font_bold: FontFile
var font_black: FontFile
var col: VBoxContainer
var scroll: ScrollContainer
var partner_vp: SubViewport
var partner_world: Node3D
var partner_node: Obake3D
var sfx: AudioStreamPlayer
var toast: Label

const SHARD_COLOR := {"register": "ffc23d", "dish": "5fc4ff", "hall": "a98bff", "kitchen": "ff7a45", "stock": "e8b878", "rainbow": "ff9ed8"}


func _ready() -> void:
	font_bold = load("res://assets/fonts/ZenMaruGothic-Bold.ttf")
	font_black = load("res://assets/fonts/ZenMaruGothic-Black.ttf")
	var bg := ColorRect.new()
	bg.color = Color("f3e6d6")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var head := HBoxContainer.new()
	head.position = Vector2(16, 14)
	head.size = Vector2(328, 44)
	add_child(head)
	head.add_child(_text("ポイ工房", 26, Color("2a2233"), font_black))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var back := _button("もどる", Color.WHITE, func(): main.go("room"), Color("2a2233"))
	back.custom_minimum_size = Vector2(80, 40)
	head.add_child(back)
	scroll = ScrollContainer.new()
	scroll.position = Vector2(0, 64)
	scroll.size = Vector2(360, 576)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	sfx = AudioStreamPlayer.new()
	add_child(sfx)
	toast = _text("", 15, Color.WHITE, font_black)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var tp := PanelContainer.new()
	tp.add_theme_stylebox_override("panel", _pill(Color(0.16, 0.13, 0.22, 0.92), 18))
	tp.position = Vector2(20, 560)
	tp.size = Vector2(320, 0)
	tp.add_child(toast)
	tp.modulate.a = 0.0
	tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tp)
	GameState.tut["partner"] = true
	_build()


func _build() -> void:
	var y := scroll.scroll_vertical
	if col:
		col.queue_free()
	col = VBoxContainer.new()
	col.custom_minimum_size = Vector2(348, 0)
	col.add_theme_constant_override("separation", 10)
	scroll.add_child(col)
	# かけら
	col.add_child(_section("かけら（かぶったおばけから出る）"))
	var sh := HFlowContainer.new()
	sh.add_theme_constant_override("h_separation", 6)
	sh.add_theme_constant_override("v_separation", 6)
	col.add_child(_margin(sh))
	for k in ["register", "dish", "hall", "kitchen", "stock", "rainbow"]:
		sh.add_child(_shard_chip(k, GameState.shards.get(k, 0)))
	# 改良
	col.add_child(_section("ポイの改良（ずっと効く）"))
	var ukeys := ["fuchi", "wa", "kami"]
	ukeys.sort_custom(func(a, b): return _afford_up(a) and not _afford_up(b))
	for key in ukeys:
		col.add_child(_margin(_upgrade_card(key)))
	# 特別なポイ
	col.add_child(_section("特別なポイ（1本ずつ使い切り）"))
	var ckeys := ["lure", "double", "akari", "paper"]
	ckeys.sort_custom(func(a, b): return GameState.can_pay(GameState.CRAFTS[a]) and not GameState.can_pay(GameState.CRAFTS[b]))
	for pid in ckeys:
		col.add_child(_margin(_craft_card(pid)))
	col.add_child(_section("色のポイ（その色の玉を寄せて、軽くすくえる）"))
	var tkeys := ["bubble", "tray", "receipt", "pan", "box"]
	tkeys.sort_custom(func(a, b): return GameState.can_pay(GameState.CRAFTS[a]) and not GameState.can_pay(GameState.CRAFTS[b]))
	for pid in tkeys:
		col.add_child(_margin(_craft_card(pid)))
	# かざり
	col.add_child(_section("休憩室のかざり（見た目だけ）"))
	var dg := VBoxContainer.new()
	dg.add_theme_constant_override("separation", 6)
	for key in GameState.DECOR_ORDER:
		dg.add_child(_decor_row(key))
	col.add_child(_margin(dg))
	# 相棒
	col.add_child(_section("相棒（池のほとりで手伝う）"))
	col.add_child(_margin(_partner_card()))
	# おすそわけ
	var gift_ids: Array = GameState.NORMAL_IDS.filter(func(i): return GameState.can_gift(i))
	if gift_ids.size() > 0:
		col.add_child(_section("おすそわけ（%sさんへ）" % GameState.gift_target()))
		var gv := HFlowContainer.new()
		gv.add_theme_constant_override("h_separation", 6)
		gv.add_theme_constant_override("v_separation", 6)
		for id in gift_ids:
			var b := _button("%s を1体" % GameState.info(id).name, Color("5fc4a8"), _gift.bind(id))
			b.custom_minimum_size = Vector2(150, 40)
			b.add_theme_font_size_override("font_size", 14)
			gv.add_child(b)
		col.add_child(_margin(gv))
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 40)
	col.add_child(pad)
	await get_tree().process_frame
	scroll.scroll_vertical = y


func _afford_up(key: String) -> bool:
	var lv: int = GameState.upgrades[key]
	return lv < 3 and GameState.can_pay(GameState.UPGRADES[key].cost[lv])


func _pill(bg: Color, radius := 16) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 8
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
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(t: String, bg: Color, cb: Callable, fg := Color.WHITE) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 40)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font_black)
	b.add_theme_font_size_override("font_size", 15)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, _pill(bg if k != "pressed" else bg.darkened(0.1), 20))
	b.add_theme_stylebox_override("disabled", _pill(Color("ddd2c4"), 20))
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Color("8a7e88"))
	b.pressed.connect(cb)
	return b


func _section(t: String) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 18)
	m.add_theme_constant_override("margin_top", 6)
	m.add_child(_text(t, 14, Color("8a7a88")))
	return m


func _margin(c: Control) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_child(c)
	return m


func _shard_chip(k: String, n: int) -> Control:
	var p := PanelContainer.new()
	var st := _pill(Color.WHITE, 14)
	st.content_margin_left = 8
	st.content_margin_right = 10
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", st)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 5)
	p.add_child(h)
	h.add_child(_gem(k))
	h.add_child(_text("%s %d" % [GameState.SHARD_LABEL[k], n], 14, Color("2a2233") if n > 0 else Color("b0a4ae"), font_black))
	return p


func _gem(k: String, size := 14) -> Control:
	var g := Panel.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(SHARD_COLOR[k])
	s.border_color = Color("2a2233")
	s.set_border_width_all(2)
	s.set_corner_radius_all(3)
	g.add_theme_stylebox_override("panel", s)
	g.custom_minimum_size = Vector2(size, size)
	g.rotation = PI / 4
	g.pivot_offset = Vector2(size, size) / 2
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return g


func _cost_row(cost: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	if not GameState.can_pay(cost):
		h.add_child(_text("あと", 12, Color("e85a4f")))
	for k in cost:
		var have: int = GameState.shards.get(k, 0)
		h.add_child(_gem(k, 11))
		if have >= cost[k]:
			h.add_child(_text("%s ✓" % GameState.SHARD_LABEL[k], 13, Color("5fa05a")))
		else:
			h.add_child(_text("%s%d" % [GameState.SHARD_LABEL[k], cost[k] - have], 13, Color("e85a4f")))
	return h


func _upgrade_card(key: String) -> Control:
	var u: Dictionary = GameState.UPGRADES[key]
	var lv: int = GameState.upgrades[key]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _pill(Color.WHITE, 18))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var t := HBoxContainer.new()
	t.add_child(_text(u.name, 16, Color("2a2233"), font_black))
	t.add_child(_text("  改良 %d/3" % lv, 13, Color("ff8a5b")))
	v.add_child(t)
	var d := _text(u.desc, 12, Color("6a5f70"))
	d.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(d)
	if lv < 3:
		v.add_child(_cost_row(u.cost[lv]))
		if GameState.can_pay(u.cost[lv]):
			var b := _button("作る", Color("ff8a5b"), _do_upgrade.bind(key))
			b.custom_minimum_size = Vector2(70, 44)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(b)
	else:
		v.add_child(_text("これ以上は改良できない", 12, Color("8a7a88")))
	return p


func _craft_card(pid: String) -> Control:
	var info: Dictionary = GameState.POI[pid]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _pill(Color.WHITE, 18))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	var dot := Panel.new()
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color(info.color)
	ds.border_color = Color("2a2233")
	ds.set_border_width_all(2)
	ds.set_corner_radius_all(16)
	dot.add_theme_stylebox_override("panel", ds)
	dot.custom_minimum_size = Vector2(32, 32)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var title: String = ("紙のポイの束（3本）" if pid == "paper" else info.name)
	v.add_child(_text("%s ×%d" % [title, GameState.pois.get(pid, 0)], 15, Color("2a2233"), font_black))
	var d := _text("余ったかけらで、今夜すくう数をふやす" if pid == "paper" else info.desc.replace("工房製。", ""), 12, Color("6a5f70"))
	d.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(d)
	v.add_child(_cost_row(GameState.CRAFTS[pid]))
	if GameState.can_pay(GameState.CRAFTS[pid]):
		var b := _button("作る", Color("5b6fc2"), _do_craft.bind(pid))
		b.custom_minimum_size = Vector2(70, 44)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
	return p


func _decor_row(key: String) -> Control:
	var d: Dictionary = GameState.DECOR[key]
	var have: bool = GameState.decor.has(key)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _pill(Color.WHITE if not have else Color("fff6e0"), 16))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_text(d.name, 14, Color("2a2233"), font_black))
	if have:
		v.add_child(_text("休憩室にかざってある", 12, Color("b07a3a")))
	else:
		v.add_child(_cost_row(d.cost))
	h.add_child(v)
	if not have:
		if GameState.can_pay(d.cost):
			var b := _button("かざる", Color("5fb07a"), _do_decor.bind(key))
			b.custom_minimum_size = Vector2(76, 40)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(b)
	return p


func _do_decor(key: String) -> void:
	if GameState.buy_decor(key):
		_play("craft")
		_toast("%sを休憩室にかざった" % GameState.DECOR[key].name)
		_build()


func _partner_card() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _pill(Color.WHITE, 18))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.custom_minimum_size = Vector2(100, 100)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	partner_vp = SubViewport.new()
	partner_vp.own_world_3d = true
	partner_vp.transparent_bg = true
	partner_vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(partner_vp)
	partner_world = Node3D.new()
	partner_vp.add_child(partner_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff1e0")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	partner_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	sun.light_energy = 0.6
	partner_world.add_child(sun)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.9, 3.2)
	cam.fov = 34
	partner_world.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0.55, 0))
	partner_node = Obake3D.make(GameState.partner)
	partner_node.set_level(GameState.level_of(GameState.partner))
	partner_world.add_child(partner_node)
	top.add_child(box)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	var pl := GameState.partner_level()
	tv.add_child(_text("%s  Lv%d" % [GameState.info(GameState.partner).name, pl], 18, Color("2a2233"), font_black))
	var sk := _text(GameState.PARTNER_SKILL[GameState.partner] + "（Lvで強くなる）", 13, Color("6a5f70"))
	sk.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	tv.add_child(sk)
	var o: Dictionary = GameState.owned.get(GameState.partner, {})
	if pl < GameState.MAX_LEVEL and not o.is_empty():
		tv.add_child(_text("次のLvまで %d" % (GameState.xp_to_next(pl) - o.xp), 12, Color("8b7bff")))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	v.add_child(row)
	for id in GameState.NORMAL_IDS:
		if not GameState.owned.has(id):
			continue
		var sel: bool = id == GameState.partner
		var b := _button("%s Lv%d" % [GameState.info(id).name, GameState.level_of(id)], Color("8b7bff") if sel else Color("efe7f7"), _set_partner.bind(id), Color.WHITE if sel else Color("5b4a9e"))
		b.custom_minimum_size = Vector2(96, 36)
		b.add_theme_font_size_override("font_size", 13)
		row.add_child(b)
	return p


func _play(n: String) -> void:
	sfx.stream = load("res://assets/sfx/%s.wav" % n)
	sfx.play()


func _toast(t: String) -> void:
	toast.text = t
	var tp: Control = toast.get_parent()
	tp.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(tp, "modulate:a", 0.0, 0.4)


func _do_upgrade(key: String) -> void:
	if GameState.upgrade(key):
		_play("craft")
		_toast("%s：Lv%d になった" % [GameState.UPGRADES[key].name, GameState.upgrades[key]])
		_build()


func _do_craft(pid: String) -> void:
	if GameState.craft(pid):
		_play("craft")
		_toast("%sができた" % GameState.POI[pid].name)
		_build()


func _set_partner(id: String) -> void:
	GameState.set_partner(id)
	_play("pop")
	_build()


func _gift(id: String) -> void:
	var msg := GameState.gift(id)
	if msg != "":
		_play("chime")
		_toast(msg)
		_build()


func demo_scroll() -> void:
	scroll.scroll_vertical = 3000
