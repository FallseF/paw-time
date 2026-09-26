extends Node
## ゲーム全体の状態と決まりごと（Variant B「眠りのリズム」）。
## 通貨は睡眠。いつも同じころに眠り、よく眠ると「リズム」が満ちて、夜の庭が育つ。
## 仕事はブースト：シフトの日は種類つきのポイと、その仕事にちなんだ庭の飾りが届く（時間の長さでは増えない）。
## 記録がなくても（ひとりで遊ぶ）毎日の夜が来る。記録をつなぐと（見本データ）シフトと睡眠が自動で入る。

signal changed
signal goal_completed(text: String, all_done: bool)

const SAVE_PATH := "user://obake_b_save.json"

const SPECIES := {
	"receipt": {"name": "レシートン", "type": "register", "desc": "レジの音に寄ってくる。レシートの尻尾が長いほど長生き"},
	"bubble": {"name": "アワワ", "type": "dish", "desc": "洗い場の泡から生まれる。割れても平気"},
	"tray": {"name": "オボン", "type": "hall", "desc": "頭のお盆は絶対に落とさない"},
	"pan": {"name": "ジュウ", "type": "kitchen", "desc": "油の跳ねる音が好き。少しあつい"},
	"box": {"name": "ダンボ", "type": "stock", "desc": "箱から出たがらない。重いものが得意"},
	"nemuri": {"name": "スヤリ", "type": "sleep", "desc": "夢の中の羊を数えていたら、ついてきた。だいたい寝ている"},
	"lantern": {"name": "チョウチン", "type": "night", "desc": "夜ふかしの灯りに寄ってくる。明るいが、少し眠そう"},
}
const NORMAL := ["receipt", "bubble", "tray", "pan", "box", "nemuri", "lantern"]

const NETS := {
	"plain": {"name": "いつものポイ", "short": "いつもの", "type": "any"},
	"receipt": {"name": "レシートのポイ", "short": "レシート", "type": "register"},
	"bubble": {"name": "泡のポイ", "short": "泡", "type": "dish"},
	"tray": {"name": "お盆のポイ", "short": "お盆", "type": "hall"},
	"pan": {"name": "フライパンのポイ", "short": "フライパン", "type": "kitchen"},
	"box": {"name": "段ボールのポイ", "short": "段ボール", "type": "stock"},
	"kira": {"name": "きらきらポイ", "short": "きらきら", "type": "rare"},
}

const ROLE_LABEL := {"register": "レジ", "dish": "皿洗い", "hall": "ホール", "kitchen": "キッチン", "stock": "品出し"}
const ROLE_NET := {"register": "receipt", "dish": "bubble", "hall": "tray", "kitchen": "pan", "stock": "box"}
const WEEKDAYS := ["月", "火", "水", "木", "金", "土", "日"]

## 仕事ごとに庭へ届く飾り。はじめてその仕事をした日に届き、3回目で少し豪華になる。
const DECOS := {
	"register": {"short": "パラソル", "name": "カフェのパラソル席", "desc": "レジの仕事から。おばけが紅茶を飲むふりをする"},
	"hall": {"short": "ちょうちん", "name": "赤ちょうちん", "desc": "ホールの仕事から。夜の庭がにぎやかになる"},
	"dish": {"short": "たらい", "name": "泡のたらい", "desc": "皿洗いの仕事から。アワワが泳ぐ"},
	"kitchen": {"short": "おでん", "name": "屋台のおでん鍋", "desc": "キッチンの仕事から。湯気がのぼる"},
	"stock": {"short": "秘密基地", "name": "段ボールの秘密基地", "desc": "品出しの仕事から。ダンボが住みつく"},
}

