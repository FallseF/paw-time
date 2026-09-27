extends PracticeGame
## レジのおさらい：注文を聞く → 品をそろえる → おつりを渡す → 「ありがとうございました、またどうぞ！」
## どの店でも通じる流れだけ（特定の店のレジの操作や決まり文句は入れない）。

const CUSTOMERS := ["receipt", "tray", "bubble", "box", "pan"]
const COIN_COL := {1000: Color("cfe3c4"), 500: Color("e8c35a"), 100: Color("d9dde3"), 50: Color("e6e9ee"), 10: Color("c98552")}
## ドル：札はみどり、25¢・10¢ は銀
const COIN_COL_USD := {1000: Color("c4dcb8"), 500: Color("cfe3c4"), 100: Color("d8e8cf"), 25: Color("d9dde3"), 10: Color("e6e9ee")}

var phase := "" # order / change / phrase
var cur := 0
var picked := {} # id → こ数
var given: Array = []
var customer: Obake3D
var screen_l: Label3D
var tray_items: Node3D
var change_tray: Node3D
var change_l: Label
var tile_btns: Array = []
var money := Money.JPY # この回の通貨（はじめたときの言語で決まる。注文の currency と同じ）


func build() -> void:
	if not rounds.is_empty():
		money = String(rounds[0].get("currency", Money.JPY))
	var p: Node3D = s.props
	# カウンター（天板は明るい木）・レジ・品を置くトレー・おつりの皿
	s.frame(Vector3(0, 1.6, 3.7), Vector3(0, 0.28, -0.3))
	s.box3(Vector3(1.6, 0.78, 0.62), Vector3(0.05, 0.39, -0.45), Color("8f6a4c"), p)
	s.box3(Vector3(1.7, 0.07, 0.72), Vector3(0.05, 0.8, -0.43), Color("e9d3b0"), p)
	s.box3(Vector3(1.6, 0.08, 0.04), Vector3(0.05, 0.6, -0.13), Color("b5855f"), p)
	for i in 4: # 前板の飾り
		s.box3(Vector3(0.3, 0.46, 0.03), Vector3(-0.51 + i * 0.37, 0.36, -0.13), Color("9c7555"), p)
	var reg := Node3D.new()
	reg.position = Vector3(-0.42, 0.84, -0.52)
	p.add_child(reg)
	s.box3(Vector3(0.52, 0.2, 0.42), Vector3(0, 0.1, 0), Color("5b6f8f"), reg)
	s.box3(Vector3(0.5, 0.04, 0.3), Vector3(0, 0.215, 0.04), Color("3d4a63"), reg)
	for i in 3:
		for j in 3:
			s.box3(Vector3(0.07, 0.03, 0.06), Vector3(-0.1 + i * 0.1, 0.24, -0.02 + j * 0.08), Color("f4efe6"), reg)
	s.box3(Vector3(0.05, 0.28, 0.05), Vector3(0.14, 0.32, -0.12), Color("3d4a63"), reg)
	var scr: MeshInstance3D = s.box3(Vector3(0.4, 0.22, 0.05), Vector3(0.1, 0.52, -0.12), Color("2c3548"), reg)
	scr.rotation.x = -0.25
	var glass := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.34, 0.16)
	glass.mesh = qm
	glass.material_override = Kit.glow(Color("9fe0a0"), 0.7)
	glass.position = Vector3(0.1, 0.52, -0.09)
	glass.rotation.x = -0.25
	reg.add_child(glass)
	screen_l = Kit.label3d(_m(0), 30, Color("1f4a2a"))
	screen_l.position = Vector3(0.1, 0.52, -0.075)
	screen_l.rotation.x = -0.25
	screen_l.pixel_size = 0.0035
	screen_l.outline_size = 0
	reg.add_child(screen_l)
	tray_items = Node3D.new()
	tray_items.position = Vector3(0.2, 0.84, -0.46)
	p.add_child(tray_items)
	s.box3(Vector3(0.56, 0.03, 0.36), Vector3(0, 0.0, 0), Color("c9563f"), tray_items)
	change_tray = Node3D.new()
	change_tray.position = Vector3(0.62, 0.84, -0.22)
	p.add_child(change_tray)
	s.cyl3(0.24, 0.03, Vector3.ZERO, Color("f4efe6"), change_tray, 0.27)
	# 奥の壁のメニュー（黒板）
	var board: MeshInstance3D = s.box3(Vector3(1.5, 0.8, 0.06), Vector3(0.35, 1.72, -1.85), Color("3f5d49"), p)
	s.box3(Vector3(1.6, 0.9, 0.04), Vector3(0.35, 1.72, -1.89), Color("a0673f"), p)
	board.name = "Menu"
	for i in PracticeData.MENU.size():
		var m: Dictionary = PracticeData.MENU[i]
		var x := 0.0 if i < 3 else 0.7
		var l: Label3D = s.label3(tr("PR_ITEM_" + String(m.id).to_upper()) + "  " + _m(PracticeData.price_of(m.id, money)), Vector3(x, 1.95 - (i % 3) * 0.22, -1.8), 24, Color("fffaf0"), p)
		l.outline_size = 0
	# 相棒はカウンターの左、お客さんは右から来る
	s.cat.position = Vector3(-0.98, 0, 0.2)
	s.cat.rotation.y = 0.7


