extends Node
## ゲーム全体の状態と決まりごと（C案：大ピーク防衛）。
## ゲームの芯は「店の困りごとから、おばけのみんなで店を守る」レーンバトル。
## 現実の記録はブースト：シフト → その店の戦いで開始やる気と、その仕事のおばけが強くなる／ポイが増える。
## 睡眠 → おばけが育つ（経験値）・明日のやる気のたまりが速くなる。どちらも上限あり（長く働くほど得、にはしない）。
## 記録がなくても、ステージ・強化・すくいで遊べる。

signal changed

var SAVE_PATH := "user://obake_c.json"
const SAVE_VERSION := 1

const SPECIES := {
	"receipt": {"name": "レシートン", "type": "register", "desc": "レジの音に寄ってくる。レシートの尻尾が長いほど長生き"},
	"bubble": {"name": "アワワ", "type": "dish", "desc": "洗い場の泡から生まれる。割れても平気"},
	"tray": {"name": "オボン", "type": "hall", "desc": "頭のお盆は絶対に落とさない"},
	"pan": {"name": "ジュウ", "type": "kitchen", "desc": "油の跳ねる音が好き。少しあつい"},
	"box": {"name": "ダンボ", "type": "stock", "desc": "箱から出たがらない。重いものが得意"},
}

const NETS := {
	"plain": {"name": "まかないポイ", "type": "plain"},
	"receipt": {"name": "レシート網", "type": "register"},
	"bubble": {"name": "泡の網", "type": "dish"},
	"tray": {"name": "お盆網", "type": "hall"},
	"pan": {"name": "フライパン網", "type": "kitchen"},
	"box": {"name": "段ボール網", "type": "stock"},
	"kira": {"name": "きらきら網", "type": "rare"},
}

const ROLE_LABEL := {"register": "レジ", "dish": "皿洗い", "hall": "ホール", "kitchen": "キッチン", "stock": "品出し"}
const ROLE_NET := {"register": "receipt", "dish": "bubble", "hall": "tray", "kitchen": "pan", "stock": "box"}
const DAYS := ["月", "火", "水", "木", "金", "土", "日"]

## 見本の1週間（みか、大学2年）。6日目からは記録をつくって続ける（本番ではサーバーの記録）。
const WEEK := [
	{"day": "月", "store": "カフェ こもれび", "role": "register", "band": "朝", "hours": 4, "first": false, "weather": "晴", "moon": "", "season": "秋", "coworkers": ["さとう", "りん"], "newbie": false},
	{"day": "火", "store": "居酒屋 とりまる", "role": "hall", "band": "夜", "hours": 5, "first": false, "weather": "雨", "moon": "", "season": "秋", "coworkers": ["けん", "ようこ"], "newbie": false},
	{"day": "水", "store": "", "role": "", "band": "", "hours": 0, "first": false, "weather": "晴", "moon": "", "season": "秋", "coworkers": [], "newbie": false},
	{"day": "木", "store": "居酒屋 とりまる", "role": "dish", "band": "夜", "hours": 4, "first": false, "weather": "晴", "moon": "満月", "season": "秋", "coworkers": ["けん", "みお"], "newbie": true},
	{"day": "金", "store": "北倉庫", "role": "stock", "band": "深夜", "hours": 6, "first": true, "weather": "雷", "moon": "", "season": "秋", "coworkers": ["だいち"], "newbie": false},
]
const STORE_ROLES := {"カフェ こもれび": ["register", "hall", "kitchen", "dish"], "居酒屋 とりまる": ["hall", "dish", "kitchen", "register"], "北倉庫": ["stock"]}
const STORE_BANDS := {"カフェ こもれび": ["朝", "昼"], "居酒屋 とりまる": ["夜"], "北倉庫": ["深夜", "昼"]}
const COWORKERS := ["さとう", "りん", "けん", "ようこ", "みお", "だいち", "はる", "そら"]

## 上限：これ以上働いても・寝ても、ブーストは増えない
const SHIFT_CAP_H := 4
const SLEEP_CAP_H := 8
const MAX_LV := 20

