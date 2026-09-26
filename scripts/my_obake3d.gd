class_name MyObake3D
extends Obake3D
## マイおばけ猫（診断で決まる、自分だけの相棒）。
## 体と顔は Obake3D.ghost() / face()、持ち物の材質は prop()、形は _box() / _cyl() / _torus() をそのまま使う（体の作りが変わっても、ここは自動で追従する）。
## look = {color: "rrggbb", accessory: 持ち物, accent: "rrggbb" 持ち物の色, motion: しぐさ}
## 足元は y=0、高さ約 1.0（持ち物で少し高くなる）。正面は +Z。

const ACCESSORIES := [
	"scarf", "apron", "headband", "glasses", "headphones", "beret", "bow", "bandana",
	"towel", "cap", "flower", "bell", "star_pin", "leaf", "name_tag", "chef_hat",
]
const MOTIONS := ["bob", "sway", "hop", "wiggle", "bounce", "twirl", "nod", "scan", "float", "doze"]

var look := {}
var motion := "bob"
var col: Color
var accent: Color
var acc: Node3D


## 保存済みの診断結果から作る。結果が無ければ null。
static func from_saved() -> MyObake3D:
	var r := QuizResult.load_result()
	if r.is_empty():
		return null
	return MyObake3D.new().setup_look(r.look)


func setup_look(l: Dictionary) -> MyObake3D:
	look = l
	species = "my"
	col = Color(l.get("color", "ffffff"))
	accent = Color(l.get("accent", "e8505b"))
	motion = l.get("motion", "bob")
	body = Node3D.new()
	add_child(body)
	body.add_child(ghost(col, 1.0, 0.0, INK, motion == "doze"))
	acc = Node3D.new()
	acc.name = "Accessory"
	body.add_child(acc)
	var a: String = l.get("accessory", "")
	if has_method("_acc_" + a):
		call("_acc_" + a)
	bob = false # 揺れはしぐさごとに _process で付ける（まばたきは親に任せる）
	_t = randf() * TAU
	return self


## 撮影用：しぐさを止めて、正面寄りの落ち着いた姿勢にする
func hold_still() -> void:
	set_process(false)
	body.position = Vector3.ZERO
	body.rotation = Vector3.ZERO
	body.scale = Vector3.ONE
	for e in eyes:
		e.scale = EYE_SCALE


# ---------------------------------------------------------------- 部品

## 持ち物の材質。Obake3D.prop()（体と同じ光の当たり方）を使う。grow=0 は輪郭なし（細かい飾り用）。
func _m(c: Color, rim := 0.3, grow := 0.016) -> Material:
	if grow <= 0.0:
		return skin(c, 0.0, null, 0.06 + rim * 0.2, 0.0, false, 0.025)
	return prop(c, rim)


func _put(m: Mesh, c: Color, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE, grow := 0.016) -> MeshInstance3D:
	var mi := _mesh(m, _m(c, 0.3, grow), pos)
	mi.rotation = rot
	mi.scale = scl
	acc.add_child(mi)
	return mi


func _dome(r: float) -> SphereMesh:
	var s := _sphere(r)
	s.is_hemisphere = true
	s.height = r
	return s


# ---------------------------------------------------------------- 持ち物
# 頭は半径 0.5・中心 (0, 0.5, 0)。耳は (±0.27, 0.9)。目は (±0.17, 0.55, 0.46)。

func _acc_scarf() -> void:
	var ring := _put(_torus(0.47, 0.62), accent, Vector3(0, 0.4, 0), Vector3.ZERO, Vector3(1, 0.75, 1))
	ring.rotation.x = 0.08
	# 前に垂れる端
	_put(_box(Vector3(0.15, 0.34, 0.06)), accent, Vector3(0.2, 0.22, 0.54), Vector3(0.15, 0, 0.18))
	_put(_box(Vector3(0.15, 0.04, 0.065)), accent.lightened(0.45), Vector3(0.21, 0.12, 0.55), Vector3(0.15, 0, 0.18), Vector3.ONE, 0.0)


