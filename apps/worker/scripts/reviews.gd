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


## 一緒に働いた勤務（WorkTogether.pop_ended）のうち、まだ評価していない登録シフト（Shifts にあるもの）。
## 手動の「仕事に行ってくる」は職場が無いので評価しない
static func target_for_ended(ended: Array) -> Dictionary:
	for e in ended:
		var id := String(e.get("shift_id", ""))
		if id == "" or is_reviewed(id):
			continue
		for sh in Shifts.all():
			if String(sh.id) == id:
				return sh
	return {}


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
	# 店ごとに、声の集まり方をちがえる（お店の島の育ち方が、ひと目でちがって見えるように）。
	# 見本のおさそいの店（cafe_komorebi）は、どのタグも 3 段までそろった島。ほかは目印 2〜3 個の店から、5 個ほどの店まで
	var full := listing_id == "cafe_komorebi"
	var strong: int = TAGS.size() if full else [2, 2, 3, 3, 4, 5][rng.randi() % 6]
	var order := TAGS.duplicate()
	for i in range(order.size() - 1, 0, -1): # 店ごとに決まった順で、目印が立つタグを選ぶ
		var k := rng.randi() % (i + 1)
		var t = order[i]
		order[i] = order[k]
		order[k] = t
	var tags := {}
	for i in order.size():
		if full:
			tags[order[i]] = rng.randi_range(16, 24)
		elif i < strong:
			tags[order[i]] = rng.randi_range(3, 14)
		else:
			tags[order[i]] = rng.randi_range(0, 2) # 目印はまだ（1〜2 票なら芽）
		n = maxi(n, int(tags[order[i]]))
	return {"count": n, "sum": avg * n, "tags": tags}


## 店ごとの合計（見本の集計＋自分の評価）：{count, sum, tags: {tag: 数}}。お店の島（ShopCulture）もこれだけを読む
static func totals(listing_id: String) -> Dictionary:
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
	return {"count": n, "sum": total, "tags": tags}


## 求人カードに出す声：{stars, count, tag, tag_count}（tag はいちばん多く付いたもの）
static func summary(listing_id: String) -> Dictionary:
	var t := totals(listing_id)
	var n: int = t.count
	var total: float = t.sum
	var tags: Dictionary = t.tags
	var best := ""
	for tg in TAGS:
		if best == "" or int(tags[tg]) > int(tags[best]):
			best = tg
	return {"stars": snappedf(total / maxf(1.0, n), 0.1), "count": n, "tag": best, "tag_count": int(tags[best])}


static func summary_text(listing_id: String) -> String:
	var s := summary(listing_id)
	return I18n.t("REVIEW_SAYS") % [I18n.t("REVIEW_TAG_" + String(s.tag).to_upper()), s.stars, s.count]
