class_name Reviews
## 働いたあとの、職場のひとこと評価（10 秒）。星 1〜5 と、当てはまるタグだけ。
## 保存は user://reviews.json。{"reviews": {shift_id: {listing, stars, tags, t}}, "skipped": [shift_id]}
## 求人カードの「働いた人の声」は、見本の集計（MOCK、店ごとに決まった値）に、プレイヤー自身の評価を足したもの。
## 書くとポイ（すくいの網）が 1 本もらえる（働いた時間とは無関係）。

const PATH := "user://reviews.json"
const TAGS := ["breaks", "instructions", "on_time", "paid", "friendly", "fair", "again"] # 文言は REVIEW_TAG_<大文字>
const BONUS_POI := 1

static var path := PATH
static var _loaded := false
static var _reviews := {}
static var _skipped: Array = []


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if OS.get_environment("OBAKE_NOSAVE") != "" or not FileAccess.file_exists(path):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if d is Dictionary:
		_reviews = d.get("reviews", {})
		_skipped = d.get("skipped", [])


static func _save() -> void:
	if OS.get_environment("OBAKE_NOSAVE") != "":
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"reviews": _reviews, "skipped": _skipped}))


static func is_reviewed(shift_id: String) -> bool:
	_ensure()
	return _reviews.has(shift_id) or _skipped.has(shift_id)


## 終わったのに、まだ評価していないシフト（古い順）
static func pending(now := -1.0) -> Array:
	var t := now if now >= 0 else Time.get_unix_time_from_system()
	return Shifts.all().filter(func(s): return float(s.get("end", 0)) <= t and not is_reviewed(String(s.id)))


static func add(shift: Dictionary, stars: int, tags: Array) -> void:
	_ensure()
	var clean: Array = tags.filter(func(x): return x in TAGS)
	_reviews[String(shift.id)] = {"listing": shift.get("listing", ""), "stars": clampi(stars, 1, 5), "tags": clean, "t": int(Time.get_unix_time_from_system())}
	_save()


static func skip(shift: Dictionary) -> void:
	_ensure()
	if not _skipped.has(String(shift.id)):
		_skipped.append(String(shift.id))
	_save()


static func reset() -> void:
	_loaded = true
	_reviews = {}
	_skipped = []
	_save()


## 店ごとの見本の集計（MOCK）。店の ID から決まるので、毎回同じ値になる
static func mock_base(listing_id: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(listing_id)
	var n := rng.randi_range(6, 38)
	var avg := rng.randf_range(3.6, 4.8)
	var tags := {}
	for tg in TAGS:
		tags[tg] = int(n * rng.randf_range(0.15, 0.85))
	return {"count": n, "sum": avg * n, "tags": tags}


## 求人カードに出す声：{stars, count, tag, tag_count}（tag はいちばん多く付いたもの）
static func summary(listing_id: String) -> Dictionary:
	_ensure()
	var b := mock_base(listing_id)
	var n: int = b.count
	var total: float = b.sum
	var tags: Dictionary = b.tags.duplicate()
	for id in _reviews:
		var r: Dictionary = _reviews[id]
		if r.get("listing", "") != listing_id:
			continue
		n += 1
		total += float(r.stars)
		for tg in r.tags:
			tags[tg] = int(tags.get(tg, 0)) + 1
	var best := ""
	for tg in TAGS:
		if best == "" or int(tags[tg]) > int(tags[best]):
			best = tg
	return {"stars": snappedf(total / maxf(1.0, n), 0.1), "count": n, "tag": best, "tag_count": int(tags[best])}


static func summary_text(listing_id: String) -> String:
	var s := summary(listing_id)
	return I18n.t("REVIEW_SAYS") % [I18n.t("REVIEW_TAG_" + String(s.tag).to_upper()), s.stars, s.count]
