extends Node
## 画面の切り替え役。画面は Control を差し替え、暗転でつなぐ。

const SCREENS := {
	"title": preload("res://scripts/screen_title.gd"),
	"garden": preload("res://scripts/screen_garden.gd"),
	"morning": preload("res://scripts/screen_garden.gd"),
	"room": preload("res://scripts/screen_garden.gd"),
	"evening": preload("res://scripts/screen_garden.gd"),
	"catch": preload("res://scripts/screen_scoop.gd"),
	"hatch": preload("res://scripts/screen_hatch.gd"),
	"sleep": preload("res://scripts/screen_sleep.gd"),
	"dream": preload("res://scripts/screen_dream.gd"),
	"moon": preload("res://scripts/screen_moon.gd"),
	"zukan": preload("res://scripts/screen_zukan.gd"),
	"quiz": preload("res://scripts/screen_quiz.gd"),
	"travel": preload("res://scripts/screen_travel.gd"),
}

var root: Control
var current: Control
var fade: ColorRect
var busy := false
var demo: Node


func _ready() -> void:
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
	go(start if SCREENS.has(start) else "title", true)
	root.add_child(fade)
	_music()
	GameState.goal_completed.connect(_on_goal)
	if OS.get_environment("OBAKE_DEMO") != "":
		demo = load("res://scripts/demo.gd").new()
		demo.main = self
		add_child(demo)
	_maybe_autoshot()


var music: AudioStreamPlayer
var goal_toast: PanelContainer


## めあて達成の知らせ（どの画面でも上から降りてくる）


func _on_goal(text: String, all_done: bool) -> void:
	# 寝ている間・夢の中で達成したものは、朝の庭で知らせる
	if current and current.get_script().resource_path.get_file() in ["screen_sleep.gd", "screen_dream.gd", "screen_hatch.gd"]:
		GameState.pending_toasts.append([text, all_done])
		return
	if goal_toast and is_instance_valid(goal_toast):
		goal_toast.queue_free()
	goal_toast = PanelContainer.new()
	goal_toast.add_theme_stylebox_override("panel", Kit.pill(Color("fff6d8"), 18, 0.25, Vector2(14, 8)))
	goal_toast.position = Vector2(30, -60)
	goal_toast.size = Vector2(300, 0)
	goal_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(goal_toast)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	goal_toast.add_child(v)
	v.add_child(Kit.text("めあて達成　めぐみ +3", 12, Color("b07a1a"), true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Kit.text(text, 14, Color("2a2233"), true, HORIZONTAL_ALIGNMENT_CENTER))
	if all_done:
		v.add_child(Kit.text("3つそろった！ きらきらポイ +1", 12, Color("6a5bd6"), true, HORIZONTAL_ALIGNMENT_CENTER))
	Kit.play(self, "bell", 1.3, -6)
	var tw := goal_toast.create_tween()
	tw.tween_property(goal_toast, "position:y", 56.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.0)
	tw.tween_property(goal_toast, "position:y", -80.0, 0.3).set_trans(Tween.TRANS_SINE)
	var gt := goal_toast
	tw.tween_callback(func(): if is_instance_valid(gt): gt.queue_free())


func _music() -> void:
	music = AudioStreamPlayer.new()
	var loop: AudioStreamWAV = load("res://assets/sfx/lullaby.wav")
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_end = loop.data.size() / 2
	music.stream = loop
	music.volume_db = -13
	add_child(music)
	music.play()


## 画面ごとに音楽の大きさを変える（すくいと夢では控えめ）
func _music_for(screen_name: String) -> void:
	if music == null:
		return
	var db: float = {"catch": -30.0, "dream": -22.0, "moon": -16.0}.get(screen_name, -13.0)
	create_tween().tween_property(music, "volume_db", db, 0.6)


## 確認用：途中の画面から始めるときの下ごしらえ
func _seed_for(start: String) -> void:
	var ff := int(OS.get_environment("OBAKE_FF")) if OS.get_environment("OBAKE_FF") != "" else 0
	if ff > 0:
		fast_forward(ff)
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
	if start == "hatch":
		GameState.orbs = [{"type": "dish", "rare": false}, {"type": "rare", "rare": true}]
		GameState.sleep(330, 420)
		var force := OS.get_environment("OBAKE_RARE")
		if force != "":
			GameState.add_obake(force)
			GameState.hatched.push_front({"id": force, "is_new": true, "level": 1, "rare": true})
	elif start == "morning":
		GameState.orbs = [{"type": "hall", "rare": false}]
		GameState.sleep(330, 450)
	elif start == "evening":
		GameState.phase = "evening"


## 何日か自動で進める（よく眠る日が多め）。監査・宣伝用
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
		var bed: int = 330 + [0, 0, 10, -10, 20, 0, 90][i % 7]
		GameState.sleep(bed, 420 + (30 if i % 3 == 0 else 0))
		if GameState.dream_pending:
			GameState.finish_dream(8)
	GameState.garden_seen_level = GameState.garden_level
	GameState.phase = "day"
	GameState.hatched = []
	GameState.newcomers = []
	GameState.quiet = false


func go(screen_name: String, instant := false) -> void:
	if busy:
		return
	busy = true
	if not instant:
		fade.mouse_filter = Control.MOUSE_FILTER_STOP
		var tw := create_tween()
		tw.tween_property(fade, "modulate:a", 1.0, 0.2)
		await tw.finished
	_music_for(screen_name)
	if current:
		current.queue_free()
	current = SCREENS[screen_name].new()
	if screen_name == "quiz":
		current.set("next_screen", "garden")
	current.set_anchors_preset(Control.PRESET_FULL_RECT)
	current.set("main", self)
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
	for g in list:
		await get_tree().create_timer(0.6).timeout
		_on_goal(g[0], g[1])
		await get_tree().create_timer(2.2).timeout


## 確認用：OBAKE_SHOT="画面名,waitN,call:メソッド" で進めて撮る
func _maybe_autoshot() -> void:
	var target := OS.get_environment("OBAKE_SHOT")
	if target == "":
		return
	var path := OS.get_environment("OBAKE_SHOT_PATH")
	var n := 0
	for step in target.split(","):
		if step.begins_with("wait"):
			await get_tree().create_timer(float(step.substr(4)), true, false, true).timeout
		elif step.begins_with("call:"):
			current.call(step.substr(5))
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
