extends Node
## ゲーム全体の状態と決まりごと（Variant A「すくいと収集」）。
## 毎日：紙のポイが2本もらえる（仕事がなくても遊べる）。
## 働いた日：仕事の種類のポイ（すくいやすい・玉を寄せる）が増える。量は2本まで（長く働いても増えない）。
## よく寝た朝：ポイが強くなり、玉がよく育ってかえる。
## すくった玉 → 朝おばけに。かぶったおばけはレベルが上がり「かけら」になる → 工房でポイを作る。

signal changed

const SAVE_PATH_DEFAULT := "user://obake_a_save.json"
var SAVE_PATH := SAVE_PATH_DEFAULT # テストでは別のファイルに向ける

const SPECIES := {
	"receipt": {"name": "レシートン", "type": "register", "desc": "レジの音に寄ってくる。レシートの尻尾が長いほど長生き"},
	"bubble": {"name": "アワワ", "type": "dish", "desc": "洗い場の泡から生まれる。群れで動く"},
	"tray": {"name": "オボン", "type": "hall", "desc": "頭のお盆は絶対に落とさない。人見知り"},
	"pan": {"name": "ジュウ", "type": "kitchen", "desc": "油の跳ねる音が好き。すぐ跳ねる"},
	"box": {"name": "ダンボ", "type": "stock", "desc": "箱から出たがらない。とにかく重い"},
}
const NORMAL_IDS := ["receipt", "bubble", "tray", "pan", "box"]

## ポイ。type が同じ玉は寄ってきて、軽くすくえる
const POI := {
	"paper": {"name": "紙のポイ", "short": "紙", "type": "", "color": "f4efe6", "desc": "毎日2本もらえる、ふつうのポイ"},
	"receipt": {"name": "レシートのポイ", "short": "レジ", "type": "register", "color": "ffc23d", "desc": "黄の玉が寄ってくる。黄の玉は軽い"},
	"bubble": {"name": "泡のポイ", "short": "泡", "type": "dish", "color": "5fc4ff", "desc": "青の群れが寄ってくる。まとめてすくいやすい"},
	"tray": {"name": "お盆のポイ", "short": "お盆", "type": "hall", "color": "a98bff", "desc": "人見知りの紫が逃げにくい"},
	"pan": {"name": "フライパンのポイ", "short": "フライ", "type": "kitchen", "color": "ff7a45", "desc": "跳ねる橙が寄ってくる"},
	"box": {"name": "段ボールのポイ", "short": "段ボ", "type": "stock", "color": "e8b878", "desc": "重い茶の玉も、やぶれずに持ち上がる"},
	"kira": {"name": "きらきらポイ", "short": "きら", "type": "rare", "color": "fff2a8", "desc": "虹の玉が逃げない。はじめての経験でもらえる"},
	"lure": {"name": "よびこみポイ", "short": "よび", "type": "lure", "color": "7fe3c8", "desc": "工房製。水に入れると、まわりの玉がみんな寄ってくる"},
	"double": {"name": "二重ポイ", "short": "二重", "type": "double", "color": "ff9eb8", "desc": "工房製。紙が二枚重ね。とても丈夫"},
	"akari": {"name": "灯りのポイ", "short": "灯り", "type": "akari", "color": "ffcf7a", "desc": "工房製。手に取ると、虹の玉が浮かんでくる"},
}
const POI_ORDER := ["paper", "receipt", "bubble", "tray", "pan", "box", "kira", "lure", "double", "akari"]
const FREE_POI_PER_DAY := 2
const FREE_POI_CAP := 6
const WORK_POI_CAP := 2 # 何時間働いても、仕事のポイは 2 本まで

const ROLE_LABEL := {"register": "レジ", "dish": "皿洗い", "hall": "ホール", "kitchen": "キッチン", "stock": "品出し"}
const ROLE_POI := {"register": "receipt", "dish": "bubble", "hall": "tray", "kitchen": "pan", "stock": "box"}
const TYPE_SPECIES := {"register": "receipt", "dish": "bubble", "hall": "tray", "kitchen": "pan", "stock": "box"}
const TYPE_COLOR := {"register": Color("ffc23d"), "dish": Color("5fc4ff"), "hall": Color("a98bff"), "kitchen": Color("ff7a45"), "stock": Color("e8b878"), "rare": Color("fff2a8"), "gold": Color("ffd23f")}
const SHARD_LABEL := {"register": "黄", "dish": "青", "hall": "紫", "kitchen": "橙", "stock": "茶", "rainbow": "虹"}
const DOW := ["月", "火", "水", "木", "金", "土", "日"]
const MAX_LEVEL := 5

## 工房：ずっと効く改良（3段階）と、使い切りの特別なポイ
const UPGRADES := {
	"fuchi": {"name": "ふちを太く", "desc": "ポイがやぶれにくくなる（+20%）", "cost": [{"stock": 2, "register": 2}, {"stock": 7, "hall": 4}, {"stock": 12, "rainbow": 3}]},
	"wa": {"name": "輪を広く", "desc": "ポイが大きくなる（+12%）", "cost": [{"dish": 3, "register": 2}, {"dish": 8, "kitchen": 4}, {"dish": 14, "rainbow": 3}]},
	"kami": {"name": "紙をしなやかに", "desc": "動かしても破れにくい（-20%）", "cost": [{"hall": 2, "kitchen": 2}, {"hall": 7, "register": 4}, {"hall": 12, "rainbow": 3}]},
}
const CRAFTS := {
	"lure": {"register": 2, "dish": 2},
	"double": {"stock": 2, "hall": 1},
	"akari": {"kitchen": 2, "rainbow": 1},
	# 紙のポイの束（余ったかけらを、今夜すくう数に）
	"paper": {"register": 2, "dish": 2, "stock": 2},
	# 色のポイ（働かない日でも、かけらから作れる）
	"receipt": {"register": 3},
	"bubble": {"dish": 3},
	"tray": {"hall": 3},
	"pan": {"kitchen": 3},
	"box": {"stock": 3},
}
## 休憩室のかざり（かけらの使い道。見た目だけ）
const DECOR := {
	"chochin": {"name": "赤ちょうちん", "cost": {"register": 5, "kitchen": 5}},
	"plant": {"name": "観葉植物", "cost": {"dish": 6, "stock": 4}},
	"bowl": {"name": "玉の金魚鉢", "cost": {"dish": 8, "hall": 4}},
	"poster": {"name": "すくい名人のポスター", "cost": {"hall": 6, "register": 6}},
	"kotatsu": {"name": "こたつ", "cost": {"stock": 8, "kitchen": 6}},
	"dango": {"name": "月見だんご", "cost": {"register": 8, "rainbow": 2}},
}
const DECOR_ORDER := ["chochin", "plant", "bowl", "poster", "kotatsu", "dango"]

