class_name IslandKit
## 島の置き物キット：カタログ（40 種以上）・材料・持ち物・置いた物・シェア用のバイト列。
## 見た目は IslandProps.build(id)。置く・回す・しまうは screen_garden.gd の「島をつくる」から。
## 保存は user://island_kit.json（ほかのセーブと独立。OBAKE_NOSAVE=1 で保存しない）。
##
## 買い方：肉球コイン（Wallet）＋材料。材料は夜のすくいの玉から出る（random_drop / grant_material）。
## 文字列は英語が先。表示は tr("KIT_<id>")（translations/island_kit.csv に en / ja）。

const PATH := "user://island_kit.json"

## 材料（6 種）。drop は random_drop() の重み
const MATERIALS := {
	"wood": {"icon": "🪵", "drop": 30},
	"stone": {"icon": "🪨", "drop": 26},
	"seed": {"icon": "🌱", "drop": 22},
	"paper": {"icon": "🏮", "drop": 10},
	"shell": {"icon": "🐚", "drop": 8},
	"cloth": {"icon": "🧶", "drop": 12},
}
const MAT_ORDER := ["wood", "stone", "seed", "paper", "shell", "cloth"]
## 段 2 の小島：中心 x, z と半径（tools/blender/build_island_kit.py の ISLET と同じ）
const ISLET := Vector3(6.9, 1.4, 1.35)

## 島の広がり（地形の段）。島の段（GameState.garden_level）から決まる
const STAGES := [
	{"from_level": 0, "radius": 3.9},
	{"from_level": 4, "radius": 4.5},
	{"from_level": 8, "radius": 5.0},
]

