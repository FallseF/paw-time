extends SceneTree
## レアおばけ 30 体の図鑑カード用の絵を撮る（背景は透明、512x512）。
## 画面が要るので、ウィンドウ付きで起動する:
##   godot --path . --resolution 512x512 -s tests/render_rares.gd
## 環境変数:
##   RARE_IDS=amagasa,yomise  … 一部だけ撮る（ふつうのおばけの id も可）
##   RARE_OUT=/tmp/dir        … 出力先（既定は res://assets/gen/rares3d）
## 出力: <id>.png と、全体を並べた _sheet.png（全員を撮ったときだけ）

const SIZE := 512
const SS := 2  # 大きく撮って縮め、縁をなめらかにする
const YAW := 0.42  # 顔を少し右に向ける（3/4 正面）
const PITCH := -12.0

var vp: SubViewport
var world: Node3D
var cam: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_environment("RARE_OUT")
	if out == "":
		out = ProjectSettings.globalize_path("res://assets/gen/rares3d")
	DirAccess.make_dir_recursive_absolute(out)
	var ids: Array = []
	var only := OS.get_environment("RARE_IDS")
	if only != "":
		ids = Array(only.split(","))
	else:
		for r in Rares.LIST:
			ids.append(r.id)
	_make_stage()
	var shots: Array[Image] = []
	for id in ids:
		var img := await _shoot(id)
		img.save_png(out.path_join("%s.png" % id))
		shots.append(img)
		print("rendered ", id)
	if only == "" or ids.size() > 1:
		_sheet(shots, ids).save_png(out.path_join("_sheet.png"))
	quit()


func _make_stage() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(SIZE * SS, SIZE * SS)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("e6d6e0")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 35, 0)
	sun.light_color = Color("fff1e0")
	sun.light_energy = 0.85
	world.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 26
	world.add_child(cam)


func _shoot(id: String) -> Image:
	seed(hash(id))
	var ob := Obake3D.make(id)
	if ob == null:
		push_error("could not build " + id)
		quit(1)
		return Image.create(1, 1, false, Image.FORMAT_RGBA8)
	ob.bob = false
	ob.set("_t", 0.0)
	ob.rotation.y = YAW
	world.add_child(ob)
	# 揺れの位置が決まるまで待つ
	for i in 3:
		await process_frame
	_frame(ob)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	ob.queue_free()
	await process_frame
	return img


## 全体が画面に収まるよう、カメラを寄せる（形の大きさに合わせてそろえる）
func _frame(ob: Node3D) -> void:
	var box := AABB()
	var first := true
	for m in ob.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var center := box.get_center()
	var radius := box.size.length() * 0.5
	var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * 0.92
	var dir := Vector3(0, sin(deg_to_rad(-PITCH)), cos(deg_to_rad(-PITCH)))
	cam.position = center + dir * dist
	cam.look_at(center)


func _sheet(shots: Array[Image], ids: Array) -> Image:
	var cols := 6
	var cell := 256
	var rows := ceili(shots.size() / float(cols))
	var sheet := Image.create(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var x := (i % cols) * cell
		var y := (i / cols) * cell
		var bg := Color("fbf6ef") if (i + i / cols) % 2 == 0 else Color("f1e9df")
		sheet.fill_rect(Rect2i(x, y, cell, cell), bg)
		var s := shots[i].duplicate() as Image
		s.resize(cell, cell, Image.INTERPOLATE_LANCZOS)
		sheet.blend_rect(s, Rect2i(0, 0, cell, cell), Vector2i(x, y))
	return sheet
