extends SceneTree
## セーブ → リセット → ロードで、状態が戻るかを確かめる。
## godot --headless --path . -s tests/test_save.gd
func _initialize() -> void:
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		gs = load("res://scripts/game_state.gd").new()
		gs.name = "GameState"
		root.add_child(gs)
	await process_frame
	gs.SAVE_PATH = "user://obake_a_test_save.json" # 本物のセーブには触れない
	gs.force_save = true
	gs.reset()
	gs.fast_forward(9)
	gs.pois["lure"] = 3
	gs.upgrades["wa"] = 2
	gs.partner = "box"
	gs.orbs = [{"type": "dish", "kind": "school", "quality": 2}]
	gs.day = 12 # 土曜
	gs.worked_today = false
	gs.finish_shift()
	var before := {}
	for k in gs.SAVE_KEYS:
		before[k] = JSON.stringify(gs.get(k))
	gs.save_game()
	gs.reset()
	var ok: bool = gs.load_game()
	var fails := 0
	for k in gs.SAVE_KEYS:
		var after := JSON.stringify(gs.get(k))
		if after != before[k]:
			fails += 1
			print("MISMATCH ", k, "\n  before ", before[k].left(200), "\n  after  ", after.left(200))
	# 型が戻っているか（int のはずのものが float だと表示が崩れる）
	if typeof(gs.day) != TYPE_INT or typeof(gs.pois.paper) != TYPE_INT or typeof(gs.owned.receipt.level) != TYPE_INT:
		fails += 1
		print("TYPE MISMATCH")
	# 土日の出勤の記録が、ロード後も判定に使えるか
	if gs.today().role != "" and not gs.weekend_work.has("5"):
		fails += 1
		print("WEEKEND KEY LOST ", gs.weekend_work)
	# ロード後もそのまま1晩進められるか
	gs.sleep(7)
	print("load=", ok, " fails=", fails, " day=", gs.day)
	gs.wipe_save()
	print("PASS" if ok and fails == 0 else "FAIL")
	quit(0 if ok and fails == 0 else 1)