## カタログ。順番がシェアのコードの番号なので、後ろに足すだけにする。
## foot は床の大きさ（x, z メートル）、price は肉球コイン、mats は材料、unlock は地形の段、
## spots はおばけの行き先（置き物の中の位置と、そこでのしぐさ）
const ITEMS := [
	# ---- 家・お店
	{"id": "hut", "cat": "home", "foot": [1.4, 1.2], "price": 60, "mats": {"wood": 6, "stone": 2}, "stage": 0, "spots": [[0.0, 0.0, 0.85, "sleep"]]},
	{"id": "cottage", "cat": "home", "foot": [1.8, 1.5], "price": 140, "mats": {"wood": 10, "stone": 6, "cloth": 2}, "stage": 1, "spots": [[0.5, 0.0, 1.05, "sit"], [-0.4, 0.0, 1.05, "look"]]},
	{"id": "cafe_stand", "cat": "shop", "foot": [1.4, 0.9], "price": 70, "mats": {"wood": 5, "cloth": 2}, "stage": 0, "spots": [[0.0, 0.0, 0.8, "tea"]]},
	{"id": "market_fruit", "cat": "shop", "foot": [1.2, 0.8], "price": 55, "mats": {"wood": 4, "cloth": 1, "seed": 2}, "stage": 0, "spots": [[0.0, 0.0, 0.75, "eat"]]},
	{"id": "market_fish", "cat": "shop", "foot": [1.2, 0.8], "price": 60, "mats": {"wood": 4, "cloth": 1, "shell": 2}, "stage": 1, "spots": [[0.0, 0.0, 0.75, "eat"]]},
	{"id": "ramen_cart", "cat": "shop", "foot": [1.3, 0.8], "price": 80, "mats": {"wood": 5, "paper": 2}, "stage": 1, "spots": [[0.3, 0.0, 0.75, "eat"], [-0.3, 0.0, 0.75, "eat"]]},
	# ---- 座る
	{"id": "bench", "cat": "seat", "foot": [1.0, 0.45], "price": 15, "mats": {"wood": 2}, "stage": 0, "spots": [[-0.25, 0.3, 0.0, "sit"], [0.25, 0.3, 0.0, "sit"]]},
	{"id": "log_seat", "cat": "seat", "foot": [0.8, 0.4], "price": 8, "mats": {"wood": 1}, "stage": 0, "spots": [[0.0, 0.28, 0.0, "sit"]]},
	{"id": "cushion", "cat": "seat", "foot": [0.5, 0.5], "price": 10, "mats": {"cloth": 1}, "stage": 0, "spots": [[0.0, 0.1, 0.0, "sleep"]]},
	{"id": "picnic_mat", "cat": "seat", "foot": [1.2, 1.0], "price": 20, "mats": {"cloth": 2}, "stage": 0, "spots": [[-0.25, 0.02, 0.0, "tea"], [0.3, 0.02, 0.1, "eat"]]},
	{"id": "parasol_table", "cat": "seat", "foot": [1.1, 1.1], "price": 35, "mats": {"wood": 2, "cloth": 2}, "stage": 0, "spots": [[-0.4, 0.0, 0.2, "tea"], [0.4, 0.0, 0.2, "tea"]]},
	{"id": "hammock", "cat": "seat", "foot": [1.6, 0.6], "price": 45, "mats": {"wood": 2, "cloth": 3}, "stage": 1, "spots": [[0.0, 0.42, 0.0, "sleep"]]},
	# ---- 灯り
	{"id": "stone_lantern", "cat": "light", "foot": [0.5, 0.5], "price": 25, "mats": {"stone": 3}, "stage": 0, "spots": [[0.0, 0.0, 0.5, "look"]]},
	{"id": "paper_lantern", "cat": "light", "foot": [0.4, 0.4], "price": 18, "mats": {"paper": 1, "wood": 1}, "stage": 0, "spots": []},
	{"id": "street_lamp", "cat": "light", "foot": [0.4, 0.4], "price": 22, "mats": {"stone": 1, "wood": 1}, "stage": 0, "spots": []},
	{"id": "string_lights", "cat": "light", "foot": [1.6, 0.3], "price": 30, "mats": {"paper": 2, "wood": 2}, "stage": 1, "spots": []},
	# ---- 柵・道・橋
	{"id": "fence_wood", "cat": "fence", "foot": [1.0, 0.2], "price": 5, "mats": {"wood": 1}, "stage": 0, "spots": []},
	{"id": "fence_hedge", "cat": "fence", "foot": [1.0, 0.35], "price": 8, "mats": {"seed": 1}, "stage": 0, "spots": [[0.0, 0.0, 0.4, "hide"]]},
	{"id": "stepping_stones", "cat": "path", "foot": [1.0, 0.5], "price": 4, "mats": {"stone": 1}, "stage": 0, "spots": []},
	{"id": "path_brick", "cat": "path", "foot": [1.0, 1.0], "price": 6, "mats": {"stone": 1}, "stage": 0, "spots": []},
	{"id": "bridge_arch", "cat": "path", "foot": [1.6, 0.8], "price": 50, "mats": {"wood": 5}, "stage": 1, "spots": [[0.0, 0.3, 0.0, "look"]]},
	{"id": "bridge_islet", "cat": "path", "foot": [2.4, 0.9], "price": 90, "mats": {"wood": 8, "stone": 2}, "stage": 2, "spots": [[0.0, 0.12, 0.0, "look"]]},
	# ---- 木
	{"id": "tree_round", "cat": "tree", "foot": [1.0, 1.0], "price": 20, "mats": {"seed": 2}, "stage": 0, "spots": [[0.5, 0.0, 0.5, "sleep"]]},
	{"id": "tree_sakura", "cat": "tree", "foot": [1.2, 1.2], "price": 45, "mats": {"seed": 4}, "stage": 0, "spots": [[0.6, 0.0, 0.5, "look"]]},
	{"id": "tree_pine", "cat": "tree", "foot": [0.9, 0.9], "price": 30, "mats": {"seed": 3}, "stage": 0, "spots": []},
	{"id": "tree_palm", "cat": "tree", "foot": [1.0, 1.0], "price": 40, "mats": {"seed": 3, "shell": 1}, "stage": 1, "spots": [[0.5, 0.0, 0.4, "sleep"]]},
	{"id": "bush", "cat": "tree", "foot": [0.6, 0.6], "price": 6, "mats": {"seed": 1}, "stage": 0, "spots": [[0.0, 0.0, 0.4, "hide"]]},
	# ---- 花
	{"id": "flower_pot", "cat": "flower", "foot": [0.35, 0.35], "price": 6, "mats": {"seed": 1}, "stage": 0, "spots": []},
	{"id": "flower_bed", "cat": "flower", "foot": [1.2, 0.6], "price": 16, "mats": {"seed": 2, "wood": 1}, "stage": 0, "spots": [[0.0, 0.0, 0.55, "water"]]},
	{"id": "tulip_patch", "cat": "flower", "foot": [0.8, 0.8], "price": 12, "mats": {"seed": 2}, "stage": 0, "spots": [[0.0, 0.0, 0.5, "look"]]},
	{"id": "sunflowers", "cat": "flower", "foot": [0.8, 0.5], "price": 14, "mats": {"seed": 2}, "stage": 1, "spots": []},
	# ---- 水
	{"id": "pond", "cat": "water", "foot": [1.6, 1.2], "price": 40, "mats": {"stone": 4}, "stage": 0, "spots": [[0.0, 0.02, 0.0, "swim"]]},
	{"id": "pier", "cat": "water", "foot": [0.9, 2.2], "price": 55, "mats": {"wood": 6}, "stage": 1, "spots": [[0.0, 0.18, 0.8, "look"]]},
	{"id": "hot_spring", "cat": "water", "foot": [1.6, 1.4], "price": 120, "mats": {"stone": 8, "wood": 2}, "stage": 2, "spots": [[-0.25, 0.05, 0.0, "swim"], [0.3, 0.05, 0.1, "sleep"]]},
	{"id": "fountain", "cat": "water", "foot": [1.0, 1.0], "price": 65, "mats": {"stone": 5, "shell": 1}, "stage": 1, "spots": [[0.0, 0.0, 0.7, "look"]]},
	# ---- しるし
	{"id": "lighthouse", "cat": "landmark", "foot": [1.2, 1.2], "price": 180, "mats": {"stone": 10, "paper": 3}, "stage": 2, "spots": [[0.0, 0.0, 0.8, "look"]]},
	{"id": "torii_gate", "cat": "landmark", "foot": [1.5, 0.4], "price": 75, "mats": {"wood": 6, "cloth": 1}, "stage": 1, "spots": [[0.0, 0.0, 0.5, "look"]]},
	{"id": "windmill", "cat": "landmark", "foot": [1.2, 1.2], "price": 110, "mats": {"wood": 8, "cloth": 3}, "stage": 1, "spots": []},
	# ---- 遊ぶ
	{"id": "swing", "cat": "play", "foot": [1.2, 0.7], "price": 40, "mats": {"wood": 4}, "stage": 0, "spots": [[0.0, 0.35, 0.0, "sit"]]},
	{"id": "slide", "cat": "play", "foot": [1.6, 0.7], "price": 50, "mats": {"wood": 3, "stone": 2}, "stage": 1, "spots": [[0.6, 0.0, 0.2, "look"]]},
	{"id": "sandbox", "cat": "play", "foot": [1.0, 1.0], "price": 20, "mats": {"wood": 2, "shell": 1}, "stage": 0, "spots": [[0.0, 0.05, 0.0, "hide"]]},
	{"id": "yarn_ball", "cat": "play", "foot": [0.4, 0.4], "price": 8, "mats": {"cloth": 1}, "stage": 0, "spots": [[0.3, 0.0, 0.3, "look"]]},
	# ---- 小物
	{"id": "mailbox", "cat": "sign", "foot": [0.35, 0.35], "price": 12, "mats": {"wood": 1}, "stage": 0, "spots": []},
	{"id": "bulletin_board", "cat": "sign", "foot": [0.9, 0.3], "price": 18, "mats": {"wood": 2, "paper": 1}, "stage": 0, "spots": [[0.0, 0.0, 0.5, "look"]]},
	{"id": "signpost", "cat": "sign", "foot": [0.4, 0.4], "price": 10, "mats": {"wood": 1}, "stage": 0, "spots": []},
	{"id": "shell_pile", "cat": "sign", "foot": [0.5, 0.5], "price": 6, "mats": {"shell": 1}, "stage": 0, "spots": []},
	# ---- 季節
	{"id": "snowman", "cat": "season", "foot": [0.6, 0.6], "price": 15, "mats": {"stone": 1, "cloth": 1}, "stage": 0, "spots": [[0.0, 0.0, 0.45, "look"]]},
	{"id": "pumpkin_patch", "cat": "season", "foot": [0.9, 0.7], "price": 18, "mats": {"seed": 3}, "stage": 0, "spots": []},
	{"id": "tanabata_bamboo", "cat": "season", "foot": [0.6, 0.6], "price": 25, "mats": {"paper": 2, "seed": 1}, "stage": 0, "spots": [[0.0, 0.0, 0.5, "look"]]},
	{"id": "koinobori", "cat": "season", "foot": [0.5, 0.5], "price": 30, "mats": {"cloth": 3, "wood": 1}, "stage": 1, "spots": []},
	# ---- 見た目だけの有料アイテム（見本。いまは買えない）。コイン・材料・ポイとは混ぜない。遊びの進み方は変わらない
	{"id": "lighthouse_starlight", "cat": "premium", "foot": [1.2, 1.2], "price": 0, "mats": {}, "stage": 0, "premium": true, "yen": 360, "spots": [[0.0, 0.0, 0.8, "look"]]},
	{"id": "festival_yagura", "cat": "premium", "foot": [1.6, 1.6], "price": 0, "mats": {}, "stage": 0, "premium": true, "yen": 480, "spots": [[0.7, 0.0, 0.7, "look"], [-0.7, 0.0, 0.7, "look"]]},
	{"id": "lantern_arch", "cat": "premium", "foot": [1.8, 0.5], "price": 0, "mats": {}, "stage": 0, "premium": true, "yen": 240, "spots": []},
]

