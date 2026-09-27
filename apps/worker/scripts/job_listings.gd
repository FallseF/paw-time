class_name JobListings
## 仕事さがしの見本の求人（MOCK）。本物の求人ではない。画面には「見本の求人」と小さく出す。
## 64 件の店（カフェ・居酒屋・コンビニ・倉庫・パン屋・スーパー・飲食店・そのほか）から、
## プレイヤーの条件（JobPrefs：地域・曜日・時間帯・最低時給・受け取り方）に合うものだけを選んで、日付と時刻を付ける。
## 1 件: {id, listing, role, title, place, area, start, end（unix 秒）, wage, currency, tz, pay, line, sample: true}
## 言語で見本の町が変わる：日本語＝日本（円・日本時間 Asia/Tokyo）、英語＝サンフランシスコ（US ドル・America/Los_Angeles）。
## 店の id は同じ（テレメトリーの shop_id・保存・お店の島がそのまま使える）。名前・地区・時給・受け取り方の呼び名だけが変わる。
## 時刻はその町の時刻で決める（端末のタイムゾーンに左右されない）。currency / tz の無い古い保存は JPY・日本時間。

const JST := 9 * 3600
const TZ_JP := "Asia/Tokyo"
const TZ_SF := "America/Los_Angeles"
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

## 英語＝サンフランシスコの見本（同じ店の id に、SF の店名・地区・US ドルの時給・受け取り方をあてる）。
## 店名は i18n/strings.csv の JOB_STORE_<ID> の英語。Recruit の見え方（insights の SF_SHOPS）と同じ 10 店を含む。
## [地区, 昼の時給の下, 上（USD/時）, 受け取り方（d 即日払い Instant pay / w 週払い / m 隔週払い Biweekly。英語の画面では JOB_PAY_* がそう読める）]。夕方・夜は +SF_EVENING_PLUS。
## SF の最低賃金は $19.61/時（2026-07-01 から、sf.gov。insights 側で確認済み）。どの求人もこれを下回らない。
const SF_MIN_WAGE := 19.61
const SF_EVENING_PLUS := 1.5
const SF := {
	# カフェ
	"cafe_komorebi": ["soma", 21.0, 23.0, "wm"], # Sunlit Pages Bookstore Café
	"cafe_sunnyside": ["mission", 21.0, 22.5, "dm"], # Sunnyside Boba
	"cafe_mori": ["sunset", 21.0, 22.75, "wm"],
	"cafe_tsuki": ["hayes_valley", 21.5, 23.5, "m"],
	"cafe_nekomimi": ["haight", 21.0, 22.5, "dwm"],
	"cafe_harbor": ["marina", 21.5, 23.25, "m"],
	"cafe_hoshizora": ["castro", 21.0, 22.75, "wm"],
	"cafe_matcha": ["richmond", 21.25, 23.0, "dw"],
	"cafe_beanbag": ["dogpatch", 21.75, 23.75, "m"],
	"cafe_fuwari": ["noe_valley", 21.0, 23.0, "wm"],
	# 居酒屋 → SF の居酒屋・タケリア・パブ
	"izk_torimaru": ["mission", 21.5, 24.0, "dwm"], # La Brasita Taqueria
	"izk_chochin": ["north_beach", 21.5, 23.75, "wm"], # Paper Lantern Izakaya Bar
	"izk_kemuri": ["soma", 22.0, 24.5, "m"], # Ember Izakaya
	"izk_hanabi": ["richmond", 21.5, 23.5, "d"],
	"izk_daruma": ["japantown", 21.5, 23.75, "wm"],
	"izk_minato": ["dogpatch", 21.75, 24.0, "dw"],
	"izk_hinoki": ["hayes_valley", 22.0, 24.5, "m"],
	"izk_tanuki": ["castro", 21.5, 23.5, "wm"],
	# コンビニ → コーナーマーケット
	"cvs_hoshi": ["soma", 21.0, 23.5, "wm"], # Starlight Corner Market
	"cvs_machikado": ["mission", 21.0, 23.25, "m"], # 24th Street Market
	"cvs_kurumi": ["noe_valley", 21.0, 22.75, "wm"],
	"cvs_tsuki24": ["soma", 21.5, 24.0, "dw"],
	"cvs_asahi": ["sunset", 21.0, 22.75, "m"],
	"cvs_pocket": ["haight", 21.5, 23.75, "dwm"],
	"cvs_sakura": ["japantown", 21.0, 22.5, "wm"],
	# 倉庫・物流
	"wh_kita": ["bayview", 22.5, 24.5, "dw"],
	"wh_minato": ["dogpatch", 22.75, 24.5, "dwm"],
	"wh_shiori": ["soma", 22.0, 23.5, "wm"],
	"wh_hayate": ["bayview", 23.0, 24.5, "d"],
	"wh_tsubame": ["dogpatch", 22.5, 24.25, "dw"],
	"wh_nuno": ["soma", 22.0, 23.25, "wm"],
	"wh_omocha": ["bayview", 22.0, 23.5, "dwm"],
	# パン屋
	"bk_komugi": ["north_beach", 21.0, 23.0, "wm"], # Wheatfield Bakery
	"bk_mori": ["richmond", 21.0, 22.75, "m"],
	"bk_melon": ["chinatown", 21.25, 23.0, "dw"],
	"bk_tsukiakari": ["hayes_valley", 21.0, 23.0, "wm"],
	"bk_koguma": ["sunset", 21.0, 22.5, "m"],
	"bk_tomato": ["marina", 21.0, 23.0, "dwm"],
	# スーパー・ドラッグストア
	"sm_maruya": ["north_beach", 21.0, 23.5, "wm"], # Columbus Avenue Grocery
	"sm_midori": ["mission", 21.0, 22.75, "d"],
	"sm_kaede": ["richmond", 21.25, 23.75, "m"],
	"sm_tane": ["haight", 21.5, 23.25, "wm"],
	"sm_hakka": ["castro", 21.5, 24.0, "m"],
	# 飲食店
	"rs_nikoniko": ["mission", 21.0, 23.75, "wm"], # Smiley's Diner
	"rs_yuge": ["japantown", 21.5, 23.75, "dw"],
	"rs_tsurutsuru": ["sunset", 21.0, 22.75, "wm"],
	"rs_umi": ["marina", 21.25, 23.5, "m"],
	"rs_hoshi": ["soma", 21.0, 23.0, "dwm"],
	"rs_hanamaru": ["chinatown", 21.25, 23.25, "wm"],
	"rs_teppan": ["north_beach", 21.0, 23.25, "m"],
	"rs_kiri": ["hayes_valley", 21.0, 22.75, "wm"],
	"rs_tamago": ["noe_valley", 21.0, 23.0, "d"],
	# そのほか
	"ot_shioridou": ["mission", 21.0, 22.75, "m"],
	"ot_tsukikage": ["castro", 21.0, 23.25, "wm"],
	"ot_utaya": ["japantown", 21.5, 24.0, "dwm"],
	"ot_hotel": ["soma", 21.5, 23.5, "wm"],
	"ot_ohisama": ["richmond", 21.0, 22.75, "d"],
	"ot_yuki": ["north_beach", 21.0, 22.5, "dw"],
	"ot_hanahana": ["noe_valley", 21.0, 22.75, "m"],
	"ot_mimi": ["haight", 21.0, 23.0, "wm"],
	"ot_pon": ["sunset", 21.0, 22.75, "dw"],
	"ot_wa": ["richmond", 21.0, 23.0, "m"],
	"ot_enpitsu": ["chinatown", 21.0, 22.5, "wm"],
	"ot_awa": ["mission", 21.0, 22.75, "dwm"],
}

