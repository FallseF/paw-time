extends SceneTree
## 画面の動きをコマ撮りする（孵化のひびの瞬間など、OBAKE_SHOT では間に合わない速い動きの確認用）。
##   OBAKE_START=hatch OBAKE_ITEMS=1 CAP_FROM=5.5 CAP_N=24 CAP_EVERY=2 CAP_OUT=/tmp/cap \
##     godot --path . --always-on-top -s tests/capture_frames.gd
## CAP_FROM 秒（ゲームの時間）から、CAP_EVERY コマごとに CAP_N 枚撮って、CAP_OUT/f_00.png... に書く。
## CAP_TS でゲームの速さ（既定 1）。CAP_CLICK=秒,秒 で、その時刻に画面の demo_open を呼ぶ。
## CAP_WHEN=crack なら、CAP_FROM 秒のあと、どれかの玉にひびが入り始めた瞬間から撮る。

var frames: Array[Image] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var from := float(OS.get_environment("CAP_FROM")) if OS.get_environment("CAP_FROM") != "" else 3.0
	var n := int(OS.get_environment("CAP_N")) if OS.get_environment("CAP_N") != "" else 20
	var every := int(OS.get_environment("CAP_EVERY")) if OS.get_environment("CAP_EVERY") != "" else 2
	var out := OS.get_environment("CAP_OUT") if OS.get_environment("CAP_OUT") != "" else "/tmp/cap"
	var clicks: Array = []
	for c in OS.get_environment("CAP_CLICK").split(",", false):
		clicks.append(float(c))
	if OS.get_environment("CAP_TS") != "":
		Engine.time_scale = float(OS.get_environment("CAP_TS"))
	change_scene_to_file("res://scenes/main.tscn")
	var t0 := Time.get_ticks_msec()
	var t := 0.0
	while t < from:
		await process_frame
		t = (Time.get_ticks_msec() - t0) / 1000.0 * Engine.time_scale
		if not clicks.is_empty() and t >= clicks[0]:
			clicks.pop_front()
			var main := current_scene
			if main and main.get("current") and main.current.has_method("demo_open"):
				main.current.demo_open()
	if OS.get_environment("CAP_WHEN") == "crack":
		while not _cracking(get_root()):
			await process_frame
	var k := 0
	while frames.size() < n:
		await RenderingServer.frame_post_draw
		if k % every == 0:
			frames.append(get_root().get_texture().get_image())
		k += 1
	DirAccess.make_dir_recursive_absolute(out)
	for i in frames.size():
		frames[i].save_png("%s/f_%02d.png" % [out, i])
	print("wrote ", frames.size(), " frames to ", out)
	quit()


func _cracking(n: Node) -> bool:
	for m in n.find_children("*", "OrbModel", true, false):
		var om := m as OrbModel
		var c = om.shell_mat.get_shader_parameter("crack") if om.shell_mat else null
		if c != null and float(c) > 0.0:
			return true
	return false
