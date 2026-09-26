extends Control
## 帰り道でおばけを捕まえる。網を選び（相性）、縮む輪がおばけの体に重なった瞬間にタップ（タイミング）。

var main
var hud: Label
var net_bar: HBoxContainer
var toast: Label
var selected := ""
var wilds: Array = [] # {view, vel, t, id}
var swing: Dictionary = {} # {target, r, done}
var ring: Control
var shake := 0.0
var field: Control

const TARGET_R := 34.0
const START_R := 96.0
const SWING_TIME := 0.95


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UI.background("bg_catch"))
	field = Control.new()
	field.set_anchors_preset(Control.PRESET_FULL_RECT)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(field)

	ring = Control.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.draw.connect(_draw_ring)
	add_child(ring)

	var top := VBoxContainer.new()
	top.position = Vector2(12, 12)
	top.size = Vector2(336, 60)
	add_child(top)
	var title := UI.label("帰り道 ・ おばけが出る時間", 16, UI.WHITE)
	top.add_child(title)
	hud = UI.label("", 16, UI.YELLOW)
	top.add_child(hud)

	toast = UI.label("", 20, UI.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	toast.position = Vector2(0, 250)
	toast.size = Vector2(360, 60)
	toast.add_theme_color_override("font_outline_color", UI.INK)
	toast.add_theme_constant_override("outline_size", 6)
	add_child(toast)

	var bottom := VBoxContainer.new()
	bottom.position = Vector2(10, 512)
	bottom.size = Vector2(340, 120)
	bottom.add_theme_constant_override("separation", 8)
	add_child(bottom)
	bottom.add_child(UI.label("網をえらぶ（おばけと同じ仕事の網がよく効く）", 13, UI.WHITE))
	net_bar = HBoxContainer.new()
	net_bar.add_theme_constant_override("separation", 4)
	bottom.add_child(net_bar)
	bottom.add_child(UI.button("もう帰って寝る", func(): main.go("sleep"), true))

	for i in 3:
		_spawn()
	_refresh()
	GameState.changed.connect(_refresh)


func _refresh() -> void:
	hud.text = "網を振れる回数 %d ・ 網の強さ ×%.2f" % [GameState.stamina, GameState.net_strength]
	for c in net_bar.get_children():
		c.queue_free()
	if selected == "" or GameState.nets.get(selected, 0) == 0:
		selected = ""
		for id in GameState.nets:
			if GameState.nets[id] > 0:
				selected = id
				break
	for id in GameState.NETS:
		var n: int = GameState.nets.get(id, 0)
		var b := Button.new()
		b.custom_minimum_size = Vector2(54, 52)
		b.icon = load("res://assets/sprites/net_%s.png" % id)
		b.expand_icon = true
		b.text = str(n)
		b.disabled = n == 0
		b.tooltip_text = GameState.NETS[id].name
		b.add_theme_stylebox_override("normal", UI.box(UI.YELLOW if id == selected else UI.WHITE, UI.INK, 3 if id == selected else 2, 3))
		b.add_theme_stylebox_override("hover", UI.box(UI.YELLOW if id == selected else UI.CREAM, UI.INK, 2, 3))
		b.add_theme_color_override("font_color", UI.INK)
		b.add_theme_color_override("font_hover_color", UI.INK)
		b.pressed.connect(func():
			selected = id
			_refresh())
		net_bar.add_child(b)


func _pick_species() -> String:
	var s: Dictionary = GameState.today() if GameState.day < GameState.WEEK.size() else {}
	var r := randf()
	if r < 0.06:
		return "kirari"
	if s.get("band", "") in ["夜", "深夜"] and r < 0.22:
		return "lantern"
	return ["receipt", "bubble", "tray", "pan", "box"].pick_random()


func _spawn() -> void:
	var id := _pick_species()
	var v := ObakeView.new().setup(id, 3)
	v.position = Vector2(randf_range(20, 240), randf_range(110, 380))
	v.modulate.a = 0.0
	field.add_child(v)
	create_tween().tween_property(v, "modulate:a", 0.92, 0.6)
	wilds.append({"view": v, "vel": Vector2(randf_range(-40, 40), randf_range(-14, 14)), "t": randf() * TAU, "id": id})


func _process(delta: float) -> void:
	for w in wilds:
		var v: ObakeView = w.view
		if swing.get("target") == w:
			continue
		w.t += delta
		v.position += w.vel * delta + Vector2(0, sin(w.t * 1.7) * 0.4)
		if v.position.x < 0 or v.position.x > 264:
			w.vel.x *= -1
		if v.position.y < 100 or v.position.y > 400:
			w.vel.y *= -1
	if not swing.is_empty() and not swing.done:
		swing.r -= (START_R - 0) / SWING_TIME * delta
		if swing.r <= 0:
			_resolve(0.35, "おそかった")
	if shake > 0:
		shake = max(0.0, shake - delta * 30)
		position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	else:
		position = Vector2.ZERO
	ring.queue_redraw()


func _draw_ring() -> void:
	if swing.is_empty() or swing.done:
		return
	var v: ObakeView = swing.target.view
	var c := v.position + Vector2(48, 50)
	ring.draw_arc(c, TARGET_R, 0, TAU, 40, Color(1, 1, 1, 0.5), 2)
	var col := UI.YELLOW if absf(swing.r - TARGET_R) < 7 else UI.WHITE
	ring.draw_arc(c, max(swing.r, 1.0), 0, TAU, 48, col, 4)


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if not pressed:
		return
	var p: Vector2 = event.position
	if not swing.is_empty() and not swing.done:
		var diff := absf(swing.r - TARGET_R)
		if diff < 7:
			_resolve(1.6, "ぴったり！")
		elif diff < 18:
			_resolve(1.1, "いい感じ")
		else:
			_resolve(0.35, "はやすぎた" if swing.r > TARGET_R else "おそかった")
		return
	if not swing.is_empty():
		return
	for w in wilds:
		var v: ObakeView = w.view
		if p.distance_to(v.position + Vector2(48, 50)) < 44:
			_start_swing(w)
			return


func _start_swing(w: Dictionary) -> void:
	if GameState.stamina <= 0:
		_toast("もう網を振る元気がない。寝よう")
		return
	if selected == "" or not GameState.use_net(selected):
		_toast("網がない。シフトで網をもらおう")
		return
	swing = {"target": w, "r": START_R, "done": false, "net": selected}


func _resolve(timing: float, words: String) -> void:
	swing.done = true
	var w: Dictionary = swing.target
	var v: ObakeView = w.view
	var chance := GameState.catch_chance(w.id, swing.net, timing)
	var ok := randf() < chance
	v.flash = 1.0
	shake = 6.0
	# 網が飛んでいく
	var net_icon := UI.icon("res://assets/sprites/net_%s.png" % swing.net, 48)
	net_icon.position = Vector2(156, 560)
	add_child(net_icon)
	var tw := create_tween()
	tw.tween_property(net_icon, "position", v.position + Vector2(24, 20), 0.2)
	tw.tween_callback(net_icon.queue_free)
	await tw.finished
	if ok:
		var is_new := GameState.add_obake(w.id)
		var tw2 := create_tween().set_parallel()
		tw2.tween_property(v, "scale", Vector2(0.1, 0.1), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw2.tween_property(v, "position", v.position + Vector2(44, 44), 0.35)
		_toast("%s\n%s をつかまえた！%s" % [words, GameState.info(w.id).name, "\nはじめて！" if is_new else ""])
		_burst(v.position + Vector2(48, 48))
		await tw2.finished
	else:
		_toast("%s\n%s ににげられた…（%d%%）" % [words, GameState.info(w.id).name, int(chance * 100)])
		var tw3 := create_tween().set_parallel()
		tw3.tween_property(v, "position", v.position + Vector2(randf_range(-200, 200), -260), 0.5).set_ease(Tween.EASE_IN)
		tw3.tween_property(v, "modulate:a", 0.0, 0.5)
		await tw3.finished
	wilds.erase(w)
	v.queue_free()
	swing = {}
	_spawn()


func _burst(at: Vector2) -> void:
	for i in 10:
		var d := ColorRect.new()
		d.size = Vector2(4, 4)
		d.color = [UI.YELLOW, UI.WHITE, UI.ORANGE].pick_random()
		d.position = at
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(d)
		var dir := Vector2.from_angle(randf() * TAU) * randf_range(30, 70)
		var tw := create_tween().set_parallel()
		tw.tween_property(d, "position", at + dir, 0.5).set_ease(Tween.EASE_OUT)
		tw.tween_property(d, "modulate:a", 0.0, 0.5)
		tw.chain().tween_callback(d.queue_free)


func _toast(text: String) -> void:
	toast.text = text
	toast.modulate.a = 1.0
	toast.scale = Vector2(1, 1)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(toast, "modulate:a", 0.0, 0.4)


func demo_swing() -> void:
	# 確認用：最初のおばけに網を振りかけた状態を作る
	if wilds.size() > 0:
		_start_swing(wilds[0])
		swing.r = TARGET_R + 3
