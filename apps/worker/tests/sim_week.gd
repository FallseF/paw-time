extends SceneTree
## 見本の1週間を自動で通して、生まれたおばけを表示する。godot --headless --path . -s tests/sim_week.gd
func _initialize() -> void:
	var gs = load("res://scripts/game_state.gd").new()
	gs.name = "GameState"
	root.add_child(gs)
	await process_frame
	var sleeps := [7, 8, 9, 5, 7]
	for d in 5:
		var s: Dictionary = gs.today()
		if s.role != "":
			gs.finish_shift()
		if d == gs.BATTLE_DAY:
			gs.battle_won = true
		gs.orbs = [{"type": "dish", "rare": false}]
		gs.sleep(sleeps[d], "")
		var names := []
		for h in gs.hatched:
			names.append(("★" if h.rare else "") + gs.info(h.id).name)
		print("%s曜 %d時間 → %s" % [s.day, sleeps[d], ", ".join(names)])
	print("図鑑 %d / %d" % [gs.seen.size(), gs.ALL.size()])
	quit()
