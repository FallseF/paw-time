extends PracticeGame
## キッチンのおさらい：いつも最初は手洗い → （帽子）→ 伝票を読む → 伝票どおりに作る → 盛りつけ →（台をふく）。
## ★3 は伝票にアレルギーのメモ（入れない材料）がある。

const ING_COL := {"egg": Color("ffd23f"), "cheese": Color("ffe07a"), "rice": Color("fbfaf6"), "onion": Color("e8d7c0"), "lettuce": Color("8fd18a"), "tomato": Color("ff6b5b")}
const WASH_PARTS := ["PR_KIT_WASH_PALMS", "PR_KIT_WASH_BACKS", "PR_KIT_WASH_FINGERS", "PR_KIT_WASH_THUMBS", "PR_KIT_WASH_RINSE"]

var phase := "" # step / wash / cook / wipe
var ticket := {}
var si := 0 # いまの手順の番号
var washes := 0
var wipes := 0
var added: Array = []
var pan: Node3D
var flame: MeshInstance3D
var ticket_l: Label3D
var hat: Node3D
var plate: Node3D
var tile_btns: Array = []
var order_tiles: Array = [] # 手順の札の並び（毎回同じにする）


func build() -> void:
	ticket = rounds[0]
	var p: Node3D = s.props
	s.frame(Vector3(0.25, 1.7, 3.4), Vector3(0.25, 0.35, -0.4))
	# 作業台（ステンレス）・コンロとフライパン・手洗いの流し・伝票のレール
	s.box3(Vector3(2.6, 0.8, 0.66), Vector3(0.1, 0.4, -0.6), Color("c4c9cf"), p)
	s.box3(Vector3(2.7, 0.06, 0.72), Vector3(0.1, 0.82, -0.6), Color("e3e7ea"), p)
	s.cyl3(0.2, 0.03, Vector3(-0.6, 0.86, -0.6), Color("3a3a42"), p)
	flame = MeshInstance3D.new()
	var fm := SphereMesh.new()
	fm.radius = 0.12
	fm.height = 0.1
	flame.mesh = fm
	flame.position = Vector3(-0.6, 0.88, -0.6)
	flame.material_override = Kit.glow(Color("ff9a4d"), 2.2)
	flame.visible = false
	p.add_child(flame)
	pan = Node3D.new()
	pan.position = Vector3(-0.6, 0.9, -0.6)
	p.add_child(pan)
	s.cyl3(0.2, 0.06, Vector3(0, 0.03, 0), Color("4a4a52"), pan, 0.22)
	var h: MeshInstance3D = s.box3(Vector3(0.32, 0.03, 0.05), Vector3(0.36, 0.05, 0), Color("2e2a2a"), pan)
	h.rotation.z = 0.12
	# 手洗い（右）：水色の流しと蛇口・石けん
	s.box3(Vector3(0.5, 0.02, 0.4), Vector3(0.95, 0.86, -0.6), Color("9fd0ec"), p)
	s.box3(Vector3(0.05, 0.36, 0.05), Vector3(0.95, 1.03, -0.86), Color("c8ced6"), p)
	s.box3(Vector3(0.05, 0.05, 0.2), Vector3(0.95, 1.2, -0.78), Color("c8ced6"), p)
	s.cyl3(0.05, 0.14, Vector3(1.28, 0.93, -0.75), Color("ff8fb1"), p)
	s.label3(tr("PR_KIT_SINK"), Vector3(0.95, 1.42, -0.8), 22, Color("4a5a6a"), p)
	# 伝票のレール（奥の壁）
	s.box3(Vector3(1.4, 0.05, 0.05), Vector3(0, 1.85, -1.8), Color("8a8f98"), p)
	s.box3(Vector3(0.95, 0.56, 0.02), Vector3(0, 1.55, -1.78), Color("fffaf0"), p)
	ticket_l = s.label3(tr("PR_KIT_TICKET_BACK"), Vector3(0, 1.6, -1.75), 26, Color("2a2233"), p)
	ticket_l.outline_size = 0
	# 手順の札の並び（段の手順＋ほかの段の手順を少し）を決めておく
	var all: Array = ["wash", "cap", "read", "cook", "plate", "wipe"]
	order_tiles = []
	for k in [3, 0, 4, 1, 5, 2]:
		if all[k] in ticket.steps or level == 1 and all[k] in ["cap"]:
			order_tiles.append(all[k])
	s.cat.position = Vector3(0.2, 0, 0.35)
	s.cat.rotation.y = 0.0


