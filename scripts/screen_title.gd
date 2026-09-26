extends Control
## タイトル。つづきから／はじめから。後ろを困りごとがゆっくり横切る。

var main

var walkers: Array = []
var confirm: Control


func _ready() -> void:
	Kit.music("c_calm_loop")
	var bg := TextureRect.new()
	var bgp := "res://assets/gen/c/bg_peak.png"
	if ResourceLoader.exists(bgp):
		var tex: Texture2D = load(bgp)
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(tex.get_width() * 0.3, 0, tex.get_height() * 0.5625, tex.get_height())
		bg.texture = at
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.07, 0.15, 0.25)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var ground := ColorRect.new()
	ground.color = Color("fff8ef")
	ground.position = Vector2(0, 596)
	ground.size = Vector2(360, 44)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ground)
	var line := ColorRect.new()
	line.color = Kit.INK
	line.position = Vector2(0, 594)
	line.size = Vector2(360, 3)
	add_child(line)
	# 困りごとが、画面の下を横切る
	var ids := ["receipt", "tray", "bubble", "pan", "box"]
	Kit.make_portraits(ids)
	for i in ids.size():
		var tr := TextureRect.new()
		tr.set_meta("id", ids[i])
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.size = Vector2(70, 70)
		tr.position = Vector2(-80 - i * 95, 528)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)
		walkers.append(tr)

	var card := PanelContainer.new()
	var cs := Kit.pill(Color(1, 0.98, 0.95, 0.95), 28, 0.25)
	cs.content_margin_top = 22
	cs.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", cs)
	card.position = Vector2(30, 120)
	card.size = Vector2(300, 0)
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var t1 := Kit.text("おばけの休憩室", 30, Kit.INK, true)
	t1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t1)
	var t2 := Kit.text("大ピーク防衛", 38, Color("ff6b5b"), true)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t2)
	var tag := Kit.text("よく寝た朝は、玉がかえる。", 13, Color("8b7bff"), true)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tag)

	var bv := VBoxContainer.new()
	bv.position = Vector2(50, 360)
	bv.size = Vector2(260, 0)
	bv.add_theme_constant_override("separation", 10)
	add_child(bv)
	if GameState.has_save():
		bv.add_child(Kit.button("つづきから（%d週目 %s曜）" % [GameState.week_no(), GameState.weekday()], Color("ff6b5b"), func(): main.go("morning")))
		bv.add_child(Kit.button("はじめから", Color(1, 1, 1, 0.92), _confirm_new, Kit.INK, 44, 15))
	else:
		bv.add_child(Kit.button("はじめる", Color("ff6b5b"), func():
			GameState.reset()
			main.go("morning")))
	var mb := Kit.button("音楽：%s" % ("ON" if Kit.music_on else "OFF"), Color(1, 1, 1, 0.8), func(): pass, Kit.INK, 34, 12)
	mb.custom_minimum_size = Vector2(90, 34)
	mb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mb.pressed.connect(func():
		Kit.set_music_on(not Kit.music_on)
		GameState.settings["music"] = Kit.music_on
		GameState.save_game()
		mb.text = "音楽：%s" % ("ON" if Kit.music_on else "OFF"))
	bv.add_child(mb)


func _process(delta: float) -> void:
	for tr: TextureRect in walkers:
		if tr.texture == null:
			tr.texture = Kit.portrait(tr.get_meta("id"))
		tr.position.x += 38.0 * delta
		tr.position.y = 528 - absf(sin(tr.position.x * 0.08)) * 6
		if tr.position.x > 380:
			tr.position.x -= 600


func _confirm_new() -> void:
	confirm = Control.new()
	confirm.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(confirm)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.15, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	confirm.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Kit.CREAM, 24))
	p.position = Vector2(40, 220)
	p.size = Vector2(280, 0)
	confirm.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var t := Kit.text("はじめから遊ぶ？\nいまの記録は消える", 17, Kit.INK, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(Kit.button("はじめから", Color("ff6b5b"), func():
		GameState.wipe_save()
		main.go("morning")))
	v.add_child(Kit.button("やめる", Color("b0a4b8"), func(): confirm.queue_free()))