## 相棒：池のほとりで手伝う。レベルが上がるほど効く
const PARTNER_SKILL := {
	"receipt": "コンボが途切れにくい",
	"bubble": "近くの玉を少し寄せる",
	"tray": "重い玉が軽くなる",
	"pan": "虹の玉が長くとどまる",
	"box": "ポイがやぶれにくい",
}

## 図鑑のグループを埋めたときのごほうび
const GROUP_REWARD := {
	"睡眠": {"poi": {"double": 2}, "shards": {"rainbow": 1}},
	"はじめて": {"poi": {"kira": 2}, "shards": {"rainbow": 1}},
	"時間帯": {"poi": {"akari": 1}, "shards": {"rainbow": 1}},
	"天気": {"poi": {"lure": 2}, "shards": {"rainbow": 1}},
	"つながり": {"poi": {"double": 1, "lure": 1}, "shards": {"rainbow": 2}},
	"リズム": {"poi": {"akari": 2}, "shards": {"rainbow": 2}},
	"ふつう": {"poi": {"kira": 1, "double": 1}, "shards": {"rainbow": 1}},
}
const MILESTONES := [5, 10, 15, 20, 25, 30, 35]

## 見本の1週間（みか、大学2年）。これ以降の日は、決まった乱数で作る
const WEEK := [
	{"store": "カフェ こもれび", "role": "register", "band": "朝", "hours": 4, "weather": "晴", "coworkers": ["さとう", "りん"], "newbie": false},
	{"store": "居酒屋 とりまる", "role": "hall", "band": "夜", "hours": 5, "weather": "雨", "coworkers": ["けん", "ようこ"], "newbie": false},
	{"store": "", "role": "", "band": "", "hours": 0, "weather": "晴", "coworkers": [], "newbie": false},
	{"store": "居酒屋 とりまる", "role": "dish", "band": "夜", "hours": 4, "weather": "晴", "coworkers": ["けん", "みお"], "newbie": true},
	{"store": "北倉庫", "role": "stock", "band": "深夜", "hours": 6, "weather": "雷", "coworkers": ["だいち"], "newbie": false},
]
const STORES := [
	{"name": "カフェ こもれび", "roles": ["register", "hall"], "bands": ["朝", "昼"], "crew": ["さとう", "りん", "まこ"]},
	{"name": "居酒屋 とりまる", "roles": ["hall", "dish", "kitchen"], "bands": ["夜"], "crew": ["けん", "ようこ", "みお"]},
	{"name": "北倉庫", "roles": ["stock"], "bands": ["深夜", "昼"], "crew": ["だいち", "しん"]},
	{"name": "パン工房 むぎ", "roles": ["kitchen", "register"], "bands": ["朝"], "crew": ["はる", "ともえ"], "from": 8},
	{"name": "ホテル しらなみ", "roles": ["dish", "hall"], "bands": ["昼", "夜"], "crew": ["ゆい", "こう"], "from": 15},
]

var day := 0
var phase := "morning" # morning → room → shift_done → scooped → (寝る) → morning
var pois := {}
var strength := 1.0
var last_sleep := 7
var owned := {} # id -> {level, xp, count}
var seen := {}
var shards := {}
var upgrades := {"fuchi": 0, "wa": 0, "kami": 0}
var partner := "receipt"
var decor := {}
var orbs: Array = [] # 今夜すくった玉 {type, kind, quality}
var hatched: Array = [] # 今朝かえったおばけ
var morning_report: Array = []
var worked_today := false
var scooped_tonight := false
var tonight := {} # 今夜のすくいの結果 {count, best_combo, clean}
var records := {"best_combo": 0, "total": 0, "nights": 0, "rainbow": 0, "festival_best": 0, "clean": 0}
var claimed := {} # 図鑑のごほうび（グループ・節目）
var tut := {} # はじめての説明を見たか
var practice := false # 練習ですくう（保存しない）
var week_snap := {"total": 0, "seen": 1}
var week_best := {"combo": 0, "festival": 0} # 今週いちばん
var ALL := {}

# レアの判定用の記録
var sleep_hist: Array = []
var roles_seen := {}
var stores_seen := {}
var stores_week := {}
var coworker_count := {}
var morning_shifts := 0
var bands_week := {}
var weekend_work := {}
var work_hist: Array = [] # 実際に働いた日か（日ごと）
var first_role_today := false
var first_store_today := false
var gifted := false
var received := false
var festival_cleared := false
var drought := 0 # 新しいレアに会えずに、ちゃんとすくった夜の数
const DROUGHT_NIGHTS := 5
var rare_pending: Array = []
const RARES_PER_NIGHT := 2


func _ready() -> void:
	for id in SPECIES:
		ALL[id] = SPECIES[id]
	for r in Rares.LIST:
		ALL[r.id] = {"name": r.name, "type": "rare", "desc": r.desc, "hint": r.hint, "group": r.group}
	reset()
	if not _sandboxed():
		load_game()


## 確認・デモの起動では、セーブを読まず、書かない
var force_save := false
var demo_mode := false # タイトルの「デモ」で遊んでいるあいだは、セーブしない


func _sandboxed() -> bool:
	if force_save:
		return false
	if demo_mode:
		return true
	for k in ["OBAKE_FRESH", "OBAKE_SHOT", "OBAKE_DEMO", "OBAKE_NOSAVE", "OBAKE_AUTOPLAY"]:
		if OS.get_environment(k) != "":
			return true
	return false


func info(id: String) -> Dictionary:
	return ALL.get(id, {"name": id, "type": "", "desc": ""})


