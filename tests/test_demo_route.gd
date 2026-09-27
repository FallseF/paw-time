extends Node
## 3 分デモ（scripts/demo_route.gd）を本物の画面で通す：求人 1 枚 → 受ける → 早送りのシフトでへとへと → ひとこと評価
## → すくい（おばネコの玉）→ 朝、はじめての夜と同じ特別なレア（動画）→ 最後のカード。タップの代わりに各画面の関数を呼ぶ。
## OBAKE_NOSAVE=1 godot --headless --path . res://tests/test_demo_route.tscn

var fails := 0
var main


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _ready() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _until(cond: Callable, sec: float, what: String) -> bool:
	var t := 0.0
	while t < sec:
		if cond.call():
			return true
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	_check(false, "timed out: " + what)
	return false


func _screen() -> String:
	return main.current.get_script().resource_path.get_file() if main.current else ""


func _run() -> void:
	await get_tree().create_timer(1.0).timeout
	var t0 := Time.get_ticks_msec()
	DemoRoute.begin(main)
	var pick := SpecialReveal.pick()
	_check(GameState.my_obake.get("special", "") != "", "the preset cat is a special cat")
	# 1 求人カード
	await _until(func(): return _screen() == "screen_garden.gd" and DemoRoute.node._desk(main.current) != null and DemoRoute.node._desk(main.current).viewer != null, 8.0, "job viewer opens")
	var desk: JobDesk = DemoRoute.node._desk(main.current)
	_check(desk.jobs.size() == 1, "one job card (%d)" % desk.jobs.size())
	desk.index = 0
	desk._show_job()
	desk._accept()
	# 2 シフト（早送り）
	await _until(func(): return _screen() == "screen_work.gd", 6.0, "goes to work")
	_check(WorkTogether.active() and not WorkTogether.screen_allowed("garden"), "on shift: locked to the work screen")
	await _until(func(): return not WorkTogether.active(), 40.0, "the shift ends by itself")
	var ended: Array = WorkTogether._ended
	_check(not ended.is_empty() and ended[-1].get("exhausted", false), "the cat stopped tired (%s)" % [ended[-1] if not ended.is_empty() else {}])
	await get_tree().create_timer(1.0).timeout
	_check(absf(WorkTogether.now() - Time.get_unix_time_from_system()) < 5.0, "time runs normally again")
	main.go("garden")
	# 3 ひとこと評価
	await _until(func(): return _screen() == "screen_garden.gd" and DemoRoute.node._desk(main.current) != null and DemoRoute.node._desk(main.current).rv_send != null and is_instance_valid(DemoRoute.node._desk(main.current).rv_send), 8.0, "the quick review opens")
	desk = DemoRoute.node._desk(main.current)
	desk.rv_stars = 5
	desk._send_review(desk.rv_shift if not desk.rv_shift.is_empty() else Shifts.all()[0])
	# 4 すくい
	await _until(func(): return _screen() == "screen_scoop.gd", 8.0, "goes to the scoop")
	var sc = main.current
	await get_tree().create_timer(0.5).timeout
	if _screen() != "screen_scoop.gd":
		print("DEMO ROUTE TEST FAIL (stopped at %s)" % _screen())
		get_tree().quit(1)
		return
	_check(sc.orbs.size() == 1 and String(sc.orbs[0].data.content.get("special", "")) == pick, "one cat orb holding the same special (%s)" % pick)
	GameState.orbs.append({"type": "hall", "rare": true, "content": sc.orbs[0].data.content}) # すくった
	await _until(func(): return GameState.scooped_tonight, 6.0, "the night ends after the catch")
	await get_tree().create_timer(0.8).timeout
	main.go("garden")
	# 5 朝：動画
	await _until(func(): return _screen() == "screen_hatch.gd", 6.0, "the hatch morning")
	var saw := await _until(func(): return main.current.get_children().any(func(c): return c is SpecialReveal), 10.0, "the reveal video plays")
	if saw:
		for c in main.current.get_children():
			if c is SpecialReveal:
				c._finish()
	await get_tree().create_timer(1.5).timeout
	_check(GameState.seen.has(pick), "the special is obtained")
	main.current._to_garden()
	# 6 最後のカード
	await _until(func(): return DemoRoute.node != null and DemoRoute.node.layer.get_node_or_null("Final") != null, 8.0, "the final card")
	print("demo route (automated) took %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	print("DEMO ROUTE TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
