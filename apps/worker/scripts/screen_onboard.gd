extends Control
## はじめての流れの「shift」の段（診断のあと）。小さな場面を 3 つ、順に：
##   1. name  … 相棒に名前をつける（診断で会った子に。候補から選ぶか、打つ。10 文字まで。「あとで」でそのままでもよい）
##              入っている名前は、診断の結果で呼んだ名前（「Sunny だよ」→ Sunny）。候補もその名前が先頭で、
##              あとは英語版は英語の名前・日本語版は日本語の名前（SpecialObake.name_ideas）
##   2. go    … 相棒「きみがシフトの間、ぼくも働くね！」。主ボタン「シフトに行く」
##   3. mock  … 猫の仕事場（screen_work.gd）をこの画面の中に置き、早送りで 4 時間の見本のシフト。
##              終わったら「いっしょにがんばったね！」で肉球コインとポイ → はじめての夜のすくいへ
## 仕事場は本物の WorkTogether で動かし、終わったら記録を片づける（Onboarding.end_mock_shift）。残すのはコインとポイだけ。
## ひとつの場面に、主ボタンはひとつ。

var main
var screen_name := "onboard"

const MOCK_HOURS := 4.0 # 見本のシフトの長さ（ゲームの中の時間）
const MOCK_SEC := 8.0 # それを実時間で何秒に
const MOCK_NETS := 2 # もらえるポイ（泡のポイ。はじめての夜の玉に強い）
const INK := Color("2a2233")
const SUB := Color("6a5f70")
const CREAM := Color(1, 0.99, 0.97, 0.97)
const ORANGE := Color("ff8a5b")
const LILAC := Color("6a5bd6")

var phase := "name" # name → go → mock → done
var box: SubViewportContainer
var vp: SubViewport
var world: Node3D
var cam: Camera3D
var partner: MyObake3D

var bubble: PanelContainer
var bubble_l: Label
var card: PanelContainer
var name_edit: LineEdit
var name_web: WebTextField # Web では、入力欄の上にブラウザの <input> を重ねる（スマホのキーボード・変換・音声入力のため）
var main_btn: Button
var work: Control # 猫の仕事場（screen_work.gd）。見本のシフトの間だけ
var chip: PanelContainer
var sheet: PanelContainer
var coins_earned := 0
var busy := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# 名前は、診断で相棒に会ってから。まだ診断を受けていなければ、診断へ（名前を先に聞かない）
	if GameState.my_obake.is_empty() and main:
		main.go.call_deferred("quiz", true)
		return
	Onboarding.end_mock_shift() # 前に途中で閉じた見本のシフトが残っていたら、片づけてから
	_build_world()
	_build_bubble()
	_show_name()


# ---------------------------------------------------------------- 3D（休憩室の相棒）

func _build_world() -> void:
	box = SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	View3D.fit(box, vp)
	world = Node3D.new()
	vp.add_child(world)
	# 光と空気は他の画面と同じ Look（休憩室）
	Look.apply(world, "room", Color("f6d9b8"), false, false)
	cam = Camera3D.new()
	cam.fov = 40
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	# 相棒は画面の上半分（吹き出しの下・カードの上）に見えるよう、足もとより下を見る
	cam.position = Vector3(0, 1.25, 3.6)
	world.add_child(cam)
	cam.look_at(Vector3(0, -0.05, 0))
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
	_box(Vector3(1.1, 0.7, 0.05), Vector3(-1.0, 1.35, -1.82), Color("ffd9a0")) # 窓
	_box(Vector3(0.7, 0.5, 0.05), Vector3(1.05, 1.3, -1.82), Color("4f7a5a")) # シフト表の黒板
	partner = MyObake3D.from_saved()
	if partner == null:
		partner = MyObake3D.new().setup_look(QuizData.TYPES["IFHY"].look)
	partner.position = Vector3(0, 0.0, 0.4)
	partner.scale = Vector3.ONE * 0.85
	world.add_child(partner)