func reset() -> void:
	day = 0
	phase = "morning"
	pois = {}
	for id in POI_ORDER:
		pois[id] = 0
	pois["paper"] = 3
	strength = 1.0
	last_sleep = 7
	owned = {"receipt": {"level": 1, "xp": 0, "count": 1}}
	seen = {"receipt": 1} # 値は「会った日 + 1」
	shards = {"register": 0, "dish": 0, "hall": 0, "kitchen": 0, "stock": 0, "rainbow": 0}
	upgrades = {"fuchi": 0, "wa": 0, "kami": 0}
	partner = "receipt"
	decor = {}
	orbs = []
	hatched = []
	morning_report = ["休憩室の隅に、レシートンが1体ついてきた", "紙のポイを3本もらった。今夜、川べりでおばけの玉をすくおう"]
	worked_today = false
	scooped_tonight = false
	tonight = {}
	records = {"best_combo": 0, "total": 0, "nights": 0, "rainbow": 0, "festival_best": 0, "clean": 0}
	claimed = {}
	tut = {}
	week_snap = _make_snap()
	week_best = {"combo": 0, "festival": 0}
	festival_gift_day = -1
	work_hist = []
	sleep_hist = []
	roles_seen = {}
	stores_seen = {}
	stores_week = {}
	coworker_count = {}
	morning_shifts = 0
	bands_week = {}
	weekend_work = {}
	first_role_today = false
	first_store_today = false
	gifted = false
	received = false
	festival_cleared = false
	drought = 0
	rare_pending = []
	changed.emit()


# ---------- こよみ（何週でも続く） ----------

func week_no() -> int:
	return day / 7 + 1


func dow() -> String:
	return DOW[day % 7]


func season_of(d: int) -> String:
	return ["秋", "冬", "春", "夏"][(d / 14) % 4]


func moon_of(d: int) -> String:
	var p := posmod(d - 3, 14)
	if p == 0:
		return "満月"
	if p == 7:
		return "新月"
	if p in [3, 4, 10, 11]:
		return "半月"
	return ""


func is_festival(d := -1) -> bool:
	if d < 0:
		d = day
	return d % 7 == 5


## その日の予定（本番では、アプリの勤務記録に置き換える）
func shift_for(d: int) -> Dictionary:
	var s: Dictionary
	if d < WEEK.size():
		s = WEEK[d].duplicate(true)
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = d * 7919 + 131
		var weekend := d % 7 >= 5
		var works := rng.randf() < (0.45 if weekend else 0.62)
		var season := season_of(d)
		var weathers: Array = {"秋": ["晴", "晴", "曇", "雨"], "冬": ["晴", "雪", "曇", "雪"], "春": ["晴", "晴", "雨", "曇"], "夏": ["晴", "雷", "雨", "晴"]}[season]
		var weather: String = weathers[rng.randi() % weathers.size()]
		s = {"store": "", "role": "", "band": "", "hours": 0, "weather": weather, "coworkers": [], "newbie": false}
		if works:
			var open: Array = []
			for st in STORES:
				if d >= st.get("from", 0):
					open.append(st)
			var st: Dictionary = open[rng.randi() % open.size()]
			s.store = st.name
			s.role = st.roles[rng.randi() % st.roles.size()]
			s.band = st.bands[rng.randi() % st.bands.size()]
			s.hours = rng.randi_range(3, 8)
			var crew: Array = st.crew.duplicate()
			var n := rng.randi_range(1, 2)
			for i in n:
				var c: String = crew[rng.randi() % crew.size()]
				crew.erase(c)
				s.coworkers.append(c)
			s.newbie = rng.randf() < 0.15
	s["day"] = DOW[d % 7]
	s["season"] = season_of(d)
	s["moon"] = moon_of(d)
	return s


func today() -> Dictionary:
	return shift_for(day)


# ---------- 仕事（ブースト） ----------

func work_poi_count(hours: int) -> int:
	# 何時間働いても同じ（長く働くほど得、にはしない）
	return WORK_POI_CAP if hours > 0 else 0


## シフトを終えたときにポイを受け取る。はじめての仕事・店ならきらきらポイ
func finish_shift() -> Array:
	var s := today()
	var got: Array = []
	if s.role == "" or worked_today:
		return got
	worked_today = true
	first_role_today = not roles_seen.has(s.role)
	first_store_today = not stores_seen.has(s.store)
	roles_seen[s.role] = true
	stores_seen[s.store] = true
	stores_week[s.store] = true
	bands_week[s.band] = true
	if s.band == "朝":
		morning_shifts += 1
	if day % 7 >= 5:
		weekend_work[str(day % 7)] = true
	var old_friend := ""
	for c in s.coworkers:
		coworker_count[c] = coworker_count.get(c, 0) + 1
		if coworker_count[c] >= 3 and old_friend == "":
			old_friend = c
	var pid: String = ROLE_POI[s.role]
	var n := work_poi_count(s.hours)
	pois[pid] += n
	got.append({"poi": pid, "n": n, "why": "%sの仕事" % ROLE_LABEL[s.role]})
	if first_role_today or first_store_today:
		pois["kira"] += 1
		got.append({"poi": "kira", "n": 1, "why": "はじめての%s" % ("店" if first_store_today else "仕事")})
	# なかよしの同僚から、ときどき工房のポイをもらう
	if old_friend != "" and (day % 3 == 0 or not received):
		pois["lure"] += 1
		received = true
		got.append({"poi": "lure", "n": 1, "why": "%sさんからのおすそわけ" % old_friend})
	changed.emit()
	return got


# ---------- ポイ ----------

func total_pois() -> int:
	var n := 0
	for id in pois:
		n += pois[id]
	return n


func poi_durability_max() -> float:
	var m: float = strength * (1.0 + 0.2 * upgrades.fuchi)
	if partner == "box":
		m *= 1.0 + 0.05 * partner_level()
	return m


func poi_radius_mult() -> float:
	return 1.0 + 0.12 * upgrades.wa


func poi_gentle_mult() -> float:
	return pow(0.8, upgrades.kami)


func partner_level() -> int:
	return owned.get(partner, {}).get("level", 0)


