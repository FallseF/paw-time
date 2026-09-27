extends Node
## 島の画面の重なり（ユーザーレビュー2）：本物の島（main.tscn）を開いて確かめる。
##   - 船着き場のカタログが 360 の画面からはみ出さない
##   - 島の HUD（下のタブ・上の段・✎）は、しごとのシート・求人カード・カタログ・チャットが開いている間は引っこむ
##   - 上の段（状態の札・丸いボタン）どうしが重ならず、くわしく（何週目・庭 Lv / ポイ）がそれらに重ならない
##   - 「話す」の丸いボタン：いつも見えて、押すとカメラが相棒に寄ってからチャット。閉じたら眺めに戻る
##   - 下のタブ：しごと → シフトのシート（マイスキル・仕事に行ってくるもここ）、図鑑 → 図鑑の画面。マイスキルから 5 つのおさらい
##   - いかだ（桟橋の乗り物）を押すと、行き先えらび（友だちの島・お店の島）。読めないコードでは出かけない
##   - 島の拡大・縮小（ホイール・二本の指でつまむ）。範囲の中に収まり、拡大してもおばけのタップが当たる
##   - 島をなぞって動かす（慣性・範囲の外はやわらかく押しもどす）。なぞりはタップにならない。「もどる」で家の前へ
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


## 島の上の段のボタン（状態の札・丸いボタン。画面の上のほうに出ているもの）
func _hud_buttons(g: Node) -> Array:
	var out: Array = []
	for c in g.hud.top_row.find_children("*", "Button", true, false):
		if c.is_visible_in_tree() and c.get_global_rect().position.y < 140.0:
			out.append(c)
	return out


## HUD が出ているか（下のタブが画面の中にあって、上の段が見えている）
func _hud_on(g) -> bool:
	return g.hud.shown and g.hud.top_row.visible


