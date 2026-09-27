extends Control
## Working together: while you are at work, your cat-obake works at a tiny workplace too.
## It earns Paw Coins into a little tray, gets tired as the shift goes on (face and pose, not a meter),
## and when it is pooped it stops earning and asks to go home.
## Logic lives in WorkTogether. This screen only shows it.

var main

const INK := Color("2a2233")
const SUB := Color("6a5f70")
const COIN := Color("ffc93d")

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var obake: Obake3D
var props: Node3D
var tray: Node3D
var coin_nodes: Array = []
var zzz: Label3D
var sweat: MeshInstance3D
var role := ""

var bubble: PanelContainer
var bubble_label: Label
var head: Label
var sub: Label
var info_line: Label
var action: Button
var home_link: Button
var result_layer: Control
var shop_link: Button
var _t := 0.0
var _tick := 0.0
var _last_coins := -1
var _last_stage := ""
var _ending := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	WorkTogether.sync()
	role = _current_role()
	_build_world()
	_build_ui()
	_refresh(true)


## The job for this screen: the running session, else today's recorded shift, else the obake's best job
func _current_role() -> String:
	var ses := WorkTogether.session()
	if not ses.is_empty():
		return ses.role
	var s: Dictionary = GameState.today()
	if s.get("role", "") != "" and not s.get("chore", false):
		return s.role
	var tid: String = GameState.my_obake.get("type_id", "")
	if QuizData.TYPES.has(tid):
		return QuizData.TYPES[tid].get("job", "hall")
	return "hall"


# ---------------------------------------------------------------- 3D

func _build_world() -> void:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_2X
	box.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	# 光と空気は休憩室と同じ Look（room）。キーライトだけ影を落とす
	Look.apply(world, "room", Color("f3dcc4"), false, true)
	cam = Camera3D.new()
	cam.position = Vector3(0, 2.3, 5.6)
	cam.fov = 40
	world.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0.55, -0.2))

	# A small corner of a shop: floor tiles, back wall, a warm lamp
	_box(Vector3(6, 0.1, 5), Vector3(0, -0.05, 0), Color("c99a72"))
	for i in 7:
		_box(Vector3(6, 0.004, 0.02), Vector3(0, 0.002, -2.4 + i * 0.8), Color("b5855f"))
	_box(Vector3(6, 3.4, 0.12), Vector3(0, 1.7, -1.6), Color("f6e6d2"))
	_box(Vector3(6, 0.6, 0.14), Vector3(0, 0.3, -1.55), Color("d9b48c"))
	var lamp := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.16
	lm.height = 0.24
	lamp.mesh = lm
	lamp.position = Vector3(-1.3, 2.4, -1.2)
	lamp.material_override = Kit.glow(Color("ffd48a"), 1.6)
	world.add_child(lamp)
	var ol := OmniLight3D.new()
	ol.light_color = Color("ffcf8a")
	ol.light_energy = 0.8
	ol.omni_range = 4.0
	ol.position = lamp.position
	world.add_child(ol)

	props = Node3D.new()
	world.add_child(props)
	_build_props(role)

	# The cat-obake
	# 自分の相棒は保存した look（とくべつな印つき）で。島と同じ AAA の体
	var my_look: Dictionary = GameState.my_obake.get("look", {})
	if GameState.host() == "my" and not my_look.is_empty():
		obake = Obake3D.make_custom(my_look)
	elif GameState.host() == "my" and QuizData.TYPES.has(GameState.my_obake.get("type_id", "")):
		obake = Obake3D.make_custom(QuizData.TYPES[GameState.my_obake.type_id].look)
	else:
		obake = Obake3D.make(GameState.host())
	obake.scale = Vector3.ONE * 0.62
	obake.position = Vector3(-0.3, 0, 0.2)
	obake.bob = false
	world.add_child(obake)
	# tired signs: a sweat drop and "z z"
	sweat = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.13
	sweat.mesh = sm
	sweat.material_override = Kit.glow(Color("9fd8ff"), 0.4)
	sweat.position = Vector3(0.38, 0.95, 0.25)
	sweat.visible = false
	obake.add_child(sweat)
	zzz = Kit.label3d("z z", 44, Color("8b7bff"))
	zzz.position = Vector3(0.45, 1.35, 0)
	zzz.visible = false
	obake.add_child(zzz)

	# The coin tray
	tray = Node3D.new()
	tray.position = Vector3(0.78, 0.62, 0.45)
	world.add_child(tray)
	var dish := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.34
	dm.bottom_radius = 0.28
	dm.height = 0.07
	dish.mesh = dm
	dish.material_override = Obake3D.toon(Color("e8e2d8"), 0.2)
	tray.add_child(dish)
	_box(Vector3(0.5, 0.62, 0.5), Vector3(0.78, 0.29, 0.45), Color("a8795a"))


