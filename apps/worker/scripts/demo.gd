extends Node
## 自動操作。OBAKE_DEMO=play で実際の画面を通して何日も遊ぶ（通しの確認用）。
## OBAKE_DEMO=promo で宣伝動画用の見せ場を順に流す。

var main
var mode := "play"
var cool := 1.0
var days_target := 10
var log_lines: Array = []
var last_screen := ""
var stuck := 0.0


func _ready() -> void:
	mode = OS.get_environment("OBAKE_DEMO")
	if OS.get_environment("OBAKE_DAYS") != "":
		days_target = int(OS.get_environment("OBAKE_DAYS"))
	if mode == "promo":
		_promo()


func _screen() -> String:
	if main.current == null:
		return ""
	return main.current.get_script().resource_path.get_file().get_basename().replace("screen_", "")


func _process(delta: float) -> void:
	if mode != "play":
		return
	var sc := _screen()
	if sc != last_screen:
		last_screen = sc
		stuck = 0.0
		print("[play] day %d %s phase=%s garden=%d zukan=%d" % [GameState.day, sc, GameState.phase, GameState.garden_level, GameState.seen.size()])
		_snap(sc)
	stuck += delta
	if stuck > 60.0:
		print("[play] STUCK on ", sc)
		get_tree().quit(1)
	cool -= delta
	if cool > 0 or main.busy:
		return
	cool = 1.2
	var c: Control = main.current
	match sc:
		"title":
			GameState.reset(OS.get_environment("OBAKE_MODE") if OS.get_environment("OBAKE_MODE") != "" else "data")
			main.go("garden")
		"garden":
			if GameState.day >= days_target:
				print("[play] done. zukan=%d rares=%d garden=%d" % [GameState.seen.size(), _rares(), GameState.garden_level])
				get_tree().quit()
				return
			if c.busy:
				return
			if GameState.phase == "morning":
				c.call("_after_morning")
				cool = 3.0
			elif GameState.phase == "day":
				if GameState.today().role != "" and not GameState.shift_done_today:
					c.call("_do_shift")
				else:
					# 夜は時計で来るが、自動で遊ぶときはすぐ夜に
					GameState.phase = "evening"
					main.go("garden")
				cool = 3.0
			elif GameState.phase == "evening":
				if GameState.is_moon_night() and not GameState.scooped_tonight:
					main.go("moon")
				elif not GameState.scooped_tonight:
					main.go("catch")
				else:
					main.go("night")
		"scoop":
			if GameState.scooped_tonight:
				main.go("night")
				return
			if c.busy:
				return
			if c.orbs.is_empty() or c.poi_type == "":
				c.call("_finish")
			else:
				c.call("demo_hold")
				await get_tree().create_timer(0.4).timeout
				if is_instance_valid(c) and main.current == c:
					c.call("demo_lift")
				cool = 2.5
		"night":
			if not c.get("going"):
				c.call("_morning")
			cool = 2.0
		"hatch":
			if not c.busy:
				c.call("_next")
				cool = 2.0
		"moon":
			if c.done:
				main.go("night")
			elif c.lit < c.good_total:
				c.call("demo_light_all")
				cool = 4.0
		"zukan":
			main.go("garden")


var snap_n := 0


## OBAKE_PLAYSHOTS=dir のとき、画面が変わるたびに少し待って撮る
func _snap(sc: String) -> void:
	var dir := OS.get_environment("OBAKE_PLAYSHOTS")
	if dir == "":
		return
	snap_n += 1
	var n := snap_n
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%03d_d%d_%s.png" % [dir, n, GameState.day, sc])


func _rares() -> int:
	var n := 0
	for id in GameState.seen:
		if Rares.is_rare(id):
			n += 1
	return n


# ---------- 宣伝動画 ----------

func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _mark(tag: String) -> void:
	print("[promo] %s frame=%d" % [tag, Engine.get_process_frames()])


func _go(screen: String, instant := false) -> void:
	while main.busy:
		await get_tree().process_frame
	await main.go(screen, instant)


func _promo() -> void:
	await get_tree().process_frame
	# 0) つかみ：育ちきった夜の庭
	_mark("0)")
	GameState.reset("data")
	main.fast_forward(26)
	GameState.phase = "evening"
	await _go("garden", true)
	main.current.call("hide_card", true)
	await _wait(1.8)
	# 1) すくい（スロー）
	_mark("1)")
	GameState.reset("data")
	GameState.nets["plain"] = 3
	await _go("catch")
	await _wait(0.6)
	main.current.call("demo_still")
	await _wait(2.6)
	main.current.call("demo_lift")
	await _wait(2.6)
	# 2) 夜のおわり → 朝へ（入力は無い。玉は朝にかえる）
	_mark("2)")
	GameState.scooped_tonight = true
	await _go("night")
	await _wait(1.6)
	main.current.call("_morning")
	await _wait(2.4)
	# 4) 朝の孵化（レア）
	_mark("4)")
	GameState.add_obake("yumemi")
	GameState.hatched.push_front({"id": "yumemi", "is_new": true, "level": 1, "rare": true})
	await _go("hatch")
	await _wait(0.4)
	main.current.call("_next")
	await _wait(3.3)
	# 5) 庭が育つ
	_mark("5)")
	main.fast_forward(6)
	GameState.garden_seen_level = GameState.garden_level - 1
	GameState.phase = "morning"
	GameState.last_night = {"growth_gain": 11, "level_before": 0, "worked": true, "river": true}
	await _go("garden")
	await _wait(1.6)
	main.current.call("_after_morning")
	await _wait(4.0)
	# 6) 満月の夜
	_mark("6)")
	await _go("moon")
	await _wait(0.6)
	main.current.call("demo_light_all")
	await _wait(4.2)
	# 7) 育った夜の庭
	_mark("7)")
	main.fast_forward(24)
	GameState.phase = "evening"
	await _go("garden")
	await _wait(2.6)
	# 8) 図鑑
	_mark("8)")
	await _go("zukan")
	await _wait(1.0)
	for c in main.current.get_children():
		if c is ScrollContainer:
			var tw := create_tween()
			tw.tween_property(c, "scroll_vertical", 1100, 2.6).set_trans(Tween.TRANS_SINE)
	await _wait(3.0)
	# 9) タイトル
	_mark("9)")
	await _go("title")
	await _wait(2.3)
	get_tree().quit()
