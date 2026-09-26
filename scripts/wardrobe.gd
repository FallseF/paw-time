class_name Wardrobe
## キセカエの持ち物と、だれが何を着ているか。保存は user://wardrobe.json（ほかのセーブと独立）。
##
## 外から使うとき（すくい・孵化・島など本線のコード）
##   Wardrobe.grant(item_id) -> bool          手に入れる（はじめてなら true、NEW 印がつく）
##   Wardrobe.random_drop(rarity) -> String   光る玉の中身として 1 つ選ぶ（"common" / "rare"）。持っていない物を優先。
##                                            選ぶだけで、渡すのは grant()。空文字なら、もう全部ある
##   Wardrobe.check_unlocks() -> Array        仕事・眠り・図鑑の条件で届いた物（朝や画面を開いたときに呼ぶ）
##   Wardrobe.outfit_of(obake_id) -> Dictionary   {slot: item_id, "tint": id}
##   Outfit.make(obake_id) -> Obake3D         着せた姿で作る（庭・島・店で Obake3D.make の代わりに）
##   OutfitReveal.open(parent, item_id)       「新しい服！」の演出
##
## 特別な棚（premium）は見本：買えない。肉球コインやポイとは混ざらない。

const PATH := "user://wardrobe.json"

static var _loaded := false
static var owned := {} # item_id → true
static var fresh := {} # まだ見ていない（NEW 印）
static var tints := {"": true, "cream": true, "mint": true}
static var outfits := {} # obake_id → {slot: item_id, "tint": id}


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	for it in WardrobeData.ITEMS:
		if WardrobeData.kind(it) == "free":
			owned[it.id] = true
	if OS.get_environment("OBAKE_NOSAVE") != "" or not FileAccess.file_exists(PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not d is Dictionary:
		return
	for id in d.get("owned", []):
		if not WardrobeData.item(id).is_empty():
			owned[id] = true
	for id in d.get("fresh", []):
		fresh[id] = true
	for id in d.get("tints", []):
		tints[id] = true
	var o = d.get("outfits", {})
	if o is Dictionary:
		outfits = o


static func save() -> void:
	if OS.get_environment("OBAKE_NOSAVE") != "":
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"owned": owned.keys(), "fresh": fresh.keys(), "tints": tints.keys(), "outfits": outfits}))


static func has(id: String) -> bool:
	_ensure()
	return owned.has(id)


static func grant(id: String) -> bool:
	_ensure()
	var it := WardrobeData.item(id)
	if it.is_empty() or owned.has(id) or WardrobeData.kind(it) == "premium":
		return false
	owned[id] = true
	fresh[id] = true
	save()
	return true


## 光る玉の中身。rarity は "common" / "rare"（虹の玉）。持っていない物から選ぶ
static func random_drop(rarity := "common") -> String:
	_ensure()
	var pool: Array = []
	for it in WardrobeData.ITEMS:
		if it.src == "orb:" + rarity and not owned.has(it.id):
			pool.append(it.id)
	if pool.is_empty() and rarity == "rare":
		return random_drop("common")
	return pool.pick_random() if not pool.is_empty() else ""


## 肉球コインで買う
static func buy(id: String) -> bool:
	_ensure()
	var it := WardrobeData.item(id)
	var p := WardrobeData.price(it)
	if p < 0 or owned.has(id):
		return false
	if not Wallet.spend(p, "wardrobe:" + id):
		return false
	owned[id] = true
	save()
	return true


static func buy_tint(tid: String) -> bool:
	_ensure()
	var t := WardrobeData.tint(tid)
	var p: PackedStringArray = String(t.src).split(":")
	if tints.has(tid) or p[0] != "shop":
		return false
	if not Wallet.spend(int(p[1]), "tint:" + tid):
		return false
	tints[tid] = true
	save()
	return true


static func outfit_of(obake_id: String) -> Dictionary:
	_ensure()
	return outfits.get(obake_id, {})


static func set_outfit(obake_id: String, o: Dictionary) -> void:
	_ensure()
	var clean := {}
	for slot in WardrobeData.SLOTS:
		var id: String = o.get(slot, "")
		if id != "" and owned.has(id):
			clean[slot] = id
	if o.get("tint", "") != "" and tints.has(o.tint):
		clean["tint"] = o.tint
	if clean.is_empty():
		outfits.erase(obake_id)
	else:
		outfits[obake_id] = clean
	save()


static func seen_all() -> void:
	fresh.clear()
	save()


## 条件で届く物。GameState を読むだけで、長く働いたり寝たりしても多くはもらえない
static func check_unlocks() -> Array:
	_ensure()
	var got: Array = []
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
	if gs == null:
		return got
	var streak := 0
	for i in range(gs.good_hist.size() - 1, -1, -1):
		if not gs.good_hist[i]:
			break
		streak += 1
	var rare_n := 0
	var normal_all := true
	for id in gs.seen:
		if Rares.is_rare(id):
			rare_n += 1
	for id in ["receipt", "bubble", "tray", "pan", "box"]:
		if not gs.seen.has(id):
			normal_all = false
	for it in WardrobeData.ITEMS:
		if owned.has(it.id):
			continue
		var p: PackedStringArray = String(it.src).split(":")
		var ok := false
		match p[0]:
			"job":
				ok = gs.roles_seen.has(p[1]) or gs.decos.get(p[1], 0) > 0 or gs.chores.get(p[1], 0) > 0
			"sleep":
				ok = streak >= int(p[1])
			"rares":
				ok = rare_n >= int(p[1])
			"normal_all":
				ok = normal_all
		if ok and grant(it.id):
			got.append(it.id)
	return got


## ---- シェアのコード用：着ている物を 7 バイトに（6 か所＋色）。0 はなし ----
static func pack(obake_id: String) -> PackedByteArray:
	var o := outfit_of(obake_id)
	var b := PackedByteArray()
	for slot in WardrobeData.SLOTS:
		b.append(WardrobeData.index_of(o.get(slot, "")) + 1)
	var ti := 0
	for i in WardrobeData.TINTS.size():
		if WardrobeData.TINTS[i].id == o.get("tint", ""):
			ti = i
	b.append(ti)
	return b


static func unpack(b: PackedByteArray) -> Dictionary:
	var o := {}
	for i in mini(6, b.size()):
		var k: int = b[i] - 1
		if k >= 0 and k < WardrobeData.ITEMS.size():
			o[WardrobeData.SLOTS[i]] = WardrobeData.ITEMS[k].id
	if b.size() >= 7 and b[6] > 0 and b[6] < WardrobeData.TINTS.size():
		o["tint"] = WardrobeData.TINTS[b[6]].id
	return o


## テスト・はじめから用
static func reset() -> void:
	_loaded = true
	owned = {}
	fresh = {}
	tints = {"": true, "cream": true, "mint": true}
	outfits = {}
	for it in WardrobeData.ITEMS:
		if WardrobeData.kind(it) == "free":
			owned[it.id] = true
	save()
