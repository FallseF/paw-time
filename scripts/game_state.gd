extends Node
## ゲーム全体の状態と決まりごと。
## 現実の仕事 → 網（種類も数も）、現実の睡眠 → 網を振る回数・網の強さ・おばけの成長。
## 仕事と睡眠の記録は WEEK の見本データ。本番ではここをサーバーの記録に差し替える。

signal changed

const SPECIES := {
	"receipt": {"name": "レシートン", "type": "register", "desc": "レジの音に寄ってくる。レシートの尻尾が長いほど長生き"},
	"bubble": {"name": "アワワ", "type": "dish", "desc": "洗い場の泡から生まれる。割れても平気"},
	"tray": {"name": "オボン", "type": "hall", "desc": "頭のお盆は絶対に落とさない"},
	"pan": {"name": "ジュウ", "type": "kitchen", "desc": "油の跳ねる音が好き。少しあつい"},
	"box": {"name": "ダンボ", "type": "stock", "desc": "箱から出たがらない。重いものが得意"},
}

const NETS := {
	"receipt": {"name": "レシート網", "type": "register"},
	"bubble": {"name": "泡の網", "type": "dish"},
	"tray": {"name": "お盆網", "type": "hall"},
	"pan": {"name": "フライパン網", "type": "kitchen"},
	"box": {"name": "段ボール網", "type": "stock"},
	"kira": {"name": "きらきら網", "type": "rare"},
}

const ROLE_LABEL := {"register": "レジ", "dish": "皿洗い", "hall": "ホール", "kitchen": "キッチン", "stock": "品出し"}
const ROLE_NET := {"register": "receipt", "dish": "bubble", "hall": "tray", "kitchen": "pan", "stock": "box"}

## 見本の1週間（みか、大学2年）。hours が網の数、first がきらきら網。
const WEEK := [
	{"day": "月", "store": "カフェ こもれび", "role": "register", "band": "朝", "hours": 4, "first": false, "weather": "晴", "moon": "", "season": "秋", "coworkers": ["さとう", "りん"], "newbie": false},
	{"day": "火", "store": "居酒屋 とりまる", "role": "hall", "band": "夜", "hours": 5, "first": false, "weather": "雨", "moon": "", "season": "秋", "coworkers": ["けん", "ようこ"], "newbie": false},
	{"day": "水", "store": "", "role": "", "band": "", "hours": 0, "first": false, "weather": "晴", "moon": "", "season": "秋", "coworkers": [], "newbie": false},
	{"day": "木", "store": "居酒屋 とりまる", "role": "dish", "band": "夜", "hours": 4, "first": false, "weather": "晴", "moon": "満月", "season": "秋", "coworkers": ["けん", "みお"], "newbie": true},
	{"day": "金", "store": "北倉庫", "role": "stock", "band": "深夜", "hours": 6, "first": true, "weather": "雷", "moon": "", "season": "秋", "coworkers": ["だいち"], "newbie": false},
]
const BATTLE_DAY := 4 # 金曜の夜は「大ピーク」

var day := 0
var phase := "morning" # morning → room → catch → sleep → (次の日の) morning
var nets := {}
var stamina := 0 # 網を振れる回数（睡眠で溜まる）
var net_strength := 1.0 # 睡眠で決まる
var last_sleep := 7
var trap := ""
var owned: Array = [] # {id, level, xp}
var seen := {}
var morning_report: Array = []
var battle_won := false
var orbs: Array = [] # すくった光る玉 {type, rare}。朝に割れておばけになる
var hatched: Array = [] # 今朝割れた玉 {id, is_new, level}
var scooped_tonight := false
var ALL := {} # ふつうのおばけ + レア 30 体
var sleep_hist: Array = []
var roles_seen := {}
var stores_week := {}
var coworker_count := {}
var morning_shifts := 0
var bands_week := {}
var first_role_today := false
var gifted := false
var rare_pending: Array = [] # 条件を満たしたが、まだ生まれていないレア（1晩2体まで）
const RARES_PER_NIGHT := 2
var received := false


func _ready() -> void:
	for id in SPECIES:
		ALL[id] = SPECIES[id]
	for r in Rares.LIST:
		ALL[r.id] = {"name": r.name, "type": "rare", "desc": r.desc, "hint": r.hint, "group": r.group}
	reset()


