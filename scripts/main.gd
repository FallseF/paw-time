extends Node
## 画面の切り替え役。画面は Control を差し替え、暗転でつなぐ。

const SCREENS := {
	"title": preload("res://scripts/screen_title.gd"),
	"morning": preload("res://scripts/screen_room.gd"),
	"room": preload("res://scripts/screen_room.gd"),
	"catch": preload("res://scripts/screen_scoop.gd"),
	"hatch": preload("res://scripts/screen_hatch.gd"),
	"sleep": preload("res://scripts/screen_sleep.gd"),
	"zukan": preload("res://scripts/screen_zukan.gd"),
	"workshop": preload("res://scripts/screen_workshop.gd"),
}

var root: Control
var current: Control
var current_name := ""
var fade: ColorRect
var busy := false


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.make_theme()
	add_child(root)
	fade = ColorRect.new()
	fade.color = Color("140f1c")
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0
	var ff := OS.get_environment("OBAKE_FF")
	if ff != "":
		GameState.fast_forward(int(ff))
	var start := OS.get_environment("OBAKE_START")
	if start == "hatch":
		GameState.orbs = [{"type": "dish", "kind": "school", "quality": 2}, {"type": "rare", "kind": "rainbow", "quality": 1}, {"type": "stock", "kind": "heavy", "quality": 0}]
		GameState.sleep(7)
		var force := OS.get_environment("OBAKE_RARE")
		if force != "":
			GameState.add_obake(force)
			GameState.hatched.push_front({"id": force, "is_new": true, "level": 1, "rare": true, "quality": 3, "kind": "rare"})
	if OS.get_environment("OBAKE_DEMO") != "":
		var demo = load("res://scripts/demo.gd").new()
		add_child(demo)
		root.add_child(fade)
		demo.run(self)
		return
	go(start if SCREENS.has(start) else "title", true)
	root.add_child(fade)
	_maybe_autoshot()


func go(screen_name: String, instant := false) -> void:
	if busy:
		return
	busy = true
	if not instant:
		fade.mouse_filter = Control.MOUSE_FILTER_STOP
		var tw := create_tween()
		tw.tween_property(fade, "modulate:a", 1.0, 0.18)
		await tw.finished
	Engine.time_scale = 1.0
	if current:
		current.queue_free()
	current = SCREENS[screen_name].new()
	current_name = screen_name
	current.set_anchors_preset(Control.PRESET_FULL_RECT)
	current.set("main", self)
	root.add_child(current)
	root.move_child(current, 0)
	if not instant:
		var tw2 := create_tween()
		tw2.tween_property(fade, "modulate:a", 0.0, 0.22)
		await tw2.finished
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false


## 確認用：OBAKE_SHOT="画面名,wait1,call:メソッド" で起動すると、最後に撮って終わる
func _maybe_autoshot() -> void:
	var target := OS.get_environment("OBAKE_SHOT")
	if target == "":
		return
	var path := OS.get_environment("OBAKE_SHOT_PATH")
	var shots := 0
	for step in target.split(","):
		if step.begins_with("wait"):
			await get_tree().create_timer(float(step.substr(4)), true, false, true).timeout
		elif step.begins_with("call:"):
			current.call(step.substr(5))
			await get_tree().create_timer(0.6, true, false, true).timeout
		elif step == "snap":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%d.png" % shots))
			shots += 1
		else:
			await go(step, true)
			await get_tree().create_timer(0.8, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
