extends Control
## 編成と強化。出撃するおばけ（最大7体）を選び、まかないで Lv を上げる。
## 寝ているあいだにたまった経験値のぶん、強化は安くなる。

var main

var deck_row: HBoxContainer
var list: VBoxContainer
var coin_l: Label
var scroll: ScrollContainer


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("f6efe6")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var head := HBoxContainer.new()
	head.position = Vector2(14, 12)
	head.size = Vector2(332, 44)
	head.add_theme_constant_override("separation", 8)
	add_child(head)
	head.add_child(Kit.text("編成・強化", 24, Kit.INK, true))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", Kit.pill(Color.WHITE, 18, 0.06))
	coin_l = Kit.text("", 13, Color("e8792f"), true)
	cp.add_child(coin_l)
	head.add_child(cp)
	var back := Kit.button("もどる", Color.WHITE, func(): main.go("map"), Kit.INK, 38, 14)
	back.custom_minimum_size = Vector2(72, 38)
	head.add_child(back)

	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", Kit.pill(Color.WHITE, 18, 0.06))
	dp.position = Vector2(12, 62)
	dp.size = Vector2(336, 78)
	add_child(dp)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 2)
	dp.add_child(dv)
	dv.add_child(Kit.text("店に出るおばけ（%d体まで）" % GameState.DECK_MAX, 11, Kit.SUB, true))
	deck_row = HBoxContainer.new()
	deck_row.add_theme_constant_override("separation", 2)
	dv.add_child(deck_row)

	scroll = ScrollContainer.new()
	scroll.position = Vector2(0, 148)
	scroll.size = Vector2(360, 492)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(360, 0)
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var ids: Array = []
	for o in GameState.owned:
		if not DefData.unit(o.id).is_empty():
			ids.append(o.id)
	await Kit.make_portraits(ids)
	_render()


func _render() -> void:
	coin_l.text = "まかない %d" % GameState.coins
	for c in deck_row.get_children():
		c.queue_free()
	for i in GameState.DECK_MAX:
		var slot := PanelContainer.new()
		var s := Kit.pill(Color("f6efe6"), 10, 0.0)
		s.content_margin_left = 2
		s.content_margin_right = 2
		s.content_margin_top = 2
		s.content_margin_bottom = 2
		slot.add_theme_stylebox_override("panel", s)
		slot.custom_minimum_size = Vector2(40, 40)
		if i < GameState.deck.size():
			var pic := TextureRect.new()
			pic.texture = Kit.portrait(GameState.deck[i])
			pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pic.custom_minimum_size = Vector2(36, 36)
			slot.add_child(pic)
		deck_row.add_child(slot)
	var y := scroll.scroll_vertical
	for c in list.get_children():
		c.queue_free()
	for o in GameState.owned:
		if DefData.unit(o.id).is_empty():
			continue
		list.add_child(_card(o))
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 20)
	list.add_child(pad)
	await get_tree().process_frame
	scroll.scroll_vertical = y