func total_steps() -> int:
	return ticket.steps.size()


func begin() -> void:
	si = 0
	_ask_step()


func _want() -> String:
	return ticket.steps[si] if si < ticket.steps.size() else ""


# ---------------------------------------------------------------- 次の手順

func _ask_step() -> void:
	phase = "step"
	var list: Array = []
	for k in order_tiles:
		var st: String = k
		var done: bool = ticket.steps.find(st) >= 0 and ticket.steps.find(st) < si
		list.append({"text": tr("PR_KIT_STEP_" + st.to_upper()), "color": Color("e2f3e6") if done else Color("fff3e8"), "cb": func(b): _step(st, b), "glow": hints() and st == _want()})
	tile_btns = s.tiles(list, 2)
	s.task(tr("PR_KIT_TASK_STEP") if si > 0 else tr("PR_KIT_TASK_FIRST"), tr("PR_KIT_HINT_STEP") if level < 3 else "")


func _step(st: String, b: Control) -> void:
	if phase != "step":
		return
	var want := _want()
	if st != want:
		if ticket.steps.find(st) >= 0 and ticket.steps.find(st) < si:
			s.oops(tr("PR_KIT_OOPS_DONE"), b)
		elif want == "wash":
			s.oops(tr("PR_KIT_OOPS_WASH_FIRST"), b)
		elif not st in ticket.steps:
			s.oops(tr("PR_KIT_OOPS_NOT_TODAY"), b)
		else:
			s.oops(tr("PR_KIT_OOPS_ORDER"), b)
		return
	match st:
		"wash":
			_start_wash()
		"cap":
			_put_cap()
		"read":
			_read_ticket()
		"cook":
			_start_cook()
		"plate":
			_plate()
		"wipe":
			_start_wipe()


func _step_ok(t := "") -> void:
	si += 1
	s.step_done()
	if si >= ticket.steps.size():
		phase = ""
		s.good(tr("PR_KIT_GOOD_ALL"))
		s.finish()
		return
	s.good(t)
	await s.get_tree().create_timer(0.35).timeout
	_ask_step()


# ---------------------------------------------------------------- 手洗い

func _start_wash() -> void:
	phase = "wash"
	washes = 0
	s.walk_cat(Vector3(0.95, 0, 0.1), 0.0)
	Kit.play(s, "splash", 1.1, -10)
	tile_btns = s.tiles([{"text": tr(WASH_PARTS[0]), "sub": "1 / %d" % WASH_PARTS.size(), "color": Color("dff1ff"), "cb": _wash, "glow": hints()}], 1)
	s.task(tr("PR_KIT_TASK_WASH"), tr("PR_KIT_HINT_WASH"))
	s.say(tr("PR_KIT_SAY_WASH"))


func _wash(b: Control) -> void:
	if phase != "wash":
		return
	washes += 1
	s.suds_at(s.cat.position + Vector3(0, 0.45, 0.2))
	Kit.play(s, "pop", 1.0 + washes * 0.1, -8)
	s.hop(s.cat, 0.08)
	if washes < WASH_PARTS.size():
		(b as Button).text = tr(WASH_PARTS[washes]) + "\n%d / %d" % [washes + 1, WASH_PARTS.size()]
		return
	phase = ""
	s.walk_cat(Vector3(0.2, 0, 0.35), 0.0)
	_step_ok(tr("PR_KIT_GOOD_WASH"))


# ---------------------------------------------------------------- 帽子・伝票

func _put_cap() -> void:
	hat = Node3D.new()
	s.cyl3(0.2, 0.2, Vector3(0, 0.1, 0), Color("ffffff"), hat, 0.24)
	s.ball3(0.2, Vector3(0, 0.24, 0), Color("ffffff"), hat)
	hat.position = Vector3(0, 1.05, 0)
	s.cat.add_child(hat)
	s.pop_in(hat)
	Kit.play(s, "pop", 1.3, -6)
	_step_ok(tr("PR_KIT_GOOD_CAP"))


func _ticket_text() -> String:
	var adds: Array = ticket.adds.map(func(a): return tr("PR_ING_" + String(a).to_upper()))
	var t := tr("PR_DISH_NAME_" + String(ticket.dish).to_upper()) + "\n+ " + ", ".join(adds)
	if ticket.avoid != "":
		t += "\n" + tr("PR_KIT_NO") % tr("PR_ING_" + String(ticket.avoid).to_upper())
	return t