func _acc_apron() -> void:
	# 胴の丸みに沿うよう、細い板を弧に並べる
	for i in range(-2, 3):
		var a := i * 0.21
		_put(_box(Vector3(0.125, 0.36, 0.03)), accent, Vector3(sin(a) * 0.58, 0.23, cos(a) * 0.58), Vector3(0, a, 0), Vector3.ONE, 0.0)
	# 縁取り（輪郭）の代わりに、上下に細い帯
	_put(_box(Vector3(0.6, 0.035, 0.035)), accent.darkened(0.3), Vector3(0, 0.41, 0.575), Vector3.ZERO, Vector3.ONE, 0.0)
	# ポケット
	_put(_box(Vector3(0.2, 0.12, 0.02)), accent.lightened(0.25), Vector3(0, 0.19, 0.605), Vector3.ZERO, Vector3.ONE, 0.008)


func _acc_headband() -> void:
	_put(_torus(0.435, 0.5), accent, Vector3(0, 0.72, 0.0), Vector3(-0.18, 0, 0))
	# 後ろの結び目と、なびく端
	_put(_sphere(0.06), accent, Vector3(0, 0.7, -0.48))
	for sx in [-1.0, 1.0]:
		_put(_box(Vector3(0.07, 0.24, 0.03)), accent, Vector3(sx * 0.08, 0.6, -0.53), Vector3(0.4, 0, sx * 0.5))
	# 額の赤丸
	_put(_cyl(0.06, 0.06, 0.02), Color("e8505b"), Vector3(0, 0.79, 0.45), Vector3(PI / 2 - 0.4, 0, 0), Vector3.ONE, 0.0)


func _acc_glasses() -> void:
	for sx in [-1.0, 1.0]:
		_put(_torus(0.085, 0.115), accent, Vector3(sx * 0.17, 0.55, 0.53), Vector3(PI / 2, sx * 0.3, 0), Vector3.ONE, 0.0)
		# つる
		_put(_box(Vector3(0.022, 0.022, 0.16)), accent, Vector3(sx * 0.3, 0.57, 0.45), Vector3(0, sx * 0.75, 0), Vector3.ONE, 0.0)
	_put(_box(Vector3(0.1, 0.025, 0.025)), accent, Vector3(0, 0.575, 0.55), Vector3.ZERO, Vector3.ONE, 0.0)


func _acc_headphones() -> void:
	# バンドは耳のすぐ前を通って頭頂（y≈1.02）に乗る。耳先（x±0.33, y1.11）はバンドの上に出る。
	_put(_torus(0.5, 0.555), accent, Vector3(0, 0.53, 0.02), Vector3(PI / 2, 0, 0))
	for sx in [-1.0, 1.0]:
		_put(_cyl(0.14, 0.14, 0.11), accent, Vector3(sx * 0.545, 0.52, 0.0), Vector3(0, 0, PI / 2))
		_put(_cyl(0.1, 0.1, 0.02), Color("ff9e6b").lerp(accent, 0.2), Vector3(sx * 0.61, 0.52, 0.0), Vector3(0, 0, PI / 2), Vector3.ONE, 0.0)
	# マイク
	_put(_box(Vector3(0.025, 0.025, 0.34)), accent, Vector3(-0.5, 0.43, 0.17), Vector3(0.3, -0.35, 0), Vector3.ONE, 0.0)
	_put(_sphere(0.045), accent, Vector3(-0.43, 0.38, 0.33))


func _acc_beret() -> void:
	_put(_sphere(0.4), accent, Vector3(0.1, 0.95, -0.02), Vector3(0, 0, -0.3), Vector3(1, 0.32, 1))
	_put(_cyl(0.015, 0.03, 0.08, 8), accent, Vector3(0.16, 1.1, -0.02), Vector3(0, 0, -0.3))


func _acc_bow() -> void:
	var root := Node3D.new()
	root.position = Vector3(0.36, 0.86, 0.2)
	root.rotation = Vector3(0, 0.5, -0.35)
	acc.add_child(root)
	for sx in [-1.0, 1.0]:
		var wing := _mesh(_cyl(0.0, 0.12, 0.2, 16), _m(accent), Vector3(sx * 0.1, 0, 0))
		wing.rotation = Vector3(0, 0, sx * PI / 2)
		wing.scale = Vector3(1, 1, 0.55)
		root.add_child(wing)
	root.add_child(_mesh(_sphere(0.055), _m(accent.darkened(0.15)), Vector3.ZERO))