## 庭の育ち。めぐみ（毎朝、リズムと睡眠で溜まる）がこの値をこえると、庭が一段育つ。
const GARDEN := [
	{"need": 0, "name": "さびしい庭", "desc": "土と、灯っていない灯籠がひとつ"},
	{"need": 21, "name": "芝が生えた", "desc": "足もとがやわらかくなった"},
	{"need": 48, "name": "花壇に芽が出た", "desc": "よく眠った朝ほど、まっすぐ伸びる"},
	{"need": 83, "name": "灯籠がともった", "desc": "庭がほんのり明るくなった"},
	{"need": 124, "name": "花が咲いた", "desc": "リズムが整うと、花がひらく"},
	{"need": 172, "name": "小さな池ができた", "desc": "月が映るようになった"},
	{"need": 228, "name": "縁台が置かれた", "desc": "おばけたちが並んで座る"},
	{"need": 293, "name": "桜の木が育った", "desc": "いつ見ても、少しだけ咲いている"},
	{"need": 368, "name": "ほたるが住みついた", "desc": "ぐっすりの夜は、数が増える"},
	{"need": 454, "name": "月見台ができた", "desc": "満月の夜の、特等席"},
	{"need": 552, "name": "夢見の木が光った", "desc": "眠りを大切にした庭にだけ育つ木"},
]

## 見本の1週間（みか、大学2年）。月〜金。土日と2週目以降は記録を生成する。
const WEEK := [
	{"store": "カフェ こもれび", "role": "register", "band": "朝", "hours": 4, "first": false, "weather": "晴", "coworkers": ["さとう", "りん"], "newbie": false},
	{"store": "居酒屋 とりまる", "role": "hall", "band": "夜", "hours": 5, "first": false, "weather": "雨", "coworkers": ["けん", "ようこ"], "newbie": false},
	{"store": "", "role": "", "band": "", "hours": 0, "first": false, "weather": "晴", "coworkers": [], "newbie": false},
	{"store": "居酒屋 とりまる", "role": "dish", "band": "夜", "hours": 4, "first": false, "weather": "晴", "coworkers": ["けん", "みお"], "newbie": true},
	{"store": "北倉庫", "role": "stock", "band": "深夜", "hours": 6, "first": true, "weather": "雷", "coworkers": ["だいち"], "newbie": false},
]
const STORES := [
	{"store": "カフェ こもれび", "roles": ["register", "hall", "dish"], "bands": ["朝", "昼"]},
	{"store": "居酒屋 とりまる", "roles": ["hall", "dish", "kitchen"], "bands": ["夜"]},
	{"store": "北倉庫", "roles": ["stock"], "bands": ["深夜", "昼"]},
	{"store": "ベーカリー こむぎ", "roles": ["register", "kitchen"], "bands": ["朝"]},
	{"store": "スーパー まるや", "roles": ["register", "stock"], "bands": ["昼", "夜"]},
]
const COWORKERS := ["さとう", "りん", "けん", "ようこ", "みお", "だいち", "はる", "ゆい"]

const RARES_PER_NIGHT := 1
const USUAL_DEFAULT := 330 # 23:30（18:00 からの分）
const LATE_LINE := 420
const RHYTHM_RATE := 0.6 # 1晩の点数がリズムに効く割合（良い夜 +15、悪い夜 -12 くらい） # 1:00 より遅いと夜ふかし

var mode := "data" # data = 記録をつなぐ（見本）, solo = ゲームだけ
var seed_base := 0
var day := 0
var phase := "day" # day → evening → (sleep) → 朝の孵化 → day
var nets := {}
var owned: Array = [] # {id, level, xp}
var seen := {}
var orbs: Array = [] # すくった光る玉 {type, rare}。朝に割れておばけになる
var hatched: Array = [] # 今朝割れた玉 {id, is_new, level, rare}
var scooped_tonight := false
var ALL := {}

# 眠りのリズム
var rhythm := 30.0
var bed_hist: Array = [] # 寝た時刻（18:00 からの分）
var sleep_hist: Array = [] # 睡眠時間（時間, float）
var good_hist: Array = [] # よく眠れた夜か（満月の灯りに使う）
var last_night := {} # 朝に見せる、昨夜のまとめ
var dream_pending := false

# 庭
var growth := 0
var garden_level := 0
var garden_seen_level := 0 # 朝の演出で見せ終わった段
var decos := {} # role → 届いた回数
var deco_store := {} # role → 飾りをくれた店
var new_decos: Array = [] # 今日届いた飾り（庭で演出する）
var dream_flowers := 0