var day := 0
var phase := "morning" # morning → room → (shift) → catch → sleep → morning
var nets := {}
var net_strength := 1.0
var last_sleep := 7
var owned: Array = [] # {id, level, xp}
var seen := {}
var morning_report: Array = []
var orbs: Array = [] # すくった光る玉 {type, rare}。朝に割れておばけになる
var hatched: Array = []
var scooped_tonight := false
var ALL := {}
var sleep_hist: Array = []
var roles_seen := {}
var stores_week := {}
var coworker_count := {}
var morning_shifts := 0
var bands_week := {}
var weekend_days := {}
var first_role_today := false
var gifted := false
var received := false
var rare_pending: Array = []
const RARES_PER_NIGHT := 2

# ---- 防衛 ----
var coins := 0 # まかない（強化に使う）
var deck: Array = [] # 出撃するおばけの id（最大 DECK_MAX）
const DECK_MAX := 7
var cleared := {} # "店-ステージ" → クリア回数
var best_lap := 1 # 何周目まで開いたか
var lap := 1 # いま挑んでいる周
var boost := {} # 今日のシフトの応援 {store, role, hours}
var shift_done_today := false
var regen_bonus := 1.0 # 昨夜の睡眠で決まる、今日のやる気のたまり
var boss_won_today := false
var boss_wins := 0
var tutorial := {} # 見せたチュートリアル
var battles_today := 0
var wins_today := 0
var daily_done := false
var consolation_done := false
var daily_pick: Array = [] # [日, 店, 面]
var perfect := {} # お店を無傷で守った面（周回つきのキー）
var focus := "" # 育てたい一体。その日の最初の勝ちで経験値 +FOCUS_XP
const FOCUS_XP := 40
var total_battles := 0
var last_result := {} # 直前の戦いの結果（結果画面が読む）
var pending_battle := {} # これから戦うステージ {shop, stage}
var enemies_seen := {} # 会った困りごと（図鑑）


func _ready() -> void:
	for id in SPECIES:
		ALL[id] = SPECIES[id]
	for r in Rares.LIST:
		ALL[r.id] = {"name": r.name, "type": "rare", "desc": r.desc, "hint": r.hint, "group": r.group}
	if OS.get_environment("OBAKE_SAVE") != "":
		SAVE_PATH = OS.get_environment("OBAKE_SAVE")
	reset()
	if OS.get_environment("OBAKE_FRESH") == "" and OS.get_environment("OBAKE_DEMO") == "":
		load_game()


func info(id: String) -> Dictionary:
	return ALL.get(id, {"name": id, "type": "", "desc": ""})


func reset() -> void:
	day = 0
	phase = "morning"
	nets = {"plain": 2, "receipt": 0, "bubble": 0, "tray": 0, "pan": 0, "box": 0, "kira": 0}
	net_strength = 1.0
	last_sleep = 7
	owned = [{"id": "receipt", "level": 1, "xp": 0}, {"id": "box", "level": 1, "xp": 0}]
	seen = {"receipt": true, "box": true}
	morning_report = []
	orbs = []
	hatched = []
	scooped_tonight = false
	sleep_hist = []
	roles_seen = {}
	stores_week = {}
	coworker_count = {}
	morning_shifts = 0
	bands_week = {}
	weekend_days = {}
	first_role_today = false
	gifted = false
	received = false
	rare_pending = []
	coins = 0
	deck = ["receipt", "box"]
	cleared = {}
	best_lap = 1
	lap = 1
	boost = {}
	shift_done_today = false
	regen_bonus = 1.0
	boss_won_today = false
	boss_wins = 0
	tutorial = {}
	battles_today = 0
	wins_today = 0
	daily_done = false
	consolation_done = false
	total_battles = 0
	last_result = {}
	pending_battle = {}
	enemies_seen = {}
	daily_pick = []
	focus = ""
	perfect = {}
	changed.emit()


# ---------- 日々の記録 ----------

func weekday(d := -1) -> String:
	return DAYS[(day if d < 0 else d) % 7]


func week_no() -> int:
	return day / 7 + 1


