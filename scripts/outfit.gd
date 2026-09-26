class_name Outfit
## 服と小物を、おばけの体（body）に着せる。体に付けるので、ゆれ・まばたき・しぐさについてくる。
## 形は Obake3D の部品（lathe・rbox・球・輪）と、トゥーンの持ち物の材質 Obake3D.prop() だけで組む。
## 体の基準：足元 y=0、頭の中心 y≈0.5（半径 0.5）、耳の先 y≈1.1（x=±0.33）、口 y≈0.41、正面は +Z。
## 大きさのちがうレアには、体の大きさに合わせて縮尺をかける。

## 診断の子がはじめから持っている物と、ぶつかる場所
const ACC_SLOT := {"scarf": "neck", "apron": "body", "headband": "head", "glasses": "face", "headphones": "head",
	"beret": "head", "bow": "head", "bandana": "neck", "towel": "neck", "cap": "head", "flower": "head",
	"bell": "neck", "star_pin": "body", "leaf": "head", "name_tag": "body", "chef_hat": "head"}


## 着せた姿で作る（庭・島・キセカエで Obake3D.make の代わりに）
static func make(obake_id: String, outfit = null) -> Obake3D:
	var o: Dictionary = Wardrobe.outfit_of(obake_id) if outfit == null else outfit
	var ob: Obake3D
	if obake_id == "my":
		var gs = Engine.get_main_loop().root.get_node_or_null("GameState")
		var look: Dictionary = gs.my_obake.get("look", {}).duplicate() if gs else {}
		var t := WardrobeData.tint(o.get("tint", ""))
		if t.c != "":
			look["color"] = t.c
		ob = Obake3D.make_custom(look) if not look.is_empty() else Obake3D.make("receipt")
	else:
		ob = Obake3D.make(obake_id)
	dress(ob, o)
	return ob


## いま着ている物を外して、outfit を着せなおす
static func dress(ob: Obake3D, outfit: Dictionary) -> void:
	if ob == null or ob.body == null:
		return
	var old := ob.body.get_node_or_null("Outfit")
	if old:
		ob.body.remove_child(old)
		old.queue_free()
	var root := Node3D.new()
	root.name = "Outfit"
	ob.body.add_child(root)
	_fit(ob, root)
	var acc := ob.body.get_node_or_null("Accessory") as Node3D
	var my_acc: String = ob.get("look").get("accessory", "") if ob is MyObake3D else ""
	if acc:
		acc.visible = not outfit.has(ACC_SLOT.get(my_acc, "-"))
	for slot in WardrobeData.SLOTS:
		var id: String = outfit.get(slot, "")
		if id == "":
			continue
		var it := WardrobeData.item(id)
		if it.is_empty():
			continue
		var n := build(ob, it)
		n.name = slot
		root.add_child(n)
	# キャラの層（Look のフィル・リム）にも乗せる
	for m in root.find_children("*", "GeometryInstance3D", true, false):
		(m as VisualInstance3D).layers |= 1 << (Look.CHAR_LAYER - 1)


## 体の大きさに合わせる（ふつうのおばけは高さ約 1.12）
static func _fit(ob: Obake3D, root: Node3D) -> void:
	var box := AABB()
	var first := true
	var nodes: Array = ob.body.find_children("Body", "MeshInstance3D", true, false)
	if nodes.is_empty():
		nodes = ob.body.find_children("*", "MeshInstance3D", true, false)
	for m in nodes:
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != ob.body:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var b := t * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		return
	var k := clampf(box.size.y / 1.12, 0.75, 1.6)
	root.scale = Vector3.ONE * k
	root.position = Vector3(box.get_center().x, box.position.y, box.get_center().z)


# ---------------------------------------------------------------- 組み立て

static func build(ob: Obake3D, it: Dictionary) -> Node3D:
	var n := Node3D.new()
	var c := Color(it.c)
	var c2 := Color(it.c2)
	var fn := "_b_" + String(it.shape)
	var s := Outfit.new()
	if s.has_method(fn):
		s.call(fn, ob, n, c, c2)
	return n


