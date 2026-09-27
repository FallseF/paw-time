class_name ShopCulture
## お店の島（実績で育つ島）の決まりごと。見た目は screen_shop_island.gd と ShopLandmarks。
## 島を決めるのは、働いた人の評価だけ（Reviews.totals：見本の集計＋プレイヤー自身の評価）。
##   ・評価のタグ（時間どおりに帰れる・休憩がとれる…）ごとに、よい目印がひとつ。タグが集まるほど 3 段まで育つ
##   ・お店の島は、足されるだけ。減る・枯れる・恥をかかせる飾り・店どうしの順位は、いっさい無い
##   ・声が少ないタグは、目印がまだ無い（1〜2 票なら小さな芽）
##   ・お金では目印を買えない。お店が決められるのは、名前の看板・色・「大事にしていること」のひとことだけ
## 段は票の「数」だけで決まる（割合は使わない）。割合だと、ほかのタグの票が増えたときに下がってしまうため。

## [タグ, 目印の id]。文言は SHOP_LM_<ID>（名前）と SHOP_LM_<ID>_BODY（説明）
const LANDMARKS := [
	["on_time", "clock_tower"],
	["breaks", "rest_grove"],
	["instructions", "guide_post"],
	["paid", "payday_bell"],
	["friendly", "lantern_path"],
	["fair", "fair_fountain"],
	["again", "welcome_arch"],
]
## この票数で 1 段・2 段・3 段
const LEVELS := [3, 8, 16]
const SPROUT_MIN := 1

## お店の種類ごとの、看板と日よけの色（お店が選べる見た目。見本）
const KIND_STYLE := {
	"cafe": {"sign": "5fb7a8", "accent": "fdf7ee"},
	"izakaya": {"sign": "c9454a", "accent": "fff1dc"},
	"konbini": {"sign": "4f9bd6", "accent": "f4fbff"},
	"warehouse": {"sign": "e8a23a", "accent": "fff5e0"},
	"bakery": {"sign": "d9894f", "accent": "fff3e3"},
	"supermarket": {"sign": "5fa864", "accent": "f4fff0"},
	"restaurant": {"sign": "e8705b", "accent": "fff5ee"},
	"shop": {"sign": "8b7bff", "accent": "f7f3ff"},
}


## 票の数 → 段（0 = まだ無い、1〜3）。票が増えて下がることはない
static func level_for(votes: int) -> int:
	var lv := 0
	for i in LEVELS.size():
		if votes >= LEVELS[i]:
			lv = i + 1
	return lv


## 島の目印の一覧：[{tag, id, votes, level, sprout}]（LANDMARKS の順）
static func landmarks(listing_id: String) -> Array:
	return landmarks_from(Reviews.totals(listing_id))


static func landmarks_from(totals: Dictionary) -> Array:
	var tags: Dictionary = totals.get("tags", {})
	var out: Array = []
	for lm in LANDMARKS:
		var v := int(tags.get(lm[0], 0))
		var lv := level_for(v)
		out.append({"tag": lm[0], "id": lm[1], "votes": v, "level": lv, "sprout": lv == 0 and v >= SPROUT_MIN})
	return out


## 目印の段の合計（島の広さに使う。これも減らない）
static func total_level(list: Array) -> int:
	var n := 0
	for lm in list:
		n += int(lm.level)
	return n


## 島の地形の段（IslandKit.STAGES の 0〜2）
static func stage_for(list: Array) -> int:
	var t := total_level(list)
	return 0 if t < 6 else (1 if t < 12 else 2)


## お店が決めた見た目（見本）：{name, sign, accent, values}
static func profile(listing_id: String) -> Dictionary:
	var e := JobListings.entry(listing_id)
	var kind: String = e[1] if not e.is_empty() else "shop"
	var st: Dictionary = KIND_STYLE.get(kind, KIND_STYLE.shop)
	return {
		"name": JobListings.store_name(listing_id),
		"kind": kind,
		"sign": Color(st.sign),
		"accent": Color(st.accent),
		"values": I18n.t("SHOP_VALUES_" + kind.to_upper()),
	}


## おでかけの行き先（GameState.visit）。shop があれば、乗り物の場面のあとはお店の島へ
static func visit_data(listing_id: String) -> Dictionary:
	var list := landmarks(listing_id)
	var lvl: int = [0, 4, 8][stage_for(list)] # 乗り物の場面で、行き先の島の地形の段に使う
	return {"shop": listing_id, "name": JobListings.store_name(listing_id), "level": lvl, "expansions": []}


## 「働いたお店」：登録シフトのうち、もう終わったもの（新しい順・店ごとに 1 つ）
static func worked_shops(now := -1.0) -> Array:
	var t := now if now >= 0 else Time.get_unix_time_from_system()
	var out: Array = []
	var all := Shifts.all()
	all.reverse()
	for s in all:
		var id := String(s.get("listing", ""))
		if id == "" or JobListings.entry(id).is_empty() or float(s.get("end", 0)) > t or out.has(id):
			continue
		out.append(id)
	return out
