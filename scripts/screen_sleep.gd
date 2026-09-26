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
	ms.set_corner_radius_all(30)
	ms.shadow_color = Color(1, 0.95, 0.8, 0.45)
	ms.shadow_size = 24
	moon.add_theme_stylebox_override("panel", ms)
	moon.position = Vector2(270, 40)
	moon.size = Vector2(60, 60)
	add_child(moon)

	var title := Kit.text("おやすみの前に", 24, Color("f3eeff"), true, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(0, 50)
	title.size = Vector2(360, 36)
	add_child(title)
	locked = GameState.mode == "data"
	var note_t := "スマホの睡眠記録（見本）から入ります" if locked else "いつもの時刻は %s ごろ" % GameState.clock(GameState.usual_bed())
	var note := Kit.text(note_t, 12, Color(1, 1, 1, 0.6), false, HORIZONTAL_ALIGNMENT_CENTER)
	note.position = Vector2(0, 86)
	note.size = Vector2(360, 20)
	add_child(note)

	if locked:
		var r := GameState.recorded_sleep()
		bed = r.bed
		wake = r.wake
	else:
		bed = GameState.usual_bed()
		wake = 420

	bed_label = _row("寝る", 118, func(d): _set_time(bed + d * 30, wake))
	wake_label = _row("起きる", 180, func(d): _set_time(bed, wake + d * 30))

	timeline = Control.new()
	timeline.position = Vector2(24, 250)
	timeline.size = Vector2(312, 46)
	timeline.draw.connect(_draw_timeline)
	add_child(timeline)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.09), 22, 0.0, Vector2(16, 12)))
	card.position = Vector2(24, 306)
	card.size = Vector2(312, 220)
	add_child(card)
	preview = VBoxContainer.new()
	preview.add_theme_constant_override("separation", 5)
	card.add_child(preview)

	var go := Kit.button("おやすみ", Color("8b7bff"), _sleep, Color.WHITE, 54, 20)
	go.position = Vector2(70, 560)
	go.size = Vector2(220, 54)
	add_child(go)
	if not GameState.tut.has("sleep"):
		Kit.nudge.call_deferred(go)
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
	bed_label.text = GameState.clock(bed)
	wake_label.text = GameState.wake_clock(wake)
	timeline.queue_redraw()
	for c in preview.get_children():
		c.queue_free()
	var ns := GameState.night_score(bed, wake)
	var h: float = ns.hours
	var head := Kit.text("%.1f時間の眠り" % h, 18, Color.WHITE, true)
	preview.add_child(head)
	var parts := HFlowContainer.new()
	parts.add_theme_constant_override("h_separation", 6)
	parts.add_theme_constant_override("v_separation", 4)
	for p in ns.parts:
		var good: bool = p[1] >= 0
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", Kit.pill(Color(0.56, 0.88, 0.63, 0.22) if good else Color(1, 0.5, 0.45, 0.25), 12, 0.0, Vector2(8, 3)))
		pc.add_child(Kit.text("%s %s%d" % [p[0], "+" if good else "", p[1]], 12, Color("d8ffe0") if good else Color("ffd3cc")))
		parts.add_child(pc)
	preview.add_child(parts)
	var after := clampf(GameState.rhythm + ns.score, 0, 100)
	var t_after := 3 if after >= 75 else (2 if after >= 50 else (1 if after >= 25 else 0))
	preview.add_child(Kit.text("リズム %d → %d（%s）" % [int(GameState.rhythm), int(after), GameState.TIER_NAME[t_after]], 14, GameState.TIER_COLOR[t_after]))
	preview.add_child(Kit.text("明日の庭のめぐみ ＋%d くらい" % GameState.growth_gain(ns.score, h), 14, Color("c8f0c0")))
	var n := GameState.orbs.size()
	if n > 0:
		preview.add_child(Kit.text("光る玉 %d 個が、朝にかえる" % n, 13, Color("e8e2ff")))
	if ns.late:
		preview.add_child(Kit.wrap(Kit.text("夜ふかし：夜のおばけが寄ってくる。でも庭はしおれる", 13, Color("ffc28a"))))
	elif h >= 7.0 and t_after >= 2:
		preview.add_child(Kit.text("夢を見そう（羊をかぞえる夢）", 13, Color("c9bdf5")))


func _sleep() -> void:
	if going:
		return
	going = true
	GameState.tut["sleep"] = true
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


func demo_late() -> void:
	_set_time(450, 450)
