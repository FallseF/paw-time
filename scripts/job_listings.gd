class_name JobListings
## 仕事さがしの見本の求人（MOCK）。本物の求人ではない。画面には「見本の求人」と小さく出す。
## 64 件の店（カフェ・居酒屋・コンビニ・倉庫・パン屋・スーパー・飲食店・そのほか）から、
## プレイヤーの条件（JobPrefs：地域・曜日・時間帯・最低時給・受け取り方）に合うものだけを選んで、日付と時刻を付ける。
## 1 件: {id, listing, role, title, place, area, start, end（unix 秒）, wage（円/時）, pay, line, sample: true}
## 時刻は日本時間（JST, UTC+9）で決める（見本の求人は日本の店なので、端末のタイムゾーンに左右されない）。

const JST := 9 * 3600
const ROLES := ["register", "dish", "hall", "kitchen", "stock"]

## 店の名前は i18n/strings.csv の JOB_STORE_<ID>（store_name）。
## [id, 種類, 仕事, 時給の下, 時給の上, 受け取り方(d日/w週/m月), 時間帯(M朝/D昼/E夕/N夜), 1回の時間]
const LIST := [
	# カフェ
	["cafe_komorebi", "cafe", ["register", "hall", "dish"], 1150, 1350, "wm", "MD", 4],
	["cafe_sunnyside", "cafe", ["register", "kitchen"], 1180, 1400, "m", "MD", 5],
	["cafe_mori", "cafe", ["hall", "dish"], 1150, 1300, "wm", "DE", 4],
	["cafe_tsuki", "cafe", ["hall", "kitchen"], 1200, 1450, "m", "EN", 5],
	["cafe_nekomimi", "cafe", ["register", "hall"], 1170, 1300, "dwm", "DE", 4],
	["cafe_harbor", "cafe", ["register", "dish"], 1200, 1380, "m", "MD", 4],
	["cafe_hoshizora", "cafe", ["hall", "kitchen"], 1160, 1320, "wm", "DE", 5],
	["cafe_matcha", "cafe", ["register"], 1200, 1400, "dw", "MD", 4],
	["cafe_beanbag", "cafe", ["register", "stock"], 1250, 1450, "m", "MD", 6],
	["cafe_fuwari", "cafe", ["kitchen", "hall", "dish"], 1180, 1400, "wm", "DE", 5],
	# 居酒屋
	["izk_torimaru", "izakaya", ["hall", "dish", "kitchen"], 1250, 1550, "dwm", "EN", 5],
	["izk_chochin", "izakaya", ["hall", "dish"], 1230, 1500, "wm", "EN", 5],
	["izk_kemuri", "izakaya", ["kitchen", "hall"], 1300, 1600, "m", "EN", 5],
	["izk_hanabi", "izakaya", ["kitchen", "register"], 1250, 1450, "d", "EN", 4],
	["izk_daruma", "izakaya", ["hall", "kitchen", "dish"], 1240, 1500, "wm", "EN", 5],
	["izk_minato", "izakaya", ["hall", "dish"], 1260, 1520, "dw", "EN", 5],
	["izk_hinoki", "izakaya", ["kitchen", "dish"], 1300, 1650, "m", "EN", 6],
	["izk_tanuki", "izakaya", ["hall", "register"], 1230, 1480, "wm", "E", 4],
	# コンビニ
	["cvs_hoshi", "konbini", ["register", "stock"], 1180, 1480, "wm", "MDEN", 5],
	["cvs_machikado", "konbini", ["register", "stock"], 1170, 1450, "m", "MDEN", 5],
	["cvs_kurumi", "konbini", ["register"], 1180, 1400, "wm", "MDE", 4],
	["cvs_tsuki24", "konbini", ["register", "stock"], 1200, 1550, "dw", "EN", 6],
	["cvs_asahi", "konbini", ["register", "stock"], 1170, 1420, "m", "MD", 4],
	["cvs_pocket", "konbini", ["stock"], 1200, 1500, "dwm", "N", 6],
	["cvs_sakura", "konbini", ["register"], 1170, 1380, "wm", "DE", 5],
	# 倉庫・物流
	["wh_kita", "warehouse", ["stock"], 1300, 1700, "dw", "DEN", 6],
	["wh_minato", "warehouse", ["stock"], 1320, 1750, "dwm", "DN", 8],
	["wh_shiori", "warehouse", ["stock"], 1250, 1500, "wm", "MD", 6],
	["wh_hayate", "warehouse", ["stock"], 1350, 1800, "d", "MN", 6],
	["wh_tsubame", "warehouse", ["stock"], 1300, 1700, "dw", "EN", 5],
	["wh_nuno", "warehouse", ["stock"], 1250, 1450, "wm", "D", 6],
	["wh_omocha", "warehouse", ["stock"], 1260, 1500, "dwm", "DE", 5],
	# パン屋
	["bk_komugi", "bakery", ["register", "kitchen"], 1170, 1380, "wm", "M", 5],
	["bk_mori", "bakery", ["register", "kitchen"], 1160, 1350, "m", "MD", 5],
	["bk_melon", "bakery", ["kitchen"], 1200, 1420, "dw", "M", 4],
	["bk_tsukiakari", "bakery", ["register", "kitchen"], 1180, 1400, "wm", "MD", 5],
	["bk_koguma", "bakery", ["register"], 1160, 1300, "m", "MD", 4],
	["bk_tomato", "bakery", ["kitchen", "register"], 1170, 1380, "dwm", "M", 4],
	# スーパー・ドラッグストア
	["sm_maruya", "supermarket", ["register", "stock"], 1170, 1450, "wm", "MDE", 5],
	["sm_midori", "supermarket", ["register", "stock"], 1160, 1350, "d", "MD", 4],
	["sm_kaede", "supermarket", ["stock", "register"], 1180, 1480, "m", "DEN", 5],
	["sm_tane", "supermarket", ["register"], 1200, 1400, "wm", "D", 5],
	["sm_hakka", "supermarket", ["register", "stock"], 1200, 1500, "m", "DE", 5],
	# 飲食店
	["rs_nikoniko", "restaurant", ["hall", "kitchen", "dish"], 1200, 1550, "wm", "MDEN", 5],
	["rs_yuge", "restaurant", ["kitchen", "hall"], 1250, 1550, "dw", "DEN", 5],
	["rs_tsurutsuru", "restaurant", ["kitchen", "register"], 1180, 1400, "wm", "D", 4],
	["rs_umi", "restaurant", ["hall", "dish", "kitchen"], 1200, 1500, "m", "DE", 5],
	["rs_hoshi", "restaurant", ["kitchen", "hall"], 1180, 1420, "dwm", "DE", 4],
	["rs_hanamaru", "restaurant", ["kitchen", "dish"], 1220, 1480, "wm", "E", 5],
	["rs_teppan", "restaurant", ["hall", "kitchen"], 1200, 1450, "m", "DE", 5],
	["rs_kiri", "restaurant", ["hall", "dish"], 1170, 1380, "wm", "D", 4],
	["rs_tamago", "restaurant", ["kitchen", "hall"], 1190, 1420, "d", "DE", 4],
	# そのほか
	["ot_shioridou", "shop", ["register", "stock"], 1170, 1350, "m", "DE", 5],
	["ot_tsukikage", "shop", ["register", "hall"], 1180, 1450, "wm", "DEN", 5],
	["ot_utaya", "shop", ["hall", "kitchen"], 1250, 1600, "dwm", "EN", 5],
	["ot_hotel", "shop", ["hall", "dish"], 1250, 1500, "wm", "M", 4],
	["ot_ohisama", "shop", ["kitchen", "register"], 1170, 1380, "d", "MD", 4],
	["ot_yuki", "shop", ["register"], 1180, 1350, "dw", "DE", 4],
	["ot_hanahana", "shop", ["register", "stock"], 1170, 1350, "m", "MD", 5],
	["ot_mimi", "shop", ["kitchen", "register"], 1180, 1400, "wm", "DE", 4],
	["ot_pon", "shop", ["register", "kitchen"], 1170, 1380, "dw", "DE", 4],
	["ot_wa", "shop", ["register", "kitchen"], 1170, 1400, "m", "MD", 5],
	["ot_enpitsu", "shop", ["register", "stock"], 1160, 1320, "wm", "D", 5],
	["ot_awa", "shop", ["register", "dish"], 1170, 1380, "dwm", "MDE", 4],
]

