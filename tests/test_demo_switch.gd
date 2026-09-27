extends Node
## デモの見せ場の切りかえ（scripts/demo_switch.gd）：どの場面も本物の状態（Shifts・WorkTogether・時計）を作る。
## シフト中は仕事場だけ（4379f4b の遊ばないルール）を守り、終われば島・ひとこと評価へ、次の朝は玉がかえる。
## 島の時計（GameState の autoload）を使うので、-s ではなく場面として動かす：
## OBAKE_NOSAVE=1 godot --headless --path . res://tests/test_demo_switch.tscn

var fails := 0


class FakeMain:
	extends Node
	var went := ""
	func go(n: String, _instant := false) -> void:
		if not WorkTogether.screen_allowed(n):
			n = "work"
		if n == "garden":
			get_node("/root/GameState").sync_clock()
		went = n


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _run() -> void:
	OS.set_environment("OBAKE_NOSAVE", "1")
	var gs = GameState
	var root := get_tree().root
	await get_tree().process_frame
	gs.reset("solo")
	Shifts.reset()
	WorkTogether.reset()
	Reviews.reset()
	var fm := FakeMain.new()
	root.add_child(fm)
	var ds := DemoSwitch.new()
	ds.main = fm
	root.add_child(ds)
	await get_tree().process_frame
	_check(ds.get_child_count() >= 1, "the Demo chip is there")

	# シフトの 1 時間前：島は開いていて、1 時間後のシフトが入っている。昼の時刻
	ds._before()
	var real := Time.get_unix_time_from_system()
	var up: Array = Shifts.upcoming(real)
	_check(not up.is_empty() and absf(float(up[0].start) - real - 3600.0) < 5.0, "before: a shift starts in 1 h")
	_check(fm.went == "garden", "before: goes to the island (went %s)" % fm.went)
	_check(GameState.real_phase() == "day", "before: daytime on the island clock")
	_check(WorkTogether.upcoming_line() != "", "before: the 'see you at work' line shows")

	# シフト中（早送り）：仕事場だけ。時間が早く進む
	ds._on_shift()
	_check(fm.went == "work", "on shift: goes to the work screen")
	_check(not WorkTogether.screen_allowed("garden"), "on shift: the island stays locked (play lock)")
	_check(WorkTogether.active(), "on shift: a real WorkTogether session")
	var h0: float = WorkTogether.status().hours_session
	await get_tree().create_timer(0.5).timeout
	var h1: float = WorkTogether.status().hours_session
	_check(h1 - h0 > 0.03, "on shift: fast-forward runs (%.3f h in 0.5 s)" % (h1 - h0))
	# 早送りでシフトの終わりまで
	var ended := WorkTogether.sync(float(WorkTogether.session().end_at) + 1.0)
	_check(not ended.is_empty(), "on shift: the shift ends at its end time")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(absf(WorkTogether.now() - Time.get_unix_time_from_system()) < 5.0, "after the fast shift: time runs normally again")
	_check(WorkTogether.screen_allowed("garden"), "after the fast shift: the island opens again")
	WorkTogether.pop_ended()

	# シフトが終わった：2 秒後に終わる。疲れた結果とひとこと評価の相手
	ds._finished()
	_check(fm.went == "work", "finished: goes to the work screen")
	await get_tree().create_timer(2.5).timeout
	var e := WorkTogether.sync()
	_check(not e.is_empty(), "finished: the shift ends by itself")
	_check(WorkTogether.stage_for(float(e.get("hours", 0.0))) in ["tired", "sleepy", "exhausted"], "finished: the cat is tired (%s h)" % e.get("hours", 0.0))
	_check(int(e.get("coins", 0)) > 0, "finished: coins paid")
	var rv := Reviews.target_for_ended(WorkTogether.pop_ended())
	_check(not rv.is_empty(), "finished: the quick review opens for that shift")
	fm.go("garden")
	_check(fm.went == "garden", "finished: the island is open after the shift")

	# シフト中から次の朝へ：仕事場に閉じこめられず、夜が明けて朝になる
	ds._on_shift()
	var day0: int = gs.day
	ds._next_morning()
	_check(fm.went == "garden", "next morning: goes to the island, not stuck at work (went %s)" % fm.went)
	_check(gs.phase == "morning" and gs.day == day0 + 1, "next morning: the night ended (phase %s, day %d→%d)" % [gs.phase, day0, gs.day])
	GameState.clock_offset = 0.0
	print("DEMO SWITCH TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