func total_steps() -> int:
	return rounds.size()


func begin() -> void:
	cur = 0
	_customer_in()


func _order() -> Dictionary:
	return rounds[cur]


# ---------------------------------------------------------------- お客さん

func _customer_in() -> void:
	phase = ""
	picked = {}
	given = []
	for c in tray_items.get_children():
		if c is Node3D and c.get_index() > 0:
			c.queue_free()
	for c in change_tray.get_children():
		if c.get_index() > 0:
			c.queue_free()
	screen_l.text = _m(0)
	customer = Obake3D.make(CUSTOMERS[cur % CUSTOMERS.size()])
	customer.scale = Vector3.ONE * 0.55
	customer.position = Vector3(2.4, 0, 0.45)
	customer.rotation.y = -1.3
	s.world.add_child(customer)
	s.order_anchor = customer
	s.tiles([], 2)
	s.task(tr("PR_REG_WAIT"))
	var tw: Tween = s.move(customer, Vector3(1.0, 0, 0.3), 0.6)
	await tw.finished
	if not is_instance_valid(customer):
		return
	customer.rotation.y = -0.6
	Kit.play(s, "bell", 1.2, -8)
	s.order(tr("PR_REG_ORDER") % PracticeData.order_text(_order()))
	s.say(tr("PR_REG_SAY_ORDER"))
	_show_menu()


# ---------------------------------------------------------------- 1. 品をそろえる

func _show_menu() -> void:
	phase = "order"
	var list: Array = []
	var want := _wanted()
	for m in PracticeData.MENU:
		var id: String = m.id
		list.append({"text": tr("PR_ITEM_" + id.to_upper()), "sub": _m(PracticeData.price_of(id, money)), "color": Color(m.c).lerp(Color.WHITE, 0.55), "cb": func(b): _pick(id, b), "glow": hints() and want.has(id)})
	tile_btns = s.tiles(list, 3)
	s.task(tr("PR_REG_TASK_ITEMS"), tr("PR_REG_HINT_ITEMS") if level < 3 else "")


func _wanted() -> Dictionary:
	var w := {}
	for it in _order().items:
		w[it.id] = int(it.qty) - int(picked.get(it.id, 0))
	return w


func _pick(id: String, b: Control) -> void:
	if phase != "order":
		return
	var w := _wanted()
	if int(w.get(id, 0)) <= 0:
		s.oops(tr("PR_REG_OOPS_ITEM") if not w.has(id) else tr("PR_REG_OOPS_ENOUGH"), b)
		return
	picked[id] = int(picked.get(id, 0)) + 1
	var n := 0
	for k in picked:
		n += int(picked[k])
	var mesh := _item_mesh(id)
	mesh.position = Vector3(-0.2 + ((n - 1) % 3) * 0.2, 0.02, 0.0 if n <= 3 else 0.12)
	tray_items.add_child(mesh)
	s.pop_in(mesh)
	Kit.play(s, "pop", 1.2 + n * 0.08, -6)
	s.hop(s.cat, 0.12)
	# 全部そろった？
	var left := 0
	for k in _wanted().values():
		left += maxi(0, int(k))
	if left > 0:
		return
	s.good(tr("PR_REG_GOOD_ITEMS"))
	await s.get_tree().create_timer(0.45).timeout
	_ring_up()