const CATS := ["home", "shop", "seat", "light", "fence", "path", "tree", "flower", "water", "landmark", "play", "sign", "season", "premium"]

static var _loaded := false
static var mats := {} # 材料 → 数
static var stock := {} # しまってある物 id → 数
static var placed: Array = [] # 置いた物 {u, id, x, z, r}
static var _next_uid := 1
static var _by_id := {}


# ---------------------------------------------------------------- カタログ

static func item(id: String) -> Dictionary:
	if _by_id.is_empty():
		for it in ITEMS:
			_by_id[it.id] = it
	return _by_id.get(id, {})


static func index_of(id: String) -> int:
	for i in ITEMS.size():
		if ITEMS[i].id == id:
			return i
	return -1


static func is_premium(id: String) -> bool:
	return item(id).get("premium", false)


static func name_of(id: String) -> String:
	return TranslationServer.translate("KIT_" + id)


static func stage_for(level: int) -> int:
	var s := 0
	for i in STAGES.size():
		if level >= STAGES[i].from_level:
			s = i
	return s


static func unlocked(id: String, stage: int) -> bool:
	return int(item(id).get("stage", 0)) <= stage


# ---------------------------------------------------------------- 材料

static func count(kind: String) -> int:
	_ensure()
	return int(mats.get(kind, 0))


