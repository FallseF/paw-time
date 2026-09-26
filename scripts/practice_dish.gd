extends PracticeGame
## 皿洗いのおさらい：汚れの軽い物から洗う（グラス → お皿 → フライパン）、こすって、割らない場所に立てる。

const LOOK := {"glass": Color("cfeaff"), "plate": Color("fbfaf6"), "pan": Color("4a4a52")}

var phase := "" # pick / scrub / rack
var left: Array = [] # まだ洗っていない物
var cur := ""
var scrubs := 0
var bin: Node3D
var in_sink: Node3D
var racks := {} # rack → Node3D
var racked := {"cups": 0, "plates": 0, "hooks": 0}
var tile_btns: Array = []


func build() -> void:
	var p: Node3D = s.props
	s.frame(Vector3(0, 1.7, 3.4), Vector3(0, 0.35, -0.4))
	# 流し台（ステンレス）・水・たらい・水切りかご
	s.box3(Vector3(2.4, 0.8, 0.66), Vector3(0, 0.4, -0.55), Color("aeb8c2"), p)
	s.box3(Vector3(2.5, 0.06, 0.72), Vector3(0, 0.82, -0.55), Color("d5dde4"), p)
	s.box3(Vector3(0.8, 0.02, 0.44), Vector3(0, 0.85, -0.55), Color("6fa8d0"), p)
	s.box3(Vector3(0.06, 0.4, 0.06), Vector3(0, 1.05, -0.82), Color("c8ced6"), p)
	s.box3(Vector3(0.06, 0.06, 0.24), Vector3(0, 1.24, -0.72), Color("c8ced6"), p)
	# 洗い物のたらい（右）
	bin = Node3D.new()
	bin.position = Vector3(0.85, 0.86, -0.5)
	p.add_child(bin)
	s.cyl3(0.3, 0.16, Vector3(0, 0.08, 0), Color("7a8fa3"), bin, 0.34)
	# 水切り（左）：グラスは逆さに、お皿は立てて、フライパンは壁のフック
	racks.cups = s.box3(Vector3(0.36, 0.05, 0.3), Vector3(-0.95, 0.88, -0.55), Color("e0e6ec"), p)
	racks.plates = Node3D.new()
	racks.plates.position = Vector3(-0.55, 0.86, -0.55)
	p.add_child(racks.plates)
	for i in 5:
		s.box3(Vector3(0.015, 0.18, 0.3), Vector3(-0.12 + i * 0.06, 0.09, 0), Color("e0e6ec"), racks.plates)
	racks.hooks = s.box3(Vector3(0.9, 0.05, 0.06), Vector3(-0.7, 1.6, -1.8), Color("8a8f98"), p)
	s.label3(tr("PR_DISH_RACK_CUPS"), Vector3(-0.95, 1.05, -0.3), 22, Color("4a5a6a"), p)
	s.label3(tr("PR_DISH_RACK_PLATES"), Vector3(-0.55, 1.12, -0.3), 22, Color("4a5a6a"), p)
	s.label3(tr("PR_DISH_RACK_HOOKS"), Vector3(-0.7, 1.82, -1.7), 22, Color("4a5a6a"), p)
	left = rounds.duplicate()
	for i in left.size():
		var m := _item(left[i], true)
		m.position = Vector3(-0.12 + (i % 3) * 0.12, 0.12 + (i / 3) * 0.07, -0.05 + (i % 2) * 0.1)
		m.rotation.z = (i % 3 - 1) * 0.35
		m.name = "D%d" % i
		bin.add_child(m)
	s.cat.position = Vector3(0.15, 0, 0.35)
	s.cat.rotation.y = -0.2


func _item(kind: String, dirty: bool) -> Node3D:
	var n := Node3D.new()
	match kind:
		"glass":
			var g: MeshInstance3D = s.cyl3(0.05, 0.14, Vector3(0, 0.07, 0), LOOK.glass, n, 0.058)
			g.material_override = Obake3D.toon(LOOK.glass, 0.9, 0.08)
		"plate":
			s.cyl3(0.13, 0.02, Vector3(0, 0.01, 0), LOOK.plate, n, 0.15)
			s.cyl3(0.08, 0.021, Vector3(0, 0.011, 0), Color("e8e2d8"), n)
		_:
			s.cyl3(0.14, 0.05, Vector3(0, 0.025, 0), LOOK.pan, n, 0.16)
			var h: MeshInstance3D = s.box3(Vector3(0.22, 0.025, 0.04), Vector3(0.25, 0.04, 0), Color("2e2a2a"), n)
			h.rotation.z = 0.15
	if dirty:
		var sp := Node3D.new()
		sp.name = "Dirt"
		n.add_child(sp)
		for i in 3:
			s.ball3(0.018 + i * 0.004, Vector3(-0.04 + i * 0.04, 0.05 if kind != "plate" else 0.03, 0.03 * (i % 2)), Color("a0733f") if kind != "glass" else Color("c9b48a"), sp)
	return n


func total_steps() -> int:
	return rounds.size()


func begin() -> void:
	_ask_pick()


func _counts() -> Dictionary:
	var c := {"glass": 0, "plate": 0, "pan": 0}
	for k in left:
		c[k] += 1
	return c


# ---------------------------------------------------------------- 1. 次に洗う物

func _ask_pick() -> void:
	phase = "pick"
	var c := _counts()
	var nx := PracticeData.dish_next(left)
	var list: Array = []
	for k in PracticeData.DISH_ORDER:
		var kind: String = k
		if c[kind] > 0:
			list.append({"text": tr("PR_DISH_" + kind.to_upper()), "sub": "×%d" % c[kind], "color": LOOK[kind].lerp(Color("fff8ea"), 0.4) if kind != "pan" else Color("8a8f98"), "cb": func(b): _pick(kind, b), "glow": hints() and kind == nx})
	tile_btns = s.tiles(list, list.size())
	s.task(tr("PR_DISH_TASK_PICK"), tr("PR_DISH_HINT_ORDER") if level < 3 else "")


