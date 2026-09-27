extends Node
## ゲーム全体の状態と決まりごと。
## 毎日の暮らし（働いた日・休んだ日・夜のすくい・めあて）で、夜の庭が育つ。働きすぎを止めるのは、猫が疲れることだけ（WorkTogether）。
## 仕事はブースト：シフトの日は種類つきのポイと、その仕事にちなんだ庭の飾りが届く（時間の長さでは増えない）。
## 夜にすくった玉は、次の朝にかえる（寝る時刻などの入力は無い。end_night() で朝になる）。
## 記録がなくても（ひとりで遊ぶ）毎日の夜が来る。見本の記録（mode = data）ではシフトが自動で入る。

signal changed
signal goal_completed(text: String, all_done: bool)
## 一緒に働いた時間が終わった（WorkTogether が出す）。ふりかえり画面はこれを受けるか、last_shift_ended を見る
signal shift_ended(summary: Dictionary)

const SAVE_PATH := "user://obake_b_save.json"

const SPECIES := {
	"receipt": {"name": "レシートン", "type": "register", "desc": "レジの音に寄ってくる。尻尾のレシートは、捨てないでほしいらしい"},
	"bubble": {"name": "アワワ", "type": "dish", "desc": "洗い場の泡から生まれる。割れても平気。割れても"},
	"tray": {"name": "オボン", "type": "hall", "desc": "頭のお盆は絶対に落とさない。中身は気にしない"},
	"pan": {"name": "ジュウ", "type": "kitchen", "desc": "油の跳ねる音が好き。さわると少しあつい。本人は言わない"},
	"box": {"name": "ダンボ", "type": "stock", "desc": "住居です。資源ごみに出さないでください"},
	"lantern": {"name": "チョウチン", "type": "night", "desc": "満月の夜の灯りに寄ってくる。提灯の中は、ほんのりあたたかい"},
}
const NORMAL := ["receipt", "bubble", "tray", "pan", "box", "lantern"]

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