## すくい・孵化から呼ぶ：材料をふやす
static func grant_material(kind: String, n := 1) -> void:
	_ensure()
	if not MATERIALS.has(kind) or n <= 0:
		return
	mats[kind] = count(kind) + n
	_save()


## 夜のすくいの玉から出る材料をひとつ決めて、ふやして返す {kind, n}。
## rng を渡すと、その乱数で決める（テスト・再現用）
static func random_drop(rng: RandomNumberGenerator = null) -> Dictionary:
	var total := 0
	for k in MAT_ORDER:
		total += int(MATERIALS[k].drop)
	var roll := (rng.randi_range(0, total - 1) if rng else randi_range(0, total - 1))
	var kind := "wood"
	for k in MAT_ORDER:
		roll -= int(MATERIALS[k].drop)
		if roll < 0:
			kind = k
			break
	var n := 1 + ((rng.randi_range(0, 2) if rng else randi_range(0, 2)) if kind in ["wood", "stone", "seed"] else 0)
	grant_material(kind, n)
	return {"kind": kind, "n": n}


## 足りない分 {kind: 不足数}（コインは "coins"）。空なら買える
static func missing(id: String) -> Dictionary:
	_ensure()
	var it := item(id)
	var out := {}
	var short: int = int(it.price) - Wallet.balance()
	if short > 0:
		out["coins"] = short
	for k in it.mats:
		var s: int = int(it.mats[k]) - count(k)
		if s > 0:
			out[k] = s
	return out


