extends PracticeGame
## 品出しのおさらい：先入れ先出し（日付の古い物を前、新しい物を奥）→ 前出し（ラベルを正面にそろえる）。
## ★3 では、たなの物より古い日付の箱が届くことがある（そのときは前へ）。

const CARTON_COLS := [Color("5fa8ff"), Color("ff8fb1"), Color("8fd18a"), Color("ffc23d"), Color("a98bff")]
const LANE_X := [-0.72, -0.36, 0.0, 0.36, 0.72]

var phase := "" # box / face
var cur := 0
var lanes: Array = [] # 箱の回ごとの、前の品
var incoming: Node3D
var turned: Array = []
var faced := 0
var tile_btns: Array = []


func build() -> void:
	var p: Node3D = s.props
	s.frame(Vector3(0.1, 1.75, 3.6), Vector3(0.1, 0.42, -0.5))
	# たな（2 段）。上の段に先入れ先出しの列、下の段は前出しする品
	s.box3(Vector3(2.0, 1.5, 0.08), Vector3(0, 0.75, -1.25), Color("9a7458"), p)
	for y in [0.35, 0.95]:
		s.box3(Vector3(2.0, 0.05, 0.62), Vector3(0, y, -0.94), Color("b58a66"), p)
		s.box3(Vector3(2.0, 0.08, 0.02), Vector3(0, y + 0.03, -0.62), Color("f2b233"), p) # 値札のレール
	for x in [-1.0, 1.0]:
		s.box3(Vector3(0.06, 1.5, 0.64), Vector3(x, 0.75, -0.94), Color("8a6448"), p)
	var boxes := 0
	for r in rounds:
		if r.kind == "box":
			var c := _carton(CARTON_COLS[boxes % CARTON_COLS.size()], PracticeData.date_text(int(r.shelf_date)))
			c.position = Vector3(LANE_X[boxes], 0.98, -0.8)
			p.add_child(c)
			lanes.append(c)
			boxes += 1
		else:
			for i in int(r.n) + 2:
				var c := _carton(CARTON_COLS[(i + 2) % CARTON_COLS.size()], "")
				c.position = Vector3(-0.75 + i * 0.3, 0.38, -0.8 if i >= int(r.n) else -1.0)
				if i < int(r.n):
					c.rotation.y = 1.1 if i % 2 == 0 else -1.2
					turned.append(c)
				p.add_child(c)
	# 台車（右）
	s.box3(Vector3(0.6, 0.05, 0.45), Vector3(1.25, 0.3, 0.2), Color("6b8f5a"), p)
	for x in [1.02, 1.48]:
		for z in [0.4, 0.0]:
			var wheel: MeshInstance3D = s.cyl3(0.06, 0.04, Vector3(x, 0.06, z), Color("3a3a42"), p)
			wheel.rotation.x = PI / 2
	s.box3(Vector3(0.04, 0.7, 0.04), Vector3(1.52, 0.65, 0.2), Color("6b8f5a"), p)
	s.cat.position = Vector3(-1.05, 0, 0.35)
	s.cat.rotation.y = 0.6


## 牛乳パックの形（屋根つき）。date が空なら無地
func _carton(c: Color, date: String) -> Node3D:
	var n := Node3D.new()
	s.box3(Vector3(0.18, 0.26, 0.16), Vector3(0, 0.13, 0), Color("fbfaf6"), n)
	s.box3(Vector3(0.182, 0.1, 0.162), Vector3(0, 0.08, 0), c, n)
	var roof := MeshInstance3D.new()
	var pr := PrismMesh.new()
	pr.size = Vector3(0.18, 0.08, 0.16)
	roof.mesh = pr
	roof.material_override = Obake3D.toon(c.lightened(0.2), 0.2)
	roof.rotation.y = PI / 2
	roof.position = Vector3(0, 0.3, 0)
	n.add_child(roof)
	if date != "":
		var l := Kit.label3d(date, 22, Color("2a2233"))
		l.position = Vector3(0, 0.2, 0.085)
		l.pixel_size = 0.004
		l.outline_size = 0
		l.name = "Date"
		n.add_child(l)
	return n


func total_steps() -> int:
	return rounds.size()


func begin() -> void:
	cur = 0
	_next()