## 庭の育ち。めぐみ（毎朝、きのうの暮らしで溜まる）がこの値をこえると、庭が一段育つ。
const GARDEN := [
	{"need": 0, "name": "さびしい庭", "desc": "土と、灯っていない灯籠がひとつ"},
	{"need": 8, "name": "芝が生えた", "desc": "足もとがやわらかくなった"},
	{"need": 26, "name": "花壇に芽が出た", "desc": "かかしが見張りに立った。真顔で"},
	{"need": 52, "name": "灯籠がともった", "desc": "庭がほんのり明るくなった"},
	{"need": 88, "name": "花が咲いた", "desc": "毎日の暮らしで、花がひらく"},
	{"need": 132, "name": "小さな池ができた", "desc": "月が映るようになった"},
	{"need": 185, "name": "縁台が置かれた", "desc": "おじぞうも来て、並んで座った"},
	{"need": 250, "name": "桜の木が育った", "desc": "いつ見ても、少しだけ咲いている"},
	{"need": 325, "name": "ほたるが住みついた", "desc": "にぎやかな夜は、数が増える"},
	{"need": 410, "name": "月見台ができた", "desc": "満月の特等席。ねぶくろが先に来ていた"},
	{"need": 505, "name": "星見の木が光った", "desc": "毎日を大切にした庭にだけ育つ木"},
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
## 毎朝のめぐみ（庭の育ち）：いつもの分 ＋ 働いた日 ＋ 川べりに行った夜。時間の長さでは増えない
const GROW_DAY := 6
const GROW_WORKED := 3
const GROW_RIVER := 2

var mode := "data" # data = 記録をつなぐ（見本）, solo = ゲームだけ
var seed_base := 0
var day := 0
var phase := "day" # day → evening → 夜のおわり（end_night）→ 朝の孵化 → day
var nets := {}
var owned: Array = [] # {id, level, xp}
var seen := {}
var orbs: Array = [] # すくった光る玉 {type, rare}。朝に割れておばけになる
var hatched: Array = [] # 今朝割れた玉 {id, is_new, level, rare}
var scooped_tonight := false
var ALL := {}

# 眠りのリズム
var river_hist: Array = [] # その夜、川べりですくったか（満月の灯りに使う）
var last_night := {} # 朝に見せる、きのうのまとめ {growth_gain, level_before, worked, river}
var friend_visits := 0 # 友だちの島におでかけした回数
var store_count := {} # 店 → 働いた回数（同じ店にまた入った日に）

# 庭
var growth := 0
var garden_level := 0
var garden_seen_level := 0 # 朝の演出で見せ終わった段
var decos := {} # role → 届いた回数
var deco_store := {} # role → 飾りをくれた店
var chores := {} # ひとりのときのおてつだいの回数
var new_decos: Array = [] # 今日届いた飾り（庭で演出する）
var dream_flowers := 0 # 満開のあとに咲く星見草（めぐみ 80 ごとに一輪）

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
var night_plan := "" # 使わない（互換のため）
var lit_deco := "" # 今夜ともす飾り（その仕事の玉が出やすい）
var goals: Array = [] # 今日のめあて {id, text, done}
var last_goals := 0
var stall_claimed := false
var stash := {} # 玉から出た材料と服 "kind:id" → 数（Drops.grant が数える）
var last_new_cat_day := 0 # 最後に新しいおばネコがかえった日（Drops.CAT_PITY_NIGHTS の数え始め）

# ---------- 島（自分たちの島をつくって、シェアする） ----------
var layout := {} # 島の物の置き場所 key → {x, z, r(45°単位), h(しまった)}
var nickname := ""
var host_id := "" # 島のあるじ（マイおばけ猫が決まったら、ここに入れる）。空なら最初の子
var keepsakes: Array = [] # おでかけ先に置いてきたおばけ {owner, id, day}
var visit := {} # いま、おでかけ中の島（空なら自分の島）
var new_outfits: Array = [] # 光る玉から出た服（朝、庭で見せる）
var my_obake := {} # マイおばけ猫 {type_id, look, answers, axes}。正本は user://my_obake.json
var week_start_seen := 1
var pending_toasts: Array = [] # 夜のあいだに達成しためあての知らせ
var week_start_growth := 0
var quiet := false # 早送り中は知らせを出さない
var newcomers: Array = [] # けさ初めて来た子（庭で縁側から出てくる）
var work_hist: Array = [] # その日に実際に働いたか
var tonight_caught := 0
var moon_won_saved := false
var last_shift_ended := {} # 最後に終わった「一緒に働く」のまとめ（ふりかえり用の目印）
var work_nets_day := -1 # 一緒に働いてポイをもらった日（1日1回）
var rest_net_day := -1 # 休みの日のポイ 1 本をもらった日
var clock_date := "" # 実際の日付（朝 5 時で区切る）。次の日付の朝が来たら、夜が明ける（sync_clock）
var skip_shift_day := -1 # 見本の記録のシフトを「今日は休む」にした日


func _ready() -> void:
	for id in SPECIES:
		ALL[id] = SPECIES[id]
	for r in Rares.LIST:
		ALL[r.id] = {"name": r.name, "type": "rare", "desc": r.desc, "hint": r.hint, "group": r.group}
	reset()
	my_obake = QuizResult.load_result()


func info(id: String) -> Dictionary:
	return ALL.get(id, {"name": id, "type": "", "desc": ""})


func reset(new_mode := "data") -> void:
	work_nets_day = -1
	rest_net_day = -1
	clock_date = ""
	skip_shift_day = -1
	last_shift_ended = {}
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
	river_hist = []
	last_night = {}
	friend_visits = 0
	store_count = {}
	growth = 0
	garden_level = 0
	garden_seen_level = 0
	decos = {}
	deco_store = {}
	chores = {}
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
	week_start_seen = 1
	week_start_growth = 0
	pending_toasts = []
	layout = {}
	stash = {}
	last_new_cat_day = 0
	host_id = ""
	keepsakes = []
	visit = {}
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
	return tr("%d週目 %s曜日") % [week() + 1, tr(WEEKDAYS[weekday()])]


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
		s.coworkers = []
		s.first = false
		s.newbie = false
		# ひとりのときは、庭のおてつだい（仕事の代わり。ポイ1本、飾りは届かない）
		if d > 0 and rng.randf() < 0.45:
			s.role = ["register", "hall", "dish", "kitchen", "stock"][rng.randi() % 5]
			# 場所・時間帯・いっしょに手伝う近所のおばけ（ひとりでも、ゆっくり出会える）
			s.store = ["庭のおてつだい", "となりの庭", "川べりの番小屋"][rng.randi() % 3]
			s.band = ["朝", "昼", "昼", "夜", "深夜"][rng.randi() % 5]
			s.hours = 1
			s.first = rng.randf() < 0.06
			if rng.randf() < 0.5:
				s.coworkers = [["ぬらりさん", "こだまくん", "ろくろさん"][rng.randi() % 3]]
				s.newbie = rng.randf() < 0.1
			s["chore"] = true
	s["day"] = WEEKDAYS[wd]
	s["moon"] = "満月" if wd == 6 else ""
	s["season"] = season()
	return s


func today() -> Dictionary:
	return shift_for(day)


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
	store_count[s.store] = int(store_count.get(s.store, 0)) + 1
	bands_week[s.band] = true
	if s.band == "朝":
		morning_shifts += 1
	if weekday() >= 5:
		weekend_shifts[weekday()] = true
	for c in s.coworkers:
		coworker_count[c] = coworker_count.get(c, 0) + 1
	var net_id: String = ROLE_NET[s.role]
	if s.get("chore", false):
		# おてつだいの日は、シフトの無い日と同じく 1 本（はじめてなら、それがきらきら）
		var cid: String = "kira" if first_role_today else net_id
		nets[cid] = mini(nets[cid] + 1, 4)
		got.append({"kind": "poi", "id": cid, "n": 1, "text": "%s ×1" % tr(NETS[cid].name)})
		# おてつだい 2 回で、その仕事の飾りが（手作りで）届く
		chores[s.role] = chores.get(s.role, 0) + 1
		if chores[s.role] == 2 and decos.get(s.role, 0) == 0:
			decos[s.role] = 1
			deco_store[s.role] = "手作り"
			new_decos.append(s.role)
			got.append({"kind": "deco", "id": s.role, "text": tr("手作りの「%s」ができた") % tr(DECOS[s.role].name)})
		save()
		changed.emit()
		return got
	# スキルの記録：本物のシフトは 1 回＝経験 1（時間は見ない）。早送り（監査・宣伝）では数えない
	if not quiet:
		Skills.record_shift(s.role, "day:%d:%d" % [seed_base, day])
	# 働いた日は 2 本（何時間でも同じ）。はじめての経験なら、そのうち 1 本がきらきら
	var n_typed := 1 if s.first or first_role_today else 2
	nets[net_id] = mini(nets[net_id] + n_typed, 4) # 種類つきのポイは4本まで（ためこみすぎない）
	got.append({"kind": "poi", "id": net_id, "n": n_typed, "text": "%s ×%d" % [tr(NETS[net_id].name), n_typed]})
	if n_typed == 1:
		nets["kira"] += 1
		got.append({"kind": "poi", "id": "kira", "n": 1, "text": "きらきらポイ ×1（はじめての経験）"})
	# 何度も一緒に入った同僚から、おばけをもらうことがある
	if not received:
		for c in s.coworkers:
			if coworker_count.get(c, 0) >= 2:
				received = true
				orbs.append({"type": s.role, "rare": false, "content": Drops.roll(s.role, false)})
				got.append({"kind": "gift", "id": s.role, "text": tr("%sから、光る玉をもらった") % tr(c)})
				break
	var before: int = decos.get(s.role, 0)
	if before == 0:
		deco_store[s.role] = s.store
	decos[s.role] = before + 1
	if before == 0:
		new_decos.append(s.role)
		got.append({"kind": "deco", "id": s.role, "text": tr("庭に「%s」が届いた") % tr(DECOS[s.role].name)})
	elif before == 2:
		new_decos.append(s.role)
		got.append({"kind": "deco", "id": s.role, "text": tr("「%s」が少し豪華になった") % tr(DECOS[s.role].name)})
	save()
	changed.emit()
	return got


## 一緒に働き終えたとき：その仕事の種類のポイを n 本（何時間でも同じ・1日1回・4本まで）。
## 見本の記録でシフトを済ませた日は、もう渡しているので0。
func grant_work_nets(role: String, n: int) -> int:
	if not ROLE_NET.has(role) or shift_done_today or work_nets_day == day:
		return 0
	work_nets_day = day
	var net_id: String = ROLE_NET[role]
	var before: int = nets.get(net_id, 0)
	nets[net_id] = mini(before + n, 4)
	save()
	changed.emit()
	return nets[net_id] - before


const CHORE_TEXT := {"register": "落ち葉のおかんじょう", "hall": "縁側へのおぜん運び", "dish": "たらいでお皿あらい", "kitchen": "おでんの下ごしらえ", "stock": "物置の箱の整理"}


## 休みの日（シフトもおてつだいも無い日）の、夜のポイ 1 本。夜になったら 1 日 1 回
func grant_rest_net() -> int:
	if worked_today() or rest_net_day == day:
		return 0
	rest_net_day = day
	nets["plain"] = mini(nets.get("plain", 0) + 1, 5)
	save()
	changed.emit()
	return 1


## 今日は働いた（シフト・一緒に働いた・おてつだい）
func worked_today() -> bool:
	return shift_done_today or work_nets_day == day


## 今夜のポイの本数（働いた日 2・休みの日 1。何時間でも同じ）。島の夜のカードに出す
func tonight_nets() -> int:
	if shift_done_today and today().get("chore", false):
		return 1
	return 2 if worked_today() else 1


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


# ---------- ふしぎな時計（朝の庭の数字） ----------

## 7.67 → 「7時間40分」
static func hm(h: float) -> String:
	var m := int(round(h * 60.0))
	if m % 60 == 0:
		return TranslationServer.translate("%d時間") % (m / 60)
	return TranslationServer.translate("%d時間%d分") % [m / 60, m % 60]


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
	# 救済の数え直し：新しい子がかえった日。いつもの 5 種がそろったあとは、どの子でも数え直す（毎晩おばネコにならないように）
	if is_new or ["receipt", "bubble", "tray", "pan", "box"].all(func(x): return seen.has(x)):
		last_new_cat_day = day
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


const TYPE_SPECIES := {"register": "receipt", "dish": "bubble", "hall": "tray", "kitchen": "pan", "stock": "box", "night": "lantern", "rare": "kirari"}
const TYPE_COLOR := {"register": Color("ffc23d"), "dish": Color("5fc4ff"), "hall": Color("a98bff"), "kitchen": Color("ff7a45"), "stock": Color("e8b878"), "rare": Color("fff2a8"), "any": Color("f4f1ea"), "night": Color("ff9a4d")}


func species_for_type(t: String) -> String:
	return TYPE_SPECIES.get(t, "receipt")


## ポイの破れにくさ（いつも同じ）
func poi_strength() -> float:
	return 1.1


## 今夜の水面に出る玉。今日の仕事の種類が多めに出る。
## 今夜の川べりの様子（日ごとに決まる）
func night_kind() -> String:
	var w: String = today().weather
	if w == "雨" or w == "雷":
		return "rain"
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base * 7 + day * 389
	var r := rng.randf()
	if r < 0.15:
		return "fireflies"
	elif r < 0.25:
		return "bounty"
	return ""


const NIGHT_KIND_TEXT := {
	"rain": ["雨の夜", "玉が重い。でも、ひとつ多い"],
	"fireflies": ["ほたるの夜", "虹の玉が出やすい"],
	"bounty": ["にぎやかな夜", "玉がいつもより多い"],
}


func tonight_orbs() -> Array:
	var s: Dictionary = today()
	var types := ["register", "dish", "hall", "kitchen", "stock"]
	var out: Array = []
	var kind := night_kind()
	var n := randi_range(4, 5) + (1 if kind == "rain" else 0) + (2 if kind == "bounty" else 0)
	var rare_p: float = 0.09 + (0.15 if s.get("first", false) else 0.0) + (0.12 if kind == "fireflies" else 0.0)
	for i in n:
		var t: String = types.pick_random()
		if s.get("role", "") != "" and randf() < 0.45:
			t = s.role
		elif lit_deco != "" and randf() < 0.4:
			t = lit_deco
		var rare: bool = randf() < rare_p
		var wgt: float = 0.5 if rare else randf_range(0.22, 0.34)
		if kind == "rain":
			wgt *= 1.25
		if t == "stock" and not rare:
			wgt *= 1.3 # 箱の玉は重い
		elif t == "dish" and not rare:
			wgt *= 0.8 # 泡の玉は軽い
		var tt: String = "rare" if rare else t
		out.append({"type": tt, "rare": rare, "weight": wgt, "content": Drops.roll(tt, rare)})
	# しばらく新しいおばネコに会えていなければ、いちばんいい玉（虹の玉、なければ先頭）をおばネコに
	if day - last_new_cat_day >= Drops.CAT_PITY_NIGHTS and not out.is_empty() and not out.any(func(o): return Drops.is_cat(o.content)):
		var best := 0
		for i in out.size():
			if out[i].rare:
				best = i
				break
		out[best].content = {"kind": "obake"}
		# まだ会っていない、いつもの子がいれば、その子の仕事の色の玉にする（救済で同じ子ばかりにならないように）
		for t in ["register", "dish", "hall", "kitchen", "stock"]:
			if not seen.has(TYPE_SPECIES[t]):
				out[best].type = t
				out[best].rare = false
				break
	return out


## レアの「きざし」。あと少しで会えそうなものを一行で
func omen() -> String:
	# 週の後半は、満月の夜までの数を
	if weekday() >= 3 and weekday() <= 5:
		var lit: int = moon_lanterns().count(true)
		if lit < 4:
			return tr("満月まで：川べりの夜 %d / 4") % lit
		return "日曜は、満月になりそう"
	if not seen.has("hirunen") and shift_for(day).role == "" and weekday() >= 5:
		return "週末の休みに、だれかが来そう"
	if not seen.has("nemurin") and friend_visits == 0:
		return "友だちの島に、行ってみよう"
	return ""


# ---------- 今日のめあて ----------

const GOAL_TEXT := {
	"scoop3": "玉を3個すくう",
	"talk": "庭のおばけに話しかける",
	"light": "飾りをひとつともす",
	"match": "仕事のポイで、同じ色の玉をすくう",
	"zukan": "図鑑でヒントを見る",
	"outfit": "キセカエで服を着せる",
	"moon4": "満月の夜に、灯りを4つともす",
}


func make_goals() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_base * 13 + day * 71
	var pool := ["scoop3", "talk", "zukan", "outfit"] if weekday() != 6 else ["talk", "zukan", "outfit"]
	if weekday() == 6 and moon_lanterns().count(true) >= 4:
		pool.append("moon4")
	var role_decos := decos.keys().filter(func(k): return ROLE_NET.has(k))
	if not role_decos.is_empty() and weekday() != 6:
		pool.append("light")
	var typed := false
	for k in ["receipt", "bubble", "tray", "pan", "box"]:
		if nets.get(k, 0) > 0:
			typed = true
	if (typed or today().role != "") and weekday() != 6:
		pool.append("match")
	var picks: Array = []
	while picks.size() < 3:
		var g: String = pool[rng.randi() % pool.size()]
		if not picks.has(g):
			picks.append(g)
	goals = []
	for g in picks:
		goals.append({"id": g, "text": GOAL_TEXT[g], "done": false})


func _recalc_level() -> void:
	while garden_level + 1 < GARDEN.size() and growth >= GARDEN[garden_level + 1].need:
		garden_level += 1


## めあてを達成したら、めぐみ +3。3つそろうと、肉球コイン +10（ポイは増やさない：夜のポイは働いた日 2・休みの日 1 だけ）
func goal(id: String) -> void:
	for g in goals:
		if g.id == id and not g.done:
			g.done = true
			Wallet.add(10, "goal")
			growth += 3
			_recalc_level()
			var all := goals.all(func(x): return x.done)
			if all:
				Wallet.add(10, "goals_all")
			if not quiet:
				goal_completed.emit(g.text, all)
			changed.emit()
			return


func goals_done() -> int:
	return goals.filter(func(x): return x.done).size()


# ---------- 実際の時計 ----------

const DAY_START_H := 5 # この時刻で日付が変わる（深夜は前の日の夜）
const EVENING_H := 17 # 川べりは夕方 5 時から（ANYTIME のときは時刻を問わない）
## 審査・試遊用：すくい・孵化を時刻に関係なくいつでも試せる（夕方 5 時まで待たない、朝まで待たない）
const ANYTIME := true


## いまの時刻（確認用に OBAKE_NOW=unix 秒。デモの切りかえは set_clock_offset）
static var clock_offset := 0.0


static func now_real() -> float:
	var e := OS.get_environment("OBAKE_NOW")
	return (float(e) if e != "" else Time.get_unix_time_from_system()) + clock_offset


static func _local(t: float) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(int(t + Time.get_time_zone_from_system().get("bias", 0) * 60.0))


## 朝 5 時で区切った、その日の日付 "YYYY-MM-DD"
static func real_date(t := -1.0) -> String:
	var d := _local((now_real() if t < 0.0 else t) - DAY_START_H * 3600.0)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


## 実際の時刻の、昼か夜か（夕方 5 時〜朝 5 時は夜）
static func real_phase(t := -1.0) -> String:
	var h: int = _local(now_real() if t < 0.0 else t).hour
	return "evening" if h >= EVENING_H or h < DAY_START_H else "day"


## 実際の時計に合わせる：次の日付の朝が来ていたら夜を明け（true）、昼のうちに夕方になっていたら夜にする
func sync_clock(t := -1.0) -> bool:
	var today := real_date(t)
	if clock_date == "":
		clock_date = today
		save()
	if today > clock_date:
		clock_date = today
		end_night()
		return true
	if phase == "day" and real_phase(t) == "evening":
		phase = "evening"
		save()
		changed.emit()
	return false


# ---------- 夜のおわり ----------

## 夜が明ける（入力は無い）。庭の育ち・レア・玉の孵化をまとめて決めて、次の朝へ。
func end_night() -> void:
	var s: Dictionary = today()
	var worked := shift_done_today or work_nets_day == day
	var river := scooped_tonight or tonight_caught > 0
	var gain := GROW_DAY + (GROW_WORKED if worked else 0) + (GROW_RIVER if river else 0)
	var level_before := garden_level
	growth += gain
	_recalc_level()
	last_goals = goals_done()
	river_hist.append(river)
	last_night = {"growth_gain": gain, "level_before": level_before, "worked": worked, "river": river}
	hatched = []
	# 条件を満たしたレアが生まれる
	var have := seen.duplicate()
	for rid in rare_pending:
		have[rid] = true
	var fresh: Array = Rares.check(rare_context(s), have)
	rare_pending = fresh + rare_pending
	for i in min(RARES_PER_NIGHT, rare_pending.size()):
		var rid: String = rare_pending.pop_front()
		add_obake(rid)
		hatched.append({"id": rid, "is_new": true, "level": 1, "rare": true})
	_hatch_orbs()
	work_hist.append(shift_done_today)
	gifted_today = false
	scooped_tonight = false
	tonight_caught = 0
	stall_claimed = false
	night_plan = ""
	shift_done_today = false
	moon_won_today = false
	day += 1
	if weekday() == 0:
		week_start_seen = seen.size()
		week_start_growth = growth
		stores_week = {}
		bands_week = {}
		weekend_shifts = {}
	# 夜のポイは、その日の暮らしで決まる：働いた日 2 本（finish_shift / grant_work_nets）、休みの日 1 本（grant_rest_net）
	make_goals()
	phase = "morning"
	save()
	changed.emit()


func _hatch_orbs() -> void:
	for orb in orbs:
		# 中身が材料・服なら、おばけではなくそれが出る
		var c: Dictionary = orb.get("content", {})
		if c.get("kind", "obake") != "obake":
			var nw := Drops.grant(c)
			hatched.append({"id": c.id, "kind": c.kind, "content": c, "is_new": nw, "level": 1, "rare": false})
			continue
		# はじめての夜の玉（と 3 分デモの玉）は、決まった特別なレア（SpecialReveal.pick）
		var sp_id := String(c.get("special", ""))
		if SpecialReveal.is_special(sp_id):
			hatched.append({"id": sp_id, "is_new": add_obake(sp_id), "level": 1, "rare": true, "special": true})
			continue
		var sid: String = species_for_type(orb.type) if orb.type != "rare" else ["receipt", "bubble", "tray", "pan", "box"].pick_random()
		var is_new := add_obake(sid)
		var lv := 1
		for o in owned:
			if o.id == sid:
				o.xp += 40 + (60 if orb.rare else 0)
				_level_up(o)
				lv = o.level
		hatched.append({"id": sid, "is_new": is_new, "level": lv, "rare": false, "big": orb.rare})
	orbs = []


# ---------- 満月の夜 ----------

## この週の夜（直近 6 夜）のうち、川べりですくった夜
func moon_lanterns() -> Array:
	var out: Array = []
	var recent: Array = river_hist.slice(-6)
	for i in 6 - recent.size():
		out.append(false)
	for g in recent:
		out.append(g)
	return out


func finish_moon(lit: int, bonus_taps: int) -> Dictionary:
	moon_nights += 1
	var won := lit >= 4
	moon_won_today = won
	if lit >= 4:
		goal("moon4")
	var gain := lit * 4 + bonus_taps
	growth += gain
	while garden_level + 1 < GARDEN.size() and growth >= GARDEN[garden_level + 1].need:
		garden_level += 1
	# 月の玉：灯りの数に応じて段階的に。3つでちょうちんの玉、4つで満月（虹の玉とツキミ）
	var n := clampi((lit + 1) / 2, 1, 3)
	for i in n:
		# 満月の虹の玉はおばネコのまま（ツキミの夜）。ほかの月の玉は、ふつうの玉と同じ割合（Drops）
		var mt: String = "rare" if won and i == 0 else ["register", "dish", "hall", "kitchen", "stock"].pick_random()
		orbs.append({"type": mt, "rare": won and i == 0, "content": {"kind": "obake"} if won and i == 0 else Drops.roll(mt, false)})
	if lit >= 3:
		orbs.append({"type": "night", "rare": false})
		n += 1
	scooped_tonight = true
	save()
	return {"won": won, "growth": gain, "orbs": n}


# ---------- レア条件 ----------

func rare_context(s: Dictionary) -> Dictionary:
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
	var sh := s.duplicate()
	if not worked:
		sh.role = ""
	return {
		"shift": sh,
		"rest_day": not worked and day > 0,
		"weekend": weekday() >= 5,
		"after_moon": weekday() == 0 and moon_nights > 0,
		"moon_nights": moon_nights,
		"friend_visits": friend_visits,
		"keepsakes": keepsakes.size(),
		"same_store_again": worked and int(store_count.get(s.get("store", ""), 0)) >= 2,
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
		"moon_won": moon_won_today,
	}


# ---------- セーブ ----------

const SAVE_KEYS := ["mode", "seed_base", "day", "phase", "nets", "owned", "seen", "orbs", "scooped_tonight", "river_hist", "friend_visits", "store_count", "last_night", "growth", "garden_level", "garden_seen_level", "decos", "new_decos", "dream_flowers", "roles_seen", "stores_week", "coworker_count", "morning_shifts", "bands_week", "shift_done_today", "weekend_shifts", "gifted", "received", "moon_nights", "rare_pending", "tut", "total_scooped", "first_role_today", "night_plan", "lit_deco", "goals", "deco_store", "chores", "work_hist", "tonight_caught", "moon_won_today", "hatched", "last_goals", "newcomers", "stall_claimed", "week_start_seen", "week_start_growth", "pending_toasts", "layout", "nickname", "host_id", "keepsakes", "stash", "work_nets_day", "rest_net_day", "clock_date", "skip_shift_day", "last_new_cat_day"]


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
	if OS.get_environment("OBAKE_NOSAVE") != "":
		return false
	return FileAccess.file_exists(SAVE_PATH)


func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	return load_text(f.get_as_text())


## セーブの中身（JSON の文字列）を読みこむ。やめたレアの id は代わりの子へ置きかえる
func load_text(text: String) -> bool:
	var d = JSON.parse_string(Rares.migrate_text(text))
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
	# 眠りの仕組みをやめる前の保存：スヤリ（夢のおばけ）と夢の玉は、もういない。
	# 条件を眠りから変えたレアは、前の条件で待っていた分を取り消す（新しい条件で会う）
	if d.has("bed_hist"):
		rare_pending = rare_pending.filter(func(r): return not r in ["nemurin", "yumemi", "asayake", "yomise", "hirunen", "totonou", "mangetsu"])
	owned = owned.filter(func(o): return o.id != "nemuri")
	seen.erase("nemuri")
	orbs = orbs.filter(func(o): return o.get("type", "") != "sleep")
	if not last_night.has("growth_gain") or last_night.has("bed"):
		last_night = {}
	var ws := {}
	for k in weekend_shifts:
		ws[int(k)] = true
	weekend_shifts = ws
	changed.emit()
	return true


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ---------- 島のシェア（サーバーなし：URL の #island=<code>） ----------

const SHARE_URL := "https://paw-time-play.vercel.app/#island="
## 動かせる物（順番がコードの番号。後ろに足すだけにする）
const ISLAND_ITEMS := ["flowerbed", "lantern", "pond", "bench", "sakura", "moondeck", "dream", "deco_register", "deco_hall", "deco_dish", "deco_kitchen", "deco_stock", "deco_mask", "res_kakashi", "res_jizo", "res_nebukuro"]
const ITEM_NAME := {"flowerbed": "花壇", "lantern": "灯籠", "pond": "池", "bench": "縁台", "sakura": "桜", "moondeck": "月見台", "dream": "星見の木", "deco_register": "パラソル席", "deco_hall": "赤ちょうちん", "deco_dish": "泡のたらい", "deco_kitchen": "おでん鍋", "deco_stock": "秘密基地", "deco_mask": "お面屋", "res_kakashi": "かかし", "res_jizo": "おじぞう", "res_nebukuro": "ねぶくろ"}


func species_list() -> Array:
	var out: Array = NORMAL.duplicate()
	for r in Rares.LIST:
		out.append(r.id)
	return out


func set_my_obake(result: Dictionary) -> void:
	my_obake = result.duplicate(true)
	QuizResult.save(my_obake)
	changed.emit()


## 島のあるじ。マイおばけ猫がいればその子（"my"）
func host() -> String:
	if host_id == "" and not my_obake.is_empty():
		return "my"
	if host_id == "my" and not my_obake.is_empty():
		return "my"
	if host_id != "" and seen.has(host_id):
		return host_id
	return owned[0].id if not owned.is_empty() else "receipt"


## 今の島をコードにする：版・段・リズム段・名前・あるじ・住人・物（番号＋位置＋向き＋豪華さ）・置き物キット（版3）・広げた場所と乗り物（版4）
func island_code(items_present: Array) -> String:
	var b := PackedByteArray()
	b.append(5) # 版5：服（キセカエ）＋置き物キット＋広げた場所＋乗り物。版1〜4も読める
	b.append(garden_level)
	b.append(2) # もとは眠りの段の欄。コードの形を変えないよう、いつも 2
	var nm := (nickname if nickname != "" else "ななし").to_utf8_buffer()
	if nm.size() > 30:
		nm = nm.slice(0, 30)
	b.append(nm.size())
	b.append_array(nm)
	var sl := species_list()
	b.append(255 if host() == "my" else maxi(0, sl.find(host())))
	var tids: Array = QuizData.TYPES.keys()
	b.append(tids.find(my_obake.type_id) if not my_obake.is_empty() and tids.has(my_obake.type_id) else 255)
	var res: Array = []
	for o in owned.slice(-12):
		res.append(maxi(0, sl.find(o.id)))
	b.append(res.size())
	for r in res:
		b.append(r)
	var its: Array = []
	for key in items_present:
		var idx := ISLAND_ITEMS.find(key)
		if idx < 0:
			continue
		var l: Dictionary = layout.get(key, {})
		if l.get("h", false):
			continue
		its.append([idx, l])
	b.append(its.size())
	for it in its:
		var key: String = ISLAND_ITEMS[it[0]]
		var lv := 0
		if key.begins_with("deco_"):
			lv = deco_level(key.substr(5))
		var l: Dictionary = it[1]
		b.append(it[0] | (lv << 6))
		b.append(clampi(int(round((float(l.get("x", 99.0)) + 6.0) * 20.0)), 0, 255) if l.has("x") else 255)
		b.append(clampi(int(round((float(l.get("z", 0.0)) + 6.0) * 20.0)), 0, 255) if l.has("x") else 255)
		b.append(int(l.get("r", 0)) & 7)
	# 服（版5。キセカエの版3と同じ形）。あるじ（255）と住人の番号ごとに、6 か所＋色の 7 バイト。着ている子だけ、最大 6 体
	var dressed: Array = []
	if not Wardrobe.outfit_of(host()).is_empty():
		dressed.append([255, host()])
	for k in res.size():
		var rid: String = owned.slice(-12)[k].id
		if rid != host() and not Wardrobe.outfit_of(rid).is_empty() and dressed.size() < 6:
			dressed.append([k, rid])
	b.append(dressed.size())
	for dd in dressed:
		b.append(dd[0])
		b.append_array(Wardrobe.pack(dd[1]))
	# 置き物キット（買って置いた物）を後ろに足す
	b.append_array(IslandKit.encode(IslandKit.placed))
	# プレイヤーが広げた場所と、桟橋にとめてある乗り物
	b.append_array(IslandKit.encode_expansions(IslandKit.expansions()))
	b.append(Vehicles.index_of(Vehicles.current()))
	return Marshalls.raw_to_base64(b).replace("+", "-").replace("/", "_").replace("=", "")


## コードから島を読む。こわれていたら {} を返す
func decode_island(code: String) -> Dictionary:
	code = code.strip_edges()
	if code.contains("#island="):
		code = code.split("#island=")[1]
	code = code.replace("-", "+").replace("_", "/")
	while code.length() % 4 != 0:
		code += "="
	var b := Marshalls.base64_to_raw(code)
	if b.size() < 6 or b[0] < 1 or b[0] > 5:
		return {}
	var i := 1
	var d := {"level": b[1], "tier": clampi(b[2], 0, 3)}
	i = 3
	var n: int = b[i]
	i += 1
	if i + n > b.size():
		return {}
	d.name = b.slice(i, i + n).get_string_from_utf8()
	i += n
	var sl := species_list()
	d.host = "my" if b[i] == 255 else sl[clampi(b[i], 0, sl.size() - 1)]
	i += 1
	d.my_type = ""
	if b[0] >= 2:
		var tids: Array = QuizData.TYPES.keys()
		if b[i] < tids.size():
			d.my_type = tids[b[i]]
		i += 1
	if d.host == "my" and d.my_type == "":
		d.host = "receipt"
	var rn: int = b[i]
	i += 1
	d.residents = []
	for k in rn:
		if i >= b.size():
			return {}
		d.residents.append(sl[clampi(b[i], 0, sl.size() - 1)])
		i += 1
	var itn: int = b[i] if i < b.size() else 0
	i += 1
	d.items = {}
	d.layout = {}
	d.decos = {}
	for k in itn:
		if i + 3 >= b.size():
			return {}
		var idx: int = b[i] & 63
		var lv: int = b[i] >> 6
		var x: int = b[i + 1]
		var z: int = b[i + 2]
		var r: int = b[i + 3]
		i += 4
		if idx >= ISLAND_ITEMS.size():
			continue
		var key: String = ISLAND_ITEMS[idx]
		d.items[key] = true
		if x != 255:
			d.layout[key] = {"x": x / 20.0 - 6.0, "z": z / 20.0 - 6.0, "r": r}
		if key.begins_with("deco_"):
			d.decos[key.substr(5)] = maxi(1, lv)
	# 版3 は 2 種類ある（キセカエの版3＝服、島キットの版3＝置き物）。長さがぴったり合うほうで読む
	d.outfits = {}
	d.kit = []
	d.expansions = []
	d.vehicle = "raft"
	var ver: int = b[0]
	var has_outfits: bool = ver >= 5 or (ver == 3 and _is_outfit_block(b, i))
	var has_kit: bool = ver >= 4 or (ver == 3 and not has_outfits)
	# 服：あるじ（255）と住人の番号ごとに 7 バイト。あるじの服は "my"／あるじの id で引けるようにする
	if has_outfits and i < b.size():
		var dn: int = b[i]
		i += 1
		for k in dn:
			if i + 8 > b.size():
				break
			var who: int = b[i]
			var o := Wardrobe.unpack(b.slice(i + 1, i + 8))
			i += 8
			if who == 255:
				d.outfits[d.host] = o
			elif who < d.residents.size():
				d.outfits[d.residents[who]] = o
	if has_kit:
		var kd := IslandKit.decode(b, i)
		d.kit = kd.list
		i = kd.next
	# 広げた場所と乗り物（版4から）
	if ver >= 4:
		var ed := IslandKit.decode_expansions(b, i)
		d.expansions = ed.list
		i = ed.next
		if i < b.size() and b[i] < Vehicles.LIST.size():
			d.vehicle = Vehicles.LIST[b[i]].id
	return d


## キセカエの版3（服の並び）として長さがぴったり合うか（島キットの版3と見分ける）
static func _is_outfit_block(b: PackedByteArray, i: int) -> bool:
	if i >= b.size():
		return false
	var n: int = b[i]
	return n <= 6 and i + 1 + 8 * n == b.size()
