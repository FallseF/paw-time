extends SceneTree
## キセカエの全アイテムを、おばけに着せて並べて撮る（見た目の確認用）。
##   godot --path . --resolution 256x256 -s tests/render_outfits.gd
## 環境変数 OUTFIT_WHO=receipt（着せる子。my / レアの id も可）、OUTFIT_OUT=出力先の png

const S := 220

var vp: SubViewport
var world: Node3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var who := OS.get_environment("OUTFIT_WHO")
	if who == "":
		who = "receipt"
	var out := OS.get_environment("OUTFIT_OUT")
	if out == "":
		out = "/tmp/outfits.png"
	vp = SubViewport.new()
	vp.size = Vector2i(S, S)
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	Look.apply(world, "studio", Color("f6efe6"))
	var cam := Camera3D.new()
	cam.fov = 32
	world.add_child(cam)
	var yaw := float(OS.get_environment("OUTFIT_YAW")) if OS.get_environment("OUTFIT_YAW") != "" else 0.4
	cam.look_at_from_position(Vector3(sin(yaw) * 3.7, 1.5, cos(yaw) * 3.7), Vector3(0, 0.62, 0))
	var shots: Array[Image] = []
	var names: Array = []
	for it in WardrobeData.ITEMS:
		var o := {it.slot: it.id}
		var ob := Outfit.make(who, o)
		ob.bob = false
		ob.set_process(false)
		world.add_child(ob)
		for k in 3:
			await RenderingServer.frame_post_draw
		shots.append(vp.get_texture().get_image())
		names.append(it.id)
		ob.queue_free()
		await process_frame
	var cols := 8
	var rows := ceili(shots.size() / float(cols))
	var sheet := Image.create(cols * S, rows * S, false, Image.FORMAT_RGBA8)
	for i in shots.size():
		var im := shots[i]
		im.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(im, Rect2i(0, 0, S, S), Vector2i((i % cols) * S, (i / cols) * S))
	sheet.save_png(out)
	print("wrote ", out, " ", names.size())
	quit()
