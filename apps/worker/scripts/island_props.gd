class_name IslandProps
## 島の置き物の見た目（IslandKit.ITEMS の id ごと）。おばけと同じ塗り（Obake3D.prop / skin の輪郭つき）で、
## 箱は角を丸め（Obake3D.rbox）、円柱は縁を丸め（Obake3D.lathe）、曲がる物は管（Obake3D.tube）。
## 木の葉・松・岩は Blender 製（tools/blender/build_island_kit.py → assets/models/island/*.glb）。
## どれも足元が y=0、正面が +Z、中心が原点。

const GLB := "res://assets/models/island/%s.glb"
const WOOD := Color("c08a5c")
const WOOD_D := Color("8a5a3c")
const WOOD_L := Color("e0b98a")
const STONE := Color("b9b3ad")
const STONE_D := Color("8f8a88")
const PAPER := Color("fff4e2")
const RED := Color("e8575b")
const ROOF := Color("6f86c9")
const LEAF := Color("7cc46a")
const LEAF_D := Color("4f9a57")
const WATER := Color("7fd0e6")
const GOLD := Color("f2c14e")
const INK := Color("3a2e3c")

static var _meshes := {}


## id の置き物を組んで返す（知らない id なら小さな木箱）
static func build(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = id
	var fn := "_b_" + id
	var s := IslandProps.new()
	if s.has_method(fn):
		s.call(fn, root)
	else:
		s._crate(root)
	return root


# ---------------------------------------------------------------- 部品

static func m(c: Color, rim := 0.3, em := 0.0) -> Material:
	return Obake3D.prop(c, rim, em)


static func glow(c: Color, e := 1.2) -> Material:
	return Obake3D.skin(c, e, null, 0.2, 0.0, false)


func add(p: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	p.add_child(mi)
	return mi


func node(p: Node3D, pos := Vector3.ZERO, rot := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation = rot
	p.add_child(n)
	return n


func box(size: Vector3, bevel := -1.0) -> Mesh:
	if bevel < 0.0:
		bevel = clampf(minf(size.x, minf(size.y, size.z)) * 0.2, 0.004, 0.04)
	return Obake3D.rbox(size, bevel)


func cyl(top: float, bottom: float, h: float, bevel := -1.0) -> Mesh:
	var r := maxf(top, bottom)
	if bevel < 0.0:
		bevel = minf(minf(r, h) * 0.22, 0.03)
	return Obake3D.lathe(top, bottom, h, 40 if r >= 0.2 else (28 if r >= 0.06 else 14), bevel)


func sph(r: float) -> SphereMesh:
	var key := "s%s" % r
	if not _meshes.has(key):
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = 40 if r >= 0.2 else (24 if r >= 0.06 else 14)
		s.rings = s.radial_segments / 2
		_meshes[key] = s
	return _meshes[key]


func torus(inner: float, outer: float) -> TorusMesh:
	var key := "t%s/%s" % [inner, outer]
	if not _meshes.has(key):
		var t := TorusMesh.new()
		t.inner_radius = inner
		t.outer_radius = outer
		t.rings = 40
		t.ring_segments = 14
		_meshes[key] = t
	return _meshes[key]


## Blender 製のメッシュ（canopy_round / canopy_sakura / canopy_pine / rock / terrain_s0..2）
static func glb(name: String) -> Mesh:
	if not _meshes.has(name):
		var scn := load(GLB % name) as PackedScene
		var inst := scn.instantiate()
		for n in inst.find_children("*", "MeshInstance3D", true, false):
			_meshes[name] = (n as MeshInstance3D).mesh
			break
		inst.free()
	return _meshes.get(name)


## 広げた陸・小島の地面（地形と同じ色づけ：芝・砂・ぬれた砂・深い海の底）。半径 r、上は y=0 で平ら。
## 地形の材質の色合わせ（庭・お店の島・おでかけで同じ）。Blender で sRGB → 線形にしてから書き出した頂点色が、
## 取りこみでもう一度線形として読まれ（二重の線形化）、芝が #79E438 の蛍光色になっていた。ガンマを 1 回もどし、
## 島の光（約 2.2 倍）に合わせて明るさを下げる。昼の島で芝 ≈ #90C362・砂 ≈ #FFDC89（測った値）
const TERRAIN_GAMMA := 1.0 / 2.2
const TERRAIN_GAIN := 0.65


static func terrain_look(m: ShaderMaterial) -> void:
	m.set_shader_parameter("vertex_gamma", TERRAIN_GAMMA)
	m.set_shader_parameter("base_color", Color(TERRAIN_GAIN, TERRAIN_GAIN, TERRAIN_GAIN))


## 頂点色は線形の色（肌のシェーダーの vertex_albedo で使う）。岸は少しゆらぐ
static func land_lobe(r: float, seed_v := 0) -> ArrayMesh:
	var key := "lobe/%s/%d" % [r, seed_v]
	if _meshes.has(key):
		return _meshes[key]
	var grass := Color(0.58, 0.80, 0.45).srgb_to_linear()
	var grass2 := Color(0.47, 0.72, 0.40).srgb_to_linear()
	var sand := Color(0.93, 0.84, 0.64).srgb_to_linear()
	var wet := Color(0.78, 0.68, 0.52).srgb_to_linear()
	var bed := Color("1f6f8a").srgb_to_linear()
	var seg := 64
	var rings := 22
	var outer := r + 1.3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in rings + 1:
		var t := float(j) / rings
		var rho := outer * pow(t, 0.8)
		for i in seg + 1:
			var a := TAU * i / seg
			var edge := r * (1.0 + 0.06 * sin(3.0 * a + seed_v) + 0.035 * sin(5.0 * a + seed_v * 2.0))
			var d := rho - edge
			var h := 0.0 if d < -0.35 else -0.55 * _smooth(-0.35, 1.2, d)
			var x := cos(a) * rho
			var z := sin(a) * rho
			var n := 0.5 + 0.5 * sin(x * 1.7 + sin(z * 1.3) * 2.0) * sin(z * 1.9 + sin(x * 0.9))
			var g := grass.lerp(grass2, n * 0.6)
			var sd := sand.lerp(wet, _smooth(-0.12, -0.3, h))
			var c := sd.lerp(g, 1.0 - _smooth(-0.45, -0.25, d))
			c = c.lerp(bed, _smooth(-0.3, -0.55, h))
			st.set_color(c)
			st.add_vertex(Vector3(x, h, z))
	for j in rings:
		for i in seg:
			var a := j * (seg + 1) + i
			var b := a + seg + 1
			for id in [a, b, a + 1, a + 1, b, b + 1]:
				st.add_index(id)
	st.generate_normals()
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh


static func _smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func tube(key: String, pts: Array, radii: Array) -> Mesh:
	return Obake3D.tube(key, PackedVector3Array(pts), PackedFloat32Array(radii), 16)


func roof(p: Node3D, w: float, d: float, h: float, c: Color, pos: Vector3) -> void:
	# 切妻屋根：傾けた 2 枚の板
	var a := atan2(h, w * 0.5)
	var len := sqrt(pow(w * 0.5, 2) + h * h) + 0.08
	for sx in [-1.0, 1.0]:
		add(p, box(Vector3(len, 0.07, d + 0.16), 0.03), m(c), pos + Vector3(sx * w * 0.25, h * 0.5, 0), Vector3(0, 0, -sx * a))


func _crate(p: Node3D) -> void:
	add(p, box(Vector3(0.4, 0.4, 0.4)), m(WOOD), Vector3(0, 0.2, 0))


func _lamp_glow(p: Node3D, pos: Vector3, c := Color("ffd98a"), rng := 1.6) -> void:
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 0.0
	l.omni_range = rng
	l.position = pos
	l.set_meta("kit_lamp", true)
	p.add_child(l)


# ---------------------------------------------------------------- 家・お店

func _b_hut(p: Node3D) -> void:
	add(p, box(Vector3(1.1, 0.12, 1.0)), m(STONE_D), Vector3(0, 0.06, 0))
	add(p, box(Vector3(1.0, 0.62, 0.86)), m(Color("f3e2c8")), Vector3(0, 0.43, 0))
	for x in [-0.5, 0.5]:
		for z in [-0.43, 0.43]:
			add(p, box(Vector3(0.08, 0.66, 0.08)), m(WOOD_D), Vector3(x, 0.45, z))
	add(p, box(Vector3(0.3, 0.44, 0.04)), m(WOOD), Vector3(0, 0.36, 0.44))
	add(p, sph(0.025), m(GOLD), Vector3(0.09, 0.36, 0.47))
	add(p, box(Vector3(0.22, 0.18, 0.03)), glow(Color("ffe3a6"), 0.4), Vector3(0.32, 0.5, 0.44))
	roof(p, 1.3, 1.0, 0.42, Color("e7a15a"), Vector3(0, 0.76, 0))
	add(p, box(Vector3(0.1, 0.1, 1.2), 0.03), m(Color("c47c3c")), Vector3(0, 1.2, 0))


func _b_cottage(p: Node3D) -> void:
	add(p, box(Vector3(1.5, 0.14, 1.2)), m(STONE), Vector3(0, 0.07, 0))
	add(p, box(Vector3(1.36, 0.8, 1.06)), m(Color("fff3e3")), Vector3(0, 0.54, 0))
	add(p, box(Vector3(0.34, 0.54, 0.05)), m(Color("9a6a4a")), Vector3(-0.3, 0.41, 0.54))
	add(p, sph(0.028), m(GOLD), Vector3(-0.2, 0.41, 0.57))
	for x in [0.28]:
		add(p, box(Vector3(0.34, 0.3, 0.05)), glow(Color("ffe3a6"), 0.5), Vector3(x, 0.6, 0.54))
		add(p, box(Vector3(0.4, 0.05, 0.08)), m(WOOD_L), Vector3(x, 0.43, 0.56))
		add(p, box(Vector3(0.4, 0.1, 0.12)), m(Color("f08aa0")), Vector3(x, 0.38, 0.6))
	roof(p, 1.7, 1.2, 0.56, ROOF, Vector3(0, 0.96, 0))
	add(p, box(Vector3(0.2, 0.36, 0.2)), m(Color("c46a52")), Vector3(0.42, 1.38, -0.2))
	add(p, box(Vector3(0.9, 0.06, 0.4)), m(WOOD), Vector3(0, 0.03, 0.78))


func _stall(p: Node3D, awning: Array, counter: Color) -> void:
	add(p, box(Vector3(1.1, 0.5, 0.55)), m(counter), Vector3(0, 0.25, 0.05))
	add(p, box(Vector3(1.18, 0.06, 0.62)), m(WOOD_L), Vector3(0, 0.53, 0.05))
	for x in [-0.52, 0.52]:
		add(p, cyl(0.03, 0.03, 1.1), m(WOOD_D), Vector3(x, 0.55, -0.2))
	# しま模様の日よけ
	var n := awning.size()
	for i in 6:
		var x := -0.5 + i * 0.2
		add(p, box(Vector3(0.2, 0.05, 0.62), 0.02), m(awning[i % n]), Vector3(x, 1.1, 0.05), Vector3(0.28, 0, 0))
		add(p, cyl(0.1, 0.1, 0.02), m(awning[i % n]), Vector3(x, 1.0, 0.36), Vector3(PI / 2, 0, 0), Vector3(1, 1, 1))


func _b_cafe_stand(p: Node3D) -> void:
	_stall(p, [Color("fdf7ee"), Color("5fb7a8")], Color("e8c49a"))
	add(p, cyl(0.07, 0.06, 0.14), m(Color("fdf7ee")), Vector3(-0.3, 0.63, 0.1))
	add(p, cyl(0.07, 0.06, 0.14), m(Color("f7b6c2")), Vector3(-0.1, 0.63, 0.12))
	add(p, cyl(0.1, 0.12, 0.26), m(Color("5a5560")), Vector3(0.3, 0.69, -0.02))
	add(p, box(Vector3(0.5, 0.26, 0.03)), m(Color("3a4a44")), Vector3(0, 0.3, 0.34))
	add(p, box(Vector3(0.36, 0.03, 0.01)), m(Color("fdf7ee")), Vector3(0, 0.33, 0.36))


func _b_market_fruit(p: Node3D) -> void:
	_stall(p, [Color("fff5e0"), Color("f59b4b")], Color("d6a36f"))
	var cols := [Color("ff6f5b"), Color("ffb347"), Color("9bd06a"), Color("ffd24d")]
	for i in 8:
		add(p, sph(0.07), m(cols[i % 4], 0.4), Vector3(-0.42 + (i % 4) * 0.28, 0.62 + (i / 4) * 0.05, 0.12 - (i / 4) * 0.14))


func _b_market_fish(p: Node3D) -> void:
	_stall(p, [Color("f4fbff"), Color("4f9bd6")], Color("c9d6e0"))
	add(p, box(Vector3(0.9, 0.06, 0.4)), m(Color("dff4ff")), Vector3(0, 0.59, 0.05))
	for i in 3:
		var f := node(p, Vector3(-0.28 + i * 0.28, 0.65, 0.05), Vector3(0, 0.4 * (i - 1), 0))
		add(f, sph(0.08), m(Color("9fb8d0"), 0.5), Vector3.ZERO, Vector3.ZERO, Vector3(1.6, 0.6, 0.7))
		add(f, cyl(0.0, 0.06, 0.1), m(Color("8aa3bd")), Vector3(-0.16, 0, 0), Vector3(0, 0, PI / 2), Vector3(1, 1, 0.3))


func _b_ramen_cart(p: Node3D) -> void:
	add(p, box(Vector3(1.1, 0.5, 0.6)), m(Color("b5543e")), Vector3(0, 0.45, 0))
	add(p, box(Vector3(1.2, 0.05, 0.7)), m(WOOD_L), Vector3(0, 0.72, 0))
	for x in [-0.4, 0.4]:
		add(p, torus(0.1, 0.16), m(Color("4a4048")), Vector3(x, 0.16, 0.31), Vector3(PI / 2, 0, 0))
	for x in [-0.55, 0.55]:
		add(p, cyl(0.025, 0.025, 0.7), m(WOOD_D), Vector3(x, 1.05, -0.25))
	add(p, box(Vector3(1.24, 0.08, 0.5)), m(Color("2e2a36")), Vector3(0, 1.42, -0.1))
	for i in 3:
		add(p, box(Vector3(0.3, 0.34, 0.02), 0.01), m(Color("fdf2e0")), Vector3(-0.36 + i * 0.36, 1.2, 0.14))
	add(p, cyl(0.12, 0.1, 0.12), m(Color("fdf7ee")), Vector3(0.25, 0.8, 0.1))
	add(p, sph(0.12), glow(Color("ff8a5b"), 0.9), Vector3(-0.62, 1.1, 0.2), Vector3.ZERO, Vector3(1, 1.2, 1))
	_lamp_glow(p, Vector3(-0.62, 1.1, 0.4), Color("ffb37a"))


# ---------------------------------------------------------------- 座る

func _b_bench(p: Node3D) -> void:
	for i in 3:
		add(p, box(Vector3(1.0, 0.04, 0.11)), m(WOOD), Vector3(0, 0.3, -0.13 + i * 0.13))
	for i in 2:
		add(p, box(Vector3(1.0, 0.1, 0.04)), m(WOOD), Vector3(0, 0.46 + i * 0.13, -0.24), Vector3(-0.15, 0, 0))
	for x in [-0.42, 0.42]:
		add(p, box(Vector3(0.06, 0.3, 0.36)), m(Color("5b5d6b")), Vector3(x, 0.15, -0.02))
		add(p, box(Vector3(0.05, 0.36, 0.05)), m(Color("5b5d6b")), Vector3(x, 0.44, -0.24), Vector3(-0.15, 0, 0))


func _b_log_seat(p: Node3D) -> void:
	add(p, cyl(0.16, 0.16, 0.8), m(WOOD_D), Vector3(0, 0.16, 0), Vector3(0, 0, PI / 2))
	for x in [-0.41, 0.41]:
		add(p, cyl(0.135, 0.135, 0.02, 0.005), m(WOOD_L), Vector3(x, 0.16, 0), Vector3(0, 0, PI / 2))
	add(p, box(Vector3(0.7, 0.04, 0.2)), m(WOOD), Vector3(0, 0.3, 0))


func _b_cushion(p: Node3D) -> void:
	add(p, box(Vector3(0.48, 0.1, 0.48), 0.05), m(Color("e36b6f"), 0.4), Vector3(0, 0.05, 0))
	add(p, sph(0.025), m(GOLD), Vector3(0, 0.105, 0))
	for c in [Vector3(0.22, 0.05, 0.22), Vector3(-0.22, 0.05, 0.22), Vector3(0.22, 0.05, -0.22), Vector3(-0.22, 0.05, -0.22)]:
		add(p, sph(0.02), m(GOLD), c)


func _b_picnic_mat(p: Node3D) -> void:
	for i in 4:
		for j in 3:
			var c := Color("e86a6a") if (i + j) % 2 == 0 else Color("fdf7ee")
			add(p, box(Vector3(0.3, 0.02, 0.33), 0.006), m(c), Vector3(-0.45 + i * 0.3, 0.01, -0.33 + j * 0.33))
	add(p, box(Vector3(0.3, 0.16, 0.2)), m(Color("c8955e")), Vector3(0.35, 0.08, -0.25))
	add(p, torus(0.08, 0.1), m(WOOD_D), Vector3(0.35, 0.18, -0.25))
	add(p, cyl(0.05, 0.05, 0.08), m(Color("fdf7ee")), Vector3(-0.3, 0.06, 0.2))


func _b_parasol_table(p: Node3D) -> void:
	add(p, cyl(0.34, 0.34, 0.04), m(Color("fdf7ee")), Vector3(0, 0.5, 0))
	add(p, cyl(0.03, 0.03, 0.5), m(Color("6a6470")), Vector3(0, 0.25, 0))
	add(p, cyl(0.16, 0.18, 0.03), m(Color("6a6470")), Vector3(0, 0.015, 0))
	add(p, cyl(0.022, 0.022, 1.0), m(Color("fdf7ee")), Vector3(0, 1.0, 0))
	var cols := [Color("f28c8c"), Color("fdf7ee")]
	for i in 8:
		var a := TAU * i / 8.0
		add(p, box(Vector3(0.3, 0.03, 0.7), 0.012), m(cols[i % 2]), Vector3(sin(a) * 0.3, 1.38, cos(a) * 0.3), Vector3(0.36, a, 0), Vector3(1, 1, 1))
	add(p, sph(0.04), m(cols[0]), Vector3(0, 1.52, 0))
	for x in [-0.45, 0.45]:
		add(p, cyl(0.14, 0.14, 0.05), m(Color("f7c56b")), Vector3(x, 0.3, 0.1))
		add(p, cyl(0.02, 0.02, 0.3), m(Color("6a6470")), Vector3(x, 0.15, 0.1))


func _b_hammock(p: Node3D) -> void:
	for x in [-0.72, 0.72]:
		add(p, cyl(0.05, 0.06, 1.0), m(WOOD_D), Vector3(x, 0.5, 0))
		add(p, sph(0.06), m(WOOD_D), Vector3(x, 1.02, 0))
	add(p, tube("hammock", [Vector3(-0.7, 0.8, 0), Vector3(-0.35, 0.45, 0), Vector3(0, 0.38, 0), Vector3(0.35, 0.45, 0), Vector3(0.7, 0.8, 0)], [0.02, 0.1, 0.12, 0.1, 0.02]), m(Color("7cc4c0")), Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 2.2))


# ---------------------------------------------------------------- 灯り

func _b_stone_lantern(p: Node3D) -> void:
	add(p, cyl(0.2, 0.24, 0.1), m(STONE), Vector3(0, 0.05, 0))
	add(p, cyl(0.07, 0.09, 0.4), m(STONE), Vector3(0, 0.3, 0))
	add(p, cyl(0.18, 0.15, 0.06), m(STONE), Vector3(0, 0.52, 0))
	add(p, box(Vector3(0.26, 0.22, 0.26)), m(STONE), Vector3(0, 0.66, 0))
	add(p, box(Vector3(0.14, 0.12, 0.28), 0.01), glow(Color("ffd98a"), 1.6), Vector3(0, 0.67, 0))
	add(p, cyl(0.0, 0.26, 0.2, 0.02), m(STONE_D), Vector3(0, 0.87, 0))
	add(p, sph(0.04), m(STONE_D), Vector3(0, 0.99, 0))
	_lamp_glow(p, Vector3(0, 0.67, 0.2))


func _b_paper_lantern(p: Node3D) -> void:
	add(p, cyl(0.02, 0.02, 1.0), m(WOOD_D), Vector3(0, 0.5, 0))
	add(p, box(Vector3(0.3, 0.03, 0.03)), m(WOOD_D), Vector3(0.12, 1.0, 0))
	add(p, sph(0.13), glow(Color("ff9a6b"), 1.1), Vector3(0.24, 0.8, 0), Vector3.ZERO, Vector3(1, 1.25, 1))
	for y in [0.64, 0.96]:
		add(p, cyl(0.07, 0.07, 0.03), m(INK), Vector3(0.24, y, 0))
	_lamp_glow(p, Vector3(0.24, 0.8, 0.2), Color("ffb37a"))


func _b_street_lamp(p: Node3D) -> void:
	add(p, cyl(0.12, 0.15, 0.1), m(Color("4a4f63")), Vector3(0, 0.05, 0))
	add(p, cyl(0.035, 0.045, 1.2), m(Color("4a4f63")), Vector3(0, 0.66, 0))
	add(p, cyl(0.12, 0.08, 0.2), glow(Color("fff1c0"), 1.4), Vector3(0, 1.36, 0))
	add(p, cyl(0.0, 0.16, 0.1, 0.02), m(Color("4a4f63")), Vector3(0, 1.51, 0))
	add(p, sph(0.03), m(GOLD), Vector3(0, 1.58, 0))
	_lamp_glow(p, Vector3(0, 1.3, 0.1), Color("fff1c0"), 2.0)


func _b_string_lights(p: Node3D) -> void:
	for x in [-0.78, 0.78]:
		add(p, cyl(0.03, 0.035, 1.1), m(WOOD_D), Vector3(x, 0.55, 0))
	var pts := []
	for i in 9:
		var t := i / 8.0
		pts.append(Vector3(-0.78 + t * 1.56, 1.05 - sin(t * PI) * 0.22, 0))
	add(p, tube("strlights", pts, [0.008, 0.008, 0.008, 0.008, 0.008, 0.008, 0.008, 0.008, 0.008]), m(INK))
	var cols := [Color("ffd98a"), Color("ff9a9a"), Color("9ad7ff"), Color("b9f59a")]
	for i in 7:
		var t := (i + 1) / 8.0
		add(p, sph(0.04), glow(cols[i % 4], 1.6), Vector3(-0.78 + t * 1.56, 1.0 - sin(t * PI) * 0.22, 0), Vector3.ZERO, Vector3(1, 1.3, 1))


# ---------------------------------------------------------------- 柵・道・橋

func _b_fence_wood(p: Node3D) -> void:
	for i in 4:
		var x := -0.42 + i * 0.28
		add(p, box(Vector3(0.09, 0.5, 0.05)), m(Color("f3e6d3")), Vector3(x, 0.25, 0))
		add(p, cyl(0.0, 0.064, 0.07, 0.005), m(Color("f3e6d3")), Vector3(x, 0.53, 0), Vector3.ZERO, Vector3(1, 1, 0.55))
	for y in [0.16, 0.36]:
		add(p, box(Vector3(1.0, 0.06, 0.035)), m(Color("e6d4bd")), Vector3(0, y, -0.035))


func _b_fence_hedge(p: Node3D) -> void:
	add(p, box(Vector3(1.0, 0.46, 0.34), 0.12), m(LEAF_D, 0.35), Vector3(0, 0.23, 0))
	var r := RandomNumberGenerator.new()
	r.seed = 5
	for i in 6:
		add(p, sph(0.12), m(LEAF_D.lightened(0.08), 0.35), Vector3(-0.4 + i * 0.16, 0.44 + r.randf() * 0.04, r.randf_range(-0.08, 0.08)))
	for i in 3:
		add(p, sph(0.03), m(Color("fff0f5")), Vector3(-0.3 + i * 0.3, 0.4, 0.17))


func _b_stepping_stones(p: Node3D) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 11
	for i in 3:
		add(p, cyl(0.16, 0.18, 0.05, 0.02), m(STONE.darkened(r.randf() * 0.1)), Vector3(-0.33 + i * 0.33, 0.025, r.randf_range(-0.08, 0.08)), Vector3(0, r.randf() * 3.0, 0), Vector3(1.15, 1, 0.9))


func _b_path_brick(p: Node3D) -> void:
	for i in 4:
		for j in 4:
			var off := 0.12 if j % 2 else 0.0
			var c := Color("d99a78") if (i + j) % 3 else Color("c98566")
			add(p, box(Vector3(0.23, 0.04, 0.23), 0.012), m(c), Vector3(-0.36 + i * 0.24 + off - 0.06, 0.02, -0.36 + j * 0.24))


func _b_bridge_arch(p: Node3D) -> void:
	var pts := []
	var rad := []
	for i in 9:
		var t := i / 8.0
		pts.append(Vector3(-0.8 + t * 1.6, 0.05 + sin(t * PI) * 0.3, 0))
	for i in 12:
		var t := (i + 0.5) / 12.0
		var y := 0.06 + sin(t * PI) * 0.3
		var a := cos(t * PI) * 0.35
		add(p, box(Vector3(0.13, 0.04, 0.62), 0.01), m(Color("d9774f")), Vector3(-0.75 + t * 1.5, y, 0), Vector3(0, 0, a))
	for sz in [-0.3, 0.3]:
		for i in 9:
			rad.append(0.022)
		var rail := []
		for q in pts:
			rail.append(q + Vector3(0, 0.3, sz))
		add(p, tube("arch_rail%s" % sz, rail, rad.slice(0, 9)), m(RED))
		for i in 5:
			var t := (i + 0.5) / 5.0
			add(p, cyl(0.02, 0.02, 0.3), m(RED), Vector3(-0.8 + t * 1.6, 0.2 + sin(t * PI) * 0.3, sz))


func _b_bridge_islet(p: Node3D) -> void:
	for i in 14:
		var x := -1.15 + i * 0.177
		add(p, box(Vector3(0.15, 0.05, 0.72), 0.012), m(WOOD if i % 2 else WOOD_L), Vector3(x, 0.08, 0), Vector3(0, 0, 0))
	for x in [-1.2, -0.4, 0.4, 1.2]:
		for z in [-0.38, 0.38]:
			add(p, cyl(0.045, 0.05, 0.9), m(WOOD_D), Vector3(x, 0.0, z))
	for z in [-0.38, 0.38]:
		var rope := []
		for i in 9:
			var t := i / 8.0
			rope.append(Vector3(-1.2 + t * 2.4, 0.42 - sin(fmod(t * 3.0, 1.0) * PI) * 0.08, z))
		add(p, tube("islet_rope%s" % z, rope, [0.014, 0.014, 0.014, 0.014, 0.014, 0.014, 0.014, 0.014, 0.014]), m(Color("d8c49a")))


# ---------------------------------------------------------------- 木

func _trunk(p: Node3D, h: float, r: float, bend := 0.0) -> void:
	add(p, tube("trunk%s/%s/%s" % [h, r, bend], [Vector3(0, 0, 0), Vector3(bend * 0.3, h * 0.4, 0), Vector3(bend, h, 0)], [r * 1.35, r, r * 0.8]), m(Color("9a6a4a")))


func _b_tree_round(p: Node3D) -> void:
	_trunk(p, 0.8, 0.08)
	add(p, glb("canopy_round"), Obake3D.skin(Color("86cc6c"), 0.0, null, 0.18, 0.08), Vector3(0, 1.15, 0), Vector3.ZERO, Vector3.ONE * 0.82)


func _b_tree_sakura(p: Node3D) -> void:
	_trunk(p, 0.85, 0.08, 0.08)
	add(p, glb("canopy_sakura"), Obake3D.skin(Color("f8bfd0"), 0.0, null, 0.2, 0.1), Vector3(0.08, 1.2, 0), Vector3.ZERO, Vector3.ONE * 0.9)
	for i in 5:
		add(p, sph(0.03), m(Color("fbd3de")), Vector3(-0.5 + i * 0.25, 0.02, 0.3 + (i % 2) * 0.2), Vector3.ZERO, Vector3(1, 0.3, 1))


func _b_tree_pine(p: Node3D) -> void:
	_trunk(p, 0.5, 0.07)
	add(p, glb("canopy_pine"), Obake3D.skin(Color("4f9a6a"), 0.0, null, 0.16, 0.05), Vector3(0, 0.42, 0), Vector3.ZERO, Vector3(0.9, 1.05, 0.9))


func _b_tree_palm(p: Node3D) -> void:
	var top := Vector3(0.25, 1.5, 0)
	add(p, tube("palm", [Vector3.ZERO, Vector3(0.05, 0.5, 0), Vector3(0.14, 1.0, 0), top], [0.1, 0.08, 0.07, 0.06]), m(Color("b88a5a")))
	for i in 7:
		var a := TAU * i / 7.0
		var dir := Vector3(cos(a), 0, sin(a))
		var pts := [top, top + dir * 0.3 + Vector3(0, 0.12, 0), top + dir * 0.6 + Vector3(0, 0.02, 0), top + dir * 0.82 + Vector3(0, -0.2, 0)]
		add(p, tube("frond%d" % i, pts, [0.03, 0.09, 0.07, 0.01]), m(Color("5fb65a"), 0.35), Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.45, 1))
	for i in 3:
		add(p, sph(0.07), m(Color("7a5230")), top + Vector3(cos(i * 2.1) * 0.08, -0.08, sin(i * 2.1) * 0.08))


func _b_bush(p: Node3D) -> void:
	add(p, glb("canopy_round"), Obake3D.skin(Color("6fbf64"), 0.0, null, 0.18, 0.05), Vector3(0, 0.26, 0), Vector3.ZERO, Vector3(0.42, 0.36, 0.42))
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		add(p, sph(0.035), m(Color("fff0a8")), Vector3(cos(a) * 0.24, 0.3 + (i % 2) * 0.08, sin(a) * 0.24))


# ---------------------------------------------------------------- 花

func _flower(p: Node3D, pos: Vector3, c: Color, h := 0.24, s := 1.0) -> void:
	add(p, cyl(0.01, 0.012, h, 0.0), m(LEAF_D), pos + Vector3(0, h * 0.5, 0))
	var f := node(p, pos + Vector3(0, h, 0))
	for k in 5:
		var a := TAU * k / 5.0
		add(f, sph(0.035 * s), m(c, 0.4), Vector3(cos(a), 0, sin(a)) * 0.035 * s, Vector3.ZERO, Vector3(1, 0.45, 1))
	add(f, sph(0.022 * s), m(Color("ffd54d")), Vector3(0, 0.012, 0))


func _b_flower_pot(p: Node3D) -> void:
	add(p, cyl(0.15, 0.11, 0.22), m(Color("d9774f")), Vector3(0, 0.11, 0))
	add(p, cyl(0.16, 0.16, 0.04), m(Color("e08a62")), Vector3(0, 0.22, 0))
	add(p, cyl(0.13, 0.13, 0.02), m(Color("6b4a3a")), Vector3(0, 0.23, 0))
	_flower(p, Vector3(0, 0.22, 0), Color("ff8fb1"), 0.18, 1.3)
	_flower(p, Vector3(0.06, 0.22, 0.04), Color("fff5f8"), 0.12, 1.0)


func _b_flower_bed(p: Node3D) -> void:
	add(p, box(Vector3(1.2, 0.16, 0.6)), m(WOOD), Vector3(0, 0.08, 0))
	add(p, box(Vector3(1.1, 0.04, 0.5)), m(Color("6b4a3a")), Vector3(0, 0.15, 0))
	var cols := [Color("ff8fb1"), Color("ffd54d"), Color("b89bff"), Color("ff9a6b"), Color("fff5f8")]
	for i in 10:
		_flower(p, Vector3(-0.45 + (i % 5) * 0.22, 0.16, -0.12 + (i / 5) * 0.24), cols[i % 5], 0.2 + (i % 3) * 0.04)


func _b_tulip_patch(p: Node3D) -> void:
	var cols := [Color("ff6f7d"), Color("ffd24d"), Color("ff9fc5")]
	var r := RandomNumberGenerator.new()
	r.seed = 3
	for i in 9:
		var pos := Vector3(-0.3 + (i % 3) * 0.3 + r.randf_range(-0.05, 0.05), 0, -0.3 + (i / 3) * 0.3)
		add(p, cyl(0.012, 0.014, 0.3, 0.0), m(LEAF_D), pos + Vector3(0, 0.15, 0))
		add(p, sph(0.06), m(cols[i % 3], 0.4), pos + Vector3(0, 0.34, 0), Vector3.ZERO, Vector3(0.9, 1.25, 0.9))
		add(p, sph(0.06), m(LEAF, 0.3), pos + Vector3(0.04, 0.1, 0), Vector3(0, 0, -0.6), Vector3(0.35, 1.2, 0.25))


func _b_sunflowers(p: Node3D) -> void:
	for i in 3:
		var pos := Vector3(-0.25 + i * 0.25, 0, (i % 2) * 0.1)
		var h := 0.7 + (i % 2) * 0.15
		add(p, cyl(0.018, 0.022, h, 0.0), m(LEAF_D), pos + Vector3(0, h * 0.5, 0))
		var f := node(p, pos + Vector3(0, h, 0.02), Vector3(0.3, 0, 0))
		for k in 12:
			var a := TAU * k / 12.0
			add(f, sph(0.05), m(Color("ffcc33"), 0.35), Vector3(cos(a), sin(a), 0) * 0.1, Vector3(0, 0, a), Vector3(0.5, 1.3, 0.25))
		add(f, cyl(0.075, 0.075, 0.04), m(Color("7a4a2a")), Vector3(0, 0, 0.01), Vector3(PI / 2, 0, 0))


# ---------------------------------------------------------------- 水

func _water_disc(p: Node3D, rx: float, rz: float, y: float) -> void:
	var w := Obake3D.skin(WATER, 0.15, null, 0.5, 0.0, false, 0.4)
	add(p, cyl(1.0, 1.0, 0.02, 0.0), w, Vector3(0, y, 0), Vector3.ZERO, Vector3(rx, 1, rz))


func _b_pond(p: Node3D) -> void:
	_water_disc(p, 0.66, 0.46, 0.03)
	var r := RandomNumberGenerator.new()
	r.seed = 9
	for i in 14:
		var a := TAU * i / 14.0
		add(p, glb("rock"), m(STONE.darkened(r.randf() * 0.12)), Vector3(cos(a) * 0.72, 0.03, sin(a) * 0.52), Vector3(0, r.randf() * 3, 0), Vector3.ONE * r.randf_range(0.18, 0.26))
	for i in 2:
		add(p, cyl(0.1, 0.1, 0.01, 0.0), m(LEAF), Vector3(-0.2 + i * 0.35, 0.05, 0.1 - i * 0.15))
	add(p, sph(0.04), m(Color("ffb3c8")), Vector3(-0.2, 0.08, 0.1))


func _b_pier(p: Node3D) -> void:
	for i in 10:
		add(p, box(Vector3(0.8, 0.05, 0.2), 0.012), m(WOOD if i % 2 else WOOD_L), Vector3(0, 0.14, -1.0 + i * 0.22))
	for z in [-1.0, 0.0, 1.0]:
		for x in [-0.38, 0.38]:
			add(p, cyl(0.05, 0.055, 0.7), m(WOOD_D), Vector3(x, -0.15, z))
	add(p, cyl(0.06, 0.06, 0.3), m(WOOD_D), Vector3(0.38, 0.3, 1.0))
	add(p, torus(0.08, 0.13), m(RED), Vector3(-0.44, 0.35, 0.9), Vector3(0, 0, PI / 2))
	add(p, torus(0.08, 0.13), m(Color("fdf7ee")), Vector3(-0.44, 0.35, 0.9), Vector3(0, 0, PI / 2), Vector3(1.02, 0.4, 1.02))


func _b_hot_spring(p: Node3D) -> void:
	_water_disc(p, 0.62, 0.52, 0.12)
	var r := RandomNumberGenerator.new()
	r.seed = 21
	for i in 16:
		var a := TAU * i / 16.0
		add(p, glb("rock"), m(Color("9a9290").darkened(r.randf() * 0.15)), Vector3(cos(a) * 0.7, 0.08, sin(a) * 0.58), Vector3(0, r.randf() * 3, 0), Vector3.ONE * r.randf_range(0.26, 0.34))
	add(p, box(Vector3(0.7, 0.9, 0.06)), m(WOOD), Vector3(0, 0.45, -0.72))
	add(p, box(Vector3(0.5, 0.2, 0.02)), m(Color("f3ecff")), Vector3(0, 0.7, -0.68))
	add(p, cyl(0.06, 0.06, 0.02), m(Color("e05a5a")), Vector3(0, 0.7, -0.67), Vector3(PI / 2, 0, 0))
	for i in 3:
		var st := add(p, sph(0.12), Obake3D.skin(Color(1, 1, 1), 0.5, null, 0.5, 0.0, false), Vector3(-0.2 + i * 0.2, 0.55 + i * 0.12, 0.0), Vector3.ZERO, Vector3(1.2, 0.8, 1.0))
		st.set_meta("steam", i)


func _b_fountain(p: Node3D) -> void:
	add(p, cyl(0.5, 0.52, 0.2), m(STONE), Vector3(0, 0.1, 0))
	_water_disc(p, 0.44, 0.44, 0.19)
	add(p, cyl(0.07, 0.1, 0.5), m(STONE), Vector3(0, 0.4, 0))
	add(p, cyl(0.24, 0.1, 0.1), m(STONE), Vector3(0, 0.66, 0))
	_water_disc(p, 0.2, 0.2, 0.7)
	add(p, sph(0.05), m(Color("dff4ff"), 0.6), Vector3(0, 0.84, 0))
	for i in 6:
		var a := TAU * i / 6.0
		add(p, sph(0.025), m(Color("dff4ff"), 0.6), Vector3(cos(a) * 0.18, 0.62, sin(a) * 0.18))


# ---------------------------------------------------------------- しるし

func _b_lighthouse(p: Node3D, stripe := RED, top := Color("fdf7ee"), lamp := Color("fff1c0")) -> void:
	add(p, cyl(0.5, 0.56, 0.16), m(STONE), Vector3(0, 0.08, 0))
	var h := 2.0
	for i in 5:
		var y0 := 0.16 + i * h / 5.0
		var r0 := lerpf(0.4, 0.26, float(i) / 5.0)
		var r1 := lerpf(0.4, 0.26, float(i + 1) / 5.0)
		add(p, cyl(r1, r0, h / 5.0, 0.0), m(stripe if i % 2 else Color("fdf7ee")), Vector3(0, y0 + h / 10.0, 0))
	add(p, box(Vector3(0.14, 0.24, 0.04)), m(WOOD_D), Vector3(0, 0.3, 0.39))
	add(p, cyl(0.36, 0.36, 0.06), m(Color("4a4f63")), Vector3(0, 2.2, 0))
	add(p, cyl(0.2, 0.2, 0.3, 0.0), glow(lamp, 2.2), Vector3(0, 2.38, 0))
	for i in 6:
		var a := TAU * i / 6.0
		add(p, cyl(0.015, 0.015, 0.32), m(Color("4a4f63")), Vector3(cos(a) * 0.2, 2.38, sin(a) * 0.2))
	add(p, cyl(0.0, 0.3, 0.26, 0.02), m(top.darkened(0.0) if top != Color("fdf7ee") else stripe), Vector3(0, 2.66, 0))
	add(p, sph(0.05), m(GOLD), Vector3(0, 2.82, 0))
	for i in 12:
		var a := TAU * i / 12.0
		add(p, cyl(0.012, 0.012, 0.14), m(Color("4a4f63")), Vector3(cos(a) * 0.34, 2.3, sin(a) * 0.34))
	_lamp_glow(p, Vector3(0, 2.4, 0.3), lamp, 3.0)


func _b_torii_gate(p: Node3D) -> void:
	for x in [-0.6, 0.6]:
		add(p, cyl(0.07, 0.08, 1.5), m(RED), Vector3(x, 0.75, 0))
		add(p, cyl(0.1, 0.1, 0.12), m(INK), Vector3(x, 0.06, 0))
	add(p, box(Vector3(1.5, 0.08, 0.14)), m(RED), Vector3(0, 1.22, 0))
	add(p, box(Vector3(1.9, 0.1, 0.2), 0.04), m(INK), Vector3(0, 1.58, 0))
	add(p, box(Vector3(1.8, 0.1, 0.2), 0.04), m(RED), Vector3(0, 1.49, 0))
	add(p, box(Vector3(0.1, 0.26, 0.1)), m(RED), Vector3(0, 1.36, 0))


func _b_windmill(p: Node3D) -> void:
	add(p, cyl(0.34, 0.5, 1.5), m(Color("fdf1dc")), Vector3(0, 0.75, 0))
	add(p, cyl(0.0, 0.44, 0.5, 0.03), m(Color("c46a52")), Vector3(0, 1.75, 0))
	add(p, box(Vector3(0.22, 0.36, 0.04)), m(WOOD_D), Vector3(0, 0.18, 0.47))
	add(p, box(Vector3(0.18, 0.18, 0.04)), glow(Color("ffe3a6"), 0.5), Vector3(0, 0.95, 0.41))
	var hub := node(p, Vector3(0, 1.45, 0.42))
	hub.set_meta("spin", 0.6)
	add(hub, sph(0.07), m(WOOD_D))
	for i in 4:
		var a := TAU * i / 4.0 + 0.3
		var blade := node(hub, Vector3.ZERO, Vector3(0, 0, a))
		add(blade, box(Vector3(0.05, 0.8, 0.02)), m(WOOD_D), Vector3(0, 0.42, 0))
		add(blade, box(Vector3(0.2, 0.62, 0.015), 0.006), m(Color("fdf7ee")), Vector3(0.11, 0.48, 0))


# ---------------------------------------------------------------- 遊ぶ

func _b_swing(p: Node3D) -> void:
	for x in [-0.55, 0.55]:
		for z in [-0.25, 0.25]:
			add(p, cyl(0.035, 0.035, 1.1), m(Color("5fa8d6")), Vector3(x, 0.55, z * 0.6), Vector3(z * 0.9, 0, 0))
	add(p, cyl(0.04, 0.04, 1.2), m(Color("5fa8d6")), Vector3(0, 1.08, 0), Vector3(0, 0, PI / 2))
	for x in [-0.16, 0.16]:
		add(p, cyl(0.008, 0.008, 0.72), m(INK), Vector3(x, 0.7, 0))
	add(p, box(Vector3(0.42, 0.04, 0.2)), m(Color("ffcf5a")), Vector3(0, 0.34, 0))


func _b_slide(p: Node3D) -> void:
	for x in [-0.5, -0.2]:
		for z in [-0.2, 0.2]:
			add(p, cyl(0.03, 0.03, 0.8), m(Color("ff8a5b")), Vector3(x, 0.4, z))
	add(p, box(Vector3(0.4, 0.05, 0.46)), m(Color("ffcf5a")), Vector3(-0.35, 0.8, 0))
	for i in 4:
		add(p, box(Vector3(0.04, 0.04, 0.4)), m(Color("ff8a5b")), Vector3(-0.6, 0.18 + i * 0.18, 0), Vector3(0, 0, 0))
	add(p, box(Vector3(1.0, 0.04, 0.36)), m(Color("5fc4c0")), Vector3(0.28, 0.45, 0), Vector3(0, 0, -0.66))
	for z in [-0.18, 0.18]:
		add(p, box(Vector3(1.0, 0.07, 0.03)), m(Color("5fc4c0")), Vector3(0.28, 0.49, z), Vector3(0, 0, -0.66))


func _b_sandbox(p: Node3D) -> void:
	for i in 4:
		var a := PI * 0.5 * i
		add(p, box(Vector3(1.0, 0.14, 0.08)), m(WOOD), Vector3(sin(a) * 0.46, 0.07, cos(a) * 0.46), Vector3(0, a, 0))
	add(p, box(Vector3(0.88, 0.08, 0.88), 0.03), m(Color("f0dcae")), Vector3(0, 0.05, 0))
	add(p, cyl(0.0, 0.14, 0.14, 0.02), m(Color("e8cf9a")), Vector3(-0.15, 0.14, 0.1))
	add(p, cyl(0.07, 0.06, 0.1), m(Color("ff6f7d")), Vector3(0.2, 0.14, -0.15))
	add(p, glb("rock"), m(Color("fff0f0")), Vector3(0.25, 0.1, 0.2), Vector3.ZERO, Vector3.ONE * 0.08)


func _b_yarn_ball(p: Node3D) -> void:
	add(p, sph(0.15), m(Color("f07aa0"), 0.4), Vector3(0, 0.15, 0))
	for i in 3:
		add(p, torus(0.148, 0.158), m(Color("f59bb8")), Vector3(0, 0.15, 0), Vector3(i * 1.0, i * 0.7, 0.3))
	add(p, tube("yarn_tail", [Vector3(0.1, 0.05, 0.1), Vector3(0.25, 0.01, 0.2), Vector3(0.4, 0.01, 0.1)], [0.01, 0.01, 0.01]), m(Color("f07aa0")))


# ---------------------------------------------------------------- 小物

func _b_mailbox(p: Node3D) -> void:
	add(p, cyl(0.03, 0.035, 0.7), m(WOOD_D), Vector3(0, 0.35, 0))
	add(p, box(Vector3(0.22, 0.2, 0.32), 0.03), m(Color("e8575b")), Vector3(0, 0.78, 0))
	add(p, cyl(0.11, 0.11, 0.32, 0.02), m(Color("e8575b")), Vector3(0, 0.88, 0), Vector3(PI / 2, 0, 0))
	add(p, box(Vector3(0.02, 0.14, 0.04)), m(GOLD), Vector3(0.12, 0.92, 0.08))
	add(p, box(Vector3(0.1, 0.06, 0.02)), m(GOLD), Vector3(0.14, 1.0, 0.08))


func _b_bulletin_board(p: Node3D) -> void:
	for x in [-0.42, 0.42]:
		add(p, cyl(0.035, 0.035, 1.1), m(WOOD_D), Vector3(x, 0.55, 0))
	add(p, box(Vector3(0.9, 0.56, 0.05)), m(Color("c69a6c")), Vector3(0, 0.75, 0))
	add(p, box(Vector3(1.0, 0.07, 0.16), 0.02), m(Color("7a5a8c")), Vector3(0, 1.08, 0))
	var cols := [Color("fff6e0"), Color("ffe0ea"), Color("e0f4ff"), Color("f0ffe0")]
	for i in 4:
		add(p, box(Vector3(0.22, 0.2, 0.01), 0.004), m(cols[i]), Vector3(-0.3 + i * 0.2, 0.74 + (i % 2) * 0.08, 0.03), Vector3(0, 0, (i - 1.5) * 0.08))
		add(p, sph(0.012), m(RED), Vector3(-0.3 + i * 0.2, 0.82 + (i % 2) * 0.08, 0.045))


func _b_signpost(p: Node3D) -> void:
	add(p, cyl(0.035, 0.04, 1.0), m(WOOD_D), Vector3(0, 0.5, 0))
	var cols := [Color("fdf1dc"), Color("ffd9c4"), Color("dff0ff")]
	for i in 3:
		var n := node(p, Vector3(0, 0.88 - i * 0.2, 0), Vector3(0, (i - 1) * 0.9, 0))
		add(n, box(Vector3(0.5, 0.13, 0.04)), m(cols[i]), Vector3(0.2, 0, 0))
		add(n, cyl(0.0, 0.07, 0.1, 0.0), m(cols[i]), Vector3(0.49, 0, 0), Vector3(0, 0, -PI / 2), Vector3(1, 1, 0.3))


func _b_shell_pile(p: Node3D) -> void:
	var cols := [Color("fbe3d6"), Color("f7c6c6"), Color("fff5e8"), Color("f0d6ff")]
	for i in 6:
		var a := TAU * i / 6.0
		var sh := node(p, Vector3(cos(a) * 0.14, 0.03, sin(a) * 0.14), Vector3(0, a, 0))
		add(sh, sph(0.06), m(cols[i % 4], 0.45), Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.5, 0.8))
		for k in 3:
			add(sh, torus(0.03 + k * 0.012, 0.033 + k * 0.012), m(cols[i % 4].darkened(0.1)), Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1, 0.5, 0.8))
	add(p, glb("rock"), m(Color("fff4f0")), Vector3(0, 0.06, 0), Vector3.ZERO, Vector3.ONE * 0.12)


