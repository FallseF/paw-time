extends Control
## 寝る前。寝る時刻と起きる時刻を決める（記録モードでは、スマホの睡眠記録（見本）が入る）。
## いつもの時刻に、7〜9時間眠るとリズムが上がる。夜ふかしは夜のおばけを呼ぶが、リズムが下がる。

var main
var bed := 330
var wake := 420
var locked := false
var bed_label: Label
var wake_label: Label
var hours_label: Label
var preview: VBoxContainer
var timeline: Control
var bed_btns: Array = []
var stars: Array = []
var _t := 0.0
var going := false
var show_parts := false
var plan := "usual"
var plan_btns := {}
var go_btn: Button


## 決定ボタンの文言を、選んだ過ごし方に合わせる
func _label_go() -> void:
	if go_btn == null:
		return
	if plan == "extra" and GameState.night_plan != "extra":
		go_btn.text = "もうひと回り、すくいに行く"
	elif plan == "market":
		go_btn.text = "夜店へ"
	else:
		go_btn.text = "おやすみ"

const PLANS := [
	["early", "少し早めに寝る", "いつもより30分早く"],
	["usual", "いつもの時刻に寝る", "リズムがととのう"],
	["extra", "もうひと回り、すくう", "玉が増える・1時間おそく"],
	["market", "夜店をのぞく", "夜のおばけ・夜ふかし"],
]


## ひとりで遊ぶときは、夜の過ごし方を選ぶ（寝る時刻が決まる）
func _build_plans() -> void:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.position = Vector2(20, 106)
	grid.size = Vector2(320, 0)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	add_child(grid)
	var locked_extra := GameState.night_plan == "extra"
	var list := PLANS.duplicate()
	if GameState.mode == "data":
		var r := GameState.recorded_sleep()
		list[0] = ["record", "スマホの記録どおり", "%s に寝て %s に起きた" % [GameState.clock(r.bed), GameState.wake_clock(r.wake)]]
	for p in list:
		var b := Button.new()
		b.custom_minimum_size = Vector2(156, 62)
		b.text = "%s\n%s" % [p[1], p[2]]
		b.add_theme_font_override("font", Kit.bold())
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
		var id: String = p[0]
		b.pressed.connect(func():
			Kit.play(self, "tap", 1.2)
			_choose(id))
		if locked_extra and id != "extra":
			b.disabled = true
		grid.add_child(b)
		plan_btns[id] = b
	_style_plans()


func _style_plans() -> void:
	for id in plan_btns:
		var b: Button = plan_btns[id]
		var on: bool = id == plan
		var c := Color("8b7bff") if on else Color(1, 1, 1, 0.1)
		if id == "market" and on:
			c = Color("d9773a")
		for k in ["normal", "hover", "pressed", "focus", "disabled"]:
			var st := Kit.pill(c, 16, 0.0, Vector2(8, 6))
			if on:
				st.border_color = Color.WHITE
				st.set_border_width_all(2)
			b.add_theme_stylebox_override(k, st)


func _choose(id: String) -> void:
	plan = id
	_style_plans()
	_label_go()
	if id == "record":
		var r := GameState.recorded_sleep()
		_set_time(r.bed, r.wake)
	else:
		wake = GameState.wake_for_tomorrow()
		_set_time(GameState.plan_bed(id), wake)