func _read_ticket() -> void:
	ticket_l.text = _ticket_text()
	ticket_l.font_size = 17
	s.order(_ticket_text())
	Kit.play(s, "tap", 0.9)
	_step_ok(tr("PR_KIT_GOOD_READ"))


# ---------------------------------------------------------------- 作る

func _start_cook() -> void:
	phase = "cook"
	added = []
	flame.visible = true
	s.walk_cat(Vector3(-0.3, 0, 0.3), -0.2)
	_cook_tiles()
	s.task(tr("PR_KIT_TASK_COOK"), tr("PR_KIT_HINT_COOK") if level < 3 else "")
	if s.order_box.visible == false:
		s.order(_ticket_text())


func _cook_tiles() -> void:
	var list: Array = []
	for k in PracticeData.INGREDIENTS:
		var ing: String = k
		var done: bool = ing in added
		list.append({"text": tr("PR_ING_" + ing.to_upper()), "color": Color("e2f3e6") if done else ING_COL[ing].lerp(Color.WHITE, 0.5), "cb": func(b): _add(ing, b), "glow": hints() and ing in ticket.adds and not done})
	tile_btns = s.tiles(list, 3)


func _add(ing: String, b: Control) -> void:
	if phase != "cook":
		return
	if ing == ticket.avoid:
		s.oops(tr("PR_KIT_OOPS_AVOID") % tr("PR_ING_" + ing.to_upper()), b)
		return
	if not ing in ticket.adds:
		s.oops(tr("PR_KIT_OOPS_NOT_ON_TICKET"), b)
		return
	if ing in added:
		s.oops(tr("PR_KIT_OOPS_ALREADY"), b)
		return
	added.append(ing)
	var m: MeshInstance3D = s.ball3(0.05, Vector3(-0.08 + added.size() * 0.05, 0.4, 0), ING_COL[ing], pan)
	s.move(m, Vector3(-0.1 + added.size() * 0.06, 0.07, 0.02 * added.size()), 0.25)
	s.create_tween().tween_property(m, "scale", Vector3(1.3, 0.5, 1.3), 0.25)
	Kit.play(s, "splash", 1.6, -12)
	s.hop(pan, 0.05)
	if added.size() < ticket.adds.size():
		_cook_tiles()
		return
	phase = ""
	flame.visible = false
	_step_ok(tr("PR_KIT_GOOD_COOK"))


func _plate() -> void:
	plate = Node3D.new()
	s.cyl3(0.16, 0.02, Vector3.ZERO, Color("fbfaf6"), plate, 0.18)
	plate.position = Vector3(0.2, 0.87, -0.45)
	s.props.add_child(plate)
	s.pop_in(plate)
	for c in pan.get_children():
		if c is MeshInstance3D and c.mesh is SphereMesh:
			c.reparent(plate)
			s.move(c, Vector3(randf_range(-0.05, 0.05), 0.03, randf_range(-0.04, 0.04)), 0.3)
	Kit.play(s, "chime", 1.3, -8)
	_step_ok(tr("PR_KIT_GOOD_PLATE"))


# ---------------------------------------------------------------- 台をふく

func _start_wipe() -> void:
	phase = "wipe"
	wipes = 0
	tile_btns = s.tiles([{"text": tr("PR_KIT_WIPE"), "sub": "0 / 3", "color": Color("eef3f7"), "cb": _wipe, "glow": hints()}], 1)
	s.task(tr("PR_KIT_TASK_WIPE"))


func _wipe(b: Control) -> void:
	if phase != "wipe":
		return
	wipes += 1
	s.sparkle_at(Vector3(-0.6 + wipes * 0.4, 0.95, -0.5))
	Kit.play(s, "tap", 1.2 + wipes * 0.1)
	(b as Button).text = tr("PR_KIT_WIPE") + "\n%d / 3" % wipes
	if wipes >= 3:
		phase = ""
		_step_ok()


# ---------------------------------------------------------------- 撮影・自動操作用

func demo_step() -> void:
	match phase:
		"step":
			_step(_want(), null)
		"wash":
			_wash(tile_btns[0])
		"cook":
			for a in ticket.adds:
				if not a in added:
					_add(a, null)
					return
		"wipe":
			_wipe(tile_btns[0])


func demo_wrong() -> void:
	if phase == "step" and _want() == "wash":
		_step("cook", tile_btns[0])
