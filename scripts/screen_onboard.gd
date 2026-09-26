extends Control
## はじめての流れの、専用の2場面。
##   "onboard"       … 体験バイト（見本）：30 秒で 17:00→21:00 を早送り。カフェで相棒が応援し、お客さんに「出す」を押す。
##                     終わるとポイ（すくいの網）がもらえて、はじめての夜のすくいへ。
##   "onboard_night" … すくいのあと、寝る前のひと場面。「朝まで眠る」で玉がかえる朝へ（孵化の画面）。
## ひとつの画面に、主ボタンはひとつ。説明はひとつずつ。

var main
var screen_name := "onboard"

const SHIFT_SEC := 30.0
const CLOCK_FROM := 17 * 60
const CLOCK_TO := 21 * 60
const INK := Color("2a2233")
const SUB := Color("6a5f70")
const CREAM := Color(1, 0.99, 0.97, 0.97)
const ORANGE := Color("ff8a5b")

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var env: Environment
var partner: MyObake3D
var customer: Obake3D
var window_mat: StandardMaterial3D

var clock_l: Label
var place_l: Label
var bar: ProgressBar
var bubble: PanelContainer
var bubble_l: Label
var order: PanelContainer
var order_l: Label
var hint: Label
var main_btn: Button
var served_l: Label
var sheet: PanelContainer

var running := false
var t := 0.0
var served := 0
var waiting := false # お客さんが待っている
var next_customer := 0.6
var busy := false
const CUSTOMERS := ["receipt", "tray", "pan", "box", "nemuri"]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_world()
	if screen_name == "onboard_night":
		_build_night()
	else:
		_build_shift()


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
	env.background_color = Color("f6d9b8")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff0e0")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	sun.light_color = Color("fff0dc")
	sun.light_energy = 0.8
	world.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 40
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.position = Vector3(0, 1.5, 4.4)
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.55, 0))
	partner = MyObake3D.from_saved()
	if partner == null:
		partner = MyObake3D.new().setup_look(QuizData.TYPES["IFHY"].look)