func _ready() -> void:
	var bg := TextureRect.new()
	var gt := GradientTexture2D.new()
	var g := Gradient.new()
	g.set_color(0, Color("0b1026"))
	g.set_color(1, Color("3a2d5c"))
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	bg.texture = gt
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(bg)
	for i in 50:
		var s := ColorRect.new()
		s.size = Vector2.ONE * randf_range(1.5, 3.0)
		s.position = Vector2(randf() * 360, randf() * 200)
		s.color = Color(1, 1, 1, randf_range(0.3, 0.9))
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(s)
		stars.append([s, randf() * TAU])
	var moon := Panel.new()
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color("fff1c8")
	ms.set_corner_radius_all(20)
	ms.shadow_color = Color(1, 0.95, 0.8, 0.45)
	ms.shadow_size = 14
	moon.add_theme_stylebox_override("panel", ms)
	moon.position = Vector2(306, 10)
	moon.size = Vector2(40, 40)
	add_child(moon)

	var title := Kit.text("おやすみの前に", 24, Color("f3eeff"), true, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(0, 50)
	title.size = Vector2(360, 36)
	add_child(title)
	locked = false
	var note_t := "いつもの時刻は %s ごろ" % GameState.clock(GameState.usual_bed())
	if GameState.mode == "data":
		note_t = "スマホの睡眠記録（見本）がとどいています"
	if not GameState.tut.has("sleep"):
		note_t = "いつもの時刻に 7〜9 時間眠ると、明日の庭が育つ"
	var note := Kit.text(note_t, 12, Color(1, 1, 1, 0.6), false, HORIZONTAL_ALIGNMENT_CENTER)
	note.position = Vector2(0, 86)
	note.size = Vector2(360, 20)
	add_child(note)

	wake = GameState.wake_for_tomorrow()
	plan = GameState.night_plan if GameState.night_plan != "" else ("record" if GameState.mode == "data" else "usual")
	bed = GameState.plan_bed(plan)
	if plan == "record":
		var r := GameState.recorded_sleep()
		bed = r.bed
		wake = r.wake
	_build_plans()

	timeline = Control.new()
	timeline.position = Vector2(24, 250)
	timeline.size = Vector2(312, 46)
	timeline.draw.connect(_draw_timeline)
	add_child(timeline)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.09), 22, 0.0, Vector2(16, 12)))
	card.position = Vector2(24, 306)
	card.size = Vector2(312, 150)
	add_child(card)
	preview = VBoxContainer.new()
	preview.add_theme_constant_override("separation", 5)
	card.add_child(preview)

	var go := Kit.button("おやすみ", Color("8b7bff"), _sleep, Color.WHITE, 54, 20)
	go_btn = go
	go.position = Vector2(40, 560)
	go.size = Vector2(280, 54)
	go.add_theme_font_size_override("font_size", 18)
	add_child(go)
	if not GameState.tut.has("sleep"):
		Kit.nudge.call_deferred(go)
	_label_go()
	_set_time(bed, wake)


func _row(label: String, y: int, cb: Callable) -> Label:
	var row := HBoxContainer.new()
	row.position = Vector2(24, y)
	row.size = Vector2(312, 56)
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	var l := Kit.text(label, 16, Color(1, 1, 1, 0.7))
	l.custom_minimum_size = Vector2(64, 0)
	row.add_child(l)
	var minus := _round("−", func(): cb.call(-1))
	row.add_child(minus)
	var big := Kit.text("", 36, Color.WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	big.custom_minimum_size = Vector2(120, 50)
	row.add_child(big)
	var plus := _round("＋", func(): cb.call(1))
	row.add_child(plus)
	if locked:
		minus.visible = false
		plus.visible = false
	return big


func _round(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(46, 46)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", Kit.black())
	b.add_theme_font_size_override("font_size", 22)
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, Kit.pill(Color(1, 1, 1, 0.16 if k != "pressed" else 0.3), 23, 0.0, Vector2(4, 2)))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.pressed.connect(func():
		Kit.play(self, "tap", 1.2)
		cb.call())
	return b


func _process(delta: float) -> void:
	_t += delta
	for s in stars:
		s[0].modulate.a = 0.5 + 0.5 * sin(_t * 2.0 + s[1])


## 21:00〜11:00 の帯に、眠る時間と「いつもの時刻」を描く
func _draw_timeline() -> void:
	var w := timeline.size.x
	var x0 := 0.0
	var span := 14.0 * 60.0 # 21:00 → 11:00
	var to_x := func(m_from_21: float) -> float: return x0 + clampf(m_from_21 / span, 0, 1) * w
	timeline.draw_rect(Rect2(0, 14, w, 16), Color(1, 1, 1, 0.08))
	# いつもの時刻（±30分）
	var u := GameState.usual_bed() - 180
	var ux: float = to_x.call(u - 30)
	var ux2: float = to_x.call(u + 30)
	timeline.draw_rect(Rect2(ux, 10, ux2 - ux, 24), Color("8fe0a0", 0.35))
	# 眠る時間
	var bx: float = to_x.call(bed - 180)
	var wx: float = to_x.call(wake + 360 - 180)
	var col := Color("9fb4ff") if bed <= GameState.LATE_LINE else Color("ff9a4d")
	timeline.draw_rect(Rect2(bx, 16, wx - bx, 12), col)
	# 1:00 の線
	var lx: float = to_x.call(GameState.LATE_LINE - 180)
	timeline.draw_line(Vector2(lx, 6), Vector2(lx, 38), Color(1, 0.6, 0.4, 0.6), 1.0)
	var f := Kit.bold()
	for m in [0, 180, 360, 540, 720, 840]:
		var x: float = to_x.call(m)
		var lbl := GameState.clock(m + 180)
		timeline.draw_string(f, Vector2(x - 12, 46), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.5))
	timeline.draw_string(f, Vector2(ux, 8), "いつも", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("8fe0a0"))