# 記録（レアの条件用）
var roles_seen := {}
var stores_week := {}
var coworker_count := {}
var morning_shifts := 0
var bands_week := {}
var first_role_today := false
var shift_done_today := false
var weekend_shifts := {}
var gifted := false
var received := false
var moon_won_today := false
var moon_nights := 0
var rare_pending: Array = []
var tut := {} # チュートリアルの済み印
var total_scooped := 0
var night_plan := "" # "" / extra（もうひと玉）/ market（夜店）
var lit_deco := "" # 今夜ともす飾り（その仕事の玉が出やすい）
var goals: Array = [] # 今日のめあて {id, text, done}
var last_goals := 0
var work_hist: Array = [] # その日に実際に働いたか
var tonight_caught := 0
var moon_won_saved := false


func _ready() -> void:
	for id in SPECIES:
		ALL[id] = SPECIES[id]
	for r in Rares.LIST:
		ALL[r.id] = {"name": r.name, "type": "rare", "desc": r.desc, "hint": r.hint, "group": r.group}
	reset()


func info(id: String) -> Dictionary:
	return ALL.get(id, {"name": id, "type": "", "desc": ""})


func reset(new_mode := "data") -> void:
	mode = new_mode
	seed_base = randi() % 100000
	day = 0
	phase = "day"
	nets = {}
	for id in NETS:
		nets[id] = 0
	nets["plain"] = 3
	owned = [{"id": "receipt", "level": 1, "xp": 0}]
	seen = {"receipt": true}
	orbs = []
	hatched = []
	scooped_tonight = false
	rhythm = 30.0
	bed_hist = []
	sleep_hist = []
	good_hist = []
	last_night = {}
	dream_pending = false
	growth = 0
	garden_level = 0
	garden_seen_level = 0
	decos = {}
	deco_store = {}
	new_decos = []
	dream_flowers = 0
	roles_seen = {}
	stores_week = {}
	coworker_count = {}
	morning_shifts = 0
	bands_week = {}
	first_role_today = false
	shift_done_today = false
	weekend_shifts = {}
	gifted = false
	received = false
	moon_won_today = false
	moon_nights = 0
	rare_pending = []
	tut = {}
	total_scooped = 0
	night_plan = ""
	lit_deco = ""
	work_hist = []
	tonight_caught = 0
	last_goals = 0
	make_goals()
	changed.emit()


# ---------- 日付と記録 ----------

func weekday() -> int:
	return day % 7


func week() -> int:
	return day / 7


func season() -> String:
	var w := week()
	if w < 6:
		return "秋"
	elif w < 12:
		return "冬"
	elif w < 20:
		return "春"
	return "夏"


func is_moon_night() -> bool:
	return weekday() == 6


func day_label() -> String:
	return "%d週目 %s曜日" % [week() + 1, WEEKDAYS[weekday()]]


## その日の記録（シフト・天気）。1週目の月〜金は見本、それ以外は日付から生成する。
func shift_for(d: int) -> Dictionary:
	var wd := d % 7
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base * 7919 + d * 131
	var weather := "晴"
	var r := rng.randf()
	var sea := season()
	if r < 0.2:
		weather = "雨"
	elif r < 0.26:
		weather = "雷"
	elif r < 0.36 and sea == "冬":
		weather = "雪"
	var s := {"store": "", "role": "", "band": "", "hours": 0, "first": false, "weather": weather, "coworkers": [], "newbie": false}
	if d < 5:
		s = WEEK[d].duplicate(true)
	elif mode == "data":
		# 週に3〜4日くらい働く
		var work_p := 0.55 if wd < 5 else 0.4
		if rng.randf() < work_p:
			var st: Dictionary = STORES[rng.randi() % STORES.size()]
			s.store = st.store
			s.role = st.roles[rng.randi() % st.roles.size()]
			s.band = st.bands[rng.randi() % st.bands.size()]
			s.hours = rng.randi_range(3, 6)
			s.first = rng.randf() < 0.08
			var c1: String = COWORKERS[rng.randi() % COWORKERS.size()]
			var c2: String = COWORKERS[rng.randi() % COWORKERS.size()]
			s.coworkers = [c1] if c1 == c2 else [c1, c2]
			s.newbie = rng.randf() < 0.12
	if mode == "solo":
		s.role = ""
		s.store = ""
	s["day"] = WEEKDAYS[wd]
	s["moon"] = "満月" if wd == 6 else ""
	s["season"] = season()
	return s


func today() -> Dictionary:
	return shift_for(day)


