extends Node
## 画面の切り替え役。画面は Control を差し替え、暗転でつなぐ。

const SCREENS := {
	"morning": preload("res://scripts/screen_morning.gd"),
	"room": preload("res://scripts/screen_room.gd"),
	"catch": preload("res://scripts/screen_scoop.gd"),
	"catch3d": preload("res://scripts/screen_catch3d.gd"),
	"hatch": preload("res://scripts/screen_hatch.gd"),
	"catch2d": preload("res://scripts/screen_catch.gd"),
	"sleep": preload("res://scripts/screen_sleep.gd"),
	"battle": preload("res://scripts/screen_battle.gd"),
	"zukan": preload("res://scripts/screen_zukan.gd"),
	"summary": preload("res://scripts/screen_summary.gd"),
}

var root: Control
var current: Control
var fade: ColorRect
var busy := false


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.make_theme()
	add_child(root)
	fade = ColorRect.new()
	fade.color = UI.INK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0
	var start := OS.get_environment("OBAKE_START")
	if start == "hatch":
		GameState.orbs = [{"type": "dish", "rare": false}, {"type": "rare", "rare": true}]
		GameState.sleep(7, "")
	go(start if SCREENS.has(start) else "morning", true)
	root.add_child(fade)
	_maybe_autoshot()


func go(screen_name: String, instant := false) -> void:
	if busy:
		return
	if screen_name == "morning" and GameState.is_week_over():
		screen_name = "summary"
	busy = true
	if not instant:
		fade.mouse_filter = Control.MOUSE_FILTER_STOP
		var tw := create_tween()
		tw.tween_property(fade, "modulate:a", 1.0, 0.18)
		await tw.finished
	if current:
		current.queue_free()
	current = SCREENS[screen_name].new()
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


## 確認用：OBAKE_SHOT=画面名 で起動すると、その画面を撮って終わる
func _maybe_autoshot() -> void:
	var target := OS.get_environment("OBAKE_SHOT")
	if target == "":
		return
	var path := OS.get_environment("OBAKE_SHOT_PATH")
	for step in target.split(","):
		if step.begins_with("wait"):
			await get_tree().create_timer(float(step.substr(4))).timeout
		elif step.begins_with("call:"):
			current.call(step.substr(5))
			await get_tree().create_timer(0.6).timeout
		else:
			await go(step, true)
			await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