func info(id: String) -> Dictionary:
	return ALL.get(id, {"name": id, "type": "", "desc": ""})


func reset() -> void:
	day = 0
	phase = "morning"
	nets = {"receipt": 2, "bubble": 0, "tray": 0, "pan": 0, "box": 0, "kira": 0}
	stamina = 6
	net_strength = 1.0
	last_sleep = 7
	trap = ""
	owned = [{"id": "receipt", "level": 1, "xp": 0}]
	seen = {"receipt": true}
	morning_report = ["はじめての朝。レシートンが1体、ついてきている"]
	battle_won = false
	orbs = []
	hatched = []
	scooped_tonight = false
	sleep_hist = []
	roles_seen = {}
	stores_week = {}
	coworker_count = {}
	morning_shifts = 0
	bands_week = {}
	first_role_today = false
	gifted = false
	received = false
	rare_pending = []
	changed.emit()


func today() -> Dictionary:
	return WEEK[day]


## シフトを終えたときに網を受け取る。働いた時間の分だけ増える（2時間で1本）。
func finish_shift() -> Array:
	var s := today()
	var got: Array = []
	if s.role == "":
		return got
	first_role_today = not roles_seen.has(s.role)
	roles_seen[s.role] = true
	stores_week[s.store] = true
	bands_week[s.band] = true
	if s.band == "朝":
		morning_shifts += 1
	for c in s.coworkers:
		coworker_count[c] = coworker_count.get(c, 0) + 1
	var net_id: String = ROLE_NET[s.role]
	var n: int = max(1, int(s.hours / 2))
	nets[net_id] += n
	got.append("%s ×%d" % [NETS[net_id].name, n])
	if s.first:
		nets["kira"] += 1
		got.append("きらきら網 ×1（はじめての経験）")
	changed.emit()
	return got


## 網の相性と振るタイミングで、捕まる確率を決める。
func catch_chance(species_id: String, net_id: String, timing: float) -> float:
	var sp: Dictionary = info(species_id)
	var net: Dictionary = NETS[net_id]
	var match_mult := 0.8
	if net.type == sp.type:
		match_mult = 2.0
	elif net_id == "kira":
		match_mult = 1.5
	elif sp.type in ["night", "rare"]:
		match_mult = 0.5
	var base := 0.35
	return clampf(base * match_mult * timing * net_strength, 0.03, 0.95)


func use_net(net_id: String) -> bool:
	if stamina <= 0 or nets.get(net_id, 0) <= 0:
		return false
	nets[net_id] -= 1
	stamina -= 1
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


## 寝る。睡眠時間で、次の日の振れる回数・網の強さ・おばけの成長・仕掛けの結果が決まる。
func sleep(hours: int, trap_net: String) -> void:
	last_sleep = hours
	stamina = hours
	if hours < 6:
		net_strength = 0.7
	elif hours < 7:
		net_strength = 1.0
	else:
		net_strength = 1.25
	morning_report = []
	morning_report.append("%d時間ねた → 今日のポイの強さ ×%.2f" % [hours, net_strength])
	for o in owned:
		o.xp += hours * 6
		if _level_up(o):
			morning_report.append("%s が Lv%d に育った" % [info(o.id).name, o.level])
	if trap_net != "" and nets.get(trap_net, 0) > 0:
		nets[trap_net] -= 1
		var caught := _trap_result(trap_net, hours)
		if caught == "":
			morning_report.append("仕掛けた%sは、からっぽだった" % NETS[trap_net].name)
		else:
			var is_new := add_obake(caught)
			morning_report.append("仕掛けた網に %s がかかっていた%s" % [info(caught).name, "（はじめて！）" if is_new else ""])
	hatched = []
	# その日の記録から、条件を満たしたレアが生まれる
	sleep_hist.append(hours)
	var s: Dictionary = WEEK[day] if day < WEEK.size() else {}
	var have := seen.duplicate()
	for rid in rare_pending:
		have[rid] = true
	# その日に満たした条件を先に（持ち越し分はあと）
	var fresh: Array = Rares.check(rare_context(s, hours), have)
	rare_pending = fresh + rare_pending
	for i in min(RARES_PER_NIGHT, rare_pending.size()):
		var rid: String = rare_pending.pop_front()
		add_obake(rid)
		hatched.append({"id": rid, "is_new": true, "level": 1, "rare": true})
	# すくった光る玉は、ふつうのおばけに。虹の玉は大きく育って生まれる
	for orb in orbs:
		var sid: String = species_for_type(orb.type) if orb.type != "rare" else ["receipt", "bubble", "tray", "pan", "box"].pick_random()
		var is_new := add_obake(sid)
		var lv := 1
		for o in owned:
			if o.id == sid:
				o.xp += hours * 4 + (60 if orb.rare else 0)
				_level_up(o)
				lv = o.level
		hatched.append({"id": sid, "is_new": is_new, "level": lv, "rare": false})
	if orbs.size() > 0:
		morning_report.append("光る玉が %d 個、朝日で割れた" % orbs.size())
	orbs = []
	scooped_tonight = false
	day += 1
	phase = "morning"
	changed.emit()