func _box(size: Vector3, pos: Vector3, c: Color, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = Obake3D.toon(c, 0.05)
	(parent if parent else world).add_child(m)
	return m


func _cyl(r: float, h: float, pos: Vector3, c: Color, parent: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	m.mesh = cm
	m.position = pos
	m.material_override = Obake3D.toon(c, 0.15)
	parent.add_child(m)
	return m


## A tiny workplace for each job
func _build_props(r: String) -> void:
	for c in props.get_children():
		c.queue_free()
	match r:
		"register":
			_box(Vector3(1.6, 0.8, 0.6), Vector3(-0.2, 0.4, -0.75), Color("8f6a4c"), props)
			_box(Vector3(0.5, 0.3, 0.4), Vector3(-0.55, 0.95, -0.75), Color("5b6f8f"), props)
			_box(Vector3(0.36, 0.14, 0.02), Vector3(-0.55, 1.05, -0.54), Color("9fe0a0"), props)
			_box(Vector3(0.1, 0.02, 0.4), Vector3(-0.2, 0.81, -0.55), Color("fffaf0"), props)
		"dish":
			_box(Vector3(1.6, 0.8, 0.6), Vector3(-0.2, 0.4, -0.75), Color("aeb8c2"), props)
			_box(Vector3(0.8, 0.06, 0.45), Vector3(-0.2, 0.8, -0.75), Color("6fa8d0"), props)
			for i in 4:
				_cyl(0.16, 0.025, Vector3(0.45, 0.83 + i * 0.03, -0.75), Color("fffaf0"), props)
			for i in 5:
				var bub := MeshInstance3D.new()
				var bm := SphereMesh.new()
				bm.radius = 0.06 + i * 0.01
				bm.height = bm.radius * 2
				bub.mesh = bm
				bub.position = Vector3(-0.45 + i * 0.12, 0.88, -0.7)
				bub.material_override = Obake3D.toon(Color("f4fbff"), 0.8)
				props.add_child(bub)
		"hall":
			for x in [-1.2, 0.6]:
				_cyl(0.35, 0.05, Vector3(x, 0.7, -0.6), Color("b07a4a"), props)
				_cyl(0.05, 0.7, Vector3(x, 0.35, -0.6), Color("7a4e32"), props)
				_cyl(0.05, 0.12, Vector3(x + 0.1, 0.78, -0.6), Color("cfe8ff"), props)
			_cyl(0.3, 0.03, Vector3(0.35, 0.95, 0.35), Color("c8ced6"), props)
		"kitchen":
			_box(Vector3(1.6, 0.8, 0.6), Vector3(-0.2, 0.4, -0.75), Color("c4c9cf"), props)
			_cyl(0.22, 0.02, Vector3(-0.5, 0.81, -0.75), Color("3a3a42"), props)
			_cyl(0.2, 0.08, Vector3(-0.5, 0.86, -0.75), Color("4a4a52"), props)
			_box(Vector3(0.36, 0.03, 0.06), Vector3(-0.2, 0.87, -0.75), Color("4a4a52"), props)
			var flame := MeshInstance3D.new()
			var fm := SphereMesh.new()
			fm.radius = 0.08
			fm.height = 0.12
			flame.mesh = fm
			flame.position = Vector3(-0.5, 0.79, -0.75)
			flame.material_override = Kit.glow(Color("ff9a4d"), 2.0)
			props.add_child(flame)
		_: # stock
			for i in 3:
				_box(Vector3(1.7, 0.05, 0.5), Vector3(-0.3, 0.3 + i * 0.55, -1.2), Color("9a7458"), props)
				for j in 3:
					_box(Vector3(0.36, 0.3, 0.3), Vector3(-0.9 + j * 0.5, 0.48 + i * 0.55, -1.2), Color("d9a86c").lerp(Color("c78f55"), j * 0.3), props)
			_box(Vector3(0.45, 0.35, 0.4), Vector3(0.45, 0.18, 0.1), Color("d9a86c"), props)


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var top := HBoxContainer.new()
	top.position = Vector2(12, 14)
	top.size = Vector2(336, 44)
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	var tp := PanelContainer.new()
	tp.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.92), 22))
	head = Kit.text("", 16, INK, true)
	tp.add_child(head)
	top.add_child(tp)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	home_link = Kit.button(tr("Island"), Color(1, 1, 1, 0.92), func(): main.go("garden"), Color("5b6fc2"), 44, 15)
	home_link.custom_minimum_size.x = 84
	top.add_child(home_link)

	# What the obake says (one line, above its head)
	bubble = PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.96), 18))
	bubble.position = Vector2(30, 104)
	bubble.size = Vector2(300, 0)
	bubble_label = Kit.text("", 16, INK, true, HORIZONTAL_ALIGNMENT_CENTER)
	bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_label.custom_minimum_size = Vector2(270, 0)
	bubble.add_child(bubble_label)
	add_child(bubble)

	# The card: one line of numbers the player needs, one primary action
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Kit.pill(Color(1, 0.99, 0.97, 0.97), 24, 0.14, Vector2(18, 14)))
	card.position = Vector2(12, 462)
	card.size = Vector2(336, 166)
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	sub = Kit.text("", 18, INK, true)
	v.add_child(sub)
	info_line = Kit.text("", 14, SUB)
	info_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_line.custom_minimum_size = Vector2(300, 0)
	v.add_child(info_line)
	action = Kit.button("", Color("ff8a5b"), _on_action)
	v.add_child(action)
	# 働いている間に開けるのは、いまのシフトのお店とのチャットだけ（「少し遅れます」など）
	shop_link = Kit.button(tr("Message the shop"), Color(1, 1, 1, 0.92), func():
		var th := _shop_thread()
		if th != "" and ChatHub.allowed_during_shift(th):
			ChatHub.open(self, th), Color("6a5bd6"), 34, 13)
	shop_link.position = Vector2(12, 420)
	shop_link.size = Vector2(0, 34)
	shop_link.visible = false
	add_child(shop_link)


