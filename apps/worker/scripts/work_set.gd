class_name WorkSet
extends RefCounted
## 猫の仕事場（いっしょに働く画面）のセット：床・壁・窓・棚・灯り・時計と、仕事ごとの台。
## 動かない部品は種類（輪郭つき・輪郭なし・光る・足元の影・日だまり）ごとに 1 つのメッシュへ頂点色でまとめ、
## Web で描く回数を増やさない。床ぎわ・壁ぎわ・天井ぎわは頂点色で少し暗くして、置いてある感じ（AO）を出す。
##   var ws := WorkSet.new()
##   ws.build(parent, "register", WorkSet.night_amount(GameState.now_real()), tray_pos)
##   WorkSet.grade(Look.apply(world, "room", ...), n)   # 光：暖かいキー・やわらかいフィル・猫の縁の光
## night は 0 昼 / 0.5 夕方 / 1 夜。夕方・夜は窓の外が暮れて、吊りランプが主役になる。

const WALL_Z := -1.7
const WALL_F := WALL_Z + 0.06 # 壁の表の面
const LINE := Color("4a3226")
const WOOD := Color("b97f52")
const WOOD_D := Color("7d5236")
const WOOD_L := Color("dcb487")
const CREAM := Color("f3e3cc")
const STEEL := Color("b9c3cc")
const STEEL_D := Color("7f8a96")
const LEAF := Color("6fb86a")
const LEAF_D := Color("4c9457")

## 仕事ごとの壁・腰壁・床の色（白っぽくしない：パステルでも少し濃いめ）
const ROOMS := {
	"register": {"wall": Color("f3cba8"), "wall_top": Color("e3ad8c"), "wain": Color("7fae98"), "trim": Color("5a8b76"), "floor": [Color("cfa684"), Color("bf9574"), Color("d9b592")]},
	"hall": {"wall": Color("e9ad9f"), "wall_top": Color("d28f86"), "wain": Color("7aa3b8"), "trim": Color("56809a"), "floor": [Color("cfa684"), Color("bf9574"), Color("d9b592")], "stripes": Color("dd9d90")},
	"kitchen": {"wall": Color("f0c49a"), "wall_top": Color("d9a079"), "tile": Color("9fd3c7"), "grout": Color("7fb8ab"), "trim": Color("5f9b8e"), "floor": [Color("c9a27e"), Color("a9825f"), Color("c9a27e")]},
	"dish": {"wall": Color("e8c29c"), "wall_top": Color("cf9f7e"), "tile": Color("a3c4ea"), "grout": Color("809fcb"), "trim": Color("5f7fae"), "floor": [Color("c9a27e"), Color("a9825f"), Color("c9a27e")]},
	"stock": {"wall": Color("a9b7c4"), "wall_top": Color("8d9bab"), "brick": Color("a3b3c3"), "wain": Color("8a9aa8"), "trim": Color("6b7b8a"), "floor": [Color("b58c66"), Color("a27a56"), Color("bd9670")]},
}

var solid: Batch # 輪郭つき（家具・小物）
var flat: Batch # 輪郭なし（床板・壁・タイルの目地など平らなもの）
var lit: Batch # 自分で光る（窓の外・電球・画面）
var blobs: Batch # 足元のぼんやりした影
var sun: Batch # 窓からの日だまり（足し算）
var hands: Array[Node3D] = [] # 時計の針（時・分）
var lamps: Array[OmniLight3D] = []
var night := 0.0
var _root: Node3D


# ---------------------------------------------------------------- まとめ描き

class Batch:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()

	## mesh を xf で置いて足す。top を渡すと、下の色 col → 上の色 top のグラデーション。ao: 0 なし / 1 床と壁ぎわ / 2 床（壁ぎわだけ）
	func add(mesh: Mesh, xf: Transform3D, col: Color, top = null, ao := 1) -> void:
		var arr: Array = mesh.surface_get_arrays(0)
		var mv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var mn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var muv = arr[Mesh.ARRAY_TEX_UV]
		var mi = arr[Mesh.ARRAY_INDEX]
		var box := mesh.get_aabb()
		var base := v.size()
		var nb := xf.basis.inverse().transposed()
		for i in mv.size():
			var p := xf * mv[i]
			v.append(p)
			n.append((nb * mn[i]).normalized())
			var k := col
			if top != null:
				k = col.lerp(top, clampf((mv[i].y - box.position.y) / maxf(box.size.y, 0.0001), 0.0, 1.0))
			if ao > 0:
				k = WorkSet.ao(p, k, ao == 2)
			c.append(k)
			uv.append(muv[i] if muv != null and i < muv.size() else Vector2.ZERO)
		if mi == null or mi.is_empty():
			for i in mv.size():
				idx.append(base + i)
		else:
			for i in mi:
				idx.append(base + i)

	func commit(parent: Node3D, mat: Material, shadows := true) -> MeshInstance3D:
		if v.is_empty():
			return null
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var mi := MeshInstance3D.new()
		mi.mesh = am
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		return mi


## 焼いた AO：床ぎわ・壁ぎわ・天井ぎわほど暗く（色は sRGB のまま掛ける）
static func ao(p: Vector3, col: Color, floor_only := false) -> Color:
	var k := 1.0
	if not floor_only:
		k *= lerpf(0.68, 1.0, smoothstep(0.0, 0.42, p.y))
		k *= lerpf(0.84, 1.0, 1.0 - smoothstep(2.4, 3.4, p.y))
	k *= lerpf(0.72 if floor_only else 0.86, 1.0, smoothstep(0.0, 0.55 if floor_only else 0.3, p.z - WALL_F))
	return Color(col.r * k, col.g * k, col.b * k, col.a)


static var _meshes := {}


static func _cube() -> BoxMesh:
	if not _meshes.has("cube"):
		var b := BoxMesh.new()
		b.size = Vector3.ONE
		_meshes["cube"] = b
	return _meshes["cube"]


static func _plane() -> PlaneMesh:
	if not _meshes.has("plane"):
		var p := PlaneMesh.new()
		p.size = Vector2.ONE
		_meshes["plane"] = p
	return _meshes["plane"]


static func _sphere(seg: int) -> SphereMesh:
	var key := "sph%d" % seg
	if not _meshes.has(key):
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = seg
		s.rings = maxi(seg / 2, 4)
		_meshes[key] = s
	return _meshes[key]


