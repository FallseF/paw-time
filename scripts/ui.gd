class_name UI
## 共通の見た目。パレットは tools/gen_art.py と同じ。

const INK := Color8(46, 34, 47)
const WHITE := Color8(255, 246, 232)
const CREAM := Color8(246, 225, 196)
const SAND := Color8(226, 196, 150)
const ORANGE := Color8(240, 138, 78)
const RED := Color8(214, 78, 72)
const YELLOW := Color8(255, 214, 102)
const NAVY := Color8(38, 46, 90)
const GREEN := Color8(92, 150, 110)
const SKY := Color8(150, 206, 240)
const GRAY := Color8(112, 104, 118)


static func box(bg: Color, border := INK, width := 2, shadow := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	if shadow > 0:
		s.shadow_color = INK
		s.shadow_size = 0
		s.shadow_offset = Vector2(0, shadow)
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 16
	t.set_color("font_color", "Label", INK)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var bg := ORANGE
		if state == "hover":
			bg = Color8(248, 160, 104)
		elif state == "pressed":
			bg = Color8(214, 116, 64)
		elif state == "disabled":
			bg = SAND
		var sb := box(bg, INK, 2, 0 if state == "pressed" else 3)
		if state == "focus":
			sb = box(Color(0, 0, 0, 0), GREEN, 2)
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", WHITE)
	t.set_color("font_hover_color", "Button", WHITE)
	t.set_color("font_pressed_color", "Button", WHITE)
	t.set_color("font_disabled_color", "Button", GRAY)
	t.set_font_size("font_size", "Button", 16)
	t.set_stylebox("panel", "PanelContainer", box(WHITE, INK, 2, 3))
	return t


static func label(text: String, size := 16, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	# 折り返すラベルは横に広がるようにする（横並びの中で幅0になって縦書きに崩れるのを防ぐ）
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func button(text: String, cb: Callable, ghost := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(cb)
	if ghost:
		for state in ["normal", "hover"]:
			b.add_theme_stylebox_override(state, box(WHITE, INK, 2, 3))
		b.add_theme_stylebox_override("pressed", box(CREAM, INK, 2))
		b.add_theme_color_override("font_color", INK)
		b.add_theme_color_override("font_hover_color", INK)
		b.add_theme_color_override("font_pressed_color", INK)
	return b


static func panel(child: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_child(child)
	return p


static func background(name: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load("res://assets/sprites/%s.png" % name)
	t.set_anchors_preset(Control.PRESET_FULL_RECT)
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func icon(path: String, px := 32) -> TextureRect:
	var t := TextureRect.new()
	t.texture = load(path)
	t.custom_minimum_size = Vector2(px, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return t
