extends Node
## 画面の切り替え役。画面は Control を差し替え、暗転でつなぐ。

const SCREENS := {
	"title": preload("res://scripts/screen_title_v2.gd"), # 夕方の港のタイトル（ボタンの行き先は screen_title.gd のまま）
	"garden": preload("res://scripts/screen_garden.gd"),
	"morning": preload("res://scripts/screen_garden.gd"),
	"room": preload("res://scripts/screen_garden.gd"),
	"evening": preload("res://scripts/screen_garden.gd"),
	"catch": preload("res://scripts/screen_scoop.gd"),
	"hatch": preload("res://scripts/screen_hatch.gd"),
	"night": preload("res://scripts/screen_night.gd"), # 夜のおわり（朝へ）
	"moon": preload("res://scripts/screen_moon.gd"),
	"zukan": preload("res://scripts/screen_zukan.gd"),
	"quiz": preload("res://scripts/screen_quiz.gd"),
	# はじめての流れと仕事さがし（feature/onboarding-jobs）。流れの順番は scripts/onboarding.gd
	"onboard": preload("res://scripts/screen_onboard.gd"),
	"prefs": preload("res://scripts/screen_job_prefs.gd"),
	"work": preload("res://scripts/screen_work.gd"),
	"wardrobe": preload("res://scripts/screen_wardrobe.gd"),
	"travel": preload("res://scripts/screen_travel.gd"),
	# お店の島（実績で育つ島）。行き先は GameState.visit.shop（scripts/shop_culture.gd）
	"shop_island": preload("res://scripts/screen_shop_island.gd"),
	# おさらい（練習）とスキルの記録（feature/skills）
	"practice": preload("res://scripts/screen_practice.gd"),
	"skills": preload("res://scripts/screen_skills.gd"),
	"chat": preload("res://scripts/screen_chat.gd"), # チャット（feature/cat-chat）。OBAKE_CHAT=me|list|shop:<id>
	# マイページ（設定）。島などの上に重ねるときは SettingsScreen.open(parent)
	"settings": preload("res://scripts/screen_settings.gd"),
}

var root: Control
var current: Control
var current_name := "" # いまの画面の名前（マイページで言語を変えたあと、同じ画面を作り直すため）
var fade: ColorRect
var busy := false
var demo: Node


func _ready() -> void:
	Kit.load_lang()
	Sfx.install(get_tree())
	# 宣伝動画の撮影用：ウィンドウの大きさを指定（OBAKE_WINDOW=720x1280）
	var win := OS.get_environment("OBAKE_WINDOW")
	if win != "":
		var wh := win.split("x")
		DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UI.make_theme()
	add_child(root)
	fade = ColorRect.new()
	fade.color = Color("0b1026")
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0
	# 確認用：表示の言語（en / ja）。ふだんは端末の言語
	if OS.get_environment("OBAKE_LOCALE") != "":
		TranslationServer.set_locale(OS.get_environment("OBAKE_LOCALE"))
	var start := OS.get_environment("OBAKE_START")
	if start != "" and start != "title":
		GameState.reset(OS.get_environment("OBAKE_MODE") if OS.get_environment("OBAKE_MODE") != "" else "data")
		_seed_for(start)
	# はじめて起動した人は、タイトルを飛ばしてマイおばけ猫の診断から（scripts/onboarding.gd の順番）
	if start == "" and not GameState.has_save() and Onboarding.at("quiz"):
		GameState.reset("solo") # 見本の記録ではなく、自分で受けた仕事（Shifts）で遊ぶ
		GameState.save()
		start = "quiz"
	# 島のコード（Web は URL の #island=、手元では OBAKE_VISIT）で起動したら、その島へおでかけ
	var code := OS.get_environment("OBAKE_VISIT")
	if OS.has_feature("web"):
		var h = JavaScriptBridge.eval("location.hash", true)
		if typeof(h) == TYPE_STRING and String(h).begins_with("#island="):
			code = String(h).substr(8)
	if code != "":
		if GameState.has_save():
			GameState.load_game()
		var d := GameState.decode_island(code)
		if not d.is_empty():
			d.code = code
			GameState.visit = d
			# 自分の乗り物で海を渡ってから（OBAKE_NOTRAVEL=1 で、すぐ島へ）
			start = "garden" if OS.get_environment("OBAKE_NOTRAVEL") != "" else "travel"
	# 確認用：特別なレアの動画（OBAKE_REVEAL=<id>）。その子が玉からかえる朝から
	var rv := OS.get_environment("OBAKE_REVEAL")
	if SpecialReveal.is_special(rv):
		if start == "quiz" or start == "":
			GameState.reset("solo")
		GameState.hatched = [{"id": rv, "is_new": GameState.add_obake(rv), "level": 1, "rare": true, "special": OS.get_environment("OBAKE_REVEAL_TUTORIAL") != ""}]
		start = "hatch"
	go(start if SCREENS.has(start) else "title", true)
	root.add_child(fade)
	_music()
	GameState.goal_completed.connect(_on_goal)
	# デモの見せ場の切りかえ（OBAKE_DEMO=1 か、Web の ?demo=1）
	if DemoSwitch.enabled():
		var ds := DemoSwitch.new()
		ds.main = self
		add_child(ds)
	if OS.get_environment("OBAKE_DEMO") in ["play", "promo"]:
		demo = load("res://scripts/demo.gd").new()
		demo.main = self
		add_child(demo)
	_app_open()
	TelemetryNotice.show_once(self)
	_maybe_autoshot()


