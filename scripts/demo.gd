extends Node
## 自動で遊ぶ。
## OBAKE_AUTOPLAY=日数 OBAKE_SKILL=0〜1 OBAKE_WORK=0/1 OBAKE_SLEEP=7,8,6… で、本物のすくい画面を自動で回し、夜ごとの成績を出す（バランス確認）。
## godot --headless --path . --fixed-fps 60 で速く回せる。

var main


func run(m) -> void:
	main = m
	var days := int(OS.get_environment("OBAKE_AUTOPLAY"))
	if days > 0:
		await autoplay(days)
		get_tree().quit()
	elif OS.get_environment("OBAKE_DEMO") != "":
		await promo()
		get_tree().quit()


var layer: CanvasLayer
var cap_box: PanelContainer
var cap_label: Label
var font_black: FontFile


func _setup_captions() -> void:
	font_black = load("res://assets/fonts/ZenMaruGothic-Black.ttf")
	layer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	cap_box = PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.06, 0.11, 0.62)
	st.set_corner_radius_all(18)
	st.content_margin_left = 14
	st.content_margin_right = 14
	st.content_margin_top = 8
	st.content_margin_bottom = 10
	cap_box.add_theme_stylebox_override("panel", st)
	cap_box.position = Vector2(14, 240)
	cap_box.size = Vector2(332, 0)
	cap_box.modulate.a = 0.0
	cap_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cap_box)
	cap_label = Label.new()
	cap_label.add_theme_font_override("font", font_black)
	cap_label.add_theme_font_size_override("font_size", 21)
	cap_label.add_theme_color_override("font_color", Color.WHITE)
	cap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap_box.add_child(cap_label)


