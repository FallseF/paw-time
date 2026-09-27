class_name OrbContents
extends RefCounted
## 光る玉の中身の形：丸まって眠る子猫おばけ・島の材料 6 種・服（台にのせる）・乗り物。
## どれも大きさ約 1（横幅がだいたい 1〜1.4）、中心がだいたい原点、正面が +Z で返す。
## 孵化で出すときはそのまま（Drops.make_icon）、玉の中では OrbModel が縮めて restyle() で自ら光らせる。
##   var n := OrbContents.build({"kind": "material", "id": "shell"})
##   var cat := OrbContents.sleeper(Color("4fb3f0"))

const CURL := "res://assets/orb/cat_obake_curl.glb"
const CURL_LO := "res://assets/orb/cat_obake_curl_lo.glb"
const SKIN_SHADER := preload("res://shaders/character.gdshader")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")
## 旧いセーブの材料の id → いまの 6 種
const LEGACY_MAT := {"driftwood": "wood", "pebble": "stone", "moss": "seed", "seaglass": "stone"}
## 猫の中身の、この距離より遠い玉は粗い形にする（すくいの画面の玉は遠いので粗い形、孵化・大写しは細かい形）
const LOD_DIST := 3.4

static var _mesh := {}
static var _mats := {}
static var _minis := {}


# ---------------------------------------------------------------- 眠る子猫

## Blender で作った丸まった体（body / tail）。lo=true で粗い形
static func curl_meshes(lo := false) -> Dictionary:
	var key := "curl_lo" if lo else "curl"
	if _mesh.has(key):
		return _mesh[key]
	var parts := {}
	var inst := (load(CURL_LO if lo else CURL) as PackedScene).instantiate()
	for n in inst.find_children("*", "MeshInstance3D", true, false):
		parts[String(n.name).to_lower()] = (n as MeshInstance3D).mesh
	inst.free()
	_mesh[key] = parts
	return parts


