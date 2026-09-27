extends Node
## はじめての流れを通しで撮る（レビュー用の画面写真）。診断の結果 → 名前 → シフトへ → 早送りの見本のシフト →
## いっしょにがんばったね → はじめてのすくい → 結果 → 朝の孵化、それとチャットの同意・マイページ。
##   HOME=$(mktemp -d) OBAKE_NOSAVE=1 OBAKE_LANG=en CAP_OUT=ui_review/review2 \
##     godot --path . --always-on-top res://tests/capture_onboarding.tscn
## CAP_OUT/<言語>_NN_<場面>.png に書く。

var main
var out := ""
var lang := "en"


func _ready() -> void:
	out = OS.get_environment("CAP_OUT") if OS.get_environment("CAP_OUT") != "" else "user://cap"
	lang = OS.get_environment("OBAKE_LANG") if OS.get_environment("OBAKE_LANG") != "" else "en"
	DirAccess.make_dir_recursive_absolute(out)
	QuizResult.clear()
	GameState.my_obake = {}
	Onboarding.reset()
	WorkTogether.reset()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	var p := out.path_join("%s_%s.png" % [lang, n])
	get_viewport().get_texture().get_image().save_png(p)
	print("shot ", p)


func _run() -> void:
	await _wait(1.0)
	var q = main.current
	q._auto_answer("ABABABABABAB")
	await _wait(6.0)
	await _shot("01_quiz_reveal")
	q._begin()
	await _wait(1.5)
	var ob = main.current
	await _shot("02_name_input")
	ob.name_edit.text = "Mochi" if lang == "en" else "もち"
	ob.name_edit.grab_focus()
	ob.name_edit.caret_column = ob.name_edit.text.length()
	await _wait(0.3)
	await _shot("03_name_typed")
	ob.demo_name()
	await _wait(0.8)
	await _shot("04_go_to_shift")
	ob.demo_start()
	await _wait(4.0)
	await _shot("05_mock_shift")
	await _wait(6.0)
	await _shot("06_together")
	ob.demo_river()
	await _wait(1.8)
	await _shot("07_first_scoop")
	await _wait(6.5)
	await _shot("08_scoop_coach_gone")
	var sc = main.current
	GameState.orbs = Onboarding.tutorial_orbs()
	sc.caught_count = 3
	sc._finish()
	await _wait(1.0)
	await _shot("09_scoop_result")
	main.go(Onboarding.next_after("catch", "garden"))
	await _wait(2.5)
	await _shot("10_morning_hatch")
	await _wait(6.0)
	await _shot("11_morning_hatch_open")
	# チャットの同意とマイページ（タイトルの上に重ねて）
	await main.go("title", true)
	ChatMe.persist = false
	ChatMe._consent = ""
	var chat := ChatHub.open(main.current, "me")
	await _wait(1.2)
	await _shot("12_chat_consent")
	chat.queue_free()
	var s := SettingsScreen.open(main.current)
	await _wait(0.8)
	await _shot("13_settings_top")
	s.scroll.scroll_vertical = 330
	await _wait(0.4)
	await _shot("14_settings_usage")
	s.demo_privacy()
	await _wait(0.5)
	await _shot("15_settings_privacy")
	s.scroll.scroll_vertical = 100000
	s.demo_reset()
	await _wait(0.6)
	await _shot("16_settings_reset_confirm")
	QuizResult.clear()
	get_tree().quit()