static func _prism() -> PrismMesh:
	if not _meshes.has("prism"):
		var p := PrismMesh.new()
		p.size = Vector3.ONE
		_meshes["prism"] = p
	return _meshes["prism"]


static func _xf(pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot).scaled_local(scl), pos)


## 角の丸い箱（輪郭つき）
func box(size: Vector3, pos: Vector3, col: Color, rot := Vector3.ZERO, top = null, bevel := -1.0) -> void:
	if bevel < 0.0:
		bevel = clampf(minf(size.x, minf(size.y, size.z)) * 0.2, 0.004, 0.035)
	solid.add(Obake3D.rbox(size, bevel), _xf(pos, rot), col, top)


## 平らな箱（輪郭なし。壁・床板・目地など）
func slab(size: Vector3, pos: Vector3, col: Color, top = null, ao_kind := 1, rot := Vector3.ZERO) -> void:
	flat.add(_cube(), _xf(pos, rot, size), col, top, ao_kind)


func cyl(top_r: float, bottom_r: float, h: float, pos: Vector3, col: Color, rot := Vector3.ZERO, seg := 20) -> void:
	solid.add(Obake3D.lathe(top_r, bottom_r, h, seg, minf(minf(maxf(top_r, bottom_r), h) * 0.22, 0.02)), _xf(pos, rot), col)


func ball(r: float, pos: Vector3, col: Color, scl := Vector3.ONE, seg := 14, into: Batch = null) -> void:
	(into if into else solid).add(_sphere(seg), _xf(pos, Vector3.ZERO, scl * r * 2.0), col, null, 0 if into == lit else 1)


func glow_box(size: Vector3, pos: Vector3, col: Color, top = null, rot := Vector3.ZERO) -> void:
	lit.add(_cube(), _xf(pos, rot, size), col, top, 0)


## 足元のぼんやりした影（横 w × 奥 d）
func blob(x: float, z: float, w: float, d: float, a := 0.4) -> void:
	blobs.add(_plane(), _xf(Vector3(x, 0.006, z), Vector3.ZERO, Vector3(w, 1, d)), Color(1, 1, 1, a), null, 0)


# ---------------------------------------------------------------- 時刻

## いまが昼（0）・夕方（0.5）・夜（1）のどこか。t は unix 秒（GameState.now_real）
static func night_amount(t: float) -> float:
	var d := Time.get_datetime_dict_from_unix_time(int(t + Time.get_time_zone_from_system().get("bias", 0) * 60.0))
	var h: float = d.hour + d.minute / 60.0
	if h >= 6.5 and h < 16.0:
		return 0.0
	if h >= 16.0 and h < 18.0:
		return (h - 16.0) / 2.0 * 0.5
	if h >= 18.0 and h < 19.5:
		return 0.5 + (h - 18.0) / 1.5 * 0.5
	if h >= 5.5 and h < 6.5:
		return 1.0 - (h - 5.5)
	return 1.0


static func _tod(day: Color, eve: Color, nite: Color, n: float) -> Color:
	return day.lerp(eve, clampf(n * 2.0, 0.0, 1.0)).lerp(nite, clampf(n * 2.0 - 1.0, 0.0, 1.0))


## 光と空気。Look.apply(…"room"…) の返り値を、この部屋用に締める（露出を下げ、コントラストを上げ、暖かいキーと猫の縁の光）
static func grade(rig: Dictionary, n: float) -> void:
	var env: Environment = rig.env
	env.background_color = _tod(Color("5a3f3c"), Color("4a3040"), Color("1f1a33"), n)
	env.ambient_light_color = _tod(Color("f4ded0"), Color("e8c0b8"), Color("8c7fc0"), n)
	env.ambient_light_energy = lerpf(0.3, 0.26, n)
	env.tonemap_exposure = lerpf(0.86, 0.84, n)
	env.adjustment_contrast = 1.14
	env.adjustment_saturation = 1.1
	# 奥の壁だけ、少し空気でかすませる（猫と台の手前はそのまま）。白ではなく部屋の色で
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = _tod(Color("a88a86"), Color("9a7486"), Color("2e2850"), n)
	env.fog_light_energy = 1.0
	env.fog_density = 0.12
	env.fog_depth_begin = 4.6
	env.fog_depth_end = 8.5
	env.fog_depth_curve = 1.0
	env.fog_sky_affect = 0.0
	var key: DirectionalLight3D = rig.key
	key.rotation_degrees = Vector3(-38, -32, 0) # 窓（左奥）の側から
	key.light_color = _tod(Color("ffe9cc"), Color("ffc090"), Color("8f9fe6"), n)
	key.light_energy = lerpf(0.62, 0.3, n)
	key.shadow_enabled = true
	key.shadow_opacity = 0.75
	key.shadow_blur = 1.5
	var fill: DirectionalLight3D = rig.fill
	fill.rotation_degrees = Vector3(-12, 140, 0)
	fill.light_color = _tod(Color("aebcff"), Color("b59cff"), Color("ffc890"), n)
	fill.light_energy = lerpf(0.26, 0.34, n)
	var rim: DirectionalLight3D = rig.rim
	rim.rotation_degrees = Vector3(-24, 172, 0)
	rim.light_color = _tod(Color("ffe2b8"), Color("ffc088"), Color("ffcf8a"), n)
	rim.light_energy = lerpf(0.9, 1.05, n)


## 時計の針を合わせる（t は unix 秒）
func set_time(t: float) -> void:
	if hands.size() < 2:
		return
	var d := Time.get_datetime_dict_from_unix_time(int(t + Time.get_time_zone_from_system().get("bias", 0) * 60.0))
	var m: float = d.minute + d.second / 60.0
	hands[0].rotation.z = -TAU * (fmod(float(d.hour), 12.0) + m / 60.0) / 12.0
	hands[1].rotation.z = -TAU * m / 60.0


# ---------------------------------------------------------------- 組み立て