# ---------------------------------------------------------------- 季節

func _b_snowman(p: Node3D) -> void:
	add(p, sph(0.26), m(Color("f7fbff"), 0.5), Vector3(0, 0.24, 0))
	add(p, sph(0.19), m(Color("f7fbff"), 0.5), Vector3(0, 0.6, 0))
	add(p, torus(0.15, 0.2), m(Color("e8575b")), Vector3(0, 0.46, 0))
	add(p, cyl(0.12, 0.14, 0.18), m(Color("5a6ab0")), Vector3(0, 0.84, 0), Vector3(0, 0, 0.15))
	for x in [-0.06, 0.06]:
		add(p, sph(0.022), m(INK), Vector3(x, 0.66, 0.17))
	add(p, cyl(0.0, 0.03, 0.14, 0.0), m(Color("ff8a3d")), Vector3(0, 0.6, 0.22), Vector3(PI / 2, 0, 0))
	for sx in [-1.0, 1.0]:
		add(p, cyl(0.012, 0.016, 0.34, 0.0), m(WOOD_D), Vector3(sx * 0.26, 0.62, 0), Vector3(0, 0, sx * 1.0))


func _b_pumpkin_patch(p: Node3D) -> void:
	for i in 3:
		var pos := Vector3(-0.28 + i * 0.28, 0, (i % 2) * 0.16 - 0.05)
		var s := 1.0 - (i % 2) * 0.25
		for k in 6:
			var a := TAU * k / 6.0
			add(p, sph(0.1 * s), m(Color("ff9a3d"), 0.4), pos + Vector3(cos(a) * 0.05 * s, 0.1 * s, sin(a) * 0.05 * s), Vector3.ZERO, Vector3(0.8, 1, 0.8))
		add(p, cyl(0.015, 0.02, 0.08, 0.0), m(LEAF_D), pos + Vector3(0, 0.22 * s, 0), Vector3(0, 0, 0.3))
	add(p, sph(0.1), m(LEAF, 0.3), Vector3(0.2, 0.03, 0.25), Vector3.ZERO, Vector3(1.2, 0.2, 0.8))