func _card(o: Dictionary) -> Control:
	var id: String = o.id
	var u: Dictionary = DefData.unit(id)
	var rare := Rares.is_rare(id)
	var job: String = u.get("job", "")
	var in_deck: bool = id in GameState.deck
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	var p := PanelContainer.new()
	var ps := Kit.pill(Color.WHITE, 18, 0.06)
	if in_deck:
		ps.border_color = DefData.job_color(job) if not rare else Color("ff8fb1")
		ps.set_border_width_all(3)
	p.add_theme_stylebox_override("panel", ps)
	m.add_child(p)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	var pic := TextureRect.new()
	pic.texture = Kit.portrait(id)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(64, 64)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 1)
	row.add_child(v)
	var nr := HBoxContainer.new()
	nr.add_theme_constant_override("separation", 6)
	nr.add_child(Kit.text(GameState.info(id).name, 16, Kit.INK, true))
	var tag := PanelContainer.new()
	var ts := Kit.pill(DefData.job_color(job) if not rare else Color("ff8fb1"), 8, 0.0)
	ts.content_margin_left = 6
	ts.content_margin_right = 6
	ts.content_margin_top = 1
	ts.content_margin_bottom = 1
	tag.add_theme_stylebox_override("panel", ts)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tag_text: String = ("レア" if rare else GameState.ROLE_LABEL[job])
	tag.add_child(Kit.text(tag_text, 10, Color.WHITE, true))
	nr.add_child(tag)
	var is_focus: bool = GameState.focus == id
	var fb := Button.new()
	fb.text = "★育てる" if is_focus else "☆"
	fb.flat = true
	fb.tooltip_text = "育てたい一体：その日の最初の勝ちで経験 +%d" % GameState.FOCUS_XP
	fb.add_theme_font_override("font", Kit.font_black)
	fb.add_theme_font_size_override("font_size", 12)
	fb.add_theme_color_override("font_color", Color("e8792f") if is_focus else Color("c9bcc8"))
	fb.pressed.connect(func():
		GameState.focus = "" if is_focus else id
		GameState.save_game()
		Kit.sfx("c_tap")
		_render())
	nr.add_child(fb)
	v.add_child(nr)
	var mult := DefData.unit_mult(o.level) * (0.8 if rare else 1.0)
	if o.level >= DefData.VETERAN_LV:
		nr.add_child(Kit.text("ベテラン", 11, Color("e8792f"), true))
	var wk: Dictionary = ShopData.worker(id)
	v.add_child(Kit.text("Lv%d　速さ %.1f　スタミナ %d秒" % [o.level, wk.rate * DefData.unit_mult(o.level), int(wk.stamina * (1.0 + 0.08 * (o.level - 1)))], 11, Kit.SUB))
	var line := Kit.text(ShopData.HELP_TEXT.get(ShopData.help_of(id), "") if rare else ShopData.worker(id).line, 11, Kit.INK)
	line.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(line)
	var xr := HBoxContainer.new()
	xr.add_theme_constant_override("separation", 6)
	var need := DefData.xp_need(o.level)
	var xb := Kit.bar(float(o.xp) / need, Color("8b7bff"), Color(0, 0, 0, 0.08), 6)
	xb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xr.add_child(xb)
	var xt := "寝て育った %d/%d" % [o.xp, need]
	if o.level < DefData.VETERAN_LV:
		xt += "　Lv%dでベテラン" % DefData.VETERAN_LV
	xr.add_child(Kit.text(xt, 9, Color("8b7bff")))
	v.add_child(xr)
	var br := HBoxContainer.new()
	br.add_theme_constant_override("separation", 6)
	var full: bool = not in_deck and GameState.deck.size() >= GameState.DECK_MAX
	var last: String = GameState.deck[GameState.deck.size() - 1] if not GameState.deck.is_empty() else ""
	var label := "外す" if in_deck else ("%sと入れかえ" % GameState.info(last).name if full else "編成に入れる")
	var tb := Kit.button(label, Color("efe6f5") if in_deck else Color("ff8a5b"), func():
		if full:
			GameState.toggle_deck(last)
		if GameState.toggle_deck(id):
			_render()
		else:
			Kit.sfx("c_deny"), Kit.INK if in_deck else Color.WHITE, 32, 12)
	tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	br.add_child(tb)
	var cost := GameState.upgrade_cost(id)
	var ub := Kit.button(("強化 %d" % cost) if cost >= 0 else "Lv MAX", Color("8b7bff"), func():
		if GameState.upgrade(id):
			Kit.sfx("c_levelup")
			_render()
		else:
			Kit.sfx("c_deny"), Color.WHITE, 32, 12)
	ub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ub.disabled = cost < 0 or GameState.coins < cost
	br.add_child(ub)
	v.add_child(br)
	return m