## 買う：コインと材料を減らし、しまってある物に 1 つ足す。足りなければ false（何も減らさない）
static func buy(id: String) -> bool:
	_ensure()
	var it := item(id)
	# 有料の見本（premium）は、ここでは買えない（見本のストア。お金の処理は無い）
	if it.is_empty() or it.get("premium", false) or not missing(id).is_empty():
		return false
	if not Wallet.spend(int(it.price), "island:" + id):
		return false
	for k in it.mats:
		mats[k] = count(k) - int(it.mats[k])
	stock[id] = int(stock.get(id, 0)) + 1
	_save()
	return true


# ---------------------------------------------------------------- 置く・しまう

## しまってある物を 1 つ島に出す。置いた物の辞書を返す（無ければ {}）
static func place(id: String, x: float, z: float, r := 0) -> Dictionary:
	_ensure()
	if int(stock.get(id, 0)) <= 0:
		return {}
	stock[id] = int(stock[id]) - 1
	if stock[id] <= 0:
		stock.erase(id)
	var p := {"u": _next_uid, "id": id, "x": x, "z": z, "r": r}
	_next_uid += 1
	placed.append(p)
	_save()
	return p


static func move(u: int, x: float, z: float, r: int) -> void:
	for p in placed:
		if int(p.u) == u:
			p.x = snappedf(x, 0.05)
			p.z = snappedf(z, 0.05)
			p.r = r & 7
	_save()


## 島から戻して、しまってある物に 1 つ足す
static func store(u: int) -> void:
	for i in placed.size():
		if int(placed[i].u) == u:
			var id: String = placed[i].id
			stock[id] = int(stock.get(id, 0)) + 1
			placed.remove_at(i)
			break
	_save()


# ---------------------------------------------------------------- シェア

## 置いた物をバイト列に：数（2 バイト）＋ 1 つ 4 バイト（番号・x・z・向き）。x, z は 0.08 刻みで ±10.2
static func encode(list: Array) -> PackedByteArray:
	var b := PackedByteArray()
	var its := list.filter(func(p): return index_of(p.id) >= 0).slice(0, 400)
	b.append(its.size() & 255)
	b.append(its.size() >> 8)
	for p in its:
		b.append(index_of(p.id))
		b.append(clampi(int(round((float(p.x) + 10.2) / 0.08)), 0, 255))
		b.append(clampi(int(round((float(p.z) + 10.2) / 0.08)), 0, 255))
		b.append(int(p.r) & 7)
	return b


## encode の逆。i は読み始め。返り値 {"list": [...], "next": 次の位置}。壊れていたら list は空
static func decode(b: PackedByteArray, i: int) -> Dictionary:
	if i + 2 > b.size():
		return {"list": [], "next": i}
	var n: int = b[i] | (b[i + 1] << 8)
	i += 2
	var out: Array = []
	for k in n:
		if i + 4 > b.size():
			return {"list": [], "next": i}
		var idx: int = b[i]
		if idx < ITEMS.size():
			out.append({"u": 10000 + k, "id": ITEMS[idx].id, "x": b[i + 1] * 0.08 - 10.2, "z": b[i + 2] * 0.08 - 10.2, "r": b[i + 3] & 7})
		i += 4
	return {"list": out, "next": i}


