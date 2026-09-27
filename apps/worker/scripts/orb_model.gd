class_name OrbModel
extends Node3D
## 光る玉の見た目。厚い透明なガラスの殻の中に、本物の小さな中身が浮かんでゆっくり回る。
##   おばネコ：丸まって眠る子猫おばけ（寝息でふくらむ）。材料：その材料の小さな形。服：丸い台にのった服。
## 中身の後ろで、仕事の色の霧が渦を巻く（中身を塗りつぶさない）。種類は縁の色で分かる：
##   おばネコ＝金の縁・金の細い筋・まわりを回る金の粒、材料＝青白い縁、服＝淡いピンクの縁。
## color: 仕事の色。rare: 虹色に流れ、粒が回る。radius: 殻の半径（既定 0.17）。
##   var m := OrbModel.new().setup(col, false)
##   m.set_contents({"kind": "material", "id": "shell"})   # 中身（drops.gd の辞書）
##   await m.hatch_vfx(world, true)                          # 孵化：ひび → 破片と光

const GOLD := Color("ffd76a")
const ACCENT := {"cat": Color("ffd76a"), "material": Color("cfe6ff"), "cloth": Color("ffc4dc"), "vehicle": Color("fff2a8")}
const GLASS_SHADER := preload("res://shaders/orb_glass.gdshader")
const GLASS_BACK_SHADER := preload("res://shaders/orb_glass_back.gdshader")
const CORE_SHADER := preload("res://shaders/orb_core.gdshader")
const BURST_SHADER := preload("res://shaders/orb_burst.gdshader")
## 中身だけが乗る描画の層。玉の光（light）はこの層を照らさない（光が強まっても中身が白飛びしないように。
## 中身は自分でほんのり光り、画面のキーの光で形が出る）
const CONTENTS_LAYER := 11

var radius := 0.17
var light: OmniLight3D
var shell: MeshInstance3D
var shell_back: MeshInstance3D
var core: MeshInstance3D
var core_mat: ShaderMaterial
var shell_mat: ShaderMaterial
var back_mat: ShaderMaterial
## 中身の入れ物（寝息・浮き沈み・回転はこのノードで）。互換のため sleeper とも呼ぶ
var sleeper: Node3D
var contents: Node3D
var motes: MultiMeshInstance3D
var kind := "cat"
var color := Color.WHITE
var _t := 0.0
var rare := false
var _base_scale := 1.0
var _base_y := 0.0

## 共有の形・材質（玉がたくさんあっても作り直さない）
static var _shared := {}


func setup(col: Color, is_rare := false, r := 0.17) -> OrbModel:
	radius = r
	rare = is_rare
	color = col
	_t = randf() * TAU

	# 中身の後ろの霧（奥半分だけ）
	core = MeshInstance3D.new()
	core.mesh = _sphere("core", r * 0.84, 24)
	core_mat = ShaderMaterial.new()
	core_mat.shader = CORE_SHADER
	core_mat.set_shader_parameter("glow", col)
	core_mat.set_shader_parameter("rare", 1.0 if is_rare else 0.0)
	core_mat.set_shader_parameter("seed", randf() * 10.0)
	core.material_override = core_mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)

	sleeper = Node3D.new()
	sleeper.name = "Contents"
	add_child(sleeper)

	# ガラスの殻：奥の面と表の面
	shell_back = MeshInstance3D.new()
	shell_back.mesh = _sphere("shell", r, 40)
	back_mat = ShaderMaterial.new()
	back_mat.shader = GLASS_BACK_SHADER
	back_mat.set_shader_parameter("tint", col)
	shell_back.material_override = back_mat
	shell_back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shell_back)
	shell = MeshInstance3D.new()
	shell.mesh = shell_back.mesh
	shell_mat = ShaderMaterial.new()
	shell_mat.shader = GLASS_SHADER
	shell_mat.set_shader_parameter("tint", col.lightened(0.35))
	shell_mat.set_shader_parameter("rare", 1.0 if is_rare else 0.0)
	shell_mat.set_shader_parameter("seed", randf() * 10.0)
	shell.material_override = shell_mat
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shell.sorting_offset = r * 2.0
	add_child(shell)

	# まわり（水面・床）を照らす光。中身は照らさない（CONTENTS_LAYER）
	light = OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.1
	light.omni_range = r * 7.0
	light.position = Vector3(0, r * 0.2, 0)
	light.light_cull_mask &= ~(1 << (CONTENTS_LAYER - 1))
	add_child(light)

	if is_rare:
		_add_motes(Color("fff4d6"), 7)
	return self


func _ready() -> void:
	# 中身を入れずに置いた玉（診断の玉・夢の泡など）は、仕事の色の子猫が眠っている
	if contents == null:
		set_contents({"kind": "obake"}, color.lerp(Color.WHITE, 0.35))