func build(parent: Node3D, role: String, n: float, tray_pos: Vector3) -> Node3D:
	night = n
	if _root and is_instance_valid(_root):
		_root.queue_free()
	_root = Node3D.new()
	_root.name = "WorkSet"
	parent.add_child(_root)
	solid = Batch.new()
	flat = Batch.new()
	lit = Batch.new()
	blobs = Batch.new()
	sun = Batch.new()
	hands.clear()
	lamps.clear()
	var room: Dictionary = ROOMS.get(role, ROOMS.register)
	_shell(room, role)
	_window(Vector3(-1.0, 1.66, WALL_F), role)
	match role:
		"register":
			_register()
		"hall":
			_hall()
		"kitchen":
			_kitchen()
		"dish":
			_dish()
		_:
			_stock()
	_stool(tray_pos)
	_commit()
	return _root


func _commit() -> void:
	var line := ShaderMaterial.new()
	line.shader = Obake3D.OUTLINE_SHADER
	line.set_shader_parameter("color", LINE)
	line.set_shader_parameter("width", 0.0045)
	solid.commit(_root, _solid_mat(line))
	flat.commit(_root, _solid_mat(null), false)
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.vertex_color_use_as_albedo = true
	lm.vertex_color_is_srgb = true
	lit.commit(_root, lm, false)
	blobs.commit(_root, _soft_mat(Color(0.24, 0.12, 0.1), GradientTexture2D.FILL_RADIAL, BaseMaterial3D.BLEND_MODE_MIX), false)
	sun.commit(_root, _soft_mat(Color(1, 1, 1), GradientTexture2D.FILL_SQUARE, BaseMaterial3D.BLEND_MODE_ADD), false)


static func _solid_mat(line: Material) -> ShaderMaterial:
	var m := Obake3D.skin(Color.WHITE, 0.0, null, 0.08, 0.0, false, 0.02).duplicate() as ShaderMaterial
	m.set_shader_parameter("vertex_albedo", 1.0)
	m.set_shader_parameter("top_light", 0.05)
	m.next_pass = line
	return m


static func _soft_mat(col: Color, fill: int, blend: int) -> StandardMaterial3D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.75))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = fill
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = blend
	m.albedo_color = col
	m.albedo_texture = t
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m


## 床・壁・腰壁・天井の梁・旗飾り
func _shell(room: Dictionary, role: String) -> void:
	# 床板（手前へのびる板。3 色を混ぜ、壁ぎわほど暗く）
	var fl: Array = room.floor
	var tiles := role in ["kitchen", "dish"]
	for i in 18:
		var x := -2.55 + i * 0.3
		if tiles:
			for j in 12:
				var z := WALL_F + 0.15 + j * 0.3
				slab(Vector3(0.29, 0.1, 0.29), Vector3(x, -0.05, z), fl[(i + j) % 2], null, 2)
		else:
			slab(Vector3(0.285, 0.1, 5.4), Vector3(x, -0.05, WALL_F + 2.7), fl[(i * 7) % 3], null, 2)
	slab(Vector3(5.6, 0.09, 5.4), Vector3(0, -0.06, WALL_F + 2.7), Color("5e3d2c"), null, 2) # 板の目地
	# 奥の壁：上ほど少し濃く（天井の暗さ）
	slab(Vector3(5.6, 3.8, 0.12), Vector3(0, 1.9, WALL_Z), room.wall, room.wall_top, 1)
	if room.has("stripes"):
		for i in 14:
			slab(Vector3(0.12, 2.6, 0.01), Vector3(-2.6 + i * 0.4, 2.3, WALL_F + 0.004), room.stripes, room.wall_top.lerp(room.stripes, 0.5), 1)
	if room.has("brick"):
		for r in 12:
			for i in 12:
				var bx := -2.7 + i * 0.46 + (0.23 if r % 2 == 1 else 0.0)
				slab(Vector3(0.42, 0.16, 0.012), Vector3(bx, 1.02 + r * 0.2, WALL_F + 0.005), (room.brick as Color).lerp(room.wall_top, float((r * 5 + i * 3) % 4) * 0.12), null, 1)
	if room.has("tile"):
		# タイルの腰壁（目地つき）
		slab(Vector3(5.6, 1.5, 0.02), Vector3(0, 0.75, WALL_F + 0.01), room.grout, null, 1)
		for r in 7:
			for i in 26:
				slab(Vector3(0.2, 0.19, 0.02), Vector3(-2.6 + i * 0.21, 0.11 + r * 0.21, WALL_F + 0.022), (room.tile as Color).lerp(Color.WHITE, 0.12 if (r + i) % 3 == 0 else 0.0), null, 1)
		box(Vector3(5.6, 0.06, 0.08), Vector3(0, 1.52, WALL_F + 0.04), room.trim)
	else:
		# 羽目板の腰壁と、見切りの細い木
		slab(Vector3(5.6, 0.95, 0.03), Vector3(0, 0.475, WALL_F + 0.015), room.wain, null, 1)
		for i in 28:
			slab(Vector3(0.018, 0.86, 0.01), Vector3(-2.7 + i * 0.2, 0.47, WALL_F + 0.034), (room.trim as Color).lerp(room.wain, 0.4), null, 1)
		box(Vector3(5.6, 0.07, 0.07), Vector3(0, 0.97, WALL_F + 0.04), room.trim)
	box(Vector3(5.6, 0.12, 0.06), Vector3(0, 0.06, WALL_F + 0.03), WOOD_D) # 幅木
	# 天井の梁と、旗飾り
	box(Vector3(5.6, 0.22, 0.3), Vector3(0, 3.05, WALL_Z + 0.3), WOOD_D)
	var flags := [Color("ff8f7a"), Color("ffd166"), Color("7cc6a4"), Color("8fa8ff"), Color("f7a8c8")]
	for i in 15:
		var x := -2.1 + i * 0.3
		var sag := 0.14 * (1.0 - pow((x - 0.0) / 2.2, 2.0))
		var y := 2.86 - sag
		solid.add(_prism(), _xf(Vector3(x, y - 0.1, WALL_F + 0.35), Vector3(0, 0, PI), Vector3(0.2, 0.2, 0.02)), flags[i % flags.size()])
	for i in 14:
		var x0 := -2.1 + i * 0.3
		var y0 := 2.86 - 0.14 * (1.0 - pow(x0 / 2.2, 2.0))
		var y1 := 2.86 - 0.14 * (1.0 - pow((x0 + 0.3) / 2.2, 2.0))
		slab(Vector3(0.3, 0.012, 0.012), Vector3(x0 + 0.15, (y0 + y1) * 0.5 + 0.0, WALL_F + 0.35), Color("5e4636"), null, 0, Vector3(0, 0, atan2(y1 - y0, 0.3)))
	# 壁の時計（実際の時刻）
	_clock(Vector3(-0.1, 2.42, WALL_F))
	# 吊りランプ 2 つ
	_pendant(Vector3(-0.45, 2.3, -0.7))
	_pendant(Vector3(1.05, 2.3, -0.85))
	# 左の奥の鉢植え
	_plant(Vector3(-1.55, 0, WALL_Z + 0.45), 1.15)


