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


## 画面の点から、ポイ（宙の位置〜水面の位置を結ぶ線）の当たりの輪のふちまで（px。負なら、ポイの陰の中）
func _poi_gap(sc, sp: Vector2) -> float:
	var w: Vector3 = Vector3(sc.poi.position.x, 0.0, sc.poi.position.z)
	var ws := View3D.unproject(sc.cam, w)
	var r := View3D.unproject(sc.cam, w + Vector3(sc._hit_r(), 0, 0)).distance_to(ws)
	var air := View3D.unproject(sc.cam, sc.poi.position)
	return Geometry2D.get_closest_point_to_segment(sp, air, ws).distance_to(sp) - r


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
	# 手の見本・ポイの陰に、ほかの玉がかくれていない（開いてから 1.5 秒ただよったので、開いたときの置き直しをもう一度通す）
	sc._clear_hand_path()
	var hz: Array = sc._hand_zone(sc.hand_orb)
	for ob in sc.orbs:
		var osp := View3D.unproject(sc.cam, ob.position)
		_check(_poi_gap(sc, osp) > 0.0, "a first orb is not under the poi (%.1f px)" % _poi_gap(sc, osp))
		if ob != sc.hand_orb:
			_check(ScoopAssist.clearance(osp, [hz]) >= 0.0, "a first orb is not under the hand ghost (%.1f px)" % ScoopAssist.clearance(osp, [hz]))
	var caps := {}
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 3600:
		await get_tree().process_frame
		if sc.hand_cap and sc.hand_group.modulate.a > 0.5:
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
	# ほかの玉からいちばん離れた玉で見る（磁石は、いちばん近い玉へ寄るので）
	var o: Orb3D = sc.orbs[0]
	var lone := -1.0
	for ob in sc.orbs:
		var nd := INF
		for ob2 in sc.orbs:
			if ob2 != ob:
				nd = minf(nd, ob.position.distance_to(ob2.position))
		if nd > lone:
			lone = nd
			o = ob
	var os := View3D.unproject(sc.cam, o.position)
	# 押す点：玉の少し横。ほかの玉より、この玉にいちばん近い向きをえらぶ（磁石は、いちばん近い玉へ寄るので）
	var side := os + Vector2(22, 0)
	var margin := -INF
	for off in [Vector2(22, 0), Vector2(-22, 0), Vector2(0, 22), Vector2(0, -22)]:
		var g: Vector3 = sc._ground(os + off)
		var mine := Vector2(g.x - o.position.x, g.z - o.position.z).length()
		var other := INF
		for ob in sc.orbs:
			if ob != o:
				other = minf(other, Vector2(g.x - ob.position.x, g.z - ob.position.z).length())
		if other - mine > margin:
			margin = other - mine
			side = os + off
	_mouse(sc, side, true)
	# 玉は、押したポイから少し逃げる（毎フレーム動く）ので、ここでは玉を止めて、磁石だけを見る
	var pins := {}
	for ob in sc.orbs:
		pins[ob] = ob.position
	var tp := Time.get_ticks_msec()
	while Time.get_ticks_msec() - tp < 400:
		for ob in sc.orbs:
			if pins.has(ob):
				ob.position = pins[ob]
				ob.vel = Vector3.ZERO
		await get_tree().process_frame
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

	# 7 新しい玉は、ポイ（宙でも水の中でも）と当たりの輪の下には浮かばない（ポイの陰で見えない玉を作らない）
	await _until(func(): return not sc.busy, 4.0)
	var d0: Dictionary = {"type": "dish"}
	var worst := INF
	var outside := 0
	for at in [Vector3(0, 0.45, 1.2), Vector3(0, 0.45, 0.2), Vector3(-0.8, 0.45, 0.4), Vector3(0.9, -0.04, 0.6), Vector3(0.3, 0.45, -0.3)]:
		sc.poi.position = at
		for i in 25:
			sc._spawn_orb(d0)
			var no: Orb3D = sc.orbs.back()
			var sp := View3D.unproject(sc.cam, no.position)
			worst = minf(worst, _poi_gap(sc, sp))
			if not sc.ORB_SAFE.has_point(sp):
				outside += 1
			sc.orbs.erase(no)
			no.queue_free()
	_check(worst > 0.0, "new orbs never surface under the poi or its hit ring (worst gap %.1f px)" % worst)
	_check(outside == 0, "new orbs stay on the visible pond (%d outside)" % outside)
	# ただよって宙のポイの下に来た玉は、網が透けて、光る輪で見える（ほかの玉は片づけて、この玉だけで見る）
	for ob in sc.orbs.duplicate():
		sc.orbs.erase(ob)
		ob.queue_free()
	sc.poi.position = Vector3(0.2, 0.45, 0.5)
	sc.aim = Vector3(0.2, 0.0, 0.5)
	sc.poi_vel = Vector2.ZERO
	var hd: Dictionary = {"type": "dish"}
	sc._spawn_orb(hd)
	var ho: Orb3D = sc.orbs.back()
	ho.set_process(false)
	ho.vel = Vector3.ZERO
	var ps := View3D.unproject(sc.cam, sc.poi.position)
	ho.position = sc.cam.project_position(View3D.to_vp(sc.cam, ps), 1.0) # 仮置き（下で水面へ）
	var from: Vector3 = sc.cam.project_ray_origin(View3D.to_vp(sc.cam, ps))
	var dir: Vector3 = sc.cam.project_ray_normal(View3D.to_vp(sc.cam, ps))
	ho.position = from + dir * ((0.12 - from.y) / dir.y) - Vector3(0, 0.12, 0)
	await get_tree().create_timer(0.4).timeout
	_check(sc.peek_ring.visible, "an orb hidden under the lifted poi gets a see-through ring")
	_check(sc.poi_film_mat.albedo_color.a < 0.2, "the poi net turns see-through over it (%.2f)" % sc.poi_film_mat.albedo_color.a)
	_check(sc.guide.visible, "the guide ring stays")
	ho.position = Vector3(-1.2, 0, 0.9)
	await get_tree().create_timer(0.4).timeout
	_check(not sc.peek_ring.visible and sc.poi_film_mat.albedo_color.a > 0.3, "the net is solid again when nothing is under it")

	print("SCOOP PLAY TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
