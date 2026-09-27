extends Node
## 「しごとの条件」（screen_job_prefs）が 360 幅に収まる：カードも中のボタン・字も、右のはしで切れない（英語・日本語）。
## OBAKE_NOSAVE=1 godot --headless --path . res://tests/test_prefs_fit.tscn

var fails := 0
var main


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _ready() -> void:
	for kv in [["OBAKE_NOSAVE", "1"], ["OBAKE_START", "garden"], ["OBAKE_ONBOARD", "done"], ["OBAKE_MODE", "solo"], ["OBAKE_NO_REVEAL", "1"]]:
		OS.set_environment(kv[0], kv[1])
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _run() -> void:
	await _wait(1.5)
	for lang in ["en", "ja"]:
		TranslationServer.set_locale(lang)
		main.busy = false
		await main.go("prefs", true)
		await _wait(1.0)
		var p = main.current
		var sc: ScrollContainer = p.scroll
		var bad := 0
		# スクロールの中の物は、画面の 360 幅（左右 16 の余白の内側）に収まる
		for c in sc.find_children("*", "Control", true, false):
			if not c.is_visible_in_tree() or c is ScrollBar:
				continue
			var r: Rect2 = c.get_global_rect()
			var right: float = r.end.x - (p as Control).get_global_rect().position.x
			if right > 360.5 and bad < 6:
				bad += 1
				_check(false, "[%s] %s %s sticks out to x=%.0f (%s)" % [lang, c.get_class(), c.name, right, c.get("text") if c.get("text") != null else ""])
		_check(sc.get_child(0).size.x <= 360.5, "[%s] the content is not wider than the screen (%.0f)" % [lang, sc.get_child(0).size.x])
	print("PREFS FIT ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