func _next() -> void:
	if cur >= rounds.size():
		s.good(tr("PR_STOCK_GOOD_ALL"))
		s.finish()
		return
	var r: Dictionary = rounds[cur]
	if r.kind == "box":
		_box_in(r)
	else:
		_face_in(r)


# ---------------------------------------------------------------- 先入れ先出し

func _box_in(r: Dictionary) -> void:
	phase = ""
	incoming = _carton(CARTON_COLS[cur % CARTON_COLS.size()], PracticeData.date_text(int(r.date)))
	incoming.position = Vector3(2.6, 0.33, 0.2)
	s.props.add_child(incoming)
	var tw: Tween = s.move(incoming, Vector3(1.25, 0.33, 0.2), 0.5)
	Kit.play(s, "lift", 1.1, -8)
	var lane: Node3D = lanes[cur]
	s.hop(lane, 0.06)
	await tw.finished
	phase = "box"
	s.order(tr("PR_STOCK_DATES") % [PracticeData.date_text(int(r.shelf_date)), PracticeData.date_text(int(r.date))])
	s.say(tr("PR_STOCK_SAY_BOX"))
	var ok: String = r.ok
	tile_btns = s.tiles([
		{"text": tr("PR_STOCK_FRONT"), "sub": tr("PR_STOCK_FRONT_SUB"), "color": Color("fff3d6"), "cb": func(b): _place("front", b), "glow": hints() and ok == "front"},
		{"text": tr("PR_STOCK_BACK"), "sub": tr("PR_STOCK_BACK_SUB"), "color": Color("e6efe0"), "cb": func(b): _place("back", b), "glow": hints() and ok == "back"},
	], 2)
	s.task(tr("PR_STOCK_TASK_BOX"), tr("PR_STOCK_HINT_FIFO") if level < 3 else "")


func _place(where: String, b: Control) -> void:
	if phase != "box":
		return
	var r: Dictionary = rounds[cur]
	if where != r.ok:
		s.oops(tr("PR_STOCK_OOPS_BACK") if r.ok == "back" else tr("PR_STOCK_OOPS_FRONT"), b)
		return
	phase = ""
	s.order("")
	var lane: Node3D = lanes[cur]
	var x: float = LANE_X[cur]
	s.walk_cat(Vector3(x - 0.35, 0, 0.1), 0.3)
	if where == "back":
		s.move(incoming, Vector3(x, 0.98, -1.1), 0.45)
	else:
		s.move(lane, Vector3(x, 0.98, -1.1), 0.35)
		s.move(incoming, Vector3(x, 0.98, -0.8), 0.5)
	Kit.play(s, "pop", 1.2, -6)
	s.step_done()
	await s.get_tree().create_timer(0.6).timeout
	s.good(tr("PR_STOCK_GOOD_BOX"))
	cur += 1
	_next()


# ---------------------------------------------------------------- 前出し

func _face_in(r: Dictionary) -> void:
	phase = "face"
	faced = 0
	s.walk_cat(Vector3(-0.9, 0, 0.3), 0.2)
	s.say(tr("PR_STOCK_SAY_FACE"))
	tile_btns = s.tiles([{"text": tr("PR_STOCK_FACE"), "sub": "0 / %d" % int(r.n), "color": Color("fff3d6"), "cb": _face, "glow": hints()}], 1)
	s.task(tr("PR_STOCK_TASK_FACE"), tr("PR_STOCK_HINT_FACE"))


func _face(b: Control) -> void:
	if phase != "face" or faced >= turned.size():
		return
	var c: Node3D = turned[faced]
	faced += 1
	var tw: Tween = s.create_tween().set_parallel()
	tw.tween_property(c, "rotation:y", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "position:z", -0.8, 0.3)
	s.sparkle_at(c.position + Vector3(0, 0.3, 0.1))
	Kit.play(s, "pop", 1.1 + faced * 0.1, -6)
	(b as Button).text = tr("PR_STOCK_FACE") + "\n%d / %d" % [faced, turned.size()]
	if faced < turned.size():
		return
	phase = ""
	s.step_done()
	cur += 1
	await s.get_tree().create_timer(0.4).timeout
	_next()


# ---------------------------------------------------------------- 撮影・自動操作用

func demo_step() -> void:
	match phase:
		"box":
			_place(rounds[cur].ok, null)
		"face":
			_face(tile_btns[0])


func demo_wrong() -> void:
	if phase == "box":
		_place("front" if rounds[cur].ok == "back" else "back", tile_btns[0])
