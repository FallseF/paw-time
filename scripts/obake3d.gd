class_name Obake3D
extends Node3D
## 3D のおばけ。Blender で作った切れ目のない体（assets/models/cat_obake*.glb、作り方は
## tools/blender/build_cat_obake.py）に、手描き風の肌のシェーダー（shaders/character.gdshader）と
## 細い色つきの輪郭を掛け、つやのある目と、距離関数で描いた顔の線を貼る。
## 持ち物は球・円柱などの組み合わせなので、種類ごとに足すのも簡単。

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
const PINK := Color("f6a8aa")
const BODY_SCENES := {
	"cat": "res://assets/models/cat_obake.glb",
	"plain": "res://assets/models/cat_obake_plain.glb",
	"squat": "res://assets/models/cat_obake_squat.glb",
}
const SKIN_SHADER := preload("res://shaders/character.gdshader")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
const EYE_SHADER := preload("res://shaders/eye.gdshader")
const DECAL_SHADER := preload("res://shaders/face_decal.gdshader")
const EYE_SCALE := Vector3(0.8, 1.2, 0.5)
const BLINK_TIME := 0.16

var species := "bubble"
var body: Node3D
var _t := 0.0
var _blink := 0.0
var _next_blink := 3.0
var eyes: Array[MeshInstance3D] = []
var bob := true
## 足元のぼんやりした影を付けるか
var contact_shadow := true

## 形・材質の使い回し（同じものを何度も作らない）
static var _bodies := {}
static var _shared := {}
static var _patches := {}


static func make(id: String) -> Obake3D:
	if Rares.is_rare(id):
		return RareObake3D.new().setup(id)
	return Obake3D.new().setup(id)


## 診断で決まる「マイおばけ猫」を見た目の辞書から作る（MyObake3D / QuizData の look を参照）
static func make_custom(look: Dictionary) -> Obake3D:
	return MyObake3D.new().setup_look(look)


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


## おばけの肌の材質。色ごとに使い回す。tex を渡すと色に掛ける（縦じまの塗り分けなど）。
## rim は縁の光の強さ、sss は明暗の境目の赤み。outline=false で輪郭なし。
## sheen は光のつや（-1 でシェーダーの既定）。
static func skin(color: Color, emission := 0.0, tex: Texture2D = null, rim := 0.15, sss := 0.1, outline := true, sheen := -1.0) -> ShaderMaterial:
	var key := "%s/%s/%s/%s/%s/%s/%s" % [color.to_html(), emission, tex.get_instance_id() if tex else 0, rim, sss, outline, sheen]
	if _shared.has(key):
		return _shared[key]
	var m := ShaderMaterial.new()
	m.shader = SKIN_SHADER
	m.set_shader_parameter("base_color", color)
	m.set_shader_parameter("emission_energy", emission)
	m.set_shader_parameter("rim_strength", rim)
	m.set_shader_parameter("sss_strength", sss)
	if sheen >= 0.0:
		m.set_shader_parameter("sheen", sheen)
	if tex:
		m.set_shader_parameter("albedo_tex", tex)
	if outline:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE_SHADER
		o.set_shader_parameter("color", line_color(color))
		# 持ち物（肌らしさなし）は輪郭を細くして、部品ごとの縁取りを目立たせない
		if sss <= 0.0:
			o.set_shader_parameter("width", 0.0045)
		m.next_pass = o
	_shared[key] = m
	return m


## 持ち物の材質：肌と同じ光の当たり方で、境目の赤み（肌らしさ）は付けず、つやも控えめ。
## rim は昔の toon() と同じ目安（大きいほど縁が明るい）。
static func prop(color: Color, rim := 0.35, emission := 0.0) -> ShaderMaterial:
	return skin(color, emission, null, 0.06 + rim * 0.2, 0.0, true, 0.025)


