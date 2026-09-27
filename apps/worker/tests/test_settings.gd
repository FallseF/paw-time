extends Node
## マイページ（scripts/screen_settings.gd）：重ねて開く・名前・言語・チャットのひみつ・利用データ・プライバシー・やり直し。
## 利用データの項目が働く条件の画面から消えたことも確かめる。
## OBAKE_NOSAVE=1 godot --headless --path . res://tests/test_settings.tscn

var fails := 0
var main


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _texts(n: Node) -> String:
	var out := ""
	for c in n.find_children("*", "", true, false):
		if c is Label or c is Button:
			out += c.text + "\n"
	return out


func _ready() -> void:
	QuizResult.path = "user://test_settings_my_obake.json"
	ChatMe.persist = false
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	TranslationServer.set_locale("en")
	GameState.set_my_obake(SpecialObake.apply(QuizData.score(QuizData.answers_for("OFHK"))))

	# 1 働く条件の画面には、利用データの項目がもう無い
	await main.go("prefs", true)
	var pt := _texts(main.current)
	_check(not pt.contains(tr("TELEMETRY_DELETE")) and not pt.contains(tr("TELEMETRY_TOGGLE")), "usage data is gone from Work conditions")

	# 2 島などの上に重ねて開く
	await main.go("title", true)
	var s := SettingsScreen.open(main.current)
	await get_tree().process_frame
	await get_tree().process_frame
	var st := _texts(s)
	for k in ["SETTINGS_TITLE", "SETTINGS_NAME", "SETTINGS_LANG", "SETTINGS_CHAT", "TELEMETRY_TOGGLE", "TELEMETRY_DELETE", "SETTINGS_PRIVACY", "SETTINGS_RESET"]:
		_check(st.contains(tr(k)), "My page shows %s" % k)
	_check(st.contains(tr("PRIVACY_CHAT")), "the privacy text (chat) is in My page")

	# 2b 効果音のつまみ（音楽のつまみの下）
	_check(s.sfx_slider != null and s.sfx_slider.is_inside_tree() and st.contains("Sound effects"), "My page has the sound effects slider")
	s.set_sfx_volume(0.4)
	_check(is_equal_approx(Sfx.volume, 0.4) and absf(Sfx.bus_db() - linear_to_db(0.16)) < 0.01, "sound effects volume set from My page")
	s.set_sfx_volume(0.8)

	# 3 名前
	s.name_edit.text = "  Kuro  "
	s.save_name()
	_check(SpecialObake.pet_name() == "Kuro" and QuizResult.load_result().get("name", "") == "Kuro", "name saved from My page")
	s.name_edit.text = ""
	s.save_name()
	_check(not SpecialObake.has_custom_name(), "empty name goes back to the auto name")

	# 4 チャットの「ふたりだけのひみつ」
	s.set_chat_private(true)
	_check(ChatMe.is_private(), "chat private on")
	s.set_chat_private(false)
	_check(not ChatMe.is_private(), "chat private off")

	# 5 利用データ（送る／送らない）
	var was := Telemetry.is_enabled()
	s.set_usage(false)
	_check(not Telemetry.is_enabled(), "usage data off")
	s.set_usage(was)
	s.delete_usage()
	_check(s.tm_status.text == tr("TELEMETRY_DELETED"), "delete shows the status")

	# 6 言語：切りかえると作り直し、閉じると下の画面もその言語で
	s.set_lang("ja")
	await get_tree().process_frame
	_check(not Kit.is_en() and s.lang_changed, "language switched to ja")
	_check(_texts(s).contains("マイページ"), "My page rebuilt in Japanese")
	var before = main.current
	s.close()
	await get_tree().create_timer(0.3).timeout
	_check(main.current != before and main.current_name == "title", "the screen below is rebuilt after a language change")
	Kit.save_lang("en")

	# 7 プライバシーから開く（チャットの「くわしく」）
	var s2 := SettingsScreen.open(main.current, "privacy")
	for i in 5:
		await get_tree().process_frame
	_check(s2.scroll.scroll_vertical > 0, "opens scrolled to privacy (%d)" % s2.scroll.scroll_vertical)
	s2.close()

	# 8 やり直し：記録（.json）を消し、利用データと言語の設定は残す
	var dir := "user://test_reset/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for f in ["obake_b_save.json", "my_obake.json", "shifts.json", "telemetry.json", "telemetry_notice.json", "settings.cfg"]:
		var fa := FileAccess.open(dir + f, FileAccess.WRITE)
		fa.store_string("{}")
		fa.close()
	var gone: Array = SettingsScreen.erase_saves(dir)
	var left := Array(DirAccess.get_files_at(dir))
	left.sort()
	_check(gone.size() == 3 and left == ["settings.cfg", "telemetry.json", "telemetry_notice.json"], "reset erases saves only (%s)" % [left])
	for f in left:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + f))

	# 9 画面として開く（main.go）→ 閉じると島へ
	await main.go("settings", true)
	_check(main.current is SettingsScreen, "settings is a registered screen")

	# 10 チャットの同意：短い文と「くわしく」→ マイページのプライバシー
	ChatMe._consent = ""
	await main.go("title", true)
	var chat := ChatHub.open(main.current, "me")
	await get_tree().create_timer(0.3).timeout
	var body := tr("CHAT_CONSENT_BODY")
	_check(_texts(chat).contains(body) and body.length() <= 120, "short consent text (%d chars)" % body.length())
	var details: Button = null
	for c in chat.find_children("*", "Button", true, false):
		if (c as Button).text.begins_with(tr("CHAT_CONSENT_DETAILS")):
			details = c
	_check(details != null, "a Details link on the consent card")
	if details:
		details.pressed.emit()
		await get_tree().create_timer(0.2).timeout
		var opened := chat.find_children("*", "SettingsScreen", true, false)
		_check(not opened.is_empty() and opened[0].focus == "privacy", "Details opens My page at Privacy")

	QuizResult.clear()
	print("SETTINGS TEST ", "OK" if fails == 0 else "FAILED (%d)" % fails)
	get_tree().quit(1 if fails else 0)
