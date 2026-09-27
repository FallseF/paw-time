extends Control
## おさらい（Practice）：仕事ごとの 1〜3 分の練習。相棒のおばネコが小さな職場で一緒にやる。
## 選んだ仕事は Skills.practice_role。中身は scripts/practice_*.gd、問題は PracticeData。
##
## 決まり: いつでも任意。お店が求めるものではない。罰なし・急かすタイマーなし・他人との順位なし。
## （お店に命じられた事前研修は労働時間で、賃金が要る。だからここは、どの店でも通じる一般的な技能を自分のために練習する場所）
## ごほうびは Skills.record_practice（段をはじめてクリアしたときだけ、制服か小さなポイ。コインは出さない）。

var main
var screen_name := "practice"

const INK := Color("2a2233")
const SUB := Color("6a5f70")
const PAPER := Color(1, 0.99, 0.97, 0.97)
const ORANGE := Color("ff8a5b")
const GREEN := Color("3f8a55")
const GAMES := {
	"register": preload("res://scripts/practice_register.gd"),
	"dish": preload("res://scripts/practice_dish.gd"),
	"hall": preload("res://scripts/practice_hall.gd"),
	"kitchen": preload("res://scripts/practice_kitchen.gd"),
	"stock": preload("res://scripts/practice_stock.gd"),
}

var role := "register"
var level := 1
var game: PracticeGame

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var props: Node3D
var cat: Obake3D
var sparkle: CPUParticles3D
var suds: CPUParticles3D

var head_l: Label
var dots: HBoxContainer
var bubble: PanelContainer
var bubble_l: Label
var order_box: PanelContainer
var order_l: Label
var note: PanelContainer
var note_l: Label
var panel: PanelContainer
var task_l: Label
var hint_l: Label
var grid: GridContainer
var extra: VBoxContainer
var overlay: Control
var done_steps := 0
var order_anchor: Node3D # お客さん・伝票のことばを、この上に出す（空なら右上に固定）


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	role = Skills.practice_role if Skills.practice_role in Skills.ROLES else "register"
	level = Skills.next_level(role)
	if OS.get_environment("OBAKE_PRACTICE_LEVEL") != "": # 確認用：段を決めて撮る
		level = clampi(int(OS.get_environment("OBAKE_PRACTICE_LEVEL")), 1, 3)
	_build_world()
	_build_ui()
	_new_game()
	_show_intro()


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
	View3D.fit(box, vp)
	world = Node3D.new()
	vp.add_child(world)
	# 光と空気は休憩室・一緒に働く画面と同じ Look（room）。キーだけ影を落とす
	Look.apply(world, "room", Color("f3dcc4"), false, true)
	cam = Camera3D.new()
	cam.fov = 38
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	world.add_child(cam)
	frame(Vector3(0, 2.25, 4.9), Vector3(0, 0.2, -0.3))
	_room()
	props = Node3D.new()
	world.add_child(props)
	# 相棒（診断の子。まだなら見本の子）
	var my := MyObake3D.from_saved()
	cat = my if my != null else MyObake3D.new().setup_look(QuizData.TYPES["IFHY"].look)
	cat.scale = Vector3.ONE * 0.62
	cat.position = Vector3(-1.1, 0, 0.5)
	cat.rotation.y = 0.5
	world.add_child(cat)
	sparkle = _particles(Color("ffe27a"), 0.03, 36)
	suds = _particles(Color("f4fbff"), 0.06, 24)
	suds.gravity = Vector3(0, 0.6, 0)
	suds.initial_velocity_min = 0.3
	suds.initial_velocity_max = 0.8


