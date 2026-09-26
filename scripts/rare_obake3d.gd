class_name RareObake3D
extends Obake3D
## レアおばけ 30 体。ふつうのおばけと同じ体・顔・トゥーンの塗りで組み、1体ずつ「ひとひねり」を足す。
## 形は球・円柱・円すい・輪・箱だけ。色は Rares の look.c1 / c2。
## 足元は y=0、高さはふつうのおばけ（約 1.0）の 1.3 倍まで。正面は +Z。
## 図鑑カード用の絵は tests/render_rares.gd で assets/gen/rares3d/<id>.png に撮る。

const CARD_DIR := "res://assets/gen/rares3d/%s.png"
const WOOD := Color("b07a4a")
const WOOD_DARK := Color("7a4e32")
const PAPER := Color("fff6ee")
const RED := Color("e8505b")
const LEAF := Color("6cbf5a")

var c1: Color
var c2: Color
## 揺らす部品（名前 → ノード）と、その元の位置・向き
var _p := {}
var _base := {}


## 図鑑カードの絵。3D で撮った絵を優先し、無ければ古い平たい絵を返す。
static func art_path(id: String) -> String:
	for d in [CARD_DIR, "res://assets/gen/rares/%s.png"]:
		var p: String = d % id
		if ResourceLoader.exists(p):
			return p
	return ""


func setup(id: String) -> Obake3D:
	species = id
	var look: Dictionary = Rares.by_id(id).get("look", {"c1": "ffffff", "c2": "cccccc"})
	c1 = Color(look.c1)
	c2 = Color(look.c2)
	body = Node3D.new()
	add_child(body)
	if has_method("_b_" + id):
		call("_b_" + id)
	else:
		body.add_child(ghost(c1))
	for k in _p:
		var n: Node3D = _p[k]
		_base[k] = n.transform
	_t = randf() * TAU
	return self


# ---------------------------------------------------------------- 部品

## 持ち物の材質（肌と同じ塗り・輪郭つき、色ごとに使い回す）。
## s は昔の輪郭の太さ補正の名残。いまの輪郭は縮尺に左右されないので使わない。
func _mat(c: Color, rim := 0.25, em := 0.0, _s := 1.0) -> ShaderMaterial:
	return prop(c, rim, em)


## おばけの肌（ふつうのおばけと同じ塗り）
func _skin(c: Color, _s := 1.0, em := 0.0) -> ShaderMaterial:
	return skin(c, em)


