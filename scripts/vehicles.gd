class_name Vehicles
## ほかの人の島へおでかけするときの乗り物。見た目だけ：速さ・もらえる物・遊びの有利さは、どれでも同じ。
## いかだ（はじめから）・ボート・フェリー・水上飛行機・ヘリ、と見本の有料 2 つ（紙の舟・大きな鯉。いまは買えない）。
## 手に入れ方：肉球コイン＋島の材料（IslandKit）で作る、またはすくい・孵化から grant(id)。
## 保存は user://vehicles.json（OBAKE_NOSAVE=1 で保存しない）。見た目は VehicleProps.build(id)。

const PATH := "user://vehicles.json"

## 順番がシェアのコードの番号なので、後ろに足すだけにする。fly は空を飛ぶ（おでかけの場面の高さだけ）
const LIST := [
	{"id": "raft", "price": 0, "mats": {}, "fly": false},
	{"id": "rowboat", "price": 60, "mats": {"wood": 6, "cloth": 1}, "fly": false},
	{"id": "ferry", "price": 180, "mats": {"wood": 10, "stone": 4, "cloth": 3}, "fly": false},
	{"id": "seaplane", "price": 260, "mats": {"cloth": 5, "shell": 3, "paper": 2}, "fly": true},
	{"id": "helicopter", "price": 320, "mats": {"stone": 6, "shell": 4, "cloth": 4}, "fly": true},
	# 見本の有料（見た目だけ。コイン・材料とは混ぜない）
	{"id": "paper_boat", "premium": true, "yen": 240, "fly": false},
	{"id": "giant_koi", "premium": true, "yen": 480, "fly": false},
]

static var _loaded := false
static var _owned: Array = ["raft"]
static var _current := "raft"


static func info(id: String) -> Dictionary:
	for v in LIST:
		if v.id == id:
			return v
	return {}


static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i].id == id:
			return i
	return 0


static func name_of(id: String) -> String:
	return TranslationServer.translate("VEH_" + id)


## 持っている乗り物（mainline 用）
static func owned() -> Array:
	_ensure()
	return _owned.duplicate()


## いま乗る乗り物（mainline 用）
static func current() -> String:
	_ensure()
	return _current


static func set_current(id: String) -> void:
	_ensure()
	if _owned.has(id):
		_current = id
		_save()


## すくい・孵化などから乗り物をもらう（mainline 用）。見本の有料は渡せない
static func grant(id: String) -> bool:
	_ensure()
	var v := info(id)
	if v.is_empty() or v.get("premium", false) or _owned.has(id):
		return false
	_owned.append(id)
	_save()
	return true


## 足りない分 {"coins": n, <材料>: n}
static func missing(id: String) -> Dictionary:
	var v := info(id)
	var out := {}
	if v.is_empty() or v.get("premium", false):
		return {"premium": 1}
	var short: int = int(v.price) - Wallet.balance()
	if short > 0:
		out["coins"] = short
	for k in v.mats:
		var s: int = int(v.mats[k]) - IslandKit.count(k)
		if s > 0:
			out[k] = s
	return out


## コインと材料で作る。足りなければ false（何も減らさない）。有料の見本は作れない
static func buy(id: String) -> bool:
	_ensure()
	if _owned.has(id) or not missing(id).is_empty():
		return false
	var v := info(id)
	if not IslandKit.spend(int(v.price), v.mats, "vehicle:" + id):
		return false
	_owned.append(id)
	_current = id
	_save()
	return true


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if OS.get_environment("OBAKE_NOSAVE") != "" or not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f else null
	if d is Dictionary:
		_owned = d.get("owned", ["raft"])
		if not _owned.has("raft"):
			_owned.push_front("raft")
		_current = d.get("current", "raft")


static func _save() -> void:
	if OS.get_environment("OBAKE_NOSAVE") != "":
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"owned": _owned, "current": _current}))


## テスト・確認用
static func reset(owned_ids: Array = ["raft"], cur := "raft") -> void:
	_loaded = true
	_owned = owned_ids.duplicate()
	if not _owned.has("raft"):
		_owned.push_front("raft")
	_current = cur if _owned.has(cur) else "raft"
