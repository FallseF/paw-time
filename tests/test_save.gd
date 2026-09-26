extends SceneTree
## セーブして読み直すと、同じ状態に戻るか。godot --headless --path . -s tests/test_save.gd
func _initialize() -> void:
	OS.set_environment("OBAKE_SAVE", "user://obake_c_test.json")
	OS.set_environment("OBAKE_FRESH", "1")
	var a = load("res://scripts/game_state.gd").new()
	root.add_child(a)
	await process_frame
	a.finish_shift()
	a.record_battle(0, 0, true, {"time": 40.0, "kills": 5})
	a.orbs = [{"type": "dish", "rare": false}]
	a.sleep(7, "")
	a.upgrade("receipt")
	a.lap = 1
	a.save_game()
	var b = load("res://scripts/game_state.gd").new()
	root.add_child(b)
	await process_frame
	var ok: bool = b.load_game()
	var fails := []
	for k in a.SAVE_KEYS:
		if JSON.stringify(a.get(k)) != JSON.stringify(b.get(k)) and str(a.get(k)) != str(b.get(k)):
			fails.append("%s: %s != %s" % [k, str(a.get(k)), str(b.get(k))])
	print("load ok=%s  mismatches=%d" % [ok, fails.size()])
	for f in fails:
		print("  ", f)
	print("day=%d coins=%d owned=%d" % [b.day, b.coins, b.owned.size()])
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://obake_c_test.json"))
	quit(0 if ok and fails.is_empty() else 1)
