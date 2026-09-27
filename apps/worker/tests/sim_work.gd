extends SceneTree
## "Work together" balance: coins by shift length, overtime ("still tired" the next day), daily cap, split shifts.
## There is no sleep factor: only the cat getting tired limits a day.
## Also checks the rules: longer hours never pay more after exhaustion, the cap holds,
## overtime costs tomorrow's mood, and nets are the same for any length.
## godot --headless --path . -s tests/sim_work.gd   (OBAKE_NOSAVE is set by the test itself)

var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL: ", what)


func _initialize() -> void:
	OS.set_environment("OBAKE_NOSAVE", "1")
	await process_frame
	var gs = root.get_node("GameState")
	gs.reset("solo")
	Wallet.reset()
	WorkTogether.reset()
	Shifts.reset()

	print("== coins by shift length (one shift, fresh day / the day after overtime)")
	print("hours   fresh  still tired")
	var hours_list := [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 7.5, 8.0, 9.0, 10.0, 12.0]
	var prev := {}
	for h in hours_list:
		var row := "%5.1f  " % h
		for k in 2:
			var mult: float = 1.0 if k == 0 else WorkTogether.OVERTIME_MOOD
			var c: int = mini(int(floor(WorkTogether.coins_between(0.0, h, mult))), WorkTogether.DAILY_CAP)
			row += "  %6d" % c
			if prev.has(k):
				check(c >= prev[k], "coins go down with more hours? %d h %.1f" % [k, h])
				if h > WorkTogether.EXHAUST_HOURS:
					check(c == prev[k], "more than %.1fh must not pay more (%d, %.1fh)" % [WorkTogether.EXHAUST_HOURS, k, h])
			prev[k] = c
		print(row)
	check(WorkTogether.day_mult(1790000000.0) == 1.0, "a normal day has no multiplier (no sleep factor)")

	print("== coins per hour by hour of the shift")
	for i in 9:
		var c := WorkTogether.coins_between(i, i + 1, 1.0)
		print("  hour %d→%d: %5.1f coins  (energy %.0f%%)" % [i, i + 1, c, WorkTogether.energy(i + 0.5) * 100])

	# ---- real sessions with the session API (time given explicitly)
	var t0 := 1790000000.0 # a fixed day
	var day := 86400.0
	print("== 6h shift (manual start/stop)")
	WorkTogether.start("kitchen", "Cafe", t0 + 9 * 3600)
	var mid := WorkTogether.status(t0 + 12 * 3600)
	print("  after 3h: coins %d, stage %s, energy %.0f%%" % [mid.coins, mid.stage, mid.energy * 100])
	var r6 := WorkTogether.stop(t0 + 15 * 3600)
	print("  end: %d coins, nets +%d, exhausted %s" % [r6.coins, r6.nets, r6.exhausted])
	check(r6.nets == 2, "a shift gives 2 nets")
	check(Wallet.balance() == r6.coins, "coins go to the Wallet")

	print("== 11h shift the next day (overtime)")
	WorkTogether.reset()
	Wallet.reset()
	gs.reset("solo")
	WorkTogether.start("hall", "Izakaya", t0 + day + 8 * 3600)
	var r11 := WorkTogether.stop(t0 + day + 19 * 3600)
	print("  11h: %d coins, overtime %d min, nets +%d, tomorrow's mood penalty %s" % [r11.coins, r11.overtime_min, r11.nets, r11.mood_penalty_tomorrow])
	WorkTogether.reset()
	gs.reset("solo")
	WorkTogether.start("hall", "Izakaya", t0 + day + 8 * 3600)
	var r75 := WorkTogether.stop(t0 + day + 15.5 * 3600)
	check(r11.coins == r75.coins, "11h pays the same as 7.5h (%d vs %d)" % [r11.coins, r75.coins])
	check(r11.nets == 2 and r75.nets == 2, "nets are the same for any length (%d, %d)" % [r11.nets, r75.nets])
	check(r11.mood_penalty_tomorrow and not r75.mood_penalty_tomorrow, "only overtime costs tomorrow's mood")
	# the day after the 11h shift
	WorkTogether.reset()
	gs.reset("solo")
	WorkTogether.start("hall", "", t0 + day + 8 * 3600)
	WorkTogether.stop(t0 + day + 19 * 3600)
	WorkTogether.start("hall", "", t0 + 2 * day + 9 * 3600)
	var after_ot := WorkTogether.stop(t0 + 2 * day + 15 * 3600)
	WorkTogether.reset()
	gs.reset("solo")
	WorkTogether.start("hall", "", t0 + 2 * day + 9 * 3600)
	var normal := WorkTogether.stop(t0 + 2 * day + 15 * 3600)
	print("  6h the day after overtime: %d coins (normal day %d)" % [after_ot.coins, normal.coins])
	check(after_ot.coins < normal.coins, "overtime makes the next day earn less")
	check(absf(float(after_ot.coins) / float(normal.coins) - WorkTogether.OVERTIME_MOOD) < 0.02, "the day after overtime is ×%.2f (%d / %d)" % [WorkTogether.OVERTIME_MOOD, after_ot.coins, normal.coins])

	print("== split shifts share the day's tiredness (4h + 4h vs 8h)")
	WorkTogether.reset()
	gs.reset("solo")
	WorkTogether.start("dish", "", t0 + 3 * day + 8 * 3600)
	var a := WorkTogether.stop(t0 + 3 * day + 12 * 3600)
	WorkTogether.start("dish", "", t0 + 3 * day + 13 * 3600)
	var b := WorkTogether.stop(t0 + 3 * day + 17 * 3600)
	WorkTogether.reset()
	gs.reset("solo")
	WorkTogether.start("dish", "", t0 + 3 * day + 8 * 3600)
	var one := WorkTogether.stop(t0 + 3 * day + 16 * 3600)
	print("  4h+4h = %d + %d = %d, one 8h = %d" % [a.coins, b.coins, a.coins + b.coins, one.coins])
	check(absi(a.coins + b.coins - one.coins) <= 1, "splitting a day does not reset tiredness")
	check(b.nets == 0, "nets once per day")

	print("== registered shift (Shifts) starts and ends by itself")
	WorkTogether.reset()
	gs.reset("solo")
	Shifts.reset()
	Shifts.add({"id": "s1", "title": "Floor staff", "place": "Torimaru", "role": "hall", "start": t0 + 4 * day + 17 * 3600, "end": t0 + 4 * day + 22 * 3600, "wage": 1200, "pay": "weekly"})
	WorkTogether.sync(t0 + 4 * day + 16 * 3600)
	check(not WorkTogether.active(), "no session before the shift")
	WorkTogether.sync(t0 + 4 * day + 18 * 3600)
	check(WorkTogether.active() and WorkTogether.session().source == "shift", "session starts during the shift")
	var ended := WorkTogether.sync(t0 + 4 * day + 23 * 3600)
	check(not ended.is_empty() and absf(ended.hours - 5.0) < 0.01, "session ends at the shift end (%.2fh)" % ended.get("hours", -1.0))
	WorkTogether.sync(t0 + 4 * day + 21 * 3600)
	check(not WorkTogether.active(), "an ended shift does not start again")
	check(gs.last_shift_ended.get("shift_id", "") == "s1", "shift_ended hook is set for the quick review")
	check(WorkTogether.pop_ended().size() >= 1 and WorkTogether.pop_ended().is_empty(), "pop_ended hands each ended shift over once")

	print("== a week of 5 shifts")
	for hrs in [5.0, 7.5, 10.0]:
		WorkTogether.reset()
		Wallet.reset()
		gs.reset("solo")
		for d in 5:
			WorkTogether.start("register", "", t0 + (10 + d) * day + 9 * 3600)
			WorkTogether.stop(t0 + (10 + d) * day + (9 + hrs) * 3600)
		print("  %4.1fh × 5: %d coins" % [hrs, Wallet.balance()])
	print("PASS" if fails == 0 else "FAILED %d" % fails)
	quit(0 if fails == 0 else 1)
