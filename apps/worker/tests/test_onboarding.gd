extends Node
## はじめての流れ（scripts/onboarding.gd）を本物の画面で通す：
##   診断 → 診断の結果（相棒に会う）→ 相棒の名前（候補から選ぶ・打つ。保存して、あちこちで同じ名前）→ シフトへ → 早送りの見本のシフト（猫の仕事場）→ いっしょにがんばったね（コインとポイ）
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

	# 名前の候補：英語版は英語（ASCII）の名前、日本語版は日本語の名前。同じ相棒なら同じ並び
	var my_d := SpecialObake.apply(QuizData.score(QuizData.answers_for("IFHY")))
	TranslationServer.set_locale("ja")
	var ideas_ja := SpecialObake.name_ideas(3, my_d)
	_check(ideas_ja.size() == 3 and ideas_ja.all(func(n): return SpecialObake.NAME_IDEAS.ja.has(n)), "Japanese name ideas in Japanese (%s)" % [ideas_ja])
	TranslationServer.set_locale("en")
	var ideas := SpecialObake.name_ideas(3, my_d)
	_check(ideas.size() == 3 and ideas.all(func(n): return SpecialObake.NAME_IDEAS.en.has(n) and _ascii(n)), "English name ideas are English (%s)" % [ideas])
	_check(ideas == SpecialObake.name_ideas(3, my_d), "the ideas are stable for the same cat")

	# 1 診断（名前はまだ聞かない）
	await _until(func(): return _screen() == "screen_quiz.gd", 5.0, "first launch opens the quiz")
	var q = main.current
	await get_tree().create_timer(0.3).timeout
	_check(q.find_children("*", "LineEdit", true, false).is_empty(), "no name input during the quiz")
	_check(GameState.my_obake.is_empty() and not SpecialObake.has_custom_name(), "no partner and no name before the quiz is done")
	q.result = my_d
	q._begin()
	await _until(func(): return _screen() == "screen_onboard.gd", 5.0, "quiz → the onboarding screen")
	_check(not GameState.my_obake.is_empty(), "the name step comes after the quiz result (the partner exists)")
	_check(Onboarding.at("shift"), "step is shift (%s)" % Onboarding.step())
	var ob = main.current
	await get_tree().create_timer(0.3).timeout

	# 2 名前（英語版は英語の候補のはじめが入っている → 候補をタップ／打って、自分の名前にする）
	_check(ob.phase == "name", "starts with the name input (%s)" % ob.phase)
	var shown := SpecialObake.pet_name(SpecialObake._without_name(GameState.my_obake))
	_check(ob.name_edit.text == shown and shown != "", "prefilled with the name the quiz result showed (%s / %s)" % [ob.name_edit.text, shown])
	var chips: Array = ob.chip_names()
	_check(chips[0] == shown and chips.size() == 4, "the quiz's name is the first chip (%s)" % [chips])
	_check(ob.name_edit.max_length == SpecialObake.NAME_MAX, "max length")
	_check(ob.main_btn != null and ob.main_btn.text == tr("ONB_NAME_OK"), "a clear confirm button")
	ob.demo_pick(1)
	_check(ob.name_edit.text == chips[1] and SpecialObake.NAME_IDEAS.en.has(chips[1]), "tapping an English idea fills it in (%s)" % ob.name_edit.text)
	ob.demo_name("  Mochi  ")
	_check(GameState.my_obake.get("name", "") == "Mochi", "the name is stored in my_obake")
	_check(QuizResult.load_result().get("name", "") == "Mochi", "the name is saved in my_obake.json")
	_check(SpecialObake.pet_name() == "Mochi", "pet_name uses it")
	_check(ScreenChat.cat_name() == "Mochi", "the chat uses it")
	# 読み直しても同じ（次に起動したとき）
	GameState.my_obake = QuizResult.load_result()
	_check(SpecialObake.pet_name() == "Mochi", "the name survives a reload")
	_check(ob.phase == "go", "then: go to your shift (%s)" % ob.phase)
	_check(ob.bubble_l.text.begins_with("Mochi"), "the cat answers with its new name (%s)" % ob.bubble_l.text)
	# 英語の長い名前は NAME_MAX で切る。空なら自動の呼び名へ
	SpecialObake.set_partner_name("Maximilian the Great")
	_check(SpecialObake.pet_name() == "Maximilian", "long ASCII names are cut to %d (%s)" % [SpecialObake.NAME_MAX, SpecialObake.pet_name()])
	SpecialObake.set_partner_name("   ")
	_check(not SpecialObake.has_custom_name(), "an empty name falls back to the automatic one")
	SpecialObake.set_partner_name("Mochi")

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
	# 説明は、半透明の手だけ（文字の説明は出さない）
	_check(sc.hand != null and sc.hand.visible, "the hand tutorial shows on the first scoop")
	_check(not sc.hint.visible and not sc.tip.visible, "no text coaching while the hand shows")
	_check(not sc.get_children().any(func(c): return c is PanelContainer and c.find_children("*", "Label", true, false).any(func(l): return l.text == tr("ONB_SCOOP_COACH"))), "no text coach panel")
	# まとめ：朝を待たせず「玉をあける」
	sc._finish()
	await get_tree().process_frame
	var open_btn: Array = sc.find_children("*", "Button", true, false).filter(func(b): return b.text == tr("ONB_NIGHT_OPEN"))
	_check(not open_btn.is_empty(), "the first-night result goes straight to opening the orbs")

	# 5 結果 → そのまま朝の孵化（夜の場面なし）
	GameState.orbs = Onboarding.tutorial_orbs()
	var nxt := Onboarding.next_after("catch", "garden")
	_check(nxt == "hatch", "scoop result → hatch directly (%s)" % nxt)
	_check(Onboarding.at("island"), "step moves on to island (%s)" % Onboarding.step())
	_check(GameState.hatched.any(func(h): return h.get("special", false)), "the special cat hatches")
	main.go(nxt)
	await _until(func(): return _screen() == "screen_hatch.gd", 5.0, "the morning hatch opens")
	# 材料からひとつずつあけて、特別な子はいちばん最後
	var hs: Array = GameState.hatched
	_check(hs.size() >= 2 and hs.back().get("special", false) and not hs.front().get("special", false), "materials first, the special cat last %s" % [hs.map(func(h): return h.id)])
	_check(main.current.batch_from == hs.size(), "the first morning opens orbs one by one")

	# 6 画面の順番
	var order := visited.filter(func(s): return s in ["screen_quiz.gd", "screen_onboard.gd", "screen_work.gd", "screen_scoop.gd", "screen_hatch.gd", "screen_title.gd"])
	_check(order == ["screen_quiz.gd", "screen_onboard.gd", "screen_scoop.gd", "screen_hatch.gd"], "screen order %s" % [order])

	# 7 見本のシフトの途中で閉じた人：再開すると片づけてから名前の場面へ
	Onboarding.reset()
	Onboarding.advance("shift")
	WorkTogether.start("hall", Onboarding.MOCK_PLACE)
	_check(Onboarding.resume_screen() == "onboard" and not WorkTogether.active(), "resume clears a half-done mock shift")

	# 8 相棒がまだいないのに名前の段にいる（古い保存など）：名前より先に診断へ。診断のあとは名前へ
	var keep: Dictionary = GameState.my_obake
	GameState.my_obake = {}
	_check(Onboarding.resume_screen() == "quiz", "no partner yet → the quiz first, not the name")
	await _until(func(): return not main.busy, 3.0, "the previous screen change finishes")
	main.go("onboard", true)
	await _until(func(): return _screen() == "screen_quiz.gd", 5.0, "the name screen without a partner sends you to the quiz")
	_check(Onboarding.next_after("quiz", "garden") == "onboard", "after the quiz → the name step")
	GameState.my_obake = keep

	QuizResult.clear()
	print("ONBOARDING TEST ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	get_tree().quit(1 if fails else 0)


func _ascii(s: String) -> bool:
	for i in s.length():
		if s.unicode_at(i) > 127:
			return false
	return true


func Main_has_screen(s: String) -> bool:
	return main.SCREENS.has(s)
