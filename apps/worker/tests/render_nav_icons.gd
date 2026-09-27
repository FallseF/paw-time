extends SceneTree
## 下のタブと丸いボタンのアイコンを、ゲームの 3D 部品（おばネコ・島の置き物・光る玉）から撮る（背景透明）。
## どれも同じ画角・同じ向き・同じ光（Look の studio）で、輪郭は小さく表示しても形が残るよう太く濃くする。
##   godot --path . --always-on-top --resolution 384x384 -s tests/render_nav_icons.gd
## （ウィンドウが隠れると macOS が描画を止めるので --always-on-top を付ける）
## 環境変数: NAV_OUT=出力先（既定は assets/ui/nav）、NAV_IDS=island,jobs,... 一部だけ、
## NAV_LINE=輪郭の太さ（物の大きさに対する割合）、NAV_SIZE=書き出す大きさ（既定はタブ 192・丸いボタン 128）

const SIZE := 384
## 書き出す大きさ（タブは 192、丸いボタンは 128。今までの絵と同じ）
const OUT_SIZE := {"island": 192, "jobs": 192, "scoop": 192, "closet": 192, "book": 192, "goals": 128, "talk": 128, "edit": 128, "cat_face": 128}
const SS := 2
const YAW := 0.55
const PITCH := -22.0
const FOV := 24.0
const MARGIN := 0.035
const INK := Color("2e222f")

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var line_k := 0.022


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_environment("NAV_OUT")
	if out == "":
		out = ProjectSettings.globalize_path("res://assets/ui/nav")
	DirAccess.make_dir_recursive_absolute(out)
	if OS.get_environment("NAV_LINE") != "":
		line_k = float(OS.get_environment("NAV_LINE"))
	var ids: Array = ["island", "jobs", "scoop", "closet", "book", "goals", "talk", "edit", "cat_face"]
	if OS.get_environment("NAV_IDS") != "":
		ids = Array(OS.get_environment("NAV_IDS").split(","))
	vp = SubViewport.new()
	vp.size = Vector2i(SIZE * SS, SIZE * SS)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	Look.apply(world, "studio", Color(0, 0, 0, 0), true)
	cam = Camera3D.new()
	cam.fov = FOV
	world.add_child(cam)
	for id in ids:
		var n: Node3D = call("_b_" + id)
		world.add_child(n)
		for i in 4:
			await process_frame
		_freeze(n)
		_frame(n)
		_ink(n, _size_of(n) * line_k)
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		var sz := int(OS.get_environment("NAV_SIZE")) if OS.get_environment("NAV_SIZE") != "" else int(OUT_SIZE.get(id, SIZE))
		img.resize(sz, sz, Image.INTERPOLATE_LANCZOS)
		img.save_png(out.path_join("%s.png" % id))
		n.queue_free()
		await process_frame
		print("rendered ", id)
	quit()


# ---------------------------------------------------------------- 5 つの絵

