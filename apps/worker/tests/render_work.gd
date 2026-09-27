extends SceneTree
## 「いっしょに働く」画面を仕事ごとに撮る（見た目の確認用）。
##   OBAKE_START=work OBAKE_NOSAVE=1 RW_ROLE=kitchen RW_OUT=/tmp/w.png \
##     godot --path . --resolution 390x844 -s tests/render_work.gd
## 夜のシフトは OBAKE_NOW=<unix 秒>（画面の光は GameState.now_real の時刻で決まる）。
## RW_HOURS で、シフトを始めてからの時間（既定 3 時間。コインと疲れが出る）。


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var role := OS.get_environment("RW_ROLE") if OS.get_environment("RW_ROLE") != "" else "register"
	var out := OS.get_environment("RW_OUT") if OS.get_environment("RW_OUT") != "" else "/tmp/work.png"
	var hours := float(OS.get_environment("RW_HOURS")) if OS.get_environment("RW_HOURS") != "" else 3.0
	change_scene_to_file("res://scenes/main.tscn")
	for i in 10:
		await process_frame
	WorkTogether.reset()
	WorkTogether.start(role, "", WorkTogether.now() - hours * 3600.0)
	var main := current_scene
	main.go("work", true)
	await create_timer(2.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("wrote ", out, "  draw calls: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), "  objects: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
	quit()
