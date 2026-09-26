class_name JobPrefs
## 働く条件（プレイヤーが入力する希望）。user://job_prefs.json に置く（ゲーム本体のセーブとは別）。
## 口座・カード番号など、お金の受け取りの本物の情報は、聞かないし持たない。受け取り方の「希望」（日払い・週払い・月払い）だけ。
## 形: {area, days: [0..6（0=月）], windows: ["morning"|"day"|"evening"|"night"], min_wage: 円/時, pay: "daily"|"weekly"|"monthly"|"any"}

const PATH := "user://job_prefs.json"

## 時間帯（JST の時。night は 22 時〜翌 5 時 = 29 時）
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
const WAGE_MIN := 1000
const WAGE_MAX := 2000

## テストで本物に触れないよう差し替えられる
static var path := PATH


static func defaults() -> Dictionary:
	return {"area": "", "days": [0, 1, 2, 3, 4, 5, 6], "windows": ["day", "evening"], "min_wage": 1200, "pay": "any"}


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
	d.area = String(p.get("area", "")).strip_edges().left(40)
	var days: Array = []
	for x in p.get("days", []):
		var i := int(x)
		if i >= 0 and i <= 6 and not days.has(i):
			days.append(i)
	days.sort()
	d.days = days
	var wins: Array = []
	for w in WINDOW_ORDER:
		if w in p.get("windows", []):
			wins.append(w)
	d.windows = wins
	d.min_wage = clampi(int(p.get("min_wage", 1200)), WAGE_MIN, WAGE_MAX)
	var pay := String(p.get("pay", "any"))
	d.pay = pay if pay in PAYS else "any"
	return d


## 地域の表示名（候補の ID なら翻訳、自由入力ならそのまま）。空なら「近く」
static func area_label(area: String) -> String:
	if area == "":
		return I18n.t("JOB_AREA_NEARBY")
	if area in AREAS:
		return I18n.t("JOB_AREA_" + area.to_upper())
	return area
