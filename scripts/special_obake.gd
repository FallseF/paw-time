class_name SpecialObake
## 診断で決まるマイおばけ猫を「とくべつな子」にする。16 タイプの上に、4 つのとくべつな印（special）が乗る。
## どの印になるかは答えで決まる（外へ/内へ × きっちり/ゆったり）。印ごとに、ほかのおばけには無い
## 浮かぶ持ち物（光の輪・王冠・まわる星・花の冠）と、体のきらめき色、相棒の呼び名がつく。
## 見た目は MyObake3D.setup_look() が look.special を見て decorate() を呼ぶ（呼ぶ側は何もしなくてよい）。

## 文言は i18n/strings.csv の SPECIAL_<KIND>_NAME（印の名前）/ _PET（相棒の呼び名）/ _LINE（ひとこと）
const KINDS := {
	"moon": {"glow": "c9d4ff", "shine": "e9ecff", "axis": "IK"},
	"sun": {"glow": "ffd23f", "shine": "fff1b8", "axis": "OK"},
	"star": {"glow": "b99af0", "shine": "efe6ff", "axis": "IY"},
	"blossom": {"glow": "ff9ecb", "shine": "ffe3f0", "axis": "OY"},
}


## 答え（"A"/"B" ×12）から印を決める。軸0（外へ O / 内へ I）と軸3（きっちり K / ゆったり Y）の組み合わせ。
static func pick(type_id: String) -> String:
	var key := type_id.substr(0, 1) + type_id.substr(3, 1)
	for k in KINDS:
		if KINDS[k].axis == key:
			return k
	return "star"


static func name_of(kind: String) -> String:
	return I18n.t("SPECIAL_%s_NAME" % kind.to_upper())


## 相棒の呼び名（チュートリアルや仕事の知らせで使う）。印が無ければ一般名
static func pet_name(my: Dictionary = {}) -> String:
	# GameState は名前で引く（tests の -s 実行では、自動読み込みより先にこのスクリプトが読まれるため）
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameState")
	var d: Dictionary = my if not my.is_empty() or gs == null else gs.my_obake
	var kind: String = d.get("special", "")
	if kind == "":
		return I18n.t("ONB_PARTNER")
	return I18n.t("SPECIAL_%s_PET" % kind.to_upper())


static func glow(kind: String) -> Color:
	return Color(KINDS.get(kind, KINDS.star).glow)


## 診断の結果に印を足す（look にも入れて、見た目が保存の読み直しでも付くように）
static func apply(result: Dictionary) -> Dictionary:
	var r := result.duplicate(true)
	r["special"] = pick(r.type_id)
	r.look["special"] = r.special
	return r


## 体に、印の持ち物ときらめきを足す。ob.body の子に "Special" を作る。
static func decorate(ob: Obake3D, kind: String) -> void:
	if not KINDS.has(kind):
		return
	var g := glow(kind)
	var root := Node3D.new()
	root.name = "Special"
	ob.body.add_child(root)
	match kind:
		"moon":
			_halo(root, g)
			var moon := _ball(0.085, Kit.glow(Color("fff6d8"), 2.2))
			moon.position = Vector3(0.42, 1.12, 0.05)
			root.add_child(moon)
			var bite := _ball(0.08, Obake3D.flat(Color("2a2233")))
			bite.position = Vector3(0.46, 1.14, 0.1)
			bite.scale = Vector3(1, 1, 0.6)
			root.add_child(bite)
		"sun":
			_crown(root, g)
		"star":
			var orbit := Spin.new()
			orbit.speed = 1.6
			orbit.position = Vector3(0, 0.55, 0)
			root.add_child(orbit)
			for i in 3:
				var a := TAU * i / 3.0
				var st := _star(g)
				st.position = Vector3(cos(a) * 0.72, sin(a * 2.0) * 0.12, sin(a) * 0.72)
				orbit.add_child(st)
		"blossom":
			_wreath(root, g)
	# 足もとの光の輪と、ゆっくり立ちのぼる粒（どの印にも）
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.5
	tm.outer_radius = 0.56
	tm.rings = 32
	tm.ring_segments = 6
	ring.mesh = tm
	ring.material_override = Kit.glow(g, 1.6)
	ring.scale = Vector3(1, 0.2, 1)
	ring.position = Vector3(0, 0.02, 0)
	root.add_child(ring)
	var dust := CPUParticles3D.new()
	dust.amount = 14
	dust.lifetime = 2.4
	dust.preprocess = 2.4
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	dust.emission_ring_axis = Vector3.UP
	dust.emission_ring_radius = 0.55
	dust.emission_ring_inner_radius = 0.3
	dust.emission_ring_height = 0.05
	dust.gravity = Vector3(0, 0.25, 0)
	dust.initial_velocity_min = 0.0
	dust.initial_velocity_max = 0.05
	dust.scale_amount_min = 0.6
	dust.scale_amount_max = 1.2
	var dm := SphereMesh.new()
	dm.radius = 0.018
	dm.height = 0.036
	dm.radial_segments = 8
	dm.rings = 4
	dust.mesh = dm
	dust.material_override = Kit.glow(Color(KINDS[kind].shine), 2.5)
	root.add_child(dust)