func _add(m: Mesh, mat: Material, pos: Vector3, parent: Node3D = null, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := _mesh(m, mat, pos)
	mi.rotation = rot
	mi.scale = scl
	(parent if parent else body).add_child(mi)
	return mi


func _node(pos: Vector3, parent: Node3D = null, rot := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	n.rotation = rot
	(parent if parent else body).add_child(n)
	return n


func _hemi(r: float) -> SphereMesh:
	var s := _sphere(r)
	s.is_hemisphere = true
	s.height = r
	return s


## ノードの +Y を dir へ向ける（円柱・円すいを好きな向きに寝かせる）
func _point(n: Node3D, dir: Vector3) -> void:
	n.basis = Basis(Quaternion(Vector3.UP, dir.normalized())) * Basis.from_scale(n.scale)


## 小さなおばけを置く
func _mini(c: Color, s: float, pos: Vector3, parent: Node3D = null, sleepy := false) -> Node3D:
	var g := ghost(c, s, 0.0, _eye(c), sleepy)
	g.position = pos
	(parent if parent else body).add_child(g)
	return g


## 暗い色の体には白い目
func _eye(c: Color) -> Color:
	return Color.WHITE if c.get_luminance() < 0.3 else INK


## 顔のない丸い頭（顔は face() で別に付ける）
func _head(c: Color, r: float, pos: Vector3, parent: Node3D = null, em := 0.0) -> MeshInstance3D:
	return _add(_sphere(r), _skin(c, 1.0, em), pos, parent)


## 五つ角の星（XY 平面に立つ）
func _star(r: float, c: Color, pos: Vector3, parent: Node3D = null, em := 0.5) -> Node3D:
	var n := _node(pos, parent)
	var m := _mat(c, 0.3, em, r / 0.15)
	_add(_sphere(r * 0.42), m, Vector3.ZERO, n, Vector3.ZERO, Vector3(1, 1, 0.55))
	for i in 5:
		var a := TAU * i / 5.0
		_add(_cyl(0.0, r * 0.3, r * 0.75, 8), m, Vector3(-sin(a), cos(a), 0) * r * 0.55, n, Vector3(0, 0, a), Vector3(1, 1, 0.55))
	return n


## 雪の結晶
func _flake(r: float, c: Color, pos: Vector3) -> Node3D:
	var n := _node(pos)
	var m := _mat(c, 0.4, 0.2, 0.5)
	for i in 3:
		_add(_box(Vector3(r * 2.0, r * 0.22, r * 0.12)), m, Vector3.ZERO, n, Vector3(0, 0, PI * i / 3.0))
	_add(_sphere(r * 0.3), m, Vector3.ZERO, n)
	return n


## 光る粒（ほたる・火花）
func _glow(r: float, c: Color, pos: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var m := skin(c, 0.7, null, 0.3, 0.0, false)
	return _add(_sphere(r), m, pos, parent)


## 湯気・雲のひとかたまり
func _puff(r: float, c: Color, pos: Vector3, parent: Node3D = null) -> Node3D:
	var n := _node(pos, parent)
	var m := _mat(c, 0.5, 0.0, 0.6)
	for o in [Vector3(-1.0, 0, 0), Vector3(0, 0.35, 0), Vector3(1.0, 0, 0), Vector3(0.5, -0.2, 0.5), Vector3(-0.5, -0.2, 0.5)]:
		_add(_sphere(r), m, o * r, n)
	return n


## 縦じまの塗り（傘・左右の塗り分け）。u は正面 +Z から回る向き。
func _stripes(cols: Array, rim := 0.2) -> ShaderMaterial:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offs := PackedFloat32Array()
	var cs := PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / cols.size())
		cs.append(cols[i])
	g.offsets = offs
	g.colors = cs
	var tex := GradientTexture1D.new()
	tex.gradient = g
	tex.width = 256
	return skin(Color.WHITE, 0.0, tex, 0.18 + rim * 0.6)


# ---------------------------------------------------------------- 睡眠

## ネムリン：ふとんで巻かれて、のり巻きのよう。顔だけ出して眠る
func _b_nemurin() -> void:
	var roll := _node(Vector3(0, 0.44, -0.05), null, Vector3(0, -0.12, 0))
	_p.roll = roll
	var rot := Vector3(PI / 2, 0, 0)
	_add(_cyl(0.44, 0.44, 0.9, 24), _mat(c2), Vector3.ZERO, roll, rot)
	_add(_cyl(0.455, 0.455, 0.16, 24), _mat(Color("f4f1ff")), Vector3(0, 0, -0.15), roll, rot)
	_add(_cyl(0.36, 0.36, 0.06, 24), _mat(Color("fbf8ff"), 0.4), Vector3(0, 0, 0.46), roll, rot)
	_head(c1, 0.3, Vector3(0, -0.02, 0.5), roll)
	roll.add_child(face(Vector3(0, -0.02, 0.5), 0.6, INK, true))
	_p.bubble = _add(_sphere(0.055), _mat(Color("9fd8ff"), 0.2), Vector3(0.16, -0.08, 0.8), roll)


## ユメミ：眠るおばけの上に、夢の雲。雲の上ではマントのおばけになっている
func _b_yumemi() -> void:
	_mini(c1, 0.8, Vector3(-0.15, 0, 0.05), null, true)
	var cloud := _node(Vector3(0.28, 1.02, -0.05))
	_p.cloud = cloud
	_puff(0.14, Color.WHITE, Vector3.ZERO, cloud)
	var hero := _mini(c2, 0.26, Vector3(0, 0.08, 0.02), cloud)
	_add(_box(Vector3(0.75, 0.62, 0.06)), _mat(Color("9b6bf0"), 0.3, 0, 0.26), Vector3(0, 0.45, -0.46), hero, Vector3(0.25, 0, 0))
	_add(_sphere(0.035), _mat(Color.WHITE, 0.5), Vector3(0.1, 0.86, 0.12))
	_add(_sphere(0.05), _mat(Color.WHITE, 0.5), Vector3(0.18, 0.93, 0.05))


## アサヤケ：山の向こうから昇るお日さまのおばけ
func _b_asayake() -> void:
	_mini(c1, 0.9, Vector3(0, 0.08, -0.1))
	var rays := _node(Vector3(0, 0.55, -0.25))
	_p.rays = rays
	for i in 12:
		var a := TAU * i / 12.0
		_add(_cyl(0.0, 0.07, 0.2, 10), _mat(c2.lightened(0.2), 0.3, 0.2), Vector3(-sin(a), cos(a), 0) * 0.62, rays, Vector3(0, 0, a))
	var mtn := _mat(Color("9a8fd0"))
	var snow := _mat(Color.WHITE, 0.4)
	for m in [[Vector3(-0.48, 0, 0.3), 0.36, 0.55], [Vector3(0.5, 0, 0.22), 0.3, 0.45], [Vector3(-0.1, 0, 0.5), 0.24, 0.26]]:
		var base: Vector3 = m[0]
		var r: float = m[1]
		var h: float = m[2]
		_add(_cyl(0.0, r, h), mtn, base + Vector3(0, h * 0.5, 0))
		_add(_cyl(0.0, r * 0.36, h * 0.36), snow, base + Vector3(0, h * 0.82 + 0.005, 0))


## ヨミセ：提灯のおばけ。ぼんやり光って、ちょっと舌を出している
func _b_yomise() -> void:
	var lan := _node(Vector3(0, 1.2, 0))
	_p.lantern = lan
	_add(_sphere(0.42), _skin(Color("ffe3b0"), 1.0, 0.35), Vector3(0, -0.62, 0), lan, Vector3.ZERO, Vector3(1, 1.2, 1))
	var rib := _mat(Color("d99a5c"), 0.2)
	for h in [-0.36, -0.18, 0.0, 0.18, 0.36]:
		var rr := 0.42 * sqrt(1.0 - pow(h / 0.504, 2))
		_add(_torus(rr - 0.012, rr + 0.012), rib, Vector3(0, -0.62 + h, 0), lan)
	var capm := _mat(c1.lightened(0.1))
	_add(_cyl(0.2, 0.24, 0.1), capm, Vector3(0, -0.1, 0), lan)
	_add(_cyl(0.24, 0.2, 0.08), capm, Vector3(0, -1.12, 0), lan)
	_add(_torus(0.04, 0.07), capm, Vector3(0, -0.01, 0), lan, Vector3(PI / 2, 0, 0))
	lan.add_child(face(Vector3(0, -0.56, 0.0), 0.86))
	_add(_sphere(0.07), _mat(Color("ff7f96"), 0.3), Vector3(0, -0.74, 0.42), lan, Vector3(0.5, 0, 0), Vector3(0.8, 1.3, 0.5))
	var light := OmniLight3D.new()
	light.light_color = c2
	light.light_energy = 0.8
	light.omni_range = 2.0
	light.position = Vector3(0, -0.5, 0.6)
	lan.add_child(light)
	for i in 3:
		_p["fly%d" % i] = _glow(0.035, c2, Vector3(-0.55 + i * 0.5, 0.35 + i * 0.25, 0.25 - i * 0.2))


## ヒルネン：休みの日の日だまりで、とろけて昼寝
func _b_hirunen() -> void:
	_add(_box(Vector3(1.5, 0.04, 1.05)), _mat(c2), Vector3(0, 0.02, 0))
	_add(_box(Vector3(0.42, 0.1, 0.3)), _mat(Color.WHITE, 0.3), Vector3(-0.5, 0.09, -0.2), null, Vector3(0, 0.2, 0))
	var g := ghost(c1, 1.0, 0.0, INK, true, false)
	g.position.y = 0.04
	g.scale = Vector3(1.2, 0.55, 1.1)
	body.add_child(g)
	_p.melt = g
	body.add_child(face(Vector3(0, 0.3, 0.08), 1.0, INK, true))
	_add(_sphere(0.5), _mat(LEAF), Vector3(0.1, 0.62, -0.1), null, Vector3(0, 0.4, 0.35), Vector3(0.5, 0.08, 0.28))
	_add(_cyl(0.02, 0.02, 0.14), _mat(Color("4f8a3a")), Vector3(-0.15, 0.58, -0.15), null, Vector3(0, 0, 1.0))


## トトノウ：ベンチに座って、頭にタオル。湯気の向こうで落ち着いている
func _b_totonou() -> void:
	var wood := _mat(WOOD)
	_add(_box(Vector3(1.05, 0.08, 0.46)), wood, Vector3(0, 0.34, 0))
	for x in [-0.42, 0.42]:
		for z in [-0.16, 0.16]:
			_add(_box(Vector3(0.07, 0.32, 0.07)), _mat(WOOD_DARK), Vector3(x, 0.16, z))
	_mini(c1, 0.78, Vector3(0, 0.36, 0), null, true)
	var towel := _node(Vector3(0.03, 1.12, 0), null, Vector3(0, 0.2, 0.1))
	var tw := _mat(Color.WHITE, 0.3)
	_add(_sphere(0.5), tw, Vector3(0, -0.02, 0), towel, Vector3.ZERO, Vector3(0.62, 0.14, 0.42))
	_add(_sphere(0.5), tw, Vector3(0, 0.05, 0), towel, Vector3.ZERO, Vector3(0.52, 0.12, 0.36))
	_add(_box(Vector3(0.05, 0.03, 0.2)), _mat(c2), Vector3(0.2, 0.09, 0), towel)
	for i in 3:
		_p["steam%d" % i] = _puff(0.05, Color.WHITE, Vector3(-0.42 + i * 0.42, 1.25, -0.1))


# ---------------------------------------------------------------- はじめて

## キラリ：大きすぎる王冠をかぶって、うれしそう
func _b_kirari() -> void:
	_mini(c2, 0.8, Vector3(0, 0, 0))
	var crown := _node(Vector3(0.02, 0.74, 0), null, Vector3(0, 0, 0.16))
	_p.crown = crown
	var gold := metal(c1)
	_add(_cyl(0.48, 0.44, 0.28, 24), gold, Vector3.ZERO, crown)
	var gems := [Color("ff6f91"), Color("5fc4f0"), Color("7fd18a"), Color("ff6f91"), Color("b98cff")]
	for i in 5:
		var a := TAU * i / 5.0 + PI / 2
		var p := Vector3(cos(a) * 0.43, 0.26, sin(a) * 0.43)
		_add(_cyl(0.0, 0.11, 0.26, 12), gold, p, crown)
		_add(_sphere(0.055), _mat(Color("fff7c2"), 0.3, 0.3), p + Vector3(0, 0.15, 0), crown)
		_add(_sphere(0.05), _mat(gems[i], 0.4), Vector3(cos(a + PI / 5) * 0.47, 0.0, sin(a + PI / 5) * 0.47), crown)
	_star(0.07, Color("fff7c2"), Vector3(-0.5, 0.95, 0.2), null, 0.8)
	_star(0.05, Color("fff7c2"), Vector3(0.52, 0.5, 0.25), null, 0.8)


## ハジメテ：大きすぎる帽子と、胸に若葉マーク。まだ少しぎこちない
func _b_hajimete() -> void:
	_mini(c1, 0.9, Vector3.ZERO)
	var hat := _node(Vector3(0.02, 0.82, -0.02), null, Vector3(0.18, 0, -0.1))
	_p.hat = hat
	var hm := _mat(c2)
	_add(_cyl(0.56, 0.58, 0.04, 24), hm, Vector3.ZERO, hat)
	_add(_hemi(0.4), hm, Vector3(0, 0.0, 0), hat, Vector3.ZERO, Vector3(1, 0.9, 1))
	_add(_cyl(0.405, 0.405, 0.06, 24), _mat(Color.WHITE, 0.3), Vector3(0, 0.05, 0), hat)
	var mark := _node(Vector3(0, 0.17, 0.5), null, Vector3(-0.15, 0, 0))
	_add(_box(Vector3(0.09, 0.2, 0.03)), _mat(Color("ffd93b"), 0.3), Vector3(-0.045, 0, 0), mark, Vector3(0, 0, 0.3))
	_add(_box(Vector3(0.09, 0.2, 0.03)), _mat(Color("3cb371"), 0.3), Vector3(0.045, 0, 0), mark, Vector3(0, 0, -0.3))
	var drop := _node(Vector3(-0.45, 0.72, 0.2))
	_p.drop = drop
	var dm := _mat(Color("9fd4ff"), 0.6)
	_add(_sphere(0.06), dm, Vector3.ZERO, drop)
	_add(_cyl(0.0, 0.055, 0.1, 10), dm, Vector3(0, 0.06, 0), drop)


## ワタリドリ：羽の生えた小さなおばけが、V の字で渡っていく
func _b_wataridori() -> void:
	var spots := [Vector3(0, 0.5, 0.25), Vector3(-0.42, 0.62, -0.05), Vector3(0.42, 0.62, -0.05), Vector3(-0.66, 0.32, -0.25), Vector3(0.66, 0.32, -0.25)]
	for i in spots.size():
		var s := 0.62 if i == 0 else 0.3
		var g := _mini(c1, s, spots[i])
		_p["bird%d" % i] = g
		var wm := _mat(Color.WHITE, 0.4, 0.0, s)
		for side in [-1.0, 1.0]:
			var w := _node(Vector3(side * 0.42, 0.55, -0.1), g)
			_add(_sphere(0.3), wm, Vector3(side * 0.28, 0.08, 0), w, Vector3(0, 0, side * 0.35), Vector3(1.0, 0.5, 0.55))
			_p["wing%d_%d" % [i, int(side)]] = w
		if i == 0:
			_add(_torus(0.44, 0.58), _mat(c2, 0.3, 0.0, s), Vector3(0, 0.34, 0), g)
			_add(_box(Vector3(0.16, 0.4, 0.08)), _mat(c2, 0.3, 0.0, s), Vector3(0.28, 0.15, 0.45), g, Vector3(0.2, 0, 0.3))


## ミツボシ：夜空色のおばけが星のステッキを振る。三つの星がまわりを巡る
func _b_mitsuboshi() -> void:
	var col := c1.lightened(0.12)
	_mini(col, 0.95, Vector3.ZERO)
	var speck := flat(Color("fff7c2"))
	for d in [Vector3(-0.8, 0.5, -0.1), Vector3(-0.5, 0.85, -0.2), Vector3(0.6, 0.75, -0.3), Vector3(0.1, 0.9, -0.45), Vector3(-0.3, 0.3, -0.9), Vector3(0.75, 0.3, -0.55)]:
		_add(_sphere(0.022), speck, Vector3(0, 0.475, 0) + d.normalized() * 0.472)
	var wand := _node(Vector3(0.5, 0.42, 0.25), null, Vector3(0, 0, -0.45))
	_p.wand = wand
	_add(_cyl(0.022, 0.022, 0.5, 8), _mat(Color("f4e3c4")), Vector3(0, 0.2, 0), wand)
	_star(0.13, c2, Vector3(0, 0.5, 0), wand, 0.6)
	_add(_sphere(0.08), _skin(col), Vector3(0, 0.02, 0), wand)
	var orbit := _node(Vector3(0, 0.55, 0))
	_p.orbit = orbit
	for i in 3:
		var a := TAU * i / 3.0
		var st := _star(0.09, c2, Vector3(sin(a) * 0.72, 0.28 + i * 0.12, cos(a) * 0.72), orbit, 0.6)
		st.rotation.y = a


## ハツコエ：メガホンで、はじめましての大きな声
func _b_hatsukoe() -> void:
	_mini(c1, 0.9, Vector3(-0.14, 0, -0.05))
	var dir := Vector3(0.75, 0.12, 0.9).normalized()
	var meg := _node(Vector3(-0.08, 0.34, 0.38) + dir * 0.22)
	meg.scale = Vector3.ONE * 0.85
	_p.meg = meg
	var cone := _add(_cyl(0.07, 0.25, 0.45), _mat(c2), Vector3.ZERO, meg)
	_point(cone, -dir)
	var ring := _add(_torus(0.23, 0.28), _mat(Color.WHITE, 0.3), dir * 0.22, meg)
	_point(ring, dir)
	var inner := _add(_cyl(0.22, 0.22, 0.01), flat(Color("7a3a28")), dir * 0.215, meg)
	_point(inner, dir)
	_add(_sphere(0.1), _skin(c1), Vector3(0, -0.12, 0) - dir * 0.08, meg)
	for i in 2:
		var w := _add(_torus(0.14 + i * 0.08, 0.175 + i * 0.08), _mat(c2.lightened(0.3), 0.3, 0.3, 3.0), dir * (0.4 + i * 0.14), meg)
		_point(w, dir)
		_p["wave%d" % i] = w


## ヨナキ：おばけが屋根になった屋台。夜の街を静かにひく
func _b_yonaki() -> void:
	var col := c1.lightened(0.28)
	var roof := _mini(col, 0.8, Vector3(0, 0.46, -0.08))
	_p.roof = roof
	var wood := _mat(WOOD)
	_add(_box(Vector3(1.05, 0.38, 0.6)), wood, Vector3(0, 0.36, 0.05))
	_add(_box(Vector3(1.15, 0.05, 0.7)), _mat(WOOD_DARK), Vector3(0, 0.57, 0.05))
	for x in [-0.36, 0.36]:
		_add(_cyl(0.16, 0.16, 0.06, 18), _mat(Color("3a3440")), Vector3(x, 0.16, 0.37), null, Vector3(PI / 2, 0, 0))
		_add(_sphere(0.04), _mat(Color("c8ced6")), Vector3(x, 0.16, 0.41))
	_add(_hemi(0.12), _mat(Color.WHITE, 0.3), Vector3(0.3, 0.6, 0.2), null, Vector3(PI, 0, 0))
	_add(_cyl(0.11, 0.11, 0.01), _mat(Color("ffcf5a")), Vector3(0.3, 0.6, 0.2))
	var lan := _node(Vector3(-0.56, 0.95, 0.28))
	_p.lantern = lan
	_add(_cyl(0.008, 0.008, 0.12, 6), _mat(INK), Vector3(0, 0.02, 0), lan)
	_add(_sphere(0.09), _skin(Color("ff7a5c"), 1.0, 0.9), Vector3(0, -0.1, 0), lan, Vector3.ZERO, Vector3(1, 1.25, 1))
	for i in 3:
		_p["fly%d" % i] = _glow(0.03, c2, Vector3(-0.6 + i * 0.6, 1.05 + (i % 2) * 0.15, 0.2 - i * 0.1))


# ---------------------------------------------------------------- 時間帯

## アサツユ：大きな葉っぱの上に、朝露と小さなおばけ
func _b_asatsuyu() -> void:
	var leaf := _node(Vector3(0, 0.34, 0), null, Vector3(0, -0.35, 0.18))
	_p.leaf = leaf
	_add(_sphere(0.5), _mat(c2.darkened(0.1)), Vector3.ZERO, leaf, Vector3.ZERO, Vector3(1.4, 0.1, 0.66))
	_add(_cyl(0.012, 0.02, 1.2, 8), _mat(c2.lightened(0.35)), Vector3(0, 0.03, 0), leaf, Vector3(0, 0, PI / 2))
	_mini(c1, 0.5, Vector3(0.14, 0.03, 0.0), leaf)
	var drop := _node(Vector3(-0.42, 0.12, 0.08), leaf)
	_p.drop = drop
	_add(_sphere(0.1), _mat(Color("8fd6ff"), 0.35, 0.1), Vector3(0, -0.02, 0), drop, Vector3.ZERO, Vector3(1, 0.85, 1))
	_add(_sphere(0.03), flat(Color.WHITE), Vector3(0.04, 0.05, 0.1), drop)


## ツキミ：月見だんごの串に、小さなおばけが三つ。うしろにまんまるの月
func _b_tsukimi() -> void:
	_add(_cyl(0.52, 0.52, 0.04, 32), _mat(Color("ffe38a"), 0.3, 0.35), Vector3(0, 0.78, -0.35), null, Vector3(PI / 2, 0, 0))
	_add(_cyl(0.3, 0.26, 0.05, 24), _mat(Color("e0c08a")), Vector3(0, 0.025, 0))
	_add(_cyl(0.022, 0.022, 1.32, 8), _mat(Color("d8b27a")), Vector3(0, 0.68, 0))
	var cols := [Color("cdeaa8"), Color("fffaf0"), Color("ffc9d9")]
	for i in 3:
		_p["dango%d" % i] = _mini(cols[i], 0.36, Vector3(0, 0.08 + i * 0.36, 0))
	for x in [-0.42, 0.44]:
		var grass := _node(Vector3(x, 0.0, -0.15), null, Vector3(0, 0, -x * 0.35))
		_add(_cyl(0.012, 0.016, 0.8, 6), _mat(Color("b8a878")), Vector3(0, 0.4, 0), grass)
		_add(_cap(0.06, 0.3), _mat(c2.lightened(0.2), 0.4), Vector3(0, 0.88, 0), grass)


## タソガレ：右半分が昼、左半分が夜。お日さまとお月さまがまわりを巡る
func _b_tasogare() -> void:
	var m := _stripes([c1, c1, c2, c2], 0.12)
	var g := ghost(Color.WHITE, 1.0, 0.0, INK, false, true, m)
	body.add_child(g)
	# 夜の側の目を白く
	for e in eyes:
		if e.position.x < 0:
			e.material_override = eye_mat(Color.WHITE)
	var orbit := _node(Vector3(0, 0.55, 0))
	_p.orbit = orbit
	var sun := _node(Vector3(0.72, 0.3, 0), orbit)
	_add(_sphere(0.1), _mat(Color("ffcf5a"), 0.3, 0.6), Vector3.ZERO, sun)
	for i in 8:
		var a := TAU * i / 8.0
		_add(_cyl(0.0, 0.03, 0.07, 6), _mat(Color("ffcf5a"), 0.3, 0.6), Vector3(-sin(a), cos(a), 0) * 0.15, sun, Vector3(0, 0, a))
	var moon := _node(Vector3(-0.72, 0.3, 0), orbit)
	_add(_sphere(0.1), _mat(Color("fff1c8"), 0.3, 0.4), Vector3.ZERO, moon)
	_add(_sphere(0.085), _mat(c2.darkened(0.2)), Vector3(0.06, 0.03, 0.04), moon)


## マヨナカ：真夜中の品出し。積んだ段ボールのいちばん上から顔を出す
func _b_shinya() -> void:
	var card := _mat(c2)
	var tape := _mat(c2.darkened(0.25))
	_add(_box(Vector3(0.82, 0.36, 0.62)), card, Vector3(0, 0.18, 0))
	_add(_box(Vector3(0.16, 0.365, 0.625)), tape, Vector3(0, 0.18, 0))
	var top := _node(Vector3(0.02, 0.53, 0.0), null, Vector3(0, 0.12, 0))
	_add(_box(Vector3(0.74, 0.34, 0.58)), card, Vector3.ZERO, top)
	_add(_box(Vector3(0.22, 0.02, 0.58)), card, Vector3(0.44, 0.2, 0), top, Vector3(0, 0, -1.0))
	_add(_box(Vector3(0.22, 0.02, 0.58)), card, Vector3(-0.44, 0.2, 0), top, Vector3(0, 0, 1.0))
	var g := _mini(c1.lightened(0.3), 0.68, Vector3(0, 0.02, 0.0), top)
	_p.peek = g


## アマガサ：紅白の唐傘が頭になったおばけ。一本足の下駄で、ぴょんぴょん
func _b_amagasa() -> void:
	var um := _node(Vector3(0, 0.68, 0))
	_p.umbrella = um
	var cols := []
	for i in 8:
		cols.append(PAPER if i % 2 == 0 else RED)
	var sm := _stripes(cols, 0.12)
	_add(_hemi(0.62), sm, Vector3.ZERO, um, Vector3(0, -TAU / 16.0, 0), Vector3(1, 0.72, 1))
	for i in 16:
		var a := TAU * i / 16.0
		_add(_sphere(0.075), _mat(RED if i % 2 else PAPER, 0.2), Vector3(sin(a) * 0.6, 0.0, cos(a) * 0.6), um)
	_add(_cyl(0.03, 0.05, 0.08, 10), _mat(RED), Vector3(0, 0.47, 0), um)
	_add(_sphere(0.045), _mat(WOOD_DARK), Vector3(0, 0.53, 0), um)
	# 傘はくるくる回すので、顔は回さないよう体に付ける。
	# 傘の面は上向きに傾いているので、顔もその傾き（約 35 度）に合わせ、縁の玉より上に置く
	var tilt := 0.62
	var n := Vector3(0, sin(tilt), cos(tilt))
	var on_canopy := Vector3(0, 0.215, 0.545)
	var fc := face(um.position + on_canopy - n * 0.4, 0.8)
	fc.rotation.x = -tilt
	body.add_child(fc)
	var leg := _node(Vector3(0, 0.0, 0.05))
	_add(_cyl(0.028, 0.028, 0.3, 8), _mat(WOOD_DARK), Vector3(0, 0.55, 0), leg)
	_add(_cap(0.1, 0.34), _skin(c1), Vector3(0, 0.3, 0), leg)
	_add(_box(Vector3(0.2, 0.05, 0.34)), _mat(WOOD), Vector3(0, 0.08, 0.02), leg)
	for z in [-0.08, 0.12]:
		_add(_box(Vector3(0.17, 0.06, 0.05)), _mat(WOOD_DARK), Vector3(0, 0.03, z), leg)
	_add(_box(Vector3(0.22, 0.04, 0.05)), _mat(RED), Vector3(0, 0.14, 0.1), leg)
	for i in 4:
		var d := _add(_sphere(0.03), _mat(c1.lightened(0.2), 0.6), Vector3(-0.75 + i * 0.5, 1.1 - (i % 2) * 0.3, 0.1 - i * 0.1), null, Vector3.ZERO, Vector3(0.7, 1.4, 0.7))
		_p["rain%d" % i] = d


## ユキミ：おばけ三つで雪だるま。バケツをかぶって、枝の腕
func _b_yukimi() -> void:
	body.add_child(ghost(c1.darkened(0.05), 0.72, 0.0, INK, false, false))
	var top := _mini(Color.WHITE, 0.58, Vector3(0, 0.56, 0.03))
	_p.top = top
	var scarf := _mat(Color("5d99c8"), 0.3, 0.0, 0.58)
	_add(_torus(0.44, 0.58), scarf, Vector3(0, 0.26, 0), top, Vector3(0.1, 0, 0))
	_add(_box(Vector3(0.18, 0.42, 0.08)), scarf, Vector3(0.3, 0.06, 0.45), top, Vector3(0.1, 0, 0.25))
	_add(_cyl(0.26, 0.21, 0.26), _mat(c2.darkened(0.15), 0.3, 0.0, 0.58), Vector3(0.06, 1.02, 0), top, Vector3(0, 0, 0.3))
	var twig := _mat(WOOD_DARK)
	for side in [-1.0, 1.0]:
		var arm := _node(Vector3(side * 0.3, 0.74, 0.02), null, Vector3(0, 0, -side * 1.1))
		_add(_cyl(0.018, 0.022, 0.36, 6), twig, Vector3(0, 0.18, 0), arm)
		_add(_cyl(0.012, 0.015, 0.12, 6), twig, Vector3(side * 0.04, 0.3, 0), arm, Vector3(0, 0, -side * 0.7))
	for i in 4:
		_p["flake%d" % i] = _flake(0.06, Color.WHITE if i % 2 else c2, Vector3(-0.55 + (i % 2) * 1.1, 0.35 + i * 0.25, 0.15))


# ---------------------------------------------------------------- 天気

## カミナリ：おばけの頭に、ずんぐりした龍の体。角と、稲妻と、小さな雷雲
func _b_kaminari() -> void:
	var skin := _skin(c1)
	var belly := _mat(c1.lightened(0.45), 0.2)
	var dark := _mat(c2)
	var trunk := _add(_cap(0.3, 1.0), skin, Vector3(-0.12, 0.36, -0.12))
	_point(trunk, Vector3(1.0, 0.25, 0.45))
	_add(_sphere(0.26), skin, Vector3(0.12, 0.52, 0.02))
	_head(c1, 0.4, Vector3(0.24, 0.78, 0.1))
	body.add_child(face(Vector3(0.24, 0.78, 0.1), 0.8))
	_add(_sphere(0.22), belly, Vector3(0.08, 0.36, 0.2), null, Vector3.ZERO, Vector3(1, 1, 0.6))
	for p in [Vector3(0.1, 0.1, 0.18), Vector3(0.18, 0.1, -0.12), Vector3(-0.42, 0.1, -0.06), Vector3(-0.3, 0.1, -0.36)]:
		_add(_cap(0.1, 0.24), skin, p)
	for x in [-0.15, 0.15]:
		_add(_cyl(0.0, 0.07, 0.2, 10), dark, Vector3(0.24 + x, 1.18, 0.05), null, Vector3(-0.2, 0, -x * 2.2))
	for i in 4:
		_add(_cyl(0.0, 0.06, 0.13, 8), dark, Vector3(-0.08 - i * 0.14, 0.66 - i * 0.05, -0.2 - i * 0.07), null, Vector3(0, 0, 0.4))
	var tail := _node(Vector3(-0.55, 0.26, -0.36))
	_p.tail = tail
	# 竜の尻尾：胴から先へ細くなる一本の管
	var pts := PackedVector3Array()
	var rad := PackedFloat32Array()
	var r := 0.16
	var p2 := Vector3.ZERO
	pts.append(Vector3(0.22, -0.06, 0.12))
	rad.append(0.2)
	for i in 4:
		pts.append(p2)
		rad.append(r)
		p2 += Vector3(-0.14, 0.08 + i * 0.03, -0.02)
		r *= 0.8
	_add(tube("kaminari_tail", pts, rad, 24), skin, Vector3.ZERO, tail)
	_add(_cyl(0.0, 0.07, 0.16, 8), dark, p2 + Vector3(0.02, 0.04, 0), tail, Vector3(0, 0, 0.3))
	var bolt := _node(Vector3(-0.3, 1.0, 0.0), null, Vector3(0, 0, -0.2))
	bolt.scale = Vector3.ONE * 1.6
	_p.bolt = bolt
	var bm := _mat(Color("ffe14d"), 0.3, 0.9, 0.6)
	_add(_box(Vector3(0.07, 0.2, 0.04)), bm, Vector3(-0.03, 0.08, 0), bolt, Vector3(0, 0, -0.5))
	_add(_box(Vector3(0.16, 0.05, 0.04)), bm, Vector3(0.0, -0.01, 0), bolt, Vector3(0, 0, 0.2))
	_add(_box(Vector3(0.07, 0.22, 0.04)), bm, Vector3(0.04, -0.1, 0), bolt, Vector3(0, 0, -0.5))


## サクラ：おばけの頭が満開の桜の木。花びらがひらひら
func _b_sakura() -> void:
	var bark := _mat(Color("9a6a4a"))
	_add(_cyl(0.11, 0.17, 0.5, 14), bark, Vector3(0, 0.25, 0))
	for i in 3:
		var a := TAU * i / 3.0 + 0.4
		_add(_sphere(0.09), bark, Vector3(sin(a) * 0.15, 0.03, cos(a) * 0.15), null, Vector3.ZERO, Vector3(1.4, 0.6, 1.4))
	var crown := _node(Vector3(0, 0.84, 0))
	_p.crown = crown
	_head(c1, 0.44, Vector3.ZERO, crown)
	var puff := _skin(c1)
	for d in [Vector3(-0.38, 0.1, -0.1), Vector3(0.38, 0.12, -0.1), Vector3(-0.22, 0.3, -0.2), Vector3(0.2, 0.32, -0.18), Vector3(0.0, 0.2, -0.36), Vector3(-0.36, -0.14, -0.2), Vector3(0.36, -0.14, -0.2)]:
		_add(_sphere(0.24), puff, d, crown)
	crown.add_child(face(Vector3(0, -0.02, 0.0), 0.88))
	var petal := _mat(c2, 0.3)
	for d in [Vector3(-0.4, 0.3, 0.12), Vector3(0.44, 0.2, 0.14), Vector3(0.05, 0.46, 0.14), Vector3(-0.5, -0.1, 0.1), Vector3(0.5, -0.08, 0.05)]:
		var fl := _node(d, crown)
		for k in 5:
			var a := TAU * k / 5.0
			_add(_sphere(0.045), petal, Vector3(sin(a), cos(a), 0) * 0.045, fl, Vector3.ZERO, Vector3(1, 1, 0.4))
		_add(_sphere(0.022), _mat(Color("ffe27a"), 0.3), Vector3(0, 0, 0.015), fl)
	for i in 4:
		_p["petal%d" % i] = _add(_sphere(0.04), petal, Vector3(-0.6 + i * 0.4, 0.3 + (i % 2) * 0.25, 0.3), null, Vector3(0.5, i, 0.3), Vector3(1, 0.35, 0.8))


# ---------------------------------------------------------------- つながり

## ナカヨシ：ふたりで一本のマフラー。寄りそって揺れる
func _b_nakayoshi() -> void:
	var a := _mini(c1, 0.8, Vector3(-0.33, 0, 0))
	a.rotation.z = -0.08
	var b := _mini(c2, 0.8, Vector3(0.33, 0, 0))
	b.rotation.z = 0.08
	_p.a = a
	_p.b = b
	var scarf := _mat(RED, 0.3)
	_add(_torus(0.4, 0.5), scarf, Vector3(0, 0.34, 0), null, Vector3.ZERO, Vector3(1.72, 0.9, 0.95))
	_add(_sphere(0.08), scarf, Vector3(0, 0.33, 0.44))
	_add(_box(Vector3(0.1, 0.3, 0.05)), scarf, Vector3(-0.05, 0.2, 0.45), null, Vector3(0.1, 0, 0.2))
	_add(_box(Vector3(0.1, 0.26, 0.05)), scarf, Vector3(0.07, 0.2, 0.44), null, Vector3(0.1, 0, -0.25))
	var heart := _node(Vector3(0, 1.0, 0.1))
	_p.heart = heart
	var hm := _mat(Color("ff8fb1"), 0.3, 0.2)
	for x in [-0.045, 0.045]:
		_add(_sphere(0.06), hm, Vector3(x, 0, 0), heart)
	_add(_cyl(0.0, 0.085, 0.1, 12), hm, Vector3(0, -0.06, 0), heart, Vector3(PI, 0, 0))


## オクリモノ：おばけが贈りものの箱になった。赤いふたにリボン
func _b_okurimono() -> void:
	var box := _node(Vector3.ZERO)
	_p.box = box
	var skin := _skin(c1)
	# 箱の下からのぞく、波打つ裾（ふつうのおばけの体を縮めて箱の中に入れる）
	_add(body_meshes("plain").body, skin, Vector3.ZERO, box, Vector3.ZERO, Vector3(0.8, 0.8, 0.8))
	_add(_box(Vector3(0.9, 0.62, 0.8)), skin, Vector3(0, 0.46, 0), box)
	box.add_child(face(Vector3(0, 0.38, -0.03), 0.9))
	var red := _mat(c2, 0.3)
	_add(_box(Vector3(0.98, 0.16, 0.88)), red, Vector3(0, 0.8, 0), box)
	var bow := _node(Vector3(0, 0.9, 0), box)
	_p.bow = bow
	for side in [-1.0, 1.0]:
		_add(_torus(0.07, 0.14), red, Vector3(side * 0.15, 0.1, 0), bow, Vector3(PI / 2, 0, side * 0.5), Vector3(1, 1, 0.6))
		_add(_box(Vector3(0.09, 0.2, 0.03)), red, Vector3(side * 0.1, -0.02, 0.2), bow, Vector3(-0.8, 0, side * 0.5))
	_add(_sphere(0.07), red, Vector3(0, 0.06, 0), bow)


## モラッタン：もらった大きな箱を、頭の上にかかえてよろよろ
func _b_morattan() -> void:
	_mini(c1, 0.72, Vector3(0, 0, 0.05))
	var skin := _skin(c1)
	for x in [-0.3, 0.3]:
		_add(_sphere(0.09), skin, Vector3(x, 0.72, 0.12))
	var box := _node(Vector3(0, 1.0, 0.02), null, Vector3(0, 0.35, 0.08))
	_p.box = box
	_add(_box(Vector3(0.62, 0.44, 0.52)), _mat(c2), Vector3.ZERO, box)
	var rib := _mat(Color.WHITE, 0.3)
	_add(_box(Vector3(0.12, 0.45, 0.53)), rib, Vector3.ZERO, box)
	_add(_box(Vector3(0.63, 0.45, 0.12)), rib, Vector3.ZERO, box)
	for side in [-1.0, 1.0]:
		_add(_torus(0.05, 0.1), rib, Vector3(side * 0.1, 0.27, 0), box, Vector3(PI / 2, 0, side * 0.5), Vector3(1, 1, 0.6))
	_add(_sphere(0.05), rib, Vector3(0, 0.25, 0), box)
	_star(0.06, Color("ffe27a"), Vector3(-0.48, 1.2, 0.1), null, 0.7)
	_star(0.045, Color("ffe27a"), Vector3(0.5, 0.75, 0.2), null, 0.7)


## テヲツナグ：みんなで組んだおばけのピラミッド。てっぺんは鉢巻き
func _b_teamwork() -> void:
	var s := 0.42
	var spots := [Vector3(-0.42, 0, 0), Vector3(0, 0, 0.04), Vector3(0.42, 0, 0), Vector3(-0.21, 0.36, 0.02), Vector3(0.21, 0.36, 0.02), Vector3(0, 0.72, 0.03)]
	for i in spots.size():
		_p["g%d" % i] = _mini(c1 if i % 2 == 0 else c2, s, spots[i])
	var top: Node3D = _p.g5
	var band := _mat(Color.WHITE, 0.3, 0.0, s)
	_add(_torus(0.44, 0.52), band, Vector3(0, 0.78, 0), top, Vector3.ZERO, Vector3(1, 1.4, 1))
	_add(_sphere(0.08), _mat(RED, 0.3, 0.0, s), Vector3(0, 0.78, 0.5), top)
	for side in [-1.0, 1.0]:
		_add(_box(Vector3(0.28, 0.08, 0.06)), band, Vector3(0.52 + side * 0.02, 0.78, -0.22), top, Vector3(0, 0.5, side * 0.5 - 0.3))
	_star(0.06, c2, Vector3(-0.5, 0.95, 0.1), null, 0.7)
	_star(0.05, c2, Vector3(0.5, 0.85, 0.1), null, 0.7)


## センパイ：丸めがねで本を読んであげる。となりで後輩が見上げる
func _b_senpai() -> void:
	var s := 0.92
	var g := _mini(c1, s, Vector3(0.1, 0, 0))
	var fr := _mat(c2.darkened(0.2), 0.2, 0.0, s)
	for x in [-0.17, 0.17]:
		_add(_torus(0.085, 0.115), fr, Vector3(x, 0.55, 0.49), g, Vector3(PI / 2, 0, 0))
	_add(_cyl(0.015, 0.015, 0.1, 6), fr, Vector3(0, 0.57, 0.5), g, Vector3(0, 0, PI / 2))
	var book := _node(Vector3(0.08, 0.3, 0.52), null, Vector3(-0.7, 0, 0))
	_p.book = book
	_add(_box(Vector3(0.52, 0.03, 0.34)), _mat(c2), Vector3(0, -0.02, 0), book)
	for side in [-1.0, 1.0]:
		_add(_box(Vector3(0.23, 0.03, 0.31)), _mat(Color.WHITE, 0.3), Vector3(side * 0.125, 0.015, 0), book, Vector3(0, 0, -side * 0.12))
	for x in [-0.3, 0.46]:
		_add(_sphere(0.08), _skin(c1), Vector3(x, 0.3, 0.45))
	var kohai := _mini(c1.lightened(0.55), 0.42, Vector3(-0.62, 0, 0.3))
	kohai.rotation = Vector3(-0.15, 0.5, 0)
	_p.kohai = kohai


## ヤスミジョウズ：たらいのお湯につかって、アヒルと休む
func _b_yasumijouzu() -> void:
	var tub := _mat(Color("c89660"))
	_add(_cyl(0.5, 0.44, 0.48, 24), tub, Vector3(0, 0.24, 0))
	for y in [0.1, 0.38]:
		var rr: float = 0.44 + (y / 0.48) * 0.06
		_add(_torus(rr - 0.005, rr + 0.03), _mat(WOOD_DARK), Vector3(0, y, 0))
	var g := _mini(c1, 0.72, Vector3(0, 0.2, 0))
	_p.bather = g
	_add(_cyl(0.48, 0.48, 0.02, 24), _mat(Color("aee8f0"), 0.5), Vector3(0, 0.46, 0))
	var duck := _node(Vector3(0.3, 0.5, 0.26), null, Vector3(0, 0.6, 0))
	_p.duck = duck
	var dm := _mat(Color("ffd93b"), 0.3)
	_add(_sphere(0.09), dm, Vector3.ZERO, duck, Vector3.ZERO, Vector3(1.2, 0.8, 1))
	_add(_sphere(0.06), dm, Vector3(0.06, 0.09, 0), duck)
	_add(_cyl(0.0, 0.025, 0.06, 8), _mat(Color("ff9a4d")), Vector3(0.12, 0.09, 0), duck, Vector3(0, 0, -PI / 2))
	for i in 3:
		_p["bub%d" % i] = _add(_sphere(0.04 + i * 0.01), _mat(Color.WHITE, 0.6), Vector3(-0.32 + i * 0.1, 0.49, 0.2 - i * 0.12))
	_p["steam0"] = _puff(0.045, Color.WHITE, Vector3(-0.4, 1.0, -0.1))
	_p["steam1"] = _puff(0.045, Color.WHITE, Vector3(0.42, 1.05, -0.15))


## シュウマツ：白鳥ボートで、週末の池をのんびり
func _b_shuumatsu() -> void:
	_add(_cyl(0.8, 0.8, 0.03, 32), _mat(c2, 0.4), Vector3(0, 0.015, 0))
	var boat := _node(Vector3(0, 0.02, 0))
	_p.boat = boat
	var white := _mat(Color.WHITE, 0.3)
	_add(_sphere(0.5), white, Vector3(0, 0.16, 0), boat, Vector3.ZERO, Vector3(1.3, 0.5, 0.95))
	_add(_cyl(0.0, 0.12, 0.22, 10), white, Vector3(-0.66, 0.36, 0), boat, Vector3(0, 0, 0.9))
	_mini(c1, 0.6, Vector3(-0.1, 0.34, 0.06), boat)
	var neck := Curve3D.new()
	for p in [Vector3(0.5, 0.26, 0), Vector3(0.66, 0.45, 0), Vector3(0.64, 0.66, 0), Vector3(0.6, 0.8, 0)]:
		neck.add_point(p)
	for i in 10:
		_add(_sphere(0.075), white, neck.sample_baked(neck.get_baked_length() * i / 9.0), boat)
	_add(_sphere(0.12), white, Vector3(0.66, 0.86, 0), boat)
	_add(_cyl(0.0, 0.045, 0.14, 8), _mat(Color("ff9a4d")), Vector3(0.82, 0.84, 0), boat, Vector3(0, 0, -PI / 2 - 0.2))
	for z in [-0.1, 0.1]:
		_add(_sphere(0.022), flat(INK), Vector3(0.72, 0.9, z), boat)


# ---------------------------------------------------------------- リズム

## ヒャッキ：ふつうのおばけたちの行列。先頭は王冠をかぶって提灯をかかげる
func _b_hyakki() -> void:
	var cols := [COLORS.nemuri, COLORS.box, COLORS.lantern.lightened(0.2), COLORS.pan, COLORS.tray, COLORS.bubble, COLORS.receipt]
	var n := cols.size() + 1
	for i in n:
		var u := float(i) / (n - 1)
		var p := Vector3(-0.75 + u * 1.4, 0, -0.4 + u * 0.75 + sin(u * PI * 2.0) * 0.3)
		var lead := i == n - 1
		var s := 0.62 if lead else 0.34
		var g := _mini(c2 if lead else cols[i], s, p)
		g.rotation.y = 0.1
		_p["walker%d" % i] = g
		if lead:
			var gold := _mat(Color("ffd23f"), 0.3, 0.2, s)
			_add(_cyl(0.3, 0.26, 0.2, 16), gold, Vector3(0, 1.02, 0), g)
			for k in 5:
				var a := TAU * k / 5.0
				_add(_cyl(0.0, 0.08, 0.2, 8), gold, Vector3(cos(a) * 0.27, 1.2, sin(a) * 0.27), g)
			var pole := _node(Vector3(0.52, 0.3, 0.2), g, Vector3(0, 0, -0.25))
			_add(_cyl(0.03, 0.03, 1.0, 6), _mat(WOOD_DARK, 0.2, 0.0, s), Vector3(0, 0.5, 0), pole)
			_add(_sphere(0.16), _skin(Color("ffb35c"), s, 0.9), Vector3(0.12, 0.85, 0), pole, Vector3.ZERO, Vector3(1, 1.3, 1))
	for i in 3:
		_p["fly%d" % i] = _glow(0.03, Color("ffe27a"), Vector3(-0.6 + i * 0.55, 0.7 + (i % 2) * 0.2, 0.0))


## カゾエウタ：たくさんの手で数をかぞえて、そろばんをはじいて歌う
func _b_kazoeuta() -> void:
	_mini(c1, 0.9, Vector3.ZERO)
	var skin := _skin(c1)
	for side in [-1.0, 1.0]:
		for k in 3:
			var arm := _node(Vector3(side * 0.4, 0.3 + k * 0.14, 0.05 - k * 0.06), null, Vector3(0, 0, -side * (0.6 + k * 0.45)))
			_add(_cap(0.045, 0.24), skin, Vector3(0, 0.12, 0), arm)
			_add(_sphere(0.065), skin, Vector3(0, 0.25, 0), arm)
			_p["arm%d_%d" % [k, int(side)]] = arm
	var ab := _node(Vector3(0, 0.22, 0.56), null, Vector3(-0.35, 0, 0))
	var fr := _mat(WOOD_DARK)
	_add(_box(Vector3(0.56, 0.04, 0.04)), fr, Vector3(0, 0.13, 0), ab)
	_add(_box(Vector3(0.56, 0.04, 0.04)), fr, Vector3(0, -0.13, 0), ab)
	_add(_box(Vector3(0.56, 0.02, 0.03)), fr, Vector3(0, 0.03, 0), ab)
	for x in [-0.27, 0.27]:
		_add(_box(Vector3(0.04, 0.3, 0.04)), fr, Vector3(x, 0, 0), ab)
	for k in 4:
		var x := -0.18 + k * 0.12
		_add(_cyl(0.008, 0.008, 0.26, 6), fr, Vector3(x, 0, 0), ab)
		_add(_sphere(0.04), _mat(c2, 0.3), Vector3(x, 0.08, 0), ab, Vector3.ZERO, Vector3(1, 0.7, 1))
		for j in 2:
			_add(_sphere(0.04), _mat(Color("ff8fb1"), 0.3), Vector3(x, -0.03 - j * 0.06 - (k % 2) * 0.02, 0), ab, Vector3.ZERO, Vector3(1, 0.7, 1))
	for i in 2:
		var note := _node(Vector3(0.52 - i * 1.0, 1.0 - i * 0.08, 0.05))
		_p["note%d" % i] = note
		var nm := _mat(c2.darkened(0.2), 0.3)
		_add(_sphere(0.05), nm, Vector3.ZERO, note, Vector3(0, 0, 0.4), Vector3(1.3, 1, 0.7))
		_add(_box(Vector3(0.018, 0.18, 0.018)), nm, Vector3(0.05, 0.09, 0), note)
		_add(_box(Vector3(0.07, 0.03, 0.018)), nm, Vector3(0.08, 0.17, 0), note, Vector3(0, 0, -0.4))


## マンゲツ：まんまるのお月さまおばけ。てっぺんに小さなおばけ
func _b_mangetsu() -> void:
	var s := 1.08
	var moon := _mini(c2, s, Vector3.ZERO)
	var crater := _mat(c2.darkened(0.12), 0.1, 0.0, s)
	for d in [Vector3(-0.8, 0.5, 0.2), Vector3(0.7, 0.75, -0.1), Vector3(-0.3, 0.8, -0.55), Vector3(0.5, 0.2, -0.8), Vector3(0.85, 0.1, 0.45)]:
		var n: Vector3 = d.normalized()
		var cm := _add(_sphere(0.08 + absf(d.x) * 0.03), crater, Vector3(0, 0.5, 0) + n * 0.49, moon, Vector3.ZERO, Vector3(1, 1, 0.35))
		cm.basis = Basis(Quaternion(Vector3.BACK, n)) * Basis.from_scale(Vector3(1, 1, 0.35))
	var tiny := _mini(c1, 0.28, Vector3(0.05, 1.04, 0.0))
	_p.tiny = tiny
	_star(0.07, Color("fff1c8"), Vector3(-0.66, 1.05, 0.1), null, 0.6)
	_star(0.05, Color("fff1c8"), Vector3(0.68, 0.95, 0.0), null, 0.6)


# ---------------------------------------------------------------- 動き

func _process(delta: float) -> void:
	super._process(delta)
	_idle(_t)


## 部品の transform を、元の形から少し動かした形にする
func _wiggle(k: String, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := 1.0) -> void:
	if not _p.has(k):
		return
	var n: Node3D = _p[k]
	var b: Transform3D = _base[k]
	n.transform = Transform3D(b.basis * Basis.from_euler(rot) * Basis.from_scale(Vector3.ONE * scl), b.origin + pos)


func _idle(t: float) -> void:
	match species:
		"nemurin":
			_wiggle("roll", Vector3.ZERO, Vector3(0, 0, sin(t * 1.2) * 0.04))
			_wiggle("bubble", Vector3.ZERO, Vector3.ZERO, 0.7 + (sin(t * 1.6) * 0.5 + 0.5) * 0.9)
		"yumemi":
			_wiggle("cloud", Vector3(0, sin(t * 1.3) * 0.04, 0), Vector3(0, 0, sin(t * 0.9) * 0.05))
		"asayake":
			_wiggle("rays", Vector3.ZERO, Vector3(0, 0, t * 0.3))
		"yomise":
			_wiggle("lantern", Vector3.ZERO, Vector3(0, 0, sin(t * 1.3) * 0.1))
		"hirunen":
			_wiggle("melt", Vector3.ZERO, Vector3.ZERO, 1.0 + sin(t * 1.4) * 0.025)
		"totonou", "yasumijouzu":
			for i in 3:
				var k := fmod(t * 0.35 + i * 0.33, 1.0)
				_wiggle("steam%d" % i, Vector3(sin(k * 6.0) * 0.03, k * 0.2, 0), Vector3.ZERO, 1.0 - k * 0.6)
			_wiggle("duck", Vector3(0, sin(t * 2.0) * 0.015, 0), Vector3(0, 0, sin(t * 2.0) * 0.1))
			_wiggle("bather", Vector3(0, sin(t * 1.1) * 0.015, 0))
		"kirari":
			_wiggle("crown", Vector3.ZERO, Vector3(0, 0, sin(t * 2.4) * 0.07))
		"hajimete":
			_wiggle("hat", Vector3.ZERO, Vector3(0, 0, sin(t * 7.0) * 0.02))
			_wiggle("drop", Vector3(0, -fmod(t * 0.3, 1.0) * 0.1, 0))
		"wataridori":
			for i in 5:
				_wiggle("bird%d" % i, Vector3(0, sin(t * 2.0 + i) * 0.03, 0))
				for side in [-1, 1]:
					_wiggle("wing%d_%d" % [i, side], Vector3.ZERO, Vector3(0, 0, side * sin(t * 7.0 + i) * 0.35))
		"mitsuboshi":
			_wiggle("orbit", Vector3.ZERO, Vector3(0, t * 0.8, 0))
			_wiggle("wand", Vector3.ZERO, Vector3(0, 0, sin(t * 2.0) * 0.15))
		"hatsukoe":
			for i in 3:
				var k := fmod(t * 0.8 + i / 3.0, 1.0)
				_wiggle("wave%d" % i, Vector3.ZERO, Vector3.ZERO, 0.7 + k * 0.6)
		"yonaki":
			_wiggle("lantern", Vector3.ZERO, Vector3(0, 0, sin(t * 1.5) * 0.12))
		"asatsuyu":
			_wiggle("leaf", Vector3(0, sin(t * 1.2) * 0.02, 0), Vector3(0, 0, sin(t * 1.2) * 0.04))
			_wiggle("drop", Vector3.ZERO, Vector3.ZERO, 1.0 + sin(t * 3.0) * 0.05)
		"tsukimi":
			for i in 3:
				_wiggle("dango%d" % i, Vector3.ZERO, Vector3(0, sin(t * 1.5 + i) * 0.3, 0))
		"tasogare":
			_wiggle("orbit", Vector3.ZERO, Vector3(0, t * 0.5, 0))
		"shinya":
			_wiggle("peek", Vector3(0, (sin(t * 1.3) * 0.5 + 0.5) * 0.08 - 0.04, 0))
		"amagasa":
			if bob:
				body.position.y = absf(sin(t * 3.0)) * 0.12
			_wiggle("umbrella", Vector3.ZERO, Vector3(0, t * 0.6, 0))
			for i in 4:
				_wiggle("rain%d" % i, Vector3(0, -fmod(t * 0.8 + i * 0.25, 1.0) * 0.5, 0))
		"yukimi":
			_wiggle("top", Vector3.ZERO, Vector3(0, 0, sin(t * 1.5) * 0.06))
			for i in 4:
				_wiggle("flake%d" % i, Vector3(sin(t + i) * 0.04, -fmod(t * 0.15 + i * 0.25, 1.0) * 0.3, 0), Vector3(0, 0, t * 0.8))
		"kaminari":
			_wiggle("tail", Vector3.ZERO, Vector3(0, sin(t * 3.0) * 0.3, sin(t * 3.0) * 0.08))
			_wiggle("bolt", Vector3.ZERO, Vector3.ZERO, 1.0 + (0.12 if fmod(t, 1.7) < 0.12 else 0.0))
		"sakura":
			_wiggle("crown", Vector3.ZERO, Vector3(0, 0, sin(t * 1.1) * 0.04))
			for i in 4:
				var k := fmod(t * 0.25 + i * 0.25, 1.0)
				_wiggle("petal%d" % i, Vector3(sin(k * 8.0) * 0.05, -k * 0.3, 0), Vector3(0, k * 4.0, 0))
		"nakayoshi":
			var sway := sin(t * 1.6) * 0.05
			_wiggle("a", Vector3.ZERO, Vector3(0, 0, sway))
			_wiggle("b", Vector3.ZERO, Vector3(0, 0, sway))
			_wiggle("heart", Vector3(0, sin(t * 2.0) * 0.03, 0), Vector3.ZERO, 1.0 + sin(t * 4.0) * 0.08)
		"okurimono":
			_wiggle("bow", Vector3.ZERO, Vector3(0, 0, sin(t * 3.0) * 0.1))
		"morattan":
			_wiggle("box", Vector3(sin(t * 2.2) * 0.02, 0, 0), Vector3(0, 0, sin(t * 2.2) * 0.07))
		"teamwork":
			for i in 6:
				_wiggle("g%d" % i, Vector3.ZERO, Vector3(0, 0, sin(t * 2.5 + i) * 0.05))
		"senpai":
			_wiggle("kohai", Vector3(0, absf(sin(t * 2.5)) * 0.05, 0))
			_wiggle("book", Vector3.ZERO, Vector3(sin(t * 1.2) * 0.05, 0, 0))
		"shuumatsu":
			_wiggle("boat", Vector3(0, sin(t * 1.4) * 0.015, 0), Vector3(sin(t * 1.4) * 0.04, 0, sin(t * 1.1) * 0.03))
		"hyakki":
			for i in 8:
				_wiggle("walker%d" % i, Vector3(0, absf(sin(t * 4.0 + i * 0.8)) * 0.05, 0))
		"kazoeuta":
			for k in 3:
				for side in [-1, 1]:
					_wiggle("arm%d_%d" % [k, side], Vector3.ZERO, Vector3(0, 0, side * sin(t * 3.0 + k * 1.2) * 0.25))
			for i in 2:
				_wiggle("note%d" % i, Vector3(0, sin(t * 2.0 + i * 2.0) * 0.05, 0))
		"mangetsu":
			_wiggle("tiny", Vector3(0, absf(sin(t * 2.2)) * 0.05, 0))
	for i in 3:
		_wiggle("fly%d" % i, Vector3(sin(t * 1.3 + i * 2.0) * 0.08, sin(t * 1.7 + i) * 0.06, cos(t * 1.1 + i) * 0.05))