## 丸まって眠る子猫おばけ。足元が y=0、高さ約 1.1、横幅約 1.4（前に巻いた尻尾まで）。
## lod=true なら、近くは細かい形・遠くは粗い形を距離で切りかえる（顔の線も遠くでは消す）
static func sleeper(col: Color, lod := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Sleeper"
	var mat := Obake3D.skin(col, 0.0, null, 0.25, 0.35)
	for lo in ([false, true] if lod else [false]):
		var parts := curl_meshes(lo)
		for k in ["body", "tail"]:
			if not parts.has(k):
				continue
			var mi := MeshInstance3D.new()
			mi.name = k.capitalize() + ("Lo" if lo else "")
			mi.mesh = parts[k]
			mi.material_override = mat
			if lod:
				if lo:
					mi.visibility_range_begin = LOD_DIST
				else:
					mi.visibility_range_end = LOD_DIST
			root.add_child(mi)
	# 閉じた目・ほっぺ・鼻・口（ひげは小さすぎてちらつくので付けない）
	var tmp := Obake3D.new()
	var f := tmp.face(Vector3(0, 0.5, 0), 1.0, Obake3D.INK, true)
	tmp.free()
	var drop: Array = []
	for c in f.get_children():
		var mi := c as MeshInstance3D
		if mi and _is_whisker(mi.mesh):
			drop.append(mi)
		elif mi and lod:
			mi.visibility_range_end = LOD_DIST
	for c in drop:
		f.remove_child(c)
		c.free()
	root.add_child(f)
	# 顔を少しうつむかせ、横に傾けて「寝ている」姿勢に
	root.rotation = Vector3(0.12, 0.0, 0.1)
	return root


static func _is_whisker(m: Mesh) -> bool:
	for k in Obake3D._patches:
		if String(k).begins_with("whisker/") and Obake3D._patches[k] == m:
			return true
	return false


# ---------------------------------------------------------------- 材料・服・乗り物

## 中身の辞書（drops.gd の {"kind", "id"}）から形を作る。おばネコなら眠る子猫（色は col）
static func build(c: Dictionary, col := Color("fff1c8"), lod := false) -> Node3D:
	match c.get("kind", "obake"):
		"material":
			return material(String(c.get("id", "wood")))
		"cloth":
			return cloth(String(c.get("id", "")))
		"vehicle":
			var n := Node3D.new()
			var v := VehicleProps.build_vehicle(String(c.id))
			v.scale = Vector3.ONE * 0.45
			v.position.y = -0.2
			n.add_child(v)
			return n
	return sleeper(col, lod)


## 島の材料（wood / stone / seed / paper / shell / cloth）。古い id は近いものに読みかえる
static func material(id: String) -> Node3D:
	id = LEGACY_MAT.get(id, id)
	var root := Node3D.new()
	root.name = "mat_" + id
	var col := Color(IslandKit.MATERIALS[id].color) if IslandKit.MATERIALS.has(id) else Color("b07a4a")
	match id:
		"wood":
			_wood(root, col)
		"stone":
			_stone(root, col)
		"seed":
			_seed(root, col)
		"paper":
			_paper(root, col)
		"shell":
			_shell(root, col)
		"cloth":
			_cloth_bolt(root, col)
		_:
			_add(root, Obake3D.rbox(Vector3(0.6, 0.4, 0.5), 0.06), Obake3D.prop(col))
	return root


static func _add(p: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	p.add_child(mi)
	return mi


static func _sph(r: float, seg := 24) -> SphereMesh:
	var key := "sph/%s/%d" % [r, seg]
	if not _mesh.has(key):
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = seg
		s.rings = seg / 2
		_mesh[key] = s
	return _mesh[key]


## 丸太：樹皮の胴、切り口は明るい木目の輪、小枝と若葉
static func _wood(root: Node3D, col: Color) -> void:
	var bark := col.darkened(0.25)
	var cut := Color("e8c38e")
	var log := Node3D.new()
	log.rotation = Vector3(0.0, 0.55, PI * 0.5)
	root.add_child(log)
	_add(log, Obake3D.lathe(0.27, 0.3, 0.86, 28, 0.05), Obake3D.prop(bark, 0.3))
	# 切り口（両端）：明るい面と、年輪の細い輪
	for sy in [-1.0, 1.0]:
		var face := Node3D.new()
		face.position = Vector3(0, sy * 0.43, 0)
		face.rotation.x = 0.0 if sy > 0 else PI
		log.add_child(face)
		var r0 := 0.27 if sy > 0 else 0.3
		_add(face, Obake3D.lathe(r0 * 0.86, r0 * 0.86, 0.03, 28, 0.01), Obake3D.prop(cut, 0.2), Vector3(0, 0.005, 0))
		for k in 2:
			var rr := r0 * (0.3 + k * 0.28)
			var tm := TorusMesh.new()
			tm.inner_radius = rr - 0.012
			tm.outer_radius = rr
			tm.rings = 28
			tm.ring_segments = 6
			_add(face, tm, Obake3D.prop(col.darkened(0.05), 0.1), Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1, 0.3, 1))
	# 小枝と若葉
	var twig := Obake3D.tube("orb_twig", PackedVector3Array([Vector3(0.0, 0.1, 0.24), Vector3(0.05, 0.2, 0.34), Vector3(0.12, 0.28, 0.4)]), PackedFloat32Array([0.035, 0.028, 0.02]), 10)
	_add(root, twig, Obake3D.prop(bark, 0.3), Vector3(-0.05, 0.12, -0.1))
	var leaf := Obake3D.prop(Color("7cc46a"), 0.35)
	_add(root, _sph(0.08, 16), leaf, Vector3(0.1, 0.43, 0.3), Vector3(0.3, 0.0, -0.6), Vector3(1.6, 0.35, 0.9))
	_add(root, _sph(0.065, 16), leaf, Vector3(0.0, 0.42, 0.24), Vector3(-0.2, 0.0, 0.7), Vector3(1.5, 0.35, 0.9))


## 川の小石を 3 つ積んだもの（下ほど大きく、少しずつずらす）
static func _stone(root: Node3D, col: Color) -> void:
	var cols := [col.lightened(0.05), col.lightened(0.2).lerp(Color("c9d6e8"), 0.2), col.lightened(0.35)]
	var y := -0.3
	var sizes := [0.36, 0.27, 0.19]
	for i in 3:
		var r: float = sizes[i]
		var h: float = r * 0.52
		y += h * 0.9
		_add(root, _sph(r, 32), Obake3D.prop(cols[i], 0.35), Vector3((i - 1) * 0.04, y, i * 0.02), Vector3(0.0, i * 0.9, (i - 1) * 0.12), Vector3(1.0, 0.55, 0.85))
		y += h * 0.9
	# 苔のひとつまみ
	_add(root, _sph(0.06, 12), Obake3D.prop(Color("7fb35f"), 0.3), Vector3(0.22, -0.2, 0.18), Vector3.ZERO, Vector3(1.4, 0.5, 1.0))


## 花の種：割れた大きな種から双葉とつぼみが出ている。まわりに小さな種
static func _seed(root: Node3D, col: Color) -> void:
	var husk := Color("c08a5c")
	_add(root, _sph(0.3, 28), Obake3D.prop(husk, 0.3), Vector3(0, -0.12, 0), Vector3(0.2, 0.0, 0.25), Vector3(0.9, 1.15, 0.9))
	# 割れ目の明るい中身
	_add(root, _sph(0.17, 20), Obake3D.prop(Color("f4e2b8"), 0.2), Vector3(0.0, 0.12, 0.05), Vector3.ZERO, Vector3(1.0, 0.45, 1.0))
	var stem := Obake3D.tube("orb_sprout", PackedVector3Array([Vector3(0, 0.1, 0.03), Vector3(0.02, 0.28, 0.03), Vector3(-0.02, 0.44, 0.02)]), PackedFloat32Array([0.03, 0.025, 0.02]), 10)
	_add(root, stem, Obake3D.prop(col.darkened(0.15), 0.3))
	var leaf := Obake3D.prop(col, 0.35)
	_add(root, _sph(0.1, 16), leaf, Vector3(-0.12, 0.38, 0.03), Vector3(0.0, 0.0, 0.5), Vector3(1.5, 0.35, 0.8))
	_add(root, _sph(0.1, 16), leaf, Vector3(0.12, 0.42, 0.03), Vector3(0.0, 0.0, -0.5), Vector3(1.5, 0.35, 0.8))
	# つぼみ（花の種らしく、ピンクの先）
	_add(root, _sph(0.06, 14), Obake3D.prop(Color("ff8fb1"), 0.35), Vector3(-0.02, 0.5, 0.02), Vector3.ZERO, Vector3(0.9, 1.2, 0.9))
	for i in 2:
		var sx := -1.0 if i == 0 else 1.0
		_add(root, _sph(0.09, 14), Obake3D.prop(husk.darkened(0.1), 0.3), Vector3(sx * 0.32, -0.3, 0.1), Vector3(0.0, 0.0, sx * 0.9), Vector3(0.75, 1.2, 0.75))


## ちょうちん紙：小さな紙のちょうちん（竹の骨、上下の黒い輪、ほんのり灯る）
static func _paper(root: Node3D, col: Color) -> void:
	var paper := Color("fff4e2").lerp(col, 0.45)
	_add(root, _sph(0.3, 28), Obake3D.prop(paper, 0.4, 0.35), Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.15, 1.0))
	var rib := Obake3D.prop(col.darkened(0.12), 0.2)
	for k in 4:
		var yy := -0.21 + k * 0.14
		var rr := 0.3 * sqrt(maxf(1.0 - pow(yy / 0.345, 2.0), 0.0)) + 0.002
		var tm := TorusMesh.new()
		tm.inner_radius = rr - 0.005
		tm.outer_radius = rr + 0.004
		tm.rings = 32
		tm.ring_segments = 6
		_add(root, tm, rib, Vector3(0, yy, 0))
	var cap := Obake3D.prop(Color("3a2e3c"), 0.3)
	_add(root, Obake3D.lathe(0.13, 0.15, 0.07, 24, 0.02), cap, Vector3(0, 0.34, 0))
	_add(root, Obake3D.lathe(0.15, 0.13, 0.07, 24, 0.02), cap, Vector3(0, -0.34, 0))
	var loop := TorusMesh.new()
	loop.inner_radius = 0.035
	loop.outer_radius = 0.055
	_add(root, loop, cap, Vector3(0, 0.41, 0), Vector3(PI * 0.5, 0, 0))


