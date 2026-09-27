class_name JobPrefs
## 働く条件（プレイヤーが入力する希望）。user://job_prefs.json に置く（ゲーム本体のセーブとは別）。
## 口座・カード番号など、お金の受け取りの本物の情報は、聞かないし持たない。受け取り方の「希望」（日払い・週払い・月払い）だけ。
## 形: {areas: [地域, …]（いくつでも。どれかに合えばよい）, area（areas の先頭。古い読み方のため）, slots: ["<曜日>:<時間帯>", …]（週のマス。曜日 0=月、時間帯 morning|day|evening|night）, days, windows, min_wage: 円/時, min_wage_usd: ドル/時（英語＝SF の見本）, pay: "daily"|"weekly"|"monthly"|"any", suggest: bool}
## 受け取り方の id は日本も SF も同じ。英語の画面では daily＝Instant pay、monthly＝Biweekly と読む（JOB_PAY_*）
## days と windows は slots から作る（どの曜日・どの時間帯が一つでもあるか）。slots の無い古い保存は days × windows を slots にする
## suggest＝相棒が毎日の求人を知らせるか（Off なら毎日の求人カードは出さない。自分で入れたシフトと評価はそのまま）

const PATH := "user://job_prefs.json"

## 時間帯（見本の町の時刻。night は 22 時〜翌 5 時 = 29 時）
const WINDOWS := {
	"morning": [6, 12],
	"day": [11, 17],
	"evening": [17, 22],
	"night": [22, 29],
}
const WINDOW_ORDER := ["morning", "day", "evening", "night"]
const PAYS := ["daily", "weekly", "monthly"]
## 候補の地域（自由入力もできる）。表示名は JOB_AREA_<ID>
const AREAS := ["shibuya", "shinjuku", "ikebukuro", "kichijoji", "yokohama", "umeda"]
## 英語（サンフランシスコ）の地区。表示名は JOB_AREA_<ID>。はじめの 6 つを候補のチップに出す
const AREAS_SF := ["mission", "soma", "north_beach", "sunset", "richmond", "hayes_valley", "castro", "chinatown", "dogpatch",
	"bayview", "noe_valley", "haight", "marina", "japantown"]
const MAX_AREAS := 8
const WAGE_MIN := 1000
const WAGE_MAX := 2000
const WAGE_MIN_USD := 20.0
const WAGE_MAX_USD := 28.0
const WAGE_STEP_USD := 0.5

## テストで本物に触れないよう差し替えられる
static var path := PATH


static func defaults() -> Dictionary:
	var d := {"area": "", "areas": [], "days": [0, 1, 2, 3, 4, 5, 6], "windows": ["day", "evening"], "min_wage": 1200, "min_wage_usd": 21.0, "pay": "any", "suggest": true}
	d["slots"] = grid(d.days, d.windows)
	return d


## 曜日 × 時間帯のマスを全部（古い形の保存の読み替えにも使う）
static func grid(days: Array, windows: Array) -> Array:
	var out: Array = []
	for i in days:
		for w in WINDOW_ORDER:
			if w in windows:
				out.append("%d:%s" % [int(i), w])
	return out


## その曜日（0=月）に選んだ時間帯（マスが一つも無ければ、どれでも）
static func windows_on(prefs: Dictionary, weekday: int) -> Array:
	if prefs.get("slots", []).is_empty():
		return WINDOW_ORDER.duplicate()
	var out: Array = []
	for w in WINDOW_ORDER:
		if ("%d:%s" % [weekday, w]) in prefs.get("slots", []):
			out.append(w)
	return out


static func exists() -> bool:
	return FileAccess.file_exists(path)


static func load_prefs() -> Dictionary:
	var d := defaults()
	if not FileAccess.file_exists(path):
		return d
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return d
	for k in d:
		if parsed.has(k):
			d[k] = parsed[k]
	return normalize(d)


static func save_prefs(p: Dictionary) -> bool:
	var d := normalize(p)
	d["saved_at"] = int(Time.get_unix_time_from_system())
	if OS.get_environment("OBAKE_NOSAVE") != "":
		return true
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("JobPrefs: 保存できない %s" % path)
		return false
	f.store_string(JSON.stringify(d, "\t"))
	return true


## 型と範囲をそろえる（JSON の数値は float で戻るため）
static func normalize(p: Dictionary) -> Dictionary:
	var d := defaults()
	# 地域：いくつでも（MAX_AREAS まで）。areas の無い古い保存は area ひとつを読む
	var src_areas: Array = p.areas if p.get("areas", null) is Array and not p.areas.is_empty() else [p.get("area", "")]
	var areas: Array = []
	for a in src_areas:
		var t := String(a).strip_edges().left(40)
		if t != "" and not areas.has(t) and areas.size() < MAX_AREAS:
			areas.append(t)
	d.areas = areas
	d.area = areas[0] if not areas.is_empty() else ""
	var src: Array = []
	if p.get("slots", null) is Array:
		src = p.slots
	else:
		src = grid(p.get("days", []).map(func(x): return int(x)), p.get("windows", []))
	var slots: Array = []
	var days: Array = []
	var wins: Array = []
	for x in src:
		var parts := String(x).split(":")
		if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1] in WINDOW_ORDER:
			continue
		var i := int(parts[0])
		if i < 0 or i > 6:
			continue
		var key := "%d:%s" % [i, parts[1]]
		if not slots.has(key):
			slots.append(key)
		if not days.has(i):
			days.append(i)
		if not wins.has(parts[1]):
			wins.append(parts[1])
	days.sort()
	d.slots = grid(days, WINDOW_ORDER).filter(func(k): return slots.has(k))
	d.days = days
	d.windows = WINDOW_ORDER.filter(func(w): return wins.has(w))
	d.min_wage = clampi(int(p.get("min_wage", 1200)), WAGE_MIN, WAGE_MAX)
	d.min_wage_usd = clampf(snappedf(float(p.get("min_wage_usd", 21.0)), 0.25), WAGE_MIN_USD, WAGE_MAX_USD)
	var pay := String(p.get("pay", "any"))
	d.pay = pay if pay in PAYS else "any"
	d.suggest = bool(p.get("suggest", true))
	return d


## その通貨での最低時給（JPY＝min_wage、USD＝min_wage_usd）
static func min_wage_in(p: Dictionary, currency: String) -> float:
	if currency == Money.USD:
		return float(p.get("min_wage_usd", 21.0))
	return float(p.get("min_wage", 1200))


## 今の言語の町の地区の候補
static func areas() -> Array:
	return AREAS_SF if Kit.is_en() else AREAS


## 毎日の求人の知らせを出すか
static func suggest_on() -> bool:
	return bool(load_prefs().suggest)


## 地域の表示名（候補の ID なら翻訳、自由入力ならそのまま）。空なら「近く」
static func area_label(area: String) -> String:
	if area == "":
		return I18n.t("JOB_AREA_NEARBY")
	if area in AREAS or area in AREAS_SF:
		return I18n.t("JOB_AREA_" + area.to_upper())
	return area