func can_pay(cost: Dictionary) -> bool:
	for k in cost:
		if shards.get(k, 0) < cost[k]:
			return false
	return true


func pay(cost: Dictionary) -> bool:
	if not can_pay(cost):
		return false
	for k in cost:
		shards[k] -= cost[k]
	return true


func upgrade(key: String) -> bool:
	var lv: int = upgrades[key]
	if lv >= 3 or not pay(UPGRADES[key].cost[lv]):
		return false
	upgrades[key] = lv + 1
	changed.emit()
	save_game()
	return true


func buy_decor(key: String) -> bool:
	if decor.has(key) or not pay(DECOR[key].cost):
		return false
	decor[key] = true
	changed.emit()
	save_game()
	return true


const CRAFT_YIELD := {"paper": 3}


func craft(pid: String) -> bool:
	if not pay(CRAFTS[pid]):
		return false
	pois[pid] += CRAFT_YIELD.get(pid, 1)
	changed.emit()
	save_game()
	return true


## 一緒に働いた同僚に、かぶったおばけをおすそわけする。お返しにかけらが届く
func gift_target() -> String:
	var best := ""
	for c in coworker_count:
		if best == "" or coworker_count[c] > coworker_count[best]:
			best = c
	return best


func can_gift(id: String) -> bool:
	return SPECIES.has(id) and owned.get(id, {}).get("count", 0) >= 2 and gift_target() != ""


func gift(id: String) -> String:
	if not can_gift(id):
		return ""
	owned[id].count -= 1
	gifted = true
	var back: String = NORMAL_IDS.filter(func(i): return i != id).pick_random()
	var bt: String = SPECIES[back].type
	shards[bt] += 2
	changed.emit()
	save_game()
	return "%sさんに%sをおすそわけした。お返しに%sのかけら×2" % [gift_target(), info(id).name, SHARD_LABEL[bt]]


func set_partner(id: String) -> void:
	if owned.has(id) and SPECIES.has(id):
		partner = id
		changed.emit()
		save_game()


# ---------- おばけ ----------

func xp_to_next(level: int) -> int:
	return 30 + level * 70


## おばけを1体ふやす。かぶったら経験値とかけら。{is_new, level, leveled, shard}
func add_obake(id: String, xp := 0, quality := 3) -> Dictionary:
	var is_new := not seen.has(id)
	if is_new:
		seen[id] = day + 1
	var res := {"is_new": is_new, "level": 1, "leveled": false, "shard": ""}
	if not owned.has(id):
		owned[id] = {"level": 1, "xp": 0, "count": 1}
	else:
		owned[id].count += 1
		xp += 4
	var o: Dictionary = owned[id]
	if SPECIES.has(id):
		var t: String = SPECIES[id].type
		# ていねいにすくった（★2以上の）玉だけが、かけらを残す
		if not is_new and quality >= 2:
			shards[t] += 1
			res.shard = t
		if o.level < MAX_LEVEL:
			o.xp += xp
			while o.level < MAX_LEVEL and o.xp >= xp_to_next(o.level):
				o.xp -= xp_to_next(o.level)
				o.level += 1
				res.leveled = true
			if o.level >= MAX_LEVEL:
				o.xp = 0
		elif not is_new and quality >= 1:
			shards[t] += 1
	res.level = o.level
	return res


## いつ会ったか（図鑑に出す）
func met_text(id: String) -> String:
	var v = seen.get(id, null)
	if typeof(v) != TYPE_INT or v <= 0:
		return ""
	var d: int = v - 1
	return "第%d週 %s曜に会った" % [d / 7 + 1, DOW[d % 7]]


func level_of(id: String) -> int:
	return owned.get(id, {}).get("level", 0)


func normal_species_for(orb: Dictionary) -> String:
	if orb.kind in ["rainbow", "gold"]:
		# まだ持っていない種類を優先
		var missing: Array = NORMAL_IDS.filter(func(i): return not seen.has(i))
		return missing.pick_random() if missing.size() > 0 else NORMAL_IDS.pick_random()
	return TYPE_SPECIES.get(orb.type, "receipt")


# ---------- 夜のすくい ----------

## 今夜の池の決まり（天気・月・祭り）
func night_mods() -> Dictionary:
	var s := today()
	var m := {"speed": 1.0, "drain": 1.0, "supply": 9, "rainbow": 0.35, "rainbow_max": 1, "scatter": false, "snow": false, "rain": false, "dark": false, "festival": false, "label": []}
	match s.weather:
		"雨":
			m.speed = 1.25
			m.drain = 1.2
			m.supply += 3
			m.rain = true
			m.label.append("雨：玉が多い・ポイがぬれやすい")
		"雷":
			m.scatter = true
			m.rainbow += 0.2
			m.label.append("雷：光るたびに玉が散る")
		"雪":
			m.speed = 0.6
			m.snow = true
			m.label.append("雪：水がつめたく、玉がゆっくり")
		"曇":
			m.label.append("くもり：おだやかな夜")
	match s.moon:
		"満月":
			m.rainbow += 0.45
			m.rainbow_max = 2
			m.label.append("満月：虹の玉が浮かびやすい")
		"新月":
			m.dark = true
			m.supply += 2
			m.label.append("新月：暗いが、玉が多い")
	if worked_today and (first_role_today or first_store_today):
		m.rainbow += 0.3
	if drought >= DROUGHT_NIGHTS:
		m.rainbow += 0.45
		m.label.append("虹の気配：まだ見ぬレアが近い")
	if is_festival():
		m.festival = true
		m.supply += 8
		m.rainbow_max += 1
		m.label.push_front("大すくい祭り：金の玉が出る。12こで景品、20こで特賞")
	if m.label.is_empty():
		m.label.append("晴れ：しずかな水面")
	m.rainbow = minf(m.rainbow, 0.95)
	return m


## 玉の種類。仕事の種類で性格が違う
func orb_kind_for(t: String) -> String:
	return {"register": "normal", "dish": "school", "hall": "shy", "kitchen": "jumper", "stock": "heavy"}.get(t, "normal")


