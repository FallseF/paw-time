class_name ShopLandmarks
extends IslandProps
## お店の島の目印（ShopCulture.LANDMARKS）の 3D。島の置き物キットと同じ塗り・同じ部品（IslandProps）で組む。
## 段 1〜3 で、ひと目でわかるほど育つ。段 0 で票が少しあるときは、小さな芽（sprout）。
## どれも足元が y=0、正面が +Z、中心が原点。灯りは kit_lamp の OmniLight3D（画面側で明るさを決める）。


## 目印を組んで返す。level 0 なら芽
static func build_landmark(id: String, level: int) -> Node3D:
	var root := Node3D.new()
	root.name = id
	var s := ShopLandmarks.new()
	if level <= 0:
		s._sprout(root)
		return root
	var fn := "_lm_" + id
	if s.has_method(fn):
		s.call(fn, root, clampi(level, 1, 3))
	else:
		s._crate(root)
	return root


## お店そのもの（うしろの丘に建つ）：看板と日よけは、お店が選んだ色
static func build_shop(sign_c: Color, accent: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "shop_front"
	ShopLandmarks.new()._shop(root, sign_c, accent)
	return root


# ---------------------------------------------------------------- お店

func _shop(p: Node3D, sign_c: Color, accent: Color) -> void:
	add(p, box(Vector3(2.6, 0.14, 1.6)), m(STONE), Vector3(0, 0.07, 0))
	add(p, box(Vector3(2.4, 1.1, 1.3)), m(Color("fff6ea")), Vector3(0, 0.69, -0.05))
	# 大きな窓と、あいた戸
	add(p, box(Vector3(0.9, 0.5, 0.04)), glow(Color("ffe9b8"), 0.5), Vector3(-0.55, 0.75, 0.62))
	add(p, box(Vector3(0.98, 0.06, 0.08)), m(WOOD_L), Vector3(-0.55, 0.47, 0.64))
	add(p, box(Vector3(0.44, 0.74, 0.05)), m(WOOD), Vector3(0.62, 0.51, 0.62))
	add(p, sph(0.03), m(GOLD), Vector3(0.76, 0.51, 0.66))
	# しま模様の日よけ（お店の色）
	for i in 8:
		var x := -1.12 + i * 0.32
		var c := sign_c if i % 2 == 0 else accent
		add(p, box(Vector3(0.32, 0.05, 0.6), 0.02), m(c), Vector3(x, 1.2, 0.86), Vector3(0.38, 0, 0))
		add(p, cyl(0.16, 0.16, 0.03), m(c), Vector3(x, 1.08, 1.13), Vector3(PI / 2, 0, 0), Vector3(1, 1, 0.6))
	roof(p, 2.8, 1.5, 0.5, sign_c.darkened(0.25), Vector3(0, 1.24, -0.05))
	# 屋根の上の看板の板（文字は画面側で Label3D）
	add(p, box(Vector3(1.9, 0.46, 0.08), 0.03), m(sign_c), Vector3(0, 1.98, 0.2))
	add(p, box(Vector3(1.78, 0.36, 0.02), 0.01), m(accent), Vector3(0, 1.98, 0.25))
	for x in [-0.7, 0.7]:
		add(p, cyl(0.03, 0.03, 0.3), m(WOOD_D), Vector3(x, 1.7, 0.18))
	# 店先の植木と、黒板の立て看板
	for x in [-1.25, 1.25]:
		add(p, cyl(0.15, 0.11, 0.24), m(Color("d9774f")), Vector3(x, 0.12, 0.95))
		add(p, glb("canopy_round"), Obake3D.skin(Color("7cc46a"), 0.0, null, 0.18, 0.05), Vector3(x, 0.4, 0.95), Vector3.ZERO, Vector3.ONE * 0.26)
	var sb := node(p, Vector3(1.0, 0, 1.35), Vector3(0, -0.3, 0))
	for sx in [-1.0, 1.0]:
		add(sb, box(Vector3(0.04, 0.6, 0.04)), m(WOOD_D), Vector3(sx * 0.2, 0.3, 0.06), Vector3(-0.18, 0, 0))
	add(sb, box(Vector3(0.44, 0.44, 0.03)), m(Color("3a4a44")), Vector3(0, 0.36, 0.1), Vector3(-0.18, 0, 0))
	add(sb, box(Vector3(0.3, 0.03, 0.01)), m(accent), Vector3(0, 0.44, 0.13), Vector3(-0.18, 0, 0))
	add(sb, box(Vector3(0.22, 0.03, 0.01)), m(accent), Vector3(0, 0.36, 0.14), Vector3(-0.18, 0, 0))
	_lamp_glow(p, Vector3(-0.55, 0.8, 1.0), Color("ffe3a6"), 2.0)


# ---------------------------------------------------------------- 芽（票がまだ少ないタグ）

func _sprout(p: Node3D) -> void:
	add(p, cyl(0.16, 0.18, 0.05, 0.02), m(Color("8a6a4a")), Vector3(0, 0.025, 0))
	add(p, cyl(0.012, 0.014, 0.18, 0.0), m(LEAF_D), Vector3(0, 0.12, 0))
	for sx in [-1.0, 1.0]:
		add(p, sph(0.06), m(LEAF, 0.35), Vector3(sx * 0.06, 0.2, 0), Vector3(0, 0, -sx * 0.5), Vector3(1.3, 0.35, 0.8))


# ---------------------------------------------------------------- 時間どおりに帰れる：時計台（育つほど高く、灯る）

func _clock_face(p: Node3D, pos: Vector3, r: float, lit: bool) -> void:
	add(p, cyl(r + 0.03, r + 0.03, 0.05), m(GOLD), pos, Vector3(PI / 2, 0, 0))
	add(p, cyl(r, r, 0.06), glow(Color("fff6dc"), 1.4) if lit else m(Color("fffaf0")), pos + Vector3(0, 0, 0.01), Vector3(PI / 2, 0, 0))
	for i in 12:
		var a := TAU * i / 12.0
		add(p, sph(r * 0.07), m(INK), pos + Vector3(cos(a) * r * 0.8, sin(a) * r * 0.8, 0.05))
	# 針はいつも「帰る時刻」：6 時ちょうど
	add(p, box(Vector3(r * 0.08, r * 0.7, 0.015), 0.004), m(INK), pos + Vector3(0, r * 0.35, 0.05))
	add(p, box(Vector3(r * 0.1, r * 0.5, 0.015), 0.004), m(INK), pos + Vector3(0, -r * 0.25, 0.055))
	add(p, sph(r * 0.1), m(GOLD), pos + Vector3(0, 0, 0.06))


func _lm_clock_tower(p: Node3D, lv: int) -> void:
	if lv == 1:
		add(p, cyl(0.14, 0.18, 0.1), m(STONE), Vector3(0, 0.05, 0))
		add(p, cyl(0.04, 0.05, 1.0), m(Color("4a4f63")), Vector3(0, 0.55, 0))
		var head := node(p, Vector3(0, 1.18, 0))
		add(head, cyl(0.2, 0.2, 0.12), m(Color("4a4f63")), Vector3.ZERO, Vector3(PI / 2, 0, 0))
		_clock_face(head, Vector3(0, 0, 0.05), 0.17, false)
		return
	var h := 1.5 if lv == 2 else 2.2
	add(p, box(Vector3(0.9, 0.16, 0.9)), m(STONE_D), Vector3(0, 0.08, 0))
	add(p, box(Vector3(0.66, h, 0.66), 0.04), m(Color("f3e2c8")), Vector3(0, 0.16 + h * 0.5, 0))
	for x in [-0.33, 0.33]:
		for z in [-0.33, 0.33]:
			add(p, box(Vector3(0.1, h, 0.1)), m(WOOD_D), Vector3(x, 0.16 + h * 0.5, z))
	add(p, box(Vector3(0.24, 0.4, 0.04)), m(WOOD), Vector3(0, 0.36, 0.34))
	var top := 0.16 + h
	# 前と裏の文字盤（裏は向きを反転）
	for sz in [1.0, -1.0]:
		var face := node(p, Vector3(0, top - 0.32, sz * 0.35), Vector3(0, 0.0 if sz > 0 else PI, 0))
		_clock_face(face, Vector3.ZERO, 0.24, true)
	add(p, box(Vector3(0.8, 0.08, 0.8), 0.03), m(WOOD_L), Vector3(0, top + 0.02, 0))
	add(p, cyl(0.0, 0.56, 0.62, 0.03), m(ROOF), Vector3(0, top + 0.37, 0), Vector3(0, PI / 4, 0), Vector3(1, 1, 1))
	add(p, sph(0.06), m(GOLD), Vector3(0, top + 0.72, 0))
	_lamp_glow(p, Vector3(0, top - 0.32, 0.6), Color("fff1c0"), 2.4)
	if lv >= 3:
		# 鐘の小屋と、旗と、足元の花
		add(p, box(Vector3(0.5, 0.36, 0.5), 0.03), m(Color("fdf7ee")), Vector3(0, top + 0.26, 0))
		add(p, cyl(0.1, 0.15, 0.18), m(GOLD, 0.5), Vector3(0, top + 0.22, 0))
		add(p, cyl(0.0, 0.4, 0.4, 0.02), m(ROOF), Vector3(0, top + 0.64, 0), Vector3(0, PI / 4, 0))
		add(p, cyl(0.015, 0.015, 0.5), m(WOOD_D), Vector3(0, top + 1.05, 0))
		add(p, box(Vector3(0.3, 0.16, 0.01), 0.004), m(RED), Vector3(0.16, top + 1.2, 0))
		for i in 6:
			var a := TAU * i / 6.0 + 0.3
			_flower(p, Vector3(cos(a) * 0.62, 0, sin(a) * 0.62), [Color("ffd24d"), Color("ff8fb1"), Color("fff5f8")][i % 3], 0.2)


# ---------------------------------------------------------------- 休憩がとれる：ハンモックとベンチの木立

func _lm_rest_grove(p: Node3D, lv: int) -> void:
	var t1 := node(p, Vector3(-0.55, 0, -0.35))
	_b_tree_round(t1)
	var b := node(p, Vector3(0.25, 0, 0.3), Vector3(0, -0.3, 0))
	_b_bench(b)
	if lv >= 2:
		var hm := node(p, Vector3(0.35, 0, -0.55), Vector3(0, 0.15, 0))
		hm.scale = Vector3.ONE * 0.85
		_b_hammock(hm)
		var c := node(p, Vector3(-0.2, 0, 0.55))
		c.scale = Vector3.ONE * 0.7
		_b_cushion(c)
	if lv >= 3:
		var t2 := node(p, Vector3(1.05, 0, -0.1))
		t2.scale = Vector3.ONE * 0.85
		_b_tree_sakura(t2)
		var pt := node(p, Vector3(-0.95, 0, 0.5))
		pt.scale = Vector3.ONE * 0.8
		_b_parasol_table(pt)
		# ポットのお茶
		add(p, cyl(0.06, 0.07, 0.12), m(Color("fdf7ee")), Vector3(-0.95, 0.46, 0.5))


# ---------------------------------------------------------------- 説明がわかりやすい：矢印のはっきりした道しるべ

func _lm_guide_post(p: Node3D, lv: int) -> void:
	var sp := node(p, Vector3.ZERO)
	sp.scale = Vector3.ONE * (1.0 if lv == 1 else 1.3)
	_b_signpost(sp)
	if lv >= 2:
		for i in 4:
			add(p, cyl(0.14, 0.16, 0.05, 0.02), m(STONE.darkened(0.04 * (i % 2))), Vector3(-0.1 + i * 0.05, 0.025, 0.4 + i * 0.32), Vector3(0, i * 0.7, 0), Vector3(1.15, 1, 0.9))
		# 矢印の形の、明るい案内板
		var arrow := node(p, Vector3(-0.55, 0, 0.1), Vector3(0, 0.4, 0))
		add(arrow, cyl(0.03, 0.035, 0.6), m(WOOD_D), Vector3(0, 0.3, 0))
		add(arrow, box(Vector3(0.44, 0.2, 0.05)), m(Color("5fc4c0")), Vector3(0.1, 0.62, 0))
		add(arrow, cyl(0.0, 0.14, 0.16, 0.0), m(Color("5fc4c0")), Vector3(0.39, 0.62, 0), Vector3(0, 0, -PI / 2), Vector3(1, 1, 0.35))
		add(arrow, box(Vector3(0.28, 0.04, 0.01)), m(Color("fdf7ee")), Vector3(0.08, 0.62, 0.03))
	if lv >= 3:
		var bb := node(p, Vector3(0.7, 0, -0.2), Vector3(0, -0.4, 0))
		bb.scale = Vector3.ONE * 0.9
		_b_bulletin_board(bb)
		var lamp := node(p, Vector3(-0.4, 0, -0.45))
		lamp.scale = Vector3.ONE * 0.8
		_b_street_lamp(lamp)


# ---------------------------------------------------------------- 給料が遅れない：時間どおりに鳴る金の鐘

func _lm_payday_bell(p: Node3D, lv: int) -> void:
	var gold := m(GOLD, 0.55, 0.15 if lv >= 3 else 0.0)
	if lv == 1:
		add(p, cyl(0.03, 0.04, 0.9), m(WOOD_D), Vector3(0, 0.45, 0))
		add(p, box(Vector3(0.4, 0.04, 0.04)), m(WOOD_D), Vector3(0.12, 0.9, 0))
		add(p, cyl(0.04, 0.11, 0.16), gold, Vector3(0.24, 0.78, 0))
		add(p, sph(0.03), gold, Vector3(0.24, 0.69, 0))
		return
	var w := 0.9 if lv == 2 else 1.2
	for x in [-w * 0.5, w * 0.5]:
		add(p, cyl(0.05, 0.06, 1.2), m(RED), Vector3(x, 0.6, 0))
		add(p, cyl(0.08, 0.08, 0.1), m(STONE), Vector3(x, 0.05, 0))
	add(p, box(Vector3(w + 0.1, 0.08, 0.12)), m(RED), Vector3(0, 1.18, 0))
	roof(p, w + 0.35, 0.5, 0.28, ROOF, Vector3(0, 1.24, 0))
	add(p, cyl(0.07, 0.2, 0.3), gold, Vector3(0, 0.96, 0))
	add(p, torus(0.17, 0.21), gold, Vector3(0, 0.82, 0))
	add(p, sph(0.04), gold, Vector3(0, 0.78, 0))
	add(p, tube("bell_rope", [Vector3(0.05, 0.8, 0), Vector3(0.1, 0.55, 0.02), Vector3(0.08, 0.3, 0.04)], [0.012, 0.012, 0.012]), m(Color("e8575b")))
	if lv >= 3:
		# 両脇に灯りと、きちんと届いた手紙の箱
		for sx in [-1.0, 1.0]:
			add(p, sph(0.1), glow(Color("ffd98a"), 1.4), Vector3(sx * (w * 0.5 + 0.02), 1.02, 0.1), Vector3.ZERO, Vector3(1, 1.25, 1))
		var mb := node(p, Vector3(w * 0.5 + 0.4, 0, 0.25))
		_b_mailbox(mb)
		for i in 3:
			add(p, box(Vector3(0.2, 0.02, 0.14), 0.004), m(Color("fdf7ee")), Vector3(-w * 0.5 - 0.35, 0.02 + i * 0.025, 0.3), Vector3(0, i * 0.3, 0))
		_lamp_glow(p, Vector3(0, 1.0, 0.4), Color("ffd98a"), 2.2)


# ---------------------------------------------------------------- 人がやさしい：灯りの小道

func _lm_lantern_path(p: Node3D, lv: int) -> void:
	# 手前から奥へ、左右に灯り。段ごとに数がふえる
	var n: int = [2, 4, 6][lv - 1]
	for i in n:
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := 0.9 - (i / 2) * 0.7
		var l := node(p, Vector3(side * 0.55, 0, z), Vector3(0, PI if side > 0 else 0.0, 0))
		_b_paper_lantern(l)
	for i in n + 1:
		add(p, cyl(0.15, 0.17, 0.04, 0.02), m(Color("e8dcc6")), Vector3(sin(i * 1.3) * 0.08, 0.02, 1.0 - i * 0.36), Vector3(0, i, 0), Vector3(1.1, 1, 0.85))
	if lv >= 3:
		var sl := node(p, Vector3(0, 0, -1.3))
		_b_string_lights(sl)
		sl.scale = Vector3(0.85, 1.1, 1)


# ---------------------------------------------------------------- 忙しいけど公平：ふたつの受け皿がつりあう噴水

func _lm_fair_fountain(p: Node3D, lv: int) -> void:
	if lv == 1:
		add(p, cyl(0.07, 0.1, 0.5), m(STONE), Vector3(0, 0.25, 0))
		add(p, cyl(0.28, 0.1, 0.1), m(STONE), Vector3(0, 0.55, 0))
		_water_disc(p, 0.24, 0.24, 0.6)
		return
	var f := node(p, Vector3.ZERO)
	_b_fountain(f)
	f.scale = Vector3.ONE * (0.9 if lv == 2 else 1.1)
	# つりあった、ふたつの受け皿（同じ高さ）
	var y := 1.0 if lv == 2 else 1.2
	add(p, cyl(0.03, 0.03, 0.9), m(STONE_D), Vector3(0, y, 0), Vector3(0, 0, PI / 2))
	for sx in [-1.0, 1.0]:
		var bowl := node(p, Vector3(sx * 0.45, 0, 0))
		add(bowl, cyl(0.16, 0.08, 0.08), m(STONE), Vector3(0, y - 0.06, 0))
		_water_disc(bowl, 0.13, 0.13, y - 0.02)
	add(p, sph(0.05), m(GOLD), Vector3(0, y + 0.05, 0))
	if lv >= 3:
		for i in 8:
			var a := TAU * i / 8.0
			_flower(p, Vector3(cos(a) * 0.75, 0, sin(a) * 0.75), [Color("b89bff"), Color("ffd24d")][i % 2], 0.22)


# ---------------------------------------------------------------- また働きたい：おかえりのアーチ（岸辺）

func _lm_welcome_arch(p: Node3D, lv: int) -> void:
	for sx in [-0.75, 0.75]:
		var fp := node(p, Vector3(sx, 0, 0.15))
		_b_flower_pot(fp)
	if lv == 1:
		return
	var pts := []
	for i in 9:
		var t := i / 8.0
		pts.append(Vector3(-0.7 + t * 1.4, sin(t * PI) * 1.35, 0))
	add(p, tube("welcome_arch", pts, [0.05, 0.045, 0.04, 0.04, 0.04, 0.04, 0.04, 0.045, 0.05]), m(Color("fdf1dc")))
	var cols := [Color("ff8fb1"), Color("ffd24d"), Color("fff5f8"), Color("b89bff")]
	var n := 9 if lv == 2 else 15
	for i in n:
		var t := (i + 0.5) / n
		var q := Vector3(-0.7 + t * 1.4, sin(t * PI) * 1.35, 0.03)
		add(p, sph(0.07), m(cols[i % 4], 0.4), q, Vector3.ZERO, Vector3(1, 0.8, 1))
		add(p, sph(0.06), m(LEAF, 0.3), q + Vector3(0.04, -0.05, -0.04), Vector3.ZERO, Vector3(1.3, 0.5, 0.9))
	# 足元の飛び石
	for i in 3:
		add(p, cyl(0.15, 0.17, 0.04, 0.02), m(Color("e8dcc6")), Vector3(sin(i * 1.7) * 0.06, 0.02, 0.25 - i * 0.34), Vector3(0, i, 0), Vector3(1.1, 1, 0.85))
	if lv >= 3:
		# 旗の列と、ふたつの灯り
		var pts2 := []
		for i in 9:
			var t := i / 8.0
			pts2.append(Vector3(-0.7 + t * 1.4, 1.1 - sin(t * PI) * 0.18, 0.08))
		for i in 7:
			var t := (i + 1) / 8.0
			add(p, cyl(0.0, 0.07, 0.14, 0.0), m(cols[i % 4]), Vector3(-0.7 + t * 1.4, 1.02 - sin(t * PI) * 0.18, 0.08), Vector3(PI, 0, 0), Vector3(1, 1, 0.25))
		for sx in [-1.2, 1.2]:
			var l := node(p, Vector3(sx, 0, 0.1), Vector3(0, PI if sx > 0 else 0.0, 0))
			_b_paper_lantern(l)