func caption(t: String, y := 240.0) -> void:
	cap_label.text = t
	cap_box.reset_size()
	cap_box.size.x = 332
	cap_box.position.y = y
	cap_box.scale = Vector2(0.9, 0.9)
	cap_box.pivot_offset = Vector2(166, 24)
	var tw := create_tween().set_parallel()
	tw.tween_property(cap_box, "modulate:a", 1.0, 0.2)
	tw.tween_property(cap_box, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func caption_off() -> void:
	create_tween().tween_property(cap_box, "modulate:a", 0.0, 0.2)


func _big_text(lines: Array, colors: Array, dim_alpha: float, y0: float) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.05, 0.12, dim_alpha)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(dim)
	var y := y0
	for i in lines.size():
		var l := Label.new()
		l.text = lines[i]
		l.add_theme_font_override("font", font_black)
		var big: bool = lines[i].length() <= 8
		l.add_theme_font_size_override("font_size", 44 if big else 21)
		l.add_theme_color_override("font_color", colors[i])
		l.add_theme_color_override("font_outline_color", Color("0b1026"))
		l.add_theme_constant_override("outline_size", 10 if big else 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.position = Vector2(0, y)
		l.size = Vector2(360, 60 if big else 30)
		l.modulate.a = 0.0
		c.add_child(l)
		create_tween().tween_property(l, "modulate:a", 1.0, 0.25).set_delay(0.3 * i)
		y += 62 if big else 36
	layer.add_child(c)
	return c


## OBAKE_SNAPDIR があれば、その場面を PNG に残す（窓ありで動かしたとき）
func _snap(name: String) -> void:
	var dir := OS.get_environment("OBAKE_SNAPDIR")
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


## 広告動画用：いちばんいい場面を自動で見せる（約 42 秒）
func promo() -> void:
	seed(20260926)
	GameState.reset()
	GameState.fast_forward(10, [7, 8, 7])
	_setup_captions()
	# 1) 満月の夜、仕事のポイで、すくう（0〜12秒）
	GameState.day = 17 # 木曜・満月
	GameState.worked_today = false
	GameState.finish_shift()
	GameState.pois["kira"] = max(GameState.pois.kira, 1)
	GameState.upgrades = {"fuchi": 3, "wa": 2, "kami": 3}
	if not GameState.seen.has("tsukimi"):
		GameState.rare_pending.push_front("tsukimi")
	await main.go("catch", true)
	var scoop = main.current
	scoop.start_auto(0.95)
	var hook := _big_text(["光る玉を", "そっと すくう。"], [Color.WHITE, Color("ffe27a")], 0.35, 200)
	await _wait(1.2)
	scoop.demo_rainbow()
	await _wait(1.2)
	hook.queue_free()
	caption("働いた日は、ポイが増える。")
	await _wait(4.4)
	caption("そっと、真ん中で。コンボ！")
	await _wait(4.4)
	caption_off()
	await _wait(0.8)
	# 2) 寝る → 朝、玉がかえる（12〜24秒）
	scoop.ended = true
	GameState.record_scoop_night({"count": scoop.count, "best_combo": scoop.best_combo, "clean": scoop.clean_count, "rainbow": scoop.rainbow_count})
	# 朝の見せ場：ふつうの玉ふたつと、最後にレア
	GameState.orbs = GameState.orbs.slice(0, 1)
	GameState.rare_pending = ["tsukimi"]
	await main.go("sleep")
	caption("よく寝た朝は、玉がよくかえる。", 470)
	await _wait(1.6)
	main.current._sleep()
	await _wait(2.6)
	var hatch = main.current
	caption("よく寝た朝は、玉がよくかえる。", 130)
	for i in 2:
		if hatch.has_method("_next"):
			hatch._next()
		await _wait(4.0)
	# 3) 休憩室がにぎやかに（24〜29秒）
	await main.go("room")
	caption("かえったおばけが、休憩室に。", 250)
	await _wait(1.0)
	main.current._close_report()
	await _wait(3.0)
	# 4) 図鑑はトロフィー部屋（29〜34秒）
	await main.go("zukan")
	caption("レア30体。図鑑をうめよう。", 520)
	var z = main.current
	await _wait(0.6)
	var sc: ScrollContainer = z.get_child(2) if z.get_child(2) is ScrollContainer else null
	for c in z.get_children():
		if c is ScrollContainer:
			sc = c
	if sc:
		var tw := create_tween()
		tw.tween_property(sc, "scroll_vertical", 900, 3.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait(3.6)
	# 5) 土曜は大すくい祭り（34〜42秒）
	GameState.day = 19
	GameState.phase = "room"
	GameState.orbs = []
	GameState.pois["paper"] = 6
	GameState.pois["double"] = 2
	await main.go("catch")
	main.current.selected = "double"
	main.current.start_auto(1.0)
	caption("土曜の夜は、大すくい祭り。", 250)
	await _wait(7.0)
	caption_off()
	_big_text(["おばけの休憩室", "働いた日は、ポイが増える。", "よく寝た朝は、玉がよくかえる。"], [Color.WHITE, Color("ffe27a"), Color("ffe27a")], 0.9, 230)
	await _wait(3.6)


func autoplay(days: int) -> void:
	var skill := float(OS.get_environment("OBAKE_SKILL")) if OS.get_environment("OBAKE_SKILL") != "" else 0.8
	var work := OS.get_environment("OBAKE_WORK") != "0"
	var pattern: Array = []
	for x in (OS.get_environment("OBAKE_SLEEP") if OS.get_environment("OBAKE_SLEEP") != "" else "7").split(","):
		pattern.append(int(x))
	var total := 0
	var full_ui := OS.get_environment("OBAKE_FULLUI") != ""
	for d in days:
		var s := GameState.today()
		if full_ui:
			await main.go("room")
			await _wait(0.3)
			if main.current.has_method("_close_report"):
				main.current._close_report()
			await _wait(0.6)
			_snap("d%02d_a_room" % (d + 1))
			if work and s.role != "":
				main.current._do_shift()
			await _wait(0.2)
		elif work and s.role != "":
			GameState.finish_shift()
		var mods := GameState.night_mods()
		var pois_before := GameState.total_pois()
		await main.go("catch", true)
		var scoop = main.current
		scoop.start_auto(skill)
		var frames := 0
		while not scoop.ended and frames < 60 * 240:
			await get_tree().process_frame
			frames += 1
			if full_ui and frames == 60 * 6:
				_snap("d%02d_a2_scoop" % (d + 1))
		if not scoop.ended:
			print("  自動すくいが時間切れ: busy=%s pressed=%s in_hand=%s sel=%s state=%s supply=%d vis=%d pois=%s tele=%.1f" % [scoop.busy, scoop.pressed, scoop.in_hand, scoop.selected, scoop.auto_state, scoop.supply, scoop._visible_count(), str(GameState.pois), scoop.telegraph_left])
		var t: Dictionary = GameState.tonight
		total += t.get("count", 0)
		var h: int = pattern[d % pattern.size()]
		if full_ui:
			await _wait(0.8)
			_snap("d%02d_b_result" % (d + 1))
			await main.go("sleep")
			main.current._set_hours(h)
			main.current._sleep()
			await _wait(2.2)
			if main.current_name == "hatch":
				main.current._next()
				await _wait(3.0)
				_snap("d%02d_c_hatch" % (d + 1))
				main.current._open_all()
				await _wait(0.5)
			await main.go("zukan")
			await _wait(0.2)
			await main.go("workshop")
			await _wait(0.2)
			print("D%02d 画面を一巡: %s" % [d + 1, main.current_name])
			continue
		print("D%02d %s曜 %s %s%s | ポイ%2d 使%2d | すくい%2d コンボ%2d ていねい%2d 虹%d | %4.0f秒 | 寝%d" % [d + 1, s.day, s.weather, s.moon if s.moon != "" else "--", " 祭" if mods.festival else "", pois_before, pois_before - GameState.total_pois(), t.get("count", 0), t.get("best_combo", 0), t.get("clean", 0), t.get("rainbow", 0), frames / 60.0, h])
		var kinds := {}
		for o in GameState.orbs:
			kinds[o.kind] = kinds.get(o.kind, 0) + 1
		GameState.sleep(h)
		if OS.get_environment("OBAKE_VERBOSE") != "":
			var hs := {}
			for x in GameState.hatched:
				hs[x.id] = hs.get(x.id, 0) + 1
			print("      玉 ", kinds, " → ", hs)
		var lv := []
		for id in GameState.NORMAL_IDS:
			lv.append(GameState.level_of(id))
		var news := []
		for x in GameState.hatched:
			if x.is_new:
				news.append(GameState.info(x.id).name)
		if news.size() > 0:
			print("      NEW: ", ", ".join(news))
		for key in GameState.claimable():
			GameState.claim(key)
		for u in ["fuchi", "wa", "kami"]:
			if GameState.upgrade(u):
				print("      工房: %s Lv%d（%d日目）" % [u, GameState.upgrades[u], d + 1])
		if d % 7 == 6:
			print("   -- 週末: 図鑑 %d/%d  Lv %s  かけら %s  累計すくい %d" % [GameState.seen.size(), GameState.ALL.size(), str(lv), str(GameState.shards), total])
	print("== 終了: 図鑑 %d/%d 最高コンボ %d 累計 %d" % [GameState.seen.size(), GameState.ALL.size(), GameState.records.best_combo, total])
