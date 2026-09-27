class_name Reminders
## 前の晩と当日の朝の、ひとこと（ゲームの中だけ。通知は送らない）。
##   前の晩：あした登録シフトがあれば、相棒が「あした 10:00・カフェ こもれび。また向こうでね！」（島の夜・夜のおわりの画面）
##   当日の朝：まだ始まっていないきょうのシフトがあれば、やさしく「9:30 に出る？」のカード（島の朝・昼）
## 休んでも何も減らない。連続の記録もつけない。日付と時刻は見本の求人と同じ町の時刻（日本語＝日本時間、英語＝サンフランシスコ）。

const LEAVE_BEFORE := 30 * 60 # 出発の目安：始まる 30 分前


## いまの時刻（確認用に OBAKE_NOW=unix 秒 で決められる）
static func now() -> float:
	var e := OS.get_environment("OBAKE_NOW")
	return float(e) if e != "" else Time.get_unix_time_from_system()


static func _day0(t: float) -> int:
	return JobListings.day0(t)


## あした（見本の町の暦の上で）始まるシフトのうち、いちばん早いもの。無ければ空
static func evening(t := -1.0) -> Dictionary:
	var n := t if t >= 0 else now()
	var d1 := _day0(n) + 86400
	for s in Shifts.upcoming(n):
		if float(s.start) >= d1 and float(s.start) < d1 + 86400:
			return s
	return {}


## きょう（見本の町の暦）これから始まるシフトのうち、いちばん早いもの。無ければ空
static func morning(t := -1.0) -> Dictionary:
	var n := t if t >= 0 else now()
	var d0 := _day0(n)
	for s in Shifts.upcoming(n):
		if float(s.start) < d0 + 86400:
			return s
	return {}


static func clock(unix: float) -> String:
	var d := JobListings.local(unix)
	return "%d:%02d" % [d.hour, d.minute]


static func store_of(s: Dictionary) -> String:
	return String(s.get("store", s.get("title", "")))


## 前の晩のひとこと：[見出し, 小さな文]
static func evening_text(s: Dictionary) -> Array:
	return [I18n.t("REMIND_EVE_TITLE") % [clock(s.start), store_of(s)], I18n.t("REMIND_EVE_SUB")]


## 当日の朝のひとこと：[見出し, 小さな文]
static func morning_text(s: Dictionary) -> Array:
	return [I18n.t("REMIND_AM_TITLE") % clock(float(s.start) - LEAVE_BEFORE), I18n.t("REMIND_AM_SUB") % [store_of(s), clock(s.start), clock(s.end)]]


## 夜のおわりの画面に、相棒と吹き出しを置く（あしたのシフトがなければ何もしない）
static func attach_night(parent: Control, y := 300.0) -> Control:
	var s := evening()
	if s.is_empty():
		return null
	var tx := evening_text(s)
	var row := Control.new()
	row.position = Vector2(14, y)
	row.size = Vector2(332, 96)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cat := PartnerStage.new(Vector2(88, 96))
	row.add_child(cat)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.95), 18, 0.2, Vector2(12, 8)))
	p.position = Vector2(88, 10)
	p.size = Vector2(244, 0)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.custom_minimum_size = Vector2(220, 0)
	p.add_child(v)
	v.add_child(Kit.text(SpecialObake.pet_name(), 11, Color("8a5bd6"), true))
	v.add_child(I18n.wrap(Kit.text(tx[0], 15, Color("2a2233"), true)))
	v.add_child(I18n.wrap(Kit.text(tx[1], 13, Color("6a5f70"), true)))
	row.add_child(p)
	parent.add_child(row)
	cat.talk.call_deferred()
	return row


## 確認用：あした（eve）／きょう（am）の 10:00〜14:00 に、見本のお店のシフトを 1 件入れる
static func demo_shift(kind: String) -> void:
	var d0 := _day0(now()) + (86400 if kind == "eve" else 0)
	var job := JobListings.demo_pay({"id": "demo_remind_" + kind, "listing": Invites.SAMPLE_LISTING, "role": "hall", "area": "", "start": JobListings.at_hour(d0, 10), "end": JobListings.at_hour(d0, 14), "line_n": 1, "pay": "weekly"})
	JobListings.localize(job)
	Shifts.add(JobListings.as_shift(job))