func _clock(p: Vector3) -> void:
	cyl(0.2, 0.2, 0.05, p + Vector3(0, 0, 0.03), WOOD_D, Vector3(PI / 2, 0, 0), 28)
	cyl(0.17, 0.17, 0.02, p + Vector3(0, 0, 0.065), CREAM, Vector3(PI / 2, 0, 0), 28)
	for i in 12:
		var a := TAU * i / 12.0
		slab(Vector3(0.012, 0.035 if i % 3 == 0 else 0.018, 0.005), p + Vector3(sin(a) * 0.14, cos(a) * 0.14, 0.078), Color("5e4636"), null, 0, Vector3(0, 0, -a))
	for k in 2:
		var pivot := Node3D.new()
		pivot.position = p + Vector3(0, 0, 0.082 + k * 0.004)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.018, 0.09 if k == 0 else 0.13, 0.006)
		mi.mesh = bm
		mi.position = Vector3(0, bm.size.y * 0.4, 0)
		mi.material_override = Obake3D.flat(Color("3a2a2e"))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mi)
		_root.add_child(pivot)
		hands.append(pivot)
	ball(0.014, p + Vector3(0, 0, 0.09), Color("e8575b"))


func _pendant(p: Vector3) -> void:
	cyl(0.008, 0.008, 3.6 - p.y, p + Vector3(0, (3.6 - p.y) * 0.5 + 0.08, 0), Color("3a2a2e"), Vector3.ZERO, 6)
	cyl(0.05, 0.2, 0.17, p, Color("2f5d5a").lerp(Color("e0a060"), 0.0 if p.x < 0.0 else 1.0), Vector3.ZERO, 24)
	ball(0.065, p + Vector3(0, -0.08, 0), _tod(Color("fff0c8"), Color("ffe0a0"), Color("ffd98a"), night), Vector3(1, 0.85, 1), 12, lit)
	var l := OmniLight3D.new()
	l.light_color = Color("ffc98a")
	l.light_energy = lerpf(0.18, 1.3, night)
	l.omni_range = lerpf(2.6, 3.4, night)
	l.omni_attenuation = 1.4
	l.position = p + Vector3(0, -0.25, 0.1)
	_root.add_child(l)
	lamps.append(l)


func _plant(p: Vector3, s := 1.0) -> void:
	cyl(0.2 * s, 0.15 * s, 0.34 * s, p + Vector3(0, 0.17 * s, 0), Color("d9825e"), Vector3.ZERO, 20)
	cyl(0.215 * s, 0.215 * s, 0.05 * s, p + Vector3(0, 0.34 * s, 0), Color("e8966f"), Vector3.ZERO, 20)
	var leaves := [Vector3(0, 0.62, 0), Vector3(-0.16, 0.5, 0.05), Vector3(0.17, 0.52, 0.04), Vector3(0.05, 0.8, -0.02), Vector3(-0.1, 0.74, 0.1), Vector3(0.14, 0.72, 0.08)]
	for i in leaves.size():
		ball(0.14 * s, p + leaves[i] * s, LEAF if i % 2 == 0 else LEAF_D, Vector3(1, 0.8, 1))
	blob(p.x, p.z + 0.05, 0.7 * s, 0.5 * s, 0.45)