func _pick(kind: String, b: Control) -> void:
	if phase != "pick":
		return
	if kind != PracticeData.dish_next(left):
		s.oops(tr("PR_DISH_OOPS_ORDER_" + PracticeData.dish_next(left).to_upper()), b)
		return
	left.erase(kind)
	cur = kind
	# たらいから流しへ
	for c in bin.get_children():
		if c.name.begins_with("D") and _kind_of(c) == kind:
			in_sink = c
			break
	in_sink.name = "Washing"
	in_sink.reparent(s.props)
	s.move(in_sink, Vector3(0, 0.92, -0.5), 0.35)
	in_sink.rotation = Vector3.ZERO
	Kit.play(s, "splash", 1.2, -10)
	scrubs = 0
	phase = "scrub"
	var need := _need_scrubs()
	tile_btns = s.tiles([{"text": tr("PR_DISH_SCRUB"), "sub": "0 / %d" % need, "color": Color("dff1ff"), "cb": _scrub, "glow": hints()}], 1)
	s.task(tr("PR_DISH_TASK_SCRUB") % tr("PR_DISH_" + kind.to_upper()), tr("PR_DISH_HINT_SCRUB"))


func _kind_of(n: Node) -> String:
	var i := int(String(n.name).substr(1))
	return rounds[i] if i < rounds.size() else ""


func _need_scrubs() -> int:
	return 2 if cur == "glass" else (3 if cur == "plate" else 4)


# ---------------------------------------------------------------- 2. こする

func _scrub(b: Control) -> void:
	if phase != "scrub":
		return
	scrubs += 1
	s.suds_at(Vector3(0, 1.0, -0.45))
	Kit.play(s, "pop", 1.0 + scrubs * 0.12, -8)
	var tw: Tween = s.create_tween()
	tw.tween_property(s.cat, "rotation:y", 0.25, 0.08)
	tw.tween_property(s.cat, "rotation:y", -0.45, 0.1)
	tw.tween_property(s.cat, "rotation:y", -0.2, 0.08)
	var dirt: Node = in_sink.get_node_or_null("Dirt")
	if dirt and dirt.get_child_count() > 0:
		var d: Node3D = dirt.get_child(0)
		dirt.remove_child(d) # 数え直しのため、すぐに外す
		d.queue_free()
	var need := _need_scrubs()
	(b as Button).text = tr("PR_DISH_SCRUB") + "\n%d / %d" % [scrubs, need]
	if scrubs < need:
		return
	if dirt:
		dirt.queue_free()
	s.good(tr("PR_DISH_GOOD_CLEAN"))
	phase = "rack"
	var list: Array = []
	var ok: String = PracticeData.DISH_RACK[cur]
	for r in ["cups", "plates", "hooks"]:
		var rk: String = r
		list.append({"text": tr("PR_DISH_RACK_" + rk.to_upper()), "sub": tr("PR_DISH_RACK_SUB_" + rk.to_upper()), "color": Color("eef3f7"), "cb": func(bt): _rack(rk, bt), "glow": hints() and rk == ok})
	await s.get_tree().create_timer(0.3).timeout
	tile_btns = s.tiles(list, 3)
	s.task(tr("PR_DISH_TASK_RACK"), tr("PR_DISH_HINT_RACK") if level < 3 else "")


# ---------------------------------------------------------------- 3. 割らない置き場所

func _rack(r: String, b: Control) -> void:
	if phase != "rack":
		return
	if r != PracticeData.DISH_RACK[cur]:
		s.oops(tr("PR_DISH_OOPS_RACK_" + cur.to_upper()), b)
		var y := in_sink.position.y
		var tw: Tween = s.create_tween()
		tw.tween_property(in_sink, "rotation:z", 0.25, 0.08)
		tw.tween_property(in_sink, "rotation:z", -0.2, 0.1)
		tw.tween_property(in_sink, "rotation:z", 0.0, 0.08)
		in_sink.position.y = y
		return
	phase = ""
	var n: int = racked[r]
	racked[r] += 1
	var to: Vector3
	var rot := Vector3.ZERO
	match r:
		"cups":
			to = Vector3(-1.05 + (n % 3) * 0.1, 1.05, -0.62 + (n / 3) * 0.12)
			rot = Vector3(PI, 0, 0) # 逆さに
		"plates":
			to = Vector3(-0.64 + n * 0.06, 0.99, -0.55)
			rot = Vector3(0, 0, PI / 2) # 立てて
		_:
			to = Vector3(-0.95 + n * 0.3, 1.36, -1.72)
			rot = Vector3(PI / 2, 0, 0)
	var tw: Tween = s.move(in_sink, to, 0.4)
	s.create_tween().tween_property(in_sink, "rotation", rot, 0.35)
	Kit.play(s, "chime", 1.1 + n * 0.05, -8)
	s.step_done()
	await tw.finished
	if left.is_empty():
		s.good(tr("PR_DISH_GOOD_ALL"))
		s.finish()
	else:
		s.good()
		_ask_pick()


# ---------------------------------------------------------------- 撮影・自動操作用

func demo_step() -> void:
	match phase:
		"pick":
			_pick(PracticeData.dish_next(left), null)
		"scrub":
			_scrub(tile_btns[0])
		"rack":
			_rack(PracticeData.DISH_RACK[cur], null)


func demo_wrong() -> void:
	if phase == "pick":
		for k in ["pan", "plate"]:
			if k in left and k != PracticeData.dish_next(left):
				_pick(k, tile_btns[0])
				return
