class_name DemoRoute
extends Node
## 審査員向けの 3 分デモ（タイトル／診断のはじめの「3-minute demo」）。本物の画面と状態をそのまま通る：
##   診断は見本の結果（とくべつな印つきの猫）で飛ばす → 求人カード 1 枚（受ける）→ シフトを早送りして猫がへとへとで止まる
##   → ひとこと評価 → 夜のすくい 1 回（おばネコの玉が必ずある）→ 朝、その玉から特別なレア（はじめての夜と同じ子、SpecialReveal.pick）
##   → 最後のカード「Recruit の見え方を見る」（RECRUIT_VIEW_URL）
## 画面の行き先は main.go() がここ（route）を通して決める。デモの間はテレメトリーに demo_session が付く。

## Recruit の見え方（insights のモック：シミュレーション・離職リスクの画面・ライブの引き出し）。lang は今の言語
const RECRUIT_VIEW_URL := "https://paw-time-insights.vercel.app/?mode=sim&view=at-risk&drawer=live&demo=1"
const PRESET_TYPE := "OPHK" # 見本の診断結果（ホールの子。印は SpecialObake.pick で決まる）
const SHIFT_H := WorkTogether.EXHAUST_HOURS # へとへとになるところで終わるシフト
const FAST := 1080.0 # 実時間 1 秒 = 18 分（7.5 時間 ≒ 25 秒）
const STEPS := ["job", "shift", "review", "scoop", "hatch", "final"]

static var active := false
static var stage := ""
static var node: DemoRoute

var main
var shift_id := ""
var chip: Label
var layer: CanvasLayer
var _wait := 0.0
var _t0 := 0.0
var _flush_t := 0.0


## タイトルのボタンから
static func begin(m) -> void:
	if node and is_instance_valid(node):
		node.queue_free()
	var d := DemoRoute.new()
	d.main = m
	m.add_child(d)
	node = d
	active = true
	d._setup()


## 見本の状態を作って、島（求人カード）から
func _setup() -> void:
	_t0 = Time.get_ticks_msec() / 1000.0
	Telemetry.set_demo_session(true) # デモの間のイベントには demo_session が付く（Recruit の見え方の「デモだけ」）
	GameState.reset("solo")
	GameState.set_my_obake(SpecialObake.apply(QuizData.score(QuizData.answers_for(PRESET_TYPE))))
	Onboarding.advance("done")
	Shifts.reset()
	WorkTogether.reset()
	WorkTogether.set_speed(1.0, true)
	Reviews.reset()
	Invites.reset()
	Toasts.clear()
	GameState.clock_offset = 0.0
	# 今日の求人は 1 枚だけ（見本のカフェ、ホール）。受けたら、そのシフトがすぐ始まる
	var now := Time.get_unix_time_from_system()
	var job := JobListings.demo_pay({"id": "demo3_job", "listing": Invites.SAMPLE_LISTING, "role": "hall", "area": "shibuya", "start": now + 3600.0, "end": now + 3600.0 + SHIFT_H * 3600.0,
		"pay": "daily", "line_n": 1})
	JobListings.localize(job)
	JobDesk._board = {"key": JobDesk.today_key(), "jobs": [job], "decided": {}}
	JobDesk._save_board(JobDesk._board)
	GameState.save()
	stage = "job"
	main.go("garden")


