class_name Obake3D
extends Node3D
## 3D のおばけ。丸い頭と波打つ裾をトゥーン調で描き、黒い輪郭を付ける。
## 形は球と円柱の組み合わせだけなので、種類ごとの持ち物を足すのも簡単。

const COLORS := {
	"receipt": Color("f2b233"),
	"bubble": Color("4fb3f0"),
	"tray": Color("9b82ea"),
	"pan": Color("f07a3a"),
	"box": Color("e8c48e"),
	"lantern": Color("3b4a8c"),
	"kirari": Color("ffd23f"),
	"nemuri": Color("a996f0"),
}
const INK := Color("2e222f")

var species := "bubble"
var body: Node3D
var _t := 0.0
var _blink := 0.0
var eyes: Array[MeshInstance3D] = []
var bob := true
var level := 1
var growth := 1.0
var extras: Node3D


static func make(id: String) -> Obake3D:
	if Rares.is_rare(id):
		return RareObake3D.new().setup(id)
	return Obake3D.new().setup(id)


static func toon(color: Color, rim := 0.35, emission := 0.0, grow := 0.025) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.metallic_specular = 0.0
	m.roughness = 1.0
	m.rim_enabled = true
	m.rim = rim
	m.rim_tint = 0.6
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	var outline := StandardMaterial3D.new()
	outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	outline.albedo_color = INK
	outline.cull_mode = BaseMaterial3D.CULL_FRONT
	outline.grow = true
	outline.grow_amount = grow
	m.next_pass = outline
	return m


static func flat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m


func setup(id: String) -> Obake3D:
	species = id
	body = Node3D.new()
	add_child(body)
	var col: Color = COLORS.get(id, Color.WHITE)
	var eye_col := Color.WHITE if id == "lantern" else INK
	body.add_child(ghost(col, 1.0, 0.6 if id == "kirari" else 0.0, eye_col))
	_add_prop(id)
	_t = randf() * TAU
	return self


## おばけの体（丸い頭・胴・波打つ裾・顔）をひとつ組んで返す。足元が y=0、高さ約 1.0。
## s はこのノードに掛ける縮尺。輪郭の太さが縮尺に引きずられないよう、ここで補正する。
## mat を渡すと、その材質で塗る（col と emission は使わない）。
func ghost(col: Color, s := 1.0, emission := 0.0, eye_col := INK, sleepy := false, with_face := true, mat: Material = null) -> Node3D:
	var g := Node3D.new()
	g.scale = Vector3.ONE * s
	if mat == null:
		mat = toon(col, 0.12, emission, 0.025 / s)
	g.add_child(_mesh(_sphere(0.5), mat, Vector3(0, 0.5, 0)))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.5
	trunk.bottom_radius = 0.54
	trunk.height = 0.5
	g.add_child(_mesh(trunk, mat, Vector3(0, 0.25, 0)))
	# 裾の波：小さな球を輪に並べる
	for i in 8:
		var a := TAU * i / 8.0
		g.add_child(_mesh(_sphere(0.15), mat, Vector3(cos(a) * 0.44, 0.02, sin(a) * 0.44)))
	if with_face:
		g.add_child(face(Vector3(0, 0.5, 0), 1.0, eye_col, sleepy))
		if CAT:
			_cat_parts(g, col, mat)
	return g


## Paw Time：猫おばけの耳と尻尾。頭（半径 0.5・中心 y=0.5）に合わせて付ける。
static var CAT := true


func _cat_parts(g: Node3D, col: Color, mat: Material) -> void:
	var pink := flat(Color("f6a8aa"))
	for sx in [-1.0, 1.0]:
		var ear := CylinderMesh.new()
		ear.top_radius = 0.0
		ear.bottom_radius = 0.16
		ear.height = 0.3
		ear.radial_segments = 12
		var e := _mesh(ear, mat, Vector3(sx * 0.27, 0.9, -0.02))
		e.rotation = Vector3(-0.1, 0, -sx * 0.38)
		g.add_child(e)
		var inner := CylinderMesh.new()
		inner.top_radius = 0.0
		inner.bottom_radius = 0.085
		inner.height = 0.18
		inner.radial_segments = 10
		var ie := _mesh(inner, pink, Vector3(sx * 0.265, 0.9, 0.06))
		ie.rotation = Vector3(-0.1, 0, -sx * 0.38)
		g.add_child(ie)
	# ふわっと上がる尻尾（小さな球をつないで弧にする）
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0.1, 0.22, -0.45)
	g.add_child(tail)
	for i in 6:
		var t := i / 5.0
		var r := lerpf(0.09, 0.065, t)
		var pos := Vector3(sin(t * 1.6) * 0.3, t * 0.55, -0.12 - sin(t * PI) * 0.18)
		tail.add_child(_mesh(_sphere(r), mat, pos))