## 貝がら：ほたて形（放射状のすじ）を正面に向けて立てる
static func _shell(root: Node3D, col: Color) -> void:
	var s := Node3D.new()
	s.rotation = Vector3(-1.25, 0.0, PI)
	s.position = Vector3(0, 0.02, 0)
	root.add_child(s)
	_add(s, _scallop(), Obake3D.prop(col, 0.45))
	# 付け根の耳
	var ear := Obake3D.prop(col.darkened(0.1), 0.3)
	for sx in [-1.0, 1.0]:
		_add(s, Obake3D.rbox(Vector3(0.12, 0.05, 0.1), 0.02), ear, Vector3(sx * 0.07, 0.02, -0.3), Vector3(0, sx * 0.3, 0))
	# 小さな真珠
	_add(root, _sph(0.06, 16), Obake3D.metal(Color("fff4f0")), Vector3(0.24, -0.26, 0.16))


## ほたての殻（上下 2 枚の合わさった形。蝶番は -Z、開きは +Z）。すじは 11 本
static func _scallop() -> ArrayMesh:
	if _mesh.has("scallop"):
		return _mesh.scallop
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nu := 66
	var nv := 14
	var R := 0.46
	var spread := 1.25
	var rows := []
	for half in 2:
		var sg := 1.0 if half == 0 else -1.0
		var dome := 0.2 if half == 0 else 0.07
		for j in nv + 1:
			var v := float(j) / nv
			for i in nu + 1:
				var u := -1.0 + 2.0 * i / nu
				var a := u * spread
				var rad := v * R * (1.0 - 0.06 * pow(absf(u), 3.0))
				var ridge := 0.022 * v * pow(absf(cos(u * 5.5 * PI)), 0.6)
				var y := sg * (dome * sin(v * PI * 0.92) * (1.0 - 0.35 * u * u) + ridge * (1.0 if half == 0 else 0.5))
				st.add_vertex(Vector3(sin(a) * rad, y, -R * 0.62 + cos(a) * rad))
		rows.append(half)
	var per := (nu + 1) * (nv + 1)
	for half in 2:
		var base := half * per
		for j in nv:
			for i in nu:
				var a := base + j * (nu + 1) + i
				var b := a + nu + 1
				if half == 0:
					for id in [a, a + 1, b, a + 1, b + 1, b]:
						st.add_index(id)
				else:
					for id in [a, b, a + 1, a + 1, b, b + 1]:
						st.add_index(id)
	st.generate_normals()
	var m := st.commit()
	_mesh.scallop = m
	return m