## 記録モードのときの「スマホの睡眠記録」。いつもの時刻のまわりに、少しゆらぐ。
func recorded_sleep() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base * 31 + day * 977
	var s := today()
	var bed := USUAL_DEFAULT + int(rng.randfn(0, 15))
	if s.band == "夜":
		bed += 45
	elif s.band == "深夜":
		bed += 150
	if rng.randf() < 0.12:
		bed += 100 # たまの夜ふかし
	bed = int(round(bed / 10.0) * 10)
	var wake := 420 + int(rng.randfn(0, 20))
	if shift_for(day + 1).band == "朝":
		wake = 390
	if s.role == "":
		wake += 40
	wake = int(round(wake / 10.0) * 10)
	return {"bed": clampi(bed, 180, 540), "wake": clampi(wake, 300, 630)}


## 明日の予定から決まる、起きる時刻
func wake_for_tomorrow() -> int:
	var nx := shift_for(day + 1)
	if nx.band == "朝":
		return 390
	if nx.role == "" and (day + 1) % 7 >= 5:
		return 480
	return 420


## ひとりで遊ぶときの、夜の過ごし方。寝る時刻が決まる。
func plan_bed(plan: String) -> int:
	var u := usual_bed()
	match plan:
		"extra":
			return u + 60
		"market":
			return maxi(u + 120, 450)
		"early":
			return u - 30
	return u


# ---------- シフト（ブースト） ----------

## シフトを終えたとき。種類つきのポイ2本と、はじめての仕事なら庭の飾り・きらきらポイ。時間は関係ない。
func finish_shift() -> Array:
	var s := today()
	var got: Array = []
	if s.role == "" or shift_done_today:
		return got
	shift_done_today = true
	first_role_today = not roles_seen.has(s.role)
	roles_seen[s.role] = true
	stores_week[s.store] = true
	bands_week[s.band] = true
	if s.band == "朝":
		morning_shifts += 1
	if weekday() >= 5:
		weekend_shifts[weekday()] = true
	for c in s.coworkers:
		coworker_count[c] = coworker_count.get(c, 0) + 1
	var net_id: String = ROLE_NET[s.role]
	nets[net_id] = mini(nets[net_id] + 2, 4) # 種類つきのポイは4本まで（ためこみすぎない）
	got.append({"kind": "poi", "id": net_id, "n": 2, "text": "%s ×2" % NETS[net_id].name})
	if s.first or first_role_today:
		nets["kira"] += 1
		got.append({"kind": "poi", "id": "kira", "n": 1, "text": "きらきらポイ ×1（はじめての経験）"})
	# 何度も一緒に入った同僚から、おばけをもらうことがある
	if not received:
		for c in s.coworkers:
			if coworker_count.get(c, 0) >= 2:
				received = true
				orbs.append({"type": s.role, "rare": false})
				got.append({"kind": "gift", "id": s.role, "text": "%sから、光る玉をもらった" % c})
				break
	var before: int = decos.get(s.role, 0)
	if before == 0:
		deco_store[s.role] = s.store
	decos[s.role] = before + 1
	if before == 0:
		new_decos.append(s.role)
		got.append({"kind": "deco", "id": s.role, "text": "庭に「%s」が届いた" % DECOS[s.role].name})
	elif before == 2:
		new_decos.append(s.role)
		got.append({"kind": "deco", "id": s.role, "text": "「%s」が少し豪華になった" % DECOS[s.role].name})
	save()
	changed.emit()
	return got


## 今日の同僚に、おばけをおすそわけする（オクリモノの条件）
func can_gift() -> bool:
	return shift_done_today and today().coworkers.size() > 0 and not gifted_today and owned.size() > 1


var gifted_today := false


func gift() -> String:
	gifted = true
	gifted_today = true
	var c: String = today().coworkers[0]
	save()
	return c


func deco_level(role: String) -> int:
	var n: int = decos.get(role, 0)
	return 0 if n == 0 else (1 if n < 3 else 2)


# ---------- リズム ----------

func usual_bed() -> int:
	if bed_hist.is_empty():
		return USUAL_DEFAULT
	var recent: Array = bed_hist.slice(-5)
	var sorted := recent.duplicate()
	sorted.sort()
	return sorted[sorted.size() / 2]