func _b_tanabata_bamboo(p: Node3D) -> void:
	add(p, cyl(0.1, 0.12, 0.2), m(Color("8a6a4a")), Vector3(0, 0.1, 0))
	add(p, tube("bamboo", [Vector3(0, 0.1, 0), Vector3(0.02, 0.8, 0), Vector3(0.1, 1.5, 0)], [0.03, 0.028, 0.02]), m(Color("7cc46a")))
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 7:
		var y := 0.7 + i * 0.12
		var sx := -1.0 if i % 2 else 1.0
		add(p, box(Vector3(0.22, 0.03, 0.06), 0.01), m(LEAF_D), Vector3(sx * 0.12 + 0.03, y, 0), Vector3(0, 0, sx * 0.4))
	var cols := [Color("ff8fb1"), Color("ffd54d"), Color("8fd6ff"), Color("b89bff")]
	for i in 5:
		add(p, box(Vector3(0.05, 0.14, 0.005), 0.002), m(cols[i % 4]), Vector3(r.randf_range(-0.25, 0.28), 0.8 + i * 0.13, r.randf_range(-0.05, 0.05)))


func _b_koinobori(p: Node3D) -> void:
	add(p, cyl(0.03, 0.035, 2.0), m(Color("e6e0da")), Vector3(0, 1.0, 0))
	add(p, sph(0.06), m(GOLD), Vector3(0, 2.03, 0))
	var cols := [Color("3a4a8c"), Color("e8575b"), Color("5fb7d6")]
	for i in 3:
		var y := 1.8 - i * 0.36
		var s := 1.0 - i * 0.15
		var fish := node(p, Vector3(0.05, y, 0))
		fish.set_meta("flutter", i)
		add(fish, tube("koi%d" % i, [Vector3(0, 0, 0), Vector3(0.25 * s, -0.02, 0), Vector3(0.55 * s, -0.06, 0)], [0.1 * s, 0.09 * s, 0.05 * s]), m(cols[i], 0.35))
		add(fish, sph(0.035 * s), m(Color("fdf7ee")), Vector3(0.05, 0.03, 0.08 * s))
		add(fish, sph(0.018 * s), m(INK), Vector3(0.06, 0.03, 0.1 * s))