const PAY_CODE := {"d": "daily", "w": "weekly", "m": "monthly"}
const WIN_CODE := {"M": "morning", "D": "day", "E": "evening", "N": "night"}


static func count() -> int:
	return LIST.size()


static func entry(listing_id: String) -> Array:
	for e in LIST:
		if e[0] == listing_id:
			return e
	return []


static func pays_of(e: Array) -> Array:
	var out: Array = []
	for c in String(e[5]):
		out.append(PAY_CODE[c])
	return out


static func windows_of(e: Array) -> Array:
	var out: Array = []
	for c in String(e[6]):
		out.append(WIN_CODE[c])
	return out


## その店が条件に合うか（日付を付ける前の、店そのものの条件：時給・受け取り方・時間帯）
static func listing_fits(e: Array, prefs: Dictionary) -> bool:
	if int(e[4]) < int(prefs.min_wage):
		return false
	if prefs.pay != "any" and not pays_of(e).has(prefs.pay):
		return false
	if prefs.windows.is_empty():
		return true
	for w in windows_of(e):
		if w in prefs.windows:
			return true
	return false


## 条件に合う仕事を count 件つくる（足りなければ、ある分だけ）。
## base は「いま」の unix 秒（翌日から 7 日のうちの、選べる曜日に入れる）。seed で毎日の顔ぶれを変える。
static func generate(prefs_in: Dictionary, count_n: int, seed_n: int, base := -1.0) -> Array:
	var prefs := JobPrefs.normalize(prefs_in)
	var now := base if base >= 0 else Time.get_unix_time_from_system()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var pool: Array = LIST.filter(func(e): return listing_fits(e, prefs))
	# 並びを seed で混ぜる
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var dates := _open_dates(now, prefs.days)
	var out: Array = []
	if dates.is_empty():
		return out
	for e in pool:
		if out.size() >= count_n:
			break
		# 週のマス：その店の時間帯が、その曜日に選んだ時間帯と重なる日だけ
		var ok_dates: Array = dates.filter(func(d0): return windows_of(e).any(func(w): return w in JobPrefs.windows_on(prefs, weekday_mon(d0))))
		if ok_dates.is_empty():
			continue
		out.append(_make_job(e, prefs, ok_dates[rng.randi_range(0, ok_dates.size() - 1)], rng))
	out.sort_custom(func(a, b): return a.start < b.start)
	return out


