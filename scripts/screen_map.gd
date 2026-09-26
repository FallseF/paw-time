extends Control
## 出撃の地図。店（章）ごとの夜が並ぶ。働いた店には「応援」がつく。
## ステージを選ぶと、出てくる困りごとと弱点、今日の応援を見てから出撃する。

var main

var sheet: Control
var list: VBoxContainer
var scroll: ScrollContainer


func _ready() -> void:
	Kit.music("c_calm_loop")
	var bg := ColorRect.new()
	bg.color = Color("f6efe6")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var head := HBoxContainer.new()
	head.position = Vector2(14, 12)
	head.size = Vector2(332, 44)
	head.add_theme_constant_override("separation", 8)
	add_child(head)
	head.add_child(Kit.text("出撃", 26, Kit.INK, true))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", Kit.pill(Color.WHITE, 18, 0.06))
	cp.add_child(Kit.text("まかない %d" % GameState.coins, 13, Color("e8792f"), true))
	head.add_child(cp)
	var back := Kit.button("もどる", Color.WHITE, func(): main.go("room"), Kit.INK, 38, 14)
	back.custom_minimum_size = Vector2(72, 38)
	head.add_child(back)

	if GameState.best_lap > 1:
		var lr := HBoxContainer.new()
		lr.position = Vector2(14, 60)
		lr.size = Vector2(332, 32)
		lr.add_theme_constant_override("separation", 6)
		add_child(lr)
		lr.add_child(Kit.text("混み具合", 13, Kit.SUB, true))
		for l in range(maxi(1, GameState.best_lap - 3), GameState.best_lap + 1):
			var on: bool = l == GameState.lap
			var b := Kit.button("%d周目" % l, Kit.ACCENT if on else Color.WHITE, func():
				GameState.lap = l
				GameState.save_game()
				main.go("map", true), Color.WHITE if on else Kit.INK, 30, 12)
			b.custom_minimum_size = Vector2(64, 30)
			lr.add_child(b)

	var wk := DefData.weekly(GameState.week_no())
	var top := 96.0 if GameState.best_lap > 1 else 62.0
	if not wk.is_empty():
		var wp := PanelContainer.new()
		wp.add_theme_stylebox_override("panel", Kit.pill(Color("2a2233"), 16, 0.1))
		wp.position = Vector2(12, top)
		wp.size = Vector2(336, 0)
		var wv := VBoxContainer.new()
		wv.add_theme_constant_override("separation", 0)
		wv.add_child(Kit.text("%d週目のお題「%s」" % [GameState.week_no(), wk.name], 13, Color("ffd23f"), true))
		wv.add_child(Kit.text(wk.desc, 11, Color.WHITE))
		wp.add_child(wv)
		add_child(wp)
		top += 60.0
	scroll = ScrollContainer.new()
	scroll.position = Vector2(0, top)
	scroll.size = Vector2(360, 640 - top)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(360, 0)
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	var boost_shop := ""
	if not GameState.boost.is_empty():
		boost_shop = DefData.STORE_SHOP.get(GameState.boost.store, "")
	for si in DefData.SHOPS.size():
		list.add_child(_shop_card(si, boost_shop))
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 24)
	list.add_child(pad)
	# いま挑むべき店までスクロール
	var nx := GameState.next_stage()
	await get_tree().process_frame
	await get_tree().process_frame
	if nx[0] > 0:
		var card: Control = list.get_child(nx[0])
		scroll.scroll_vertical = int(card.position.y) - 8
	if GameState.get_meta("open_next", false) or GameState.total_battles == 0:
		GameState.set_meta("open_next", false)
		_open_sheet(nx[0], nx[1])