func tier() -> int:
	if rhythm >= 75:
		return 3
	elif rhythm >= 50:
		return 2
	elif rhythm >= 25:
		return 1
	return 0


const TIER_NAME := ["ばらばら", "ゆらゆら", "ととのい", "ぐっすり"]
const TIER_COLOR := [Color("ff8f7a"), Color("ffd36b"), Color("8fe0a0"), Color("9fb4ff")]


func tier_name() -> String:
	return TIER_NAME[tier()]


static func clock(m: int) -> String:
	var t := (m + 18 * 60) % (24 * 60)
	return "%d:%02d" % [t / 60, t % 60]


static func wake_clock(m: int) -> String:
	return "%d:%02d" % [m / 60, m % 60]


static func hours_of(bed: int, wake: int) -> float:
	return (wake + 360 - bed) / 60.0


## その夜の点数（寝る前の予想にも使う）
func night_score(bed: int, wake: int) -> Dictionary:
	var h := hours_of(bed, wake)
	var parts: Array = []
	var score := 0
	if h >= 7.0 and h <= 9.0:
		score += 12
		parts.append(["たっぷり眠る", 12])
	elif h > 9.0:
		score += 5
		parts.append(["寝すぎ", 5])
	elif h >= 6.0:
		score += 3
		parts.append(["少し短い", 3])
	else:
		score -= 12
		parts.append(["睡眠不足", -12])
	var diff: int = absi(bed - usual_bed())
	if bed_hist.is_empty():
		score += 4
		parts.append(["はじめての夜", 4])
	elif diff <= 20:
		score += 10
		parts.append(["いつもの時刻", 10])
	elif diff <= 45:
		score += 3
		parts.append(["いつもの時刻に近い", 3])
	else:
		score -= 8
		parts.append(["時刻がずれた", -8])
	if bed > LATE_LINE:
		score -= 6
		parts.append(["夜ふかし", -6])
	if not shift_done_today and h >= 7.0:
		score += 4
		parts.append(["休みの日の休息", 4])
	return {"score": score, "hours": h, "parts": parts, "late": bed > LATE_LINE, "good": score >= 14}


func growth_gain(score: int, h: float) -> int:
	var g: int = 3 + int(rhythm / 100.0 * 8.0) + maxi(0, score) / 4
	if h < 6.0:
		g = maxi(3, g - 3)
	return g


# ---------- すくい ----------

func use_net(net_id: String) -> bool:
	if nets.get(net_id, 0) <= 0:
		return false
	nets[net_id] -= 1
	changed.emit()
	return true


func add_obake(species_id: String) -> bool:
	var is_new := not seen.has(species_id)
	seen[species_id] = true
	for o in owned:
		if o.id == species_id:
			o.xp += 20
			_level_up(o)
			changed.emit()
			return is_new
	owned.append({"id": species_id, "level": 1, "xp": 0})
	changed.emit()
	return is_new


func _level_up(o: Dictionary) -> bool:
	var up := false
	while o.xp >= 30 * o.level:
		o.xp -= 30 * o.level
		o.level += 1
		up = true
	return up


const TYPE_SPECIES := {"register": "receipt", "dish": "bubble", "hall": "tray", "kitchen": "pan", "stock": "box", "sleep": "nemuri", "night": "lantern", "rare": "kirari"}
const TYPE_COLOR := {"register": Color("ffc23d"), "dish": Color("5fc4ff"), "hall": Color("a98bff"), "kitchen": Color("ff7a45"), "stock": Color("e8b878"), "rare": Color("fff2a8"), "any": Color("f4f1ea"), "sleep": Color("c9bdf5"), "night": Color("ff9a4d")}


func species_for_type(t: String) -> String:
	return TYPE_SPECIES.get(t, "receipt")


## ポイの破れにくさ（リズムで決まる）
func poi_strength() -> float:
	return [0.9, 1.0, 1.15, 1.3][tier()]


