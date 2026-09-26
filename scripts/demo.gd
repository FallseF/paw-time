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
		print("[play] day %d %s phase=%s rhythm=%d garden=%d zukan=%d" % [GameState.day, sc, GameState.phase, int(GameState.rhythm), GameState.garden_level, GameState.seen.size()])
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
				print("[play] done. zukan=%d rares=%d garden=%d rhythm=%d" % [GameState.seen.size(), _rares(), GameState.garden_level, int(GameState.rhythm)])
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
					c.call("_rest")
				cool = 3.0
			elif GameState.phase == "evening":
				if GameState.is_moon_night() and not GameState.scooped_tonight:
					main.go("moon")
				elif not GameState.scooped_tonight:
					main.go("catch")
				else:
					main.go("sleep")
		"scoop":
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
		"sleep":
			if c.get("going"):
				return
			if GameState.mode == "solo":
				c.call("_choose", ["usual", "usual", "extra", "usual", "market", "usual", "early"][GameState.day % 7])
			c.call("_sleep")
			cool = 2.0
		"dream":
			if c.finished:
				main.go("hatch")
			elif not c.auto:
				c.call("demo_auto")
		"hatch":
			if not c.busy:
				c.call("_next")
				cool = 2.0
		"moon":
			if c.done:
				main.go("sleep")
			elif c.lit < c.good_total:
				c.call("demo_light_all")
				cool = 4.0
		"zukan":
			main.go("garden")


func _rares() -> int:
	var n := 0
	for id in GameState.seen:
		if Rares.is_rare(id):
			n += 1
	return n


# ---------- 宣伝動画 ----------

func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _promo() -> void:
	await get_tree().process_frame
	# 1) すくい（スロー）
	GameState.reset("data")
	GameState.nets["plain"] = 3
	await main.go("catch", true)
	await _wait(0.9)
	main.current.call("demo_hold")
	await _wait(0.5)
	main.current.call("demo_lift")
	await _wait(3.2)
	# 2) おやすみ
	await main.go("sleep")
	await _wait(1.8)
	main.current.call("_sleep")
	await _wait(1.6)
	# 3) 羊かぞえの夢
	GameState.rhythm = 80
	await main.go("dream", true)
	main.current.call("demo_auto")
	await _wait(7.5)
	# 4) 朝の孵化（レア）
	GameState.orbs = [{"type": "sleep", "rare": false}]
	GameState.sleep(330, 420)
	GameState.add_obake("yumemi")
	GameState.hatched.push_front({"id": "yumemi", "is_new": true, "level": 1, "rare": true})
	await main.go("hatch")
	await _wait(0.5)
	main.current.call("_next")
	await _wait(3.6)
	# 5) 庭が育つ
	main.fast_forward(6)
	GameState.garden_seen_level = GameState.garden_level - 1
	GameState.phase = "morning"
	GameState.last_night = {"bed": 330, "wake": 420, "hours": 7.5, "score": 26, "parts": [["たっぷり眠る", 12], ["いつもの時刻", 10], ["休みの日の休息", 4]], "rhythm_before": 70, "rhythm": 86, "growth_gain": 18, "level_before": 0, "late": false, "visitor": ""}
	await main.go("garden")
	await _wait(1.8)
	main.current.call("_after_morning")
	await _wait(4.2)
	# 6) 満月の夜
	await main.go("moon")
	await _wait(0.6)
	main.current.call("demo_light_all")
	await _wait(5.5)
	# 7) 育った夜の庭
	main.fast_forward(24)
	GameState.phase = "evening"
	await main.go("garden")
	await _wait(3.5)
	# 8) 図鑑
	await main.go("zukan")
	await _wait(1.0)
	var sc: ScrollContainer = main.current.get_child(2)
	var tw := create_tween()
	tw.tween_property(sc, "scroll_vertical", 900, 2.5).set_trans(Tween.TRANS_SINE)
	await _wait(3.0)
	# 9) タイトル
	await main.go("title")
	await _wait(3.0)
	get_tree().quit()
