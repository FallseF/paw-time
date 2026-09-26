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


static func make(id: String) -> Obake3D:
	if Rares.is_rare(id):
		return RareObake3D.new().setup(id)
	return Obake3D.new().setup(id)


static func toon(color: Color, rim := 0.35, emission := 0.0) -> StandardMaterial3D:
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
	outline.grow_amount = 0.025
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
	if Rares.is_rare(id):
		col = Color(Rares.by_id(id).look.c1)
	var mat := toon(col, 0.12, 0.6 if id == "kirari" else 0.0)

	var head := _mesh(_sphere(0.5), mat, Vector3(0, 0.5, 0))
	body.add_child(head)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.5
	trunk.bottom_radius = 0.54
	trunk.height = 0.5
	body.add_child(_mesh(trunk, mat, Vector3(0, 0.25, 0)))
	# 裾の波：小さな球を輪に並べる
	for i in 8:
		var a := TAU * i / 8.0
		body.add_child(_mesh(_sphere(0.15), mat, Vector3(cos(a) * 0.44, 0.02, sin(a) * 0.44)))

	# 顔（正面は +Z）
	var eye_col := Color.WHITE if id == "lantern" else INK
	for x in [-0.17, 0.17]:
		var e := _mesh(_sphere(0.07), flat(eye_col), Vector3(x, 0.55, 0.46))
		e.scale = Vector3(0.8, 1.2, 0.5)
		body.add_child(e)
		eyes.append(e)
		var hi := _mesh(_sphere(0.022), flat(Color.WHITE), Vector3(x + 0.02, 0.59, 0.5))
		body.add_child(hi)
		var cheek := _mesh(_sphere(0.07), flat(Color("f6a8aa")), Vector3(x * 1.7, 0.42, 0.42))
		cheek.scale = Vector3(1.0, 0.55, 0.3)
		body.add_child(cheek)
	var mouth := _mesh(_sphere(0.05), flat(INK), Vector3(0, 0.43, 0.49))
	mouth.scale = Vector3(1.2, 0.6, 0.4)
	body.add_child(mouth)
	_add_prop(id)
	_t = randf() * TAU
	return self


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
		body.scale = Vector3(1.0 + sin(_t * 4.0) * 0.015, 1.0 - sin(_t * 4.0) * 0.015, 1.0)
	_blink -= delta
	if _blink < -3.0:
		_blink = 0.12
	for e in eyes:
		e.scale.y = 0.15 if _blink > 0 else 1.2