## 中身を入れる。c は drops.gd の中身の辞書（{"kind": "obake"} / {"kind": "material", "id"} / {"kind": "cloth", "id"} ...）。
## cat_col は眠る子猫の色（孵る子の色のヒント）。
func set_contents(c: Dictionary, cat_col := Color("fff1c8")) -> void:
	if contents:
		contents.queue_free()
	var k: String = c.get("kind", "obake")
	kind = "cat" if k == "obake" else k
	contents = OrbContents.mini(c, cat_col, color.lerp(ACCENT.get(kind, Color.WHITE), 0.5), 0.42 if kind == "cat" else 0.45)
	if kind == "cat":
		# 高さ約 1.1・横幅約 1.4 の子猫を、殻の中にゆったり収める
		_base_scale = radius * 1.0
		_base_y = -radius * 0.5
	else:
		_base_scale = radius * 1.08
		_base_y = -radius * 0.04
	contents.scale = Vector3.ONE * _base_scale
	contents.position.y = _base_y
	for m in contents.find_children("*", "GeometryInstance3D", true, false):
		(m as VisualInstance3D).layers = 1 << (CONTENTS_LAYER - 1)
	sleeper.add_child(contents)
	var acc: Color = ACCENT.get(kind, Color("cfe6ff"))
	shell_mat.set_shader_parameter("accent", acc)
	back_mat.set_shader_parameter("accent", acc)
	shell_mat.set_shader_parameter("iridescence", 0.45 if kind == "cloth" else 0.3)


## おばネコの入った玉：金の縁・金の細い筋・まわりを回る金の粒
func mark_cat() -> void:
	shell_mat.set_shader_parameter("accent", GOLD)
	back_mat.set_shader_parameter("accent", GOLD)
	shell_mat.set_shader_parameter("filament", 1.0)
	if motes:
		motes.queue_free()
	_add_motes(GOLD, 6)
	light.omni_range = radius * 8.0


## e は玉の中の光の強さ。light_k はまわりを照らす光の倍率（1 で今までどおり）。
func set_energy(e: float, light_k := 1.0) -> void:
	core_mat.set_shader_parameter("energy", e)
	# まわりを照らす光は頭打ちにする（孵化で光を強めても、床や座布団が白く飛ばないように）
	var x := e * 0.6 * light_k
	light.light_energy = 1.4 * (1.0 - exp(-x / 1.4))


## 殻のひび（0..1）
func set_crack(v: float) -> void:
	shell_mat.set_shader_parameter("crack", v)


func _process(delta: float) -> void:
	_t += delta
	if contents:
		# 中身はふわりと浮き沈みして、ゆっくり回る。子猫は寝息でふくらむ
		var bob := sin(_t * 1.3) * radius * 0.04
		contents.position.y = _base_y + bob
		if kind == "cat":
			var br := sin(_t * 1.7)
			contents.scale = Vector3(_base_scale * (1.0 + br * 0.025), _base_scale * (1.0 + br * 0.045), _base_scale * (1.0 + br * 0.025))
			contents.rotation.y = sin(_t * 0.35) * 0.55
		else:
			# 平たい物（貝・服）も読めるよう、正面を中心にゆらゆら向きを変える
			contents.rotation.y = sin(_t * 0.5) * 0.75
			contents.rotation.z = sin(_t * 0.8) * 0.1
	shell.rotation.y += delta * 0.2
	if motes:
		motes.rotation.y += delta * 1.1
		motes.rotation.x = sin(_t * 0.5) * 0.35
	if rare:
		light.light_color = Color.from_hsv(fmod(_t * 0.2, 1.0), 0.5, 1.0)


# ---------------------------------------------------------------- 孵化