## その日のシフトの記録。見本の5日のあとは、同じ人の暮らしっぽく作って続ける。
func shift_for(d: int) -> Dictionary:
	if d < WEEK.size():
		return WEEK[d]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * d + 17
	var wd: String = DAYS[d % 7]
	var s := {"day": wd, "store": "", "role": "", "band": "", "hours": 0, "first": false, "weather": "晴", "moon": "", "season": _season(d), "coworkers": [], "newbie": false}
	var w := rng.randf()
	s.weather = "雨" if w < 0.2 else ("雷" if w < 0.26 else ("雪" if w < 0.3 and s.season == "冬" else "晴"))
	if (d + 10) % 29 == 0:
		s.moon = "満月"
	# 週に4日くらい働く。水曜と日曜は休みがち
	var work_p := 0.25 if wd in ["水", "日"] else 0.72
	if rng.randf() < work_p:
		var stores: Array = STORE_ROLES.keys()
		var store: String = stores[rng.randi() % stores.size()]
		var roles: Array = STORE_ROLES[store]
		s.store = store
		s.role = roles[rng.randi() % roles.size()]
		s.band = STORE_BANDS[store][rng.randi() % STORE_BANDS[store].size()]
		s.hours = rng.randi_range(3, 7)
		s.first = rng.randf() < 0.1
		s.newbie = rng.randf() < 0.12
		var n := rng.randi_range(1, 2)
		for i in n:
			var c: String = COWORKERS[rng.randi() % COWORKERS.size()]
			if not c in s.coworkers:
				s.coworkers.append(c)
	return s


func _season(d: int) -> String:
	return ["秋", "秋", "冬", "冬", "春", "春", "夏", "夏"][(d / 21) % 8]


func today() -> Dictionary:
	return shift_for(day)


## シフトの記録を受け取る（1日1回）。ポイと、その店の戦いへの応援がもらえる。
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
	if weekday() in ["土", "日"]:
		weekend_days[weekday()] = true
	if s.band == "朝":
		morning_shifts += 1
	for c in s.coworkers:
		coworker_count[c] = coworker_count.get(c, 0) + 1
	var net_id: String = ROLE_NET[s.role]
	# 何時間働いても同じ（長く働くほど得、にしない）
	var h: int = min(s.hours, SHIFT_CAP_H)
	var n := 2
	nets[net_id] += n
	got.append("%s ×%d" % [NETS[net_id].name, n])
	if s.first:
		nets["kira"] += 1
		got.append("きらきら網 ×1（はじめての経験）")
	boost = {"store": s.store, "role": s.role, "hours": h}
	changed.emit()
	save_game()
	return got


## 戦いのブースト。shop_id の店で働いた日なら、開始やる気とその仕事のおばけが強くなる。
func battle_boost(shop_id: String) -> Dictionary:
	var b := {"regen": regen_bonus, "start_energy": 0.0, "job": "", "job_mult": 1.0, "lines": [], "weekly": DefData.weekly(week_no())}
	if not b.weekly.is_empty():
		b.lines.append("今週のお題「%s」：%s" % [b.weekly.name, b.weekly.desc])
	if regen_bonus > 1.0:
		b.lines.append("よく寝た：やる気のたまり ×%.2f" % regen_bonus)
	if boost.is_empty():
		return b
	var here: bool = DefData.STORE_SHOP.get(boost.store, "") == shop_id or (shop_id == "peak")
	b.job = boost.role
	if here:
		b.start_energy = 200.0
		b.job_mult = 1.3
		b.lines.append("%sで働いた：はじめのやる気 +%d" % [boost.store, int(b.start_energy)])
		b.lines.append("%sのおばけ ×1.3" % ROLE_LABEL[boost.role])
	else:
		b.job_mult = 1.1
		b.lines.append("%sの仕事をした：%sのおばけ ×1.1" % [ROLE_LABEL[boost.role], ROLE_LABEL[boost.role]])
	return b


# ---------- おばけ ----------

func add_obake(species_id: String) -> bool:
	var is_new := not seen.has(species_id)
	seen[species_id] = true
	for o in owned:
		if o.id == species_id:
			o.xp += 30
			_level_up(o)
			changed.emit()
			return is_new
	# あとから来た仲間も、すぐ戦えるように：編成のまん中の Lv − 1（最大10）
	var start_lv := 1
	var lvs: Array = []
	for o in owned:
		lvs.append(o.level)
	if not lvs.is_empty():
		lvs.sort()
		start_lv = clampi(int(lvs[lvs.size() / 2]) - 1, 1, 10)
	owned.append({"id": species_id, "level": start_lv, "xp": 0})
	if deck.size() < DECK_MAX and not DefData.unit(species_id).is_empty():
		deck.append(species_id)
	changed.emit()
	return is_new


func owned_of(id: String) -> Dictionary:
	for o in owned:
		if o.id == id:
			return o
	return {}