## いまのシフト（登録シフト）のお店のチャット。手で始めたときは無し
func _shop_thread() -> String:
	var cur := Shifts.current()
	return "" if cur.is_empty() else ChatShops.thread_id_for(cur)


func _on_action() -> void:
	if _ending:
		return
	if WorkTogether.active():
		_end_shift()
	else:
		WorkTogether.start(role, _place())
		Kit.play(self, "chime")
		_pop(obake)
		_refresh(true)


func _place() -> String:
	var s: Dictionary = GameState.today()
	return s.get("store", "") if s.get("role", "") == role else ""


func _end_shift() -> void:
	_ending = true
	var r := WorkTogether.stop()
	Kit.play(self, "sparkle")
	_show_result(r)


# ---------------------------------------------------------------- every frame

func _process(delta: float) -> void:
	_t += delta
	_tick -= delta
	if _tick <= 0.0 and not _ending:
		_tick = 0.5
		var ended := WorkTogether.sync()
		if not ended.is_empty():
			_ending = true
			Kit.play(self, "sparkle")
			_show_result(ended)
			return
		_refresh()
	_animate(delta)


func _refresh(force := false) -> void:
	var st := WorkTogether.status()
	var working: bool = st.working
	var r: String = st.get("role", role)
	if r != role:
		role = r
		_build_props(role)
	# 見本の記録の店名は日本語のキー（tr で英語に）。自分で入れた場所はそのまま出る
	var place := tr(String(st.get("place", "")))
	head.text = WorkTogether.role_label(role) + ((" · " + place) if place != "" else "")
	bubble_label.text = WorkTogether.line(st)
	# 働いている間は、島へは行かない（ここで猫を見守るだけ。終わったら「帰る」）
	home_link.visible = not working and not _ending
	if shop_link:
		shop_link.visible = working and not _shop_thread().is_empty()
	if working:
		var hs: float = st.hours_session
		sub.text = tr("At work together")
		info_line.text = tr("Your cat is at work too. See you after your shift!") + "\n" + tr("%dh %02dm · %d Paw Coins") % [int(hs), int(fmod(hs * 60.0, 60.0)), st.coins]
		if st.exhausted:
			info_line.text += "\n" + tr("No more coins today — time to rest.")
		action.text = tr("Back home")
	else:
		sub.text = tr("Today's work") if st.hours_today > 0.0 else tr("Work together")
		var lines: Array = []
		if int(st.earned_today) > 0:
			lines.append(tr("Earned today: %d Paw Coins") % st.earned_today)
		else:
			lines.append(tr("Your cat-obake earns Paw Coins while you work."))
		var up := WorkTogether.upcoming_line()
		if up != "":
			lines.append(up)
		info_line.text = "\n".join(lines)
		action.text = tr("I'm going to work")
		action.disabled = st.exhausted
		if st.exhausted:
			action.text = tr("Resting until tomorrow")
	# coins in the tray
	var c: int = int(st.coins) if working else int(st.earned_today)
	if c != _last_coins:
		_set_coins(c, not force and c > _last_coins)
		_last_coins = c
	if st.stage != _last_stage:
		_last_stage = st.stage
		if not force and st.stage == "exhausted":
			# a soft low tap (the lullaby froze the frame loop when it ended here, so it is not used)
			Kit.play(self, "tap", 0.7, -4)
			_pop(bubble)
		elif not force:
			_pop(bubble)