func _acc_bandana() -> void:
	# 頭を覆う布（半球を後ろに傾ける）。おでこは出して、耳は布から出る。
	var c := Vector3(0, 0.6, -0.04)
	_put(_dome(0.5), accent, c, Vector3(-0.5, 0, 0))
	# 水玉（布の表面に平たく貼る）
	for d in [Vector3(-0.45, 0.75, 0.5), Vector3(0.4, 0.8, 0.45), Vector3(0.0, 1.0, 0.15), Vector3(-0.2, 0.9, -0.35), Vector3(0.3, 0.85, -0.3), Vector3(0.75, 0.55, 0.1), Vector3(-0.75, 0.55, 0.1)]:
		var n: Vector3 = d.normalized()
		var dot := _put(_sphere(0.05), Color("fffaf2"), c + n * 0.505, Vector3.ZERO, Vector3.ONE, 0.0)
		dot.basis = Basis.looking_at(n).scaled_local(Vector3(1, 1, 0.3))
	# 後ろの結び目
	_put(_sphere(0.07), accent, Vector3(0, 0.6, -0.52))
	for sx in [-1.0, 1.0]:
		_put(_cyl(0.0, 0.07, 0.2, 10), accent, Vector3(sx * 0.1, 0.52, -0.56), Vector3(0.3, 0, sx * 2.4))


func _acc_towel() -> void:
	# 頭に乗せた手ぬぐい（温泉の人）。たたんだ厚みと、両端の縞。
	var rot := Vector3(0.12, 0, 0.1)
	_put(_box(Vector3(0.44, 0.12, 0.36)), accent.lightened(0.45), Vector3(0, 0.96, 0.04), rot)
	for z in [-0.1, 0.12]:
		_put(_box(Vector3(0.445, 0.125, 0.05)), accent, Vector3(0, 0.96, 0.04 + z), rot, Vector3.ONE, 0.0)


func _acc_cap() -> void:
	_put(_dome(0.515), accent, Vector3(0, 0.63, -0.02), Vector3(-0.15, 0, 0))
	# つば：前へ長めに張り出し、少し下を向ける（上から見下ろしても厚みが見えるように）
	var brim := _put(_cyl(0.3, 0.3, 0.04, 24), accent.darkened(0.12), Vector3(0, 0.72, 0.5), Vector3(0.3, 0, 0))
	brim.scale = Vector3(0.95, 1, 0.9)
	_put(_sphere(0.045), accent.darkened(0.15), Vector3(0, 1.14, -0.05))


func _acc_flower() -> void:
	var root := Node3D.new()
	root.position = Vector3(-0.36, 0.84, 0.28)
	root.rotation = Vector3(0, -0.55, 0.2)
	acc.add_child(root)
	for i in 5:
		var a := TAU * i / 5.0
		var p := _mesh(_sphere(0.075), _m(accent, 0.3, 0.01), Vector3(cos(a) * 0.08, sin(a) * 0.08, 0))
		p.scale = Vector3(1, 1, 0.45)
		root.add_child(p)
	root.add_child(_mesh(_sphere(0.05), _m(Color("ffd23f"), 0.3, 0.01), Vector3(0, 0, 0.03)))


func _acc_bell() -> void:
	# 首輪と鈴
	_put(_torus(0.5, 0.565), accent, Vector3(0, 0.32, 0), Vector3(0.08, 0, 0), Vector3(1, 0.8, 1))
	var bell_col := Color("ffd23f")
	_put(_sphere(0.085), bell_col, Vector3(0, 0.22, 0.6))
	_put(_box(Vector3(0.1, 0.012, 0.02)), INK, Vector3(0, 0.17, 0.675), Vector3.ZERO, Vector3.ONE, 0.0)
	_put(_sphere(0.016), INK, Vector3(0, 0.145, 0.67), Vector3.ZERO, Vector3.ONE, 0.0)


func _acc_star_pin() -> void:
	var root := Node3D.new()
	root.position = Vector3(0.22, 0.3, 0.53)
	root.rotation = Vector3(0, 0.4, 0)
	acc.add_child(root)
	for i in 5:
		var a := TAU * i / 5.0 + PI / 2
		var ray := _mesh(_cyl(0.0, 0.05, 0.12, 8), _m(accent, 0.4, 0.008), Vector3(cos(a) * 0.06, sin(a) * 0.06, 0))
		ray.rotation.z = a - PI / 2
		ray.scale = Vector3(1, 1, 0.45)
		root.add_child(ray)
	var c := _mesh(_sphere(0.055), _m(accent, 0.4, 0.008), Vector3.ZERO)
	c.scale = Vector3(1, 1, 0.5)
	root.add_child(c)