## 顔（目・ハイライト・ほっぺ・口）。center は半径 0.5 の頭の中心、k はその頭に対する倍率。正面は +Z。
## sleepy なら、目を閉じた線にする（まばたきしない）。
func face(center: Vector3, k := 1.0, eye_col := INK, sleepy := false) -> Node3D:
	var f := Node3D.new()
	f.position = center
	f.scale = Vector3.ONE * k
	for x in [-0.17, 0.17]:
		var e := _mesh(_sphere(0.07), flat(eye_col), Vector3(x, 0.05, 0.46))
		if sleepy:
			e.position.y = 0.02
			e.scale = Vector3(1.1, 0.18, 0.5)
		else:
			e.scale = Vector3(0.8, 1.2, 0.5)
			eyes.append(e)
			f.add_child(_mesh(_sphere(0.022), flat(Color.WHITE), Vector3(x + 0.02, 0.09, 0.5)))
		f.add_child(e)
		var cheek := _mesh(_sphere(0.07), flat(Color("f6a8aa")), Vector3(x * 1.7, -0.08, 0.42))
		cheek.scale = Vector3(1.0, 0.55, 0.3)
		f.add_child(cheek)
	if CAT:
		# 鼻と「ω」の口、ひげ
		var nose := _mesh(_sphere(0.028), flat(Color("f08a9a")), Vector3(0, -0.035, 0.5))
		nose.scale = Vector3(1.3, 0.8, 0.6)
		f.add_child(nose)
		for x in [-0.035, 0.035]:
			var m := _mesh(_sphere(0.032), flat(INK), Vector3(x, -0.085, 0.485))
			m.scale = Vector3(1.0, 0.55, 0.4)
			f.add_child(m)
		for sx in [-1.0, 1.0]:
			for j in 3:
				var w := BoxMesh.new()
				w.size = Vector3(0.2, 0.012, 0.012)
				var wm := _mesh(w, flat(INK), Vector3(sx * 0.33, -0.03 - j * 0.045, 0.43))
				wm.rotation = Vector3(0, -sx * 0.35, sx * (0.12 - j * 0.12))
				f.add_child(wm)
	else:
		var mouth := _mesh(_sphere(0.05), flat(INK), Vector3(0, -0.07, 0.49))
		mouth.scale = Vector3(1.2, 0.6, 0.4)
		f.add_child(mouth)
	return f


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 24
	s.rings = 12
	return s