## 今夜の水面に出る玉。今日の仕事の種類が多めに出る。リズムが整うと、虹の玉が混ざりやすい。
func tonight_orbs() -> Array:
	var s: Dictionary = today()
	var types := ["register", "dish", "hall", "kitchen", "stock"]
	var out: Array = []
	var n := randi_range(4, 5)
	var rare_p: float = [0.04, 0.07, 0.11, 0.16][tier()] + (0.15 if s.get("first", false) else 0.0)
	for i in n:
		var t: String = types.pick_random()
		if s.get("role", "") != "" and randf() < 0.45:
			t = s.role
		elif lit_deco != "" and randf() < 0.4:
			t = lit_deco
		var rare: bool = randf() < rare_p
		out.append({"type": "rare" if rare else t, "rare": rare, "weight": 0.5 if rare else randf_range(0.22, 0.34)})
	return out


## 眠りのレアの「きざし」。あと少しで会えそうなものを一行で
func omen() -> String:
	if not seen.has("asayake"):
		var n := 0
		for i in range(sleep_hist.size() - 1, -1, -1):
			if sleep_hist[i] < 7.0:
				break
			n += 1
		if n >= 1 and n < 3:
			return "よく眠る夜が %d つ続いている。朝焼けの色が近い" % n
	if not seen.has("totonou") and bed_hist.size() >= 2:
		if absi(bed_hist[-1] - bed_hist[-2]) <= 20:
			return "同じ時刻に眠る夜が続いている。鈴の音がする"
	if not seen.has("hirunen") and shift_for(day).role == "":
		return "今日は休み。たっぷり眠ると、日だまりの匂いがするかも"
	if not seen.has("mangetsu") and sleep_hist.size() >= 7:
		return "ひと月の眠り：%d / 28 夜" % sleep_hist.size()
	return ""


# ---------- 今日のめあて ----------

const GOAL_TEXT := {
	"scoop3": "玉を3個すくう",
	"talk": "庭のおばけに話しかける",
	"usual": "いつもの時刻（±20分）に寝る",
	"hours7": "7時間以上眠る",
	"light": "飾りをひとつともす",
	"match": "仕事のポイで、同じ色の玉をすくう",
	"zukan": "図鑑でヒントを見る",
	"early_ok": "0時までに寝る",
}


func make_goals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base * 13 + day * 71
	var sleep_goal: String = ["usual", "hours7", "early_ok"][rng.randi() % 3]
	if bed_hist.is_empty():
		sleep_goal = "hours7"
	var pool := ["scoop3", "talk", "zukan"]
	if not decos.is_empty() and weekday() != 6:
		pool.append("light")
	var typed := false
	for k in ["receipt", "bubble", "tray", "pan", "box"]:
		if nets.get(k, 0) > 0:
			typed = true
	if typed or today().role != "":
		pool.append("match")
	var picks: Array = []
	while picks.size() < 2:
		var g: String = pool[rng.randi() % pool.size()]
		if not picks.has(g):
			picks.append(g)
	goals = []
	for g in picks + [sleep_goal]:
		goals.append({"id": g, "text": GOAL_TEXT[g], "done": false})


func _recalc_level() -> void:
	while garden_level + 1 < GARDEN.size() and growth >= GARDEN[garden_level + 1].need:
		garden_level += 1


## めあてを達成したら、めぐみ +3。3つそろうと、きらきらポイ +1
func goal(id: String) -> void:
	for g in goals:
		if g.id == id and not g.done:
			g.done = true
			growth += 3
			_recalc_level()
			var all := goals.all(func(x): return x.done)
			if all:
				nets["kira"] += 1
			goal_completed.emit(g.text, all)
			changed.emit()
			return


func goals_done() -> int:
	return goals.filter(func(x): return x.done).size()


# ---------- 眠る ----------