func _trap_result(net_id: String, hours: int) -> String:
	var r := randf()
	if hours >= 7 and r < 0.6:
		return "nemurin"
	if hours <= 5 and r < 0.5:
		return "yomise"
	if r < 0.35 + hours * 0.05:
		for sid in SPECIES:
			if SPECIES[sid].type == NETS[net_id].type:
				return sid
		return "kirari" if net_id == "kira" else ""
	return ""


func obake_power(o: Dictionary) -> int:
	return 8 + o.level * 4


func is_week_over() -> bool:
	return day >= WEEK.size()


const TYPE_SPECIES := {"register": "receipt", "dish": "bubble", "hall": "tray", "kitchen": "pan", "stock": "box", "sleep": "nemurin", "night": "yomise", "rare": "kirari"}
const TYPE_COLOR := {"register": Color("ffc23d"), "dish": Color("5fc4ff"), "hall": Color("a98bff"), "kitchen": Color("ff7a45"), "stock": Color("e8b878"), "rare": Color("fff2a8")}


func species_for_type(t: String) -> String:
	return TYPE_SPECIES.get(t, "receipt")


## 今夜の水面に出る玉。今日の仕事の種類が多めに出る。1晩3〜5個。
func tonight_orbs() -> Array:
	var s: Dictionary = today() if day < WEEK.size() else {}
	var types := ["register", "dish", "hall", "kitchen", "stock"]
	var out: Array = []
	var n := randi_range(3, 5)
	for i in n:
		var t: String = types.pick_random()
		if s.get("role", "") != "" and randf() < 0.45:
			t = s.role
		var rare: bool = randf() < (0.25 if s.get("first", false) else 0.08)
		out.append({"type": "rare" if rare else t, "rare": rare, "weight": 0.55 if rare else randf_range(0.25, 0.4)})
	return out


## ポイの破れにくさ（睡眠で決まる）
func poi_strength() -> float:
	return net_strength


## レアの条件を判定するための、その日とここまでの記録のまとめ
func rare_context(s: Dictionary, hours: int) -> Dictionary:
	var worked: bool = s.get("role", "") != ""
	var streak := 0
	for d in range(day - 1, -1, -1):
		if WEEK[d].role == "":
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
	var total := 0.0
	for h in sleep_hist:
		total += h
	return {
		"shift": s,
		"sleep": hours,
		"sleep_hist": sleep_hist,
		"first_role": worked and first_role_today and day > 0,
		"roles_seen": roles_seen.size(),
		"stores_week": stores_week.size(),
		"new_coworker": new_co and day > 0,
		"morning_shifts": morning_shifts,
		"day_and_night": bands_week.has("昼") and (bands_week.has("夜") or bands_week.has("深夜")),
		"same_coworker_max": same_max,
		"gifted": gifted,
		"received": received,
		"battle_won": battle_won and day == BATTLE_DAY,
		"worked_streak_before": streak if not worked else 0,
		"weekend_both": false,
		"normal_all": normal_all,
		"zukan_count": seen.size(),
		"avg_sleep_month": total / max(1, sleep_hist.size()),
		"nights": sleep_hist.size(),
	}