func _level_up(o: Dictionary) -> bool:
	var up := false
	while o.level < MAX_LV and o.xp >= DefData.xp_need(o.level):
		o.xp -= DefData.xp_need(o.level)
		o.level += 1
		up = true
	if o.level >= MAX_LV:
		o.xp = 0
	return up


## まかないで強化する値段。寝て経験値がたまっているほど安い。
func upgrade_cost(id: String) -> int:
	var o := owned_of(id)
	if o.is_empty() or o.level >= MAX_LV:
		return -1
	var left: int = DefData.xp_need(o.level) - o.xp
	return int(ceil(left * 2.5))


func upgrade(id: String) -> bool:
	var c := upgrade_cost(id)
	if c < 0 or coins < c:
		return false
	coins -= c
	var o := owned_of(id)
	o.xp = DefData.xp_need(o.level)
	_level_up(o)
	changed.emit()
	save_game()
	return true


func toggle_deck(id: String) -> bool:
	if id in deck:
		if deck.size() <= 1:
			return false
		deck.erase(id)
	else:
		if deck.size() >= DECK_MAX:
			return false
		deck.append(id)
	changed.emit()
	save_game()
	return true


func deck_for_battle() -> Array:
	var out: Array = []
	for id in deck:
		var o := owned_of(id)
		if not o.is_empty():
			out.append({"id": id, "lv": o.level})
	return out


# ---------- ステージ ----------

func is_cleared(si: int, st: int, l := -1) -> bool:
	return cleared.get(DefData.stage_key(si, st, lap if l < 0 else l), 0) > 0


func is_perfect(si: int, st: int) -> bool:
	return perfect.has(DefData.stage_key(si, st, lap))


func clear_count(si: int, st: int) -> int:
	return int(cleared.get(DefData.stage_key(si, st, lap), 0))


## 今日のお手伝い：ひらいているステージから日替わりで1つ。その日の最初の勝ちに +60
func daily_stage() -> Array:
	# その日の最初に決めたら、1日変えない
	if daily_pick.size() == 3 and int(daily_pick[0]) == day:
		return [int(daily_pick[1]), int(daily_pick[2])]
	var open: Array = []
	for si in DefData.SHOPS.size():
		for st in DefData.shop(si).stages.size():
			if is_open(si, st) and is_cleared(si, st):
				open.append([si, st])
	if open.is_empty():
		return []
	var pick: Array = open[(day * 7 + 3) % open.size()]
	daily_pick = [day, pick[0], pick[1]]
	return pick


## そのステージに挑めるか（前のステージを越えたら開く）
func is_open(si: int, st: int) -> bool:
	if si == 0 and st == 0:
		return true
	if st > 0:
		return is_cleared(si, st - 1)
	var prev: Dictionary = DefData.shop(si - 1)
	return is_cleared(si - 1, prev.stages.size() - 1)


func next_stage() -> Array:
	for si in DefData.SHOPS.size():
		for st in DefData.shop(si).stages.size():
			if not is_cleared(si, st):
				return [si, st]
	return [DefData.SHOPS.size() - 1, 0]


## 戦いの結果を記録して、ごほうびを返す
func record_battle(si: int, st: int, won: bool, stats: Dictionary) -> Dictionary:
	battles_today += 1
	total_battles += 1
	var key := DefData.stage_key(si, st, lap)
	var stg: Dictionary = DefData.stage(si, st)
	var r := {"won": won, "shop": si, "stage": st, "coins": 0, "first": false, "orb": false, "lap_up": false, "stats": stats, "daily": false, "join": ""}
	if won:
		var first: bool = cleared.get(key, 0) == 0
		var base: int = int(stg.reward * DefData.lap_mult(lap) * (1.5 if stg.get("boss_stage", false) and weekday() == "金" else 1.0))
		# くり返しは半分、その日4勝目からは4分の1（何度でも遊べるが、稼ぎは逓減）
		var mult := 1.0 if first else (0.5 if wins_today < 3 else 0.25)
		r.coins = int(base * mult)
		var ds := daily_stage()
		if not first and not daily_done and not ds.is_empty() and ds[0] == si and ds[1] == st:
			daily_done = true
			r.coins += 60
			r.daily = true
		r.first = first
		# お店が無傷なら★（はじめての★で +30%）
		if stats.get("base", 0.0) >= 0.999 and not perfect.has(key):
			perfect[key] = true
			r["perfect"] = true
			r.coins += int(base * 0.3)
		if wins_today == 0 and focus != "" and not owned_of(focus).is_empty():
			var fo := owned_of(focus)
			fo.xp += FOCUS_XP
			_level_up(fo)
			r["focus"] = focus
		wins_today += 1
		cleared[key] = cleared.get(key, 0) + 1
		if first and st == DefData.shop(si).stages.size() - 1:
			orbs.append({"type": "rare", "rare": true})
			r.orb = true
		# 最初の2面で、戦い方を教える仲間が加わる
		if first and lap == 1 and si == 0 and st <= 1:
			var jid := "tray" if st == 0 else "bubble"
			if not seen.has(jid):
				add_obake(jid)
				r.join = jid
		if stg.get("boss_stage", false):
			boss_won_today = true
			boss_wins += 1
			if lap == best_lap:
				best_lap += 1
				r.lap_up = true
	elif not stats.get("retreat", false) and stats.get("time", 0.0) >= 30.0 and stats.get("kills", 0) >= 3 and not consolation_done:
		# ちゃんと戦って負けたら、1日1回だけ少しもらえる（詰まないように。すぐ帰るのは0）
		consolation_done = true
		r.coins = int(stg.reward * 0.2)
	coins += r.coins
	last_result = r
	changed.emit()
	save_game()
	return r


