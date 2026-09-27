extends SceneTree
## シフトの間は遊ばない：開けるのは猫の仕事場（とタイトル）だけ。お店とのチャットは、いまのシフトのお店だけ。
## シフトが終わったら、いつもどおり（おつかれさまのカード → ひとこと評価）。
## godot --headless --path . -s tests/test_shift_lock.gd

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _run() -> void:
	OS.set_environment("OBAKE_NOSAVE", "1")
	Shifts.reset()
	WorkTogether.reset()
	ChatShops.reset()
	var t0 := 1800000000.0
	# 登録シフト（見本のお店）
	var s := {"id": "lock1", "title": "Hall staff", "place": "Café", "store": "Café Komorebi", "role": "hall", "listing": "cafe_komorebi",
		"start": t0, "end": t0 + 4 * 3600}
	Shifts.add(s)
	_check(WorkTogether.screen_allowed("garden", t0 - 60), "before the shift: the island is open")
	for sc in ["garden", "catch", "wardrobe", "practice", "skills", "zukan", "shop_island", "travel", "prefs", "chat"]:
		_check(not WorkTogether.screen_allowed(sc, t0 + 60), "on shift: %s is locked" % sc)
	_check(WorkTogether.screen_allowed("work", t0 + 60), "on shift: the work screen is open")
	var th := ChatShops.thread_id_for(s)
	_check(ChatHub.allowed_during_shift(th, t0 + 60), "on shift: this shift's shop chat is open")
	_check(not ChatHub.allowed_during_shift("me", t0 + 60), "on shift: my-cat chat is locked")
	# 手で「仕事に行ってくる」
	Shifts.reset()
	WorkTogether.reset()
	WorkTogether.start("dish", "", t0 + 86400)
	_check(not WorkTogether.screen_allowed("garden", t0 + 86400 + 60), "manual session locks the island too")
	WorkTogether.stop(t0 + 86400 + 3 * 3600)
	_check(WorkTogether.screen_allowed("garden", t0 + 86400 + 3 * 3600 + 1), "after the shift: open again")
	print("SHIFT LOCK TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