## 眠る。リズム・庭の育ち・夜の訪問者・レア・玉の孵化をまとめて決める。
func sleep(bed: int, wake: int) -> void:
	var ns := night_score(bed, wake)
	var h: float = ns.hours
	var hours := int(round(h))
	var s: Dictionary = today()
	var rhythm_before := rhythm
	rhythm = clampf(rhythm + ns.score * RHYTHM_RATE, 0.0, 100.0)
	var gain := growth_gain(ns.score, h)
	var level_before := garden_level
	growth += gain
	while garden_level + 1 < GARDEN.size() and growth >= GARDEN[garden_level + 1].need:
		garden_level += 1
	var diff_usual: int = absi(bed - usual_bed())
	if not bed_hist.is_empty() and diff_usual <= 20:
		goal("usual")
	if h >= 7.0:
		goal("hours7")
	if bed <= 360:
		goal("early_ok")
	last_goals = goals_done()
	bed_hist.append(bed)
	sleep_hist.append(h)
	good_hist.append(ns.good)
	last_night = {"bed": bed, "wake": wake, "hours": h, "score": ns.score, "parts": ns.parts, "rhythm_before": rhythm_before, "rhythm": rhythm, "growth_gain": gain, "level_before": level_before, "late": ns.late, "visitor": ""}
	hatched = []
	# 夜ふかしの夜は、夜のおばけが寄ってくる（リズムと引きかえ）
	if ns.late:
		orbs.append({"type": "night", "rare": false})
		last_night.visitor = "lantern"
	# 夢：リズムが整っていて、よく眠った夜
	dream_pending = h >= 7.0 and (tier() >= 3 or (tier() >= 2 and randf() < 0.6))
	# 条件を満たしたレアが生まれる
	var have := seen.duplicate()
	for rid in rare_pending:
		have[rid] = true
	var fresh: Array = Rares.check(rare_context(s, h, bed), have)
	rare_pending = fresh + rare_pending
	for i in min(RARES_PER_NIGHT, rare_pending.size()):
		var rid: String = rare_pending.pop_front()
		add_obake(rid)
		hatched.append({"id": rid, "is_new": true, "level": 1, "rare": true})
	_hatch_orbs(h)
	work_hist.append(shift_done_today)
	gifted_today = false
	scooped_tonight = false
	tonight_caught = 0
	night_plan = ""
	shift_done_today = false
	moon_won_today = false
	day += 1
	if weekday() == 0:
		stores_week = {}
		bands_week = {}
		weekend_shifts = {}
	# 毎日のいつものポイ（使い残しは持ち越し、最大5本）
	nets["plain"] = mini(5, nets["plain"] + 3)
	make_goals()
	phase = "morning"
	save()
	changed.emit()


func _hatch_orbs(h: float) -> void:
	for orb in orbs:
		var sid: String = species_for_type(orb.type) if orb.type != "rare" else ["receipt", "bubble", "tray", "pan", "box"].pick_random()
		var is_new := add_obake(sid)
		var lv := 1
		for o in owned:
			if o.id == sid:
				o.xp += int(h * 4) + (60 if orb.rare else 0) + tier() * 6
				_level_up(o)
				lv = o.level
		hatched.append({"id": sid, "is_new": is_new, "level": lv, "rare": false, "big": orb.rare})
	orbs = []


## 夢の結果（羊かぞえ）。数えた数に応じて、スヤリの玉と庭のめぐみ。
func finish_dream(count: int) -> Dictionary:
	dream_pending = false
	var n_orbs := 1 + count / 5
	var bonus := count / 2
	for i in n_orbs:
		var is_new := add_obake("nemuri")
		var lv := 1
		for o in owned:
			if o.id == "nemuri":
				lv = o.level
		hatched.append({"id": "nemuri", "is_new": is_new, "level": lv, "rare": false, "dream": true})
	growth += bonus
	while garden_level + 1 < GARDEN.size() and growth >= GARDEN[garden_level + 1].need:
		garden_level += 1
	if count >= 10:
		dream_flowers += 1
	last_night["dream"] = count
	last_night["growth_gain"] = last_night.get("growth_gain", 0) + bonus
	save()
	return {"orbs": n_orbs, "growth": bonus, "flower": count >= 10}


# ---------- 満月の夜 ----------

## この週の夜（直近 6 夜）のうち、よく眠れた夜の数
func moon_lanterns() -> Array:
	var out: Array = []
	var recent: Array = good_hist.slice(-6)
	for i in 6 - recent.size():
		out.append(false)
	for g in recent:
		out.append(g)
	return out


func finish_moon(lit: int, bonus_taps: int) -> Dictionary:
	moon_nights += 1
	var won := lit >= 4
	moon_won_today = won
	var gain := lit * 4 + bonus_taps
	growth += gain
	while garden_level + 1 < GARDEN.size() and growth >= GARDEN[garden_level + 1].need:
		garden_level += 1
	# 月の玉：灯りの数に応じて段階的に。3つで夢の玉、4つで満月（虹の玉とツキミ）
	var n := clampi((lit + 1) / 2, 1, 3)
	for i in n:
		orbs.append({"type": "rare" if won and i == 0 else ["register", "dish", "hall", "kitchen", "stock"].pick_random(), "rare": won and i == 0})
	if lit >= 3:
		orbs.append({"type": "sleep", "rare": false})
		n += 1
	scooped_tonight = true
	save()
	return {"won": won, "growth": gain, "orbs": n}