## 布：たたんだ布を 3 枚重ね、リボンで結んだもの
static func _cloth_bolt(root: Node3D, col: Color) -> void:
	var cols := [col.darkened(0.12), Color("ffd9c8"), col.lightened(0.15)]
	for i in 3:
		var sz := Vector3(0.66 - i * 0.05, 0.13, 0.46 - i * 0.03)
		_add(root, Obake3D.rbox(sz, 0.05), Obake3D.prop(cols[i], 0.35), Vector3(i * 0.02 - 0.02, -0.18 + i * 0.13, 0.0), Vector3(0, (i - 1) * 0.1, 0))
	var ribbon := Obake3D.prop(Color("e8575b"), 0.35)
	_add(root, Obake3D.rbox(Vector3(0.07, 0.43, 0.5), 0.03), ribbon, Vector3(0.04, -0.05, 0.0))
	for sx in [-1.0, 1.0]:
		_add(root, _sph(0.07, 14), ribbon, Vector3(0.04 + sx * 0.07, 0.19, 0.12), Vector3(0, 0, sx * 0.6), Vector3(1.4, 0.8, 0.5))


## 服：キセカエの形をそのまま組んで、小さな丸い台の上に浮かべる
static func cloth(id: String) -> Node3D:
	var root := Node3D.new()
	root.name = "cloth_" + id
	var it := WardrobeData.item(id)
	if it.is_empty():
		_cloth_bolt(root, Color("ff8fb1"))
		return root
	var tmp := Obake3D.new()
	var item := Outfit.build(tmp, it)
	tmp.free()
	# 形の広がりから、台の上で約 0.8 の大きさ・中心がそろうように
	var box := _aabb(item)
	var k := 0.95 / maxf(maxf(box.size.x, box.size.y), maxf(box.size.z, 0.01))
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * k
	holder.position = -box.get_center() * k + Vector3(0, 0.08, 0)
	holder.add_child(item)
	# 輪の形の服（冠・首輪）も読めるよう、少し手前へ傾ける
	var tilt := Node3D.new()
	tilt.rotation.x = 0.35
	tilt.add_child(holder)
	root.add_child(tilt)
	# 台：淡いピンクの丸い台と、金の縁
	var base_y := -box.size.y * k * 0.5 + 0.08 - 0.08
	_add(root, Obake3D.lathe(0.3, 0.34, 0.07, 32, 0.025), Obake3D.prop(Color("ffe3ec"), 0.4), Vector3(0, base_y, 0))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.315
	rim.outer_radius = 0.345
	rim.rings = 36
	rim.ring_segments = 6
	_add(root, rim, Obake3D.metal(Color("f2c14e")), Vector3(0, base_y + 0.025, 0))
	return root


