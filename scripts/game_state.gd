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
	"lantern": {"name": "ヨミセ", "type": "night", "desc": "夜ふかしの人のそばにだけ出る"},
	"kirari": {"name": "キラリ", "type": "rare", "desc": "はじめての経験をした日にだけ光る"},
	"nemuri": {"name": "ネムリン", "type": "sleep", "desc": "よく眠った朝、仕掛けた網で寝ている"},
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
	{"day": "月", "store": "カフェ こもれび", "role": "register", "band": "朝", "hours": 4, "first": false},
	{"day": "火", "store": "居酒屋 とりまる", "role": "hall", "band": "夜", "hours": 5, "first": false},
	{"day": "水", "store": "", "role": "", "band": "", "hours": 0, "first": false},
	{"day": "木", "store": "居酒屋 とりまる", "role": "dish", "band": "夜", "hours": 4, "first": true},
	{"day": "金", "store": "北倉庫", "role": "stock", "band": "深夜", "hours": 6, "first": true},
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


func _ready() -> void:
	reset()


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
	changed.emit()


func today() -> Dictionary:
	return WEEK[day]


## シフトを終えたときに網を受け取る。働いた時間の分だけ増える（2時間で1本）。
func finish_shift() -> Array:
	var s := today()
	var got: Array = []
	if s.role == "":
		return got
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
	var sp: Dictionary = SPECIES[species_id]
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
	morning_report.append("%d時間ねた → 網を振れる回数 %d、網の強さ ×%.2f" % [hours, stamina, net_strength])
	for o in owned:
		o.xp += hours * 6
		if _level_up(o):
			morning_report.append("%s が Lv%d に育った" % [SPECIES[o.id].name, o.level])
	if trap_net != "" and nets.get(trap_net, 0) > 0:
		nets[trap_net] -= 1
		var caught := _trap_result(trap_net, hours)
		if caught == "":
			morning_report.append("仕掛けた%sは、からっぽだった" % NETS[trap_net].name)
		else:
			var is_new := add_obake(caught)
			morning_report.append("仕掛けた網に %s がかかっていた%s" % [SPECIES[caught].name, "（はじめて！）" if is_new else ""])
	day += 1
	phase = "morning"
	changed.emit()


func _trap_result(net_id: String, hours: int) -> String:
	var r := randf()
	if hours >= 7 and r < 0.6:
		return "nemuri"
	if hours <= 5 and r < 0.5:
		return "lantern"
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
