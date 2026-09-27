class_name Shifts
## 受けたバイト（シフト）の共通の置き場。
## 仕事探し（job_board）が add() し、一緒に働く（work_together）が upcoming()/current() を読む。
## 1件: {id, title, place, role(register|dish|hall|kitchen|stock), start, end(unixtime), wage(時給・円), pay("daily"|"weekly"|"monthly")}
## 保存は user://shifts.json。

const PATH := "user://shifts.json"

static var _loaded := false
static var _list: Array = []


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if OS.get_environment("OBAKE_NOSAVE") != "" or not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Array:
		_list = d


static func _save() -> void:
	if OS.get_environment("OBAKE_NOSAVE") != "":
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_list))


## 読み出しは写し。見本の求人から受けたシフトは、店の名前・仕事・場所を今の言語で入れ直す
## （英語で受けたシフトの名前が、日本語の画面に英語のまま出ないように。保存の中身は変えない）
static func all() -> Array:
	_ensure()
	return _list.map(func(x): return _local(x))


static func _local(s: Dictionary) -> Dictionary:
	var c: Dictionary = s.duplicate(true)
	var lid := String(c.get("listing", ""))
	if c.get("manual", false) or lid == "" or JobListings.entry(lid).is_empty():
		return c
	c["store"] = JobListings.store_name(lid)
	if c.has("role"):
		c["title"] = I18n.t("JOB_TITLE_" + String(c.role).to_upper())
	c["place"] = I18n.t("JOB_PLACE") % [c.store, JobPrefs.area_label(String(c.area))] if c.has("area") else c.store
	return c


static func add(s: Dictionary) -> void:
	_ensure()
	if not s.has("id"):
		s["id"] = str(Time.get_unix_time_from_system()) + str(randi() % 1000)
	_list.append(s)
	_list.sort_custom(func(a, b): return a.start < b.start)
	_save()


static func remove(id: String) -> void:
	_ensure()
	_list = _list.filter(func(s): return s.id != id)
	_save()


## s と時間の重なる、入っているシフト（無ければ空）。同じ町の時刻（tz）のシフトだけを比べる。
## 前のシフトの終わりちょうどに始まるのは重ならない。tz の無い古い保存は日本時間
static func overlapping(s: Dictionary) -> Dictionary:
	_ensure()
	var tz := JobListings.tz_of(s)
	for x in _list:
		if String(x.get("id", "")) == String(s.get("id", "")) or JobListings.tz_of(x) != tz:
			continue
		if float(x.start) < float(s.end) and float(s.start) < float(x.end):
			return _local(x)
	return {}


## now 以降に始まるシフト（近い順）
static func upcoming(now := -1.0) -> Array:
	_ensure()
	var t := now if now >= 0 else Time.get_unix_time_from_system()
	return _list.filter(func(s): return s.start >= t).map(func(x): return _local(x))


## いま勤務中のシフト（無ければ空）
static func current(now := -1.0) -> Dictionary:
	_ensure()
	var t := now if now >= 0 else Time.get_unix_time_from_system()
	for s in _list:
		if s.start <= t and t < s.end:
			return _local(s)
	return {}


static func reset() -> void:
	_loaded = true
	_list = []
	_save()
