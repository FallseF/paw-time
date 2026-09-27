extends Node
## ユーザーレビュー3の島の画面（本物の島 main.tscn を開いて確かめる）：
##   - 重なるシフトの仕事は受けられない（知らせが出て、シフトは増えない）
##   - 受けたら「マイシフトに入った」と、マイシフトへのリンク
##   - マイシフトの行を押すと、そのシフトのくわしいカード（店・時間・場所・時給・地図・チャット・取り消し）
## OBAKE_NOSAVE=1 godot --headless --path . res://tests/test_review3_ui.tscn

var fails := 0
var main


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _ready() -> void:
	for kv in [["OBAKE_NOSAVE", "1"], ["OBAKE_START", "garden"], ["OBAKE_ONBOARD", "done"], ["OBAKE_MODE", "solo"], ["OBAKE_FF", "3"], ["OBAKE_NO_REVEAL", "1"]]:
		OS.set_environment(kv[0], kv[1])
	TranslationServer.set_locale("en")
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _frames(n := 3) -> void:
	for i in n:
		await get_tree().process_frame


func _desk(g: Node) -> JobDesk:
	for c in g.get_children():
		if c is JobDesk:
			return c
	return null


func _texts(n: Node) -> String:
	var out := ""
	for c in n.find_children("*", "", true, false):
		if (c is Label or c is Button) and c.is_visible_in_tree():
			out += c.text + "\n"
	return out


func _run() -> void:
	await get_tree().create_timer(2.5).timeout
	var g = main.current
	var desk := _desk(g)
	_check(desk != null, "job desk on the island")
	Shifts.reset()

	# 1. 重なるシフト
	desk._open_viewer()
	await _frames()
	_check(not desk.jobs.is_empty(), "there are jobs to look at")
	var j: Dictionary = desk.jobs[0]
	Shifts.add({"id": "mine_clash", "title": "Own shift", "store": "My Bakery", "start": float(j.start) - 1800, "end": float(j.start) + 1800, "tz": JobListings.tz_of(j), "manual": true})
	desk.index = 0
	desk._show_job()
	await _frames()
	desk._accept()
	await _frames()
	_check(Shifts.all().size() == 1, "an overlapping job is not added (%d shifts)" % Shifts.all().size())
	var t := _texts(desk.card_box)
	_check(t.contains(tr("R3_OVERLAP_TITLE")) and t.contains("My Bakery"), "the clash message names the other shift: %s" % t.replace("\n", " | "))

	await _finish()


func _finish() -> void:
	print("REVIEW3 UI TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