## テレメトリー：起動 1 回につき 1 件。今日が仕事の日か・シフトの予定だけある日か・無い日か、最後のシフトからの時間
func _app_open() -> void:
	var now := Time.get_unix_time_from_system()
	var today := Time.get_date_string_from_system()
	var day_type := "no_shift"
	var last_end := -1.0
	for s in Shifts.all():
		if Time.get_date_string_from_unix_time(int(float(s.start) + WorkTogether._tz_offset())) == today:
			day_type = "work"
		elif day_type != "work" and float(s.start) > now:
			day_type = "off" # 予定はあるけれど、今日ではない
		if float(s.end) <= now:
			last_end = maxf(last_end, float(s.end))
	var since := now - last_end if last_end > 0.0 else -1.0
	Telemetry.track("app_open", {"day_type": day_type, "hours_since_last_shift_end": Telemetry.since_shift_bucket(since)})


var music: Music


## めあて達成の知らせ（どの画面でも上から降りてくる）


func _on_goal(text: String, all_done: bool) -> void:
	# 夜のおわり・孵化の間に達成したものは、朝の庭で知らせる
	if current and current.get_script().resource_path.get_file() in ["screen_night.gd", "screen_hatch.gd"]:
		GameState.pending_toasts.append([text, all_done])
		return
	# ほかの知らせと重ならないよう、順番に（Toasts）
	Toasts.push(tr("めあて達成　めぐみ +3"), tr(text) + ("\n" + tr("3つそろった！ 肉球コイン +10") if all_done else ""), "goal")
	Sfx.coins(self, 20 if all_done else 10)
	Music.duck("jingle", -6.0, 1.6)


func _music() -> void:
	music = Music.new()
	add_child(music)
	music.play_for(current_name)


## 画面ごとの曲（scripts/music.gd の SCREEN_TRACK）。同じ曲の画面どうしでは鳴らしなおさない
func _music_for(screen_name: String) -> void:
	if music == null:
		return
	music.play_for(screen_name)