## 品の 3D（カップ・グラス・クッキー・サンド・おにぎり）
func _item_mesh(id: String) -> Node3D:
	var n := Node3D.new()
	match id:
		"coffee", "tea":
			s.cyl3(0.06, 0.12, Vector3(0, 0.06, 0), Color("fffaf2"), n, 0.07)
			s.cyl3(0.062, 0.01, Vector3(0, 0.12, 0), Color("6b4128") if id == "coffee" else Color("d99a3a"), n)
			var h: MeshInstance3D = s.cyl3(0.03, 0.02, Vector3(0.075, 0.07, 0), Color("fffaf2"), n)
			h.rotation.z = PI / 2
		"juice":
			s.cyl3(0.05, 0.18, Vector3(0, 0.09, 0), Color("ff9a3d"), n, 0.055)
			s.cyl3(0.008, 0.12, Vector3(0.02, 0.2, 0), Color("ff5b6b"), n)
		"cookie":
			s.cyl3(0.08, 0.025, Vector3(0, 0.015, 0), Color("c98d4f"), n)
			for i in 3:
				s.ball3(0.012, Vector3(-0.03 + i * 0.03, 0.03, -0.02 + (i % 2) * 0.04), Color("4a2e1c"), n)
		"sandwich":
			var pm := MeshInstance3D.new()
			var pr := PrismMesh.new()
			pr.size = Vector3(0.18, 0.12, 0.06)
			pm.mesh = pr
			pm.material_override = Obake3D.toon(Color("f2d58c"), 0.2)
			pm.position = Vector3(0, 0.06, 0)
			n.add_child(pm)
			s.box3(Vector3(0.12, 0.02, 0.065), Vector3(0, 0.04, 0), Color("8fd18a"), n)
		_: # onigiri
			var om := MeshInstance3D.new()
			var op := PrismMesh.new()
			op.size = Vector3(0.14, 0.13, 0.07)
			om.mesh = op
			om.material_override = Obake3D.toon(Color("fbfaf6"), 0.3)
			om.position = Vector3(0, 0.065, 0)
			n.add_child(om)
			s.box3(Vector3(0.07, 0.05, 0.075), Vector3(0, 0.025, 0), Color("2e3a2e"), n)
	return n


# ---------------------------------------------------------------- 2. おつり

func _ring_up() -> void:
	phase = "change"
	var o := _order()
	screen_l.text = _m(int(o.total))
	s.hop(customer, 0.15)
	Kit.play(s, "chime", 1.4, -8)
	s.order(tr("PR_REG_PAID") % _m(int(o.paid)))
	# お札・お金がお客さんからおつりの皿へ
	var paid_mesh := _money_mesh(1000 if int(o.paid) >= 1000 else 500)
	paid_mesh.position = customer.position + Vector3(0, 0.6, 0)
	s.world.add_child(paid_mesh)
	s.move(paid_mesh, Vector3(-0.12, 0.86, -0.22), 0.45)
	var list: Array = []
	var ch := PracticeData.change_for(o)
	for v in PracticeData.change_money(money):
		var val: int = v
		list.append({"text": _m(val), "color": _col(val).lerp(Color.WHITE, 0.25), "cb": func(b): _give(val, b)})
	tile_btns = s.tiles(list, 4)
	var hint := tr("PR_REG_HINT_CHANGE_1") % _m(ch) if hints() else tr("PR_REG_HINT_CHANGE") % [_m(int(o.paid)), _m(int(o.total))]
	s.task(tr("PR_REG_TASK_CHANGE"), hint)
	s.say(tr("PR_REG_SAY_CHANGE"))
	change_l = Kit.text("", 16, Color("3f8a55"), true, HORIZONTAL_ALIGNMENT_CENTER)
	s.extra.add_child(change_l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var undo := Kit.button(tr("PR_REG_UNDO"), Color("eee6dd"), _undo, Color("6a5f70"), 46, 15)
	undo.custom_minimum_size.x = 96
	row.add_child(undo)
	var hand := Kit.button(tr("PR_REG_HAND"), Color("ff8a5b"), _hand_over)
	hand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hand)
	s.extra.add_child(row)
	_change_text()
	s._fit_panel()


## お金の字（この回の通貨で：¥1,080 / $10.75）
func _m(v: int) -> String:
	return PracticeData.money_text(v, money)


func _col(v: int) -> Color:
	return (COIN_COL_USD if money == Money.USD else COIN_COL).get(v, Color("d9dde3"))


func _given_sum() -> int:
	var n := 0
	for g in given:
		n += int(g)
	return n


func _change_text() -> void:
	if change_l:
		change_l.text = tr("PR_REG_GIVING") % _m(_given_sum())


func _give(v: int, _b: Control) -> void:
	if phase != "change":
		return
	given.append(v)
	var m := _money_mesh(v)
	var k := change_tray.get_child_count() - 1
	m.position = Vector3((k % 3 - 1) * 0.1, 0.03 + (k / 3) * 0.025, (k % 2) * 0.04 - 0.02)
	change_tray.add_child(m)
	s.pop_in(m)
	Kit.play(s, "pop", 1.2 if PracticeData.is_bill(v, money) or v >= 100 else 1.5, -6)
	_change_text()


