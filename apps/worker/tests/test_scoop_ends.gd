extends Node
## おばけすくいは、いつも終わる（「たまに永遠に終わらないポイすくい」）。ポイの位置は、見える水面から出ない（「右上でポイがなくなる」）。
##   - 破れないまま、すくい続けても：今夜の玉の数（ポイの本数から決まる）に届いたら、玉は足されず、まとめへ
##   - 1 本のポイで、すくえる数には上限がある（破れなくても、くたくたになる）
##   - 時間の目安（NIGHT_SEC）を過ぎたら、残りの玉は流れていって、まとめへ
##   - 「帰る」は、すくっている途中（busy）に押しても、あとで必ず帰る
##   - ポイは、画面の上のほう・右上へ指を動かしても、見える水面の中にいる。指が画面の外へ出たら、持ち上がる
## OBAKE_NOSAVE=1 godot --headless --path . res://tests/test_scoop_ends.tscn

var fails := 0
var main


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _ready() -> void:
	for kv in [["OBAKE_NOSAVE", "1"], ["OBAKE_START", "catch"], ["OBAKE_ONBOARD", "done"], ["OBAKE_LOCALE", "en"]]:
		OS.set_environment(kv[0], kv[1])
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _until(cond: Callable, sec: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > sec * 1000.0:
			return false
		await get_tree().process_frame
	return true


func _mouse(sc, at: Vector2, down: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = down
	ev.position = at
	sc._gui_input(ev)


func _move(sc, at: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = at
	m.button_mask = MOUSE_BUTTON_MASK_LEFT
	sc._gui_input(m)


## ポイ（水面の点）の画面の位置が、見える水面の中か（池の奥は岸の石と木にかくれる。下はポイの選択バー）
func _poi_on_water(sc) -> bool:
	var sp := View3D.unproject(sc.cam, Vector3(sc.poi.position.x, 0.0, sc.poi.position.z))
	return Rect2(20, 324, 320, 206).has_point(sp) and sc.poi.visible


## 次の夜の、すくいの画面を開きなおす
func _new_night(plain := 3):
	GameState.scooped_tonight = false
	for id in GameState.nets:
		GameState.nets[id] = 0
	GameState.nets["plain"] = plain
	main.busy = false
	main.go("catch", true)
	await get_tree().create_timer(1.5).timeout
	GameState.tut["scoop_hand"] = true
	return main.current


func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	var sc = main.current
	GameState.tut["scoop_hand"] = true

	# 1 右上へ指を動かしても、ポイは見える水面の中
	for at in [Vector2(330, 130), Vector2(345, 300), Vector2(355, 630)]:
		_mouse(sc, Vector2(180, 420), true)
		_move(sc, at)
		await get_tree().create_timer(0.5).timeout
		_check(_poi_on_water(sc), "the poi stays on the visible water when the finger goes to %s (poi at %s)" % [at, View3D.unproject(sc.cam, sc.poi.position)])
		_mouse(sc, at, false)
		await _until(func(): return not sc.busy, 4.0)
	# 指が画面の外へ出た（離したのが届かない）→ ポイは持ち上がる
	_mouse(sc, Vector2(180, 420), true)
	await get_tree().process_frame
	sc.notification(Control.NOTIFICATION_MOUSE_EXIT)
	sc.get_viewport().notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	sc.notification(Node.NOTIFICATION_WM_MOUSE_EXIT)
	await get_tree().create_timer(0.4).timeout
	_check(not sc.pressed, "the poi lifts when the pointer leaves the game")
	await _until(func(): return not sc.busy, 4.0)

	# 2 すくっている途中（busy）に「帰る」を押しても、終わったところで帰る
	sc.demo_hold()
	await get_tree().process_frame
	sc.demo_lift()
	_check(sc.busy, "busy while scooping")
	sc._finish()
	await _until(func(): return GameState.scooped_tonight, 5.0)
	_check(GameState.scooped_tonight, "'Go home' pressed mid-scoop still ends the night")

	# 3 破れないまま、すくい続けても、今夜は終わる
	# 3a 玉の数の上限：すくった（水面から消えた）ぶんだけ足しても、今夜の玉の数で止まり、水面は空になる
	sc = await _new_night(3)
	var budget: int = sc.night_budget
	_check(budget >= sc.MIN_ON_SCREEN and budget <= 3 * sc.NET_SCOOPS + 7, "tonight's budget comes from the nets (%d)" % budget)
	var k := 0
	while not sc.orbs.is_empty() and k < 100:
		var o = sc.orbs.pop_back()
		o.queue_free()
		sc.caught_count += 1
		sc._top_up()
		k += 1
	_check(sc.orbs.is_empty() and sc.total_tonight <= budget and k <= budget, "top-ups stop at the budget (%d orbs, %d taken, budget %d)" % [sc.total_tonight, k, budget])
	GameState.scooped_tonight = true
	# 3b 本物の手順で、破れないまま、すくい続ける（ポイ 1 本）：くたくたになって、今夜は終わる
	sc = await _new_night(1)
	var t0 := Time.get_ticks_msec()
	var n := 0
	var most := 0
	while not GameState.scooped_tonight and n < 30 and Time.get_ticks_msec() - t0 < 60000:
		await _until(func(): return not sc.busy, 4.0)
		if GameState.scooped_tonight or sc.orbs.is_empty():
			break
		sc.durability = 1.0 # 破れない
		sc.demo_hold()
		await get_tree().process_frame
		sc.demo_lift()
		n += 1
		await _until(func(): return not sc.busy, 4.0)
		for key in sc.net_scoops:
			most = maxi(most, sc.net_scoops[key])
	await _until(func(): return GameState.scooped_tonight, 4.0)
	_check(GameState.scooped_tonight, "a long session with no tears ends (%d scoops, %d caught)" % [n, sc.caught_count])
	_check(sc.caught_count <= sc.NET_SCOOPS and most <= sc.NET_SCOOPS, "one net scoops at most %d (%d caught)" % [sc.NET_SCOOPS, sc.caught_count])
	_check(sc._nets_left() == 0 and sc.orbs.is_empty(), "the worn-out net is used up and the rest drift away")

	# 4 時間の目安を過ぎたら、残りの玉は流れていって、まとめへ
	sc = await _new_night()
	_check(not GameState.scooped_tonight and not sc.orbs.is_empty(), "a new night with orbs")
	sc.night_t = sc.NIGHT_SEC - 0.1
	await _until(func(): return GameState.scooped_tonight, 5.0)
	_check(GameState.scooped_tonight and sc.orbs.is_empty(), "after the soft time limit the orbs drift away and the night ends")

	print("SCOOP ENDS TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