## One coin model per 10 coins, stacked in the tray
func _set_coins(n: int, fly: bool) -> void:
	var want: int = mini(int(ceil(n / 10.0)), 18)
	while coin_nodes.size() < want:
		var i := coin_nodes.size()
		var coin := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.07
		cm.bottom_radius = 0.07
		cm.height = 0.022
		coin.mesh = cm
		coin.material_override = Obake3D.toon(COIN, 0.35, 0.25)
		var ring := i % 6
		var layer := i / 6
		var target := Vector3(cos(ring * TAU / 6.0) * 0.14, 0.05 + layer * 0.025, sin(ring * TAU / 6.0) * 0.14)
		tray.add_child(coin)
		coin_nodes.append(coin)
		if fly:
			coin.global_position = obake.global_position + Vector3(0, 0.9, 0)
			var tw := create_tween()
			tw.tween_property(coin, "position", target + Vector3(0, 0.4, 0), 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(coin, "position", target, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			Kit.play(self, "pop", 1.2 + randf() * 0.2, -6)
		else:
			coin.position = target
	while coin_nodes.size() > want:
		coin_nodes.pop_back().queue_free()


## Fatigue as pose and face: bouncy when fresh, busy little moves, droop when tired, eyes shut when pooped
func _animate(delta: float) -> void:
	if obake == null:
		return
	var st_name := _last_stage if _last_stage != "" else "fresh"
	var working := WorkTogether.active()
	var body: Node3D = obake.body
	var speed: float = {"fresh": 3.2, "busy": 2.4, "tired": 1.4, "sleepy": 0.9, "exhausted": 0.5}.get(st_name, 2.0)
	var hop: float = absf(sin(_t * speed)) * ({"fresh": 0.1, "busy": 0.06, "tired": 0.03, "sleepy": 0.015, "exhausted": 0.0}.get(st_name, 0.05) if working else 0.03)
	body.position.y = hop
	# working: sway toward the task; tired: lean forward; exhausted: sink and tilt
	var sway: float = sin(_t * speed * 0.8) * (0.18 if working and st_name in ["fresh", "busy"] else 0.05)
	var lean: float = {"fresh": 0.0, "busy": 0.05, "tired": 0.14, "sleepy": 0.22, "exhausted": 0.28}.get(st_name, 0.0) if working else 0.0
	body.rotation = Vector3(lean, sway, sin(_t * 0.7) * (0.12 if st_name == "exhausted" else 0.03))
	var squash: float = 0.86 if st_name == "exhausted" and working else 1.0
	body.scale = Vector3(1.0 / sqrt(squash), squash, 1.0 / sqrt(squash))
	# eyes: shut when sleepy/pooped
	if working and st_name in ["sleepy", "exhausted"]:
		obake._blink = 1.0
	sweat.visible = working and st_name in ["tired", "sleepy"]
	if sweat.visible:
		sweat.position.y = 0.95 - fmod(_t * 0.25, 0.25)
	zzz.visible = working and st_name in ["sleepy", "exhausted"]
	if zzz.visible:
		zzz.modulate.a = 0.5 + 0.5 * sin(_t * 2.0)
		zzz.position.y = 1.35 + fmod(_t * 0.2, 0.2)


func _pop(c) -> void:
	if c is Control:
		c.pivot_offset = c.size / 2
		c.scale = Vector2(0.9, 0.9)
		create_tween().tween_property(c, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif c is Node3D:
		var tw := create_tween()
		tw.tween_property(c, "position:y", 0.3, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- end of the shift

func _show_result(r: Dictionary) -> void:
	_refresh(true)
	bubble_label.text = tr("I'm pooped… let's both head home.") if r.get("exhausted", false) else tr("Good work today! Let's go home.")
	result_layer = Control.new()
	result_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(result_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.15, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_layer.add_child(dim)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Kit.pill(Color(1, 0.99, 0.97, 0.98), 26, 0.2, Vector2(22, 18)))
	card.position = Vector2(24, 230)
	card.custom_minimum_size = Vector2(312, 0)
	result_layer.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	v.add_child(Kit.text(tr("Shift's over!"), 22, INK, true, HORIZONTAL_ALIGNMENT_CENTER))
	var h: float = r.get("hours", 0.0)
	v.add_child(Kit.text(tr("%dh %02dm together") % [int(h), int(fmod(h * 60.0, 60.0))], 14, SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Kit.text(tr("+%d Paw Coins") % r.get("coins", 0), 30, Color("d99a1a"), true, HORIZONTAL_ALIGNMENT_CENTER))
	if int(r.get("nets", 0)) > 0:
		v.add_child(Kit.text(tr("+%d %s nets") % [r.nets, WorkTogether.role_label(r.role)], 16, INK, true, HORIZONTAL_ALIGNMENT_CENTER))
	if r.get("exhausted", false):
		var note := Kit.text(tr("Your cat-obake got tired,\nso it stopped there.\nExtra time earns nothing."), 13, SUB, false, HORIZONTAL_ALIGNMENT_CENTER)
		_wrap_fixed(note)
		v.add_child(note)
	if r.get("mood_penalty_tomorrow", false):
		var note2 := Kit.text(tr("A long day…\ntomorrow it'll be a bit slower."), 13, Color("c0604f"), false, HORIZONTAL_ALIGNMENT_CENTER)
		_wrap_fixed(note2)
		v.add_child(note2)
	v.add_child(Kit.button(tr("Back to the island"), Color("5b6fc2"), func(): main.go("garden")))
	card.pivot_offset = Vector2(156, 120)
	card.scale = Vector2(0.9, 0.9)
	create_tween().tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Notes in the result card are written as short lines (no autowrap): a wrapping label here
## made Godot's layout loop forever and froze the screen.
func _wrap_fixed(l: Label) -> void:
	l.autowrap_mode = TextServer.AUTOWRAP_OFF


# ---------------------------------------------------------------- checks / demo

func demo_start() -> void:
	_on_action()


func demo_stop() -> void:
	if WorkTogether.active():
		_end_shift()