# ---------- レア条件 ----------

func rare_context(s: Dictionary, hours: float, bed: int) -> Dictionary:
	var worked: bool = s.get("role", "") != "" and shift_done_today
	var streak := 0
	for i in range(work_hist.size() - 1, -1, -1):
		if not work_hist[i]:
			break
		streak += 1
	var same_max := 0
	for c in coworker_count:
		same_max = max(same_max, coworker_count[c])
	var new_co := false
	if worked:
		for c in s.coworkers:
			if coworker_count.get(c, 0) == 1:
				new_co = true
	var normal_all := true
	for id in ["receipt", "bubble", "tray", "pan", "box"]:
		if not seen.has(id):
			normal_all = false
	var total := 0.0
	for x in sleep_hist:
		total += x
	var same_bed := 0
	if bed_hist.size() >= 3:
		var last3: Array = bed_hist.slice(-3)
		if absi(last3[0] - last3[1]) <= 20 and absi(last3[1] - last3[2]) <= 20:
			same_bed = 3
	var sh := s.duplicate()
	if not worked:
		sh.role = ""
	return {
		"shift": sh,
		"sleep": hours,
		"sleep_hist": sleep_hist,
		"first_role": worked and first_role_today and day > 0,
		"roles_seen": roles_seen.size(),
		"stores_week": stores_week.size(),
		"new_coworker": new_co and day > 0,
		"morning_shifts": morning_shifts,
		"day_and_night": (bands_week.has("昼") or bands_week.has("朝")) and (bands_week.has("夜") or bands_week.has("深夜")),
		"same_coworker_max": same_max,
		"gifted": gifted,
		"received": received,
		"battle_won": moon_won_today,
		"worked_streak_before": streak if s.get("role", "") == "" else 0,
		"weekend_both": weekend_shifts.size() >= 2,
		"normal_all": normal_all,
		"zukan_count": seen.size(),
		"avg_sleep_month": total / max(1, sleep_hist.size()),
		"nights": sleep_hist.size(),
		"same_bed": same_bed,
		"moon_won": moon_won_today,
		"rhythm": rhythm,
		"late": bed > LATE_LINE,
	}


# ---------- セーブ ----------

const SAVE_KEYS := ["mode", "seed_base", "day", "phase", "nets", "owned", "seen", "orbs", "scooped_tonight", "rhythm", "bed_hist", "sleep_hist", "good_hist", "last_night", "growth", "garden_level", "garden_seen_level", "decos", "new_decos", "dream_flowers", "roles_seen", "stores_week", "coworker_count", "morning_shifts", "bands_week", "shift_done_today", "weekend_shifts", "gifted", "received", "moon_nights", "rare_pending", "tut", "total_scooped", "first_role_today", "night_plan", "lit_deco", "goals", "deco_store", "work_hist", "tonight_caught", "moon_won_today", "dream_pending", "hatched", "last_goals"]


func save() -> void:
	if OS.get_environment("OBAKE_NOSAVE") != "":
		return
	var d := {}
	for k in SAVE_KEYS:
		d[k] = get(k)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		return false
	for k in SAVE_KEYS:
		if d.has(k):
			var v = d[k]
			# JSON は数を float にするので、int の変数は戻す
			if typeof(get(k)) == TYPE_INT and typeof(v) == TYPE_FLOAT:
				v = int(v)
			set(k, v)
	# 数の入った辞書・配列を int に戻す
	for id in nets:
		nets[id] = int(nets[id])
	for o in owned:
		o.level = int(o.level)
		o.xp = int(o.xp)
	for r in decos:
		decos[r] = int(decos[r])
	for c in coworker_count:
		coworker_count[c] = int(coworker_count[c])
	bed_hist = bed_hist.map(func(x): return int(x))
	var ws := {}
	for k in weekend_shifts:
		ws[int(k)] = true
	weekend_shifts = ws
	changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