# ---------------------------------------------------------------- 保存

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if OS.get_environment("OBAKE_NOSAVE") != "" or not FileAccess.file_exists(PATH):
		_starter()
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f else null
	if not d is Dictionary:
		_starter()
		return
	mats = d.get("mats", {})
	stock = d.get("stock", {})
	placed = d.get("placed", [])
	_next_uid = int(d.get("next", 1))
	for p in placed:
		_next_uid = maxi(_next_uid, int(p.u) + 1)


## はじめの持ち物（最初の日から 2〜3 個は買える）
static func _starter() -> void:
	mats = {"wood": 4, "stone": 3, "seed": 3, "cloth": 1}
	stock = {"bench": 1, "flower_pot": 2}
	placed = []


static func _save() -> void:
	if OS.get_environment("OBAKE_NOSAVE") != "":
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"mats": mats, "stock": stock, "placed": placed, "next": _next_uid}))


static func load_all() -> void:
	_ensure()


## 確認・宣伝用：段ごとの見本の飾りつけ（OBAKE_KIT_DEMO=1 で使う。保存はしない）
const DEMO := [
	[["hut", -2.55, -1.2, 0], ["tree_round", -2.7, 1.75, 0], ["tree_pine", 2.95, -0.3, 0], ["bench", 1.55, 2.3, 0],
	["flower_pot", 0.95, 2.45, 0], ["flower_pot", 2.2, 2.4, 0], ["cafe_stand", 2.35, 0.95, 7], ["stepping_stones", 0.2, 3.05, 2],
	["fence_wood", -1.2, 2.95, 0], ["paper_lantern", 0.95, -1.15, 0], ["bush", -3.1, -0.2, 0], ["cushion", -1.9, -0.55, 0], ["yarn_ball", -1.5, -0.2, 0]],
	[["cottage", -2.7, -1.15, 1], ["tree_sakura", -3.4, 1.0, 0], ["hammock", 3.3, -0.35, 6], ["market_fruit", 2.8, 1.75, 7],
	["torii_gate", 0.2, 3.55, 0], ["pier", -1.9, 4.55, 0], ["tulip_patch", 0.95, 2.6, 0], ["street_lamp", 1.75, 3.0, 0],
	["parasol_table", -1.3, 2.35, 0], ["fence_hedge", -2.4, 3.05, 7], ["stone_lantern", -0.6, 3.5, 0], ["tree_pine", 3.7, 0.9, 0], ["swing", 3.0, -1.35, 7], ["signpost", 0.75, 1.9, 1]],
	[["windmill", -3.9, 0.9, 0], ["hot_spring", -2.5, 2.4, 0], ["bridge_islet", 5.25, 1.35, 0], ["lighthouse", 7.25, 0.95, 0],
	["tree_palm", 6.45, 2.1, 0], ["tree_palm", 7.6, 2.0, 0], ["shell_pile", 6.9, 2.45, 0], ["fountain", 1.0, 2.45, 0],
	["string_lights", 2.6, 2.9, 7], ["ramen_cart", 3.4, 1.4, 7], ["tree_sakura", -4.1, -0.9, 0], ["koinobori", 3.9, -0.9, 0],
	["mailbox", -1.2, -1.2, 0], ["tanabata_bamboo", -0.5, 3.6, 0], ["bulletin_board", 1.9, -1.35, 0], ["picnic_mat", 2.1, 3.9, 0]],
]


static func demo_layout(stage: int) -> void:
	_loaded = true
	placed = []
	stock = {}
	var u := 1
	for s in mini(stage, DEMO.size() - 1) + 1:
		for d in DEMO[s]:
			placed.append({"u": u, "id": d[0], "x": d[1], "z": d[2], "r": d[3]})
			u += 1
	_next_uid = u


## テストや「はじめから」用
static func reset() -> void:
	_loaded = true
	_starter()
	_next_uid = 1
	_save()