## 小さな職場の部屋：市松の床・あたたかい壁と腰板・窓・吊りランプ・鉢植え（どの仕事でも同じ部屋）
func _room() -> void:
	box3(Vector3(7, 0.1, 6), Vector3(0, -0.05, 0), Color("c48d62"))
	for i in 9:
		for j in 8:
			if (i + j) % 2 == 0:
				box3(Vector3(0.78, 0.004, 0.78), Vector3(-3.2 + i * 0.8, 0.002, -2.4 + j * 0.8), Color("b67f56"))
	box3(Vector3(7, 3.6, 0.12), Vector3(0, 1.8, -1.95), Color("e6c49e"))
	box3(Vector3(7, 0.8, 0.14), Vector3(0, 0.4, -1.88), Color("b9825a"))
	box3(Vector3(7, 0.06, 0.18), Vector3(0, 0.82, -1.86), Color("8f5f3f"))
	# 窓（夕方の空）
	box3(Vector3(1.1, 0.8, 0.06), Vector3(-1.75, 2.0, -1.88), Color("8f5f3f"))
	var sky := box3(Vector3(0.96, 0.66, 0.05), Vector3(-1.75, 2.0, -1.86), Color("ffc98f"))
	sky.material_override = Kit.glow(Color("ffcf9a"), 0.45)
	box3(Vector3(0.04, 0.66, 0.06), Vector3(-1.75, 2.0, -1.84), Color("8f5f3f"))
	box3(Vector3(0.96, 0.04, 0.06), Vector3(-1.75, 2.0, -1.84), Color("8f5f3f"))
	# 吊りランプ
	var shade := cyl3(0.22, 0.2, Vector3(1.2, 2.35, -1.1), Color("3f6b58"), null, 0.08)
	var cord := box3(Vector3(0.03, 0.9, 0.03), Vector3(1.2, 2.9, -1.1), Color("3a3a42"))
	var bulb := ball3(0.07, Vector3(1.2, 2.24, -1.1), Color("ffe2a8"))
	bulb.material_override = Kit.glow(Color("ffd48a"), 1.4)
	for m in [shade, cord, bulb]: # 壁のメニューに影を落とさない
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ol := OmniLight3D.new()
	ol.light_color = Color("ffcf8a")
	ol.light_energy = 0.9
	ol.omni_range = 4.0
	ol.position = Vector3(1.2, 2.3, -1.1)
	world.add_child(ol)
	# 鉢植え（右奥）
	cyl3(0.16, 0.3, Vector3(2.0, 0.15, -1.45), Color("c96b4a"), null, 0.2)
	for k in 5:
		var a := TAU * k / 5.0
		ball3(0.16, Vector3(2.0 + cos(a) * 0.12, 0.5 + (k % 2) * 0.12, -1.45 + sin(a) * 0.1), Color("5f9a5b").lerp(Color("7fbf6a"), (k % 3) * 0.3))


## カメラの位置と、見る点（ゲームごとに寄ったり引いたり）
func frame(from: Vector3, at: Vector3) -> void:
	cam.look_at_from_position(from, at)


func _particles(c: Color, r: float, n: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.amount = n
	p.lifetime = 1.0
	p.explosiveness = 1.0
	p.spread = 180
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, -2.0, 0)
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2
	p.mesh = sm
	p.material_override = Kit.glow(c, 2.0) if c != Color("f4fbff") else Obake3D.toon(c, 0.8)
	world.add_child(p)
	return p


