extends Control
## マイおばけ猫 診断。はじめに → 12 問（1 問 1 画面・2 択）→ 光る玉が割れて、相棒の猫おばけが現れる。
## 結果は GameState.set_my_obake() で保存し、「この子と はじめる」で next_screen へ進む。
## 別の版に組み込むときは docs/quiz_integration.md を参照。
## 確認用: OBAKE_QUIZ_AUTO=ABBA… で、その答えを自動で選ぶ（12 個そろえば結果まで進む）。

signal finished(result: Dictionary)

var main
## 「この子と はじめる」を押したあとに main.go() する画面の名前
var next_screen := "morning"

const NIGHT := Color("2a2233")
const PAPER := Color(1, 0.99, 0.97, 0.97)
const INK := Color("2a2233")
const SUB := Color("6a5f70")
const GOLD := Color("ffe27a")
const LILAC := Color("cfc3ee")
const ORB_COL := Color("ffd84d")

var font_bold: FontFile
var font_black: FontFile
var vp: SubViewport
var world: Node3D
var cam: Camera3D
var env: Environment
var orb: OrbModel
var burst: CPUParticles3D
var obake: MyObake3D
var shadow: MeshInstance3D
var sfx := {}

var layer_intro: Control
var layer_q: Control
var layer_reveal: Control
var dots: Array[Panel] = []
var q_box: Control
var q_num: Label
var q_text: Label
var answer_btns: Array[Button] = []
var answer_labels: Array[Label] = []
var back_btn: Button
var flash: ColorRect
var share_sheet: Control
var share_status: Label

var answers := ""
var index := 0
var busy := false
var result := {}
var card_image: Image


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	font_bold = load("res://assets/fonts/ZenMaruGothic-Bold.ttf")
	font_black = load("res://assets/fonts/ZenMaruGothic-Black.ttf")
	_build_world()
	_build_intro()
	_build_questions()
	_build_reveal()
	flash = ColorRect.new()
	flash.color = Color("fff8e6")
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate.a = 0.0
	add_child(flash)
	for n in ["hatch", "sparkle", "chime", "lift"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/sfx/%s.wav" % n)
		p.volume_db = -6.0
		add_child(p)
		sfx[n] = p
	_show_layer(layer_intro)
	var auto := OS.get_environment("OBAKE_QUIZ_AUTO").strip_edges().to_upper()
	if auto != "":
		_auto_answer.call_deferred(auto)


# ---------------------------------------------------------------- 3D

func _build_world() -> void:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)

	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = NIGHT
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9a8b8")
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_color = Color("fff0dc")
	sun.light_energy = 0.75
	world.add_child(sun)

	cam = Camera3D.new()
	cam.fov = 40
	cam.position = Vector3(0, 0.9, 3.4)
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.7, 0))

	# 夜の空気に漂う、小さな光の粒
	var dust := CPUParticles3D.new()
	dust.amount = 26
	dust.lifetime = 6.0
	dust.preprocess = 6.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(1.6, 1.6, 0.6)
	dust.position = Vector3(0, 1.0, -0.4)
	dust.gravity = Vector3(0, 0.03, 0)
	dust.initial_velocity_min = 0.0
	dust.initial_velocity_max = 0.04
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.2
	var dm := SphereMesh.new()
	dm.radius = 0.012
	dm.height = 0.024
	dust.mesh = dm
	var dmat := StandardMaterial3D.new()
	dmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dmat.albedo_color = Color("fff2a8")
	dmat.emission_enabled = true
	dmat.emission = Color("fff2a8")
	dmat.emission_energy_multiplier = 2.0
	dust.material_override = dmat
	world.add_child(dust)

	orb = OrbModel.new().setup(ORB_COL, false, 0.34)
	orb.position = Vector3(0, 1.2, 0)
	orb.set_energy(0.8)
	world.add_child(orb)

	burst = CPUParticles3D.new()
	burst.emitting = false
	burst.one_shot = true
	burst.amount = 70
	burst.lifetime = 1.4
	burst.explosiveness = 1.0
	burst.spread = 180
	burst.initial_velocity_min = 1.2
	burst.initial_velocity_max = 3.0
	burst.gravity = Vector3(0, -1.4, 0)
	var bm := SphereMesh.new()
	bm.radius = 0.03
	bm.height = 0.06
	burst.mesh = bm
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color("fff2a8")
	gm.emission_enabled = true
	gm.emission = Color("fff2a8")
	gm.emission_energy_multiplier = 3.0
	burst.material_override = gm
	world.add_child(burst)