## 孵化：殻にひびが走り（big: 0.34 秒 / 0.12 秒）、割れて破片が飛び、光の筋が広がる。
## ひびが入り切ったところで戻る（破片と光は world に置いたまま、自分で消える。big 約 0.85 秒、ほか約 0.38 秒）。
## 戻ったあとに玉を消して、中身を出す。
func hatch_vfx(world: Node3D, big := false) -> void:
	var tw := create_tween()
	tw.tween_method(set_crack, 0.0, 1.0, 0.34 if big else 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	shatter(world, big)


## 殻が割れる瞬間（破片・光の筋・閃光）。玉そのものは隠す（消すのは呼んだ側）
func shatter(world: Node3D, big := false) -> void:
	var at := global_position
	var s := global_transform.basis.get_scale().x
	var r := radius * s
	var acc: Color = shell_mat.get_shader_parameter("accent")
	var fx := Node3D.new()
	fx.name = "OrbShatter"
	world.add_child(fx)
	fx.global_position = at
	var life := 0.85 if big else 0.38
	# 光の筋と閃光
	var b := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * r * (3.6 if big else 2.4)
	b.mesh = q
	var bm := ShaderMaterial.new()
	bm.shader = BURST_SHADER
	bm.set_shader_parameter("color", color.lerp(acc, 0.6).lerp(Color.WHITE, 0.2))
	bm.set_shader_parameter("strength", 0.8 if big else 0.5)
	bm.set_shader_parameter("rays", 16.0 if big else 10.0)
	bm.set_shader_parameter("seed", randf() * 10.0)
	b.material_override = bm
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(b)
	var tw := fx.create_tween().set_parallel()
	tw.tween_method(func(p: float): bm.set_shader_parameter("progress", p), 0.0, 1.0, life)
	# ガラスの破片：殻の面から外へ飛び、回りながら落ちて、小さくなって消える
	var n := 16 if big else 9
	var shard_mat := _shard_mat(acc)
	for i in n:
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.4, 1), randf_range(-0.3, 1)).normalized()
		var sh := MeshInstance3D.new()
		sh.mesh = _shard_mesh()
		sh.material_override = shard_mat
		sh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var k := r * randf_range(0.28, 0.55)
		sh.scale = Vector3.ONE * k
		sh.position = dir * r * 0.9
		sh.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		fx.add_child(sh)
		var v0 := dir * randf_range(0.8, 1.5) * (1.0 if big else 0.6) * r / 0.17 + Vector3(0, 0.5, 0)
		var spin := Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		var p0 := sh.position
		var r0 := sh.rotation
		tw.tween_method(func(t: float):
			sh.position = p0 + v0 * t + Vector3(0, -3.2, 0) * t * t
			sh.rotation = r0 + spin * t
			sh.scale = Vector3.ONE * k * (1.0 - smoothstep(life * 0.55, life, t)), 0.0, life, life)
	tw.chain().tween_callback(fx.queue_free)
	# 閃光の瞬間、玉の中身も一瞬ふくらむ（中身が出てくる前ぶれ）
	shell.visible = false
	shell_back.visible = false
	core.visible = false
	if motes:
		motes.visible = false
	if contents:
		var tc := create_tween()
		tc.tween_property(contents, "scale", Vector3.ONE * _base_scale * 1.6, 0.08)
	set_process(false)


# ---------------------------------------------------------------- 部品

func _sphere(key: String, r: float, seg: int) -> SphereMesh:
	var k := "%s/%s/%d" % [key, r, seg]
	if not _shared.has(k):
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = seg
		s.rings = seg / 2
		_shared[k] = s
	return _shared[k]


## まわりを回る光の粒（1 回の描画にまとめる）
func _add_motes(col: Color, n: int) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _mote_mesh()
	mm.instance_count = n
	for i in n:
		var a := TAU * i / n + randf() * 0.4
		var rr := radius * randf_range(1.2, 1.4)
		var p := Vector3(cos(a) * rr, randf_range(-0.5, 0.5) * radius, sin(a) * rr)
		var sc := randf_range(0.7, 1.2)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * sc), p))
	motes = MultiMeshInstance3D.new()
	motes.multimesh = mm
	motes.material_override = _mote_mat(col)
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(motes)


func _mote_mesh() -> QuadMesh:
	var k := "mote/%s" % radius
	if not _shared.has(k):
		var q := QuadMesh.new()
		q.size = Vector2.ONE * radius * 0.14
		_shared[k] = q
	return _shared[k]


static func _mote_mat(col: Color) -> StandardMaterial3D:
	var k := "motemat/" + col.to_html()
	if not _shared.has(k):
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.25, Color(1, 1, 1, 0.85))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 32
		tex.height = 32
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		m.billboard_keep_scale = true
		m.albedo_texture = tex
		m.albedo_color = Color(col.r * 1.1, col.g * 1.05, col.b * 0.9)
		m.no_depth_test = false
		_shared[k] = m
	return _shared[k]


## ガラスのかけら：少し反った三角の板（厚みあり）
static func _shard_mesh() -> ArrayMesh:
	if _shared.has("shard"):
		return _shared.shard
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(0, 0.5, 0), Vector3(-0.32, -0.3, 0.06), Vector3(0.36, -0.22, 0.04)]
	var th := Vector3(0, 0, 0.05)
	var tris := [[pts[0], pts[1], pts[2]], [pts[0] - th, pts[2] - th, pts[1] - th]]
	for i in 3:
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[(i + 1) % 3]
		tris.append([a, a - th, b])
		tris.append([b, a - th, b - th])
	for t in tris:
		for p in t:
			st.add_vertex(p)
	st.generate_normals()
	var m := st.commit()
	_shared.shard = m
	return m


static func _shard_mat(acc: Color) -> StandardMaterial3D:
	var k := "shardmat/" + acc.to_html()
	if not _shared.has(k):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(acc.lerp(Color.WHITE, 0.4), 0.42)
		m.metallic_specular = 1.0
		m.roughness = 0.08
		m.rim_enabled = true
		m.rim = 1.0
		m.rim_tint = 0.2
		m.emission_enabled = true
		m.emission = acc
		m.emission_energy_multiplier = 0.35
		_shared[k] = m
	return _shared[k]