## 3D の部品（道具づくりに使う）
func box3(sz: Vector3, pos: Vector3, c: Color, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = Obake3D.rbox(sz, minf(0.03, minf(sz.x, minf(sz.y, sz.z)) * 0.3))
	m.position = pos
	m.material_override = Obake3D.toon(c, 0.1, 0.0, 0.012)
	(parent if parent else world).add_child(m)
	return m


func cyl3(r: float, h: float, pos: Vector3, c: Color, parent: Node3D = null, top := -1.0) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r if top < 0.0 else top
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 24
	m.mesh = cm
	m.position = pos
	m.material_override = Obake3D.toon(c, 0.2, 0.0, 0.012)
	(parent if parent else world).add_child(m)
	return m


func ball3(r: float, pos: Vector3, c: Color, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2
	m.mesh = sm
	m.position = pos
	m.material_override = Obake3D.toon(c, 0.3, 0.0, 0.012)
	(parent if parent else world).add_child(m)
	return m


func label3(t: String, pos: Vector3, px := 40, c := INK, parent: Node3D = null) -> Label3D:
	var l := Kit.label3d(t, px, c)
	l.position = pos
	l.outline_size = 8
	l.outline_modulate = Color(1, 1, 1, 0.9)
	(parent if parent else world).add_child(l)
	return l


## ぴょんと跳ねる
func hop(n: Node3D, h := 0.22) -> void:
	if not is_instance_valid(n):
		return
	var y := n.position.y
	var tw := create_tween()
	tw.tween_property(n, "position:y", y + h, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "position:y", y, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## 置いた物が「ぽん」と出る
func pop_in(n: Node3D) -> void:
	var s0 := n.scale
	n.scale = s0 * 0.2
	create_tween().tween_property(n, "scale", s0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func move(n: Node3D, to: Vector3, dur := 0.4) -> Tween:
	var tw := create_tween()
	tw.tween_property(n, "position", to, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tw


## 相棒を x,z へ歩かせる（向きも変える）
func walk_cat(to: Vector3, face := 0.0) -> Tween:
	var tw := create_tween().set_parallel()
	tw.tween_property(cat, "position", to, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cat, "rotation:y", face, 0.3)
	return tw


func sparkle_at(p: Vector3) -> void:
	sparkle.position = p
	sparkle.restart()


func suds_at(p: Vector3) -> void:
	suds.position = p
	suds.restart()


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var top := HBoxContainer.new()
	top.position = Vector2(12, 12)
	top.size = Vector2(336, 40)
	top.add_theme_constant_override("separation", 6)
	add_child(top)
	var hp := PanelContainer.new()
	hp.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.94), 20, 0.14, Vector2(12, 6)))
	head_l = Kit.text("", 15, INK, true)
	hp.add_child(head_l)
	top.add_child(hp)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	var leave := Kit.button(tr("PR_LEAVE"), Color(1, 1, 1, 0.94), _leave, Color("5b6fc2"), 38, 14)
	leave.custom_minimum_size.x = 72
	top.add_child(leave)
	# 進み（点）と「任意・タイマーなし」の小さな札
	dots = HBoxContainer.new()
	dots.position = Vector2(14, 60)
	dots.add_theme_constant_override("separation", 5)
	add_child(dots)
	note = PanelContainer.new()
	note.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.7), 11, 0.0, Vector2(8, 2)))
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	note_l = Kit.text(tr("PR_NO_TIMER"), 11, SUB, true)
	note.add_child(note_l)
	add_child(note)
	# 相棒のひとこと
	bubble = PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", Kit.pill(Color("fffaf2"), 16, 0.14, Vector2(12, 7)))
	bubble.position = Vector2(14, 88)
	bubble.size = Vector2(176, 0)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_l = I18n.wrap(Kit.text("", 14, INK, true))
	bubble_l.custom_minimum_size = Vector2(152, 0)
	bubble.add_child(bubble_l)
	bubble.visible = false
	add_child(bubble)
	# お客さん・伝票のことば（右）
	order_box = PanelContainer.new()
	order_box.add_theme_stylebox_override("panel", Kit.pill(Color("fff6d8"), 16, 0.14, Vector2(12, 7)))
	order_box.position = Vector2(176, 150)
	order_box.size = Vector2(170, 0)
	order_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	order_l = I18n.wrap(Kit.text("", 14, Color("8a5a10"), true))
	order_l.custom_minimum_size = Vector2(146, 0)
	order_box.add_child(order_l)
	order_box.visible = false
	add_child(order_box)
	# 下の札：いまの手順・ヒント・押す札
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Kit.pill(PAPER, 24, 0.2, Vector2(14, 12)))
	panel.position = Vector2(10, 400)
	panel.size = Vector2(340, 0)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size = Vector2(312, 0)
	panel.add_child(v)
	task_l = I18n.wrap(Kit.text("", 17, INK, true))
	v.add_child(task_l)
	hint_l = I18n.wrap(Kit.text("", 13, SUB))
	v.add_child(hint_l)
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	extra = VBoxContainer.new()
	extra.add_theme_constant_override("separation", 4)
	v.add_child(extra)


func _head() -> void:
	head_l.text = tr("PR_HEAD") % [Skills.role_name(role), Skills.star_text(level)]