## 金属（冠・金具）：つやを強く、せまく
static func metal(color: Color) -> ShaderMaterial:
	var key := "metal/" + color.to_html()
	if _shared.has(key):
		return _shared[key]
	var m := skin(color, 0.0, null, 0.12, 0.0, true, 0.35).duplicate() as ShaderMaterial
	m.set_shader_parameter("sheen_gloss", 40.0)
	m.set_shader_parameter("wrap", 0.2)
	_shared[key] = m
	return m


## 輪郭の色：体の色を暗く濃くしたもの（真っ黒よりやわらかい）
static func line_color(c: Color) -> Color:
	var d := Color.from_hsv(c.h, clampf(c.s * 1.1 + 0.2, 0.0, 1.0), c.v * 0.34)
	return INK.lerp(d, 0.55)


## つやのある目の材質。明るい目（暗い体の子）は下を少し色づける。
static func eye_mat(col: Color) -> ShaderMaterial:
	var key := "eye/" + col.to_html()
	if _shared.has(key):
		return _shared[key]
	var m := ShaderMaterial.new()
	m.shader = EYE_SHADER
	if col.get_luminance() > 0.5:
		# 明るい目（暗い体の子）：真っ白な丸だと目に見えないので、濃い紺の黒目を明るい輪で縁取り、
		# キャッチライトが見えるようにする
		m.set_shader_parameter("iris_top", Color("1b1530"))
		m.set_shader_parameter("iris_bottom", Color("3d3468"))
		m.set_shader_parameter("ring_color", col.lerp(Color("d9ccff"), 0.25))
		m.set_shader_parameter("ring_width", 0.26)
	else:
		m.set_shader_parameter("iris_top", col.darkened(0.25))
		m.set_shader_parameter("iris_bottom", col.lerp(Color("7a4f6e"), 0.55))
	_shared[key] = m
	return m


## 顔の線・色の材質（shape は face_decal.gdshader の番号）
static func decal_mat(shape: int, col: Color, half: Vector2, stroke := 0.012, col2 := Color.WHITE, bias := 0.045) -> ShaderMaterial:
	var key := "decal/%d/%s/%s/%s/%s/%s" % [shape, col.to_html(), half, stroke, col2.to_html(), bias]
	if _shared.has(key):
		return _shared[key]
	var m := ShaderMaterial.new()
	m.shader = DECAL_SHADER
	m.set_shader_parameter("shape", shape)
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("color2", col2)
	m.set_shader_parameter("half_size", half)
	m.set_shader_parameter("stroke", stroke)
	m.set_shader_parameter("depth_bias", bias)
	m.render_priority = 0 if shape == 0 or shape == 5 else 1
	_shared[key] = m
	return m


## Blender で作った体（"cat" / "plain" / "squat"）の {"body": Mesh, "tail": Mesh}
static func body_meshes(variant: String) -> Dictionary:
	if _bodies.has(variant):
		return _bodies[variant]
	var parts := {}
	var scn := load(BODY_SCENES[variant]) as PackedScene
	var inst := scn.instantiate()
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		parts[String(n.name).to_lower()] = (n as MeshInstance3D).mesh
	inst.free()
	_bodies[variant] = parts
	return parts


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


func _ready() -> void:
	if contact_shadow:
		_add_contact_shadow()
	# おばけだけに当てる光（Look のフィル・リム）を受けられるよう、キャラの層にも乗せる
	for n in find_children("*", "GeometryInstance3D", true, false):
		(n as VisualInstance3D).layers |= 1 << (Look.CHAR_LAYER - 1)