func _box(size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = Obake3D.toon(c, 0.15, 0.0, 0.012)
	m.position = pos
	world.add_child(m)
	return m


func _text(s: String, size: int, color := INK, heavy := false) -> Label:
	var l := Kit.text(s, size, color, heavy, HORIZONTAL_ALIGNMENT_CENTER)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _panel(bg: Color, radius := 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(bg, radius, 0.14, Vector2(14, 8)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## 相棒の吹き出し（ひとこと）
func _say(s: String) -> void:
	bubble_l.text = s
	bubble.visible = true
	bubble.pivot_offset = bubble.size / 2
	bubble.scale = Vector2(0.85, 0.85)
	create_tween().tween_property(bubble, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hop(ob: Node3D, h := 0.25) -> void:
	var y := ob.position.y
	var tw := create_tween()
	tw.tween_property(ob, "position:y", y + h, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ob, "position:y", y, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------- 体験バイト

func _build_shift() -> void:
	# カフェ：床・奥の壁と窓・カウンター（奥）・コーヒーマシン。相棒は手前の左、お客さんは右から来る
	var floor_m := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 7.0
	fm.bottom_radius = 7.0
	fm.height = 0.1
	floor_m.mesh = fm
	floor_m.material_override = Obake3D.toon(Color("c99a6e"), 0.1)
	floor_m.position = Vector3(0, -0.05, -0.4)
	world.add_child(floor_m)
	_box(Vector3(8, 4, 0.1), Vector3(0, 1.6, -1.9), Color("f7e6cf"))
	var win := _box(Vector3(1.3, 0.8, 0.05), Vector3(-1.1, 1.75, -1.82), Color("ffd9a0"))
	window_mat = Obake3D.toon(Color("ffd9a0"), 0.1, 0.4, 0.012)
	win.material_override = window_mat
	_box(Vector3(0.8, 0.6, 0.05), Vector3(1.15, 1.75, -1.82), Color("4f7a5a")) # メニューの黒板
	_box(Vector3(3.2, 0.5, 0.5), Vector3(0, 0.25, -0.9), Color("a0673f"))
	_box(Vector3(3.3, 0.06, 0.58), Vector3(0, 0.52, -0.9), Color("f6efe4"))
	_box(Vector3(0.36, 0.42, 0.3), Vector3(-1.1, 0.76, -0.95), Color("6b6f7a"))
	_box(Vector3(0.12, 0.12, 0.12), Vector3(0.1, 0.61, -0.8), Color("fffaf2"))
	partner.position = Vector3(-0.75, 0.0, 0.55)
	partner.scale = Vector3.ONE * 0.7
	partner.rotation.y = 0.45
	world.add_child(partner)

	# 上：どこで・いま何時（早送り）
	var top := VBoxContainer.new()
	top.position = Vector2(16, 14)
	top.size = Vector2(328, 0)
	top.add_theme_constant_override("separation", 6)
	add_child(top)
	var tp := _panel(CREAM, 20)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 10)
	tp.add_child(th)
	place_l = Kit.text(tr("ONB_SHIFT_PLACE"), 14, SUB, true)
	place_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(place_l)
	clock_l = Kit.text("17:00", 20, INK, true)
	th.add_child(clock_l)
	top.add_child(tp)
	bar = Kit.bar(0.0, ORANGE, 328, 8, Color(1, 1, 1, 0.6))
	top.add_child(bar)
	var mock := _text(tr("ONB_SHIFT_MOCK"), 12, Color("7a5a48"), true)
	top.add_child(mock)

	# 相棒のひとこと
	bubble = _panel(Color("fffaf2"), 16)
	bubble.position = Vector2(20, 150)
	bubble.size = Vector2(190, 0)
	bubble_l = I18n.wrap(Kit.text("", 14, INK, true))
	bubble_l.custom_minimum_size = Vector2(160, 0)
	bubble.add_child(bubble_l)
	add_child(bubble)
	# お客さんの注文
	order = _panel(Color("fff6d8"), 16)
	order.position = Vector2(196, 190)
	order.size = Vector2(140, 0)
	order_l = I18n.wrap(Kit.text("", 13, Color("8a5a10"), true))
	order_l.custom_minimum_size = Vector2(112, 0)
	order.add_child(order_l)
	order.visible = false
	add_child(order)

	served_l = _text("", 14, SUB, true)
	served_l.position = Vector2(0, 470)
	served_l.size = Vector2(360, 22)
	add_child(served_l)
	hint = _text("", 16, INK, true)
	hint.position = Vector2(16, 494)
	hint.size = Vector2(328, 40)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	main_btn = Kit.button(tr("ONB_SHIFT_START"), ORANGE, _on_main)
	main_btn.position = Vector2(40, 552)
	main_btn.size = Vector2(280, 56)
	add_child(main_btn)
	_say(tr("ONB_SHIFT_HELLO") % SpecialObake.pet_name())
	hint.text = tr("ONB_SHIFT_HINT_START")
	Kit.nudge.call_deferred(main_btn)


func _on_main() -> void:
	if screen_name == "onboard_night":
		_sleep()
		return
	if sheet:
		return
	if not running:
		running = true
		t = 0.0
		main_btn.text = tr("ONB_SHIFT_SERVE")
		main_btn.pivot_offset = main_btn.size / 2
		main_btn.scale = Vector2.ONE
		_say(tr("ONB_SHIFT_GO"))
		hint.text = tr("ONB_SHIFT_HINT_WAIT")
		return
	_serve()


func _process(delta: float) -> void:
	if not running or screen_name != "onboard":
		return
	t += delta
	var k := clampf(t / SHIFT_SEC, 0.0, 1.0)
	bar.value = k
	var m := int(lerpf(CLOCK_FROM, CLOCK_TO, k))
	clock_l.text = "%02d:%02d" % [m / 60, m % 60]
	# 窓の外が、夕方から夜へ
	window_mat.albedo_color = Color("ffd9a0").lerp(Color("3b4a8c"), k)
	env.background_color = Color("f6d9b8").lerp(Color("d9b8a8"), k)
	if not waiting:
		next_customer -= delta
		if next_customer <= 0.0 and t < SHIFT_SEC - 2.0:
			_customer_in()
	if t >= SHIFT_SEC:
		running = false
		_end_shift()


func _customer_in() -> void:
	waiting = true
	if customer:
		customer.queue_free()
	customer = Obake3D.make(CUSTOMERS[served % CUSTOMERS.size()])
	customer.scale = Vector3.ONE * 0.55
	customer.position = Vector3(2.6, 0, 0.5)
	customer.rotation.y = -1.2
	world.add_child(customer)
	var tw := create_tween()
	tw.tween_property(customer, "position", Vector3(0.8, 0, 0.5), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	if not is_instance_valid(customer):
		return
	order_l.text = tr("ONB_ORDER_%d" % (served % 4 + 1))
	order.visible = true
	hint.text = tr("ONB_SHIFT_HINT_SERVE")
	Kit.play(self, "bell", 1.2, -8)


func _serve() -> void:
	if busy:
		return
	if not waiting or not order.visible:
		_say(tr("ONB_SHIFT_NOT_YET"))
		return
	busy = true
	served += 1
	waiting = false
	order.visible = false
	Kit.play(self, "chime", 1.0 + served * 0.05, -4)
	served_l.text = tr("ONB_SHIFT_SERVED") % served
	_hop(partner, 0.3)
	_say([tr("ONB_CHEER_1"), tr("ONB_CHEER_2"), tr("ONB_CHEER_3")][served % 3])
	hint.text = tr("ONB_SHIFT_HINT_WAIT")
	var c := customer
	_hop(c, 0.2)
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(c):
		c.rotation.y = 1.2
		var tw := create_tween()
		tw.tween_property(c, "position", Vector3(2.8, 0, 0.6), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(c.queue_free)
	next_customer = 1.3
	busy = false


func _end_shift() -> void:
	clock_l.text = "21:00"
	order.visible = false
	if customer and is_instance_valid(customer):
		customer.queue_free()
	main_btn.visible = false
	hint.text = ""
	served_l.text = ""
	_hop(partner, 0.4)
	_say(tr("ONB_SHIFT_DONE_SAY"))
	Kit.play(self, "sparkle")
	# ポイ（すくいの網）をもらう：泡のポイ 2 本（今夜の玉に強い）＋いつものポイはそのまま
	GameState.nets["bubble"] = GameState.nets.get("bubble", 0) + 2
	GameState.save()
	sheet = _panel(CREAM, 24)
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet.position = Vector2(16, 396)
	sheet.size = Vector2(328, 0)
	add_child(sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	sheet.add_child(v)
	v.add_child(_text(tr("ONB_SHIFT_DONE"), 22, INK, true))
	v.add_child(_text(tr("ONB_SHIFT_RESULT") % maxi(served, 1), 14, SUB))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for i in 2:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(22, 22)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(11)
		sb.bg_color = GameState.TYPE_COLOR.dish
		sb.border_color = Color(0, 0, 0, 0.2)
		sb.set_border_width_all(2)
		dot.add_theme_stylebox_override("panel", sb)
		row.add_child(dot)
	row.add_child(Kit.text(tr("ONB_SHIFT_EARNED"), 17, Color("2f7bb0"), true))
	v.add_child(row)
	var why := I18n.wrap(_text(tr("ONB_SHIFT_POI_WHY"), 13, SUB))
	v.add_child(why)
	var b := Kit.button(tr("ONB_SHIFT_TO_RIVER"), Color("5b6fc2"), _to_river)
	v.add_child(b)
	sheet.pivot_offset = Vector2(164, 120)
	sheet.scale = Vector2(0.9, 0.9)
	sheet.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(sheet, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sheet, "modulate:a", 1.0, 0.25)
	Kit.nudge.call_deferred(b)


func _to_river() -> void:
	Onboarding.advance("scoop")
	GameState.phase = "evening"
	GameState.save()
	main.go("catch")


# ---------------------------------------------------------------- 寝る前

func _build_night() -> void:
	env.background_color = Color("141a3a")
	env.ambient_light_color = Color("7a84c8")
	env.ambient_light_energy = 0.55
	var ground := MeshInstance3D.new()
	var gm := CylinderMesh.new()
	gm.top_radius = 2.4
	gm.bottom_radius = 2.4
	gm.height = 0.1
	ground.mesh = gm
	ground.material_override = Obake3D.toon(Color("3f6a4a"), 0.1)
	ground.position = Vector3(0, -0.05, 0)
	world.add_child(ground)
	var moon := MeshInstance3D.new()
	var mm := SphereMesh.new()
	mm.radius = 0.45
	mm.height = 0.9
	moon.mesh = mm
	moon.material_override = Kit.glow(Color("fff1c8"), 2.0)
	moon.position = Vector3(1.4, 2.6, -3)
	moon.name = "Moon"
	world.add_child(moon)
	partner.motion = "doze"
	partner.position = Vector3(0, 0, 0.3)
	partner.scale = Vector3.ONE * 0.8
	world.add_child(partner)
	# 眠っている間にかえる玉（今夜すくった分）
	for i in GameState.orbs.size():
		var o := Orb3D.new().setup(GameState.orbs[i])
		o.caught = true
		o.position = Vector3(0.75 + i * 0.3, 0.1, 0.6)
		world.add_child(o)
	var z := _text("z z z", 26, Color("c9bdf5"), true)
	z.position = Vector2(196, 170)
	z.size = Vector2(120, 40)
	add_child(z)
	var zt := create_tween().set_loops()
	zt.tween_property(z, "modulate:a", 0.3, 1.0)
	zt.tween_property(z, "modulate:a", 1.0, 1.0)
	var v := VBoxContainer.new()
	v.position = Vector2(16, 420)
	v.size = Vector2(328, 0)
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	v.add_child(_text(tr("ONB_NIGHT_TITLE"), 24, Color("fff6e8"), true))
	var l := I18n.wrap(_text(tr("ONB_NIGHT_BODY") % SpecialObake.pet_name(), 14, Color("c9bdf5")))
	v.add_child(l)
	main_btn = Kit.button(tr("ONB_NIGHT_SLEEP"), Color("8b7bff"), _on_main)
	main_btn.position = Vector2(40, 552)
	main_btn.size = Vector2(280, 56)
	add_child(main_btn)
	Kit.nudge.call_deferred(main_btn)


func _sleep() -> void:
	if busy:
		return
	busy = true
	main_btn.disabled = true
	Kit.play(self, "chime", 0.8)
	var moon: Node3D = world.get_node("Moon")
	var tw := create_tween().set_parallel()
	tw.tween_property(env, "background_color", Color("ffd9b0"), 1.4)
	tw.tween_property(env, "ambient_light_color", Color("fff0e0"), 1.4)
	tw.tween_property(moon, "position:y", -1.0, 1.4)
	await tw.finished
	# 23:30 に寝て 7:00 に起きた夜にする（はじめての夜は、よく眠れた夜）。玉は GameState.sleep() の中でかえる
	GameState.sleep(330, 780)
	# はじめての朝は「すくった玉から、新しい子」だけを見せる。条件を満たしたレアは、次の夜まで待ってもらう
	for h in GameState.hatched.duplicate():
		if h.get("rare", false):
			GameState.hatched.erase(h)
			GameState.seen.erase(h.id)
			GameState.owned = GameState.owned.filter(func(o): return o.id != h.id)
			GameState.rare_pending.push_front(h.id)
	# 朝の庭の演出（ねむりのまとめ）は2日目から。今朝は孵化 → 島の説明へ
	GameState.phase = "day"
	GameState.garden_seen_level = GameState.garden_level
	GameState.save()
	Onboarding.advance("island")
	main.go("hatch")


# ---------------------------------------------------------------- 確認用

func demo_start() -> void:
	_on_main()


func demo_customer() -> void:
	t = 12.0
	next_customer = 0.0


func demo_serve() -> void:
	_serve()


func demo_end() -> void:
	t = SHIFT_SEC
