extends SceneTree
## 「おやすみ」を二度押しても、1日しか進まないこと。godot --headless --path . -s tests/test_double_sleep.gd
class FakeMain:
	extends Node
	var went: Array = []
	func go(n: String, _instant := false) -> void:
		went.append(n)


func _initialize() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.reset()
	var fm := FakeMain.new()
	root.add_child(fm)
	var scr = load("res://scripts/screen_sleep.gd").new()
	scr.main = fm
	root.add_child(scr)
	await process_frame
	scr._sleep()
	scr._sleep()
	await create_timer(2.5).timeout
	var ok: bool = gs.day == 1 and fm.went.size() == 1
	print("day=", gs.day, " went=", fm.went, " → ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
