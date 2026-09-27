class_name TitleFx
extends Control
## タイトルの空気（GL Compatibility・Web で軽い 2D の重ね描き）。加算で描くので、光らせすぎない薄さで。
##   back：低い太陽から空へ広がる光の筋（3D の絵のうしろ、空の上）
##   front：水平線のもや、島のまわりの光の粒、水面のきらめき、灯りのにじみ（3D の絵の上）
## 置き場所は持ち主（screen_title_v2.gd）が毎フレーム渡す。strength は出だしの演出で 0→1。

var layer := "front"
var frame := Rect2(0, 0, 360, 640)
var horizon := 0.38
var sun := Vector2(270, 230) # 太陽（キャンバスの座標）
var halos: Array = [] # [[位置, 半径, 強さ], ...]
var avoid := Rect2() # 光の粒を置かない場所（猫の体。体に点が乗って汚れに見えないように）
var shafts := 0.0 # 光の筋の強さ 0..1
var motes := 0.0 # 光の粒の強さ 0..1
var t := 0.0

var _dot: GradientTexture2D
var _seeds: Array = []
var _glints: Array = []

const WARM := Color(1.0, 0.82, 0.62)


func _init(which := "front") -> void:
	layer = which
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = add
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.45))
	_dot = GradientTexture2D.new()
	_dot.gradient = g
	_dot.fill = GradientTexture2D.FILL_RADIAL
	_dot.fill_from = Vector2(0.5, 0.5)
	_dot.fill_to = Vector2(1.0, 0.5)
	_dot.width = 64
	_dot.height = 64
	var r := RandomNumberGenerator.new()
	r.seed = 7
	for i in 32: # 光の粒：島のまわり（枠の割合）、ゆっくり漂う
		_seeds.append([r.randf_range(0.0, 0.58), r.randf_range(0.46, 0.8), r.randf_range(1.2, 2.6), r.randf() * TAU, r.randf_range(0.15, 0.4)])
	for i in 14: # 水面のきらめき：夕日の道のあたり
		_glints.append([r.randf_range(0.56, 0.96), r.randf_range(0.46, 0.64), r.randf() * TAU, r.randf_range(0.6, 1.3)])


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if layer == "back":
		_draw_shafts()
	else:
		_draw_haze()
		_draw_glints()
		_draw_motes()
		_draw_halos()


## 太陽から空へ扇に広がる、先で消える薄い筋。ゆっくり息をする
func _draw_shafts() -> void:
	if shafts <= 0.01:
		return
	# 筋は 4 本だけ、ふちはぼかす（まん中の線だけ色があり、両脇へ消える）。先ほど薄く
	var len := frame.size.y * 0.8
	var rays := [[-158.0, 9.0, 0.8], [-128.0, 6.0, 1.0], [-96.0, 8.0, 0.7], [-50.0, 7.0, 0.6]]
	for i in rays.size():
		var rr: Array = rays[i]
		var a := deg_to_rad(rr[0] + sin(t * 0.11 + i) * 1.5)
		var w := deg_to_rad(rr[1])
		var k: float = shafts * rr[2] * (0.7 + 0.3 * sin(t * 0.35 + i * 1.7))
		var mid := Color(WARM, 0.055 * k)
		var clear := Color(WARM, 0.0)
		var d0 := Vector2(cos(a), sin(a))
		var pl := sun + Vector2(cos(a - w), sin(a - w)) * len
		var pc := sun + d0 * len * 0.55
		var pr := sun + Vector2(cos(a + w), sin(a + w)) * len
		var pe := sun + d0 * len
		draw_polygon(PackedVector2Array([sun, pl, pc]), PackedColorArray([mid, clear, Color(WARM, 0.03 * k)]))
		draw_polygon(PackedVector2Array([sun, pc, pr]), PackedColorArray([mid, Color(WARM, 0.03 * k), clear]))
		draw_polygon(PackedVector2Array([pc, pl, pe, pr]), PackedColorArray([Color(WARM, 0.03 * k), clear, clear, clear]))


## 水平線のすぐ上下に、暖かいもやの帯（遠くの島にも少し掛かる）
func _draw_haze() -> void:
	var y := frame.position.y + horizon * frame.size.y
	var h := frame.size.y
	var x0 := 0.0
	var x1 := size.x
	var top := Color(WARM, 0.0)
	var mid := Color(WARM, 0.13)
	var low := Color(WARM, 0.0)
	draw_polygon(PackedVector2Array([Vector2(x0, y - h * 0.05), Vector2(x1, y - h * 0.05), Vector2(x1, y + h * 0.008), Vector2(x0, y + h * 0.008)]),
		PackedColorArray([top, top, mid, mid]))
	draw_polygon(PackedVector2Array([Vector2(x0, y + h * 0.008), Vector2(x1, y + h * 0.008), Vector2(x1, y + h * 0.075), Vector2(x0, y + h * 0.075)]),
		PackedColorArray([mid, mid, low, low]))


func _at(fx: float, fy: float) -> Vector2:
	return frame.position + Vector2(fx * frame.size.x, fy * frame.size.y)


## 光の粒：ふわふわ漂い、ゆっくり明滅
func _draw_motes() -> void:
	if motes <= 0.01:
		return
	for s in _seeds:
		var p := _at(s[0] + sin(t * 0.11 * s[2] + s[3]) * 0.03, s[1] + sin(t * 0.07 * s[2] + s[3] * 1.3) * 0.02 - fmod(t * 0.002 * s[2], 0.04))
		if avoid.grow(6.0).has_point(p):
			continue
		var tw := 0.5 + 0.5 * sin(t * s[2] + s[3])
		var r: float = (1.4 + s[2] * 0.7) * frame.size.x / 360.0
		var c := Color(1.0, 0.84, 0.5, motes * s[4] * 0.8 * (0.3 + 0.7 * tw))
		draw_texture_rect(_dot, Rect2(p - Vector2(r, r) * 2.0, Vector2(r, r) * 4.0), false, c)


## 水面のきらめき：ときどき、ちかっと
func _draw_glints() -> void:
	var u := frame.size.x / 360.0
	for g in _glints:
		var k := pow(maxf(sin(t * g[3] + g[2]), 0.0), 14.0)
		if k < 0.02:
			continue
		var p := _at(g[0], g[1])
		var c := Color(1.0, 0.95, 0.85, 0.55 * k)
		draw_rect(Rect2(p - Vector2(5, 0.5) * u, Vector2(10, 1) * u), c)
		draw_rect(Rect2(p - Vector2(0.5, 3) * u, Vector2(1, 6) * u), Color(c, c.a * 0.7))
		draw_texture_rect(_dot, Rect2(p - Vector2(4, 4) * u, Vector2(8, 8) * u), false, c)


## 灯りのにじみ（光らせる代わりの、やわらかい丸）
func _draw_halos() -> void:
	for h in halos:
		var p: Vector2 = h[0]
		var r: float = h[1] * (1.0 + 0.06 * sin(t * 2.1 + p.x))
		draw_texture_rect(_dot, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, Color(1.0, 0.78, 0.5, h[2]))