func _box(size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = Obake3D.toon(c, 0.15, 0.0, 0.012)
	m.position = pos
	world.add_child(m)
	return m


func _panel(bg: Color, radius := 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(bg, radius, 0.14, Vector2(16, 12)))
	return p


func _text(s: String, size: int, color := INK, heavy := false) -> Label:
	var l := Kit.text(s, size, color, heavy, HORIZONTAL_ALIGNMENT_CENTER)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _link(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 36)
	b.add_theme_font_override("font", Kit.bold())
	b.add_theme_font_size_override("font_size", 14)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, SUB)
	b.pressed.connect(func():
		Kit.play(b, "tap")
		cb.call())
	return b


## 相棒の吹き出し（頭の上。ひとこと）
func _build_bubble() -> void:
	bubble = _panel(Color("fffaf2"), 18)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.position = Vector2(30, 40)
	bubble.size = Vector2(300, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	bubble.add_child(v)
	bubble_l = I18n.wrap(_text("", 17, INK, true))
	bubble_l.custom_minimum_size = Vector2(268, 0)
	v.add_child(bubble_l)
	add_child(bubble)


func _say(s: String) -> void:
	bubble_l.text = s
	bubble.visible = true
	bubble.size.y = 0
	bubble.pivot_offset = Vector2(150, 30)
	bubble.scale = Vector2(0.85, 0.85)
	create_tween().tween_property(bubble, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hop(ob: Node3D, h := 0.3) -> void:
	var y := ob.position.y
	var tw := create_tween()
	tw.tween_property(ob, "position:y", y + h, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ob, "position:y", y, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## 下のカード（場面ごとに作り直す）。中身の高さに合わせて、画面の下にそろえる
func _card() -> VBoxContainer:
	if card:
		card.queue_free()
	card = _panel(CREAM, 24)
	card.position = Vector2(16, 400)
	card.size = Vector2(328, 0)
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	card.add_child(v)
	var c := card
	Kit.keep_fit(c, func():
		c.size.y = 0
		c.position.y = 624.0 - c.size.y)
	return v


# ---------------------------------------------------------------- 1. 名前

func _show_name() -> void:
	phase = "name"
	_say(tr("ONB_NAME_SAY"))
	var v := _card()
	v.add_child(_text(tr("ONB_NAME_TITLE"), 20, INK, true))
	name_edit = LineEdit.new()
	# いまの呼び名（診断の結果で「Sunny だよ」と呼んだ名前。自分でつけた名前があればそれ）
	name_edit.text = SpecialObake.pet_name()
	name_edit.max_length = SpecialObake.NAME_MAX
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.custom_minimum_size = Vector2(0, 52)
	name_edit.select_all_on_focus = true
	name_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
	var st := Kit.pill(Color.WHITE, 16, 0.0, Vector2(12, 8))
	st.border_color = Color("e2d6c8")
	st.set_border_width_all(2)
	name_edit.add_theme_stylebox_override("normal", st)
	var stf := st.duplicate() as StyleBoxFlat
	stf.border_color = ORANGE
	name_edit.add_theme_stylebox_override("focus", stf)
	name_edit.add_theme_font_override("font", Kit.black())
	name_edit.add_theme_font_size_override("font_size", 22)
	name_edit.add_theme_color_override("font_color", INK)
	name_edit.text_submitted.connect(func(_t): _name_ok())
	v.add_child(name_edit)
	name_web = WebTextField.attach(name_edit, _name_ok)
	# 候補（タップで入る）。先頭は診断の結果で出た呼び名、そのあとに名前の案を 3 つ
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	for n in chip_names():
		row.add_child(_chip(String(n)))
	v.add_child(row)
	v.add_child(I18n.wrap(_text(tr("ONB_NAME_HINT") % SpecialObake.NAME_MAX, 12, SUB)))
	main_btn = Kit.button(tr("ONB_NAME_OK"), ORANGE, _name_ok)
	v.add_child(main_btn)
	v.add_child(_link(tr("ONB_NAME_SKIP"), _name_skip))


## 名前の候補：診断の結果で出た呼び名 → 名前の案（重なりは除く）
static func chip_names() -> Array:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameState")
	var out: Array = [SpecialObake.pet_name(SpecialObake._without_name(gs.my_obake))]
	for n in SpecialObake.name_ideas(4):
		if not out.has(n) and out.size() < 4:
			out.append(n)
	return out


## 名前の候補のボタン（押すと入力欄に入る）
func _chip(n: String) -> Button:
	var b := Button.new()
	b.text = n
	b.focus_mode = Control.FOCUS_NONE
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.custom_minimum_size = Vector2(0, 34)
	b.add_theme_font_override("font", Kit.bold())
	b.add_theme_font_size_override("font_size", 14)
	for k in ["normal", "hover", "pressed"]:
		b.add_theme_stylebox_override(k, Kit.pill(Color("fff1e0") if k != "pressed" else Color("ffe0c2"), 17, 0.0, Vector2(10, 4)))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, INK)
	b.pressed.connect(func():
		Kit.play(b, "tap")
		_set_name_text(n))
	return b


func _set_name_text(n: String) -> void:
	if name_web:
		name_web.set_text(n)
	else:
		name_edit.text = n
		name_edit.caret_column = n.length()


func _name_ok() -> void:
	if phase != "name":
		return
	var n := SpecialObake.clean_name(name_edit.text)
	if n != "":
		SpecialObake.set_partner_name(n)
	name_edit.release_focus()
	if name_web:
		name_web.blur()
	_hop(partner, 0.4)
	Kit.play(self, "sparkle")
	_show_go(tr("ONB_NAME_THANKS") % SpecialObake.pet_name())


func _name_skip() -> void:
	if phase != "name":
		return
	name_edit.release_focus()
	if name_web:
		name_web.blur()
	_show_go("")


# ---------------------------------------------------------------- 2. シフトへ

func _show_go(first_line: String) -> void:
	phase = "go"
	_say((first_line + "\n" if first_line != "" else "") + tr("ONB_GO_SAY"))
	var v := _card()
	v.add_child(_text(tr("ONB_GO_TITLE"), 20, INK, true))
	v.add_child(I18n.wrap(_text(tr("ONB_GO_BODY") % SpecialObake.pet_name(), 14, SUB)))
	main_btn = Kit.button(tr("ONB_GO_BTN"), ORANGE, _start_mock)
	v.add_child(main_btn)
	Kit.nudge.call_deferred(main_btn)


# ---------------------------------------------------------------- 3. 見本のシフト（猫の仕事場を早送りで）

func _start_mock() -> void:
	if phase != "go" or busy:
		return
	busy = true
	var fade := ColorRect.new()
	fade.color = Color("0b1026")
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.modulate.a = 0.0
	add_child(fade)
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.2)
	await tw.finished
	phase = "mock"
	for n in [box, bubble, card]:
		n.queue_free()
	card = null
	# ほんものの「一緒に働く」を、見本の場所で早送り（1 秒 = 30 分）。はじめたことは見本として送る
	WorkTogether.set_speed(MOCK_HOURS * 3600.0 / MOCK_SEC)
	Telemetry.set_demo_session(true)
	WorkTogether.start(_role(), Onboarding.MOCK_PLACE)
	Telemetry.set_demo_session(false)
	work = load("res://scripts/screen_work.gd").new()
	work.set("main", self) # 仕事場の「島へ」などは、この画面が受ける（go）
	work.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(work)
	move_child(work, 0)
	# 見本なので「帰る」は押させない（時間が来たら自分で終わる）
	var act = work.get("action")
	if act:
		act.visible = false
	chip = _panel(Color(0.1, 0.08, 0.2, 0.7), 16)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(_text(tr("ONB_SHIFT_MOCK"), 13, Color.WHITE, true))
	chip.position = Vector2(60, 420) # 下のカードのすぐ上（上は仕事場の見出しと相棒の吹き出し）
	chip.size = Vector2(240, 0)
	add_child(chip)
	var tw2 := create_tween()
	tw2.tween_property(fade, "modulate:a", 0.0, 0.25)
	tw2.tween_callback(fade.queue_free)
	busy = false


## 相棒の向いている仕事（診断のタイプ）
func _role() -> String:
	var tid: String = GameState.my_obake.get("type_id", "")
	return QuizData.TYPES[tid].get("job", "hall") if QuizData.TYPES.has(tid) else "hall"


func _process(_delta: float) -> void:
	if phase != "mock":
		return
	var st := WorkTogether.status()
	if st.get("working", false) and float(st.get("hours_session", 0.0)) >= MOCK_HOURS:
		_end_mock(int(st.get("coins", 0)))


func _end_mock(coins: int) -> void:
	phase = "done"
	coins_earned = coins
	Onboarding.end_mock_shift()
	if work:
		work.set_process(false) # 仕事場はこの形のまま止める（コインの山と、相棒）
		var bl = work.get("bubble_label")
		if bl:
			bl.text = tr("ONB_TOGETHER_SAY")
	if chip:
		chip.queue_free()
	# 肉球コインとポイ（すくいの網）をもらう：泡のポイ（今夜の玉に強い）
	Wallet.add(coins_earned, "onboarding")
	GameState.nets["bubble"] = GameState.nets.get("bubble", 0) + MOCK_NETS
	GameState.save()
	Kit.play(self, "sparkle")
	Sfx.coins(self, coins_earned, 0.2)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.15, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	sheet = _panel(CREAM, 26)
	sheet.position = Vector2(20, 200)
	sheet.size = Vector2(320, 0)
	add_child(sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	sheet.add_child(v)
	v.add_child(_text(tr("ONB_TOGETHER_TITLE"), 22, INK, true))
	v.add_child(_text(tr("+%d Paw Coins") % coins_earned, 28, Color("d99a1a"), true))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for i in MOCK_NETS:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(22, 22)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(11)
		sb.bg_color = GameState.TYPE_COLOR.dish
		sb.border_color = Color(Tokens.SHADOW, 0.2)
		sb.set_border_width_all(2)
		dot.add_theme_stylebox_override("panel", sb)
		row.add_child(dot)
	row.add_child(Kit.text(tr("ONB_SHIFT_EARNED"), 17, Color("2f7bb0"), true))
	v.add_child(row)
	v.add_child(I18n.wrap(_text(tr("ONB_SHIFT_POI_WHY"), 13, SUB)))
	var b := Kit.button(tr("ONB_SHIFT_TO_RIVER"), Color("5b6fc2"), _to_river)
	v.add_child(b)
	var s := sheet
	Kit.keep_fit(s, func():
		s.size.y = 0
		s.position.y = (640.0 - s.size.y) / 2.0)
	sheet.pivot_offset = Vector2(160, 120)
	sheet.scale = Vector2(0.9, 0.9)
	sheet.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(sheet, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sheet, "modulate:a", 1.0, 0.25)
	Kit.nudge.call_deferred(b)


## 仕事場の中のボタン（「島へ」など）が呼ぶ行き先。見本のシフトの間は、どこへも行かない
func go(to: String, _instant := false) -> void:
	if phase == "done" and to == "garden":
		_to_river()


func _to_river() -> void:
	if busy:
		return
	busy = true
	Onboarding.advance("scoop")
	GameState.phase = "evening"
	GameState.save()
	main.go("catch")


# ---------------------------------------------------------------- 確認用

func demo_name(n := "") -> void:
	if n != "":
		name_edit.text = n
	_name_ok()


func demo_pick(i: int) -> void:
	var row: HBoxContainer = name_edit.get_parent().get_child(name_edit.get_index() + 1)
	row.get_child(i).pressed.emit()


func demo_skip() -> void:
	_name_skip()


func demo_start() -> void:
	_start_mock()


func demo_end() -> void:
	if phase == "mock":
		_end_mock(int(WorkTogether.status().get("coins", 0)))


func demo_river() -> void:
	_to_river()