func _p(n: Node3D, mesh: Mesh, mat: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	n.add_child(mi)
	return mi


func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 40
	s.rings = 20
	return s


## 島：丸い芝の台（下は砂と岩）に、家と丸い木
func _b_island() -> Node3D:
	var n := Node3D.new()
	n.rotation.y = YAW
	# 芝の台・砂の縁・下の岩（どれも島の色）
	_p(n, Obake3D.lathe(0.86, 0.9, 0.16, 48, 0.06), IslandProps.m(Color("90c362")), Vector3(0, -0.08, 0))
	_p(n, Obake3D.lathe(0.96, 0.92, 0.12, 48, 0.05), IslandProps.m(Color("ffdc89")), Vector3(0, -0.2, 0))
	_p(n, Obake3D.lathe(0.86, 0.45, 0.3, 48, 0.1), IslandProps.m(Color("b9a58f")), Vector3(0, -0.4, 0))
	var hut := IslandProps.build("hut")
	hut.position = Vector3(-0.18, 0.0, 0.0)
	hut.scale = Vector3.ONE * 0.9
	n.add_child(hut)
	var tree := IslandProps.build("tree_round")
	tree.position = Vector3(0.52, 0.0, -0.3)
	tree.scale = Vector3.ONE * 0.8
	n.add_child(tree)
	return n


## 仕事：エプロンを着けたおばネコ
func _b_jobs() -> Node3D:
	var n := Node3D.new()
	var ob := Obake3D.make("tray")
	ob.bob = false
	ob.contact_shadow = false
	ob.rotation.y = YAW * 0.55
	n.add_child(ob)
	var prop := ob.body.get_node_or_null("Prop") as Node3D
	if prop:
		prop.visible = false
	# 胸の前に持つ仕事カード（クリームの紙に橙のエプロン）
	var card := Node3D.new()
	card.position = Vector3(0.0, 0.17, 0.58)
	card.rotation = Vector3(-0.18, 0, 0.1)
	ob.body.add_child(card)
	_p(card, Obake3D.rbox(Vector3(0.62, 0.44, 0.05), 0.03), IslandProps.m(Color("fff4e2")))
	var or_c := IslandProps.m(Color("f28a3c"))
	_p(card, Obake3D.rbox(Vector3(0.26, 0.2, 0.03), 0.05), or_c, Vector3(0, -0.06, 0.035))
	_p(card, Obake3D.rbox(Vector3(0.13, 0.1, 0.03), 0.02), or_c, Vector3(0, 0.08, 0.035))
	return n


## すくう：ポイの上に光る玉
func _b_scoop() -> Node3D:
	var n := Node3D.new()
	n.rotation.y = YAW
	var r := 0.5
	var root := n
	# ポイは少しこちらへ傾けて、網の丸が見えるように（水の輪は水平のまま）
	n = Node3D.new()
	n.rotation.x = 0.5
	n.position.y = 0.1
	root.add_child(n)
	var t := TorusMesh.new()
	t.inner_radius = r - 0.07
	t.outer_radius = r + 0.03
	t.rings = 48
	t.ring_segments = 16
	_p(n, t, IslandProps.m(Color("e85a4f")))
	var film := Obake3D.lathe(r - 0.02, r - 0.02, 0.01, 48, 0.0)
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color("cfe6f5")
	_p(n, film, fm, Vector3(0, 0.0, 0))
	# 柄は付けない（小さいと虫眼鏡に見える）。代わりに水の輪としぶき
	var w := TorusMesh.new()
	w.inner_radius = r + 0.1
	w.outer_radius = r + 0.17
	w.rings = 48
	w.ring_segments = 12
	var water := IslandProps.m(Color("7fd0e6"))
	_p(root, w, water, Vector3(0, -0.12, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
	for d in [[-0.62, 0.3, 0.2, 0.07], [0.66, 0.36, 0.05, 0.06], [-0.45, 0.5, -0.1, 0.045], [0.5, 0.56, 0.2, 0.04]]:
		_p(root, _sph(d[3]), water, Vector3(d[0], d[1], d[2]), Vector3.ZERO, Vector3(1, 1.25, 1))
	# 玉（ゲームの光る玉：おばネコ入りの金の玉）
	var orb := OrbModel.new().setup(Color("ffd23f"), false)
	orb.position = Vector3(0, 0.3, 0)
	orb.scale = Vector3.ONE * 1.55
	n.add_child(orb)
	orb.set_contents({"kind": "obake"}, Color("fff1c8"))
	orb.mark_cat()
	orb.sleeper.visible = false
	if orb.motes:
		orb.motes.visible = false
	# 背景が透明だと、ガラス越しの光が暗く抜ける。中に不透明な光の芯を入れる
	_p(orb, _sph(0.166), Obake3D.skin(Color("ffc94d"), 0.35, null, 0.2, 0.0, true))
	orb.set_energy(3.2, 1.0)
	return root


## キセカエ：ハンガーに掛かった服
func _b_closet() -> Node3D:
	var n := Node3D.new()
	n.rotation.y = YAW * 0.45
	var wood := IslandProps.m(Color("c08a5c"))
	# ハンガーの肩（なめらかな管）とフック
	_p(n, Obake3D.tube("nav_hanger", PackedVector3Array([Vector3(-0.62, 0.62, 0), Vector3(-0.3, 0.8, 0), Vector3(0, 0.9, 0), Vector3(0.3, 0.8, 0), Vector3(0.62, 0.62, 0)]), PackedFloat32Array([0.04, 0.045, 0.05, 0.045, 0.04])), wood)
	_p(n, Obake3D.tube("nav_hook", PackedVector3Array([Vector3(0, 0.9, 0), Vector3(0, 1.05, 0), Vector3(0.1, 1.18, 0), Vector3(0.0, 1.27, 0), Vector3(-0.1, 1.18, 0)]), PackedFloat32Array([0.025, 0.025, 0.025, 0.025, 0.025])), Obake3D.metal(Color("c9c3cf")))
	# 服（セーターの色：ゲームのキセカエの桃色）
	var c := Color("f4a3b8")
	var cloth := IslandProps.m(c)
	_p(n, Obake3D.rbox(Vector3(0.9, 0.9, 0.2), 0.08), cloth, Vector3(0, 0.2, 0))
	for sx in [-1.0, 1.0]:
		_p(n, Obake3D.rbox(Vector3(0.42, 0.26, 0.18), 0.07), cloth, Vector3(sx * 0.55, 0.47, 0), Vector3(0, 0, sx * -0.55))
	# 襟ぐり
	_p(n, Obake3D.rbox(Vector3(0.34, 0.1, 0.22), 0.04), IslandProps.m(Color("fff4e2")), Vector3(0, 0.64, 0.01))
	return n


## 図鑑：表紙に肉球の本
func _b_book() -> Node3D:
	var n := Node3D.new()
	n.rotation = Vector3(0, YAW * 0.6, 0)
	var cover := Color("9b82ea")
	_p(n, Obake3D.rbox(Vector3(0.95, 1.2, 0.26), 0.05), IslandProps.m(Color("fff4e2")), Vector3(0.03, 0, 0))
	_p(n, Obake3D.rbox(Vector3(1.0, 1.26, 0.07), 0.03), IslandProps.m(cover), Vector3(0, 0, 0.15))
	_p(n, Obake3D.rbox(Vector3(1.0, 1.26, 0.07), 0.03), IslandProps.m(cover), Vector3(0, 0, -0.15))
	_p(n, Obake3D.rbox(Vector3(0.1, 1.26, 0.37), 0.04), IslandProps.m(cover), Vector3(-0.48, 0, 0))
	# 肉球（表紙の上に少し浮かせる）
	var paw := IslandProps.m(Color("fff4e2"))
	_p(n, _sph(0.2), paw, Vector3(0.05, -0.12, 0.19), Vector3.ZERO, Vector3(1.1, 0.9, 0.18))
	var toes := [Vector3(-0.2, 0.14, 0), Vector3(-0.05, 0.26, 0), Vector3(0.15, 0.26, 0), Vector3(0.3, 0.14, 0)]
	for p in toes:
		_p(n, _sph(0.075), paw, Vector3(p.x, p.y, 0.19), Vector3.ZERO, Vector3(1, 1.15, 0.2))
	return n


## 目標：チェックの付いたクリップボード
func _b_goals() -> Node3D:
	var n := Node3D.new()
	n.rotation = Vector3(0, YAW * 0.6, 0)
	_p(n, Obake3D.rbox(Vector3(1.0, 1.3, 0.08), 0.04), IslandProps.m(Color("c08a5c")))
	_p(n, Obake3D.rbox(Vector3(0.82, 1.08, 0.03), 0.02), IslandProps.m(Color("fff4e2")), Vector3(0, -0.06, 0.055))
	_p(n, Obake3D.rbox(Vector3(0.42, 0.16, 0.12), 0.05), Obake3D.metal(Color("c9c3cf")), Vector3(0, 0.62, 0.05))
	for i in 3:
		var y := 0.26 - i * 0.3
		var done := i < 2
		_p(n, _sph(0.08), IslandProps.m(Color("7cc46a") if done else Color("e6dccf")), Vector3(-0.24, y, 0.08), Vector3.ZERO, Vector3(1, 1, 0.4))
		_p(n, Obake3D.rbox(Vector3(0.36, 0.07, 0.02), 0.02), IslandProps.m(Color("9b82ea")), Vector3(0.12, y, 0.075))
	return n


## 話す：おばネコと吹き出し
func _b_talk() -> Node3D:
	var n := Node3D.new()
	var ob := Obake3D.make("tray")
	ob.bob = false
	ob.contact_shadow = false
	ob.rotation.y = YAW * 0.4
	ob.position = Vector3(-0.2, 0, 0)
	n.add_child(ob)
	var prop := ob.body.get_node_or_null("Prop") as Node3D
	if prop:
		prop.visible = false
	var b := Node3D.new()
	b.position = Vector3(0.55, 1.05, 0.1)
	b.rotation.y = YAW * 0.4
	n.add_child(b)
	var cream := IslandProps.m(Color("fff4e2"))
	_p(b, _sph(0.3), cream, Vector3.ZERO, Vector3.ZERO, Vector3(1.25, 0.9, 0.45))
	_p(b, _sph(0.09), cream, Vector3(-0.24, -0.22, 0), Vector3.ZERO, Vector3(1, 1, 0.6))
	for x in [-0.14, 0.0, 0.14]:
		_p(b, _sph(0.045), IslandProps.m(Color("9b82ea")), Vector3(x, 0, 0.13))
	return n


## 編集：えんぴつ
func _b_edit() -> Node3D:
	var n := Node3D.new()
	var p := Node3D.new()
	p.rotation = Vector3(0.3, 0, -0.75)
	n.add_child(p)
	_p(p, Obake3D.lathe(0.13, 0.13, 1.0, 6, 0.02), IslandProps.m(Color("f2c14e")), Vector3(0, 0.1, 0))
	_p(p, Obake3D.lathe(0.13, 0.13, 0.12, 24, 0.02), Obake3D.metal(Color("c9c3cf")), Vector3(0, 0.66, 0))
	_p(p, Obake3D.lathe(0.12, 0.13, 0.2, 24, 0.05), IslandProps.m(Color("f4a3b8")), Vector3(0, 0.82, 0))
	_p(p, Obake3D.lathe(0.03, 0.13, 0.3, 24, 0.0), IslandProps.m(Color("f3d6ae")), Vector3(0, -0.55, 0), Vector3(PI, 0, 0))
	_p(p, Obake3D.lathe(0.0, 0.045, 0.1, 16, 0.0), IslandProps.m(Color("3a2e3c")), Vector3(0, -0.74, 0), Vector3(PI, 0, 0))
	return n


## 自分：おばネコの顔
func _b_cat_face() -> Node3D:
	var n := Node3D.new()
	var ob := Obake3D.make("tray")
	ob.bob = false
	ob.contact_shadow = false
	ob.rotation.y = YAW * 0.3
	n.add_child(ob)
	var prop := ob.body.get_node_or_null("Prop") as Node3D
	if prop:
		prop.visible = false
	return n


# ---------------------------------------------------------------- 仕上げ

## 動くもの（まばたき・ゆれ・玉の脈）を止める
func _freeze(n: Node) -> void:
	for c in n.find_children("*", "", true, false):
		c.set_process(false)
	n.set_process(false)


func _meshes(n: Node3D) -> Array:
	var out: Array = []
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.is_visible_in_tree() and mi.mesh != null:
			out.append(mi)
	return out


func _box_of(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in _meshes(n):
		# 地面の影（平らで大きい板）は枠に入れない
		if mi.name.to_lower().contains("shadow"):
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _size_of(n: Node3D) -> float:
	var b := _box_of(n)
	return maxf(b.size.x, maxf(b.size.y, b.size.z))


## 同じ向き・同じ画角のまま、距離と狙いだけ変えて、枠いっぱい（余白 MARGIN）に入れる
func _frame(n: Node3D) -> void:
	var box := _box_of(n)
	var center := box.get_center()
	var dir := Vector3(0, sin(deg_to_rad(-PITCH)), cos(deg_to_rad(-PITCH)))
	var dist := box.size.length() / sin(deg_to_rad(FOV * 0.5)) * 0.6
	var px := float(SIZE * SS)
	for it in 6:
		cam.position = center + dir * dist
		cam.look_at(center)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for mi in _meshes(n):
			if mi.name.to_lower().contains("shadow"):
				continue
			var ab: AABB = mi.get_aabb()
			for k in 8:
				var p: Vector2 = cam.unproject_position(mi.global_transform * ab.get_endpoint(k))
				lo = lo.min(p)
				hi = hi.max(p)
		var ext := maxf(hi.x - lo.x, hi.y - lo.y)
		var want := px * (1.0 - 2.0 * MARGIN)
		# 画面上のずれを世界のずれへ（狙いを動かして中央に）
		var mid := (lo + hi) * 0.5 - Vector2(px, px) * 0.5
		var wpp := 2.0 * dist * tan(deg_to_rad(FOV * 0.5)) / px
		center += cam.global_transform.basis.x * mid.x * wpp - cam.global_transform.basis.y * mid.y * wpp
		dist *= ext / want


## 輪郭を太く・濃く（小さく表示しても形が読めるように）
func _ink(n: Node3D, w: float) -> void:
	for mi in _meshes(n):

		if mi.material_override:
			mi.material_override = _thick(mi.material_override, w)
		else:
			for s in mi.mesh.get_surface_count():
				var m: Material = mi.get_active_material(s)
				if m:
					mi.set_surface_override_material(s, _thick(m, w))


func _thick(m: Material, w: float) -> Material:
	var np := m.next_pass
	if np is ShaderMaterial and (np as ShaderMaterial).shader == Obake3D.OUTLINE_SHADER:
		var d := m.duplicate() as Material
		var o := np.duplicate() as ShaderMaterial
		o.set_shader_parameter("width", w)
		o.set_shader_parameter("fixed_width", true)
		var c: Color = o.get_shader_parameter("color")
		o.set_shader_parameter("color", c.lerp(INK, 0.5))
		d.next_pass = o
		return d
	if np is StandardMaterial3D and (np as StandardMaterial3D).grow:
		var d := m.duplicate() as Material
		var o := np.duplicate() as StandardMaterial3D
		o.grow_amount = w
		d.next_pass = o
		return d
	return m
