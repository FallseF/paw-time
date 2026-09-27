extends Node
## おばけすくいの手ざわり（ユーザーレビュー3）：本物の画面（main.tscn → catch）で確かめる。
##   - はじめてのすくい：手が 3 拍（おさえて・すべりこませて・はなす！）で見せ、押したらすぐ消える
##   - ポイは指へ、なめらかに追いかける（飛びつかない・行きすぎない）。指の知らせ（ScreenTouch）で二重に動かない
##   - 水の中では、近くの玉へそっと寄る（磁石）。すくえる玉は光る輪、「いま！」
##   - 押す → 動かす → 離す ですくえる。はじめてすくえたら「いいね！」と一度だけ。タップでも、すくえる
## OBAKE_NOSAVE=1 godot --headless --path . res://tests/test_scoop_play.tscn

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


func _frames(n := 3) -> void:
	for i in n:
		await get_tree().process_frame


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


func _has_chip(sc, t: String) -> bool:
	for c in sc.get_children():
		if c is PanelContainer and c.find_children("*", "Label", true, false).any(func(l): return l.text == t):
			return true
	return false


func _run() -> void:
	await get_tree().create_timer(1.5).timeout
	var sc = main.current
	GameState.tut.erase("scoop_hand")
	_check(GameState.total_scooped == 0, "fresh player (%d scooped)" % GameState.total_scooped)
	_check(sc.orbs.size() >= 2, "orbs on the water (%d)" % sc.orbs.size())
	for o in sc.orbs:
		o.set_process(false)
		o.vel = Vector3.ZERO

	# 1 手の 3 拍
	_check(sc.hand != null and sc.hand.visible, "the hand ghost shows on the first scoop")
	var caps := {}
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3600:
		await get_tree().process_frame
		if sc.hand_cap and sc.hand_art.modulate.a > 0.5:
			caps[sc.hand_cap.text] = true
	_check(caps.has("Hold") and caps.has("Slide under") and caps.has("Release!"), "3 beats with captions in one loop %s" % [caps.keys()])
	_check(sc.hand_art.mouse_filter == Control.MOUSE_FILTER_IGNORE and sc.hand.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the hand never blocks input")

	# 2 押すと手が消える。ポイはなめらかに追いかける
	var a := Vector2(120, 430)
	_mouse(sc, a, true)
	await _frames(1)
	_check(sc.hand == null, "the hand disappears on the first press")
	_check(sc.pressed and sc.poi.position.y < 0.0, "pressing dips the poi into the water")
	var p0: Vector3 = sc.poi.position
	var b := Vector2(250, 400)
	var gb: Vector3 = sc._ground(b)
	_move(sc, b)
	# 指の知らせ（ScreenTouch）が一緒に来ても、二重に動かない
	var st := InputEventScreenTouch.new()
	st.pressed = true
	st.position = Vector2(60, 470)
	sc._gui_input(st)
	await _frames(1)
	var p1: Vector3 = sc.poi.position
	var d_all := Vector2(gb.x - p0.x, gb.z - p0.z).length()
	var d1 := Vector2(gb.x - p1.x, gb.z - p1.z).length()
	_check(d1 > d_all * 0.2 and d1 < d_all, "first frame moves only part way (%.2f of %.2f)" % [d1, d_all])
	await get_tree().create_timer(0.35).timeout
	var p2: Vector3 = sc.poi.position
	var d2 := Vector2(gb.x - p2.x, gb.z - p2.z).length()
	_check(d2 < 0.2, "the poi catches up with the finger (%.2f)" % d2)
	_check(sc.guide.visible, "guide ring on the water")
	_mouse(sc, b, false)
	await _frames(1)
	var nice := false
	while sc.busy:
		nice = nice or _has_chip(sc, "Nice!")
		await get_tree().process_frame

	# 3 磁石・光る輪・「いま！」：玉の少し横で押したまま
	var o: Orb3D = sc.orbs[0]
	var os := View3D.unproject(sc.cam, o.position)
	var side := os + Vector2(22, 0)
	_mouse(sc, side, true)
	await get_tree().create_timer(0.4).timeout
	var aim2 := Vector2(sc.aim.x, sc.aim.z)
	var orb2 := Vector2(o.position.x, o.position.z)
	var poi2 := Vector2(sc.poi.position.x, sc.poi.position.z)
	_check(poi2.distance_to(orb2) < aim2.distance_to(orb2) - 0.02, "the poi is pulled toward the nearby orb (%.2f < %.2f)" % [poi2.distance_to(orb2), aim2.distance_to(orb2)])
	_check(sc.target_ring.visible, "the orb in range is highlighted")
	_check(sc.now_label.visible, "'Now!' cue while in range")
	# 4 離す → すくえる。はじめてなら「いいね！」、印がつく
	var c0: int = sc.caught_count
	_mouse(sc, side, false)
	await _until(func(): return sc.caught_count > c0, 3.0)
	_check(sc.caught_count == c0 + 1, "hold, slide under, release scoops the orb")
	_check(GameState.tut.has("scoop_hand"), "the tutorial is stored as done")
	var tip := false
	var t1 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t1 < 3000:
		nice = nice or _has_chip(sc, "Nice!")
		tip = tip or _has_chip(sc, "Or just tap an orb")
		await get_tree().process_frame
	_check(nice, "a tiny 'Nice!' after the first scoop")
	_check(tip, "then the 'Or just tap an orb' hint")
	_check(sc.hand == null, "the hand does not come back after a scoop")

	# 5 タップ：玉の少し横をさっとタップ → ポイがすべっていって、すくう
	if sc.orbs.is_empty():
		_check(false, "an orb left for the tap test")
	else:
		for ob in sc.orbs:
			ob.set_process(false)
			ob.vel = Vector3.ZERO
		var c1: int = sc.caught_count
		sc.demo_tap()
		_check(sc.auto_orb != null, "tapping near an orb sends the poi to it")
		await _until(func(): return sc.caught_count > c1, 3.0)
		_check(sc.caught_count == c1 + 1, "tap-to-scoop catches the orb")
		await _until(func(): return not sc.busy, 4.0)
	# 6 はじめのうちは、破れにくい
	_check(sc._wear() < 0.7, "beginner wear is gentle (%.2f)" % sc._wear())

	print("SCOOP PLAY TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
