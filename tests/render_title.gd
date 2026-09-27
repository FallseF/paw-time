extends SceneTree
## タイトルを、画面より大きい解像度でも撮る（ウィンドウは画面の大きさで切られるので、SubViewport に描く）。
##   OBAKE_NOSAVE=1 TITLE_SIZE=1080x1920 TITLE_OUT=ui_review/title_v2/title_1080x1920.png godot --path . -s tests/render_title.gd
## ゲームと同じく、キャンバスは 360x640 を基準に縦横比で「のばす」（タイトルの間の設定）。TITLE_WAIT=秒

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var wh := (OS.get_environment("TITLE_SIZE") if OS.get_environment("TITLE_SIZE") != "" else "1080x1920").split("x")
	var px := Vector2i(int(wh[0]), int(wh[1]))
	var out := OS.get_environment("TITLE_OUT") if OS.get_environment("TITLE_OUT") != "" else "/tmp/title.png"
	var wait := float(OS.get_environment("TITLE_WAIT")) if OS.get_environment("TITLE_WAIT") != "" else 2.5
	if root.get_node_or_null("GameState") == null:
		var gs = load("res://scripts/game_state.gd").new()
		gs.name = "GameState"
		root.add_child(gs)
	OS.set_environment("OBAKE_START", "title")
	var vp := SubViewport.new()
	vp.size = px
	var aspect := float(px.x) / px.y
	vp.size_2d_override = Vector2i(roundi(640.0 * aspect), 640) if aspect >= 9.0 / 16.0 else Vector2i(360, roundi(360.0 / aspect))
	vp.size_2d_override_stretch = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	vp.add_child(load("res://scenes/main.tscn").instantiate())
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png(out)
	print("wrote ", out, " ", px)
	quit()
