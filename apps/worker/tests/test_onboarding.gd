extends Node
## はじめての流れ（scripts/onboarding.gd）を本物の画面で通す：
##   診断 → 相棒の名前（保存して、あちこちで同じ名前）→ シフトへ → 早送りの見本のシフト（猫の仕事場）→ いっしょにがんばったね（コインとポイ）
##   → はじめてのすくい（玉 3 つ・説明は消える）→ 夜の場面を挟まず朝の孵化 → 島の説明の段
## 体験バイト（カフェ）と「川べりの夜」が出ないこと、見本のシフトが本物の仕事の記録に残らないことも確かめる。
## OBAKE_NOSAVE=1 godot --headless --path . res://tests/test_onboarding.tscn

var fails := 0
var main
var visited: Array = []


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


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
	return main.current.get_script().resource_path.get_file() if main and main.current else ""


func _ready() -> void:
	# 本物の診断結果に触れないよう、別のファイルで。はじめての人として起動する
	QuizResult.path = "user://test_onboarding_my_obake.json"
	QuizResult.clear()
	GameState.my_obake = {}
	Onboarding.reset()
	WorkTogether.reset()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _process(_d: float) -> void:
	var s := _screen()
	if s != "" and (visited.is_empty() or visited[-1] != s):
		visited.append(s)


func _run() -> void:
	# 0 名前のととのえ方（純粋な関数）
	_check(SpecialObake.clean_name("  Mochi\n ") == "Mochi", "trims the name")
	_check(SpecialObake.clean_name("abcdefghijklmnop").length() == SpecialObake.NAME_MAX, "caps the name length")
	_check(not Main_has_screen("onboard_night"), "the riverside night screen is gone")

	# 1 診断
	await _until(func(): return _screen() == "screen_quiz.gd", 5.0, "first launch opens the quiz")
	var q = main.current
	q.result = SpecialObake.apply(QuizData.score(QuizData.answers_for("IFHY")))
	q._begin()
	await _until(func(): return _screen() == "screen_onboard.gd", 5.0, "quiz → the onboarding screen")
	_check(Onboarding.at("shift"), "step is shift (%s)" % Onboarding.step())
	var ob = main.current
	await get_tree().create_timer(0.3).timeout

	# 2 名前（いまの呼び名が入っている → 自分の名前にする）
	_check(ob.phase == "name", "starts with the name input (%s)" % ob.phase)
	var auto_name := SpecialObake.pet_name()
	_check(ob.name_edit.text == auto_name and auto_name != "", "prefilled with the current name (%s)" % ob.name_edit.text)
	_check(ob.name_edit.max_length == SpecialObake.NAME_MAX, "max length")
	ob.demo_name("Mochi")
	_check(GameState.my_obake.get("name", "") == "Mochi", "the name is stored in my_obake")
	_check(QuizResult.load_result().get("name", "") == "Mochi", "the name is saved in my_obake.json")
	_check(SpecialObake.pet_name() == "Mochi", "pet_name uses it")
	_check(ScreenChat.cat_name() == "Mochi", "the chat uses it")
	# 読み直しても同じ（次に起動したとき）
	GameState.my_obake = QuizResult.load_result()
	_check(SpecialObake.pet_name() == "Mochi", "the name survives a reload")
	_check(ob.phase == "go", "then: go to your shift (%s)" % ob.phase)

	# 3 早送りの見本のシフト（猫の仕事場）
	var coins0 := Wallet.balance()
	var nets0: int = GameState.nets.get("bubble", 0)
	ob.demo_start()
	await _until(func(): return ob.phase == "mock" and ob.work != null, 3.0, "the mock shift starts")
	_check(Onboarding.mock_shift_active(), "the cat is working (mock)")
	_check(ob.work.get_script().resource_path.get_file() == "screen_work.gd", "it reuses the cat work screen")
	var t0 := Time.get_ticks_msec()
	await _until(func(): return ob.phase == "done", 15.0, "the mock shift ends by itself")
	var took := (Time.get_ticks_msec() - t0) / 1000.0
	_check(took < 12.0, "fast-forward is short (%.1f s)" % took)
	_check(ob.coins_earned > 0 and Wallet.balance() == coins0 + ob.coins_earned, "paw coins paid (%d)" % ob.coins_earned)
	_check(GameState.nets.get("bubble", 0) == nets0 + 2, "2 poi for the first scoop")
	_check(not WorkTogether.active(), "the mock session is closed")
	_check(float(WorkTogether.today_summary().get("hours", 0.0)) == 0.0, "no real work record from the mock shift")
	_check(absf(WorkTogether.now() - Time.get_unix_time_from_system()) < 5.0, "time runs normally again")
	_check(ob.sheet != null and is_instance_valid(ob.sheet), "the 'We did it together' card shows")

	# 4 はじめてのすくい
	ob.demo_river()
	await _until(func(): return _screen() == "screen_scoop.gd", 5.0, "→ the first scoop")
	_check(Onboarding.at("scoop"), "step is scoop")
	var sc = main.current
	await get_tree().create_timer(0.3).timeout
	var n: int = sc.orbs.size()
	_check(n >= 3 and n <= 4, "3–4 orbs on the first scoop (%d)" % n)
	_check(sc.orbs.any(func(o): return String(o.data.get("content", {}).get("special", "")) != ""), "the special cat orb is among them")
	_check(sc.coach != null and sc.coach.visible, "the coach shows at first")
	await get_tree().create_timer(6.8).timeout
	_check(sc.coach == null or not sc.coach.visible, "the coach hides by itself")

	# 5 結果 → そのまま朝の孵化（夜の場面なし）
	GameState.orbs = Onboarding.tutorial_orbs()
	var nxt := Onboarding.next_after("catch", "garden")
	_check(nxt == "hatch", "scoop result → hatch directly (%s)" % nxt)
	_check(Onboarding.at("island"), "step moves on to island (%s)" % Onboarding.step())
	_check(GameState.hatched.any(func(h): return h.get("special", false)), "the special cat hatches")
	main.go(nxt)
	await _until(func(): return _screen() == "screen_hatch.gd", 5.0, "the morning hatch opens")

	# 6 画面の順番
	var order := visited.filter(func(s): return s in ["screen_quiz.gd", "screen_onboard.gd", "screen_work.gd", "screen_scoop.gd", "screen_hatch.gd", "screen_title.gd"])
	_check(order == ["screen_quiz.gd", "screen_onboard.gd", "screen_scoop.gd", "screen_hatch.gd"], "screen order %s" % [order])

	# 7 見本のシフトの途中で閉じた人：再開すると片づけてから名前の場面へ
	Onboarding.reset()
	Onboarding.advance("shift")
	WorkTogether.start("hall", Onboarding.MOCK_PLACE)
	_check(Onboarding.resume_screen() == "onboard" and not WorkTogether.active(), "resume clears a half-done mock shift")

	QuizResult.clear()
	print("ONBOARDING TEST ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	get_tree().quit(1 if fails else 0)


func Main_has_screen(s: String) -> bool:
	return main.SCREENS.has(s)