# ---------- すくいと睡眠 ----------

func poi_strength() -> float:
	return net_strength


const TYPE_SPECIES := {"register": "receipt", "dish": "bubble", "hall": "tray", "kitchen": "pan", "stock": "box", "sleep": "nemurin", "night": "yomise", "rare": "kirari"}
const TYPE_COLOR := {"register": Color("ffc23d"), "dish": Color("5fc4ff"), "hall": Color("a98bff"), "kitchen": Color("ff7a45"), "stock": Color("e8b878"), "rare": Color("fff2a8"), "plain": Color("f4efe6")}


func species_for_type(t: String) -> String:
	return TYPE_SPECIES.get(t, "receipt")


## 今夜の水面に出る玉。今日の仕事の種類が多めに出る。まだ持っていない種類も混ぜる。1晩3〜5個。
func tonight_orbs() -> Array:
	var s: Dictionary = today()
	var types := ["register", "dish", "hall", "kitchen", "stock"]
	var missing: Array = []
	for t in types:
		if not seen.has(TYPE_SPECIES[t]):
			missing.append(t)
	var out: Array = []
	var n := randi_range(3, 5)
	for i in n:
		var t: String = types.pick_random()
		if s.get("role", "") != "" and randf() < 0.4:
			t = s.role
		elif not missing.is_empty() and randf() < 0.5:
			t = missing.pick_random()
		var rare: bool = randf() < (0.25 if s.get("first", false) else 0.08)
		out.append({"type": "rare" if rare else t, "rare": rare, "weight": 0.55 if rare else randf_range(0.25, 0.4)})
	return out