func _shop_card(si: int, boost_shop: String) -> Control:
	var shop: Dictionary = DefData.shop(si)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	var p := PanelContainer.new()
	var ps := Kit.pill(Color.WHITE, 22, 0.08)
	ps.content_margin_left = 0
	ps.content_margin_right = 0
	ps.content_margin_top = 0
	ps.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", ps)
	m.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	# 見出し帯
	var hb := PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color(shop.color)
	hs.corner_radius_top_left = 22
	hs.corner_radius_top_right = 22
	hs.content_margin_left = 16
	hs.content_margin_right = 12
	hs.content_margin_top = 10
	hs.content_margin_bottom = 10
	hb.add_theme_stylebox_override("panel", hs)
	var bgp := "res://assets/gen/c/bg_%s.png" % shop.id
	if ResourceLoader.exists(bgp):
		var tex: Texture2D = load(bgp)
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(0, tex.get_height() * 0.12, tex.get_width() * 0.62, tex.get_height() * 0.62)
		var st := StyleBoxTexture.new()
		st.texture = at
		st.content_margin_left = 16
		st.content_margin_right = 12
		st.content_margin_top = 44
		st.content_margin_bottom = 8
		st.modulate_color = Color(0.85, 0.85, 0.85)
		hb.add_theme_stylebox_override("panel", st)
	var hr := HBoxContainer.new()
	var nm := Kit.text(shop.name, 18, Color.WHITE, true)
	nm.add_theme_color_override("font_outline_color", Kit.INK)
	nm.add_theme_constant_override("outline_size", 7)
	hr.add_child(nm)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(sp)
	if shop.id == boost_shop:
		var bp := PanelContainer.new()
		bp.add_theme_stylebox_override("panel", Kit.pill(Color.WHITE, 12, 0.0))
		bp.add_child(Kit.text("今日の応援あり", 11, Color(shop.color).darkened(0.3), true))
		hr.add_child(bp)
	hb.add_child(hr)
	v.add_child(hb)
	var open_any := GameState.is_open(si, 0)
	if not open_any:
		var prev: Dictionary = DefData.shop(si - 1)
		var l := Kit.text("  %s を越えるとひらく" % prev.stages[prev.stages.size() - 1].name, 13, Kit.SUB)
		v.add_child(l)
		return m
	for st in shop.stages.size():
		v.add_child(_stage_row(si, st))
	return m


func _stage_row(si: int, st: int) -> Control:
	var stage: Dictionary = DefData.stage(si, st)
	var open := GameState.is_open(si, st)
	var done := GameState.is_cleared(si, st)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 58)
	for k in ["normal", "hover", "pressed", "disabled", "focus"]:
		var s := Kit.pill(Color("fbf6ef") if k != "pressed" else Color("f1e8dc"), 16, 0.0)
		if k == "focus":
			s.bg_color = Color(0, 0, 0, 0)
		b.add_theme_stylebox_override(k, s)
	b.disabled = not open
	var mm := MarginContainer.new()
	mm.add_theme_constant_override("margin_left", 10)
	mm.add_theme_constant_override("margin_right", 10)
	mm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mm.add_child(b)
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12
	row.offset_right = -10
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var num := Kit.text("%d-%d" % [si + 1, st + 1] if not stage.get("boss_stage", false) else "BOSS", 13, Kit.SUB, true)
	num.custom_minimum_size = Vector2(38, 0)
	row.add_child(num)
	var nv := VBoxContainer.new()
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nv.alignment = BoxContainer.ALIGNMENT_CENTER
	nv.add_theme_constant_override("separation", 0)
	nv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nv.add_child(Kit.text(stage.name if open else "？？？", 15, Kit.INK if open else Kit.SUB, true))
	var sub := "まかない%d" % GameState.expected_reward(si, st)
	if done:
		sub = "クリア×%d・" % GameState.clear_count(si, st) + sub
	if stage.get("boss_stage", false) and GameState.weekday() == "金":
		sub = "金曜は1.5倍・" + sub
	var ds := GameState.daily_stage()
	if done and not GameState.daily_done and not ds.is_empty() and ds[0] == si and ds[1] == st:
		sub = "お手伝い+60・" + sub
	nv.add_child(Kit.text(sub, 11, Kit.SUB))
	row.add_child(nv)
	if open:
		var ids := {}
		for s in stage.spawn:
			ids[s[0]] = true
		var n := 0
		for id in ids:
			if n >= (1 if done else 3):
				break
			var tr := TextureRect.new()
			tr.texture = Kit.enemy_tex(id)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.custom_minimum_size = Vector2(30, 30)
			tr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(tr)
			n += 1
	if done:
		var star := Kit.text("★" if GameState.is_perfect(si, st) else "☆", 18, Color("e8a317") if GameState.is_perfect(si, st) else Color("d8cfc6"), true)
		star.tooltip_text = "お店を無傷で守ると★"
		row.add_child(star)
	if open and not done:
		var np := PanelContainer.new()
		np.add_theme_stylebox_override("panel", Kit.pill(Color("ff6b5b"), 10, 0.0))
		np.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		np.mouse_filter = Control.MOUSE_FILTER_IGNORE
		np.add_child(Kit.text("NEW", 10, Color.WHITE, true))
		row.add_child(np)
	b.pressed.connect(func():
		Kit.sfx("c_tap")
		_open_sheet(si, st))
	return mm


