extends Node
## 島の画面の重なり（ユーザーレビュー2）：本物の島（main.tscn）を開いて確かめる。
##   - 船着き場のカタログが 360 の画面からはみ出さない
##   - 「＋ ひろげる」札は、しごとのシート・求人カードなどが開いている間は出ない
##   - 島の段のくわしく（庭 Lv / ポイ）と、左右の札（キセカエ・マイスキル・しごと・話す）が重ならない
##   - 「話す」札：いつも見えて、押すとカメラが相棒に寄ってからチャット。閉じたら眺めに戻る
##   - いかだ（桟橋の乗り物）を押すと、行き先えらび（友だちの島・お店の島）。読めないコードでは出かけない
##   - 島の拡大・縮小（ホイール・二本の指でつまむ）。範囲の中に収まり、拡大してもおばけのタップが当たる
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
	await _frames(3)

	await _talk(g)
	await _raft(g)
	await _zoom(g)

	print("ISLAND UI TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)


func _wheel(g, up: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	e.pressed = true
	e.factor = 1.0
	e.position = Vector2(180, 330)
	g._gui_input(e)


func _touch(g, i: int, at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i
	e.position = at
	e.pressed = pressed
	g._gui_input(e)


func _drag(g, i: int, at: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i
	e.position = at
	g._gui_input(e)


## 窓のピクセルに直して、本物の入力としてタップ（tests/tap_check.gd と同じ）
func _tap(sp: Vector2) -> void:
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = get_viewport().get_final_transform() * sp
		ev.global_position = ev.position
		get_viewport().push_input(ev)


func _zoom(g) -> void:
	var d0: float = g.cam.global_position.distance_to(g.cam_look)
	for i in 3:
		_wheel(g, true)
	_check(g.zoom_to < 0.8, "wheel up zooms in (%.2f)" % g.zoom_to)
	await get_tree().create_timer(0.6).timeout
	var d1: float = g.cam.global_position.distance_to(g.cam_look)
	_check(d1 < d0 * 0.8, "camera moved closer smoothly (%.2f -> %.2f)" % [d0, d1])
	for i in 30:
		_wheel(g, true)
	_check(is_equal_approx(g.zoom_to, g.ZOOM_MIN), "zoom in is clamped (%.2f)" % g.zoom_to)
	for i in 30:
		_wheel(g, false)
	_check(is_equal_approx(g.zoom_to, g.ZOOM_MAX), "zoom out is clamped (%.2f)" % g.zoom_to)
	# 二本の指：ひろげると寄る（60 → 120 px で半分）
	g.zoom_to = 1.0
	_touch(g, 0, Vector2(150, 330), true)
	_touch(g, 1, Vector2(210, 330), true)
	_drag(g, 1, Vector2(270, 330))
	_check(absf(g.zoom_to - 0.5) < 0.01, "pinch out halves the distance (%.2f)" % g.zoom_to)
	var orbit0: float = g.orbit
	var mm := InputEventMouseMotion.new()
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	mm.relative = Vector2(-60, 0)
	g._gui_input(mm)
	_check(g.orbit == orbit0, "no orbit while pinching")
	_touch(g, 1, Vector2(270, 330), false)
	_touch(g, 0, Vector2(150, 330), false)
	_check(g.touches.is_empty(), "fingers released")
	await get_tree().create_timer(0.8).timeout
	# 拡大したままでも、おばけのタップが当たる
	var hit := false
	for w in g.walkers:
		var ob: Node3D = w.o
		var sp := View3D.unproject(g.cam, ob.global_position + Vector3(0, 0.35, 0))
		if sp.y < 140 or sp.y > 400 or sp.x < 20 or sp.x > 340:
			continue
		var n0 := ob.get_child_count()
		_tap(sp)
		await _frames(2)
		hit = ob.get_child_count() > n0
		break
	_check(hit, "tap on an obake still works while zoomed in")


func _talk(g) -> void:
	var hub: ChatHub = null
	for c in g.get_children():
		if c is ChatHub:
			hub = c
	_check(hub != null and hub.talk_pill != null and hub.talk_pill.is_visible_in_tree(), "Talk pill is on the island HUD")
	if hub == null or hub.talk_pill == null:
		return
	var far: float = g.cam.global_position.distance_to(g.host_node.global_position)
	hub.talk_pill.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	var near: float = g.cam.global_position.distance_to(g.host_node.global_position)
	_check(near < far * 0.6, "camera zooms toward the cat (%.2f -> %.2f)" % [far, near])
	await get_tree().create_timer(1.0).timeout
	var chat: Node = null
	for c in g.get_children():
		if c is ScreenChat:
			chat = c
	_check(chat != null and chat.thread == "me", "the private chat opens after the zoom")
	_check(not g.expand_btn.visible, "expand pill hidden during the chat")
	if chat:
		chat.queue_free()
	await get_tree().create_timer(0.9).timeout
	_check(not g.cam_hold and g.cam.global_position.distance_to(g._view_transform().origin) < 0.05, "camera back to the island view after the chat")
	_check(g.expand_btn.visible, "expand pill back after the chat")


func _raft(g) -> void:
	_check(g.parked != null, "a vehicle is parked at the pier")
	if g.parked == null:
		return
	var sp: Vector2 = g._raft_screen_pos()
	_check(sp.x > 0 and sp.x < 360 and sp.y > 110 and sp.y < 640, "raft is on screen (%s)" % sp)
	g._toggle_card() # 今日のカードをしまって、島をひろく見た状態（いかだはカードの下にあることが多い）
	await get_tree().create_timer(0.5).timeout
	sp = g._raft_screen_pos()
	_tap(sp)
	await _frames(2)
	_check(g.raft_ui != null and is_instance_valid(g.raft_ui), "tapping the raft opens the chooser (at %s)" % sp)
	if g.raft_ui == null:
		g._toggle_card()
		return
	_check(not g.expand_btn.visible or not g.expand_btn.is_visible_in_tree(), "expand pill hidden while the chooser is open")
	_check(not g._visit_code("not a code!"), "a bad code does not travel")
	_check(g.main.current == g, "still on the island")
	g.raft_ui.queue_free()
	g._toggle_card()
	await get_tree().create_timer(0.5).timeout