func _acc_leaf() -> void:
	# 頭にちょこんと乗った葉っぱ（前から見えるよう少し手前に傾ける）
	var rot := Vector3(0.55, 0.5, 0.3)
	_put(_sphere(0.22), accent, Vector3(0.04, 1.02, 0.06), rot, Vector3(0.5, 0.1, 1.0))
	_put(_box(Vector3(0.02, 0.012, 0.36)), accent.darkened(0.35), Vector3(0.04, 1.035, 0.07), rot, Vector3.ONE, 0.0)
	_put(_cyl(0.014, 0.014, 0.12, 6), accent.darkened(0.35), Vector3(0.14, 1.12, -0.14), Vector3(0.9, 0.5, 0), Vector3.ONE, 0.0)


func _acc_name_tag() -> void:
	var root := Node3D.new()
	root.position = Vector3(-0.2, 0.28, 0.52)
	root.rotation = Vector3(0, -0.36, 0.08)
	acc.add_child(root)
	root.add_child(_mesh(_box(Vector3(0.26, 0.15, 0.03)), _m(Color("fffaf2"), 0.2, 0.01), Vector3.ZERO))
	root.add_child(_mesh(_box(Vector3(0.262, 0.045, 0.034)), _m(accent, 0.2, 0.0), Vector3(0, 0.05, 0)))
	# 名前のかわりの線
	root.add_child(_mesh(_box(Vector3(0.15, 0.018, 0.034)), _m(INK, 0.0, 0.0), Vector3(0, -0.02, 0.002)))


func _acc_chef_hat() -> void:
	_put(_cyl(0.25, 0.27, 0.22, 24), accent, Vector3(0, 1.02, 0), Vector3(-0.05, 0, 0))
	for p in [Vector3(-0.14, 1.2, 0.0), Vector3(0.14, 1.2, 0.0), Vector3(0.0, 1.24, 0.05), Vector3(0.0, 1.22, -0.1)]:
		_put(_sphere(0.17), accent, p)


# ---------------------------------------------------------------- しぐさ

func _process(delta: float) -> void:
	super(delta)
	var t := _t
	var p := Vector3.ZERO
	var r := Vector3.ZERO
	var s := Vector3.ONE
	match motion:
		"sway": # ゆらゆら
			r.z = sin(t * 1.6) * 0.14
			p.y = sin(t * 3.2) * 0.03
		"hop": # ぴょこぴょこ跳ねる
			var h := absf(sin(t * 3.2))
			p.y = h * 0.16
			s = Vector3(1.0 + (1.0 - h) * 0.06, 1.0 - (1.0 - h) * 0.06, 1.0 + (1.0 - h) * 0.06)
		"wiggle": # 小刻みに左右へ（何かを混ぜる・洗う手つき）
			r.y = sin(t * 9.0) * 0.12 * (0.5 + 0.5 * sin(t * 1.3))
			p.y = sin(t * 2.0) * 0.04
		"bounce": # 弾むように上下
			var b := sin(t * 5.0)
			p.y = absf(b) * 0.07
			s = Vector3(1.0 - b * 0.03, 1.0 + b * 0.03, 1.0 - b * 0.03)
		"twirl": # ときどきくるっと回る
			var ph := fmod(t, 4.5)
			if ph < 0.9:
				r.y = ease(ph / 0.9, -2.0) * TAU
				p.y = sin(ph / 0.9 * PI) * 0.12
			else:
				p.y = sin(t * 2.0) * 0.04
		"nod": # うんうん、とうなずく
			r.x = maxf(0.0, sin(t * 2.4)) * 0.18
			p.y = sin(t * 2.0) * 0.03
		"scan": # あたりを見回す
			r.y = sin(t * 0.9) * 0.55
			p.y = sin(t * 2.0) * 0.04
		"float": # ふわーっと浮く
			p.y = sin(t * 1.2) * 0.12 + 0.05
			r.z = sin(t * 0.8) * 0.06
		"doze": # うとうと舟をこぐ
			r.z = 0.12 + sin(t * 0.8) * 0.05
			r.x = maxf(0.0, sin(t * 0.8)) * 0.12
			s = Vector3.ONE * (1.0 + sin(t * 1.6) * 0.02)
		_: # bob：ふつうのおばけと同じ揺れ
			p.y = sin(t * 2.0) * 0.06
			r.y = sin(t * 0.7) * 0.25
			s = Vector3(1.0 + sin(t * 4.0) * 0.015, 1.0 - sin(t * 4.0) * 0.015, 1.0)
	body.position = p
	body.rotation = r
	body.scale = s