func _mesh(m: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	return mi


func _add_prop(id: String) -> void:
	match id:
		"bubble":
			for p in [Vector3(-0.2, 1.05, 0.1), Vector3(0.05, 1.12, 0), Vector3(0.28, 1.0, -0.05)]:
				body.add_child(_mesh(_sphere(0.1 + randf() * 0.05), toon(Color("f4fbff"), 0.8), p))
		"tray":
			var tray := CylinderMesh.new()
			tray.top_radius = 0.5
			tray.bottom_radius = 0.46
			tray.height = 0.05
			body.add_child(_mesh(tray, toon(Color("c8ced6")), Vector3(0, 1.02, 0)))
			var glass := CylinderMesh.new()
			glass.top_radius = 0.08
			glass.bottom_radius = 0.07
			glass.height = 0.2
			body.add_child(_mesh(glass, toon(Color("ffcf5a")), Vector3(0.15, 1.14, 0)))
		"receipt":
			var r := BoxMesh.new()
			r.size = Vector3(0.14, 0.02, 0.5)
			var rm := _mesh(r, toon(Color("fffaf2")), Vector3(0.35, 0.05, -0.35))
			rm.rotation = Vector3(0.3, 0.6, 0)
			body.add_child(rm)
		"pan":
			var pan := CylinderMesh.new()
			pan.top_radius = 0.22
			pan.bottom_radius = 0.2
			pan.height = 0.06
			body.add_child(_mesh(pan, toon(Color("4a4a52")), Vector3(0.62, 0.45, 0.1)))
			body.add_child(_mesh(_sphere(0.08), toon(Color("ffd66b")), Vector3(0.62, 0.49, 0.1)))
		"box":
			var b := BoxMesh.new()
			b.size = Vector3(1.2, 0.45, 1.0)
			body.add_child(_mesh(b, toon(Color("d9a86c")), Vector3(0, 0.12, 0)))
		"lantern":
			var l := BoxMesh.new()
			l.size = Vector3(0.18, 0.26, 0.18)
			body.add_child(_mesh(l, toon(Color("ff9a4d"), 0.3, 1.5), Vector3(0.6, 0.55, 0.1)))
		"kirari":
			for i in 5:
				var c := CylinderMesh.new()
				c.top_radius = 0.0
				c.bottom_radius = 0.07
				c.height = 0.22
				var a := TAU * i / 5.0
				body.add_child(_mesh(c, toon(Color("ffe27a"), 0.3, 0.8), Vector3(cos(a) * 0.22, 1.08, sin(a) * 0.22)))
		"nemuri":
			var cap := CylinderMesh.new()
			cap.top_radius = 0.0
			cap.bottom_radius = 0.42
			cap.height = 0.6
			var cm := _mesh(cap, toon(Color("5b6fc2")), Vector3(0.05, 1.05, 0))
			cm.rotation.z = -0.35
			body.add_child(cm)


func _process(delta: float) -> void:
	_t += delta
	if bob:
		body.position.y = sin(_t * 2.0) * 0.06
		body.rotation.y = sin(_t * 0.7) * 0.25
		body.scale = Vector3(1.0 + sin(_t * 4.0) * 0.015, 1.0 - sin(_t * 4.0) * 0.015, 1.0) * growth
	_blink -= delta
	if _blink < -3.0:
		_blink = 0.12
	for e in eyes:
		e.scale.y = 0.15 if _blink > 0 else 1.2


## レベルで見た目が育つ：Lv2 首巻き / Lv3 頭の芽 / Lv4 胸の名札 / Lv5 王冠。少しずつ大きくなる
func set_level(lv: int) -> void:
	level = lv
	growth = 1.0 + 0.06 * (lv - 1)
	body.scale = Vector3.ONE * growth
	if extras:
		extras.queue_free()
	extras = Node3D.new()
	body.add_child(extras)
	var base: Color = COLORS.get(species, Color.WHITE)
	# 頭にお盆を乗せている子は、頭の飾りを少し上に。箱に入っている子は、首巻きと名札を箱の上に
	var head_up := 0.1 if species == "tray" else 0.0
	var neck_up := 0.14 if species == "box" else 0.0
	if lv >= 2:
		var scarf := TorusMesh.new()
		scarf.inner_radius = 0.42
		scarf.outer_radius = 0.56
		var sm := _mesh(scarf, toon(base.darkened(0.45), 0.2), Vector3(0, 0.3 + neck_up, 0))
		sm.scale = Vector3(1, 0.7, 1)
		extras.add_child(sm)
		var tail := BoxMesh.new()
		tail.size = Vector3(0.12, 0.28, 0.05)
		var tm := _mesh(tail, toon(base.darkened(0.45), 0.2), Vector3(0.28, 0.18 + neck_up, 0.46))
		tm.rotation.z = 0.3
		extras.add_child(tm)
	if lv >= 3:
		var stem := CylinderMesh.new()
		stem.top_radius = 0.02
		stem.bottom_radius = 0.025
		stem.height = 0.16
		extras.add_child(_mesh(stem, toon(Color("4f8a5b"), 0.2), Vector3(0, 1.05 + head_up, 0)))
		for x in [-1, 1]:
			var leaf := _mesh(_sphere(0.09), toon(Color("7bc96f"), 0.2), Vector3(x * 0.09, 1.13 + head_up, 0))
			leaf.scale = Vector3(1.3, 0.45, 0.8)
			leaf.rotation.z = x * 0.4
			extras.add_child(leaf)
	if lv >= 4:
		var tag := CylinderMesh.new()
		tag.top_radius = 0.09
		tag.bottom_radius = 0.09
		tag.height = 0.03
		var badge := _mesh(tag, toon(Color("fff4d6"), 0.2), Vector3(-0.2, 0.22 + neck_up * 1.6, 0.5))
		badge.rotation.x = PI / 2
		extras.add_child(badge)
	if lv >= 5:
		var ring := CylinderMesh.new()
		ring.top_radius = 0.2
		ring.bottom_radius = 0.18
		ring.height = 0.12
		extras.add_child(_mesh(ring, toon(Color("ffc93d"), 0.3, 0.3), Vector3(0.05, 1.02 + head_up, 0)))
		for i in 5:
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.06
			c.height = 0.14
			var a := TAU * i / 5.0
			extras.add_child(_mesh(c, toon(Color("ffc93d"), 0.3, 0.3), Vector3(0.05 + cos(a) * 0.15, 1.14 + head_up, sin(a) * 0.15)))