static func _aabb(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var t := Transform3D.IDENTITY
		var p: Node = mi
		while p != null and p != n:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		var b := t * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


# ---------------------------------------------------------------- 玉の中身（まとめて軽く）

## 玉の中に入れる中身。restyle() で塗り、同じ材質の部品を 1 つのメッシュにまとめる（描く回数を減らす）。
## 同じ中身・同じ光の色なら、まとめたメッシュを使い回す。
static func mini(c: Dictionary, cat_col: Color, glow: Color, self_light: float) -> Node3D:
	var key := "%s/%s/%s/%s/%s" % [c.get("kind", "obake"), c.get("id", ""), cat_col.to_html(), glow.to_html(), self_light]
	if not _minis.has(key):
		var src := build(c, cat_col, true)
		restyle(src, glow, self_light)
		_minis[key] = _merge(src)
		src.free()
	var root := Node3D.new()
	root.name = "Mini"
	for g in _minis[key]:
		var mi := MeshInstance3D.new()
		mi.mesh = g.mesh
		mi.material_override = g.mat
		mi.visibility_range_begin = g.vis.x
		mi.visibility_range_end = g.vis.y
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root


## 部品を「材質・見える距離」ごとに 1 つのメッシュへ焼き込む。
## 大きな部品（形の輪郭になるもの）だけ輪郭の線を残し、小さな部品の線は省く（遠くでは見えず、描く回数だけ増える）
static func _merge(src: Node3D) -> Array:
	var groups := {}
	var order: Array = []
	var total := _aabb(src)
	var big := maxf(total.size.x, maxf(total.size.y, total.size.z))
	for m in src.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.visible:
			continue
		var t := Transform3D.IDENTITY
		var p: Node = mi
		while p != null and p != src:
			t = (p as Node3D).transform * t
			p = p.get_parent()
		t = src.transform * t
		var mat := mi.material_override
		var vis := Vector2(mi.visibility_range_begin, mi.visibility_range_end)
		var k := "%d/%s" % [mat.get_instance_id() if mat else 0, vis]
		if not groups.has(k):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			groups[k] = {"st": st, "mat": mat, "vis": vis, "box": AABB(), "n": 0}
			order.append(k)
		var g: Dictionary = groups[k]
		for si in mi.mesh.get_surface_count():
			(g.st as SurfaceTool).append_from(mi.mesh, si, t)
		var b := t * mi.get_aabb()
		g.box = b if g.n == 0 else (g.box as AABB).merge(b)
		g.n += 1
	var out: Array = []
	for k in order:
		var g: Dictionary = groups[k]
		var mat: Material = g.mat
		var gb: AABB = g.box
		if mat and mat.next_pass and maxf(gb.size.x, maxf(gb.size.y, gb.size.z)) < big * 0.45:
			var key := "noline/%d" % mat.get_instance_id()
			if not _mats.has(key):
				var d := mat.duplicate() as Material
				d.next_pass = null
				_mats[key] = d
			mat = _mats[key]
		out.append({"mesh": (g.st as SurfaceTool).commit(), "mat": mat, "vis": g.vis})
	return out


# ---------------------------------------------------------------- 玉の中での塗り

## 玉の中に入れるときの塗り：自分の光でほんのり明るく（夜でも形と色が読める）、縁は玉の光の色、
## 輪郭は小さな形に合わせて細く。同じ材質・同じ光の色なら使い回す。
static func restyle(n: Node, glow: Color, self_light := 0.3) -> void:
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var src := mi.material_override as ShaderMaterial
		if src == null or src.shader != SKIN_SHADER:
			continue
		var key := "%d/%s/%s" % [src.get_instance_id(), glow.to_html(), self_light]
		if not _mats.has(key):
			var d := src.duplicate() as ShaderMaterial
			var base: Color = src.get_shader_parameter("base_color")
			var e0 = src.get_shader_parameter("emission_energy")
			d.set_shader_parameter("emission_energy", maxf(float(e0) if e0 != null else 0.0, self_light))
			d.set_shader_parameter("rim_color", glow.lerp(Color.WHITE, 0.35))
			d.set_shader_parameter("rim_strength", 0.9)
			d.set_shader_parameter("rim_power", 2.4)
			d.set_shader_parameter("shadow_tint", base.lerp(glow, 0.35).darkened(0.1))
			if src.next_pass:
				var o := ShaderMaterial.new()
				o.shader = OUTLINE_SHADER
				o.set_shader_parameter("color", Obake3D.line_color(base))
				o.set_shader_parameter("width", 0.0016)
				d.next_pass = o
			_mats[key] = d
		mi.material_override = _mats[key]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