func _run() -> void:
	await get_tree().create_timer(2.5).timeout
	var g = main.current
	var desk := _desk(g)
	_check(desk != null, "job desk on the island")

	# 1. 島の HUD と、重ね画面（重ね画面の上に、下のタブや丸いボタンが明るく残らない）
	_check(g.hud != null and _hud_on(g), "island HUD shows on the plain island")
	_check(g.hud.fab.visible, "the ✎ button shows on the plain island")
	var tabs_r: Rect2 = g.hud.tabs.book.get_global_rect()
	_check(tabs_r.end.y <= 640.0 and tabs_r.end.x <= 360.0, "bottom tabs are on screen (%s)" % tabs_r)
	_check(g.card.get_global_rect().end.y <= g.hud.nav_top() and not g.card.get_global_rect().intersects(g.hud.fab.get_global_rect()), "today card sits above the tabs, left of ✎")
	_check(g.hud.get_index() < desk.get_index() and g.hud.get_index() < g.card.get_index(), "HUD draws under the today card and every overlay")
	desk.open_work_menu()
	await _frames(20)
	_check(not _hud_on(g), "HUD hides while the work menu sheet is open")
	_check(desk.notes.all(func(n): return not is_instance_valid(n) or not n.visible), "job banners hide while the sheet is open")
	desk._close_sheet()
	await _frames(20)
	_check(_hud_on(g), "HUD back after the sheet closes")
	desk._open_viewer()
	await _frames(20)
	_check(not _hud_on(g), "HUD hides while the job cards are open")
	desk._close_viewer()
	await _frames(20)

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
	_check(not _hud_on(g), "HUD hides while the catalog is open")
	g.catalog_ui.queue_free()
	TranslationServer.set_locale("en")
	await _frames()

	# 3. 上の段：くわしく（何週目・庭 Lv / ポイ）を開いても、札と重ならない。札どうしも重ならない
	var hud := _hud_buttons(g)
	_check(hud.size() == 4, "status chip + 3 round buttons on the top row (%d)" % hud.size())
	for i in hud.size():
		for j in range(i + 1, hud.size()):
			_check(not hud[i].get_global_rect().intersects(hud[j].get_global_rect()), "HUD buttons overlap: %s / %s" % [hud[i].tooltip_text, hud[j].tooltip_text])
	g._toggle_meters()
	await _frames(4)
	var mr: Rect2 = g.meters.get_global_rect()
	for b in _hud_buttons(g):
		_check(not mr.intersects(b.get_global_rect()), "island details panel covers the '%s' button" % b.tooltip_text)
	g._toggle_meters()
	await _frames(3)

	await _talk(g)
	await _raft(g)
	await _zoom(g)
	await _pan(g)
	await _tabs(g)

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
	var pan0: Vector2 = g.pan
	var mm := InputEventMouseMotion.new()
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT
	mm.position = Vector2(100, 330)
	mm.relative = Vector2(-60, 0)
	g._gui_input(mm)
	_check(g.pan == pan0, "one-finger pan is off while pinching")
	# 二本の指を同じ向きに動かすと、つまみながら島が動く
	_drag(g, 0, Vector2(110, 330))
	_drag(g, 1, Vector2(230, 330))
	_check(g.pan.x > pan0.x + 0.2, "two fingers moving together pan the island (%s)" % g.pan)
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
	var talk: Button = g.hud.round_btns.talk
	_check(hub != null and talk.is_visible_in_tree(), "Talk button is on the island HUD")
	if hub == null:
		return
	var far: float = g.cam.global_position.distance_to(g.host_node.global_position)
	talk.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	var near: float = g.cam.global_position.distance_to(g.host_node.global_position)
	_check(near < far * 0.6, "camera zooms toward the cat (%.2f -> %.2f)" % [far, near])
	await get_tree().create_timer(1.0).timeout
	var chat: Node = null
	for c in g.get_children():
		if c is ScreenChat:
			chat = c
	_check(chat != null and chat.thread == "me", "the private chat opens after the zoom")
	_check(not _hud_on(g), "HUD hides during the chat")
	if chat:
		chat.queue_free()
	await get_tree().create_timer(0.9).timeout
	_check(not g.cam_hold and g.cam.global_position.distance_to(g._view_transform().origin) < 0.05, "camera back to the island view after the chat")
	await _frames(20)
	_check(_hud_on(g), "HUD back after the chat")


func _raft(g) -> void:
	_check(g.parked != null, "a vehicle is parked at the pier")
	if g.parked == null:
		return
	var sp: Vector2 = g._raft_screen_pos()
	_check(sp.x > 0 and sp.x < 360 and sp.y > 110 and sp.y < 640, "raft is on screen (%s)" % sp)
	g.hide_card(true) # 今日のカードをしまって、島をひろく見た状態（いかだはカードの下にあることが多い）
	await get_tree().create_timer(0.5).timeout
	sp = g._raft_screen_pos()
	_tap(sp)
	await _frames(2)
	_check(g.raft_ui != null and is_instance_valid(g.raft_ui), "tapping the raft opens the chooser (at %s)" % sp)
	if g.raft_ui == null:
		g.hide_card(false)
		return
	await _frames(20)
	_check(not _hud_on(g), "HUD hides while the chooser is open")
	_check(not g._visit_code("not a code!"), "a bad code does not travel")
	_check(g.main.current == g, "still on the island")
	g.raft_ui.queue_free()
	g.hide_card(false)
	await get_tree().create_timer(0.5).timeout