## 窓：外の空は時刻で変わる（昼の青空・夕焼け・夜空と月）。カーテンと出窓の鉢
func _window(c: Vector3, role: String) -> void:
	var w := 0.95
	var h := 1.05
	var sky_top := _tod(Color("7fc0ee"), Color("f08a78"), Color("1c2250"), night)
	var sky_bot := _tod(Color("cfeaf6"), Color("ffcf8f"), Color("3b3c78"), night)
	glow_box(Vector3(w, h, 0.01), c + Vector3(0, 0, 0.005), sky_bot, sky_top)
	# 外の街（屋根のシルエット）
	var town := _tod(Color("9fb8d0"), Color("c0708a"), Color("262a5a"), night)
	var roofs := [[-0.33, 0.22, 0.26], [-0.08, 0.3, 0.2], [0.14, 0.18, 0.24], [0.34, 0.26, 0.2]]
	for r in roofs:
		glow_box(Vector3(r[2], r[1], 0.01), c + Vector3(r[0], -h * 0.5 + r[1] * 0.5, 0.012), town)
		if night > 0.6:
			glow_box(Vector3(0.04, 0.04, 0.01), c + Vector3(r[0] + 0.03, -h * 0.5 + r[1] * 0.55, 0.018), Color("ffd98a"))
	if night < 0.6:
		for cl in [[-0.2, 0.28, 0.16], [0.22, 0.16, 0.12]]:
			ball(1.0, c + Vector3(cl[0], cl[1], 0.02), _tod(Color("ffffff"), Color("ffd0b0"), Color("ffffff"), night), Vector3(cl[2], cl[2] * 0.4, 0.01), 12, lit)
	else:
		ball(0.07, c + Vector3(0.24, 0.26, 0.02), Color("fff3c8"), Vector3(1, 1, 0.1), 16, lit)
		for s in [[-0.3, 0.35], [-0.1, 0.18], [0.05, 0.4], [0.35, 0.05], [-0.36, 0.1]]:
			glow_box(Vector3(0.018, 0.018, 0.01), c + Vector3(s[0], s[1], 0.015), Color("fff6d8"))
	# 枠・十字の桟・出窓の台
	var fr := CREAM.lerp(WOOD_L, 0.35)
	box(Vector3(w + 0.14, 0.08, 0.08), c + Vector3(0, h * 0.5 + 0.03, 0.03), fr)
	box(Vector3(0.08, h + 0.12, 0.08), c + Vector3(-w * 0.5 - 0.03, 0, 0.03), fr)
	box(Vector3(0.08, h + 0.12, 0.08), c + Vector3(w * 0.5 + 0.03, 0, 0.03), fr)
	box(Vector3(0.04, h, 0.04), c + Vector3(0, 0, 0.02), fr)
	box(Vector3(w, 0.04, 0.04), c + Vector3(0, 0.08, 0.02), fr)
	box(Vector3(w + 0.3, 0.06, 0.2), c + Vector3(0, -h * 0.5 - 0.02, 0.09), fr)
	# カーテン（束ねたもの）
	var cur := Color("f08f86") if role != "stock" else Color("8fb8a8")
	for sx in [-1.0, 1.0]:
		box(Vector3(0.16, h + 0.2, 0.06), c + Vector3(sx * (w * 0.5 + 0.12), 0.02, 0.07), cur.darkened(0.08), Vector3.ZERO, cur.lightened(0.12))
		box(Vector3(0.2, 0.05, 0.08), c + Vector3(sx * (w * 0.5 + 0.12), -0.12, 0.1), Color("ffd166"))
	box(Vector3(w + 0.6, 0.04, 0.04), c + Vector3(0, h * 0.5 + 0.14, 0.08), WOOD_D)
	# 出窓の小さな鉢
	cyl(0.07, 0.055, 0.1, c + Vector3(-0.25, -h * 0.5 + 0.06, 0.12), Color("e8966f"), Vector3.ZERO, 14)
	ball(0.08, c + Vector3(-0.25, -h * 0.5 + 0.16, 0.12), LEAF)
	ball(0.06, c + Vector3(-0.18, -h * 0.5 + 0.2, 0.13), Color("ff8fa8"))
	cyl(0.05, 0.05, 0.12, c + Vector3(0.28, -h * 0.5 + 0.07, 0.12), Color("8fa8ff"), Vector3.ZERO, 14)
	# 日だまり（昼・夕方の窓の光が床に落ちる）
	if night < 0.85:
		var sc := _tod(Color(1.0, 0.86, 0.6), Color(1.0, 0.6, 0.4), Color(0, 0, 0), night) * (1.0 - night)
		var b := Basis(Vector3(1.1, 0, 0), Vector3(0, 1, 0), Vector3(0.55, 0, 1.25))
		sun.add(_plane(), Transform3D(b, Vector3(c.x + 0.55, 0.008, WALL_F + 0.85)), Color(sc.r * 0.3, sc.g * 0.3, sc.b * 0.3, 1.0), null, 0)


## 棚板 1 枚と、下の金具
func _shelf(p: Vector3, w: float) -> void:
	box(Vector3(w, 0.05, 0.26), p + Vector3(0, 0, 0.13), WOOD)
	for sx in [-1.0, 1.0]:
		box(Vector3(0.03, 0.14, 0.14), p + Vector3(sx * (w * 0.5 - 0.1), -0.09, 0.08), WOOD_D)


## 棚の上の小物（瓶・カップ・箱をならべる）
func _goods(p: Vector3, w: float, seed_v: int, kind := "cafe") -> void:
	var cols := [Color("ff9f80"), Color("ffd166"), Color("8fd0b0"), Color("9fb4ff"), Color("f7a8c8"), Color("c9a0f0")]
	var x := -w * 0.5 + 0.1
	var i := seed_v
	while x < w * 0.5 - 0.08:
		var col: Color = cols[i % cols.size()]
		match (i * 7 + seed_v) % 4:
			0: # 瓶
				cyl(0.05, 0.05, 0.16, p + Vector3(x, 0.105, 0.13), col.lerp(Color.WHITE, 0.25), Vector3.ZERO, 14)
				cyl(0.035, 0.035, 0.03, p + Vector3(x, 0.2, 0.13), WOOD_L, Vector3.ZERO, 12)
				x += 0.14
			1: # カップ
				cyl(0.045, 0.04, 0.08, p + Vector3(x, 0.065, 0.14), col if kind != "stock" else CREAM, Vector3.ZERO, 14)
				x += 0.12
			2: # 箱
				box(Vector3(0.14, 0.16 + (i % 2) * 0.05, 0.14), p + Vector3(x + 0.02, 0.105 + (i % 2) * 0.025, 0.13), col)
				x += 0.19
			_: # 皿を立てたもの
				cyl(0.075, 0.075, 0.02, p + Vector3(x, 0.1, 0.06), CREAM, Vector3(PI / 2 - 0.2, 0, 0), 18)
				x += 0.14
		i += 1


## 猫の稼ぎのお皿を載せる小さな台
func _stool(p: Vector3) -> void:
	var top := p.y - 0.04
	box(Vector3(0.52, 0.06, 0.46), Vector3(p.x, top, p.z), WOOD_L)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			box(Vector3(0.05, top - 0.03, 0.05), Vector3(p.x + sx * 0.19, (top - 0.03) * 0.5, p.z + sz * 0.16), WOOD)
	box(Vector3(0.44, 0.04, 0.38), Vector3(p.x, top * 0.35, p.z), WOOD)
	blob(p.x, p.z, 0.8, 0.7, 0.5)


## 奥の台（カウンター）：本体・天板・前の縦板
func _counter(x: float, z: float, w: float, body: Color, top: Color, h := 0.84, slats := true) -> void:
	box(Vector3(w, h - 0.05, 0.6), Vector3(x, (h - 0.05) * 0.5, z), body.darkened(0.08), Vector3.ZERO, body)
	box(Vector3(w + 0.08, 0.06, 0.68), Vector3(x, h - 0.02, z + 0.02), top)
	if slats:
		var nsl := int(w / 0.16)
		for i in nsl:
			slab(Vector3(0.02, h - 0.2, 0.012), Vector3(x - w * 0.5 + (i + 0.5) * w / nsl, (h - 0.05) * 0.5, z + 0.305), body.darkened(0.2), null, 1)
	box(Vector3(w - 0.04, 0.08, 0.05), Vector3(x, 0.04, z + 0.28), body.darkened(0.3))
	blob(x, z + 0.25, w + 0.5, 0.9, 0.55)