func _p(ob: Obake3D, n: Node3D, m: Mesh, c: Color, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, glow := 0.0) -> MeshInstance3D:
	var mi := ob._mesh(m, Obake3D.prop(c, 0.35, glow), pos)
	mi.rotation = rot
	mi.scale = scl
	n.add_child(mi)
	return mi


func _metal(ob: Obake3D, n: Node3D, m: Mesh, c: Color, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := ob._mesh(m, Obake3D.metal(c), pos)
	mi.rotation = rot
	mi.scale = scl
	n.add_child(mi)
	return mi


## 胴に巻く布（頭の下〜裾の上）。口（y≈0.41）にかからない高さまで
func _shell(ob: Obake3D, n: Node3D, c: Color, top := 0.34, bottom := 0.05, flare := 0.0) -> MeshInstance3D:
	var h := top - bottom
	return _p(ob, n, Obake3D.lathe(0.54, 0.585 + flare, h, 48, 0.02), c, Vector3(0, bottom + h * 0.5, 0))


# ---- 頭 ----

func _b_visor(ob, n, c, c2) -> void:
	_p(ob, n, ob._torus(0.36, 0.42), c, Vector3(0, 0.86, 0), Vector3.ZERO, Vector3(1, 1.4, 1))
	_p(ob, n, ob._box(Vector3(0.5, 0.03, 0.28)), c, Vector3(0, 0.84, 0.46), Vector3(-0.25, 0, 0))
	_p(ob, n, ob._box(Vector3(0.14, 0.05, 0.02)), c2, Vector3(0, 0.9, 0.42))


func _b_chef_hat(ob, n, c, c2) -> void:
	_p(ob, n, ob._cyl(0.3, 0.33, 0.2), c2, Vector3(0, 0.98, -0.02))
	for p in [Vector3(-0.14, 1.18, 0), Vector3(0.14, 1.18, 0), Vector3(0, 1.22, -0.08), Vector3(0, 1.2, 0.1)]:
		_p(ob, n, ob._sphere(0.2), c, p)


func _b_cap(ob, n, c, c2) -> void:
	_p(ob, n, ob._sphere(0.4), c, Vector3(0, 0.86, -0.02), Vector3.ZERO, Vector3(1, 0.62, 1))
	_p(ob, n, ob._box(Vector3(0.46, 0.035, 0.3)), c, Vector3(0, 0.88, 0.42), Vector3(-0.15, 0, 0))
	_p(ob, n, ob._sphere(0.05), c2, Vector3(0, 1.1, -0.02))
	_p(ob, n, ob._box(Vector3(0.16, 0.08, 0.02)), c2, Vector3(0, 0.98, 0.35), Vector3(-0.5, 0, 0))


func _b_nightcap(ob, n, c, c2) -> void:
	var cone := _p(ob, n, ob._cyl(0.0, 0.36, 0.62), c, Vector3(0.1, 1.12, -0.04))
	cone.rotation.z = -0.55
	_p(ob, n, ob._torus(0.3, 0.4), c2, Vector3(0, 0.88, -0.02), Vector3(0, 0, -0.1), Vector3(1, 1.3, 1))
	_p(ob, n, ob._sphere(0.08), c2, Vector3(0.42, 1.32, -0.04))


func _b_crown(ob, n, c, c2) -> void:
	_metal(ob, n, ob._cyl(0.26, 0.24, 0.12), c, Vector3(0, 1.02, 0))
	for i in 5:
		var a := TAU * i / 5.0
		_metal(ob, n, ob._cyl(0.0, 0.06, 0.16), c, Vector3(sin(a) * 0.21, 1.15, cos(a) * 0.21))
	_p(ob, n, ob._sphere(0.045), c2, Vector3(0, 1.03, 0.26))


func _b_halo(ob, n, c, _c2) -> void:
	var h := _p(ob, n, ob._torus(0.24, 0.3), c, Vector3(0, 1.3, 0), Vector3(0.15, 0, 0), Vector3.ONE, 1.4)
	h.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _b_party_hat(ob, n, c, c2) -> void:
	_p(ob, n, ob._cyl(0.0, 0.2, 0.42), c, Vector3(0.05, 1.12, 0), Vector3(0, 0, -0.18))
	_p(ob, n, ob._torus(0.12, 0.17), c2, Vector3(0.03, 1.02, 0), Vector3(0, 0, -0.18))
	_p(ob, n, ob._sphere(0.07), c2, Vector3(0.12, 1.34, 0))


func _b_flower_crown(ob, n, c, c2) -> void:
	for i in 10:
		var a := TAU * i / 10.0
		var p := Vector3(sin(a) * 0.36, 0.92, cos(a) * 0.36)
		_p(ob, n, ob._sphere(0.07), c if i % 2 == 0 else Color("fff2a8"), p)
		_p(ob, n, ob._sphere(0.04), c2, p + Vector3(0.05, -0.03, 0.03))


func _b_sprout(ob, n, _c, c2) -> void:
	_p(ob, n, ob._cyl(0.02, 0.025, 0.2), c2, Vector3(0, 1.08, 0.05))
	_p(ob, n, ob._sphere(0.1), Color("6cbf5a"), Vector3(-0.09, 1.2, 0.05), Vector3(0, 0, 0.6), Vector3(1.4, 0.5, 0.8))
	_p(ob, n, ob._sphere(0.1), Color("7fd06a"), Vector3(0.09, 1.2, 0.05), Vector3(0, 0, -0.6), Vector3(1.4, 0.5, 0.8))


func _b_beanie(ob, n, c, c2) -> void:
	_p(ob, n, ob._sphere(0.42), c, Vector3(0, 0.84, -0.03), Vector3.ZERO, Vector3(1, 0.7, 1))
	_p(ob, n, ob._torus(0.36, 0.45), c2, Vector3(0, 0.8, -0.02), Vector3(-0.08, 0, 0), Vector3(1, 1.8, 1))
	_p(ob, n, ob._sphere(0.1), c2, Vector3(0, 1.16, -0.03))


func _b_beret(ob, n, c, _c2) -> void:
	_p(ob, n, ob._sphere(0.4), c, Vector3(-0.06, 0.98, -0.02), Vector3(0, 0, 0.25), Vector3(1.1, 0.32, 1.05))
	_p(ob, n, ob._cyl(0.02, 0.03, 0.07), c, Vector3(-0.12, 1.12, -0.02))


func _b_straw_hat(ob, n, c, c2) -> void:
	_p(ob, n, ob._cyl(0.62, 0.62, 0.03), c, Vector3(0, 0.95, 0), Vector3(-0.08, 0, 0))
	_p(ob, n, ob._cyl(0.28, 0.32, 0.22), c, Vector3(0, 1.07, -0.02))
	_p(ob, n, ob._cyl(0.325, 0.325, 0.06), c2, Vector3(0, 1.0, -0.02))


func _b_top_hat(ob, n, c, c2) -> void:
	var g := Node3D.new()
	g.position = Vector3(0.08, 0.98, 0)
	g.rotation.z = -0.15
	n.add_child(g)
	_p(ob, g, ob._cyl(0.32, 0.32, 0.03), c, Vector3.ZERO)
	_p(ob, g, ob._cyl(0.2, 0.2, 0.3), c, Vector3(0, 0.16, 0))
	_p(ob, g, ob._cyl(0.205, 0.205, 0.06), c2, Vector3(0, 0.05, 0))


func _b_bow_head(ob, n, c, _c2) -> void:
	var g := Node3D.new()
	g.position = Vector3(0.28, 0.95, 0.12)
	g.rotation = Vector3(0.2, 0, -0.4)
	n.add_child(g)
	_p(ob, g, ob._sphere(0.12), c, Vector3(-0.12, 0, 0), Vector3(0, 0, 0.4), Vector3(1.3, 0.8, 0.5))
	_p(ob, g, ob._sphere(0.12), c, Vector3(0.12, 0, 0), Vector3(0, 0, -0.4), Vector3(1.3, 0.8, 0.5))
	_p(ob, g, ob._sphere(0.06), c.darkened(0.12), Vector3.ZERO)


func _b_flower(ob, n, c, c2) -> void:
	var g := Node3D.new()
	g.position = Vector3(0.3, 0.86, 0.3)
	g.rotation = Vector3(0.5, 0.6, 0)
	g.scale = Vector3.ONE * 1.7
	n.add_child(g)
	for i in 5:
		var a := TAU * i / 5.0
		_p(ob, g, ob._sphere(0.06), c2, Vector3(cos(a) * 0.07, sin(a) * 0.07, 0), Vector3.ZERO, Vector3(1, 1, 0.5))
	_p(ob, g, ob._sphere(0.045), c, Vector3(0, 0, 0.02))


func _b_helmet(ob, n, c, c2) -> void:
	_p(ob, n, ob._torus(0.42, 0.52), c, Vector3(0, 0.56, 0.12), Vector3(PI / 2, 0, 0), Vector3(1, 1, 1.2))
	_p(ob, n, ob._sphere(0.56), c, Vector3(0, 0.62, -0.14), Vector3.ZERO, Vector3(1, 1, 0.7))
	_p(ob, n, ob._cyl(0.015, 0.02, 0.24), Color("c8ced6"), Vector3(0.24, 1.2, -0.1), Vector3(0, 0, -0.3))
	_p(ob, n, ob._sphere(0.05), c2, Vector3(0.28, 1.33, -0.1), Vector3.ZERO, Vector3.ONE, 0.8)


# ---- 顔 ----

func _b_round_glasses(ob, n, c, c2) -> void:
	for x in [-0.17, 0.17]:
		_p(ob, n, ob._torus(0.085, 0.11), c, Vector3(x, 0.55, 0.51), Vector3(PI / 2, 0, 0))
	_p(ob, n, ob._box(Vector3(0.1, 0.02, 0.02)), c, Vector3(0, 0.56, 0.53))


func _b_sunglasses(ob, n, c, _c2) -> void:
	for x in [-0.17, 0.17]:
		_p(ob, n, ob._box(Vector3(0.2, 0.13, 0.03)), c, Vector3(x, 0.55, 0.51), Vector3(0, x * 1.2, 0))
	_p(ob, n, ob._box(Vector3(0.12, 0.025, 0.02)), c, Vector3(0, 0.58, 0.53))


func _b_star_glasses(ob, n, c, c2) -> void:
	for x in [-0.18, 0.18]:
		_p(ob, n, Obake3D.lathe(0.13, 0.13, 0.03, 5, 0.01), c, Vector3(x, 0.56, 0.51), Vector3(PI / 2, 0, PI / 10), Vector3(1, 1, 1))
	_p(ob, n, ob._box(Vector3(0.1, 0.02, 0.02)), c2, Vector3(0, 0.57, 0.54))


func _b_sleep_mask(ob, n, c, c2) -> void:
	_p(ob, n, Obake3D.lathe(0.505, 0.505, 0.07, 48, 0.02), c.darkened(0.2), Vector3(0, 0.56, 0))
	_p(ob, n, ob._box(Vector3(0.56, 0.16, 0.05)), c, Vector3(0, 0.56, 0.46), Vector3(0, 0, 0))
	for x in [-0.16, 0.16]:
		_p(ob, n, ob._box(Vector3(0.12, 0.018, 0.02)), c2, Vector3(x, 0.55, 0.49))


func _b_mustache(ob, n, c, _c2) -> void:
	for sx in [-1.0, 1.0]:
		_p(ob, n, ob._sphere(0.07), c, Vector3(sx * 0.07, 0.45, 0.5), Vector3(0, 0, sx * -0.35), Vector3(1.6, 0.6, 0.6))


# ---- 首 ----

func _b_scarf(ob, n, c, c2) -> void:
	_p(ob, n, ob._torus(0.46, 0.6), c, Vector3(0, 0.33, 0), Vector3.ZERO, Vector3(1, 0.8, 1))
	_p(ob, n, ob._box(Vector3(0.16, 0.3, 0.06)), c, Vector3(0.22, 0.2, 0.55), Vector3(0.1, 0, 0.1))
	if c2 != c:
		_p(ob, n, ob._torus(0.47, 0.61), c2, Vector3(0, 0.33, 0), Vector3.ZERO, Vector3(1, 0.25, 1))
		_p(ob, n, ob._box(Vector3(0.165, 0.05, 0.065)), c2, Vector3(0.22, 0.14, 0.555), Vector3(0.1, 0, 0.1))


func _b_rainbow_scarf(ob, n, c, c2) -> void:
	var cols := [Color("ff8fb1"), Color("ffd23f"), Color("8fd18a"), Color("7fe3ff"), Color("b9a7ff")]
	for i in cols.size():
		_p(ob, n, ob._torus(0.46, 0.58), cols[i], Vector3(0, 0.27 + i * 0.03, 0), Vector3.ZERO, Vector3(1, 0.22, 1))
	_p(ob, n, ob._box(Vector3(0.16, 0.34, 0.06)), c2, Vector3(-0.22, 0.18, 0.55), Vector3(0.1, 0, -0.1))


func _b_bowtie(ob, n, c, c2) -> void:
	for sx in [-1.0, 1.0]:
		_p(ob, n, ob._cyl(0.0, 0.08, 0.14), c, Vector3(sx * 0.08, 0.33, 0.54), Vector3(0, 0, sx * PI / 2), Vector3(1, 1, 0.5))
	_p(ob, n, ob._sphere(0.045), c2, Vector3(0, 0.33, 0.56))


func _b_neckerchief(ob, n, c, c2) -> void:
	_p(ob, n, ob._torus(0.47, 0.57), c, Vector3(0, 0.33, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
	_p(ob, n, Obake3D.lathe(0.0, 0.16, 0.03, 3, 0.01), c, Vector3(0, 0.24, 0.55), Vector3(PI / 2, 0, PI), Vector3(1, 1, 1))
	_p(ob, n, ob._sphere(0.04), c2, Vector3(0, 0.33, 0.58))


func _b_bell_collar(ob, n, c, c2) -> void:
	_p(ob, n, ob._torus(0.49, 0.56), c, Vector3(0, 0.34, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
	_metal(ob, n, ob._sphere(0.07), c2, Vector3(0, 0.27, 0.57))
	_p(ob, n, ob._box(Vector3(0.06, 0.012, 0.01)), Color("2e222f"), Vector3(0, 0.25, 0.64))


func _b_necktie(ob, n, c, c2) -> void:
	_p(ob, n, ob._torus(0.49, 0.54), Color("ffffff"), Vector3(0, 0.35, 0), Vector3.ZERO, Vector3(1, 0.4, 1))
	_p(ob, n, ob._box(Vector3(0.08, 0.07, 0.04)), c, Vector3(0, 0.33, 0.56))
	_p(ob, n, ob._box(Vector3(0.1, 0.24, 0.03)), c, Vector3(0, 0.18, 0.57), Vector3(0.08, 0, 0))
	_p(ob, n, ob._box(Vector3(0.1, 0.03, 0.035)), c2, Vector3(0, 0.2, 0.585), Vector3(0.08, 0, 0))


# ---- 体 ----

func _b_vest(ob, n, c, c2) -> void:
	_shell(ob, n, c)
	_p(ob, n, ob._box(Vector3(0.1, 0.26, 0.03)), c2, Vector3(0, 0.2, 0.575))
	for y in [0.13, 0.22]:
		_p(ob, n, ob._sphere(0.025), Color("2e222f"), Vector3(0.08, y, 0.59))
	_p(ob, n, ob._box(Vector3(0.1, 0.07, 0.02)), Color("ffffff"), Vector3(-0.22, 0.26, 0.54), Vector3(0, -0.4, 0))


func _b_apron(ob, n, c, c2) -> void:
	_p(ob, n, ob._box(Vector3(0.52, 0.3, 0.03)), c, Vector3(0, 0.2, 0.55), Vector3(0.12, 0, 0))
	_p(ob, n, ob._box(Vector3(0.2, 0.1, 0.035)), c2, Vector3(0, 0.14, 0.56), Vector3(0.12, 0, 0))
	_p(ob, n, ob._torus(0.53, 0.56), c, Vector3(0, 0.31, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	_p(ob, n, ob._sphere(0.06), c, Vector3(0, 0.3, -0.58), Vector3.ZERO, Vector3(1.5, 0.8, 0.6))


func _b_pajamas(ob, n, c, c2) -> void:
	_shell(ob, n, c)
	for i in 7:
		var a := TAU * i / 7.0 + 0.2
		_p(ob, n, ob._sphere(0.035), c2, Vector3(sin(a) * 0.575, 0.12 + (i % 2) * 0.12, cos(a) * 0.575), Vector3.ZERO, Vector3.ONE, 0.3)
	_p(ob, n, ob._torus(0.5, 0.57), c2, Vector3(0, 0.34, 0), Vector3.ZERO, Vector3(1, 0.4, 1))


func _b_raincoat(ob, n, c, c2) -> void:
	_shell(ob, n, c, 0.35, 0.03, 0.05)
	_p(ob, n, ob._sphere(0.36), c, Vector3(0, 0.72, -0.26), Vector3.ZERO, Vector3(1.1, 0.9, 0.55))
	for y in [0.12, 0.24]:
		_p(ob, n, ob._sphere(0.03), c2, Vector3(0, y, 0.6))


func _b_sweater(ob, n, c, c2) -> void:
	_shell(ob, n, c)
	for y in [0.07, 0.34]:
		_p(ob, n, ob._torus(0.53, 0.6), c.darkened(0.12), Vector3(0, y, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
	_p(ob, n, Obake3D.lathe(0.555, 0.58, 0.05, 48, 0.01), c2, Vector3(0, 0.2, 0))


func _b_overalls(ob, n, c, c2) -> void:
	_shell(ob, n, c, 0.2, 0.03)
	_p(ob, n, ob._box(Vector3(0.32, 0.18, 0.03)), c, Vector3(0, 0.27, 0.54), Vector3(-0.12, 0, 0))
	for sx in [-1.0, 1.0]:
		_p(ob, n, ob._sphere(0.03), c2, Vector3(sx * 0.12, 0.33, 0.56))
		_p(ob, n, ob._box(Vector3(0.06, 0.03, 0.4)), c, Vector3(sx * 0.14, 0.36, 0.2), Vector3(0.3, 0, 0))


func _b_yukata(ob, n, c, c2) -> void:
	_shell(ob, n, c, 0.34, 0.03, 0.03)
	_p(ob, n, Obake3D.lathe(0.565, 0.575, 0.08, 48, 0.01), c2, Vector3(0, 0.2, 0))
	_p(ob, n, ob._box(Vector3(0.18, 0.1, 0.06)), c2, Vector3(0, 0.2, -0.58))
	for sx in [-1.0, 1.0]:
		_p(ob, n, ob._box(Vector3(0.05, 0.16, 0.02)), Color("ffffff"), Vector3(sx * 0.07, 0.3, 0.55), Vector3(0, 0, sx * 0.5))


# ---- 手 ----

func _b_gloves(ob, n, c, c2) -> void:
	for sx in [-1.0, 1.0]:
		_p(ob, n, ob._sphere(0.13), c, Vector3(sx * 0.58, 0.26, 0.14), Vector3.ZERO, Vector3(0.9, 1.0, 0.9))
		_p(ob, n, ob._sphere(0.055), c2 if c2 != c else c.darkened(0.1), Vector3(sx * 0.63, 0.33, 0.23))


func _b_tray(ob, n, c, c2) -> void:
	_metal(ob, n, ob._cyl(0.22, 0.2, 0.03), c, Vector3(0.62, 0.52, 0.08))
	_p(ob, n, ob._cyl(0.06, 0.05, 0.14), c2, Vector3(0.6, 0.61, 0.08))
	_p(ob, n, ob._sphere(0.07), Color("ffffff"), Vector3(0.58, 0.44, 0.1))


func _b_balloon(ob, n, c, c2) -> void:
	var pts := PackedVector3Array([Vector3(0.52, 0.3, 0.1), Vector3(0.6, 0.7, 0.05), Vector3(0.55, 1.05, 0.0), Vector3(0.62, 1.3, 0.0)])
	_p(ob, n, Obake3D.tube("balloon_string", pts, PackedFloat32Array([0.008, 0.008, 0.008, 0.008]), 8), c2, Vector3.ZERO)
	_p(ob, n, ob._sphere(0.2), c, Vector3(0.62, 1.48, 0.0), Vector3.ZERO, Vector3(1, 1.15, 1))
	_p(ob, n, ob._sphere(0.05), Color(1, 1, 1), Vector3(0.55, 1.56, 0.14), Vector3.ZERO, Vector3.ONE, 0.2)


func _b_jar(ob, n, c, c2) -> void:
	_p(ob, n, ob._cyl(0.1, 0.1, 0.2), c2, Vector3(0.6, 0.32, 0.1))
	_p(ob, n, ob._cyl(0.07, 0.07, 0.04), Color("b07a4a"), Vector3(0.6, 0.44, 0.1))
	for p in [Vector3(0.57, 0.3, 0.2), Vector3(0.64, 0.36, 0.2), Vector3(0.6, 0.26, 0.19)]:
		_p(ob, n, ob._sphere(0.025), c, p, Vector3.ZERO, Vector3.ONE, 2.0)


func _b_umbrella(ob, n, c, c2) -> void:
	_p(ob, n, ob._cyl(0.015, 0.015, 1.0), Color("7a5238"), Vector3(0.55, 0.75, 0.05), Vector3(0, 0, -0.12))
	_p(ob, n, Obake3D.lathe(0.0, 0.55, 0.26, 8, 0.02), c, Vector3(0.62, 1.3, 0.05), Vector3(0, 0, -0.12))
	_p(ob, n, ob._sphere(0.035), c2, Vector3(0.64, 1.46, 0.05))


func _b_fish(ob, n, c, c2) -> void:
	_p(ob, n, ob._sphere(0.12), c, Vector3(0.62, 0.34, 0.12), Vector3(0, 0, 0.2), Vector3(1.4, 0.7, 0.5))
	_p(ob, n, ob._cyl(0.0, 0.09, 0.12), c2, Vector3(0.44, 0.3, 0.12), Vector3(0, 0, PI / 2 + 0.2), Vector3(1, 1, 0.4))
	_p(ob, n, ob._sphere(0.02), Color("2e222f"), Vector3(0.74, 0.37, 0.17))


# ---- 背中 ----

func _b_wings(ob, n, c, c2) -> void:
	for sx in [-1.0, 1.0]:
		var g := Node3D.new()
		g.position = Vector3(sx * 0.34, 0.62, -0.42)
		g.scale = Vector3.ONE * 1.6
		g.rotation = Vector3(0, sx * 0.5, sx * -0.3)
		n.add_child(g)
		for i in 3:
			_p(ob, g, ob._sphere(0.18 - i * 0.03), c if i < 2 else c2, Vector3(sx * (0.14 + i * 0.13), 0.08 - i * 0.07, 0), Vector3.ZERO, Vector3(1.3, 0.8, 0.25))


func _b_bat_wings(ob, n, c, c2) -> void:
	for sx in [-1.0, 1.0]:
		var g := Node3D.new()
		g.position = Vector3(sx * 0.34, 0.62, -0.42)
		g.scale = Vector3.ONE * 1.6
		g.rotation = Vector3(0, sx * 0.4, sx * -0.2)
		n.add_child(g)
		for i in 3:
			_p(ob, g, ob._cyl(0.0, 0.12, 0.34), c if i != 1 else c2, Vector3(sx * (0.12 + i * 0.12), 0.05 - i * 0.03, 0), Vector3(0, 0, sx * (-1.2 - i * 0.3)), Vector3(1, 1, 0.25))


func _b_cape(ob, n, c, c2) -> void:
	_p(ob, n, ob._torus(0.49, 0.56), c2, Vector3(0, 0.36, 0), Vector3.ZERO, Vector3(1, 0.4, 1))
	_p(ob, n, Obake3D.lathe(0.5, 0.66, 0.38, 48, 0.02), c, Vector3(0, 0.18, -0.08), Vector3.ZERO, Vector3(1, 1, 0.92))
	_p(ob, n, ob._sphere(0.06), c2, Vector3(0, 0.34, 0.56), Vector3.ZERO, Vector3.ONE, 0.6)


func _b_pillow(ob, n, c, c2) -> void:
	_p(ob, n, ob._box(Vector3(0.9, 0.5, 0.26), 0.12), c, Vector3(0, 0.62, -0.62), Vector3(0.25, 0, 0.12))
	_p(ob, n, ob._box(Vector3(0.92, 0.07, 0.27), 0.03), c2, Vector3(0, 0.62, -0.62), Vector3(0.25, 0, 0.12))


func _b_backpack(ob, n, c, c2) -> void:
	_p(ob, n, ob._box(Vector3(0.72, 0.62, 0.3), 0.1), c, Vector3(0, 0.46, -0.62))
	_p(ob, n, ob._box(Vector3(0.7, 0.2, 0.32), 0.06), c.darkened(0.12), Vector3(0, 0.7, -0.62))
	_p(ob, n, ob._box(Vector3(0.26, 0.16, 0.06), 0.03), c2, Vector3(0, 0.36, -0.79))
	for sx in [-1.0, 1.0]:
		_p(ob, n, ob._box(Vector3(0.05, 0.03, 0.5)), c.darkened(0.2), Vector3(sx * 0.2, 0.42, -0.25), Vector3(0.1, 0, 0))


func _b_tote(ob, n, c, c2) -> void:
	_p(ob, n, ob._box(Vector3(0.32, 0.32, 0.08)), c, Vector3(0.48, 0.22, -0.34), Vector3(0, 0.9, 0))
	_p(ob, n, ob._torus(0.1, 0.13), c2, Vector3(0.48, 0.42, -0.34), Vector3(0, 0.9, PI / 2))
	_p(ob, n, ob._box(Vector3(0.14, 0.1, 0.085)), c2, Vector3(0.5, 0.22, -0.3), Vector3(0, 0.9, 0))


func _b_shell(ob, n, c, c2) -> void:
	_p(ob, n, ob._sphere(0.5), c, Vector3(0, 0.62, -0.6), Vector3.ZERO, Vector3(0.6, 1, 1))
	for i in 3:
		_p(ob, n, ob._torus(0.1 + i * 0.13, 0.14 + i * 0.13), c2, Vector3(0.28, 0.62, -0.6), Vector3(0, 0, PI / 2))


func _b_dragon_wings(ob, n, c, c2) -> void:
	for sx in [-1.0, 1.0]:
		var g := Node3D.new()
		g.position = Vector3(sx * 0.34, 0.66, -0.42)
		g.scale = Vector3.ONE * 1.6
		g.rotation = Vector3(0, sx * 0.45, sx * -0.35)
		n.add_child(g)
		_p(ob, g, ob._cyl(0.02, 0.03, 0.5), c.darkened(0.2), Vector3(sx * 0.2, 0.12, 0), Vector3(0, 0, sx * -1.0))
		for i in 3:
			_p(ob, g, ob._sphere(0.14), c if i != 1 else c2, Vector3(sx * (0.14 + i * 0.13), -0.02 - i * 0.05, 0), Vector3(0, 0, sx * 0.3), Vector3(1.3, 1.0, 0.18))