func _ready() -> void:
	layer = CanvasLayer.new()
	layer.layer = 55
	add_child(layer)
	chip = Kit.text("", 11, Color(1, 1, 1, 0.85), true, HORIZONTAL_ALIGNMENT_CENTER)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color(0.1, 0.08, 0.2, 0.6), 12, 0.0, Vector2(10, 3)))
	p.add_child(chip)
	p.position = Vector2(120, 4)
	p.size = Vector2(120, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(p)
	Kit.keep_fit(p, func():
		p.size = Vector2.ZERO
		p.position.x = 180 - p.size.x / 2.0)


## main.go() の行き先。デモの段に合わせて差しかえる
static func route(screen_name: String) -> String:
	if not active or node == null:
		return screen_name
	return node._route(screen_name)


func _route(screen_name: String) -> String:
	match stage:
		"scoop":
			# すくいから島へもどる → 夜が明けて、玉がかえる朝
			if screen_name == "garden":
				GameState.end_night()
				if GameState.hatched.is_empty():
					stage = "final"
					return "garden"
				stage = "hatch"
				return "hatch"
		"hatch":
			if screen_name == "garden":
				stage = "final"
	return screen_name


## すくいの玉：おばネコの玉が 1 つ（中身は特別なレア）。ゆっくりで逃げない
static func scoop_orbs() -> Array:
	return [{"type": "hall", "rare": true, "weight": 0.15, "easy": true, "content": {"kind": "obake", "special": SpecialReveal.pick()}}]


func _process(delta: float) -> void:
	if not active:
		return
	var i := STEPS.find(stage)
	chip.text = tr("DEMO3_CHIP") % [i + 1, STEPS.size(), int(Time.get_ticks_msec() / 1000.0 - _t0)]
	# デモの間は 3 秒ごとに送る（Recruit の見え方の Live の欄に、10 秒ほどで出るように。ふだんは約 20 秒ごと）
	_flush_t -= delta
	if _flush_t <= 0.0:
		_flush_t = 3.0
		Telemetry.flush_now()
	if _wait > 0.0:
		_wait -= delta
		return
	var cur = main.current
	match stage:
		"job":
			var desk := _desk(cur)
			if desk and desk.viewer == null and not desk.get_meta("demo_opened", false):
				desk.set_meta("demo_opened", true)
				desk._open_viewer()
			for s in Shifts.all():
				if String(s.id) == "demo3_job":
					_start_shift(s)
		"shift":
			# 早送りのシフトが終わったら、ふつうの時間へ（島では評価）
			if not WorkTogether.active() and WorkTogether._speed == FAST:
				WorkTogether.set_speed(1.0, true)
			if _is_garden(cur) and not WorkTogether.active():
				stage = "review"
		"review":
			if Reviews.is_reviewed(shift_id):
				stage = "scoop"
				_wait = 1.6 # お礼のカードを少し見せてから
				_go_scoop.call_deferred()
		"scoop":
			# すくえたら、今夜はおしまい（まとめのカード → 島へもどる）
			if cur and cur.has_method("_finish") and GameState.orbs.any(func(o): return String(o.get("content", {}).get("special", "")) != "") and not GameState.scooped_tonight:
				_wait = 1.2
				_finish_scoop.call_deferred(cur)
		"final":
			if _is_garden(cur) and layer.get_node_or_null("Final") == null:
				_final_card()


func _is_garden(cur) -> bool:
	return cur != null and is_instance_valid(cur) and cur.get_script().resource_path.ends_with("screen_garden.gd")


func _finish_scoop(cur) -> void:
	await get_tree().create_timer(1.2).timeout
	if main.current == cur and is_instance_valid(cur):
		cur._finish()


func _desk(cur) -> JobDesk:
	if cur == null:
		return null
	for c in cur.get_children():
		if c is JobDesk:
			return c
	return null


## 受けたシフトを「いま」から始めて、早送り（7.5 時間でへとへと → 終わり）
func _start_shift(s: Dictionary) -> void:
	stage = "shift"
	shift_id = String(s.id)
	var now := Time.get_unix_time_from_system()
	Shifts.remove(shift_id)
	s.start = now
	s.end = now + (SHIFT_H * 3600.0 + 60.0) / FAST # 実時間での終わり（早送りの時計では 7.5 時間後）
	s["hours"] = SHIFT_H # 今日のお給料の目安は、早送りの時計での長さで
	Shifts.add(s)
	WorkTogether.set_speed(FAST)
	WorkTogether.sync()
	# 早送りの時計でシフトの終わりを 7.5 時間後に（Shifts は実時間、WorkTogether は早送りの時計）
	var sess := WorkTogether._session
	sess.end_at = WorkTogether.now() + SHIFT_H * 3600.0 + 60.0 # へとへとの 1 分あと（残業にはならない）
	sess.start = WorkTogether.now()
	WorkTogether._save()
	_wait = 1.8 # 「受けた」のカードを少し見せてから
	(func():
		await get_tree().create_timer(1.8).timeout
		main.go("work")).call()


func _go_scoop() -> void:
	await get_tree().create_timer(1.6).timeout
	main.go("catch")


## 最後のカード：Recruit の見え方へ
func _final_card() -> void:
	Telemetry.flush_now() # Live の欄にすぐ出るように
	var dim := ColorRect.new()
	dim.name = "Final"
	dim.color = Color(0.05, 0.04, 0.1, 0.55)
	dim.position = Vector2.ZERO
	dim.size = Vector2(360, Kit.screen_h(self))
	layer.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color(1, 0.99, 0.97, 0.98), 24, 0.25, Vector2(18, 16)))
	p.position = Vector2(24, 150 + maxf(0.0, (Kit.screen_h(self) - 640.0) / 2.0))
	p.size = Vector2(312, 0)
	dim.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	v.add_child(Kit.text(tr("DEMO3_FINAL_TITLE"), 22, Color("2a2233"), true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Kit.wrap(Kit.text(tr("DEMO3_FINAL_BODY") % int(Time.get_ticks_msec() / 1000.0 - _t0), 14, Color("4a3f52"), false, HORIZONTAL_ALIGNMENT_CENTER)))
	var url := recruit_view_url()
	v.add_child(Kit.button(tr("DEMO3_RECRUIT"), Color("ff8a5b"), func(): OS.shell_open(url)))
	v.add_child(Kit.button(tr("DEMO3_KEEP"), Color("f3ecff"), _end, Color("6a5bd6"), 44, 15))
	p.pivot_offset = Vector2(156, 120)
	p.scale = Vector2(0.9, 0.9)
	p.modulate.a = 0.0
	var tw := p.create_tween().set_parallel()
	tw.tween_property(p, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.25)
	Kit.play(self, "sparkle")


static func recruit_view_url() -> String:
	return RECRUIT_VIEW_URL + "&lang=" + ("en" if Kit.is_en() else "ja")


## デモを終えて、そのまま遊びつづける
func _end() -> void:
	active = false
	stage = ""
	node = null
	Telemetry.set_demo_session(false)
	queue_free()
