extends SceneTree
## ユーザーレビュー2の、画面を持たない決まりごと：
##   OBAKE_NOSAVE=1 godot --headless --path . -s tests/test_review2.gd
## 1. 帰ったあとの「今日のお給料（目安）」＝ 登録したシフトの時間 × そのシフトの時給（時給の無いシフトは出さない）

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
	_pay()
	print("REVIEW2 TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


# ---------------------------------------------------------------- 1. お給料の目安

func _pay() -> void:
	var t0 := 1790000000.0 # ある日の日中
	var a := {"id": "a", "start": t0, "end": t0 + 5 * 3600, "wage": 1390}
	var b := {"id": "b", "start": t0 + 86400, "end": t0 + 86400 + 4.5 * 3600, "wage": 1200}
	var m := {"id": "m", "start": t0 + 2 * 86400, "end": t0 + 2 * 86400 + 3600, "manual": true}
	var shifts := [a, b, m]
	# 終わった勤務のシフトの時給 × そのシフトの時間（働いた時間の長さではない）
	var e := WorkTogether.pay_estimate({"shift_id": "a", "start": t0 + 60, "hours": 0.02}, shifts)
	_check(e.get("yen", -1) == 6950 and e.get("wage", 0) == 1390 and is_equal_approx(float(e.get("hours", 0)), 5.0), "5h x 1390 = 6950 (%s)" % [e])
	# 半端な時間：4.5h x 1200 = 5400
	e = WorkTogether.pay_estimate({"shift_id": "b", "start": t0 + 86400}, shifts)
	_check(e.get("yen", -1) == 5400, "4.5h x 1200 = 5400 (%s)" % [e])
	# 手で始めた勤務（shift_id なし）でも、同じ日の時給つきのシフトから
	e = WorkTogether.pay_estimate({"shift_id": "", "start": t0 + 1800}, shifts)
	_check(e.get("shift_id", "") == "a" and e.get("yen", -1) == 6950, "manual session uses that day's registered shift (%s)" % [e])
	# 自分で入れたシフト（時給なし）・シフトの無い日は、目安を出さない
	_check(WorkTogether.pay_estimate({"shift_id": "m", "start": t0 + 2 * 86400}, shifts).is_empty(), "no wage, no estimate")
	_check(WorkTogether.pay_estimate({"shift_id": "", "start": t0 + 5 * 86400}, shifts).is_empty(), "no shift that day, no estimate")
	_check(WorkTogether.pay_estimate({"shift_id": "a", "start": t0}, []).is_empty(), "no shifts at all")