## 相棒が話す
func say(t: String) -> void:
	bubble_l.text = t
	bubble.visible = t != ""
	bubble.size.y = 0
	bubble.pivot_offset = Vector2(20, 20)
	bubble.scale = Vector2(0.86, 0.86)
	create_tween().tween_property(bubble, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 吹き出しを、相棒とお客さんの頭の上に（3D の位置を画面へ写す）
func _process(_delta: float) -> void:
	if not is_instance_valid(cam) or not cam.is_inside_tree():
		return
	var floor_y := panel.position.y - 6 if panel.visible else 600.0
	if bubble.visible and is_instance_valid(cat):
		var p := View3D.unproject(cam, cat.global_position + Vector3(0, 0.78, 0))
		bubble.position = Vector2(clampf(p.x - 50, 8, 352 - bubble.size.x), clampf(p.y - bubble.size.y - 6, 84, floor_y - bubble.size.y))
	if order_box.visible:
		var q := Vector2(346 - order_box.size.x, 150)
		if order_anchor and is_instance_valid(order_anchor) and order_anchor.is_inside_tree():
			var p2 := View3D.unproject(cam, order_anchor.global_position + Vector3(0, 0.62, 0))
			q = Vector2(clampf(p2.x - order_box.size.x + 50, 8, 352 - order_box.size.x), clampf(p2.y - order_box.size.y - 6, 84, floor_y - order_box.size.y))
		# 相棒の吹き出しと重なるなら、上へずらす
		if bubble.visible and Rect2(bubble.position, bubble.size).intersects(Rect2(q, order_box.size)):
			q.y = maxf(84, bubble.position.y - order_box.size.y - 6)
		order_box.position = q


## お客さん・伝票のことば（空で隠す）
func order(t: String) -> void:
	order_l.text = t
	order_box.visible = t != ""
	order_box.size.y = 0
	if t != "":
		order_box.pivot_offset = Vector2(150, 20)
		order_box.scale = Vector2(0.86, 0.86)
		create_tween().tween_property(order_box, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## いまの手順（大きい字）とヒント（小さい字）
func task(t: String, hint := "") -> void:
	task_l.text = t
	hint_l.text = hint
	hint_l.visible = hint != ""
	_fit_panel()


func _fit_panel() -> void:
	for i in 2:
		await get_tree().process_frame
		if not is_instance_valid(panel):
			return
		panel.size.y = 0
		panel.position.y = 630 - panel.size.y


## 押す札を並べる。list: [{text, sub?, color?, cb, glow?}]。返り値はボタンの配列
func tiles(list: Array, cols := 2) -> Array:
	for c in grid.get_children():
		c.queue_free()
	for c in extra.get_children():
		c.queue_free()
	grid.columns = cols
	var out: Array = []
	var w := (312 - (cols - 1) * 8) / cols
	for e in list:
		var b := tile(String(e.text), e.get("color", Color("fff2dc")), e.cb, String(e.get("sub", "")), w)
		grid.add_child(b)
		if e.get("glow", false):
			_glow(b)
		out.append(b)
	_fit_panel()
	return out


## 押すと沈む、立体の札（下のふちが濃い）
func tile(t: String, bg: Color, cb: Callable, sub := "", w := 152) -> Button:
	var b := Button.new()
	b.text = t + ("\n" + sub if sub != "" else "")
	b.custom_minimum_size = Vector2(w, 58 if sub != "" else 50)
	b.add_theme_font_override("font", Kit.black())
	b.add_theme_font_size_override("font_size", 15)
	var fg := INK if bg.get_luminance() > 0.55 else Color.WHITE
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fg)
	for k in ["normal", "hover", "focus", "pressed"]:
		var sb := Kit.pill(bg if k != "pressed" else bg.darkened(0.08), 16, 0.0, Vector2(8, 4))
		sb.border_color = bg.darkened(0.28)
		sb.border_width_bottom = 2 if k == "pressed" else 5
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 1
		sb.shadow_color = Color(Tokens.SHADOW, 0.08)
		sb.shadow_size = 4
		b.add_theme_stylebox_override(k, sb)
	b.pressed.connect(func():
		Kit.play(b, "tap", 1.05)
		b.pivot_offset = b.size / 2
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(0.94, 0.94), 0.05)
		tw.tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		cb.call(b))
	return b


## 大きな主ボタン（下の札の下段に）
func main_button(t: String, cb: Callable, bg := ORANGE) -> Button:
	var b := Kit.button(t, bg, cb)
	extra.add_child(b)
	_fit_panel()
	return b


func small_link(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.custom_minimum_size = Vector2(0, 32)
	b.add_theme_font_override("font", Kit.bold())
	b.add_theme_font_size_override("font_size", 13)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, SUB)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func():
		Kit.play(self, "tap", 1.1)
		cb.call())
	extra.add_child(b)
	return b