const PAY_CODE := {"d": "daily", "w": "weekly", "m": "monthly"}
const WIN_CODE := {"M": "morning", "D": "day", "E": "evening", "N": "night"}


static func count() -> int:
	return LIST.size()


# ---------------------------------------------------------------- 町（言語で決まる）と時刻

## "sf"（英語）か "jp"（日本語）
static func region() -> String:
	return "sf" if Kit.is_en() else "jp"


static func _reg(r: String) -> String:
	return r if r in ["sf", "jp"] else region()


static func tz_of_region(r := "") -> String:
	return TZ_SF if _reg(r) == "sf" else TZ_JP


static func currency_of_region(r := "") -> String:
	return Money.USD if _reg(r) == "sf" else Money.JPY


## シフト・求人の時刻の町（無ければ日本時間：この欄ができる前の保存）
static func tz_of(d: Dictionary) -> String:
	return TZ_SF if String(d.get("tz", TZ_JP)) == TZ_SF else TZ_JP


## その時刻の UTC からのずれ（秒）。tz が空なら今の言語の町。
## America/Los_Angeles：3 月の第 2 日曜 2:00（PST）〜 11 月の第 1 日曜 2:00（PDT）は夏時間（UTC-7）、ほかは UTC-8
static func tz_offset(unix: float, tz := "") -> int:
	var z := tz if tz != "" else tz_of_region()
	if z != TZ_SF:
		return JST
	var y: int = Time.get_datetime_dict_from_unix_time(int(unix) - 8 * 3600).year
	var start := _nth_sunday(y, 3, 2) + 2 * 3600 + 8 * 3600 # 2:00 PST
	var end := _nth_sunday(y, 11, 1) + 2 * 3600 + 7 * 3600 # 2:00 PDT
	return -7 * 3600 if unix >= start and unix < end else -8 * 3600


