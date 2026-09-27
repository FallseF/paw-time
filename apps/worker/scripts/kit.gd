class_name Kit
## 新しい画面で使う、丸いフォントとピル型の部品。見た目は休憩室・すくい画面と同じ系統。

static var _bold: FontFile
static var _black: FontFile
static var _sfx := {}
const SETTINGS := "user://settings.cfg"


static func is_en() -> bool:
	return TranslationServer.get_locale().begins_with("en")


## 言語（既定は英語）。タイトルの EN / 日本語 で切りかえ、settings.cfg に残す
static func load_lang() -> void:
	var c := ConfigFile.new()
	var lang := "en"
	if c.load(SETTINGS) == OK:
		lang = c.get_value("ui", "lang", "en")
	if OS.get_environment("OBAKE_LANG") != "":
		lang = OS.get_environment("OBAKE_LANG")
	TranslationServer.set_locale(lang)


static func save_lang(lang: String) -> void:
	var c := ConfigFile.new()
	c.load(SETTINGS)
	c.set_value("ui", "lang", lang)
	c.save(SETTINGS)
	TranslationServer.set_locale(lang)


static func bold() -> FontFile:
	if _bold == null:
		_bold = load("res://assets/fonts/ZenMaruGothic-Bold.ttf")
	return _bold


static func black() -> FontFile:
	if _black == null:
		_black = load("res://assets/fonts/ZenMaruGothic-Black.ttf")
	return _black


static func pill(bg: Color, radius := 20, shadow := 0.14, pad := Vector2(14, 8)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y
	s.content_margin_bottom = pad.y
	if shadow > 0:
		s.shadow_color = Color(0, 0, 0, shadow)
		s.shadow_size = 8
		s.shadow_offset = Vector2(0, 3)
	return s


static func text(t: String, size: int, color := Color("2a2233"), heavy := false, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", black() if heavy else bold())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.horizontal_alignment = align
	return l


static func wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## 中身の大きさが変わるたびに fit を呼ぶ（パネルを縮め直して、置き直す係）。
## 折り返すラベルの高さは、幅が決まったあとのフレームで決まる。Web ではその順番が前後して、
## 「2 フレーム待ってから縮める」だけだと縦に伸びたまま残ることがある。遅れて変わっても、そのつど合わせ直す。
static func keep_fit(content: Control, fit: Callable) -> void:
	var f := func():
		if is_instance_valid(content) and content.is_inside_tree() and not content.is_queued_for_deletion():
			fit.call()
	content.minimum_size_changed.connect(f, CONNECT_DEFERRED)
	f.call_deferred()


static func button(t: String, bg: Color, cb: Callable, fg := Color.WHITE, h := 50, size := 17) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_override("font", black())
	b.add_theme_font_size_override("font_size", size)
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, pill(bg if k != "pressed" else bg.darkened(0.12), h / 2))
	var dis := pill(bg.lerp(Color(0.6, 0.6, 0.6), 0.6), h / 2)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_focus_color", fg)
	b.pressed.connect(func():
		play(b, "tap")
		cb.call())
	return b


## ボタンを「ここを押して」と揺らす（チュートリアル）
static func nudge(c: Control) -> void:
	if not is_instance_valid(c) or not c.is_inside_tree():
		return
	c.pivot_offset = c.size / 2
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "scale", Vector2(1.05, 1.05), 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(c, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)


static func bar(value: float, color: Color, w := 120, h := 10, back := Color(0, 0, 0, 0.12)) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = Vector2(w, h)
	p.show_percentage = false
	p.max_value = 1.0
	p.value = value
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = back
	bg.set_corner_radius_all(h / 2)
	p.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(h / 2)
	p.add_theme_stylebox_override("fill", fill)
	return p


## 効果音。node の子に AudioStreamPlayer を作って鳴らす
static func play(node: Node, name: String, pitch := 1.0, db := 0.0) -> void:
	if node == null or not node.is_inside_tree():
		return
	if not _sfx.has(name):
		var path := "res://assets/sfx/%s.wav" % name
		if not ResourceLoader.exists(path):
			return
		_sfx[name] = load(path)
	var p := AudioStreamPlayer.new()
	p.stream = _sfx[name]
	p.pitch_scale = pitch
	p.volume_db = db
	p.autoplay = true
	p.finished.connect(p.queue_free)
	node.get_tree().root.add_child.call_deferred(p)


static func glow(c: Color, e: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = e
	return m


static func label3d(t: String, size := 48, color := Color.WHITE) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font = black()
	l.font_size = size
	l.pixel_size = 0.004
	l.modulate = color
	l.outline_size = 10
	l.outline_modulate = Color(0.1, 0.08, 0.15, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	return l


## カメラを少し揺らす（ここぞという時だけ）
static func shake(cam: Camera3D, amp := 0.08, dur := 0.35) -> void:
	var tw := cam.create_tween()
	var n := int(dur / 0.04)
	for i in n:
		var k := 1.0 - float(i) / n
		tw.tween_property(cam, "h_offset", randf_range(-amp, amp) * k, 0.04)
	tw.tween_property(cam, "h_offset", 0.0, 0.04)
