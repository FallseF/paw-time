extends Control
## 寝る前。何時間寝るかを決める。本番ではスマホの睡眠記録から入る。
## 睡眠で、光る玉の育ち方・明日のポイの破れにくさが決まる。

var main
var hours := 7
var font_bold: FontFile
var font_black: FontFile
var big: Label
var preview: VBoxContainer
var stars: Array = []
var _t := 0.0


func _ready() -> void:
	font_bold = load("res://assets/fonts/ZenMaruGothic-Bold.ttf")
	font_black = load("res://assets/fonts/ZenMaruGothic-Black.ttf")
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
		s.position = Vector2(randf() * 360, randf() * 330)
		s.color = Color(1, 1, 1, randf_range(0.3, 0.9))
		add_child(s)
		stars.append([s, randf() * TAU])
	var moon := Panel.new()
	var ms := StyleBoxFlat.new()
	ms.bg_color = Color("fff1c8")
	ms.set_corner_radius_all(40)
	ms.shadow_color = Color(1, 0.95, 0.8, 0.45)
	ms.shadow_size = 30
	moon.add_theme_stylebox_override("panel", ms)
	moon.position = Vector2(250, 60)
	moon.size = Vector2(80, 80)
	add_child(moon)

	var title := _text("おやすみの前に", 24, Color("f3eeff"), font_black)
	title.position = Vector2(0, 150)
	title.size = Vector2(360, 36)
	add_child(title)
	var note := _text("よく寝た朝は、おばけが育つ", 12, Color(1, 1, 1, 0.55))
	note.position = Vector2(0, 186)
	note.size = Vector2(360, 20)
	add_child(note)

	var row := HBoxContainer.new()
	row.position = Vector2(30, 222)
	row.size = Vector2(300, 110)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	add_child(row)
	row.add_child(_round("−", func(): _set_hours(hours - 1)))
	big = _text("", 64, Color.WHITE, font_black)
	big.custom_minimum_size = Vector2(150, 100)
	row.add_child(big)
	row.add_child(_round("＋", func(): _set_hours(hours + 1)))

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _pill(Color(1, 1, 1, 0.1), 22))
	card.position = Vector2(24, 350)
	card.size = Vector2(312, 150)
	add_child(card)
	preview = VBoxContainer.new()
	preview.add_theme_constant_override("separation", 6)
	card.add_child(preview)

	var go := Button.new()
	go.text = "おやすみ"
	go.position = Vector2(70, 540)
	go.size = Vector2(220, 54)
	go.add_theme_font_override("font", font_black)
	go.add_theme_font_size_override("font_size", 20)
	for k in ["normal", "hover", "pressed"]:
		go.add_theme_stylebox_override(k, _pill(Color("8b7bff"), 27))
	go.add_theme_color_override("font_color", Color.WHITE)
	go.add_theme_color_override("font_hover_color", Color.WHITE)
	go.pressed.connect(_sleep)
	add_child(go)
	_set_hours(hours)


func _process(delta: float) -> void:
	_t += delta
	for s in stars:
		s[0].modulate.a = 0.5 + 0.5 * sin(_t * 2.0 + s[1])


func _pill(bg: Color, radius := 20) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


func _text(t: String, size: int, color := Color.WHITE, font: FontFile = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font if font else font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _round(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(56, 56)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", font_black)
	b.add_theme_font_size_override("font_size", 26)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, _pill(Color(1, 1, 1, 0.16 if k != "pressed" else 0.28), 28))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.pressed.connect(cb)
	return b


func _set_hours(h: int) -> void:
	hours = clampi(h, 4, 9)
	big.text = "%d時間" % hours
	for c in preview.get_children():
		c.queue_free()
	var regen := 1.0 if hours < 6 else (1.1 if hours < 7 else 1.25)
	var n := GameState.orbs.size()
	var lines := []
	if n > 0:
		lines.append("光る玉 %d 個が、朝にかえる" % n)
	lines.append("おばけみんなが育つ（経験 +%d）" % (min(hours, GameState.SLEEP_CAP_H) * 6))
	lines.append("明日のやる気のたまり ×%.2f" % regen)
	if hours >= 9:
		lines.append("8時間より長く寝ても、育ち方は同じ")
	elif hours >= 7:
		lines.append("よく眠ると、レアが生まれやすい")
	elif hours <= 5:
		lines.append("夜ふかしすると、ヨミセが寄ってくる")
	for s in lines:
		var l := _text("・" + s, 14, Color("e8e2ff"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		l.custom_minimum_size = Vector2(270, 0)
		preview.add_child(l)


func _sleep() -> void:
	var dark := ColorRect.new()
	dark.color = Color("05060f")
	dark.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark.modulate.a = 0.0
	add_child(dark)
	var zz := _text("Z z z …", 40, Color(1, 1, 1, 0.8), font_black)
	zz.position = Vector2(0, 290)
	zz.size = Vector2(360, 60)
	zz.modulate.a = 0.0
	add_child(zz)
	var tw := create_tween()
	tw.tween_property(dark, "modulate:a", 1.0, 0.6)
	tw.parallel().tween_property(zz, "modulate:a", 1.0, 0.6)
	tw.tween_interval(0.9)
	await tw.finished
	Kit.music("")
	GameState.sleep(hours, "")
	main.go("hatch" if GameState.hatched.size() > 0 else "morning")
