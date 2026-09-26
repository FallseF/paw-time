extends SceneTree
## はじめての夜の説明が、押す→寄せる→離すで進んで終わるか。
## godot --headless --path . -s tests/test_tutorial.gd
class FakeMain:
	extends Node
	func go(_n: String, _instant := false) -> void:
		pass


func _mouse(scr: Control, pos: Vector2, pressed = null) -> void:
	var e: InputEvent
	if pressed == null:
		e = InputEventMouseMotion.new()
	else:
		e = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
	e.position = pos
	scr._gui_input(e)


func _initialize() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.reset()
	gs.records.nights = 0 # はじめての夜（説明あり）
	var scr = load("res://scripts/screen_scoop.gd").new()
	scr.main = FakeMain.new()
	scr.size = Vector2(360, 640)
	root.add_child(scr)
	await process_frame
	await process_frame
	# いちばん手前の玉を止めて、その少し手前から入れて、そっと寄せて離す
	var target = null
	for o in scr.orbs:
		if o.catchable() and (target == null or o.position.z > target.position.z):
			target = o
	target.kind = "normal"
	target.air = 0.0
	target.leader = null
	for o in scr.orbs:
		if o != target:
			o.set_meta("far", true)
	target.vel = Vector3.ZERO
	target.position = Vector3(0.0, 0.0, 0.3)
	var goal_px: Vector2 = scr.cam.unproject_position(target.position)
	var start_px := goal_px + Vector2(0, 60)
	var before: int = gs.pois.paper
	var steps: Array = [scr.tut_step]
	_mouse(scr, start_px, true)
	steps.append(scr.tut_step)
	for i in 40:
		target.vel = Vector3.ZERO
		target.position = Vector3(0.0, 0.0, 0.3)
		for o in scr.orbs:
			if o.has_meta("far"):
				o.position = Vector3(2.0 if o.position.x >= 0 else -2.0, 0, -1.5)
		_mouse(scr, start_px.lerp(goal_px, i / 39.0))
		await process_frame
	for i in 20:
		target.vel = Vector3.ZERO
		target.position = Vector3(0.0, 0.0, 0.3)
		for o in scr.orbs:
			if o.has_meta("far"):
				o.position = Vector3(2.0 if o.position.x >= 0 else -2.0, 0, -1.5)
		await process_frame
	steps.append(scr.tut_step)
	_mouse(scr, goal_px, false)
	await create_timer(3.0).timeout
	steps.append(scr.tut_step)
	print("steps=", steps, " tut=", gs.tut)
	var ok: bool = scr.count == 1 and gs.orbs.size() == 1 and gs.pois.paper == before - 1 and steps == [0, 1, 2, -1] and gs.tut.get("scoop", false)
	print("count=", scr.count, " orbs=", gs.orbs.size(), " paper ", before, "→", gs.pois.paper, " durability=", snappedf(scr.durability, 0.01), " recorded=", gs.records.total, " → ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