## ★1 のヒント：正解の札がふわっと光る
func _glow(b: Button) -> void:
	var tw := b.create_tween().set_loops()
	tw.tween_property(b, "modulate", Color(1.12, 1.08, 0.9), 0.5)
	tw.tween_property(b, "modulate", Color.WHITE, 0.5)


## できた！（音・相棒が跳ねる・きらきら）。罰の反対で、ほめるだけ
func good(t := "") -> void:
	Kit.play(self, "chime", 1.0 + randf() * 0.15, -4)
	hop(cat, 0.25)
	sparkle_at(cat.position + Vector3(0, 0.7, 0))
	say(t if t != "" else tr(["PR_GOOD_1", "PR_GOOD_2", "PR_GOOD_3"].pick_random()))


## ちがったとき：やさしく言い直すだけ（減点・罰なし）
func oops(t: String, b: Control = null) -> void:
	Kit.play(self, "pop", 0.7, -8)
	var tw := create_tween()
	tw.tween_property(cat, "rotation:z", 0.18, 0.12)
	tw.tween_property(cat, "rotation:z", -0.1, 0.14)
	tw.tween_property(cat, "rotation:z", 0.0, 0.12)
	say(t)
	if b and is_instance_valid(b):
		var x := b.position.x
		var t2 := b.create_tween()
		for d in [6.0, -6.0, 4.0, 0.0]:
			t2.tween_property(b, "position:x", x + d, 0.05)


func _dots() -> void:
	for c in dots.get_children():
		c.queue_free()
	var n := game.total_steps()
	for i in n:
		var d := Panel.new()
		d.custom_minimum_size = Vector2(14, 14)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(7)
		sb.bg_color = GameState.TYPE_COLOR.get(role, ORANGE) if i < done_steps else Color(1, 1, 1, 0.75)
		sb.border_color = Color(Tokens.SHADOW, 0.18)
		sb.set_border_width_all(2)
		d.add_theme_stylebox_override("panel", sb)
		dots.add_child(d)
	await get_tree().process_frame
	note.position = Vector2(14 + dots.size.x + 8, 57)


## 1 つの問題が終わった（点がひとつ埋まる）
func step_done() -> void:
	done_steps += 1
	_dots()


# ---------------------------------------------------------------- 流れ

func _new_game() -> void:
	for c in props.get_children():
		c.queue_free()
	game = GAMES[role].new()
	game.s = self
	game.level = level
	var seed := int(OS.get_environment("OBAKE_PRACTICE_SEED")) if OS.get_environment("OBAKE_PRACTICE_SEED") != "" else randi() % 100000
	game.rounds = PracticeData.rounds_for(role, level, seed)
	game.build()
	done_steps = 0
	_head()
	_dots()