# ---------------------------------------------------------------- 仕事ごとの台

## レジ（カフェのカウンター）：レジ・ショーケースのケーキ・コーヒーの機械・メニューの黒板
func _register() -> void:
	_menu_board(Vector3(0.62, 2.22, WALL_F), true)
	_shelf(Vector3(0.62, 1.45, WALL_F), 1.1)
	_goods(Vector3(0.62, 1.475, WALL_F), 1.05, 1)
	_counter(0.5, -0.9, 2.1, Color("86b3c2"), Color("f3e6d2"))
	# レジ
	var r := Vector3(0.05, 0.84, -0.85)
	box(Vector3(0.44, 0.2, 0.36), r + Vector3(0, 0.1, 0), Color("6f86c9"))
	box(Vector3(0.36, 0.04, 0.2), r + Vector3(0, 0.22, 0.04), Color("4f64a8"), Vector3(-0.35, 0, 0))
	for i in 3:
		for j in 2:
			box(Vector3(0.07, 0.03, 0.05), r + Vector3(-0.1 + i * 0.1, 0.25 + j * 0.02, 0.0 + j * 0.06), [Color("fff4e2"), Color("ffd166"), Color("ff9f80")][(i + j) % 3], Vector3(-0.35, 0, 0))
	box(Vector3(0.05, 0.3, 0.05), r + Vector3(0.12, 0.35, -0.12), Color("4f64a8"))
	box(Vector3(0.3, 0.2, 0.04), r + Vector3(0.12, 0.54, -0.1), Color("3a4a74"), Vector3(0.1, 0, 0))
	glow_box(Vector3(0.24, 0.14, 0.01), r + Vector3(0.12, 0.54, -0.075), Color("a8f0c0"), Color("d8ffe0"), Vector3(0.1, 0, 0))
	# ケーキのショーケース
	var s := Vector3(0.95, 0.84, -0.9)
	box(Vector3(0.62, 0.05, 0.42), s + Vector3(0, 0.025, 0), CREAM)
	for i in 3:
		var cx := -0.19 + i * 0.19
		cyl(0.075, 0.075, 0.09, s + Vector3(cx, 0.1, 0.04), [Color("ffc2d1"), Color("fff0b0"), Color("c89a70")][i], Vector3.ZERO, 16)
		cyl(0.078, 0.078, 0.02, s + Vector3(cx, 0.155, 0.04), CREAM, Vector3.ZERO, 16)
		ball(0.025, s + Vector3(cx, 0.18, 0.04), Color("e8575b"))
	box(Vector3(0.62, 0.34, 0.03), s + Vector3(0, 0.2, -0.2), CREAM.darkened(0.05))
	box(Vector3(0.62, 0.04, 0.42), s + Vector3(0, 0.38, 0), Color("e0a060"))
	# コーヒーの機械とカップ
	var m := Vector3(1.4, 0.84, -1.0)
	box(Vector3(0.3, 0.42, 0.3), m + Vector3(0, 0.21, 0), Color("c8ced6"), Vector3.ZERO, Color("e1e6ec"))
	box(Vector3(0.22, 0.06, 0.12), m + Vector3(0, 0.3, 0.16), STEEL_D)
	cyl(0.04, 0.035, 0.06, m + Vector3(0, 0.05, 0.14), CREAM, Vector3.ZERO, 12)
	for i in 3:
		cyl(0.05, 0.042, 0.07, Vector3(-0.35 + i * 0.02, 0.88 + i * 0.07, -0.95), [Color("f7a8c8"), CREAM, Color("8fd0b0")][i], Vector3.ZERO, 14)
	# チップの瓶
	cyl(0.06, 0.06, 0.12, Vector3(-0.18, 0.9, -0.72), Color("cfe8ff"), Vector3.ZERO, 14)
	ball(0.03, Vector3(-0.18, 0.93, -0.72), Color("ffc93d"))


## メニューの黒板（字は使わず、チョークの線と絵）
func _menu_board(p: Vector3, big := false) -> void:
	var w := 1.1 if big else 0.8
	var h := 0.5
	box(Vector3(w + 0.1, h + 0.1, 0.05), p + Vector3(0, 0, 0.025), WOOD)
	slab(Vector3(w, h, 0.02), p + Vector3(0, 0, 0.055), Color("2f4a42"), Color("365549"), 0)
	var chalk := Color("f3efe2")
	slab(Vector3(w * 0.4, 0.035, 0.01), p + Vector3(0, h * 0.5 - 0.08, 0.07), Color("ffd98a"), null, 0)
	for i in 4:
		var y := h * 0.5 - 0.18 - i * 0.11
		ball(0.028, p + Vector3(-w * 0.5 + 0.1, y, 0.068), [Color("ff9f80"), Color("8fd0b0"), Color("ffd166"), Color("f7a8c8")][i], Vector3(1, 1, 0.3), 10, lit)
		slab(Vector3(w * (0.38 + 0.08 * (i % 2)), 0.018, 0.01), p + Vector3(-w * 0.5 + 0.17 + w * (0.19 + 0.04 * (i % 2)), y, 0.07), chalk, null, 0)
		slab(Vector3(0.1, 0.018, 0.01), p + Vector3(w * 0.5 - 0.12, y, 0.07), Color("ffd98a"), null, 0)
	# カップの絵
	slab(Vector3(0.12, 0.1, 0.01), p + Vector3(w * 0.5 - 0.3, h * 0.5 - 0.1, 0.07), chalk, null, 0)