## 確認用：途中の画面から始めるときの下ごしらえ
func _seed_for(start: String) -> void:
	var ff := int(OS.get_environment("OBAKE_FF")) if OS.get_environment("OBAKE_FF") != "" else 0
	if ff > 0:
		fast_forward(ff)
	# 確認用：おばネコの玉が混ざる夜（救済を効かせる）
	if OS.get_environment("OBAKE_CAT_ORB") != "":
		GameState.last_new_cat_day = GameState.day - Drops.CAT_PITY_NIGHTS
	# 島の段を決めて撮る（OBAKE_LEVEL=0..10）と、置き物キットの見本の飾りつけ（OBAKE_KIT_DEMO=1）
	if OS.get_environment("OBAKE_LEVEL") != "":
		GameState.garden_level = int(OS.get_environment("OBAKE_LEVEL"))
		GameState.garden_seen_level = GameState.garden_level
	# 確認用：広げた場所（OBAKE_EXPAND=plot_front_right,islet_front）・材料（OBAKE_MATS=各 n こ）・乗り物（OBAKE_VEHICLES=rowboat,ferry）
	if OS.get_environment("OBAKE_MATS") != "":
		IslandKit.load_all()
		for k in IslandKit.MAT_ORDER:
			IslandKit.grant_material(k, int(OS.get_environment("OBAKE_MATS")))
	if OS.get_environment("OBAKE_VEHICLES") != "":
		var vs := Array(OS.get_environment("OBAKE_VEHICLES").split(","))
		Vehicles.reset(vs, vs[-1])
	if OS.get_environment("OBAKE_COINS") != "":
		Wallet.reset(int(OS.get_environment("OBAKE_COINS")))
	if OS.get_environment("OBAKE_KIT_DEMO") != "":
		IslandKit.demo_layout(IslandKit.stage_for(GameState.garden_level))
	if OS.get_environment("OBAKE_EXPAND") != "":
		IslandKit.load_all()
		IslandKit.expanded = Array(OS.get_environment("OBAKE_EXPAND").split(","))
	# 確認用：お店の島へ（OBAKE_SHOP=<求人の店の id>。OBAKE_START=travel なら乗り物の場面から）
	if OS.get_environment("OBAKE_SHOP") != "":
		GameState.visit = ShopCulture.visit_data(OS.get_environment("OBAKE_SHOP"))
	# 確認用：前の晩・当日の朝のひとこと（OBAKE_REMIND=eve|am で、あした／きょうの 10:00 に見本のシフト。時刻は OBAKE_NOW）
	if OS.get_environment("OBAKE_REMIND") != "":
		Reminders.demo_shift(OS.get_environment("OBAKE_REMIND"))
	# 確認用：スキルの記録（OBAKE_SKILLS=register:2:3,dish:1:0 … 仕事:星:シフト回数）と、おさらいの仕事（OBAKE_PRACTICE=dish）
	if OS.get_environment("OBAKE_SKILLS") != "":
		var roles := {}
		for e in OS.get_environment("OBAKE_SKILLS").split(","):
			var p := e.split(":")
			roles[p[0]] = {"stars": int(p[1]) if p.size() > 1 else 0, "clears": 0, "shifts": int(p[2]) if p.size() > 2 else 0}
		Skills.from_dict({"roles": roles})
	if OS.get_environment("OBAKE_PRACTICE") != "":
		Skills.practice_role = OS.get_environment("OBAKE_PRACTICE")
	if start == "hatch":
		GameState.orbs = [{"type": "dish", "rare": false}, {"type": "rare", "rare": true}]
		if OS.get_environment("OBAKE_ITEMS") != "":
			GameState.orbs = [{"type": "dish", "rare": false, "content": {"kind": "obake"}}, {"type": "hall", "rare": false, "content": {"kind": "material", "id": "shell"}}, {"type": "stock", "rare": false, "content": {"kind": "material", "id": "driftwood"}}, {"type": "kitchen", "rare": false, "content": {"kind": "cloth", "id": "scarf"}}]
		GameState.end_night()
		var force := OS.get_environment("OBAKE_RARE")
		if force != "":
			GameState.add_obake(force)
			GameState.hatched.push_front({"id": force, "is_new": true, "level": 1, "rare": true})
	elif start == "morning":
		GameState.orbs = [{"type": "hall", "rare": false}]
		GameState.end_night()
	elif start == "evening":
		GameState.phase = "evening"