## 次に流れてくる玉。今日働いた仕事の種類が多めに出る
func next_orb_type(rng_val: float) -> String:
	var types := ["register", "dish", "hall", "kitchen", "stock"]
	var s := today()
	if worked_today and s.role != "" and rng_val < 0.4:
		return s.role
	# まだ会っていない種類を少し多めに（最初の数日で5種そろいやすく）
	var missing: Array = []
	for t in types:
		if not seen.has(TYPE_SPECIES[t]):
			missing.append(t)
	if missing.size() > 0 and randf() < 0.35:
		return missing.pick_random()
	if day == 0:
		return ["register", "dish", "stock"].pick_random()
	return types.pick_random()


## 今夜のおだい（毎晩ひとつ。できたら、その場でごほうび）
const TYPE_LABEL := {"register": "黄", "dish": "青", "hall": "紫", "kitchen": "橙", "stock": "茶"}


func night_goal() -> Dictionary:
	if is_festival():
		return {"id": "count", "n": 12, "text": "祭り：12こすくう", "reward": {"shards": {"rainbow": 1}}}
	var rng := RandomNumberGenerator.new()
	rng.seed = day * 31 + 7
	var w := mini(week_no(), 4)
	var types := ["register", "dish", "hall", "kitchen", "stock"]
	var t: String = types[rng.randi() % types.size()]
	var s := today()
	if s.role != "" and rng.randf() < 0.5:
		t = s.role
	var pick := rng.randi() % 5
	if day == 0:
		pick = 0
	var g := {}
	match pick:
		0:
			g = {"id": "count", "n": 3 + w, "text": "%dこすくう" % (3 + w)}
		1:
			g = {"id": "combo", "n": 2 + w, "text": "%dコンボ" % (2 + w)}
		2:
			g = {"id": "clean", "n": 1 + w, "text": "ていねいに%dこ" % (1 + w)}
		3:
			g = {"id": "multi", "n": 1, "text": "2こ以上まとめてすくう"}
		_:
			g = {"id": "type", "type": t, "n": 1 + (w + 1) / 2, "text": "%sの玉を%dこ" % [TYPE_LABEL[t], 1 + (w + 1) / 2]}
	var rt: String = types[rng.randi() % types.size()] if g.id != "type" else t
	g["reward"] = {"shards": {rt: 2}} if rng.randf() < 0.7 else {"poi": {"kira": 1}}
	return g


func grant(rw: Dictionary) -> void:
	for p in rw.get("poi", {}):
		pois[p] += rw.poi[p]
	for k in rw.get("shards", {}):
		shards[k] += rw.shards[k]
	changed.emit()


## 工房の、いちばん近い次の改良
func next_unlock_text() -> String:
	var best := ""
	var best_need := 999
	for key in UPGRADES:
		var lv: int = upgrades[key]
		if lv >= 3:
			continue
		var cost: Dictionary = UPGRADES[key].cost[lv]
		var need := 0
		var parts: Array = []
		for k in cost:
			var miss: int = max(0, cost[k] - shards.get(k, 0))
			need += miss
			if miss > 0:
				parts.append("%s×%d" % [SHARD_LABEL[k], miss])
		if need < best_need:
			best_need = need
			best = "工房で「%s」が作れる！" % UPGRADES[key].name if need == 0 else "「%s」まで かけら %s" % [UPGRADES[key].name, "・".join(parts)]
	return best


const FESTIVAL_PRIZE := {"shards": {"rainbow": 2}, "poi": {"double": 1}}
const FESTIVAL_PRIZE_BIG := {"shards": {"rainbow": 3}, "poi": {"double": 1, "akari": 1, "kira": 1}}


## 祭りの夜は、紙のポイを3本もらえる（1晩1回）
var festival_gift_day := -1


func festival_gift() -> int:
	if not is_festival() or festival_gift_day == day:
		return 0
	festival_gift_day = day
	pois.paper += 3
	changed.emit()
	return 3


## すくいの称号（腕前の目じるし）
const TITLES := [
	{"name": "見習い", "total": 0, "combo": 0, "rainbow": 0},
	{"name": "かけだし", "total": 20, "combo": 3, "rainbow": 0},
	{"name": "一人前", "total": 60, "combo": 5, "rainbow": 1},
	{"name": "名人", "total": 150, "combo": 8, "rainbow": 4},
	{"name": "達人", "total": 300, "combo": 12, "rainbow": 10},
	{"name": "名手", "total": 600, "combo": 16, "rainbow": 20},
	{"name": "川の主", "total": 1000, "combo": 20, "rainbow": 35},
]


func title_index() -> int:
	var idx := 0
	for i in TITLES.size():
		var t: Dictionary = TITLES[i]
		if records.total >= t.total and records.best_combo >= t.combo and records.rainbow >= t.rainbow:
			idx = i
	return idx


func title_name() -> String:
	var n: String = TITLES[title_index()].name
	return n if n == "川の主" else "すくい" + n


func next_title_text() -> String:
	var i := title_index()
	if i + 1 >= TITLES.size():
		return "いちばん上の称号"
	var t: Dictionary = TITLES[i + 1]
	var parts: Array = []
	if records.total < t.total:
		parts.append("すくった玉 あと%d" % (t.total - records.total))
	if records.best_combo < t.combo:
		parts.append("%dコンボ" % t.combo)
	if records.rainbow < t.rainbow:
		parts.append("虹の玉 あと%d" % (t.rainbow - records.rainbow))
	return "次は「%s」：%s" % [t.name, "・".join(parts)]


func record_scoop_night(result: Dictionary) -> void:
	tonight = result
	for t in result.get("types", {}):
		records["t_" + t] = records.get("t_" + t, 0) + result.types[t]
	week_best.combo = max(week_best.combo, result.get("best_combo", 0))
	if result.get("festival", false):
		week_best.festival = max(week_best.festival, result.get("count", 0))
	scooped_tonight = true
	records.nights += 1
	records.total += result.get("count", 0)
	records.best_combo = max(records.best_combo, result.get("best_combo", 0))
	records.rainbow += result.get("rainbow", 0)
	records.clean += result.get("clean", 0)
	if result.get("festival", false):
		records.festival_best = max(records.festival_best, result.get("count", 0))
		if result.get("count", 0) >= 12:
			festival_cleared = true
			# 祭りの景品（毎週もらえる。20こなら特賞）
			var prize := FESTIVAL_PRIZE_BIG if result.get("count", 0) >= 20 else FESTIVAL_PRIZE
			grant(prize)
			tonight["prize"] = prize
	phase = "scooped"
	changed.emit()
	save_game()


