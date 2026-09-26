extends Node
## 画面の切り替え役。画面は Control を差し替え、暗転でつなぐ。

const SCREENS := {
	"morning": preload("res://scripts/screen_room.gd"),
	"room": preload("res://scripts/screen_room.gd"),
	"catch": preload("res://scripts/screen_scoop.gd"),
	"hatch": preload("res://scripts/screen_hatch.gd"),
	"sleep": preload("res://scripts/screen_sleep.gd"),
	"zukan": preload("res://scripts/screen_zukan.gd"),
	"map": preload("res://scripts/screen_map.gd"),
	"crew": preload("res://scripts/screen_crew.gd"),
	"defense": preload("res://scripts/screen_defense.gd"),
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
	fade.color = UI.INK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0
	var start := OS.get_environment("OBAKE_START")
	_debug_setup()
	if start == "hatch":
		GameState.orbs = [{"type": "dish", "rare": false}, {"type": "rare", "rare": true}]
		GameState.sleep(7, "")
		var force := OS.get_environment("OBAKE_RARE")
		if force != "":
			GameState.add_obake(force)
			GameState.hatched.push_front({"id": force, "is_new": true, "level": 1, "rare": true})
	elif start == "defense" and GameState.pending_battle.is_empty():
		var sg := OS.get_environment("OBAKE_STAGE")
		var parts := sg.split("-") if sg != "" else PackedStringArray(["0", "0"])
		GameState.pending_battle = {"shop": int(parts[0]), "stage": int(parts[1])}
	if OS.get_environment("OBAKE_DEMO") != "":
		var demo := preload("res://scripts/demo.gd").new()
		demo.main = self
		add_child(demo)
		root.add_child(fade)
		_maybe_autoshot()
		return
	go(start if SCREENS.has(start) else "morning", true)
	root.add_child(fade)
	_maybe_autoshot()


## 確認用：OBAKE_SETUP=rich で、中盤くらいの手持ちにする
func _debug_setup() -> void:
	var s := OS.get_environment("OBAKE_SETUP")
	if s == "":
		return
	GameState.total_battles = 1
	for id in ["tray", "bubble", "pan"]:
		GameState.add_obake(id)
	if s == "rich":
		for id in ["kaminari", "nemurin", "amagasa", "yomise"]:
			GameState.add_obake(id)
		for o in GameState.owned:
			o.level = 6
		GameState.coins = 3000
		for si in 2:
			for st in DefData.shop(si).stages.size():
				GameState.cleared[DefData.stage_key(si, st)] = 1


func go(screen_name: String, instant := false) -> void:
	if busy:
		return
	busy = true
	if not instant:
		fade.mouse_filter = Control.MOUSE_FILTER_STOP
		var tw := create_tween()
		tw.tween_property(fade, "modulate:a", 1.0, 0.18)
		await tw.finished
	if current:
		current.queue_free()
	Engine.time_scale = 1.0
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


## 確認用：OBAKE_SHOT="画面,waitN,call:メソッド" で撮って終わる
func _maybe_autoshot() -> void:
	var target := OS.get_environment("OBAKE_SHOT")
	if target == "":
		return
	var path := OS.get_environment("OBAKE_SHOT_PATH")
	var n := 0
	for step in target.split(","):
		if step.begins_with("wait"):
			await get_tree().create_timer(float(step.substr(4))).timeout
		elif step.begins_with("call:"):
			current.call(step.substr(5))
			await get_tree().create_timer(0.6).timeout
		elif step == "snap":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%d.png" % n))
			n += 1
		else:
			await go(step, true)
			await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