## その年・月の第 n 日曜の 0 時（UTC の暦で。unix 秒）
static func _nth_sunday(y: int, month: int, n: int) -> int:
	var first := int(Time.get_unix_time_from_datetime_dict({"year": y, "month": month, "day": 1, "hour": 0, "minute": 0, "second": 0}))
	var wd: int = Time.get_datetime_dict_from_unix_time(first).weekday # 0 = 日曜
	return first + ((7 - wd) % 7 + (n - 1) * 7) * 86400


## その町の暦・時刻（year, month, day, hour, minute, weekday…）
static func local(unix: float, tz := "") -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(int(unix) + tz_offset(unix, tz))


## その町の、その日の 0 時（unix 秒）
static func day0(unix: float, tz := "") -> int:
	var o := tz_offset(unix, tz)
	var d := int(floor((unix + o) / 86400.0)) * 86400 - o
	return d + (o - tz_offset(d, tz)) # 夏時間の切りかわる日も、その日の 0 時に


## d0 から n 日あとの 0 時（夏時間の切りかわりをまたいでも暦の 0 時）
static func next_day0(d0: int, n: int, tz := "") -> int:
	return day0(d0 + n * 86400 + 12 * 3600, tz)


## その日（d0）の h 時（24 時以上は翌日）
static func at_hour(d0: int, h: float, tz := "") -> int:
	var t := d0 + int(h * 3600)
	return t + (tz_offset(d0, tz) - tz_offset(t, tz))


## テレメトリーの props に足す shop_id（見本の店の id だけ。自分で入れた場所などは付けない）
static func telemetry_shop(listing_id, props := {}) -> Dictionary:
	var p: Dictionary = props.duplicate()
	if typeof(listing_id) == TYPE_STRING and not entry(listing_id).is_empty():
		p["shop_id"] = listing_id
	return p


static func entry(listing_id: String) -> Array:
	for e in LIST:
		if e[0] == listing_id:
			return e
	return []


static func pays_of(e: Array, r := "") -> Array:
	var out: Array = []
	var codes := String(e[5])
	if _reg(r) == "sf" and SF.has(e[0]):
		codes = String(SF[e[0]][3])
	for c in codes:
		out.append(PAY_CODE[c])
	return out


static func windows_of(e: Array) -> Array:
	var out: Array = []
	for c in String(e[6]):
		out.append(WIN_CODE[c])
	return out


## その町での昼の時給の [下, 上]（円なら int、ドルなら float）
static func wage_range(e: Array, r := "") -> Array:
	if _reg(r) == "sf" and SF.has(e[0]):
		return [float(SF[e[0]][1]), float(SF[e[0]][2])]
	return [int(e[3]), int(e[4])]


## その店が条件に合うか（日付を付ける前の、店そのものの条件：時給・受け取り方・時間帯）
static func listing_fits(e: Array, prefs: Dictionary, r := "") -> bool:
	if float(wage_range(e, r)[1]) < JobPrefs.min_wage_in(prefs, currency_of_region(r)):
		return false
	if prefs.pay != "any" and not pays_of(e, r).has(prefs.pay):
		return false
	if prefs.windows.is_empty():
		return true
	for w in windows_of(e):
		if w in prefs.windows:
			return true
	return false


