extends PracticeGame
## ホールのおさらい：お客さんを席へ案内する（座れる中でいちばん小さい席）→ 伝票の番号の席へ、料理を運ぶ。

const TABLE_POS := {1: Vector3(-0.75, 0, -0.55), 2: Vector3(0.35, 0, -0.75), 3: Vector3(1.35, 0, -0.35)}
const GUESTS := ["bubble", "tray", "receipt", "box", "pan", "nemuri"]

var phase := "" # seat / carry
var cur := 0
var free: Array = [1, 2, 3]
var group_table: Array = [] # 何組目 → 座った席
var guests: Array = [] # いま入口にいる組のおばけたち
var dish: Node3D
var home := Vector3(-1.2, 0, 0.5)
var tile_btns: Array = []


func build() -> void:
	var p: Node3D = s.props
	s.frame(Vector3(-0.05, 2.1, 4.5), Vector3(-0.05, 0.25, -0.3))
	# 丸いテーブルといす（座れる人数だけ）・席の番号札
	for t in TABLE_POS:
		var pos: Vector3 = TABLE_POS[t]
		var seats: int = PracticeData.TABLES[t]
		s.cyl3(0.32 + seats * 0.03, 0.05, pos + Vector3(0, 0.62, 0), Color("b07a4a"), p)
		s.cyl3(0.05, 0.6, pos + Vector3(0, 0.3, 0), Color("7a4e32"), p)
		s.cyl3(0.2, 0.03, pos + Vector3(0, 0.015, 0), Color("7a4e32"), p)
		for i in seats:
			var a := TAU * i / seats + 0.4
			s.cyl3(0.1, 0.32, pos + Vector3(cos(a) * 0.52, 0.16, sin(a) * 0.42), Color("d98a5b"), p)
		var sign: Label3D = s.label3(str(t), pos + Vector3(0, 0.95, 0), 64, Color("2a2233"), p)
		sign.name = "Sign%d" % t
		s.cyl3(0.012, 0.28, pos + Vector3(0, 0.78, 0), Color("7a4e32"), p)
	# 料理の受け渡し口（左奥）と入口（右手前）
	s.box3(Vector3(0.9, 0.9, 0.45), Vector3(-1.55, 0.45, -1.35), Color("c4c9cf"), p)
	s.box3(Vector3(1.0, 0.05, 0.5), Vector3(-1.55, 0.92, -1.35), Color("e8ecef"), p)
	var lamp: MeshInstance3D = s.box3(Vector3(0.7, 0.06, 0.2), Vector3(-1.55, 1.5, -1.35), Color("ff9a4d"), p)
	lamp.material_override = Kit.glow(Color("ffb070"), 0.9)
	s.label3(tr("PR_HALL_PASS"), Vector3(-1.55, 1.72, -1.3), 24, Color("6a5f70"), p)
	s.box3(Vector3(0.08, 1.9, 0.9), Vector3(2.1, 0.95, 0.4), Color("d9b48c"), p)
	s.cat.position = home
	s.cat.rotation.y = 0.4


func total_steps() -> int:
	return rounds.size()


func begin() -> void:
	cur = 0
	_next()


func _next() -> void:
	if cur >= rounds.size():
		s.good(tr("PR_HALL_GOOD_ALL"))
		s.finish()
		return
	var r: Dictionary = rounds[cur]
	if r.kind == "seat":
		_seat_in(int(r.size))
	else:
		_carry_in(r)


func _table_tiles(cb: Callable, glow: Array) -> void:
	var list: Array = []
	for t in [1, 2, 3]:
		var tt: int = t
		var taken := not tt in free
		list.append({"text": tr("PR_HALL_TABLE") % tt, "sub": tr("PR_HALL_TAKEN") if taken and phase == "seat" else tr("PR_HALL_SEATS") % PracticeData.TABLES[tt], "color": Color("ece6de") if taken and phase == "seat" else Color("f1eaff"), "cb": func(b): cb.call(tt, b), "glow": hints() and tt in glow})
	tile_btns = s.tiles(list, 3)


# ---------------------------------------------------------------- 1. 席へ案内

func _seat_in(n: int) -> void:
	phase = ""
	guests = []
	s.tiles([], 3)
	s.task(tr("PR_HALL_TASK_SEAT"))
	for i in n:
		var g := Obake3D.make(GUESTS[(cur + i) % GUESTS.size()])
		g.scale = Vector3.ONE * 0.36
		g.position = Vector3(2.9 + i * 0.25, 0, 0.75 + (i % 2) * 0.2)
		g.rotation.y = -1.4
		s.world.add_child(g)
		guests.append(g)
		s.move(g, Vector3(1.75 - i * 0.02, 0, 0.55 + i * 0.22 - n * 0.08), 0.5 + i * 0.08)
	Kit.play(s, "bell", 1.1, -8)
	await s.get_tree().create_timer(0.55).timeout
	phase = "seat"
	s.order(tr("PR_HALL_GROUP_1") if n == 1 else tr("PR_HALL_GROUP_N") % n)
	s.say(tr("PR_HALL_SAY_WELCOME"))
	_table_tiles(_seat, PracticeData.seat_ok(n, free))
	s.task(tr("PR_HALL_TASK_SEAT"), tr("PR_HALL_HINT_SEAT") if level < 3 else "")