## はじめの札：何を練習するか・段を選ぶ・はじめる
func _show_intro() -> void:
	say(tr("PR_INTRO_SAY") % SpecialObake.pet_name())
	task(tr("PR_TITLE_" + role.to_upper()), tr("PR_ABOUT_" + role.to_upper()))
	var list: Array = []
	for lv in [1, 2, 3]:
		var open := Skills.level_open(role, lv)
		var got: bool = Skills.stars(role) >= lv
		var bg := Color("ffe7a8") if lv == level else (Color("fff8ea") if open else Color("ece6de"))
		var sub := tr("PR_LV_GOT") if got else (tr("PR_LV_OPEN") if open else tr("PR_LV_LOCKED"))
		list.append({"text": Skills.star_text(lv), "sub": sub, "color": bg, "cb": func(b): _pick_level(lv, b)})
	tiles(list, 3)
	main_button(tr("PR_START"), _start)
	var gen := I18n.wrap(Kit.text(tr("PR_GENERAL_NOTE"), 11, SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
	extra.add_child(gen)
	_fit_panel()


func _pick_level(lv: int, b: Control) -> void:
	if not Skills.level_open(role, lv):
		oops(tr("PR_LV_LOCKED_SAY") % Skills.star_text(lv - 1), b)
		return
	level = lv
	_new_game()
	_show_intro()


func _start() -> void:
	Kit.play(self, "bell", 1.2, -6)
	say(tr("PR_GO_SAY"))
	game.begin()


## 全部おわった：スキルの記録に書いて、バッジを見せる
func finish() -> void:
	var r := Skills.record_practice(role, level)
	Telemetry.track("practice_done", {"role": role, "level": clampi(level, 0, 20)})
	await get_tree().create_timer(0.6).timeout
	_show_result(r)


func _show_result(r: Dictionary) -> void:
	Kit.play(self, "sparkle")
	hop(cat, 0.4)
	sparkle_at(cat.position + Vector3(0, 0.8, 0))
	bubble.visible = false
	order("")
	panel.visible = false
	overlay = Control.new()
	overlay.size = Vector2(360, 640)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.09, 0.2, 0.55)
	dim.size = Vector2(360, 640)
	overlay.add_child(dim)
	var new_star: bool = r.get("new_star", false)
	var badge := SkillBadge.make(role, level, 124)
	badge.position = Vector2(180 - 62, 92)
	overlay.add_child(badge)
	badge.pivot_offset = Vector2(62, 62)
	badge.scale = Vector2(0.1, 0.1)
	var tw := create_tween()
	tw.tween_property(badge, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): Kit.play(self, "bell", 1.4, -4))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Kit.pill(PAPER, 24, 0.2, Vector2(18, 14)))
	card.position = Vector2(16, 236)
	card.size = Vector2(328, 0)
	overlay.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	v.custom_minimum_size = Vector2(292, 0)
	card.add_child(v)
	v.add_child(I18n.wrap(Kit.text(tr("PR_DONE_NEW") % [Skills.role_name(role), Skills.star_text(level)] if new_star else tr("PR_DONE_AGAIN"), 21, INK, true, HORIZONTAL_ALIGNMENT_CENTER)))
	v.add_child(I18n.wrap(Kit.text(tr("PR_DONE_BODY"), 13, SUB, false, HORIZONTAL_ALIGNMENT_CENTER)))
	var rw: Dictionary = r.get("reward", {})
	if not rw.is_empty():
		var rp := PanelContainer.new()
		rp.add_theme_stylebox_override("panel", Kit.pill(Color("fff2c8"), 14, 0.0, Vector2(10, 6)))
		var txt := ""
		if rw.kind == "cloth":
			txt = tr("PR_REWARD_CLOTH") % tr(WardrobeData.item(rw.id).name)
		else:
			txt = tr("PR_REWARD_POI") % [tr(GameState.NETS[rw.id].name), int(rw.n)] if int(rw.n) > 0 else tr("PR_REWARD_POI_FULL")
		rp.add_child(I18n.wrap(Kit.text(txt, 14, Color("8a5a10"), true, HORIZONTAL_ALIGNMENT_CENTER)))
		v.add_child(rp)
		if rw.kind == "cloth":
			v.add_child(Kit.button(tr("PR_SEE_UNIFORM"), Color("f3ecff"), func(): OutfitReveal.open(self, rw.id), Color("6a5bd6"), 42, 15))
	if level < Skills.MAX_STARS and Skills.level_open(role, level + 1):
		v.add_child(Kit.button(tr("PR_NEXT_LEVEL") % Skills.star_text(level + 1), ORANGE, _again.bind(level + 1)))
	else:
		v.add_child(Kit.button(tr("PR_AGAIN"), ORANGE, _again.bind(level)))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.add_child(Kit.button(tr("PR_MY_SKILLS"), Color("eef3ff"), func(): main.go("skills"), Color("3b5ba5"), 42, 14))
	row.add_child(Kit.button(tr("Island"), Color("eef3ff"), func(): main.go("garden"), Color("3b5ba5"), 42, 14))
	for c in row.get_children():
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(row)
	card.modulate.a = 0.0
	create_tween().tween_property(card, "modulate:a", 1.0, 0.3).set_delay(0.3)


func _again(lv: int) -> void:
	if overlay:
		overlay.queue_free()
		overlay = null
	panel.visible = true
	level = lv
	_new_game()
	_show_intro()


func _leave() -> void:
	main.go("skills")


# ---------------------------------------------------------------- 撮影・自動操作用

func demo_start() -> void:
	_start()


## いまの問題の正解を 1 つ押す（ゲームごとの demo_step）
func demo_step() -> void:
	if game.has_method("demo_step"):
		game.demo_step()


## 1 つだけ、わざとまちがえる（やさしい言い直しを撮る）
func demo_wrong() -> void:
	if game.has_method("demo_wrong"):
		game.demo_wrong()


func demo_finish() -> void:
	for i in 60:
		if overlay:
			return
		demo_step()
		await get_tree().create_timer(0.25).timeout
