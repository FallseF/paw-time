extends Node
## レジのおさらいのお金の表示：英語はドル（$）、日本語は円（¥）。英語の画面に ¥ が、日本語の画面に $ が出たら FAIL。
## 画面の字（Label / Button / Label3D）を、注文 → おつり → ひとことまで 1 人ずつ進めながら見る。
## OBAKE_NOSAVE=1 godot --headless --path . res://tests/test_practice_money.tscn

var fails := 0
var main
var seen := {}
var saw_own := {} # その言語の通貨の記号が、どこかに出たか


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _ready() -> void:
	for kv in [["OBAKE_NOSAVE", "1"], ["OBAKE_START", "garden"], ["OBAKE_ONBOARD", "done"], ["OBAKE_MODE", "solo"], ["OBAKE_NO_REVEAL", "1"], ["OBAKE_PRACTICE_LEVEL", "3"], ["OBAKE_PRACTICE_SEED", "7"]]:
		OS.set_environment(kv[0], kv[1])
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _scan(where: String) -> void:
	var lang := TranslationServer.get_locale().left(2)
	var bad := "¥" if lang == "en" else "$"
	var own := "$" if lang == "en" else "¥"
	for c in main.find_children("*", "", true, false):
		var t := ""
		if c is Label3D:
			t = c.text if c.visible else ""
		elif c is Control and not c.is_visible_in_tree():
			continue
		elif c is Label or c is Button:
			t = c.atr(c.text)
		if t.contains(own):
			saw_own[lang] = true
		var key: String = lang + "|" + t
		if t.contains(bad) and not seen.has(key):
			seen[key] = true
			_check(false, "[%s] %s: %s (%s)" % [lang, where, t.replace("\n", " / "), c.get_class()])


func _run() -> void:
	await _wait(2.0)
	for lang in ["en", "ja"]:
		TranslationServer.set_locale(lang)
		Skills.practice_role = "register"
		main.busy = false
		await main.go("practice", true)
		await _wait(1.0)
		var p = main.current
		_scan("intro")
		p.demo_start()
		await _wait(1.2)
		for i in 60:
			if p.overlay:
				break
			_scan("step %d (%s)" % [i, p.game.phase])
			p.demo_step()
			await _wait(0.5)
		_check(p.overlay != null, "[%s] the register practice reached the end" % lang)
		_check(saw_own.get(lang, false), "[%s] the practice shows its own currency somewhere" % lang)
	print("PRACTICE MONEY ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