func _undo() -> void:
	given.clear()
	for c in change_tray.get_children():
		if c.get_index() > 0:
			c.queue_free()
	_change_text()


func _hand_over() -> void:
	if phase != "change":
		return
	var o := _order()
	var ch := PracticeData.change_for(o)
	if not PracticeData.change_ok(o, given):
		var got := _given_sum()
		s.oops(tr("PR_REG_OOPS_MORE") % _m(ch - got) if got < ch else tr("PR_REG_OOPS_LESS") % _m(got - ch))
		if got > ch:
			_undo()
		return
	phase = ""
	# おつりが、お客さんへ
	for c in change_tray.get_children():
		if c.get_index() > 0:
			s.move(c, customer.position + Vector3(0, 0.5, 0), 0.4)
	s.good(tr("PR_REG_GOOD_CHANGE"))
	await s.get_tree().create_timer(0.5).timeout
	_phrase()


func _money_mesh(v: int) -> Node3D:
	var n := Node3D.new()
	if PracticeData.is_bill(v, money):
		s.box3(Vector3(0.3, 0.012, 0.15), Vector3.ZERO, _col(v), n)
		s.cyl3(0.04, 0.014, Vector3(0.08, 0.006, 0), Color("9fbf94"), n)
	else:
		var r: float = ({25: 0.08, 10: 0.064} if money == Money.USD else {500: 0.09, 100: 0.08, 50: 0.072, 10: 0.076}).get(v, 0.075)
		var m: MeshInstance3D = s.cyl3(r, 0.02, Vector3.ZERO, _col(v), n)
		m.material_override = Obake3D.metal(_col(v)) if (v != 10 or money == Money.USD) else Obake3D.toon(_col(v), 0.4)
	return n


# ---------------------------------------------------------------- 3. ひとこと

func _phrase() -> void:
	phase = "phrase"
	s.order("")
	var list: Array = []
	var order_i := [1, 0, 2] if cur % 2 == 0 else [2, 1, 0]
	for i in order_i:
		var k: int = i
		list.append({"text": tr(PracticeData.PHRASES[k]), "color": Color("fff8ea"), "cb": func(b): _say_phrase(k, b), "glow": hints() and k == 0})
	tile_btns = s.tiles(list, 1)
	s.task(tr("PR_REG_TASK_PHRASE"), tr("PR_REG_HINT_PHRASE") if hints() else "")


func _say_phrase(k: int, b: Control) -> void:
	if phase != "phrase":
		return
	if k != 0:
		s.oops(tr("PR_REG_OOPS_PHRASE"), b)
		return
	phase = ""
	s.say(tr(PracticeData.PHRASES[0]))
	Kit.play(s, "sparkle", 1.1, -6)
	s.hop(customer, 0.3)
	s.sparkle_at(customer.position + Vector3(0, 0.7, 0))
	s.order(tr("PR_REG_THANKS"))
	s.step_done()
	await s.get_tree().create_timer(0.8).timeout
	var c := customer
	c.rotation.y = 1.3
	var tw: Tween = s.move(c, Vector3(3.0, 0, 0.6), 0.6)
	# 品もいっしょに持って帰る
	for it in tray_items.get_children():
		if it.get_index() > 0:
			it.reparent(c)
	tw.tween_callback(c.queue_free)
	s.order("")
	await tw.finished
	cur += 1
	if cur >= rounds.size():
		s.finish()
	else:
		_customer_in()


# ---------------------------------------------------------------- 撮影・自動操作用

func demo_step() -> void:
	match phase:
		"order":
			for id in _wanted():
				if int(_wanted()[id]) > 0:
					_pick(id, null)
					return
		"change":
			var need := PracticeData.change_for(_order()) - _given_sum()
			if need <= 0:
				_hand_over()
				return
			for v in PracticeData.change_money(money):
				if v <= need:
					_give(v, null)
					return
		"phrase":
			_say_phrase(0, null)


func demo_wrong() -> void:
	match phase:
		"order":
			for m in PracticeData.MENU:
				if not _wanted().has(m.id):
					_pick(m.id, tile_btns[PracticeData.MENU.find(m)])
					return
		"change":
			_give(10, null)
			_hand_over()
		"phrase":
			_say_phrase(1, tile_btns[0] if tile_btns.size() > 0 else null)