# ---------- 寝る → 朝 ----------

func sleep_strength(hours: int) -> float:
	return {4: 0.75, 5: 0.85, 6: 1.0, 7: 1.2, 8: 1.25, 9: 1.2}.get(clampi(hours, 4, 9), 1.0)


func sleep_quality_bonus(hours: int) -> int:
	return 1 if hours >= 7 else 0


func sleep(hours: int) -> void:
	last_sleep = hours
	strength = sleep_strength(hours)
	morning_report = []
	hatched = []
	var s: Dictionary = today()
	sleep_hist.append(hours)
	# 1) すくった玉がかえる。よく寝ると玉の★がひとつ増える
	var qb := sleep_quality_bonus(hours)
	# 群れの小さな玉は、2つでひとり分
	var list: Array = []
	var school := 0
	for orb in orbs:
		if orb.kind == "school":
			school += 1
			if school % 2 == 1:
				list.append(orb)
		else:
			list.append(orb)
	var rainbows: Array = []
	for orb in list:
		if orb.kind == "rainbow":
			rainbows.append(orb)
			continue
		var sid := normal_species_for(orb)
		var q: int = clampi(orb.get("quality", 0) + qb, 0, 3)
		var xp: int = 4 + q * 4
		var before := level_of(sid)
		var r := add_obake(sid, xp, q)
		var gold_t := ""
		if orb.kind == "gold":
			gold_t = SPECIES[NORMAL_IDS.pick_random()].type
			shards[gold_t] += 2
		hatched.append({"id": sid, "is_new": r.is_new, "level": r.level, "before": before, "leveled": r.leveled, "rare": false, "quality": q, "kind": orb.kind, "shard": r.shard, "gold_shard": gold_t})
	# 2) その日の記録から、条件を満たしたレア（1晩2体まで）
	var have := seen.duplicate()
	for rid in rare_pending:
		have[rid] = true
	var fresh: Array = Rares.check(rare_context(s, hours), have)
	rare_pending = fresh + rare_pending
	for i in min(RARES_PER_NIGHT, rare_pending.size()):
		var rid: String = rare_pending.pop_front()
		add_obake(rid)
		hatched.append({"id": rid, "is_new": true, "level": 1, "rare": true, "quality": 3, "kind": "rare"})
	# 虹の玉：待っているレアがいれば、その子がかえる。
	# しばらくレアに会えていなければ、まだ見ぬレアを連れてくる（働かない日が続いても図鑑が止まりきらない）
	for orb in rainbows:
		shards.rainbow += 1
		if rare_pending.is_empty() and drought >= DROUGHT_NIGHTS:
			var unseen: Array = Rares.LIST.filter(func(r): return not seen.has(r.id)).map(func(r): return r.id)
			if unseen.size() > 0:
				rare_pending.append(unseen.pick_random())
		if rare_pending.size() > 0:
			var rid: String = rare_pending.pop_front()
			add_obake(rid)
			hatched.append({"id": rid, "is_new": true, "level": 1, "rare": true, "quality": 3, "kind": "rainbow", "from_rainbow": true})
			continue
		var sid := normal_species_for(orb)
		var q: int = clampi(orb.get("quality", 0) + qb, 0, 3)
		var before := level_of(sid)
		var r := add_obake(sid, 34 + q * 4, q)
		hatched.append({"id": sid, "is_new": r.is_new, "level": r.level, "before": before, "leveled": r.leveled, "rare": false, "quality": q, "kind": "rainbow", "shard": r.shard})
	# 3) 次の日へ
	var new_rare: bool = hatched.any(func(h): return h.get("rare", false))
	if new_rare:
		drought = 0
	elif tonight.get("count", 0) >= 3:
		drought += 1
	work_hist.append(worked_today)
	var n_orbs := orbs.size()
	orbs = []
	scooped_tonight = false
	worked_today = false
	first_role_today = false
	first_store_today = false
	tonight = {}
	# 週が変わる前に、できていた「今週のおねがい」は受け取っておく
	var auto_claimed := 0
	if (day + 1) % 7 == 0:
		for q in week_quests():
			if quest_done(q) and not claimed.has(q.key):
				claim_quest(q)
				auto_claimed += 1
	day += 1
	# 朝に会ったので、会った日は新しい日にする
	for h in hatched:
		if h.get("is_new", false):
			seen[h.id] = day + 1
	if day % 7 == 0:
		stores_week = {}
		bands_week = {}
		weekend_work = {}
	var free: int = clampi(FREE_POI_CAP - pois.paper, 0, FREE_POI_PER_DAY)
	pois.paper += free
	phase = "morning"
	# 朝の報告
	morning_report.append("%d時間ねた → ポイの強さ ×%.2f%s" % [hours, strength, "（よく寝た！玉が★1つ育った）" if qb > 0 else ""])
	if n_orbs > 0:
		morning_report.append("すくった玉 %d こが、朝日でかえった" % n_orbs)
	if free > 0:
		morning_report.append("毎朝の紙のポイ ×%d" % free)
	else:
		morning_report.append("紙のポイは %d 本でいっぱい（使わないと増えない）" % FREE_POI_CAP)
	if rare_pending.size() > 0:
		morning_report.append("まだかえっていないレアの気配が %d つ…" % rare_pending.size())
	if auto_claimed > 0:
		morning_report.append("先週のおねがい %d つのごほうびを受け取った" % auto_claimed)
	if day % 7 == 0:
		morning_report.push_front("第%d週のまとめ：すくった玉 %d・新しい出会い %d" % [week_no() - 1, records.total - int(week_snap.total), seen.size() - int(week_snap.seen)])
		week_snap = _make_snap()
		week_best = {"combo": 0, "festival": 0}
	changed.emit()
	save_game()


