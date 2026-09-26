extends SceneTree
## 島の置き物をひとつずつ撮る（背景は透明、384x384）。カタログの一覧は tools/make_kit_sheet.py で組む。
##   godot --path . --always-on-top --resolution 384x384 -s tests/render_island_kit.gd
## （ウィンドウが隠れると macOS が描画を止めるので --always-on-top を付ける）
## 環境変数: KIT_IDS=bench,hut … 一部だけ / KIT_OUT=/tmp/dir … 出力先（既定は assets/gen/island_kit。カタログのアイコンにも使う）

const SIZE := 384
const SS := 2
const YAW := 0.55
const PITCH := -24.0

var vp: SubViewport
var world: Node3D
var cam: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_environment("KIT_OUT")
	if out == "":
		out = ProjectSettings.globalize_path("res://assets/gen/island_kit")
	DirAccess.make_dir_recursive_absolute(out)
	var ids: Array = []
	if OS.get_environment("KIT_IDS") != "":
		ids = Array(OS.get_environment("KIT_IDS").split(","))
	else:
		for it in IslandKit.ITEMS:
			ids.append(it.id)
		# 乗り物（veh: を付けて区別。assets/gen/vehicles/<id>.png）
		for v in Vehicles.LIST:
			ids.append("veh:" + v.id)
	vp = SubViewport.new()
	vp.size = Vector2i(SIZE * SS, SIZE * SS)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	Look.apply(world, "island_day", Color(0, 0, 0, 0), true)
	cam = Camera3D.new()
	cam.fov = 24
	world.add_child(cam)
	for id in ids:
		var veh := String(id).begins_with("veh:")
		var n := VehicleProps.build_vehicle(id.substr(4)) if veh else IslandProps.build(id)
		n.rotation.y = YAW + (-PI / 2 if veh else 0.0)
		world.add_child(n)
		for i in 3:
			await process_frame
		_frame(n)
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		if veh:
			var vd := ProjectSettings.globalize_path("res://assets/gen/vehicles") if OS.get_environment("KIT_OUT") == "" else out
			DirAccess.make_dir_recursive_absolute(vd)
			img.save_png(vd.path_join("%s.png" % id.substr(4)))
		else:
			img.save_png(out.path_join("%s.png" % id))
		n.queue_free()
		await process_frame
		print("rendered ", id)
	quit()


func _frame(n: Node3D) -> void:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var center := box.get_center()
	var radius := maxf(box.size.length() * 0.5, 0.45)
	var dist := radius / sin(deg_to_rad(cam.fov * 0.5)) * 0.95
	var dir := Vector3(0, sin(deg_to_rad(-PITCH)), cos(deg_to_rad(-PITCH)))
	cam.position = center + dir * dist
	cam.look_at(center)
