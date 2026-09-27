class_name Invites
## 「また来てほしいな」のおさそい。働いたお店をよく評価したら（星 4 以上）、そのお店からおさそいが届く（見本）。
## デモでは、見本のお店からも 1 件届く（seed_sample）。相棒が持ってきて、毎日の求人カードのいちばん前に「おさそい」の印で並ぶ。
## 受けたら、ふつうの求人カードと同じく Shifts.add() とカレンダー。断っても何も起きない（罰なし・連続記録なし）。
## 1 件は求人と同じ形（JobListings）に {invited: true} を足したもの。保存は user://invites.json。

const PATH := "user://invites.json"
const MIN_STARS := 4
const SAMPLE_LISTING := "cafe_komorebi"
const MAX_OPEN := 3

static var _loaded := false
static var _list: Array = []
static var _decided := {}
static var _seeded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if OS.get_environment("OBAKE_NOSAVE") != "" or not FileAccess.file_exists(PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if d is Dictionary:
		_list = d.get("invites", [])
		_decided = d.get("decided", {})
		_seeded = bool(d.get("seeded", false))


static func _save() -> void:
	if OS.get_environment("OBAKE_NOSAVE") != "":
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"invites": _list, "decided": _decided, "seeded": _seeded}))


static func all() -> Array:
	_ensure()
	return _list.duplicate(true)


## そのお店からのおさそい（1〜7 日後。土曜があれば土曜）。見本の求人と同じ作り方で、日付だけ決める
static func make(listing_id: String, now := -1.0) -> Dictionary:
	var e := JobListings.entry(listing_id)
	if e.is_empty():
		return {}
	var t := now if now >= 0 else Time.get_unix_time_from_system()
	var today0 := int(floor((t + JobListings.JST) / 86400.0)) * 86400 - JobListings.JST
	var day0 := today0 + 86400
	for i in range(1, 8):
		if JobListings.weekday_mon(today0 + i * 86400) == 5:
			day0 = today0 + i * 86400
			break
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s/%d" % [listing_id, day0])
	var prefs := JobPrefs.load_prefs().duplicate()
	prefs.windows = []
	prefs.days = []
	prefs.pay = "any"
	prefs.min_wage = int(e[3])
	var job: Dictionary = JobListings._make_job(e, JobPrefs.normalize(prefs), day0, rng)
	job.id = "inv_%s_%d" % [listing_id, day0]
	job["invited"] = true
	return job


## 評価を送ったあと（JobDesk）。よい評価なら、そのお店からおさそいが 1 件届く
static func after_review(shift: Dictionary, stars: int, now := -1.0) -> Dictionary:
	_ensure()
	var id := String(shift.get("listing", ""))
	if stars < MIN_STARS or id == "":
		return {}
	return _add(make(id, now), now)


## デモ用：見本のお店から、はじめの 1 件（一度だけ）
static func seed_sample(now := -1.0) -> void:
	_ensure()
	if _seeded:
		return
	_seeded = true
	_add(make(SAMPLE_LISTING, now), now)
	_save()


static func _add(inv: Dictionary, now := -1.0) -> Dictionary:
	if inv.is_empty() or pending(now).size() >= MAX_OPEN:
		return {}
	for x in _list:
		if x.id == inv.id:
			return {}
	_list.append(inv)
	_save()
	return inv


## まだ決めていない、これからのおさそい（近い順）
static func pending(now := -1.0) -> Array:
	_ensure()
	var t := now if now >= 0 else Time.get_unix_time_from_system()
	var out: Array = _list.filter(func(x): return not _decided.has(x.id) and float(x.start) > t)
	out.sort_custom(func(a, b): return a.start < b.start)
	for x in out:
		JobListings.localize(x)
	return out


static func is_invite(job: Dictionary) -> bool:
	return bool(job.get("invited", false))


## 受ける：ふつうの求人カードと同じ形で Shifts に入れる（一緒に働く係と共有する約束）
static func accept(inv: Dictionary) -> Dictionary:
	_ensure()
	var s := {"id": inv.id, "title": inv.title, "place": inv.place, "store": inv.store, "role": inv.role, "start": inv.start, "end": inv.end,
		"wage": inv.wage, "pay": inv.pay, "listing": inv.listing, "sample": true, "invited": true}
	Shifts.add(s)
	_decided[inv.id] = "accept"
	_save()
	return s


static func decline(inv: Dictionary) -> void:
	_ensure()
	_decided[inv.id] = "pass"
	_save()


static func reset() -> void:
	_loaded = true
	_list = []
	_decided = {}
	_seeded = false
	_save()
