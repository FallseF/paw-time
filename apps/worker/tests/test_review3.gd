extends SceneTree
## ユーザーレビュー3の決まりごと：
##   OBAKE_NOSAVE=1 godot --headless --path . -s tests/test_review3.gd
## 1. 働く条件の画面：まん中（ボタンの上）を指でなぞってもスクロールする。なぞっただけではボタンは押されない
## 2. 重なるシフトは受けられない（同じ町の時刻で重なるものだけ）
## 3. 地域は複数えらべる（どれかに合えばよい）。古い保存（area ひとつ）もそのまま読める
## 4. 呼び名：「おばねこ」「Obaneko」にそろえる。「相棒」「cat-obake」「おばけ猫」は画面の文字に残さない

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _run() -> void:
	TranslationServer.set_locale("en")
	if OS.get_environment("OBAKE_NOSAVE") == "":
		print("run with OBAKE_NOSAVE=1")
		quit(2)
		return
	await _scroll()
	_overlap()
	_areas()
	_naming()
	print("REVIEW3 TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


# ---------------------------------------------------------------- 1. なぞってスクロール

func _mouse(at: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(e, true)


func _move(from: Vector2, to: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = to
	e.global_position = to
	e.relative = to - from
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e, true)


## from から to へ、指でなぞる（数フレームかけて）
func _drag(from: Vector2, to: Vector2) -> void:
	_mouse(from, true)
	await process_frame
	var last := from
	for i in range(1, 9):
		var p := from.lerp(to, i / 8.0)
		_move(last, p)
		last = p
		await process_frame
	_mouse(to, false)
	await process_frame


func _scroll() -> void:
	# 指で触る端末と同じにする（ヘッドレスでは、マウスから指の入力を作る設定で）
	Input.emulate_touch_from_mouse = true
	var s: Control = load("res://scripts/screen_job_prefs.gd").new()
	root.add_child(s)
	await process_frame
	await process_frame
	var sc: ScrollContainer = s.scroll
	# まん中あたりの、押せるもの（週のマス）の上から上へなぞる
	var cell: Button = s.cells["2:day"]
	var at := cell.get_global_rect().get_center()
	_check(at.y > 100 and at.y < 500, "a week cell is in the middle of the screen (%s)" % at)
	var was: Array = s.prefs.slots.duplicate()
	await _drag(at, at - Vector2(0, 220))
	_check(sc.scroll_vertical > 100, "dragging in the middle scrolls (scroll %d)" % sc.scroll_vertical)
	_check(s.prefs.slots == was, "dragging over a cell does not toggle it")
	# なぞらずに押せば、今までどおりボタンが効く
	var chip: Button = s.pay_chips["daily"]
	var c := chip.get_global_rect().get_center()
	_mouse(c, true)
	await process_frame
	_mouse(c, false)
	await process_frame
	_check(s.prefs.pay == "daily", "a plain tap still presses the chip (pay %s)" % s.prefs.pay)
	s.queue_free()
	await process_frame
	Input.emulate_touch_from_mouse = false


# ---------------------------------------------------------------- 2. 重なるシフト

func _overlap() -> void:
	Shifts.reset()
	var t0 := 1790000000.0
	var a := {"id": "a", "title": "Hall", "store": "Cafe", "start": t0, "end": t0 + 4 * 3600, "tz": JobListings.TZ_JP}
	Shifts.add(a)
	var inside := {"id": "b", "start": t0 + 3600, "end": t0 + 2 * 3600, "tz": JobListings.TZ_JP}
	var tail := {"id": "c", "start": t0 + 3 * 3600, "end": t0 + 6 * 3600, "tz": JobListings.TZ_JP}
	var after := {"id": "d", "start": t0 + 4 * 3600, "end": t0 + 6 * 3600, "tz": JobListings.TZ_JP}
	var other_town := {"id": "e", "start": t0 + 3600, "end": t0 + 2 * 3600, "tz": JobListings.TZ_SF}
	var old_save := {"id": "f", "start": t0 - 3600, "end": t0 + 60} # tz の無い古い保存＝日本時間
	_check(Shifts.overlapping(inside).get("id", "") == "a", "a shift inside another overlaps")
	_check(Shifts.overlapping(tail).get("id", "") == "a", "a shift that starts before the other ends overlaps")
	_check(Shifts.overlapping(after).is_empty(), "back-to-back shifts do not overlap")
	_check(Shifts.overlapping(other_town).is_empty(), "only shifts in the same town (tz) are compared")
	_check(Shifts.overlapping(old_save).get("id", "") == "a", "old saves without tz count as Japan time")
	_check(Shifts.overlapping(a).is_empty(), "a shift does not overlap itself")
	Shifts.reset()


# ---------------------------------------------------------------- 3. 地域をいくつも

func _areas() -> void:
	pass


# ---------------------------------------------------------------- 4. 呼び名

func _naming() -> void:
	pass
