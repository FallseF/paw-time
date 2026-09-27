class_name DemoSwitch
extends CanvasLayer
## デモの見せ場へ飛ぶ小さな切りかえ（審査・説明の場で使う）。ふだんは出ない。
## 出すとき：OBAKE_DEMO=1、または Web の URL に ?demo=1。右下の小さな「Demo」の札 → 4 つの場面。
## どれも本物の状態を作る（Shifts・WorkTogether・時計）ので、その先はいつもの流れのまま動く。
##   シフトの 1 時間前 … 1 時間後に始まる見本のシフトを入れて、昼の島へ（今日のシフトのカード・前の朝のひとこと）
##   シフト中（早送り）… 始まっているシフト。猫の仕事場で、時間が早く進む（1 秒＝6 分）。疲れて止まるところまで
##   シフトが終わった … 猫がへとへとになる直前で終わるシフト。仕事場で疲れたおつかれさまのカード → 島へ → ひとこと評価
##   次の朝        … 時計を次の日付の朝 7 時へ。夜が明けて、玉がかえる

const PREFIX := "demo_sw_"
const FAST := 360.0 # シフト中の早送り（実時間 1 秒 = 6 分）

var main
var panel: Control


static func enabled() -> bool:
	if OS.get_environment("OBAKE_DEMO") == "1":
		return true
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("location.search", true)
		return typeof(q) == TYPE_STRING and (String(q).contains("demo=1") or String(q).contains("demo=true"))
	return false


func _ready() -> void:
	layer = 60
	var chip := Button.new()
	chip.text = tr("R3_DEMO_CHIP")
	chip.focus_mode = Control.FOCUS_NONE
	chip.position = Vector2(154, 58) # 上のまんなか（下は島のタブ、右上は丸いボタン、左上は状態の札）
	chip.size = Vector2(52, 24)
	chip.add_theme_font_override("font", Kit.bold())
	chip.add_theme_font_size_override("font_size", 11)
	for k in ["normal", "hover", "pressed"]:
		chip.add_theme_stylebox_override(k, Kit.pill(Color(0.1, 0.08, 0.2, 0.55), 12, 0.0, Vector2(6, 2)))
	chip.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	chip.pressed.connect(_toggle)
	add_child(chip)


func _toggle() -> void:
	if panel and is_instance_valid(panel):
		panel.queue_free()
		panel = null
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.97), 16, 0.25, Vector2(10, 8)))
	p.position = Vector2(124, 400)
	p.size = Vector2(230, 0)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	v.add_child(Kit.text(tr("R3_DEMO_CHIP"), 12, Color("8a7a88"), true))
	for it in [["Before shift (in 1 h)", _before], ["On shift (fast-forward)", _on_shift], ["Just finished shift", _finished], ["Next morning", _next_morning]]:
		var cb: Callable = it[1]
		var b := Kit.button(it[0], Color("f3ecff"), func():
			_toggle()
			cb.call(), Color("6a5bd6"), 34, 13)
		v.add_child(b)
	panel = p
	Kit.keep_fit(p, func():
		p.size.y = 0
		p.position.y = 604 - p.size.y)


## 早送りしたシフトが終わったら、時間の進み方を実際の時刻にもどす（次の場面・ほかの画面がずれないように）
func _process(_delta: float) -> void:
	if WorkTogether._speed == FAST and not WorkTogether.active():
		WorkTogether.set_speed(1.0, true)


## 前の切りかえで入れた見本のシフトを消す（まだ「いま」のシフトが残っていると、仕事場から出られない）
func _clear_shifts() -> void:
	for s in Shifts.all().duplicate():
		if String(s.get("id", "")).begins_with(PREFIX):
			Shifts.remove(s.id)


## 見本のシフトを 1 件（前の切りかえで入れた分は消す）。start / end は unix 秒
func _put_shift(start: float, end: float) -> Dictionary:
	_clear_shifts()
	var job := JobListings.demo_pay({"id": PREFIX + str(int(start)), "listing": Invites.SAMPLE_LISTING, "role": "hall", "area": "shibuya", "start": start, "end": end, "line_n": 1, "pay": "weekly"})
	JobListings.localize(job)
	var s := JobListings.as_shift(job)
	Shifts.add(s)
	return s


## 一緒に働いた記録を、デモの前の状態に（前の場面の疲れや残業を持ちこさない）
func _reset_work() -> void:
	WorkTogether.set_speed(1.0, true)
	WorkTogether.reset()


## 昼の時刻に見せる（夜のカードに入らないよう、時計を今日の昼 12 時に）
func _daytime() -> void:
	var now := GameState.now_real() - GameState.clock_offset
	var d := GameState._local(now - GameState.DAY_START_H * 3600.0)
	var noon: float = Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day, "hour": 12, "minute": 0, "second": 0}) - Time.get_time_zone_from_system().get("bias", 0) * 60.0
	GameState.clock_offset = noon - now
	if GameState.phase != "morning":
		GameState.phase = "day"


func _before() -> void:
	_reset_work()
	var now := Time.get_unix_time_from_system()
	_put_shift(now + 3600.0, now + 5 * 3600.0)
	_daytime()
	GameState.save()
	main.go("garden")


func _on_shift() -> void:
	_reset_work()
	var now := Time.get_unix_time_from_system()
	_put_shift(now - 3 * 3600.0, now + 3 * 3600.0)
	WorkTogether.set_speed(FAST)
	main.go("work")


func _finished() -> void:
	_reset_work()
	var now := Time.get_unix_time_from_system()
	# あと 2 秒で終わるシフト：猫がへとへとになったところで終わる（疲れたおつかれさまのカード → 島でひとこと評価）
	_put_shift(now - WorkTogether.EXHAUST_HOURS * 3600.0 - 58.0, now + 2.0)
	main.go("work")


func _next_morning() -> void:
	_reset_work()
	_clear_shifts()
	# 次の日付の朝 7 時へ（夜が明けて、玉がかえる）
	var now := GameState.now_real()
	var d := GameState._local(now - GameState.DAY_START_H * 3600.0 + 86400.0)
	var seven: float = Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day, "hour": 7, "minute": 0, "second": 0}) - Time.get_time_zone_from_system().get("bias", 0) * 60.0
	GameState.clock_offset += seven - now
	if GameState.phase == "day":
		GameState.phase = "evening"
	main.go("garden")