## ホール：丸テーブルといす、花、奥にケーキの棚
func _hall() -> void:
	_menu_board(Vector3(0.75, 2.2, WALL_F))
	_shelf(Vector3(0.75, 1.45, WALL_F), 1.0)
	_goods(Vector3(0.75, 1.475, WALL_F), 0.95, 3)
	for t in [[-1.05, -0.55, Color("f7a8c8")], [0.85, -0.95, Color("ffd166")]]:
		var x: float = t[0]
		var z: float = t[1]
		cyl(0.36, 0.36, 0.05, Vector3(x, 0.72, z), WOOD_L, Vector3.ZERO, 32)
		cyl(0.04, 0.05, 0.68, Vector3(x, 0.36, z), WOOD_D, Vector3.ZERO, 12)
		cyl(0.2, 0.22, 0.04, Vector3(x, 0.02, z), WOOD_D, Vector3.ZERO, 20)
		cyl(0.05, 0.045, 0.1, Vector3(x + 0.12, 0.8, z + 0.05), CREAM, Vector3.ZERO, 14)
		cyl(0.035, 0.045, 0.14, Vector3(x - 0.08, 0.82, z - 0.05), Color("cfe8ff"), Vector3.ZERO, 12)
		ball(0.05, Vector3(x - 0.08, 0.93, z - 0.05), t[2])
		ball(0.04, Vector3(x - 0.03, 0.91, z - 0.02), Color("ff9f80"))
		blob(x, z, 1.0, 0.8, 0.5)
		for sx in [-1.0, 1.0]:
			var cx: float = x + sx * 0.5
			box(Vector3(0.34, 0.05, 0.32), Vector3(cx, 0.44, z), Color("e0a060"))
			box(Vector3(0.05, 0.4, 0.3), Vector3(cx + sx * 0.15, 0.66, z), Color("e0a060"))
			for lz in [-0.12, 0.12]:
				box(Vector3(0.04, 0.42, 0.04), Vector3(cx - sx * 0.12, 0.21, z + lz), WOOD_D)
				box(Vector3(0.04, 0.42, 0.04), Vector3(cx + sx * 0.14, 0.21, z + lz), WOOD_D)
	# 奥の配膳台
	_counter(0.2, -1.25, 1.0, Color("7aa3b8"), CREAM, 0.8, true)
	cyl(0.14, 0.12, 0.04, Vector3(0.05, 0.84, -1.2), CREAM, Vector3.ZERO, 18)
	cyl(0.14, 0.12, 0.04, Vector3(0.05, 0.88, -1.2), CREAM, Vector3.ZERO, 18)
	ball(0.08, Vector3(0.4, 0.88, -1.2), Color("ffc2d1"), Vector3(1, 0.6, 1))


## キッチン：ステンレスの台・コンロの鍋・換気扇のフード・お玉を吊るすバー・スパイスの棚
func _kitchen() -> void:
	_counter(0.45, -0.9, 2.2, STEEL, Color("c9d1d9"), 0.84, false)
	for i in 3:
		box(Vector3(0.6, 0.6, 0.02), Vector3(-0.3 + i * 0.72, 0.42, -0.59), Color("a9b6c2"))
		box(Vector3(0.2, 0.03, 0.03), Vector3(-0.3 + i * 0.72, 0.66, -0.575), STEEL_D)
	# コンロと鍋
	var s := Vector3(0.05, 0.87, -0.9)
	box(Vector3(0.62, 0.03, 0.46), s, Color("3a3a42"))
	for dx in [-0.15, 0.15]:
		cyl(0.1, 0.1, 0.012, s + Vector3(dx, 0.02, 0), Color("55555f"), Vector3.ZERO, 16)
	cyl(0.14, 0.13, 0.18, s + Vector3(-0.15, 0.12, 0), Color("e8575b"), Vector3.ZERO, 22)
	cyl(0.145, 0.145, 0.02, s + Vector3(-0.15, 0.22, 0), Color("c8434a"), Vector3.ZERO, 22)
	ball(0.025, s + Vector3(-0.15, 0.24, 0), Color("3a3a42"))
	cyl(0.12, 0.1, 0.04, s + Vector3(0.17, 0.04, 0.02), Color("4a4a52"), Vector3.ZERO, 20)
	box(Vector3(0.22, 0.025, 0.04), s + Vector3(0.38, 0.05, 0.05), WOOD_D)
	ball(0.04, s + Vector3(0.14, 0.07, 0.03), Color("ffd166"), Vector3(1, 0.4, 1))
	ball(0.06, s + Vector3(-0.15, 0.02, 0), Color("ff9a4d"), Vector3(1.3, 0.6, 1.3), 12, lit) # 火
	for i in 3:
		ball(0.05 + i * 0.015, s + Vector3(-0.15 + i * 0.03, 0.34 + i * 0.12, 0.02), Color("fff8f0"), Vector3.ONE, 12)
	# まな板と野菜
	var b := Vector3(0.95, 0.87, -0.85)
	box(Vector3(0.44, 0.03, 0.28), b, WOOD_L)
	ball(0.06, b + Vector3(-0.1, 0.06, 0), Color("ff7f5b"))
	ball(0.05, b + Vector3(0.06, 0.05, 0.03), Color("9bd06a"))
	for i in 3:
		cyl(0.03, 0.03, 0.012, b + Vector3(0.14 + i * 0.035, 0.025, -0.05), Color("ffb066"), Vector3(0, 0, 0.3), 10)
	# 換気扇のフード（壁の上半分）
	var h := Vector3(0.05, 2.05, WALL_F)
	box(Vector3(0.9, 0.34, 0.5), h + Vector3(0, 0, 0.25), Color("7f8c99"), Vector3.ZERO, Color("98a4b0"))
	box(Vector3(0.36, 0.9, 0.3), h + Vector3(0, 0.62, 0.15), Color("8a96a3"))
	box(Vector3(0.92, 0.05, 0.52), h + Vector3(0, -0.18, 0.26), STEEL_D)
	# お玉・フライ返しのバー
	box(Vector3(0.9, 0.03, 0.03), Vector3(0.95, 1.95, WALL_F + 0.08), STEEL_D)
	for i in 4:
		var x := 0.62 + i * 0.22
		cyl(0.012, 0.012, 0.3, Vector3(x, 1.8, WALL_F + 0.1), STEEL_D, Vector3.ZERO, 6)
		if i % 2 == 0:
			ball(0.05, Vector3(x, 1.64, WALL_F + 0.12), STEEL, Vector3(1, 0.6, 1))
		else:
			box(Vector3(0.08, 0.1, 0.015), Vector3(x, 1.62, WALL_F + 0.1), [Color("e8575b"), WOOD][i / 2 % 2])
	# スパイスの棚
	_shelf(Vector3(0.95, 2.35, WALL_F), 0.95)
	_goods(Vector3(0.95, 2.375, WALL_F), 0.9, 0)
	_shelf(Vector3(-0.95, 2.55, WALL_F), 0.5)
	_goods(Vector3(-0.95, 2.575, WALL_F), 0.45, 2)