## 足元のぼんやりした影。地面に近い部品の広がりに合わせる。
func _add_contact_shadow() -> void:
	if body == null:
		return # 部品づくりだけに使われた Obake3D（庭の住人など）
	var box := AABB()
	var first := true
	for m in body.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.material_override and mi.material_override is ShaderMaterial and (mi.material_override as ShaderMaterial).shader == DECAL_SHADER:
			continue
		var b := (global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		if b.position.y > 0.35:
			continue
		box = b if first else box.merge(b)
		first = false
	if first:
		return
	var w := clampf(maxf(box.size.x, box.size.z) * 1.05, 0.7, 2.6)
	var p := PlaneMesh.new()
	p.size = Vector2(w, w * 0.85)
	var mi := MeshInstance3D.new()
	mi.name = "ContactShadow"
	mi.mesh = p
	mi.material_override = decal_mat(5, Color(0.16, 0.1, 0.18, 0.26), Vector2.ONE, 0.0, Color.WHITE, 0.0)
	mi.position = Vector3(box.get_center().x, 0.006, box.get_center().z)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("no_frame", true)
	add_child(mi)


## おばけの体（丸い頭・胴・波打つ裾・耳・尻尾・顔）をひとつ組んで返す。足元が y=0、高さ約 1.0。
## s はこのノードに掛ける縮尺。輪郭は世界の長さで太さが決まるので、縮尺の補正は要らない。
## mat を渡すと、その材質で塗る（col と emission は使わない）。
## with_face=false なら、耳も尻尾も顔もない体にする（顔を別の場所に付けるとき用）。
func ghost(col: Color, s := 1.0, emission := 0.0, eye_col := INK, sleepy := false, with_face := true, mat: Material = null) -> Node3D:
	var g := Node3D.new()
	g.scale = Vector3.ONE * s
	if mat == null:
		mat = skin(col, emission)
	var cat := with_face and CAT
	var parts := body_meshes("cat" if cat else "plain")
	var b := _mesh(parts.body, mat, Vector3.ZERO)
	b.name = "Body"
	g.add_child(b)
	if cat and parts.has("tail"):
		var tail := _mesh(parts.tail, mat, Vector3.ZERO)
		tail.name = "Tail"
		g.add_child(tail)
	if with_face:
		g.add_child(face(Vector3(0, 0.5, 0), 1.0, eye_col, sleepy))
	return g


## Paw Time：猫おばけ（耳・尻尾・鼻・ωの口・ひげ）。false で耳なしのおばけに戻る。
static var CAT := true


## 顔（目・ほっぺ・鼻・口・ひげ）。center は半径 0.5 の頭の中心、k はその頭に対する倍率。正面は +Z。
## sleepy なら、目を閉じた弧にする（まばたきしない）。
func face(center: Vector3, k := 1.0, eye_col := INK, sleepy := false) -> Node3D:
	var f := Node3D.new()
	f.position = center
	f.scale = Vector3.ONE * k
	# 暗い体の子（明るい目）は、口とひげも明るい線にして読めるようにする
	var ink := INK if eye_col.get_luminance() <= 0.5 else Color("e6dcff")
	for x in [-0.17, 0.17]:
		if sleepy:
			var half := Vector2(0.085, 0.05)
			f.add_child(_decal(Vector2(x, 0.03), half, decal_mat(3, eye_col, half, 0.02)))
		else:
			var e := _mesh(_eye_mesh(), eye_mat(eye_col), _on_head(Vector2(x, 0.05), 0.49))
			e.rotation = _facing(Vector2(x, 0.05))
			e.scale = EYE_SCALE
			eyes.append(e)
			f.add_child(e)
		var ch := Vector2(0.11, 0.072)
		f.add_child(_decal(Vector2(x * 1.72, -0.085), ch, decal_mat(0, Color(PINK.lerp(Color("ff7f9a"), 0.35), 0.65), ch)))
	if CAT:
		# 鼻と「ω」の口、ひげ
		var nh := Vector2(0.034, 0.026)
		f.add_child(_decal(Vector2(0, -0.035), nh, decal_mat(1, Color("ee8597"), nh, 0.0, Color("ffd9df"))))
		var mh := Vector2(0.09, 0.045)
		f.add_child(_decal(Vector2(0, -0.088), mh, decal_mat(2, ink, mh, 0.0125)))
		var wh := Vector2(0.1, 0.012)
		var wm := decal_mat(4, Color(ink, 0.92), wh, 0.011)
		for sx in [-1.0, 1.0]:
			for j in 3:
				f.add_child(_whisker(sx, j, wh, wm))
	else:
		var mh := Vector2(0.05, 0.03)
		f.add_child(_decal(Vector2(0, -0.07), mh, decal_mat(3, ink, mh, 0.014)))
	return f


## 頭（半径 0.5）の表面の点。p は正面から見た x, y。
## 頭の中心より下は、体の円柱（同じ半径）の面に乗せる。
static func _on_head(p: Vector2, r := 0.5) -> Vector3:
	var yy := maxf(p.y, 0.0)
	return Vector3(p.x, p.y, sqrt(maxf(r * r - p.x * p.x - yy * yy, 0.0)))


## その点で頭の表面に向きをそろえる回転
static func _facing(p: Vector2) -> Vector3:
	var n := _on_head(p).normalized()
	if p.y < 0.0:
		n = Vector3(n.x, 0.0, n.z).normalized()
	return Vector3(-asin(n.y), atan2(n.x, n.z), 0)


static func _eye_mesh() -> SphereMesh:
	if not _patches.has("eye"):
		var s := SphereMesh.new()
		s.radius = 0.07
		s.height = 0.14
		s.radial_segments = 32
		s.rings = 16
		_patches["eye"] = s
	return _patches["eye"]


## 頭の表面に沿った小さな曲面（顔の線・色を貼る板）。UV は -half..half を 0..1 に。
static func _patch(at: Vector2, half: Vector2) -> ArrayMesh:
	var key := "%s/%s" % [at, half]
	if _patches.has(key):
		return _patches[key]
	var r := 0.5
	var n := _on_head(at, r).normalized()
	var t := Vector3.UP.cross(n).normalized()
	var bt := n.cross(t)
	var c := _on_head(at, r)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 8
	for i in seg + 1:
		for j in seg + 1:
			var u := -1.0 + 2.0 * i / seg
			var v := -1.0 + 2.0 * j / seg
			var q := c + t * u * half.x + bt * v * half.y
			var p := _on_head(Vector2(q.x, q.y), r)
			st.set_uv(Vector2((u + 1.0) * 0.5, (v + 1.0) * 0.5))
			st.set_normal(n)
			st.add_vertex(p)
	for i in seg:
		for j in seg:
			var a := i * (seg + 1) + j
			var b := a + seg + 1
			for id in [a, a + 1, b, b, a + 1, b + 1]:
				st.add_index(id)
	var m := st.commit()
	_patches[key] = m
	return m


func _decal(at: Vector2, half: Vector2, mat: Material) -> MeshInstance3D:
	var mi := _mesh(_patch(at, half), mat, Vector3.ZERO)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## ひげ一本：ほっぺの上から外へ、少し後ろへ流れる先細りの線
func _whisker(sx: float, j: int, half: Vector2, mat: Material) -> MeshInstance3D:
	var key := "whisker/%s/%d" % [sx, j]
	if not _patches.has(key):
		var root := _on_head(Vector2(sx * 0.26, -0.035 - j * 0.042), 0.5)
		var dir := Vector3(sx, 0.2 - j * 0.2, -0.3).normalized()
		var tip := root + dir * half.x * 2.0
		var up := dir.cross(root.normalized()).normalized() * sx
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var quad := [[root - up * half.y, Vector2(0, 0)], [tip - up * half.y, Vector2(1, 0)], [tip + up * half.y, Vector2(1, 1)], [root + up * half.y, Vector2(0, 1)]]
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_uv(quad[k][1])
			st.set_normal(Vector3(0, 0, 1))
			st.add_vertex(quad[k][0])
		_patches[key] = st.commit()
	var mi := _mesh(_patches[key], mat, Vector3.ZERO)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## 球。大きいものほど細かく割る（小さな粒は軽く）。
func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 48 if r >= 0.2 else (32 if r >= 0.06 else 20)
	s.rings = s.radial_segments / 2
	return s


## 円柱・円すい（y 方向に高さ h、中心が原点）。縁は丸める（bevel=-1 で太さに合わせて自動）。
## 上の半径が 0 なら先のとがった円すい。
func _cyl(top: float, bottom: float, h: float, seg := 20, bevel := -1.0) -> Mesh:
	var r := maxf(top, bottom)
	seg = maxi(seg, 48 if r >= 0.2 else (32 if r >= 0.06 else seg))
	if bevel < 0.0:
		bevel = minf(minf(r, h) * 0.22, 0.03)
	return lathe(top, bottom, h, seg, bevel)


static func lathe(top: float, bottom: float, h: float, seg: int, bevel: float) -> ArrayMesh:
	var key := "lathe/%s/%s/%s/%d/%s" % [top, bottom, h, seg, bevel]
	if _shared.has(key):
		return _shared[key]
	var y0 := -h * 0.5
	var y1 := h * 0.5
	var b := minf(bevel, minf(h * 0.45, maxf(bottom, top) * 0.45))
	# 断面（r, y）を下の中心から上の中心までたどる
	var prof: Array[Vector2] = [Vector2(0, y0)]
	var arc := 6
	if bottom > 0.0005:
		var bb := minf(b, bottom * 0.9)
		var c0 := Vector2(bottom - bb, y0 + bb)
		for k in arc + 1:
			var a := -PI * 0.5 + PI * 0.5 * k / arc
			prof.append(c0 + Vector2(cos(a), sin(a)) * bb)
	if top > b * 1.5:
		var c1 := Vector2(top - b, y1 - b)
		for k in arc + 1:
			var a := PI * 0.5 * k / arc
			prof.append(c1 + Vector2(cos(a), sin(a)) * b)
	prof.append(Vector2(0, y1))
	# 断面の各点の法線（となりの辺の向きから）
	var nrm: Array[Vector2] = []
	for i in prof.size():
		var d := Vector2.ZERO
		if i > 0:
			d += (prof[i] - prof[i - 1]).normalized()
		if i < prof.size() - 1:
			d += (prof[i + 1] - prof[i]).normalized()
		var n := Vector2(d.y, -d.x).normalized()
		if i == 0:
			n = Vector2(0, -1)
		elif i == prof.size() - 1:
			n = Vector2(0, 1)
		nrm.append(n)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in prof.size():
		for i in seg + 1:
			var u := TAU * i / seg
			var dir := Vector3(sin(u), 0, cos(u))
			st.set_uv(Vector2(float(i) / seg, float(j) / (prof.size() - 1)))
			st.set_normal((dir * nrm[j].x + Vector3.UP * nrm[j].y).normalized())
			st.add_vertex(dir * prof[j].x + Vector3.UP * prof[j].y)
	for j in prof.size() - 1:
		for i in seg:
			var a := j * (seg + 1) + i
			var c := a + seg + 1
			_quad(st, a, a + 1, c + 1, c)
	var m := st.commit()
	_shared[key] = m
	return m


## 点の列に沿った、太さの変わるなめらかな管（両端は丸くふさぐ）。key で使い回す。
static func tube(key: String, pts: PackedVector3Array, radii: PackedFloat32Array, seg := 20) -> ArrayMesh:
	key = "tube/" + key
	if _shared.has(key):
		return _shared[key]
	# 細かく割り直す（Catmull-Rom）
	var P := PackedVector3Array()
	var R := PackedFloat32Array()
	var sub := 6
	for i in pts.size() - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		for k in sub:
			var t := float(k) / sub
			P.append(p1.cubic_interpolate(p2, p0, p3, t))
			R.append(lerpf(radii[i], radii[i + 1], t))
	P.append(pts[pts.size() - 1])
	R.append(radii[radii.size() - 1])
	var n := P.size()
	var T: Array[Vector3] = []
	for i in n:
		T.append((P[mini(i + 1, n - 1)] - P[maxi(i - 1, 0)]).normalized())
	var N: Array[Vector3] = []
	var ref := Vector3.UP if absf(T[0].y) < 0.9 else Vector3.RIGHT
	N.append(T[0].cross(ref).normalized())
	for i in range(1, n):
		var v := N[i - 1] - T[i] * N[i - 1].dot(T[i])
		N.append(v.normalized())
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := []  # [中心, 接線, 法線, 半径, 前後へのふくらみの角度]
	var cap := 5
	for k in range(cap, 0, -1):
		rows.append([P[0], T[0], N[0], R[0], -PI * 0.5 * k / cap])
	for i in n:
		rows.append([P[i], T[i], N[i], R[i], 0.0])
	for k in range(1, cap + 1):
		rows.append([P[n - 1], T[n - 1], N[n - 1], R[n - 1], PI * 0.5 * k / cap])
	for j in rows.size():
		var c: Vector3 = rows[j][0]
		var t: Vector3 = rows[j][1]
		var nn: Vector3 = rows[j][2]
		var r: float = rows[j][3]
		var ang: float = rows[j][4]
		var bn := t.cross(nn)
		for i in seg + 1:
			var a := TAU * i / seg
			var radial := nn * cos(a) + bn * sin(a)
			var dir := radial * cos(ang) + t * sin(ang)
			st.set_normal(dir.normalized())
			st.set_uv(Vector2(float(i) / seg, float(j) / (rows.size() - 1)))
			st.add_vertex(c + dir * r)
	for j in rows.size() - 1:
		for i in seg:
			var a := j * (seg + 1) + i
			var b := a + seg + 1
			_quad(st, a, a + 1, b + 1, b)
	var m := st.commit()
	_shared[key] = m
	return m


## 四角（a→b→c→d が外から見て反時計回り）を、Godot の表向き（時計回り）の三角 2 枚にする
static func _quad(st: SurfaceTool, a: int, b: int, c: int, d: int) -> void:
	for id in [a, c, b, a, d, c]:
		st.add_index(id)


## 角を丸めた箱（中心が原点）。bevel=-1 で大きさに合わせて自動。
func _box(size: Vector3, bevel := -1.0) -> Mesh:
	if bevel < 0.0:
		bevel = clampf(minf(size.x, minf(size.y, size.z)) * 0.2, 0.002, 0.035)
	return rbox(size, bevel)


static func rbox(size: Vector3, bevel: float) -> ArrayMesh:
	var key := "rbox/%s/%s" % [size, bevel]
	if _shared.has(key):
		return _shared[key]
	var hs := size * 0.5
	var r := minf(bevel, minf(hs.x, minf(hs.y, hs.z)) * 0.95)
	var inner := hs - Vector3.ONE * r
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ts := [0.0, 0.25, 0.55, 1.0]
	var idx := 0
	# 6 面：法線の軸 ax、面の中の 2 軸 u, v（u × v = 法線の向き）
	for f in [[0, 1, 2, 1.0], [0, 2, 1, -1.0], [1, 2, 0, 1.0], [1, 0, 2, -1.0], [2, 0, 1, 1.0], [2, 1, 0, -1.0]]:
		var ax: int = f[0]
		var ua: int = f[1]
		var va: int = f[2]
		var sg: float = f[3]
		var cu := _axis_coords(hs[ua], r, ts)
		var cv := _axis_coords(hs[va], r, ts)
		for i in cu.size():
			for j in cv.size():
				var q := Vector3.ZERO
				q[ax] = hs[ax] * sg
				q[ua] = cu[i]
				q[va] = cv[j]
				var c := q.clamp(-inner, inner)
				var n := (q - c).normalized()
				st.set_normal(n)
				st.set_uv(Vector2(float(i) / (cu.size() - 1), float(j) / (cv.size() - 1)))
				st.add_vertex(c + n * r)
		for i in cu.size() - 1:
			for j in cv.size() - 1:
				var a := idx + i * cv.size() + j
				var b := a + cv.size()
				# u × v が法線と同じ向きなら (a, b, b+1, a+1) が外から見て反時計回り
				var e_u := Vector3.ZERO
				e_u[ua] = 1.0
				var e_v := Vector3.ZERO
				e_v[va] = 1.0
				var nn := Vector3.ZERO
				nn[ax] = sg
				if e_u.cross(e_v).dot(nn) > 0.0:
					_quad(st, a, b, b + 1, a + 1)
				else:
					_quad(st, a, a + 1, b + 1, b)
		idx += cu.size() * cv.size()
	var m := st.commit()
	_shared[key] = m
	return m


static func _axis_coords(h: float, r: float, ts: Array) -> Array[float]:
	var out: Array[float] = []
	for t in ts:
		out.append(-h + r * float(t))
	for k in range(ts.size() - 1, -1, -1):
		out.append(h - r * float(ts[k]))
	return out


func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 48
	t.ring_segments = 16
	return t


func _cap(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 24
	c.rings = 8
	return c


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
				body.add_child(_mesh(_sphere(0.1 + randf() * 0.05), prop(Color("f4fbff"), 0.8), p))
		"tray":
			body.add_child(_mesh(_cyl(0.5, 0.46, 0.05), prop(Color("c8ced6")), Vector3(0, 1.02, 0)))
			body.add_child(_mesh(_cyl(0.08, 0.07, 0.2), prop(Color("ffcf5a")), Vector3(0.15, 1.14, 0)))
		"receipt":
			var rm := _mesh(_box(Vector3(0.14, 0.02, 0.5)), prop(Color("fffaf2")), Vector3(0.35, 0.05, -0.35))
			rm.rotation = Vector3(0.3, 0.6, 0)
			body.add_child(rm)
		"pan":
			body.add_child(_mesh(_cyl(0.22, 0.2, 0.06), prop(Color("4a4a52")), Vector3(0.62, 0.45, 0.1)))
			body.add_child(_mesh(_sphere(0.08), prop(Color("ffd66b")), Vector3(0.62, 0.49, 0.1)))
		"box":
			body.add_child(_mesh(_box(Vector3(1.26, 0.45, 1.22)), prop(Color("d9a86c")), Vector3(0, 0.12, 0)))
		"lantern":
			body.add_child(_mesh(_box(Vector3(0.18, 0.26, 0.18)), prop(Color("ff9a4d"), 0.3, 1.5), Vector3(0.6, 0.55, 0.1)))
		"kirari":
			for i in 5:
				var a := TAU * i / 5.0
				body.add_child(_mesh(_cyl(0.0, 0.07, 0.22), prop(Color("ffe27a"), 0.3, 0.8), Vector3(cos(a) * 0.22, 1.08, sin(a) * 0.22)))
		"nemuri":
			var cm := _mesh(_cyl(0.0, 0.42, 0.6), prop(Color("5b6fc2")), Vector3(0.05, 1.05, 0))
			cm.rotation.z = -0.35
			body.add_child(cm)


func _process(delta: float) -> void:
	_t += delta
	if bob:
		body.position.y = sin(_t * 2.0) * 0.06
		body.rotation.y = sin(_t * 0.7) * 0.25
		body.scale = Vector3(1.0 + sin(_t * 4.0) * 0.015, 1.0 - sin(_t * 4.0) * 0.015, 1.0)
	# まばたき：なめらかに閉じて開く。間はばらつかせる
	_blink -= delta
	if _blink < -_next_blink:
		_blink = BLINK_TIME
		_next_blink = randf_range(2.2, 4.8)
	var k := 0.0
	if _blink > 0.0:
		k = sin((1.0 - _blink / BLINK_TIME) * PI)
		k = k * k * (3.0 - 2.0 * k)
	for e in eyes:
		e.scale.y = lerpf(EYE_SCALE.y, 0.1, k)
	var sh := get_node_or_null("ContactShadow") as Node3D
	if sh:
		var lift := clampf(body.position.y, 0.0, 0.3)
		sh.scale = Vector3.ONE * (1.0 - lift * 1.2)