## なぞって島を動かす：指の下の地面がついてくる・離したあと少しすべる・範囲の外からもどる・なぞりはタップにならない・「もどる」
func _pan(g) -> void:
	g.recenter()
	await get_tree().create_timer(1.2).timeout
	_check(g.pan.length() < 0.02, "starts centred (%s)" % g.pan)
	var labels0 := 0
	for w in g.walkers:
		labels0 += (w.o as Node).get_child_count()
	# 地面の 1 点が、指についてくるか（押した点の真下の地面 → 離した点の真下）
	var at := Vector2(180, 300)
	var ground0: Vector3 = g._ground_at(at)
	g.demo_pan(Vector2(-90, 0), at)
	var ground1: Vector3 = g._ground_at(at + Vector2(-90, 0))
	_check(ground0.distance_to(ground1) < 0.35, "the ground under the finger follows it (%.2f)" % ground0.distance_to(ground1))
	var p1: Vector2 = g.pan
	_check(p1.x > 0.5, "dragging left moves the view right (%s)" % p1)
	var labels1 := 0
	for w in g.walkers:
		labels1 += (w.o as Node).get_child_count()
	_check(labels1 == labels0, "a drag is not a tap on an obake")
	await _frames(6)
	_check(g.pan.x > p1.x + 0.05, "keeps gliding after release (momentum %s -> %s)" % [p1, g.pan])
	# 大きく引っぱって外へ：離すと範囲の中へもどる
	for i in 6:
		g.demo_pan(Vector2(-300, -200), Vector2(330, 500))
		await _frames(1)
	await get_tree().create_timer(1.6).timeout
	_check(g._pan_clamped(g.pan).distance_to(g.pan) < 0.05, "settles inside the island bounds (%s)" % g.pan)
	var cw: Vector3 = g._ground_at(Vector2(180, 300))
	var near_land := false
	for c in g.pan_circles:
		near_land = near_land or Vector2(cw.x - c.x, cw.z - c.y).length() < c.z + g.PAN_MARGIN + 0.3
	_check(near_land, "the middle of the screen shows land, not open sea (%s)" % cw)
	_check(g.pan.length() > 2.0, "panned far from home (%s)" % g.pan)
	await _frames(2)
	_check(g.recenter_btn != null and g.recenter_btn.visible, "the Home button shows when panned away")
	if g.recenter_btn:
		var br: Rect2 = g.recenter_btn.get_global_rect()
		_check(br.position.x >= 0 and br.end.x <= 360, "Home button on screen (%s)" % br)
		g.recenter_btn.pressed.emit()
	await get_tree().create_timer(1.4).timeout
	_check(g.pan.length() < 0.05, "Home glides back to the house (%s)" % g.pan)
	_check(g.recenter_btn == null or not g.recenter_btn.visible, "Home button hides at home")
	# 短い押し離し（ほぼ動かさない）はタップのまま
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
	_check(hit, "tap on an obake still works after panning")


## 下のタブ：しごと → シフトのシート（島にあった「マイスキル」「仕事に行ってくる」もここ）。マイスキル → 5 つのおさらい。図鑑 → 図鑑の画面
func _tabs(g) -> void:
	var desk := _desk(g)
	g.hud.tabs.jobs.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	_check(desk.sheet != null and is_instance_valid(desk.sheet), "Jobs tab opens the shifts sheet")
	var names: Array = []
	if desk.sheet:
		for b in desk.sheet.find_children("*", "Button", true, false):
			names.append(String(b.text))
	_check(names.has(tr("SK_PILL")) and names.has(tr("I'm going to work")), "shifts sheet has My skills and I'm going to work (%s)" % [names])
	var sk: Button = null
	if desk.sheet:
		for b in desk.sheet.find_children("*", "Button", true, false):
			if b.text == tr("SK_PILL"):
				sk = b
	if sk == null:
		return
	sk.pressed.emit()
	await get_tree().create_timer(1.2).timeout
	_check(main.current_name == "skills", "My skills opens the skills screen (%s)" % main.current_name)
	var n := 0
	for b in main.current.find_children("*", "Button", true, false):
		if b.text in [tr("SK_PRACTICE"), tr("SK_AGAIN")]:
			n += 1
	_check(n == 5, "the skills screen lists the 5 practice games (%d)" % n)
	await main.go("garden")
	await get_tree().create_timer(1.5).timeout
	var g2 = main.current
	g2.hud.tabs.book.pressed.emit()
	await get_tree().create_timer(1.2).timeout
	_check(main.current_name == "zukan", "Book tab opens the Book (%s)" % main.current_name)