## 皿洗い：流し台・蛇口・泡・水切りかご・皿の棚
func _dish() -> void:
	_counter(0.45, -0.9, 2.2, Color("8fb0d4"), Color("e6eef6"), 0.84, true)
	var s := Vector3(0.1, 0.87, -0.9)
	box(Vector3(0.8, 0.03, 0.46), s, STEEL)
	slab(Vector3(0.68, 0.02, 0.36), s + Vector3(0, 0.012, 0), Color("6fa8d0"), null, 0)
	box(Vector3(0.05, 0.3, 0.05), s + Vector3(0, 0.15, -0.26), STEEL_D)
	box(Vector3(0.05, 0.05, 0.2), s + Vector3(0, 0.3, -0.16), STEEL_D)
	box(Vector3(0.1, 0.04, 0.04), s + Vector3(0.1, 0.2, -0.26), Color("e8575b"))
	for i in 6:
		ball(0.05 + (i % 3) * 0.015, s + Vector3(-0.28 + i * 0.11, 0.05 + (i % 2) * 0.04, 0.05 + (i % 3) * 0.04), Color("f4fbff"), Vector3.ONE, 12)
	# 洗い終わった皿の山とかご
	var r := Vector3(0.95, 0.87, -0.9)
	box(Vector3(0.5, 0.05, 0.34), r, STEEL_D)
	for i in 6:
		cyl(0.12, 0.12, 0.018, r + Vector3(-0.12 + i * 0.05, 0.14, 0), CREAM, Vector3(0, 0, PI / 2 - 0.2), 20)
	for i in 4:
		cyl(0.13, 0.11, 0.022, Vector3(-0.7, 0.9 + i * 0.03, -0.85), CREAM, Vector3.ZERO, 20)
	# 皿の棚（壁）
	_shelf(Vector3(0.75, 1.95, WALL_F), 1.2)
	for i in 6:
		cyl(0.1, 0.1, 0.018, Vector3(0.28 + i * 0.18, 2.08, WALL_F + 0.1), [CREAM, Color("a3c4ea"), Color("f7a8c8")][i % 3], Vector3(PI / 2 - 0.15, 0, 0), 20)
	_shelf(Vector3(0.75, 2.45, WALL_F), 1.2)
	_goods(Vector3(0.75, 2.475, WALL_F), 1.15, 1)
	# 洗剤
	cyl(0.05, 0.05, 0.18, Vector3(-0.35, 0.96, -1.0), Color("8fd0b0"), Vector3.ZERO, 12)
	cyl(0.015, 0.015, 0.05, Vector3(-0.35, 1.07, -1.0), CREAM, Vector3.ZERO, 8)


## 品出し（倉庫）：スチールの棚に色とりどりの段ボール、床の木箱、台車
func _stock() -> void:
	var cols := [Color("d9a066"), Color("c98a52"), Color("e6b27a"), Color("b87a48")]
	var tags := [Color("ff8f7a"), Color("7cc6a4"), Color("8fa8ff"), Color("ffd166")]
	for unit in [[-0.05, 1.35], [1.25, 0.9]]:
		var x: float = unit[0]
		var w: float = unit[1]
		for sx in [-1.0, 1.0]:
			box(Vector3(0.05, 2.5, 0.05), Vector3(x + sx * w * 0.5, 1.25, WALL_F + 0.08), Color("5f7fae"))
			box(Vector3(0.05, 2.5, 0.05), Vector3(x + sx * w * 0.5, 1.25, WALL_F + 0.5), Color("5f7fae"))
		for k in 4:
			var y := 0.2 + k * 0.62
			box(Vector3(w, 0.04, 0.5), Vector3(x, y, WALL_F + 0.29), Color("a8b4c0"))
			var bx := x - w * 0.5 + 0.06
			var i := k * 3 + int(x * 10.0)
			while bx < x + w * 0.5 - 0.2:
				var bw := 0.2 + float((i * 5) % 3) * 0.05
				var bh := 0.22 + float((i * 3) % 4) * 0.06
				box(Vector3(bw, bh, 0.34), Vector3(bx + bw * 0.5, y + 0.02 + bh * 0.5, WALL_F + 0.3), cols[i % cols.size()])
				slab(Vector3(bw * 0.5, 0.05, 0.01), Vector3(bx + bw * 0.5, y + 0.02 + bh * 0.6, WALL_F + 0.475), tags[(i * 3) % tags.size()], null, 1)
				bx += bw + 0.03
				i += 1
		blob(x, WALL_F + 0.35, w + 0.4, 0.9, 0.5)
	# 床の木箱と、台車
	for c in [[0.2, -0.45, 0.0], [0.62, -0.5, 0.0], [0.4, -0.5, 0.42]]:
		box(Vector3(0.4, 0.4, 0.4), Vector3(c[0], 0.2 + c[2], c[1]), WOOD_L)
		for sy in [-0.12, 0.12]:
			slab(Vector3(0.41, 0.05, 0.41), Vector3(c[0], 0.2 + c[2] + sy, c[1]), WOOD, null, 1)
	blob(0.4, -0.45, 1.1, 0.8, 0.5)
	box(Vector3(0.05, 0.9, 0.05), Vector3(-1.0, 0.45, -0.5), Color("e8575b"), Vector3(0.12, 0, 0))
	box(Vector3(0.36, 0.04, 0.3), Vector3(-0.95, 0.03, -0.35), Color("e8575b"))
	cyl(0.06, 0.06, 0.04, Vector3(-1.13, 0.06, -0.45), Color("3a3a42"), Vector3(0, 0, PI / 2), 12)
	cyl(0.06, 0.06, 0.04, Vector3(-0.77, 0.06, -0.45), Color("3a3a42"), Vector3(0, 0, PI / 2), 12)
	box(Vector3(0.3, 0.26, 0.26), Vector3(-0.95, 0.18, -0.35), cols[2])
	# 壁のクリップボード
	box(Vector3(0.26, 0.34, 0.02), Vector3(-1.75, 1.35, WALL_F + 0.01), WOOD)
	slab(Vector3(0.22, 0.26, 0.01), Vector3(-1.75, 1.33, WALL_F + 0.025), CREAM, null, 0)