## 翌日から 7 日のうち、選んだ曜日の日付（JST のその日の 0 時の unix 秒）
static func _open_dates(now: float, days: Array) -> Array:
	var today0 := int(floor((now + JST) / 86400.0)) * 86400 - JST
	var out: Array = []
	for i in range(1, 8):
		var d0 := today0 + i * 86400
		if days.is_empty() or days.has(weekday_mon(d0)):
			out.append(d0)
	return out


## 月曜 = 0 … 日曜 = 6（JST）
static func weekday_mon(unix: float) -> int:
	var wd: int = Time.get_datetime_dict_from_unix_time(int(unix) + JST).weekday # 0 = 日曜
	return (wd + 6) % 7


static func _make_job(e: Array, prefs: Dictionary, day0: int, rng: RandomNumberGenerator) -> Dictionary:
	var allowed: Array = JobPrefs.windows_on(prefs, weekday_mon(day0))
	var wins: Array = windows_of(e).filter(func(w): return allowed.is_empty() or w in allowed)
	var win: String = wins[rng.randi_range(0, wins.size() - 1)]
	var span: Array = JobPrefs.WINDOWS[win]
	var hours: int = mini(int(e[7]), span[1] - span[0])
	# 始まりはその日のうち（23 時台まで）。深夜の仕事は、選んだ曜日の夜に始まって翌朝に終わる
	var start_h: int = rng.randi_range(span[0], mini(span[1] - hours, 23))
	var roles: Array = e[2]
	var role: String = roles[rng.randi_range(0, roles.size() - 1)]
	var lo: int = maxi(int(e[3]), int(prefs.min_wage))
	var wage: int = int(round(rng.randi_range(lo, int(e[4])) / 10.0)) * 10
	wage = clampi(wage, lo, int(e[4]))
	# 夜（22 時〜）は深夜の割増つき（25%）。表示の時給にそのまま入れる
	if win == "night":
		wage = int(round(wage * 1.25 / 10.0)) * 10
	var pays: Array = pays_of(e)
	var pay: String = prefs.pay if prefs.pay != "any" else pays[rng.randi_range(0, pays.size() - 1)]
	var start := day0 + start_h * 3600
	var job := {
		"id": "%s_%d_%d" % [e[0], start, rng.randi() % 1000],
		"listing": e[0],
		"role": role,
		"area": prefs.area,
		"window": win,
		"start": start,
		"end": start + hours * 3600,
		"wage": wage,
		"pay": pay,
		"line_n": rng.randi_range(1, 3),
		"sample": true,
	}
	localize(job)
	return job


## 今の言語で title / place / line を入れる（受けたあとも Shifts にこの形で入る）
static func localize(job: Dictionary) -> Dictionary:
	var e := entry(job.listing)
	var store: String = store_name(job.listing) if not e.is_empty() else job.listing
	job["store"] = store
	job["title"] = I18n.t("JOB_TITLE_" + String(job.role).to_upper())
	job["place"] = I18n.t("JOB_PLACE") % [store, JobPrefs.area_label(job.area)]
	job["line"] = I18n.t("JOB_LINE_%s_%d" % [String(job.role).to_upper(), int(job.get("line_n", 1))])
	return job


static func store_name(listing_id: String) -> String:
	return I18n.t("JOB_STORE_" + listing_id.to_upper())


## 表示用：「Tue 9/30 · 17:00–21:00」
static func when_text(job: Dictionary) -> String:
	var s := Time.get_datetime_dict_from_unix_time(int(job.start) + JST)
	var e := Time.get_datetime_dict_from_unix_time(int(job.end) + JST)
	var wd := I18n.t("JOB_WD_%d" % weekday_mon(job.start))
	return I18n.t("JOB_WHEN") % [wd, s.month, s.day, s.hour, s.minute, e.hour, e.minute]


static func wage_text(job: Dictionary) -> String:
	return I18n.t("JOB_WAGE") % _commas(int(job.wage))


static func _commas(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out
