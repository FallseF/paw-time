extends Node
## 3D のタップが、画面の実際の解像度（View3D）でも当たるか。窓の大きさを変えて動かす：
##   OBAKE_NOSAVE=1 OBAKE_START=garden TAP_SCREEN=garden godot --path . --resolution 1080x1920 res://tests/tap_check.tscn
##   TAP_SCREEN=shop_island（OBAKE_START=shop_island OBAKE_SHOP=cafe_komorebi）／ catch（OBAKE_START=catch）
## 3D の物の位置を画面へ写し、窓のピクセルに直して本物の入力として押す → その物が反応したか。TAP_SHOT=path で印つきの画面を保存

var main


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _tap(sp: Vector2, pressed := true) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	# 画面（360x640 の座標）→ 窓のピクセル
	ev.position = get_viewport().get_final_transform() * sp
	ev.global_position = ev.position
	get_viewport().push_input(ev)


func _run() -> void:
	await get_tree().create_timer(3.0).timeout
	var which := OS.get_environment("TAP_SCREEN")
	var scr = main.current
	var cam: Camera3D = scr.get("cam")
	var ok := false
	var sp := Vector2.ZERO
	var vp_size: Vector2i = cam.get_viewport().size
	match which:
		"garden":
			# 新しい服の知らせ（上にかぶさるカード）は閉じてから
			for c in scr.get_children():
				if c is OutfitReveal:
					c.queue_free()
			await get_tree().create_timer(0.3).timeout
			var w = scr.walkers[0]
			var ob: Node3D = w.o
			sp = View3D.unproject(cam, ob.global_position + Vector3(0, 0.35, 0))
			var n0: int = ob.get_child_count()
			_tap(sp)
			_tap(sp, false) # 島のタップは、離したときに決まる（なぞりと見分けるため）
			await get_tree().process_frame
			ok = ob.get_child_count() > n0 # 吹き出し（Label3D）が付いた
		"shop_island":
			var mk: Dictionary = scr.marks[0]
			sp = View3D.unproject(cam, mk.anchor)
			_tap(sp)
			await get_tree().process_frame
			ok = scr.card != null and is_instance_valid(scr.card)
		"catch":
			var o: Node3D = scr.orbs[0]
			sp = View3D.unproject(cam, o.position)
			_tap(sp)
			await get_tree().process_frame
			var d := Vector2(scr.poi.position.x - o.position.x, scr.poi.position.z - o.position.z).length()
			ok = d < 0.08 # ポイが玉の真下へ
			print("poi-orb distance ", d)
	var shot := OS.get_environment("TAP_SHOT")
	if shot != "":
		var dot := ColorRect.new()
		dot.color = Color(1, 0, 0, 0.9)
		dot.size = Vector2(6, 6)
		dot.position = sp - Vector2(3, 3)
		var cl := CanvasLayer.new()
		cl.layer = 100
		cl.add_child(dot)
		add_child(cl)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
	print("TAP %s win=%s vp3d=%s at=%s %s" % [which, DisplayServer.window_get_size(), vp_size, sp, "OK" if ok else "FAIL"])
	get_tree().quit(0 if ok else 1)