## 寝る。睡眠時間で、おばけの成長・明日のやる気のたまり・ポイの強さが決まる。
func sleep(hours: int, _trap := "") -> void:
	last_sleep = hours
	var h: int = min(hours, SLEEP_CAP_H)
	if hours < 6:
		net_strength = 1.0
		regen_bonus = 1.0
	elif hours < 7:
		net_strength = 1.0
		regen_bonus = 1.1
	else:
		net_strength = 1.25
		regen_bonus = 1.25
	morning_report = []
	morning_report.append("%d時間ねた → 今日のやる気のたまり ×%.2f" % [hours, regen_bonus])
	var ups: Array = []
	for o in owned:
		o.xp += h * 6
		if _level_up(o):
			ups.append("%s Lv%d" % [info(o.id).name, o.level])
	if not ups.is_empty():
		morning_report.append("寝ているあいだに育った：" + "、".join(ups))
	hatched = []
	sleep_hist.append(hours)
	var s: Dictionary = today()
	var have := seen.duplicate()
	for rid in rare_pending:
		have[rid] = true
	var fresh: Array = Rares.check(rare_context(s, hours), have)
	rare_pending = fresh + rare_pending
	for i in min(RARES_PER_NIGHT, rare_pending.size()):
		var rid: String = rare_pending.pop_front()
		add_obake(rid)
		hatched.append({"id": rid, "is_new": true, "level": 1, "rare": true})
	# すくった光る玉は、ふつうのおばけに。虹の玉は、まだいない種類を優先して大きく育つ
	for orb in orbs:
		var sid: String
		if orb.type == "rare":
			var pool: Array = []
			for id in SPECIES:
				if not seen.has(id):
					pool.append(id)
			# 虹色の玉：まだいないふつうのおばけ → みんないたら、まだ会っていないレア
			if pool.is_empty():
				for r in Rares.LIST:
					if not seen.has(r.id) and not r.id in rare_pending:
						pool.append(r.id)
			sid = pool.pick_random() if not pool.is_empty() else SPECIES.keys().pick_random()
		else:
			sid = species_for_type(orb.type)
		var is_new := add_obake(sid)
		var o := owned_of(sid)
		o.xp += h * 4 + (60 if orb.rare else 0)
		_level_up(o)
		hatched.append({"id": sid, "is_new": is_new, "level": o.level, "rare": Rares.is_rare(sid)})
	if orbs.size() > 0:
		morning_report.append("光る玉が %d 個、朝日で割れた" % orbs.size())
	orbs = []
	scooped_tonight = false
	# 次の日へ
	day += 1
	if day % 7 == 0:
		var wk := DefData.weekly(week_no())
		if not wk.is_empty():
			morning_report.append("%d週目のお題「%s」：%s" % [week_no(), wk.name, wk.desc])
		stores_week = {}
		bands_week = {}
		weekend_days = {}
	phase = "morning"
	boost = {}
	shift_done_today = false
	boss_won_today = false
	battles_today = 0
	wins_today = 0
	daily_done = false
	consolation_done = false
	nets["plain"] = max(nets["plain"], 2) # 毎日、まかないポイが2本まで戻る
	changed.emit()
	save_game()


## レアの条件を判定するための、その日とここまでの記録のまとめ
func rare_context(s: Dictionary, hours: int) -> Dictionary:
	var worked: bool = s.get("role", "") != "" and shift_done_today
	var streak := 0
	for d in range(day - 1, -1, -1):
		if shift_for(d).role == "":
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
		"shift": s if worked else {},
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
		"battle_won": boss_won_today,
		"worked_streak_before": streak if not worked else 0,
		"weekend_both": weekend_days.size() >= 2,
		"normal_all": normal_all,
		"zukan_count": seen.size(),
		"avg_sleep_month": total / max(1, sleep_hist.size()),
		"nights": sleep_hist.size(),
	}


# ---------- セーブ ----------

const SAVE_KEYS := ["day", "phase", "nets", "net_strength", "last_sleep", "owned", "seen", "morning_report", "orbs", "hatched",
	"scooped_tonight", "sleep_hist", "roles_seen", "stores_week", "coworker_count", "morning_shifts", "bands_week", "weekend_days",
	"first_role_today", "gifted", "received", "rare_pending", "coins", "deck", "cleared", "best_lap", "lap", "boost",
	"shift_done_today", "regen_bonus", "boss_won_today", "boss_wins", "tutorial", "battles_today", "total_battles", "wins_today", "daily_done", "consolation_done", "enemies_seen", "daily_pick", "focus", "perfect"]


func save_game() -> void:
	if OS.get_environment("OBAKE_DEMO") != "":
		return
	var d := {"version": SAVE_VERSION}
	for k in SAVE_KEYS:
		d[k] = get(k)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("セーブできませんでした: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(d))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var txt := FileAccess.get_file_as_string(SAVE_PATH)
	var d = JSON.parse_string(txt)
	if typeof(d) != TYPE_DICTIONARY or int(d.get("version", 0)) != SAVE_VERSION:
		push_warning("セーブが読めないので、はじめから")
		return false
	for k in SAVE_KEYS:
		if d.has(k):
			var v = d[k]
			# JSON は数を float にするので、整数のものは戻す
			if typeof(get(k)) == TYPE_INT:
				v = int(v)
			set(k, v)
	for o in owned:
		o.level = int(o.level)
		o.xp = int(o.xp)
	for k in nets:
		nets[k] = int(nets[k])
	for k in cleared:
		cleared[k] = int(cleared[k])
	for k in coworker_count:
		coworker_count[k] = int(coworker_count[k])
	for i in sleep_hist.size():
		sleep_hist[i] = int(sleep_hist[i])
	if boost.has("hours"):
		boost.hours = int(boost.hours)
	for h in hatched:
		h.level = int(h.level)
	changed.emit()
	return true


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func wipe_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	reset()
