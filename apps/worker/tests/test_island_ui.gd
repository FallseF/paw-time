extends Node
## 島の画面の重なり（ユーザーレビュー2）：本物の島（main.tscn）を開いて確かめる。
##   - 船着き場のカタログが 360 の画面からはみ出さない
##   - 「＋ ひろげる」札は、しごとのシート・求人カードなどが開いている間は出ない
##   - 島の段のくわしく（庭 Lv / ポイ）と、左右の札（キセカエ・マイスキル・しごと・話す）が重ならない
## OBAKE_NOSAVE=1 godot --headless --path . res://tests/test_island_ui.tscn

var fails := 0
var main


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _ready() -> void:
	for kv in [["OBAKE_NOSAVE", "1"], ["OBAKE_START", "garden"], ["OBAKE_ONBOARD", "done"], ["OBAKE_MODE", "solo"], ["OBAKE_FF", "3"], ["OBAKE_NO_REVEAL", "1"]]:
		OS.set_environment(kv[0], kv[1])
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


## 島の上の段の札（画面の上のほう、島の画面・重ね画面の直下に置いたボタン）
func _hud_buttons(g: Node) -> Array:
	var out: Array = []
	for host in [g, _desk(g)] + g.get_children().filter(func(c): return c is ChatHub):
		for c in host.get_children():
			if c is Button and c.is_visible_in_tree() and c.get_global_rect().position.y < 140.0:
				out.append(c)
	return out


func _run() -> void:
	await get_tree().create_timer(2.5).timeout
	var g = main.current
	var desk := _desk(g)
	_check(desk != null, "job desk on the island")

	# 1. 「＋ ひろげる」札と、重ね画面
	_check(g.expand_btn != null and g.expand_btn.visible, "expand pill shows on the plain island")
	desk.open_work_menu()
	await _frames()
	_check(not g.expand_btn.visible, "expand pill hidden while the work menu sheet is open")
	desk._close_sheet()
	await _frames()
	_check(g.expand_btn.visible, "expand pill back after the sheet closes")
	desk._open_viewer()
	await _frames()
	_check(not g.expand_btn.visible, "expand pill hidden while the job cards are open")
	desk._close_viewer()
	await _frames()

	# 2. 船着き場のカタログが画面の幅に収まる（日本語の「見本のストア（本当の支払いはありません）」がいちばん長い）
	TranslationServer.set_locale("ja")
	g._open_catalog("dock")
	await _frames(4)
	var panel: Control = null
	for c in g.catalog_ui.get_children():
		if c is PanelContainer:
			panel = c
	var r: Rect2 = panel.get_global_rect()
	_check(r.position.x >= 0.0 and r.end.x <= 360.0, "dock catalog fits 360 px (%s)" % r)
	_check(not g.expand_btn.visible, "expand pill hidden while the catalog is open")
	g.catalog_ui.queue_free()
	TranslationServer.set_locale("en")
	await _frames()

	# 3. 上の段：くわしく（庭 Lv / ポイ）を開いても、札と重ならない。札どうしも重ならない
	var hud := _hud_buttons(g)
	for i in hud.size():
		for j in range(i + 1, hud.size()):
			_check(not hud[i].get_global_rect().intersects(hud[j].get_global_rect()), "HUD pills overlap: %s / %s" % [hud[i].text, hud[j].text])
	g._toggle_meters()
	await _frames(4)
	var mr: Rect2 = g.meters.get_global_rect()
	for b in _hud_buttons(g):
		_check(not mr.intersects(b.get_global_rect()), "island details panel covers the '%s' pill" % b.text)
	g._toggle_meters()

	print("ISLAND UI TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