## 何日か自動で進める（毎晩すくう）。監査・宣伝用
func fast_forward(days: int) -> void:
	GameState.quiet = true
	for i in days:
		var s := GameState.today()
		if s.role != "":
			GameState.finish_shift()
		GameState.new_decos = []
		GameState.orbs = [{"type": ["register", "dish", "hall", "kitchen", "stock"].pick_random(), "rare": false}, {"type": ["register", "dish", "hall"].pick_random(), "rare": randf() < 0.2}]
		if GameState.is_moon_night():
			var lit := 0
			for g in GameState.moon_lanterns():
				if g:
					lit += 1
			GameState.finish_moon(lit, 3)
		GameState.scooped_tonight = true
		GameState.end_night()
	GameState.garden_seen_level = GameState.garden_level
	GameState.phase = "day"
	GameState.hatched = []
	GameState.newcomers = []
	GameState.quiet = false


func go(screen_name: String, instant := false) -> void:
	if busy:
		return
	busy = true
	# 3 分デモの間は、デモの段に合わせた行き先（DemoRoute）
	screen_name = DemoRoute.route(screen_name)
	# 働いている間は、猫の仕事場だけ（すくい・島づくり・キセカエ・おさらい・求人は、シフトが終わってから）
	if not WorkTogether.screen_allowed(screen_name) and OS.get_environment("OBAKE_START") == "":
		screen_name = "work"
	# 自分の島へは、実際の時計に合わせてから（朝が来ていれば夜が明けて、玉がかえる）
	if screen_name == "garden" and GameState.visit.is_empty() and Onboarding.at("done") and OS.get_environment("OBAKE_START") == "":
		GameState.sync_clock()
		if GameState.phase == "morning" and not GameState.hatched.is_empty():
			screen_name = "hatch"
	if not instant:
		fade.mouse_filter = Control.MOUSE_FILTER_STOP
		var tw := create_tween()
		tw.tween_property(fade, "modulate:a", 1.0, 0.2)
		await tw.finished
	_music_for(screen_name)
	if current:
		current.queue_free()
	current = SCREENS[screen_name].new()
	current_name = screen_name
	if screen_name == "quiz":
		current.set("next_screen", "garden")
	current.set_anchors_preset(Control.PRESET_FULL_RECT)
	current.set("main", self)
	current.set("screen_name", screen_name) # 1つの画面スクリプトで2場面を持つとき用（screen_onboard.gd）
	root.add_child(current)
	root.move_child(current, 0)
	if not instant:
		var tw2 := create_tween()
		tw2.tween_property(fade, "modulate:a", 0.0, 0.25)
		await tw2.finished
		fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busy = false
	if screen_name == "garden" and not GameState.pending_toasts.is_empty():
		_flush_goals()


func _flush_goals() -> void:
	var list := GameState.pending_toasts.duplicate()
	GameState.pending_toasts.clear()
	await get_tree().create_timer(0.6).timeout
	for g in list:
		_on_goal(g[0], g[1]) # 知らせは Toasts が順番に出す


## 確認用：OBAKE_SHOT="画面名,waitN,call:メソッド" で進めて撮る
func _maybe_autoshot() -> void:
	var target := OS.get_environment("OBAKE_SHOT")
	if target == "":
		return
	var path := OS.get_environment("OBAKE_SHOT_PATH")
	# 途中の画面から撮るとき（OBAKE_START なし）は、保存を読んでから（はじめての流れを段ごとに撮るため）
	if OS.get_environment("OBAKE_START") == "" and GameState.has_save():
		GameState.load_game()
	var n := 0
	for step in target.split(","):
		if step.begins_with("wait"):
			await get_tree().create_timer(float(step.substr(4)), true, false, true).timeout
		elif step.begins_with("call:"):
			# 画面そのものに無ければ、重ね画面（JobDesk など）の子から探す
			var m := step.substr(5)
			var who: Node = current
			if not current.has_method(m):
				for c in current.get_children():
					if c.has_method(m):
						who = c
			who.call(m)
			await get_tree().create_timer(0.6, true, false, true).timeout
		elif step == "shot":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%d.png" % n))
			n += 1
		else:
			await go(step, true)
			await get_tree().create_timer(0.8, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