# ---------------------------------------------------------------- 見本の有料アイテム（見た目だけ）

func _b_lighthouse_starlight(p: Node3D) -> void:
	_b_lighthouse(p, Color("6a5bd6"), Color("3a2e7a"), Color("c9f0ff"))
	for i in 5:
		var a := TAU * i / 5.0
		add(p, sph(0.05), glow(Color("fff1a8"), 2.0), Vector3(cos(a) * 0.55, 1.2 + i * 0.25, sin(a) * 0.55))


func _b_festival_yagura(p: Node3D) -> void:
	for x in [-0.55, 0.55]:
		for z in [-0.55, 0.55]:
			add(p, cyl(0.05, 0.06, 1.3), m(WOOD_D), Vector3(x, 0.65, z))
	add(p, box(Vector3(1.3, 0.1, 1.3)), m(WOOD), Vector3(0, 1.0, 0))
	for i in 4:
		var a := PI * 0.5 * i
		add(p, box(Vector3(1.24, 0.2, 0.03)), m(Color("fdf7ee")), Vector3(sin(a) * 0.62, 0.86, cos(a) * 0.62), Vector3(0, a, 0))
		add(p, box(Vector3(1.24, 0.06, 0.035)), m(RED), Vector3(sin(a) * 0.625, 0.8, cos(a) * 0.625), Vector3(0, a, 0))
	roof(p, 1.5, 1.4, 0.35, RED, Vector3(0, 1.4, 0))
	add(p, cyl(0.26, 0.26, 0.3), m(Color("b5543e")), Vector3(0, 1.2, 0), Vector3(PI / 2, 0, 0))
	for i in 8:
		var a := TAU * i / 8.0
		add(p, sph(0.07), glow(Color("ff9a6b"), 1.2), Vector3(cos(a) * 0.72, 1.45, sin(a) * 0.72), Vector3.ZERO, Vector3(1, 1.25, 1))
	_lamp_glow(p, Vector3(0, 1.2, 0.8), Color("ffb37a"), 2.5)


func _b_lantern_arch(p: Node3D) -> void:
	var pts := []
	for i in 9:
		var t := i / 8.0
		pts.append(Vector3(-0.85 + t * 1.7, 0.1 + sin(t * PI) * 1.25, 0))
	add(p, tube("lantern_arch", pts, [0.05, 0.045, 0.04, 0.04, 0.04, 0.04, 0.04, 0.045, 0.05]), m(RED))
	for i in 7:
		var t := (i + 1) / 8.0
		var c := Color("ffd98a") if i % 2 else Color("ff9a6b")
		add(p, sph(0.07), glow(c, 1.4), Vector3(-0.85 + t * 1.7, sin(t * PI) * 1.25 - 0.08, 0), Vector3.ZERO, Vector3(1, 1.3, 1))
	_lamp_glow(p, Vector3(0, 1.0, 0.3), Color("ffc58a"), 2.2)