func rare_context(s: Dictionary, hours: int) -> Dictionary:
	var worked: bool = worked_today and s.get("role", "") != ""
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
	for id in SPECIES:
		if not seen.has(id):
			normal_all = false
	var recent: Array = sleep_hist.slice(-28)
	var total := 0.0
	for h in recent:
		total += h
	var sh := s.duplicate()
	if not worked:
		sh.role = ""
	sh["first"] = worked and first_store_today
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
		"battle_won": festival_cleared and is_festival(),
		"worked_streak_before": streak if not worked else 0,
		"weekend_both": weekend_work.has("5") and weekend_work.has("6"),
		"normal_all": normal_all,
		"zukan_count": seen.size(),
		"avg_sleep_month": total / max(1, recent.size()),
		"nights": recent.size(),
		"scooped": tonight.get("count", 0),
	}


# ---------- 今週のおねがい（週に3つ） ----------

func _make_snap() -> Dictionary:
	var d := {"total": records.get("total", 0), "seen": seen.size(), "rainbow": records.get("rainbow", 0), "clean": records.get("clean", 0), "nights": records.get("nights", 0)}
	for t in TYPE_LABEL:
		d["t_" + t] = records.get("t_" + t, 0)
	return d


func week_quests() -> Array:
	var w := week_no()
	var rng := RandomNumberGenerator.new()
	rng.seed = w * 977 + 5
	var types: Array = TYPE_LABEL.keys()
	var t: String = types[rng.randi() % types.size()]
	var pool := [
		{"id": "rainbow", "n": 1, "text": "虹の玉を1つすくう"},
		{"id": "combo", "n": 5 + mini(w, 4), "text": "%dコンボを出す" % (5 + mini(w, 4))},
		{"id": "clean", "n": 8 + w * 2, "text": "ていねいな玉を%dこ" % (8 + w * 2)},
		{"id": "type", "type": t, "n": 5, "text": "%sの玉を5こ" % TYPE_LABEL[t]},
		{"id": "nights", "n": 4, "text": "4つの夜にすくう"},
		{"id": "festival", "n": 10, "text": "祭りで10こすくう"},
		{"id": "seen", "n": 2, "text": "新しいおばけに2体会う"},
	]
	# 図鑑がほぼ埋まっていたら「新しい出会い」は出さない
	if ALL.size() - int(week_snap.get("seen", seen.size())) < 3:
		pool = pool.filter(func(q): return q.id != "seen")
	var out: Array = []
	var idx: Array = range(pool.size())
	for i in 3:
		var k: int = idx[rng.randi() % idx.size()]
		idx.erase(k)
		var q: Dictionary = pool[k].duplicate()
		q["key"] = "w%d:%s" % [w, q.id]
		out.append(q)
	return out


func quest_progress(q: Dictionary) -> int:
	var sn: Dictionary = week_snap
	match q.id:
		"rainbow":
			return records.rainbow - int(sn.get("rainbow", 0))
		"combo":
			return week_best.combo
		"clean":
			return records.clean - int(sn.get("clean", 0))
		"type":
			return records.get("t_" + q.type, 0) - int(sn.get("t_" + q.type, 0))
		"nights":
			return records.nights - int(sn.get("nights", 0))
		"festival":
			return week_best.festival
		"seen":
			return seen.size() - int(sn.get("seen", 0))
	return 0


func quest_done(q: Dictionary) -> bool:
	return quest_progress(q) >= q.n


const QUEST_REWARD := {"shards": {"rainbow": 1}, "poi": {"kira": 1}}
const QUEST_ALL_REWARD := {"shards": {"rainbow": 2}, "poi": {"akari": 1, "double": 1}}


func quests_claimable() -> int:
	var n := 0
	for q in week_quests():
		if quest_done(q) and not claimed.has(q.key):
			n += 1
	return n


func claim_quest(q: Dictionary) -> Dictionary:
	if claimed.has(q.key) or not quest_done(q):
		return {}
	claimed[q.key] = true
	grant(QUEST_REWARD)
	var rw := QUEST_REWARD.duplicate(true)
	var all := true
	for x in week_quests():
		if not claimed.has(x.key):
			all = false
	if all:
		grant(QUEST_ALL_REWARD)
		rw = {"shards": {"rainbow": 3}, "poi": {"kira": 1, "akari": 1, "double": 1}}
	save_game()
	return rw


# ---------- 相棒のひとこと（真顔で） ----------

func partner_line() -> String:
	var s := today()
	var lines: Array = []
	if phase == "scooped":
		lines = ["今夜はもう寝よう。玉は逃げない", "すくった玉、あったかい", "明日の朝が、ちょっとたのしみ"]
	elif is_festival():
		lines = ["今夜は祭り。はっぴを探している", "金の玉は、すこし重い", "太鼓の音で、泡が出た"]
	elif last_sleep <= 5:
		lines = ["ねむそうだね。ぼくもだけど", "今日のポイは、すこし弱い。そっとね", "寝不足は、紙にでる"]
	elif s.weather == "雨":
		lines = ["雨の夜は、玉がふえる。ぬれるけど", "かさ、ないの"]
	elif s.weather == "雪":
		lines = ["雪の日の玉は、ゆっくりだよ", "しっぽが冷たい"]
	elif s.moon == "満月":
		lines = ["今夜は満月。虹が出る気がする", "月がまるい。ぼくもまるい"]
	elif s.role != "" and not worked_today:
		lines = ["今日は%sのシフトだって" % ROLE_LABEL[s.role], "働くと、色のポイがもらえる。2本まで"]
	else:
		lines = ["ここは休憩室。休むところ", "きのうのコンボ、見てた", "今日も、そっといこう", "玉は、真ん中ですくうといい", "新しい子が、隅でじっとしている"]
	return info(partner).name + "「" + String(lines[day % lines.size()]) + "」"


# ---------- 図鑑のごほうび ----------

func group_progress(g: String) -> Vector2i:
	var have := 0
	var total := 0
	if g == "ふつう":
		for id in NORMAL_IDS:
			total += 1
			if seen.has(id):
				have += 1
	else:
		for r in Rares.LIST:
			if r.group == g:
				total += 1
				if seen.has(r.id):
					have += 1
	return Vector2i(have, total)


func milestone_reward(n: int) -> Dictionary:
	return {"poi": {"kira": 1} if n < 20 else {"akari": 1, "double": 1}, "shards": {"rainbow": 1}}


