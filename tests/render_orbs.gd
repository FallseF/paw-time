extends SceneTree
## 光る玉の見た目の確認用：夜の池の上で、中身の種類ごとに玉をぐるっと回して撮る。
##   godot --path . --resolution 256x256 -s tests/render_orbs.gd
## 環境変数 ORB_OUT=出力先の png（既定 /tmp/orbs.png）、ORB_S=1 コマの大きさ（既定 256）
## 行：おばネコ・材料（木）・材料（貝）・服（花かんむり）。列：回す角度 4 つ。

const KINDS := [
	{"type": "hall", "content": {"kind": "obake"}},
	{"type": "stock", "content": {"kind": "material", "id": "wood", "n": 2}},
	{"type": "dish", "content": {"kind": "material", "id": "shell", "n": 1}},
	{"type": "kitchen", "content": {"kind": "cloth", "id": "flower_crown"}},
]
## ORB_SET=all なら、材料 6 種と服・乗り物も 1 行ずつ（正面寄りの 2 角度）
const ALL := [
	{"type": "register", "content": {"kind": "obake"}},
	{"type": "rare", "rare": true, "content": {"kind": "obake"}},
	{"type": "stock", "content": {"kind": "material", "id": "wood"}},
	{"type": "hall", "content": {"kind": "material", "id": "stone"}},
	{"type": "kitchen", "content": {"kind": "material", "id": "seed"}},
	{"type": "register", "content": {"kind": "material", "id": "paper"}},
	{"type": "dish", "content": {"kind": "material", "id": "shell"}},
	{"type": "hall", "content": {"kind": "material", "id": "cloth"}},
	{"type": "kitchen", "content": {"kind": "cloth", "id": "bell_collar"}},
	{"type": "dish", "content": {"kind": "cloth", "id": "balloon"}},
]
const YAWS := [0.0, 1.2, 2.4, 3.8]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_environment("ORB_OUT")
	if out == "":
		out = "/tmp/orbs.png"
	var s := int(OS.get_environment("ORB_S")) if OS.get_environment("ORB_S") != "" else 256
	var vp := SubViewport.new()
	vp.size = Vector2i(s, s)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	_night_pond(world)
	var cam := Camera3D.new()
	cam.fov = 30
	world.add_child(cam)
	var shots: Array[Image] = []
	var kinds: Array = ALL if OS.get_environment("ORB_SET") == "all" else KINDS
	var yaws: Array = [0.0, 0.5] if OS.get_environment("ORB_SET") == "all" else YAWS
	# ORB_ROWS=0,2 で行をしぼる（見た目の調整用）
	if OS.get_environment("ORB_ROWS") != "":
		kinds = []
		for i in OS.get_environment("ORB_ROWS").split(","):
			kinds.append(KINDS[int(i)])
	for k in kinds:
		var d: Dictionary = k.duplicate(true)
		d["rare"] = d.get("rare", false)
		d["weight"] = 0.3
		var o := Orb3D.new().setup(d)
		o.set_process(false)
		world.add_child(o)
		if OS.get_environment("ORB_NOGLASS") != "":
			o.model.shell.visible = false
			o.model.shell_back.visible = false
			o.model.core.visible = false
		o.model.set_energy(2.4 * (1.4 if o.cat else 1.0), 1.4 if o.cat else 1.0)
		for yaw in yaws:
			o.model.rotation.y = yaw
			cam.look_at_from_position(Vector3(0, 0.42, 0.95), Vector3(0, 0.12, 0))
			for f in 4:
				await RenderingServer.frame_post_draw
			var im := vp.get_texture().get_image()
			im.convert(Image.FORMAT_RGBA8)
			shots.append(im)
		o.queue_free()
		await process_frame
	# ORB_SET=all は 2 角度 × 10 種を 4 列に並べる
	var cols := 4 if OS.get_environment("ORB_SET") == "all" else yaws.size()
	var rows := ceili(shots.size() / float(cols))
	var sheet := Image.create(cols * s, rows * s, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		sheet.blit_rect(shots[i], Rect2i(0, 0, s, s), Vector2i((i % cols) * s, (i / cols) * s))
	sheet.save_png(out)
	print("wrote ", out)
	quit()


## すくいの画面と同じ空気（夜の池・月明かり・グロー）
func _night_pond(world: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b1026")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a4a8a")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 1.2
	env.glow_strength = 1.2
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-55, -30, 0)
	moon.light_color = Color("9fb4ff")
	moon.light_energy = 0.35
	world.add_child(moon)
	var water := MeshInstance3D.new()
	var wp := PlaneMesh.new()
	wp.size = Vector2(60, 60)
	wp.subdivide_width = 8
	wp.subdivide_depth = 8
	water.mesh = wp
	var wm := ShaderMaterial.new()
	wm.shader = load("res://shaders/water.gdshader")
	water.material_override = wm
	world.add_child(water)