func _seat(t: int, b: Control) -> void:
	if phase != "seat":
		return
	var n := guests.size()
	if not t in free:
		s.oops(tr("PR_HALL_OOPS_TAKEN"), b)
		return
	if int(PracticeData.TABLES[t]) < n:
		s.oops(tr("PR_HALL_OOPS_SMALL") % PracticeData.TABLES[t], b)
		return
	if not t in PracticeData.seat_ok(n, free):
		s.oops(tr("PR_HALL_OOPS_BIG"), b)
		return
	phase = ""
	free.erase(t)
	group_table.append(t)
	s.order("")
	s.say(tr("PR_HALL_SAY_THIS_WAY"))
	var pos: Vector3 = TABLE_POS[t]
	s.walk_cat(pos + Vector3(-0.55, 0, 0.55), 0.6)
	var seats: int = PracticeData.TABLES[t]
	for i in n:
		var a := TAU * i / seats + 0.4
		var g: Obake3D = guests[i]
		g.set_meta("table", t)
		var tw: Tween = s.move(g, pos + Vector3(cos(a) * 0.52, 0.3, sin(a) * 0.42), 0.6 + i * 0.1)
		tw.parallel().tween_property(g, "rotation:y", atan2(-cos(a), -sin(a)), 0.4)
	Kit.play(s, "chime", 1.1, -6)
	s.step_done()
	await s.get_tree().create_timer(0.9).timeout
	s.good()
	s.walk_cat(home, 0.4)
	cur += 1
	await s.get_tree().create_timer(0.4).timeout
	_next()


# ---------------------------------------------------------------- 2. 料理を運ぶ

func _target(r: Dictionary) -> int:
	var gi := int(r.get("group", 0))
	return group_table[gi] if gi < group_table.size() else int(r.table)


func _carry_in(r: Dictionary) -> void:
	phase = ""
	var t := _target(r)
	dish = Node3D.new()
	s.cyl3(0.14, 0.02, Vector3.ZERO, Color("fbfaf6"), dish, 0.16)
	s.ball3(0.08, Vector3(0, 0.04, 0), Color("ff9a3d") if r.dish != "PR_HALL_DISH_SALAD" else Color("8fd18a"), dish)
	dish.position = Vector3(-1.55, 0.97, -1.3)
	s.props.add_child(dish)
	s.pop_in(dish)
	Kit.play(s, "bell", 1.4, -8)
	s.order(tr("PR_HALL_TICKET") % [t, tr(r.dish)])
	s.say(tr("PR_HALL_SAY_UP"))
	s.tiles([], 3)
	s.task(tr("PR_HALL_TASK_CARRY"))
	s.walk_cat(Vector3(-1.4, 0, -0.75), PI * 0.9)
	await s.get_tree().create_timer(0.5).timeout
	# 相棒が料理を頭のお盆にのせる
	if is_instance_valid(dish):
		dish.reparent(s.cat)
		dish.position = Vector3(0, 1.25, 0)
		dish.scale = Vector3.ONE * 1.4
	s.walk_cat(home, 0.4)
	phase = "carry"
	_table_tiles(_carry, [t])
	s.task(tr("PR_HALL_TASK_CARRY"), tr("PR_HALL_HINT_CARRY") if level < 3 else "")


func _carry(t: int, b: Control) -> void:
	if phase != "carry":
		return
	var want := _target(rounds[cur])
	if t != want:
		s.oops(tr("PR_HALL_OOPS_TABLE") % want, b)
		return
	phase = ""
	s.order("")
	var pos: Vector3 = TABLE_POS[t]
	var tw: Tween = s.walk_cat(pos + Vector3(-0.5, 0, 0.5), 0.7)
	await tw.finished
	if is_instance_valid(dish):
		dish.reparent(s.props)
		s.move(dish, pos + Vector3(0.05, 0.68, 0.12), 0.3)
		s.create_tween().tween_property(dish, "scale", Vector3.ONE, 0.3)
	s.say(tr("PR_HALL_SAY_SERVE"))
	for g in s.world.get_children():
		if g is Obake3D and g.has_meta("table") and int(g.get_meta("table")) == t:
			s.hop(g, 0.15)
	Kit.play(s, "chime", 1.2, -6)
	s.step_done()
	await s.get_tree().create_timer(0.8).timeout
	s.good()
	s.walk_cat(home, 0.4)
	cur += 1
	await s.get_tree().create_timer(0.4).timeout
	_next()


# ---------------------------------------------------------------- 撮影・自動操作用

func demo_step() -> void:
	match phase:
		"seat":
			_seat(PracticeData.seat_ok(guests.size(), free)[0], null)
		"carry":
			_carry(_target(rounds[cur]), null)


func demo_wrong() -> void:
	if phase == "seat":
		for t in [2, 1, 3]:
			if t in free and not t in PracticeData.seat_ok(guests.size(), free):
				_seat(t, tile_btns[t - 1])
				return
