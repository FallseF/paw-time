extends SceneTree
## 練習ですくっても、ポイも玉も記録も変わらないこと。godot --headless --path . -s tests/test_practice.gd
class FakeMain:
	extends Node
	func go(_n: String, _instant := false) -> void:
		pass


func _initialize() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.reset()
	gs.records.nights = 2
	gs.phase = "scooped"
	var pois_before: String = JSON.stringify(gs.pois)
	var total_before: int = gs.records.total
	gs.practice = true
	var scr = load("res://scripts/screen_scoop.gd").new()
	scr.main = FakeMain.new()
	scr.size = Vector2(360, 640)
	root.add_child(scr)
	await process_frame
	scr.start_auto(0.9)
	for i in 60 * 20:
		await process_frame
	scr._end_night("test")
	await create_timer(1.5).timeout
	var ok: bool = scr.count > 0 and gs.orbs.is_empty() and JSON.stringify(gs.pois) == pois_before and gs.records.total == total_before and not gs.practice and gs.phase == "scooped"
	print("practice count=", scr.count, " orbs=", gs.orbs.size(), " pois same=", JSON.stringify(gs.pois) == pois_before, " total=", gs.records.total, " → ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