func _open_sheet(si: int, st: int) -> void:
	await Kit.make_portraits(GameState.deck.duplicate())
	if sheet:
		sheet.queue_free()
	var shop: Dictionary = DefData.shop(si)
	var stage: Dictionary = DefData.stage(si, st)
	sheet = Control.new()
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(sheet)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.15, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			sheet.queue_free()
			sheet = null)
	sheet.add_child(dim)
	var p := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Kit.CREAM
	ps.corner_radius_top_left = 26
	ps.corner_radius_top_right = 26
	ps.content_margin_left = 18
	ps.content_margin_right = 18
	ps.content_margin_top = 16
	ps.content_margin_bottom = 18
	p.add_theme_stylebox_override("panel", ps)
	p.position = Vector2(0, 640)
	p.size = Vector2(360, 0)
	p.custom_minimum_size = Vector2(360, 0)
	p.clip_contents = true
	sheet.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(Kit.text("%s" % shop.name, 12, Color(shop.color).darkened(0.2), true))
	v.add_child(Kit.text(stage.name, 22, Kit.INK, true))
	var tip := Kit.text(stage.tip, 13, Kit.SUB)
	tip.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	v.add_child(tip)
	var goal := Kit.text(("★ 達成ずみ：お店を無傷で守った" if GameState.is_perfect(si, st) else "★ お店を無傷で守ると、まかない +30%"), 12, Color("e8a317"), true)
	v.add_child(goal)
	# 出てくる困りごと
	var er := HBoxContainer.new()
	er.add_theme_constant_override("separation", 6)
	var ids := {}
	for s in stage.spawn:
		ids[s[0]] = true
	for id in ids:
		var d: Dictionary = DefData.ENEMIES[id]
		var c := VBoxContainer.new()
		c.add_theme_constant_override("separation", 0)
		c.custom_minimum_size = Vector2(60, 0)
		var tr := TextureRect.new()
		tr.texture = Kit.enemy_tex(id)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(52, 44)
		c.add_child(tr)
		var nl := Kit.text(d.name, 9, Kit.INK, true)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		c.add_child(nl)
		var wk := Kit.text(("弱点 " + GameState.ROLE_LABEL[d.weak]) if d.weak != "" else "弱点なし", 9, DefData.job_color(d.weak), true)
		wk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(wk)
		er.add_child(c)
	var es := ScrollContainer.new()
	es.custom_minimum_size = Vector2(324, 86)
	es.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	es.add_child(er)
	v.add_child(es)
	# 今日の応援
	var bst: Dictionary = GameState.battle_boost(shop.id)
	if not bst.lines.is_empty():
		var bp := PanelContainer.new()
		bp.add_theme_stylebox_override("panel", Kit.pill(Color("fff1dc"), 14, 0.0))
		var bv := VBoxContainer.new()
		bv.add_theme_constant_override("separation", 0)
		bv.add_child(Kit.text("今日の応援", 12, Color("e8792f"), true))
		for line in bst.lines:
			var bl := Kit.text("・" + line, 12, Kit.INK)
			bl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			bl.custom_minimum_size = Vector2(270, 0)
			bv.add_child(bl)
		bp.add_child(bv)
		v.add_child(bp)
	else:
		var nb := Kit.text("シフトの日や、よく寝た朝は、応援がつく", 11, Kit.SUB)
		v.add_child(nb)
	# 編成
	var dr := HBoxContainer.new()
	dr.add_theme_constant_override("separation", 4)
	for id in GameState.deck:
		var pic := TextureRect.new()
		pic.texture = Kit.portrait(id)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		pic.custom_minimum_size = Vector2(36, 36)
		dr.add_child(pic)
	var dp := PanelContainer.new()
	dp.add_theme_stylebox_override("panel", Kit.pill(Color.WHITE, 14, 0.0))
	dp.add_child(dr)
	v.add_child(dp)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var b1 := Kit.button("編成・強化", Color.WHITE, func(): main.go("crew"), Kit.INK)
	b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b1)
	var b2 := Kit.button("出撃！", Color("ff6b5b"), func():
		GameState.pending_battle = {"shop": si, "stage": st}
		main.go("defense"))
	b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(b2)
	v.add_child(row)
	await get_tree().process_frame
	var h := p.get_combined_minimum_size().y
	p.create_tween().tween_property(p, "position:y", 640 - h, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Kit.make_portraits(GameState.deck.duplicate())


func demo_open_next() -> void:
	var nx := GameState.next_stage()
	_open_sheet(nx[0], nx[1])