## 条件に合う仕事を count 件つくる（足りなければ、ある分だけ）。
## base は「いま」の unix 秒（翌日から 7 日のうちの、選べる曜日に入れる）。seed で毎日の顔ぶれを変える。
## region：""（今の言語の町）/ "jp" / "sf"
static func generate(prefs_in: Dictionary, count_n: int, seed_n: int, base := -1.0, r := "") -> Array:
	var reg := _reg(r)
	var tz := tz_of_region(reg)
	var prefs := JobPrefs.normalize(prefs_in)
	var now := base if base >= 0 else Time.get_unix_time_from_system()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var pool: Array = LIST.filter(func(e): return listing_fits(e, prefs, reg))
	# 並びを seed で混ぜる
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	# SF：選んだ地区（どれか）の店を先に（ほかの地区の店も出す）
	var picked: Array = prefs.areas.filter(func(a): return a in JobPrefs.AREAS_SF)
	if reg == "sf" and not picked.is_empty():
		pool = pool.filter(func(e): return SF[e[0]][0] in picked) + pool.filter(func(e): return not SF[e[0]][0] in picked)
	var dates := _open_dates(now, prefs.days, tz)
	var out: Array = []
	if dates.is_empty():
		return out
	for e in pool:
		if out.size() >= count_n:
			break
		# 週のマス：その店の時間帯が、その曜日に選んだ時間帯と重なる日だけ
		var ok_dates: Array = dates.filter(func(d0): return windows_of(e).any(func(w): return w in JobPrefs.windows_on(prefs, weekday_mon(d0, tz))))
		if ok_dates.is_empty():
			continue
		out.append(_make_job(e, prefs, ok_dates[rng.randi_range(0, ok_dates.size() - 1)], rng, reg))
	out.sort_custom(func(a, b): return a.start < b.start)
	return out


## そのお店の、いまの募集（お店の島で見せる。翌日から 7 日のうちの n 日、その日に 1 件）。
## 働く人の条件では絞らない（お店の事実）。地域は日本なら自分の地域、SF ならその店の地区。seed で毎日の顔ぶれを変える
static func shop_openings(listing_id: String, n: int, seed_n: int, base := -1.0, r := "") -> Array:
	var e := entry(listing_id)
	if e.is_empty():
		return []
	var reg := _reg(r)
	var tz := tz_of_region(reg)
	var mine := JobPrefs.load_prefs()
	var prefs := JobPrefs.normalize({"areas": mine.areas, "slots": JobPrefs.grid(range(7), JobPrefs.WINDOW_ORDER), "min_wage": JobPrefs.WAGE_MIN, "min_wage_usd": JobPrefs.WAGE_MIN_USD, "pay": "any"})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_n
	var dates := _open_dates(base if base >= 0 else Time.get_unix_time_from_system(), [], tz)
	var out: Array = []
	while out.size() < n and not dates.is_empty():
		var d0: int = dates.pop_at(rng.randi_range(0, dates.size() - 1))
		out.append(_make_job(e, prefs, d0, rng, reg))
	out.sort_custom(func(a, b): return a.start < b.start)
	return out


## 翌日から 7 日のうち、選んだ曜日の日付（その町のその日の 0 時の unix 秒）
static func _open_dates(now: float, days: Array, tz := "") -> Array:
	var today0 := day0(now, tz)
	var out: Array = []
	for i in range(1, 8):
		var d0 := next_day0(today0, i, tz)
		if days.is_empty() or days.has(weekday_mon(d0, tz)):
			out.append(d0)
	return out


## 月曜 = 0 … 日曜 = 6（その町の暦。tz が空なら今の言語の町）
static func weekday_mon(unix: float, tz := "") -> int:
	var wd: int = local(unix, tz).weekday # 0 = 日曜
	return (wd + 6) % 7


