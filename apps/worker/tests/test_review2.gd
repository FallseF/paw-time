extends SceneTree
## ユーザーレビュー2の、画面を持たない決まりごと：
##   OBAKE_NOSAVE=1 godot --headless --path . -s tests/test_review2.gd
## 1. 帰ったあとの「今日のお給料（目安）」＝ 登録したシフトの時間 × そのシフトの時給（時給の無いシフトは出さない）
## 3. いかだの行き先えらびの「友だちの島」（新しい順・同じ島は 1 つ・お店の島は入れない・リンクからコードだけ）
## 2. 求人・自分のシフトの曜日のカード（日本時間の日ごと。1 週間は毎日カード、月〜日が一度ずつ、中は時刻の順）

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _run() -> void:
	TranslationServer.set_locale("en")
	if OS.get_environment("OBAKE_NOSAVE") == "":
		print("run with OBAKE_NOSAVE=1")
		quit(2)
		return
	_pay()
	_days()
	_friends()
	print("REVIEW2 TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


# ---------------------------------------------------------------- 1. お給料の目安

func _pay() -> void:
	var t0 := 1790000000.0 # ある日の日中
	var a := {"id": "a", "start": t0, "end": t0 + 5 * 3600, "wage": 1390}
	var b := {"id": "b", "start": t0 + 86400, "end": t0 + 86400 + 4.5 * 3600, "wage": 1200}
	var m := {"id": "m", "start": t0 + 2 * 86400, "end": t0 + 2 * 86400 + 3600, "manual": true}
	var shifts := [a, b, m]
	# 終わった勤務のシフトの時給 × そのシフトの時間（働いた時間の長さではない）
	var e := WorkTogether.pay_estimate({"shift_id": "a", "start": t0 + 60, "hours": 0.02}, shifts)
	_check(e.get("yen", -1) == 6950 and e.get("wage", 0) == 1390 and is_equal_approx(float(e.get("hours", 0)), 5.0), "5h x 1390 = 6950 (%s)" % [e])
	# 半端な時間：4.5h x 1200 = 5400
	e = WorkTogether.pay_estimate({"shift_id": "b", "start": t0 + 86400}, shifts)
	_check(e.get("yen", -1) == 5400, "4.5h x 1200 = 5400 (%s)" % [e])
	# 手で始めた勤務（shift_id なし）でも、同じ日の時給つきのシフトから
	e = WorkTogether.pay_estimate({"shift_id": "", "start": t0 + 1800}, shifts)
	_check(e.get("shift_id", "") == "a" and e.get("yen", -1) == 6950, "manual session uses that day's registered shift (%s)" % [e])
	# 自分で入れたシフト（時給なし）・シフトの無い日は、目安を出さない
	_check(WorkTogether.pay_estimate({"shift_id": "m", "start": t0 + 2 * 86400}, shifts).is_empty(), "no wage, no estimate")
	_check(WorkTogether.pay_estimate({"shift_id": "", "start": t0 + 5 * 86400}, shifts).is_empty(), "no shift that day, no estimate")
	_check(WorkTogether.pay_estimate({"shift_id": "a", "start": t0}, []).is_empty(), "no shifts at all")


# ---------------------------------------------------------------- 2. 曜日のカード

func _days() -> void:
	var JD = load("res://scripts/job_desk.gd") # JobDesk は GameState（autoload）を使うので、読み込みは実行時に（test_jobs と同じ）
	var jst := JobListings.JST
	var d0 := 1790035200 - jst # 日本時間のある日の 0 時
	_check(JD.day0_of(d0 + 23.5 * 3600) == d0 and JD.day0_of(d0 + 24 * 3600) == d0 + 86400, "day0_of splits at JST midnight")
	var j := func(id: String, day: int, hour: float) -> Dictionary:
		return {"id": id, "start": d0 + day * 86400 + hour * 3600, "end": d0 + day * 86400 + (hour + 4) * 3600}
	# 翌日（day 1）から 1 週間。day 3 に 2 件（遅い方を先に入れる）、day 1 に 1 件、週の外（day 10）に 1 件
	var list := [j.call("late", 3, 17.0), j.call("a", 1, 9.0), j.call("early", 3, 10.0), j.call("far", 10, 12.0)]
	var g: Array = JD.day_groups(list, d0 + 86400, 7)
	_check(g.size() == 8, "7 day cards + 1 extra day (%d)" % g.size())
	var wds := {}
	for i in 7:
		_check(g[i].d0 == d0 + (i + 1) * 86400, "day %d in date order" % i)
		wds[JobListings.weekday_mon(g[i].d0)] = true
	_check(wds.size() == 7, "the week shows each weekday once (Mon..Sun)")
	_check(g[0].items.map(func(x): return x.id) == ["a"], "day 1 holds its job")
	_check(g[2].items.map(func(x): return x.id) == ["early", "late"], "jobs in a day are in time order")
	_check(g[1].items.is_empty() and g[3].items.is_empty(), "days without jobs still get a card")
	_check(g[7].d0 == d0 + 10 * 86400 and g[7].items[0].id == "far", "a job outside the week gets its own card at the end")
	var total := 0
	for x in g:
		total += x.items.size()
	_check(total == list.size(), "every job is on exactly one card")
	# 自分のシフト：今日から。今日の夜遅く（23:30 JST）に始まるシフトは今日のカード
	var s: Array = JD.day_groups([{"id": "night", "start": d0 + 23.5 * 3600, "end": d0 + 27 * 3600}], d0, 7)
	_check(s.size() == 7 and s[0].items.size() == 1, "a late-night shift stays on its start day")
	# 見出しと時刻（英語）
	_check(JD.clock_range(j.call("x", 0, 9.5)) == "09:30–13:30", "clock range %s" % JD.clock_range(j.call("x", 0, 9.5)))
	var lbl: String = JD.day_label(d0)
	_check(lbl.begins_with(TranslationServer.translate("JOB_WD_%d" % JobListings.weekday_mon(d0))) and lbl.contains("/"), "day label %s" % lbl)


# ---------------------------------------------------------------- 3. 友だちの島

func _friends() -> void:
	FriendIslands.reset()
	_check(FriendIslands.parse_code("  https://example.com/paw/#island=AbC-12_x  ") == "AbC-12_x", "code from a pasted link")
	_check(FriendIslands.parse_code("AbC") == "AbC", "plain code stays")
	FriendIslands.record({"code": "AAA", "name": "mika", "level": 3}, 100.0)
	FriendIslands.record({"code": "BBB", "name": "ren", "level": 1}, 200.0)
	FriendIslands.record({"code": "https://x/#island=AAA", "name": "mika", "level": 4}, 300.0)
	FriendIslands.record({"shop": "cafe_komorebi", "code": "", "name": "Cafe"}, 400.0)
	FriendIslands.record({"code": "", "name": "nobody"}, 500.0)
	var l := FriendIslands.all()
	_check(l.map(func(e): return e.code) == ["AAA", "BBB"], "newest first, one per island, no shops (%s)" % [l])
	_check(int(l[0].level) == 4, "revisit updates the level")
	for i in 20:
		FriendIslands.record({"code": "C%d" % i, "name": "n", "level": 0}, 1000.0 + i)
	_check(FriendIslands.all().size() == FriendIslands.MAX, "list is capped at %d" % FriendIslands.MAX)
	FriendIslands.reset()