static func _ball(r: float, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2
	s.radial_segments = 16
	s.rings = 8
	m.mesh = s
	m.material_override = mat
	return m


static func _halo(root: Node3D, g: Color) -> void:
	var h := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.24
	tm.outer_radius = 0.3
	tm.rings = 32
	tm.ring_segments = 10
	h.mesh = tm
	h.material_override = Kit.glow(g, 2.4)
	h.position = Vector3(0, 1.12, -0.02)
	h.rotation = Vector3(-0.25, 0, 0.12)
	var bob := Spin.new()
	bob.speed = 0.0
	bob.float_amp = 0.03
	root.add_child(bob)
	bob.add_child(h)


static func _crown(root: Node3D, g: Color) -> void:
	var c := Node3D.new()
	c.position = Vector3(0.05, 1.0, 0.0)
	c.rotation = Vector3(-0.1, 0, -0.12)
	root.add_child(c)
	var band := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.2
	cy.bottom_radius = 0.2
	cy.height = 0.09
	cy.radial_segments = 20
	band.mesh = cy
	band.material_override = Obake3D.toon(g, 0.5, 0.5, 0.012)
	c.add_child(band)
	for i in 5:
		var a := TAU * i / 5.0
		var sp := MeshInstance3D.new()
		var cn := CylinderMesh.new()
		cn.top_radius = 0.0
		cn.bottom_radius = 0.06
		cn.height = 0.13
		cn.radial_segments = 8
		sp.mesh = cn
		sp.material_override = Obake3D.toon(g, 0.5, 0.5, 0.01)
		sp.position = Vector3(cos(a) * 0.17, 0.1, sin(a) * 0.17)
		c.add_child(sp)
		var gem := _ball(0.028, Kit.glow(Color("ff5d8f") if i % 2 == 0 else Color("5fc4ff"), 1.8))
		gem.position = Vector3(cos(a) * 0.2, 0.0, sin(a) * 0.2)
		c.add_child(gem)


static func _star(g: Color) -> Node3D:
	var n := Node3D.new()
	for i in 5:
		var a := TAU * i / 5.0 + PI / 2
		var ray := MeshInstance3D.new()
		var cn := CylinderMesh.new()
		cn.top_radius = 0.0
		cn.bottom_radius = 0.035
		cn.height = 0.09
		cn.radial_segments = 6
		ray.mesh = cn
		ray.material_override = Kit.glow(g.lightened(0.3), 2.2)
		ray.position = Vector3(cos(a) * 0.045, sin(a) * 0.045, 0)
		ray.rotation.z = a - PI / 2
		n.add_child(ray)
	n.add_child(_ball(0.04, Kit.glow(Color("fffbe8"), 2.6)))
	return n


static func _wreath(root: Node3D, g: Color) -> void:
	var c := Node3D.new()
	c.position = Vector3(0, 0.9, 0.0)
	c.rotation = Vector3(-0.2, 0, 0)
	root.add_child(c)
	for i in 9:
		var a := TAU * i / 9.0
		var p := _ball(0.07, Obake3D.toon(g if i % 3 != 0 else Color("fff6fb"), 0.4, 0.25, 0.008))
		p.position = Vector3(cos(a) * 0.4, 0, sin(a) * 0.4)
		p.scale = Vector3(1, 0.5, 1)
		c.add_child(p)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		var leaf := _ball(0.06, Obake3D.toon(Color("6cbf5a"), 0.3, 0.0, 0.008))
		leaf.position = Vector3(cos(a) * 0.42, -0.03, sin(a) * 0.42)
		leaf.scale = Vector3(1.3, 0.35, 0.7)
		c.add_child(leaf)


## ゆっくり回る・ふわふわ浮くだけの小さなノード（Tween はツリーの外で作れないので _process で動かす）
class Spin extends Node3D:
	var speed := 1.0
	var float_amp := 0.0
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		rotation.y += speed * delta
		if float_amp > 0.0:
			position.y = sin(_t * 2.2) * float_amp