func _process(_delta: float) -> void:
	if orb and is_instance_valid(orb) and not busy:
		orb.position.y = _orb_home().y + sin(Time.get_ticks_msec() * 0.002) * 0.04


func _orb_home() -> Vector3:
	return Vector3(0, 1.28, 0) if layer_intro.visible else Vector3(0, 1.62, 0)


# ---------------------------------------------------------------- UI の部品（screen_room と同じ作法）

func _pill(bg: Color, radius := 20) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	s.shadow_color = Color(0, 0, 0, 0.14)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	return s


func _text(t: String, size: int, color := INK, font: FontFile = null, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font if font else font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(t: String, bg: Color, cb: Callable, fg := Color.WHITE, h := 50) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_override("font", font_black)
	b.add_theme_font_size_override("font_size", 17)
	for k in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(k, _pill(bg if k != "pressed" else bg.darkened(0.1), 25))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(k, fg)
	b.pressed.connect(cb)
	return b


## 文字だけの控えめなボタン（二番手の操作）
func _link(t: String, color: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_override("font", font_bold)
	b.add_theme_font_size_override("font_size", 15)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, color)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	return b


func _layer() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	return c


func _show_layer(l: Control) -> void:
	for x in [layer_intro, layer_q, layer_reveal]:
		x.visible = x == l


# ---------------------------------------------------------------- はじめに

func _build_intro() -> void:
	layer_intro = _layer()
	var logo := _text("Paw Time", 18, GOLD, font_black)
	logo.position = Vector2(0, 26)
	logo.size = Vector2(360, 28)
	layer_intro.add_child(logo)
	var v := VBoxContainer.new()
	v.position = Vector2(16, 352)
	v.size = Vector2(328, 0)
	v.add_theme_constant_override("separation", 10)
	layer_intro.add_child(v)
	v.add_child(_text("マイおばけ猫 診断", 14, LILAC))
	v.add_child(_text("あなたのおばけ猫を\nさがそう", 26, Color("fff6e8"), font_black))
	var sub := _text("12の質問で、相棒の猫おばけが決まる。\nバイトと休みの、ゆるい質問だよ。", 14, LILAC)
	v.add_child(sub)
	var start := _button("はじめる", Color("ff8a5b"), _start)
	start.position = Vector2(40, 552)
	start.size = Vector2(280, 54)
	layer_intro.add_child(start)
	var note := _text("1分くらい ・ 答えはあとで変えられる", 12, Color(0.81, 0.76, 0.93, 0.7))
	note.position = Vector2(0, 610)
	note.size = Vector2(360, 20)
	layer_intro.add_child(note)


func _start() -> void:
	if busy:
		return
	sfx["lift"].play()
	answers = ""
	index = 0
	_show_layer(layer_q)
	_render_question(false)
	var tw := create_tween()
	tw.tween_property(orb, "scale", Vector3.ONE * 0.62, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- 質問

func _build_questions() -> void:
	layer_q = _layer()
	# 進み具合の点
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.position = Vector2(0, 24)
	row.size = Vector2(360, 16)
	layer_q.add_child(row)
	for i in QuizData.QUESTIONS.size():
		var d := Panel.new()
		d.custom_minimum_size = Vector2(12, 12)
		d.pivot_offset = Vector2(6, 6)
		d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(d)
		dots.append(d)

	q_box = Control.new()
	q_box.position = Vector2(0, 0)
	q_box.size = Vector2(360, 640)
	q_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer_q.add_child(q_box)
	q_num = _text("", 14, GOLD, font_black)
	q_num.position = Vector2(0, 224)
	q_num.size = Vector2(360, 22)
	q_box.add_child(q_num)
	q_text = _text("", 22, Color("fff6e8"), font_black)
	q_text.position = Vector2(16, 250)
	q_text.size = Vector2(328, 64)
	q_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	q_box.add_child(q_text)
	for i in 2:
		var b := Button.new()
		b.position = Vector2(16, 334 + i * 108)
		b.size = Vector2(328, 96)
		b.pivot_offset = b.size / 2
		for k in ["normal", "hover", "pressed", "focus", "disabled"]:
			var s := _pill(PAPER if k != "pressed" else Color("fff1d6"), 24)
			if k == "hover":
				s.bg_color = Color("fffaf0")
			b.add_theme_stylebox_override(k, s)
		b.pressed.connect(_answer.bind("A" if i == 0 else "B"))
		q_box.add_child(b)
		answer_btns.append(b)
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 18
		h.offset_right = -18
		h.add_theme_constant_override("separation", 14)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		var chip := PanelContainer.new()
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color("ff8a5b") if i == 0 else Color("8b7bff")
		cs.set_corner_radius_all(18)
		chip.add_theme_stylebox_override("panel", cs)
		chip.custom_minimum_size = Vector2(36, 36)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(_text("A" if i == 0 else "B", 17, Color.WHITE, font_black))
		h.add_child(chip)
		var l := _text("", 20, INK, font_black, HORIZONTAL_ALIGNMENT_LEFT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		answer_labels.append(l)
	back_btn = _link("ひとつ戻る", Color(0.81, 0.76, 0.93, 0.85), _back)
	back_btn.position = Vector2(120, 580)
	back_btn.size = Vector2(120, 40)
	layer_q.add_child(back_btn)


func _render_question(animate := true) -> void:
	var q: Dictionary = QuizData.QUESTIONS[index]
	q_num.text = "Q%d" % (index + 1)
	q_text.text = q.q
	answer_labels[0].text = q.a
	answer_labels[1].text = q.b
	back_btn.visible = index > 0
	for b in answer_btns:
		b.disabled = false
		b.scale = Vector2.ONE
		b.modulate.a = 1.0
	_render_dots()
	if animate:
		q_box.position.x = 36
		q_box.modulate.a = 0.0
		var tw := create_tween().set_parallel()
		tw.tween_property(q_box, "position:x", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(q_box, "modulate:a", 1.0, 0.2)


func _render_dots() -> void:
	for i in dots.size():
		var s := StyleBoxFlat.new()
		s.set_corner_radius_all(6)
		if i < index:
			s.bg_color = GOLD
		elif i == index:
			s.bg_color = Color("fff6e8")
			s.border_color = GOLD
			s.set_border_width_all(2)
		else:
			s.bg_color = Color(1, 1, 1, 0.18)
		dots[i].add_theme_stylebox_override("panel", s)
		dots[i].scale = Vector2.ONE * (1.25 if i == index else 1.0)


func _answer(choice: String, fast := false) -> void:
	if busy or index >= QuizData.QUESTIONS.size():
		return
	answers += choice
	if fast:
		index += 1
		if index < QuizData.QUESTIONS.size():
			_render_question(false)
		return
	busy = true
	for b in answer_btns:
		b.disabled = true
	var picked := answer_btns[0 if choice == "A" else 1]
	var other := answer_btns[1 if choice == "A" else 0]
	sfx["sparkle"].pitch_scale = 0.9 + index * 0.04
	sfx["sparkle"].play()
	Input.vibrate_handheld(15)
	# 選んだカードがぷくっと膨らみ、もう一方は引っ込む。点がひとつ灯り、玉が少し明るくなる。
	var dot := dots[index]
	var tw := create_tween().set_parallel()
	tw.tween_property(picked, "scale", Vector2.ONE * 1.05, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(other, "modulate:a", 0.25, 0.15)
	tw.tween_property(dot, "scale", Vector2.ONE * 1.8, 0.12)
	tw.tween_property(orb, "scale", Vector3.ONE * 0.72, 0.12)
	await tw.finished
	index += 1
	orb.set_energy(0.8 + index * 0.12)
	_render_dots()
	dots[index - 1].scale = Vector2.ONE * 1.8
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(dots[index - 1], "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_property(orb, "scale", Vector3.ONE * 0.62, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw2.tween_property(q_box, "position:x", -36.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw2.tween_property(q_box, "modulate:a", 0.0, 0.16)
	await tw2.finished
	busy = false
	if index >= QuizData.QUESTIONS.size():
		_reveal()
	else:
		_render_question()


func _back() -> void:
	if busy or index == 0:
		return
	index -= 1
	answers = answers.left(index)
	orb.set_energy(0.8 + index * 0.12)
	_render_question()


func _auto_answer(auto: String) -> void:
	var picks := auto.replace(" ", "").left(QuizData.QUESTIONS.size())
	_start()
	for c in picks:
		_answer("A" if c == "A" else "B", true)
	if answers.length() >= QuizData.QUESTIONS.size():
		_reveal()


# ---------------------------------------------------------------- 結果

var reveal_card: PanelContainer
var r_name: Label
var r_line: Label
var r_en: Label
var r_job: Label
var r_match: Label
var r_axes: GridContainer
var r_buttons: VBoxContainer
var r_kicker: Label


func _build_reveal() -> void:
	layer_reveal = _layer()
	r_kicker = _text("あなたのマイおばけ猫は", 14, SUB)
	r_kicker.position = Vector2(0, 18)
	r_kicker.size = Vector2(360, 24)
	layer_reveal.add_child(r_kicker)

	reveal_card = PanelContainer.new()
	reveal_card.add_theme_stylebox_override("panel", _pill(PAPER, 24))
	reveal_card.position = Vector2(16, 262)
	reveal_card.size = Vector2(328, 0)
	layer_reveal.add_child(reveal_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	reveal_card.add_child(v)
	r_name = _text("", 24, INK, font_black)
	v.add_child(r_name)
	r_en = _text("", 12, SUB)
	v.add_child(r_en)
	r_line = _text("", 15, INK)
	v.add_child(r_line)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 4)
	v.add_child(sp)
	r_axes = GridContainer.new()
	r_axes.columns = 2
	r_axes.add_theme_constant_override("h_separation", 16)
	r_axes.add_theme_constant_override("v_separation", 8)
	v.add_child(r_axes)
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 4)
	v.add_child(sp2)
	r_job = _text("", 13, SUB, null, HORIZONTAL_ALIGNMENT_LEFT)
	v.add_child(r_job)
	r_match = _text("", 13, SUB, null, HORIZONTAL_ALIGNMENT_LEFT)
	v.add_child(r_match)

	r_buttons = VBoxContainer.new()
	r_buttons.position = Vector2(16, 530)
	r_buttons.size = Vector2(328, 0)
	r_buttons.add_theme_constant_override("separation", 2)
	layer_reveal.add_child(r_buttons)
	r_buttons.add_child(_button("この子と はじめる", Color("ff8a5b"), _begin))
	r_buttons.add_child(_link("結果をシェア", Color("8a5bd6"), open_share))


func _reveal() -> void:
	if busy:
		return
	busy = true
	result = QuizData.score(answers)
	var t: Dictionary = QuizData.TYPES[result.type_id]
	var col := Color(t.look.color)
	_show_layer(null)
	# 玉が真ん中に降りて、持ち主の色に染まりながら震える
	var tw := create_tween().set_parallel()
	tw.tween_property(orb, "position", Vector3(0, 1.1, 0.2), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(orb, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(k: float): _tint_orb(ORB_COL.lerp(col, k)), 0.0, 1.0, 0.9)
	await tw.finished
	for i in 3:
		var amp := 0.03 + i * 0.03
		var tw2 := create_tween()
		tw2.tween_property(orb, "position:x", amp, 0.06)
		tw2.tween_property(orb, "position:x", -amp, 0.08)
		tw2.tween_property(orb, "position:x", 0.0, 0.06)
		tw2.parallel().tween_property(orb, "scale", Vector3.ONE * (1.0 + (i + 1) * 0.1), 0.2)
		orb.set_energy(2.4 + i * 0.8)
		await tw2.finished
		await get_tree().create_timer(0.22 - i * 0.05).timeout
	# 割れる
	_crack(col)
	await get_tree().create_timer(0.7).timeout
	sfx["chime"].play()
	_fill_card(t)
	_show_layer(layer_reveal)
	reveal_card.modulate.a = 0.0
	r_buttons.modulate.a = 0.0
	r_kicker.modulate.a = 0.0
	reveal_card.position.y = 300
	var tw4 := create_tween().set_parallel()
	tw4.tween_property(r_kicker, "modulate:a", 1.0, 0.3)
	tw4.tween_property(reveal_card, "modulate:a", 1.0, 0.3)
	tw4.tween_property(reveal_card, "position:y", 262.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw4.tween_property(r_buttons, "modulate:a", 1.0, 0.3).set_delay(0.3)
	await tw4.finished
	busy = false


func _tint_orb(c: Color) -> void:
	orb.core_mat.set_shader_parameter("glow", c)
	orb.shell_mat.set_shader_parameter("tint", c.lightened(0.35))
	orb.light.light_color = c


## 玉が割れて、殻のかけらが飛び、マイおばけ猫が現れる
func _crack(col: Color) -> void:
	_flash(0.95)
	sfx["hatch"].play()
	Input.vibrate_handheld(60)
	var at := orb.global_position
	burst.position = at
	burst.restart()
	burst.emitting = true
	var shard_mat := StandardMaterial3D.new()
	shard_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shard_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shard_mat.albedo_color = Color(col.lightened(0.7), 0.85)
	for i in 10:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.1
		sm.height = 0.2
		sm.is_hemisphere = true
		s.mesh = sm
		s.material_override = shard_mat
		s.position = at
		s.scale = Vector3(1.0, 0.25, 0.8) * randf_range(0.6, 1.1)
		s.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		world.add_child(s)
		var dir := Vector3(cos(TAU * i / 10.0), randf_range(-0.2, 0.9), sin(TAU * i / 10.0) * 0.5 + 0.3).normalized()
		var tw := create_tween().set_parallel()
		tw.tween_property(s, "position", at + dir * randf_range(0.9, 1.5) + Vector3(0, -0.6, 0), 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "rotation", s.rotation + Vector3(randf_range(-6, 6), randf_range(-6, 6), 0), 0.9)
		tw.tween_property(s, "scale", Vector3.ZERO, 0.4).set_delay(0.5)
		tw.chain().tween_callback(s.queue_free)
	orb.queue_free()
	orb = null
	# 背景が夜から、その子の色の朝へ
	var bg_to := col.lightened(0.72)
	var tw_bg := create_tween().set_parallel()
	tw_bg.tween_property(env, "background_color", bg_to, 0.8)
	tw_bg.tween_property(env, "ambient_light_color", Color("fff2e6"), 0.8)
	tw_bg.tween_property(env, "ambient_light_energy", 0.45, 0.8)
	_spawn_obake(0.05)
	var tw3 := create_tween()
	tw3.tween_property(obake, "scale", Vector3.ONE * 0.78, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _spawn_obake(s: float) -> void:
	if obake:
		obake.queue_free()
	obake = MyObake3D.new().setup_look(result.look)
	obake.position = Vector3(0, 1.02, 0.2)
	obake.rotation.y = 0.3
	obake.scale = Vector3.ONE * s
	world.add_child(obake)
	if shadow == null:
		shadow = MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.42
		sm.bottom_radius = 0.42
		sm.height = 0.004
		shadow.mesh = sm
		var smat := StandardMaterial3D.new()
		smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		smat.albedo_color = Color(0.16, 0.13, 0.2, 0.13)
		shadow.material_override = smat
		shadow.position = Vector3(0, 0.98, 0.2)
		shadow.scale = Vector3(1.0, 1, 0.45)
		world.add_child(shadow)


func _fill_card(t: Dictionary) -> void:
	var col := Color(t.look.color)
	r_kicker.add_theme_color_override("font_color", col.darkened(0.5))
	r_name.text = t.name
	r_en.text = t.en_name
	r_line.text = t.line
	r_job.text = "向いてる仕事：%s" % QuizData.JOBS[t.job].ja
	r_match.text = "相性のいいタイプ：%s" % QuizData.TYPES[t.match].name
	for c in r_axes.get_children():
		c.queue_free()
	for i in 4:
		r_axes.add_child(QuizCard._axis_bar(i, result.axes[i], col, font_bold, 12, Vector2(140, 7)))


func _flash(a: float) -> void:
	flash.modulate.a = a
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.6)


func _begin() -> void:
	if busy or result.is_empty():
		return
	GameState.set_my_obake(result)
	finished.emit(result)
	if main:
		main.go(next_screen)


# ---------------------------------------------------------------- シェア

func open_share() -> void:
	if result.is_empty() or share_sheet:
		return
	share_sheet = Control.new()
	share_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	share_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(share_sheet)
	move_child(share_sheet, flash.get_index())
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.13, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	share_sheet.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _pill(PAPER, 24))
	panel.position = Vector2(16, 40)
	panel.size = Vector2(328, 0)
	share_sheet.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(_text("結果をシェア", 17, INK, font_black))
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(216, 270)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	v.add_child(preview)
	v.add_child(_button("画像を保存", Color("ff8a5b"), _save_card))
	var copy := _button("シェア文をコピー", Color("fffaf2"), _copy_text, INK, 44)
	v.add_child(copy)
	share_status = _text("カードを作っています…", 12, SUB)
	share_status.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	share_status.custom_minimum_size = Vector2(300, 0)
	v.add_child(share_status)
	v.add_child(_link("とじる", SUB, close_share))
	card_image = await QuizCard.render(self, result)
	if share_sheet and is_instance_valid(preview):
		preview.texture = ImageTexture.create_from_image(card_image)
		share_status.text = "画像を保存して、SNSに貼ってね"


func _save_card() -> void:
	if card_image == null:
		return
	share_status.text = QuizCard.deliver(card_image, result.type_id)


func _copy_text() -> void:
	DisplayServer.clipboard_set(QuizData.share_text(result.type_id))
	share_status.text = "シェア文をコピーしました"


func close_share() -> void:
	if share_sheet:
		share_sheet.queue_free()
		share_sheet = null