func _set_time(b: int, w: int) -> void:
	bed = clampi(b, 180, 540) # 21:00〜3:00
	wake = clampi(w, 300, 630) # 5:00〜10:30
	if bed_label:
		bed_label.text = GameState.clock(bed)
		wake_label.text = GameState.wake_clock(wake)
	timeline.queue_redraw()
	for c in preview.get_children():
		c.queue_free()
	var ns := GameState.night_score(bed, wake)
	var h: float = ns.hours
	var head := Kit.text("%s → %s　%s" % [GameState.clock(bed), GameState.wake_clock(wake), GameState.hm(h)], 18, Color.WHITE, true)
	preview.add_child(head)
	var after0 := clampf(GameState.rhythm + ns.score * GameState.RHYTHM_RATE, 0, 100)
	var n0 := GameState.orbs.size()
	var summary := "朝に玉 %d 個 ・ 庭のめぐみ +%d" % [n0, GameState.growth_gain(ns.score, h)] if n0 > 0 else "庭のめぐみ +%d" % GameState.growth_gain(ns.score, h)
	preview.add_child(Kit.text(summary, 15, Color("c8f0c0"), true))
	var diff := int(after0) - int(GameState.rhythm)
	var t0 := 3 if after0 >= 75 else (2 if after0 >= 50 else (1 if after0 >= 25 else 0))
	var rrow := HBoxContainer.new()
	rrow.add_theme_constant_override("separation", 8)
	rrow.add_child(Kit.text("リズム %s%d → %s" % ["+" if diff >= 0 else "", diff, GameState.TIER_NAME[t0]], 15, GameState.TIER_COLOR[t0], true))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rrow.add_child(sp)
	var more := Button.new()
	more.text = "内訳 ▾" if not show_parts else "内訳 ▴"
	more.flat = true
	more.add_theme_font_override("font", Kit.bold())
	more.add_theme_font_size_override("font_size", 12)
	more.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	more.pressed.connect(func():
		show_parts = not show_parts
		_set_time(bed, wake))
	rrow.add_child(more)
	preview.add_child(rrow)
	var parts := HFlowContainer.new()
	parts.visible = show_parts
	parts.add_theme_constant_override("h_separation", 6)
	parts.add_theme_constant_override("v_separation", 4)
	for p in ns.parts:
		var good: bool = p[1] >= 0
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", Kit.pill(Color(0.56, 0.88, 0.63, 0.22) if good else Color(1, 0.5, 0.45, 0.25), 12, 0.0, Vector2(8, 3)))
		pc.add_child(Kit.text("%s %s%d" % [p[0], "+" if good else "", p[1]], 12, Color("d8ffe0") if good else Color("ffd3cc")))
		parts.add_child(pc)
	preview.add_child(parts)
	var t_after := t0
	if ns.late:
		preview.add_child(Kit.wrap(Kit.text("夜ふかし：夜のおばけが寄ってくる。でも庭はしおれる", 13, Color("ffc28a"))))
	elif h >= 7.0 and t_after >= 2:
		preview.add_child(Kit.text("今夜は夢を見そう", 13, Color("c9bdf5")))


func _sleep() -> void:
	if going:
		return
	going = true
	GameState.tut["sleep"] = true
	if not locked and plan == "extra" and GameState.night_plan != "extra":
		# もうひと回り：川べりへ戻る（寝るのは1時間おそく）
		GameState.night_plan = "extra"
		GameState.scooped_tonight = false
		main.go("catch")
		return
	if not locked:
		GameState.night_plan = plan
	if plan == "market":
		_market()
		return
	var dark := ColorRect.new()
	dark.color = Color("05060f")
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.modulate.a = 0.0
	add_child(dark)
	var zz := Kit.text("Z z z …", 40, Color(1, 1, 1, 0.8), true, HORIZONTAL_ALIGNMENT_CENTER)
	zz.position = Vector2(0, 290)
	zz.size = Vector2(360, 60)
	zz.modulate.a = 0.0
	add_child(zz)
	Kit.play(self, "night", 1.0, -4)
	var tw := create_tween()
	tw.tween_property(dark, "modulate:a", 1.0, 0.6)
	tw.parallel().tween_property(zz, "modulate:a", 1.0, 0.6)
	tw.tween_interval(0.9)
	await tw.finished
	GameState.sleep(bed, wake)
	if GameState.dream_pending:
		main.go("dream")
	elif GameState.hatched.size() > 0:
		main.go("hatch")
	else:
		main.go("garden")


## 夜店：チョウチンが寄ってくる（夜ふかしの代わりに）
const STALLS := [
	["ちょうちん屋", "ちょうちんを一つ買う", "チョウチンがもう1体ついてくる"],
	["お面屋", "真顔のお面を見る", "庭にお面の屋台（1回目）／きらきらポイ"],
	["わたあめ屋", "わたあめを買う", "ふしぎな玉が1つ（虹かもしれない）"],
]