func claimable() -> Array:
	var out: Array = []
	for g in GROUP_REWARD:
		var p := group_progress(g)
		if p.x >= p.y and not claimed.has("g:" + g):
			out.append("g:" + g)
	for n in MILESTONES:
		if seen.size() >= n and not claimed.has("m:%d" % n):
			out.append("m:%d" % n)
	return out


func claim(key: String) -> Dictionary:
	if claimed.has(key) or not claimable().has(key):
		return {}
	var rw: Dictionary = GROUP_REWARD[key.substr(2)] if key.begins_with("g:") else milestone_reward(int(key.substr(2)))
	for p in rw.get("poi", {}):
		pois[p] += rw.poi[p]
	for k in rw.get("shards", {}):
		shards[k] += rw.shards[k]
	claimed[key] = true
	changed.emit()
	save_game()
	return rw


func reward_text(rw: Dictionary) -> String:
	var parts: Array = []
	for p in rw.get("poi", {}):
		parts.append("%s×%d" % [POI[p].name, rw.poi[p]])
	for k in rw.get("shards", {}):
		parts.append("%sのかけら×%d" % [SHARD_LABEL[k], rw.shards[k]])
	return "、".join(parts)


# ---------- セーブ ----------

const SAVE_KEYS := ["day", "phase", "pois", "strength", "last_sleep", "owned", "seen", "shards", "upgrades", "partner", "orbs", "hatched", "morning_report", "worked_today", "scooped_tonight", "tonight", "records", "claimed", "tut", "sleep_hist", "roles_seen", "stores_seen", "stores_week", "coworker_count", "morning_shifts", "bands_week", "weekend_work", "first_role_today", "first_store_today", "gifted", "received", "festival_cleared", "rare_pending", "festival_gift_day", "week_snap", "work_hist", "decor", "drought", "week_best"]


func save_game() -> void:
	if _sandboxed():
		return
	var d := {"v": 1}
	for k in SAVE_KEYS:
		d[k] = get(k)
	# いったん別のファイルに書いて、書けたことを確かめてから入れ替える（前のセーブは .bak に残す）
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("セーブを書けなかった: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(d))
	f.close()
	if typeof(_read_save(tmp)) != TYPE_DICTIONARY:
		push_warning("セーブの書き込みを確かめられなかった")
		return
	var dir := DirAccess.open("user://")
	if FileAccess.file_exists(SAVE_PATH):
		dir.rename(SAVE_PATH.get_file(), SAVE_PATH.get_file() + ".bak")
	dir.rename(tmp.get_file(), SAVE_PATH.get_file())


func _read_save(path: String):
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var d = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY or d.get("v", 0) != 1:
		return null
	return d


func has_save() -> bool:
	return _read_save(SAVE_PATH) != null or _read_save(SAVE_PATH + ".bak") != null


func load_game() -> bool:
	var d = _read_save(SAVE_PATH)
	if d == null:
		d = _read_save(SAVE_PATH + ".bak")
	if d == null:
		return false
	for k in SAVE_KEYS:
		if not d.has(k):
			continue
		var v = _intify(d[k])
		var cur = get(k)
		# JSON は数値を float で返すので、元の型に戻す
		if typeof(cur) == TYPE_INT:
			v = int(v)
		elif typeof(cur) == TYPE_FLOAT:
			v = float(v)
		set(k, v)
	_fix_ints()
	changed.emit()
	return true


## JSON から戻した入れ物の中の、整数だった数を int に戻す
func _intify(v):
	match typeof(v):
		TYPE_FLOAT:
			return int(v) if v == floorf(v) else v
		TYPE_DICTIONARY:
			var out := {}
			for k in v:
				out[k] = _intify(v[k])
			return out
		TYPE_ARRAY:
			var arr: Array = []
			for x in v:
				arr.append(_intify(x))
			return arr
	return v


func _fix_ints() -> void:
	for k in pois:
		pois[k] = int(pois[k])
	for k in shards:
		shards[k] = int(shards[k])
	for k in upgrades:
		upgrades[k] = int(upgrades[k])
	for id in owned:
		for f in ["level", "xp", "count"]:
			owned[id][f] = int(owned[id][f])
	for k in records:
		records[k] = int(records[k])
	for k in coworker_count:
		coworker_count[k] = int(coworker_count[k])
	for i in sleep_hist.size():
		sleep_hist[i] = int(sleep_hist[i])
	for o in orbs:
		o.quality = int(o.get("quality", 0))
	for id in POI_ORDER:
		if not pois.has(id):
			pois[id] = 0


func wipe_save() -> void:
	for p in [SAVE_PATH, SAVE_PATH + ".bak", SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	reset()


# ---------- デモ用の早送り ----------

## 何日か、ほどほどの腕前で自動で遊ぶ（監査・動画用）
func fast_forward(days: int, sleep_pattern := [7, 8, 6, 7, 9, 7, 5]) -> void:
	for i in days:
		var s := today()
		if s.role != "":
			finish_shift()
		var n := randi_range(3, 5) + (4 if is_festival() else 0)
		var result := {"count": 0, "best_combo": 0, "rainbow": 0, "clean": 0, "festival": is_festival(), "types": {}}
		var combo := 0
		for k in n:
			var t := next_orb_type(randf())
			var kind := orb_kind_for(t)
			if randf() < 0.07:
				kind = "rainbow"
				t = "rare"
				result.rainbow += 1
			var q := randi_range(0, 2)
			orbs.append({"type": t, "kind": kind, "quality": q})
			result.types[t] = result.types.get(t, 0) + 1
			combo += 1
			result.count += 1
			if q == 2:
				result.clean += 1
		result.best_combo = combo
		var paper_used := mini(pois.paper, 2)
		pois.paper -= paper_used
		record_scoop_night(result)
		sleep(sleep_pattern[i % sleep_pattern.size()])
		for key in claimable():
			claim(key)
		# 余ったかけらで、工房の改良を進める
		for u in ["fuchi", "wa", "kami"]:
			upgrade(u)
		if i % 3 == 2:
			for key in DECOR_ORDER:
				if buy_decor(key):
					break
