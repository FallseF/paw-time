extends SceneTree
## 実際の時計：夕方 5 時で夜になり、次の日付の朝 5 時をすぎると夜が明ける（玉がかえる）。入力はいらない。
## godot --headless --path . -s tests/test_clock.gd

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _run() -> void:
	OS.set_environment("OBAKE_NOSAVE", "1")
	var gs = root.get_node("GameState")
	gs.reset("solo")
	# 端末の時間帯の 2026-10-05 0:00（月曜）
	var bias: float = Time.get_time_zone_from_system().get("bias", 0) * 60.0
	var d0 := Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 5, "hour": 0, "minute": 0, "second": 0}) - bias
	var h := func(hours: float) -> float: return d0 + hours * 3600.0
	gs.phase = "day"
	_check(not gs.sync_clock(h.call(10.0)) and gs.phase == "day" and gs.clock_date == "2026-10-05", "morning 10:00 stays day (%s %s)" % [gs.phase, gs.clock_date])
	_check(not gs.sync_clock(h.call(16.9)) and gs.phase == "day", "16:54 is still day")
	_check(not gs.sync_clock(h.call(17.5)) and gs.phase == "evening", "17:30 is evening")
	gs.orbs = [{"type": "hall", "rare": false, "content": {"kind": "obake"}}]
	var day_before: int = gs.day
	_check(not gs.sync_clock(h.call(26.0)) and gs.phase == "evening", "2:00 after midnight is still the same night")
	_check(gs.sync_clock(h.call(29.5)) and gs.phase == "morning" and gs.day == day_before + 1, "5:30 next day: the night ends")
	_check(not gs.hatched.is_empty() and gs.orbs.is_empty(), "orbs hatch in the morning")
	_check(not gs.sync_clock(h.call(30.0)) and gs.day == day_before + 1, "the same morning does not end twice")
	# 何日も開かなかった：夜が明けるのは一度だけ（まとめて進めない）
	gs.phase = "day"
	_check(gs.sync_clock(h.call(24.0 * 4 + 9.0)) and gs.day == day_before + 2, "days away: one morning (%d)" % gs.day)
	_check(gs.real_phase(h.call(4.0)) == "evening" and gs.real_phase(h.call(5.0)) == "day" and gs.real_phase(h.call(17.0)) == "evening", "real_phase edges")
	print("CLOCK TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