## 夜店：屋台をひとつ選ぶ（夜ふかしの代わりのごほうび）
func _market() -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color(0.1, 0.08, 0.2, 0.96), 22, 0.3, Vector2(16, 14)))
	p.position = Vector2(24, 150)
	p.size = Vector2(312, 0)
	add_child(p)
	market_panel = p
	if go_btn:
		go_btn.visible = false
	for id in plan_btns:
		plan_btns[id].disabled = true
	GameState.night_plan = "market"
	GameState.save()
	if GameState.stall_claimed:
		stall_done = true
		var v0 := VBoxContainer.new()
		p.add_child(v0)
		v0.add_child(Kit.text("夜店の帰り道", 20, Color("ffb35c"), true, HORIZONTAL_ALIGNMENT_CENTER))
		market_btn = Kit.button("帰って寝る", Color("8b7bff"), _market_home)
		v0.add_child(market_btn)
		return
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(Kit.text("夜店の灯り", 22, Color("ffb35c"), true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Kit.wrap(Kit.text("たこ焼きの湯気の向こうで、ぼんやり光るおばけが並んでいる。屋台をひとつ、のぞいていく", 13, Color("f3eeff"), false, HORIZONTAL_ALIGNMENT_CENTER)))
	for st in STALLS:
		var b := Button.new()
		b.text = "%s　%s\n%s" % [st[0], st[1], st[2]]
		b.custom_minimum_size = Vector2(0, 56)
		b.add_theme_font_override("font", Kit.bold())
		b.add_theme_font_size_override("font_size", 12)
		for k in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(k, Kit.pill(Color(1, 0.7, 0.36, 0.18 if k != "pressed" else 0.35), 16, 0.0, Vector2(10, 6)))
		b.add_theme_color_override("font_color", Color("fff2dc"))
		b.add_theme_color_override("font_hover_color", Color("fff2dc"))
		var name: String = st[0]
		b.pressed.connect(func(): _stall(name))
		v.add_child(b)
	v.add_child(Kit.text("%s に寝る（リズムは下がる）" % GameState.clock(bed), 12, Color("ffc28a"), false, HORIZONTAL_ALIGNMENT_CENTER))
	Kit.play(self, "bell", 0.7)
	p.pivot_offset = Vector2(156, 120)
	p.scale = Vector2(0.7, 0.7)
	create_tween().tween_property(p, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


var market_panel: PanelContainer
var market_btn: Button
var stall_done := false


func _market_home() -> void:
	if market_btn == null or market_btn.disabled:
		return
	market_btn.disabled = true
	plan = "done_market"
	going = false
	_sleep()


func _stall(name: String) -> void:
	if stall_done:
		return
	stall_done = true
	GameState.stall_claimed = true
	Kit.play(self, "pop", 1.0)
	var msg := ""
	match name:
		"ちょうちん屋":
			GameState.orbs.append({"type": "night", "rare": false})
			msg = "ちょうちんを買ったら、中の子もついてきた"
		"お面屋":
			if GameState.decos.get("mask", 0) == 0:
				GameState.decos["mask"] = 1
				GameState.deco_store["mask"] = "夜店"
				msg = "お面屋ごと、庭についてきた。全部、真顔"
			else:
				GameState.nets["kira"] += 1
				msg = "お面をひとつもらった。きらきらポイ +1"
		"わたあめ屋":
			var rare := randf() < 0.5
			GameState.orbs.append({"type": "rare" if rare else ["register", "dish", "hall", "kitchen", "stock"].pick_random(), "rare": rare})
			msg = "わたあめの中に、光る玉が入っていた" + ("。虹色だ" if rare else "")
	GameState.save()
	for c in market_panel.get_child(0).get_children():
		c.queue_free()
	var v: VBoxContainer = market_panel.get_child(0)
	v.add_child(Kit.text(name, 20, Color("ffb35c"), true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Kit.wrap(Kit.text(msg, 14, Color("f3eeff"), false, HORIZONTAL_ALIGNMENT_CENTER)))
	market_btn = Kit.button("帰って寝る", Color("8b7bff"), _market_home)
	v.add_child(market_btn)


func demo_late() -> void:
	_set_time(450, 450)


func demo_market() -> void:
	_choose("market")
	_sleep()


func demo_stall() -> void:
	_stall("わたあめ屋")


func demo_home() -> void:
	_market_home()


func demo_parts() -> void:
	show_parts = true
	_set_time(bed, wake)
