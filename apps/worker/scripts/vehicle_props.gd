class_name VehicleProps
extends IslandProps
## 乗り物の見た目（Vehicles.LIST の id ごと）。島の置き物と同じ塗り・丸めた部品で組む。
## 正面（進む向き）は +X。水面が y=0。おばけが乗る場所に "Seat"（Node3D）を置く。
## 回る部品（プロペラ・ローター）には meta "spin_axis"（Vector3）と "spin"（回転の速さ）。


static func build_vehicle(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = id
	var s := VehicleProps.new()
	var fn := "_v_" + id
	if s.has_method(fn):
		s.call(fn, root)
	else:
		s._v_raft(root)
	return root


## おばけを乗せる（Seat の子にする）。s は乗せるおばけの大きさ
static func seat(vehicle: Node3D, ob: Node3D, s := 0.42) -> void:
	var st := vehicle.find_child("Seat", true, false) as Node3D
	ob.scale = Vector3.ONE * s
	ob.rotation.y = PI / 2 # 進む向き（+X）を見る
	(st if st else vehicle).add_child(ob)


func _seat(p: Node3D, pos: Vector3) -> void:
	var n := Node3D.new()
	n.name = "Seat"
	n.position = pos
	p.add_child(n)


func _spinner(p: Node3D, pos: Vector3, axis: Vector3, speed: float) -> Node3D:
	var n := node(p, pos)
	n.set_meta("spin_axis", axis)
	n.set_meta("spin", speed)
	return n


# ---------------------------------------------------------------- いかだ

func _v_raft(p: Node3D) -> void:
	var cols := [WOOD, WOOD_L, WOOD, WOOD_D.lightened(0.15), WOOD_L]
	for i in 5:
		add(p, cyl(0.1, 0.1, 1.3, 0.03), m(cols[i]), Vector3(0, 0.02, -0.4 + i * 0.2), Vector3(0, 0, PI / 2))
		for x in [-0.66, 0.66]:
			add(p, cyl(0.075, 0.075, 0.02, 0.005), m(WOOD_L.lightened(0.1)), Vector3(x, 0.02, -0.4 + i * 0.2), Vector3(0, 0, PI / 2))
	for x in [-0.4, 0.4]:
		add(p, box(Vector3(0.08, 0.05, 1.08), 0.02), m(Color("d8c49a")), Vector3(x, 0.13, 0))
	add(p, cyl(0.03, 0.035, 1.2), m(WOOD_D), Vector3(-0.3, 0.7, 0))
	add(p, box(Vector3(0.5, 0.62, 0.02), 0.01), m(Color("fdf2e0")), Vector3(-0.02, 0.78, 0), Vector3(0, 0.25, 0))
	add(p, box(Vector3(0.18, 0.1, 0.01), 0.004), m(RED), Vector3(-0.2, 1.28, 0))
	_seat(p, Vector3(0.25, 0.12, 0))


# ---------------------------------------------------------------- ボート

func _hull(p: Node3D, length: float, width: float, depth: float, c: Color, band: Color) -> void:
	# 下半分の球を伸ばした船体と、ふちの輪
	var hs := SphereMesh.new()
	hs.radius = 0.5
	hs.height = 0.5
	hs.is_hemisphere = true
	hs.radial_segments = 48
	hs.rings = 16
	add(p, hs, m(c), Vector3(0, 0.02, 0), Vector3(PI, 0, 0), Vector3(length, depth * 2.0, width))
	add(p, torus(0.47, 0.53), m(band), Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(length, 1.2, width))
	add(p, cyl(0.47, 0.47, 0.02, 0.0), m(c.darkened(0.3)), Vector3(0, -0.02, 0), Vector3.ZERO, Vector3(length, 1, width))


func _v_rowboat(p: Node3D) -> void:
	_hull(p, 1.6, 0.8, 0.28, Color("fdf7ee"), Color("4f8fd6"))
	add(p, box(Vector3(0.14, 0.04, 0.72), 0.015), m(WOOD), Vector3(-0.1, 0.02, 0))
	for sz in [-1.0, 1.0]:
		var oar := node(p, Vector3(-0.1, 0.08, sz * 0.4), Vector3(sz * 0.5, 0, sz * 0.35))
		add(oar, cyl(0.018, 0.018, 0.9), m(WOOD_D), Vector3(0, 0, sz * 0.3), Vector3(PI / 2, 0, 0))
		add(oar, box(Vector3(0.12, 0.02, 0.26), 0.01), m(WOOD_L), Vector3(0, 0, sz * 0.78))
	add(p, cyl(0.05, 0.05, 0.1), m(RED), Vector3(0.72, 0.1, 0))
	_seat(p, Vector3(0.3, 0.02, 0))


# ---------------------------------------------------------------- フェリー

func _v_ferry(p: Node3D) -> void:
	_hull(p, 2.6, 1.05, 0.36, Color("fdf7ee"), Color("e8575b"))
	add(p, box(Vector3(2.3, 0.05, 0.9), 0.02), m(WOOD_L), Vector3(0, 0.03, 0))
	# 船室
	add(p, box(Vector3(1.0, 0.46, 0.72), 0.06), m(Color("fdf7ee")), Vector3(-0.4, 0.28, 0))
	add(p, box(Vector3(1.1, 0.06, 0.82), 0.03), m(Color("4f8fd6")), Vector3(-0.4, 0.54, 0))
	for i in 4:
		for sz in [-1.0, 1.0]:
			add(p, box(Vector3(0.16, 0.14, 0.02), 0.02), glow(Color("fff1c0"), 0.9), Vector3(-0.78 + i * 0.25, 0.32, sz * 0.365))
	add(p, cyl(0.1, 0.12, 0.36), m(RED), Vector3(-0.62, 0.74, 0))
	add(p, cyl(0.105, 0.105, 0.08), m(INK), Vector3(-0.62, 0.95, 0))
	add(p, box(Vector3(0.36, 0.26, 0.5), 0.05), m(Color("fdf7ee")), Vector3(-0.2, 0.7, 0))
	add(p, box(Vector3(0.02, 0.12, 0.4), 0.01), glow(Color("fff1c0"), 0.9), Vector3(-0.02, 0.72, 0))
	for sz in [-1.0, 1.0]:
		add(p, torus(0.06, 0.1), m(RED), Vector3(-0.4, 0.3, sz * 0.38), Vector3(PI / 2, 0, 0))
		var rail := []
		for i in 6:
			rail.append(Vector3(0.1 + i * 0.2, 0.24, sz * (0.42 - i * i * 0.012)))
		add(p, tube("ferry_rail%s" % sz, rail, [0.012, 0.012, 0.012, 0.012, 0.012, 0.012]), m(Color("c9d6e0")))
	add(p, cyl(0.012, 0.012, 0.5), m(WOOD_D), Vector3(1.1, 0.28, 0))
	add(p, box(Vector3(0.2, 0.12, 0.01), 0.004), m(Color("5fb7d6")), Vector3(1.2, 0.46, 0))
	_seat(p, Vector3(0.55, 0.05, 0))


# ---------------------------------------------------------------- 水上飛行機

func _v_seaplane(p: Node3D) -> void:
	var body := Color("e8575b")
	add(p, tube("plane_body", [Vector3(-0.9, 0.62, 0), Vector3(-0.3, 0.6, 0), Vector3(0.3, 0.6, 0), Vector3(0.62, 0.6, 0)], [0.04, 0.17, 0.2, 0.15]), m(body, 0.35))
	add(p, sph(0.15), m(Color("fdf7ee")), Vector3(0.64, 0.6, 0), Vector3.ZERO, Vector3(0.5, 1, 1))
	# 翼と尾
	add(p, box(Vector3(0.36, 0.05, 2.0), 0.02), m(Color("ffcf5a")), Vector3(0.12, 0.8, 0))
	add(p, box(Vector3(0.22, 0.04, 0.7), 0.015), m(Color("ffcf5a")), Vector3(-0.82, 0.66, 0))
	add(p, box(Vector3(0.22, 0.3, 0.04), 0.015), m(body), Vector3(-0.84, 0.8, 0), Vector3(0, 0, -0.25))
	for sz in [-0.35, 0.35]:
		add(p, cyl(0.012, 0.012, 0.22), m(INK), Vector3(0.12, 0.7, sz))
	# うき
	for sz in [-0.34, 0.34]:
		add(p, tube("plane_float", [Vector3(-0.5, 0.06, 0), Vector3(0, 0.06, 0), Vector3(0.45, 0.08, 0)], [0.05, 0.08, 0.04]), m(Color("fdf7ee")), Vector3(0, 0, sz))
		for x in [-0.15, 0.2]:
			add(p, cyl(0.014, 0.014, 0.5), m(INK), Vector3(x, 0.33, sz * 0.7), Vector3(-sz * 0.9, 0, 0))
	# プロペラ
	var prop := _spinner(p, Vector3(0.74, 0.6, 0), Vector3(1, 0, 0), 20.0)
	add(prop, sph(0.05), m(GOLD))
	for i in 2:
		add(prop, box(Vector3(0.02, 0.48, 0.06), 0.01), m(Color("5a4a48")), Vector3.ZERO, Vector3(i * PI / 2, 0, 0))
	add(p, torus(0.12, 0.15), m(INK), Vector3(0.18, 0.74, 0), Vector3.ZERO, Vector3(1, 0.4, 1))
	_seat(p, Vector3(0.18, 0.62, 0))


# ---------------------------------------------------------------- ヘリコプター

func _v_helicopter(p: Node3D) -> void:
	var col := Color("5fb7a8")
	add(p, sph(0.42), m(col, 0.35), Vector3(0, 0.62, 0), Vector3.ZERO, Vector3(1.25, 0.95, 0.95))
	add(p, sph(0.36), glow(Color("d8f4ff"), 0.25), Vector3(0.18, 0.66, 0), Vector3.ZERO, Vector3(0.9, 0.85, 0.9))
	add(p, tube("heli_tail", [Vector3(-0.35, 0.7, 0), Vector3(-0.8, 0.78, 0), Vector3(-1.2, 0.86, 0)], [0.1, 0.06, 0.045]), m(col, 0.35))
	add(p, box(Vector3(0.18, 0.3, 0.04), 0.015), m(Color("ffcf5a")), Vector3(-1.2, 0.98, 0))
	var tr := _spinner(p, Vector3(-1.2, 0.9, 0.06), Vector3(0, 0, 1), 26.0)
	for i in 2:
		add(tr, box(Vector3(0.03, 0.34, 0.015), 0.006), m(Color("4a4f63")), Vector3.ZERO, Vector3(0, 0, i * PI / 2))
	add(p, cyl(0.05, 0.07, 0.14), m(Color("4a4f63")), Vector3(0, 1.06, 0))
	var rotor := _spinner(p, Vector3(0, 1.14, 0), Vector3(0, 1, 0), 14.0)
	add(rotor, sph(0.06), m(Color("4a4f63")))
	for i in 3:
		add(rotor, box(Vector3(1.3, 0.02, 0.1), 0.01), m(Color("4a4f63")), Vector3(0.65, 0, 0).rotated(Vector3.UP, TAU * i / 3.0), Vector3(0, TAU * i / 3.0, 0))
	for sz in [-0.3, 0.3]:
		add(p, tube("heli_skid", [Vector3(-0.45, 0.06, 0), Vector3(0.3, 0.06, 0), Vector3(0.45, 0.12, 0)], [0.022, 0.022, 0.022]), m(Color("4a4f63")), Vector3(0, 0, sz))
		for x in [-0.2, 0.2]:
			add(p, cyl(0.016, 0.016, 0.34), m(Color("4a4f63")), Vector3(x, 0.24, sz * 0.8), Vector3(sz * 0.6, 0, 0))
	_seat(p, Vector3(0.2, 0.48, 0))


# ---------------------------------------------------------------- 見本の有料：紙の舟・大きな鯉

func _v_paper_boat(p: Node3D) -> void:
	# 折り紙の舟：底のせまい四角すい台を横に伸ばした船体と、三角の帆
	var paper := Color("fdf6ea")
	add(p, Obake3D.lathe(0.5, 0.3, 0.32, 4, 0.0), m(paper, 0.45), Vector3(0, 0.1, 0), Vector3(0, PI / 4, 0), Vector3(1.6, 1, 0.55))
	add(p, Obake3D.lathe(0.46, 0.46, 0.01, 4, 0.0), m(paper.darkened(0.12)), Vector3(0, 0.26, 0), Vector3(0, PI / 4, 0), Vector3(1.5, 1, 0.5))
	add(p, Obake3D.lathe(0.0, 0.4, 0.7, 3, 0.0), m(Color("f7d7e0"), 0.45), Vector3(-0.15, 0.6, 0), Vector3(0, PI / 6, 0), Vector3(1, 1, 0.2))
	for i in 3:
		add(p, box(Vector3(0.28, 0.006, 0.004), 0.001), m(Color("9ab8e0")), Vector3(-0.3 + i * 0.28, 0.18, 0.25))
	_seat(p, Vector3(0.35, 0.26, 0))


func _v_giant_koi(p: Node3D) -> void:
	var white := Color("fdf7ee")
	var orange := Color("ff7a3d")
	add(p, tube("koi_body", [Vector3(-1.0, 0.08, 0), Vector3(-0.5, 0.14, 0), Vector3(0.1, 0.2, 0), Vector3(0.6, 0.18, 0), Vector3(0.9, 0.16, 0)], [0.05, 0.22, 0.3, 0.26, 0.14]), m(white, 0.4))
	for q in [Vector3(0.2, 0.44, 0.05), Vector3(-0.3, 0.36, -0.1), Vector3(0.62, 0.34, 0.0), Vector3(-0.62, 0.24, 0.06)]:
		add(p, sph(0.14), m(orange, 0.4), q, Vector3(0, 0, 0), Vector3(1.4, 0.35, 1.0))
	for sz in [-1.0, 1.0]:
		add(p, sph(0.04), m(INK), Vector3(0.86, 0.24, sz * 0.12))
		add(p, sph(0.14), m(white, 0.45), Vector3(0.3, 0.02, sz * 0.3), Vector3(0, sz * 0.4, 0), Vector3(1.2, 0.2, 0.7))
		add(p, tube("koi_whisker%s" % sz, [Vector3(0.95, 0.12, sz * 0.08), Vector3(1.1, 0.06, sz * 0.18), Vector3(1.2, 0.08, sz * 0.26)], [0.012, 0.01, 0.006]), m(orange))
	for sy in [-1.0, 1.0]:
		add(p, sph(0.22), m(orange, 0.45), Vector3(-1.12, 0.1 + sy * 0.14, 0), Vector3(0, 0, sy * 0.7), Vector3(1.0, 0.45, 0.12))
	add(p, sph(0.18), m(orange, 0.45), Vector3(-0.1, 0.5, 0), Vector3(0, 0, -0.3), Vector3(1.1, 0.7, 0.1))
	_seat(p, Vector3(0.35, 0.42, 0))