static func _make_job(e: Array, prefs: Dictionary, day0_t: int, rng: RandomNumberGenerator, r := "") -> Dictionary:
	var reg := _reg(r)
	var tz := tz_of_region(reg)
	var allowed: Array = JobPrefs.windows_on(prefs, weekday_mon(day0_t, tz))
	var wins: Array = windows_of(e).filter(func(w): return allowed.is_empty() or w in allowed)
	var win: String = wins[rng.randi_range(0, wins.size() - 1)]
	var span: Array = JobPrefs.WINDOWS[win]
	var hours: int = mini(int(e[7]), span[1] - span[0])
	# 始まりはその日のうち（23 時台まで）。深夜の仕事は、選んだ曜日の夜に始まって翌朝に終わる
	var start_h: int = rng.randi_range(span[0], mini(span[1] - hours, 23))
	var roles: Array = e[2]
	var role: String = roles[rng.randi_range(0, roles.size() - 1)]
	var wage = 0
	if reg == "sf":
		# SF：昼の時給＋夕方・夜は SF_EVENING_PLUS。25 セント刻み。最低賃金（SF_MIN_WAGE）を下回らない
		var plus := SF_EVENING_PLUS if win in ["evening", "night"] else 0.0
		var rg := wage_range(e, reg)
		var hi: float = rg[1] + plus
		var lo_f := maxf(maxf(rg[0] + plus, JobPrefs.min_wage_in(prefs, Money.USD)), SF_MIN_WAGE)
		var w := snappedf(rng.randf_range(lo_f, hi), 0.25)
		if w < lo_f:
			w = ceilf(lo_f * 4.0) / 4.0
		wage = clampf(w, lo_f, maxf(lo_f, hi))
	else:
		var lo: int = maxi(int(e[3]), int(prefs.min_wage))
		var wj: int = int(round(rng.randi_range(lo, int(e[4])) / 10.0)) * 10
		wj = clampi(wj, lo, int(e[4]))
		# 夜（22 時〜）は深夜の割増つき（25%）。表示の時給にそのまま入れる
		if win == "night":
			wj = int(round(wj * 1.25 / 10.0)) * 10
		wage = wj
	var pays: Array = pays_of(e, reg)
	var pay: String = prefs.pay if prefs.pay != "any" else pays[rng.randi_range(0, pays.size() - 1)]
	var start := at_hour(day0_t, start_h, tz)
	# 日本：えらんだ地域のどれか（ひとつなら、今までどおり乱数を使わない）
	var area := String(prefs.area)
	if prefs.areas.size() > 1:
		area = String(prefs.areas[rng.randi_range(0, prefs.areas.size() - 1)])
	var job := {
		"id": "%s_%d_%d" % [e[0], start, rng.randi() % 1000],
		"listing": e[0],
		"role": role,
		"area": String(SF[e[0]][0]) if reg == "sf" and SF.has(e[0]) else area,
		"window": win,
		"start": start,
		"end": start + hours * 3600,
		"wage": wage,
		"currency": currency_of_region(reg),
		"tz": tz,
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


## Google マップの検索 URL（お店の名前と地域）。住所は見本なので、名前で探す
static func maps_url(job: Dictionary) -> String:
	var q := String(job.get("store", job.get("place", "")))
	var area := String(job.get("area", ""))
	if area != "" or job.has("listing"):
		q += " " + JobPrefs.area_label(area)
	if tz_of(job) == TZ_SF:
		q += " San Francisco"
	return "https://www.google.com/maps/search/?api=1&query=" + q.strip_edges().uri_encode()


static func store_name(listing_id: String) -> String:
	return I18n.t("JOB_STORE_" + listing_id.to_upper())


## 表示用：「Tue 9/30 · 17:00–21:00」（そのシフトの町の時刻）
static func when_text(job: Dictionary) -> String:
	var tz := tz_of(job)
	var s := local(job.start, tz)
	var e := local(job.end, tz)
	var wd := I18n.t("JOB_WD_%d" % weekday_mon(job.start, tz))
	return I18n.t("JOB_WHEN") % [wd, s.month, s.day, s.hour, s.minute, e.hour, e.minute]


## 時給の表示（そのシフトの通貨で。Money を通す）
static func wage_text(job: Dictionary) -> String:
	return Money.wage_of(job)


## 見本のシフトを Shifts の形に（通貨と町の時刻も持たせる）
static func as_shift(j: Dictionary) -> Dictionary:
	return {"id": j.id, "title": j.get("title", ""), "place": j.get("place", ""), "store": j.get("store", ""), "role": j.get("role", "hall"), "area": j.get("area", ""),
		"start": j.start, "end": j.end, "wage": j.get("wage", 0), "pay": j.get("pay", "weekly"), "listing": j.get("listing", ""),
		"sample": true, "currency": Money.of(j), "tz": tz_of(j)}


## 確認用・デモの見本のシフトに入れる時給と、通貨・町・地区（今の言語の町）
static func demo_pay(job: Dictionary, r := "") -> Dictionary:
	var reg := _reg(r)
	job["wage"] = 22.5 if reg == "sf" else 1250
	job["currency"] = currency_of_region(reg)
	job["tz"] = tz_of_region(reg)
	if reg == "sf" and SF.has(String(job.get("listing", ""))):
		job["area"] = SF[job.listing][0]
	return job


static func _commas(n: int) -> String:
	return Money.commas(n)
