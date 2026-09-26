class_name WardrobeData
## キセカエの中身：6 つの場所（slot）と、服・小物の一覧、手に入れ方。
## 並び（ITEMS の順番）はシェアのコードに使うので、足すときは必ず末尾に足す。
##
## 手に入れ方（src）
##   job:<仕事>     その仕事をはじめてしたら、制服ひとそろい（何時間働いても同じ）
##   sleep:<夜>     よく眠れた夜が続いた回数（連続）
##   rares:<体>     レアに会った数 ／ normal_all ふつうのおばけを全部
##   orb:<common|rare>  光る玉の中から（Wardrobe.random_drop）
##   shop:<コイン>  肉球コインのお店
##   free           はじめから
##   premium:<ドル>:<円>  特別な棚（見本。本当の支払いはない）
## 名前は英語が正本（tr() のキー）。日本語は i18n/wardrobe.csv。

const SLOTS := ["head", "face", "neck", "body", "hand", "back"]
const SLOT_NAME := {"head": "Head", "face": "Face", "neck": "Neck", "body": "Body", "hand": "Hand", "back": "Back"}

## id, slot, name, src, c（主な色）, c2（差し色）, shape（Outfit の組み方）
const ITEMS := [
	# ---- 仕事の制服（その仕事をしたら） ----
	{"id": "reg_vest", "slot": "body", "name": "Register vest", "src": "job:register", "c": "f2b233", "c2": "fffaf2", "shape": "vest"},
	{"id": "reg_visor", "slot": "head", "name": "Cashier visor", "src": "job:register", "c": "f2b233", "c2": "ffffff", "shape": "visor"},
	{"id": "dish_apron", "slot": "body", "name": "Dish apron", "src": "job:dish", "c": "5fc4ff", "c2": "ffffff", "shape": "apron"},
	{"id": "dish_gloves", "slot": "hand", "name": "Rubber gloves", "src": "job:dish", "c": "ffd23f", "c2": "ffd23f", "shape": "gloves"},
	{"id": "hall_bowtie", "slot": "neck", "name": "Bow tie", "src": "job:hall", "c": "2e222f", "c2": "e8505b", "shape": "bowtie"},
	{"id": "hall_tray", "slot": "hand", "name": "Silver tray", "src": "job:hall", "c": "c8ced6", "c2": "ffcf5a", "shape": "tray"},
	{"id": "chef_hat", "slot": "head", "name": "Chef hat", "src": "job:kitchen", "c": "ffffff", "c2": "e8e2d8", "shape": "chef_hat"},
	{"id": "chef_scarf", "slot": "neck", "name": "Chef scarf", "src": "job:kitchen", "c": "e8505b", "c2": "ffffff", "shape": "neckerchief"},
	{"id": "stock_cap", "slot": "head", "name": "Stock cap", "src": "job:stock", "c": "6b8f5a", "c2": "fff2c8", "shape": "cap"},
	{"id": "work_gloves", "slot": "hand", "name": "Work gloves", "src": "job:stock", "c": "e8c48e", "c2": "8a6a44", "shape": "gloves"},

	# ---- よく眠る（連続） ----
	{"id": "nightcap", "slot": "head", "name": "Nightcap", "src": "sleep:3", "c": "5b6fc2", "c2": "fff1c8", "shape": "nightcap"},
	{"id": "pajamas", "slot": "body", "name": "Star pajamas", "src": "sleep:5", "c": "a9b8ff", "c2": "fff1c8", "shape": "pajamas"},
	{"id": "sleep_mask", "slot": "face", "name": "Sleep mask", "src": "sleep:7", "c": "8b7bff", "c2": "fff1c8", "shape": "sleep_mask"},
	{"id": "pillow", "slot": "back", "name": "Pillow pack", "src": "sleep:10", "c": "f4f1ea", "c2": "8fb4ff", "shape": "pillow"},

	# ---- 図鑑のごほうび ----
	{"id": "star_glasses", "slot": "face", "name": "Star glasses", "src": "rares:1", "c": "ffd23f", "c2": "2e222f", "shape": "star_glasses"},
	{"id": "crown", "slot": "head", "name": "Little crown", "src": "rares:5", "c": "ffd23f", "c2": "e8505b", "shape": "crown"},
	{"id": "angel_wings", "slot": "back", "name": "Angel wings", "src": "rares:10", "c": "ffffff", "c2": "ffe7a8", "shape": "wings"},
	{"id": "halo", "slot": "head", "name": "Halo", "src": "rares:20", "c": "ffe27a", "c2": "ffffff", "shape": "halo"},
	{"id": "party_hat", "slot": "head", "name": "Party hat", "src": "normal_all", "c": "ff8fb1", "c2": "5fc4ff", "shape": "party_hat"},

	# ---- 光る玉の中から ----
	{"id": "flower_crown", "slot": "head", "name": "Flower crown", "src": "orb:common", "c": "ff8fb1", "c2": "8fd18a", "shape": "flower_crown"},
	{"id": "leaf_sprout", "slot": "head", "name": "Leaf sprout", "src": "orb:common", "c": "6cbf5a", "c2": "4f8a5b", "shape": "sprout"},
	{"id": "bell_collar", "slot": "neck", "name": "Bell collar", "src": "orb:common", "c": "e8505b", "c2": "ffd23f", "shape": "bell_collar"},
	{"id": "balloon", "slot": "hand", "name": "Balloon", "src": "orb:common", "c": "ff6b5b", "c2": "ffffff", "shape": "balloon"},
	{"id": "firefly_jar", "slot": "hand", "name": "Firefly jar", "src": "orb:common", "c": "d8ff9a", "c2": "cfe8ff", "shape": "jar"},
	{"id": "bat_wings", "slot": "back", "name": "Bat wings", "src": "orb:rare", "c": "5b4a9e", "c2": "2e222f", "shape": "bat_wings"},
	{"id": "moon_cape", "slot": "back", "name": "Moon cape", "src": "orb:rare", "c": "2b3478", "c2": "ffe27a", "shape": "cape"},
	{"id": "rainbow_scarf", "slot": "neck", "name": "Rainbow scarf", "src": "orb:rare", "c": "ff8fb1", "c2": "7fe3ff", "shape": "rainbow_scarf"},

	# ---- 肉球コインのお店 ----
	{"id": "beanie", "slot": "head", "name": "Knit beanie", "src": "shop:60", "c": "e8505b", "c2": "ffffff", "shape": "beanie"},
	{"id": "beret", "slot": "head", "name": "Beret", "src": "shop:80", "c": "3a3f8f", "c2": "3a3f8f", "shape": "beret"},
	{"id": "straw_hat", "slot": "head", "name": "Straw hat", "src": "shop:90", "c": "f2d58c", "c2": "e8505b", "shape": "straw_hat"},
	{"id": "top_hat", "slot": "head", "name": "Tiny top hat", "src": "shop:140", "c": "2e222f", "c2": "e8505b", "shape": "top_hat"},
	{"id": "hair_bow", "slot": "head", "name": "Big bow", "src": "shop:50", "c": "ff8fb1", "c2": "ff8fb1", "shape": "bow_head"},
	{"id": "round_glasses", "slot": "face", "name": "Round glasses", "src": "shop:60", "c": "3d3b4f", "c2": "cfe8ff", "shape": "round_glasses"},
	{"id": "sunglasses", "slot": "face", "name": "Sunglasses", "src": "shop:90", "c": "2e222f", "c2": "2e222f", "shape": "sunglasses"},
	{"id": "mustache", "slot": "face", "name": "Fake mustache", "src": "shop:40", "c": "4a3228", "c2": "4a3228", "shape": "mustache"},
	{"id": "striped_scarf", "slot": "neck", "name": "Striped scarf", "src": "shop:70", "c": "5fc4ff", "c2": "ffffff", "shape": "scarf"},
	{"id": "necktie", "slot": "neck", "name": "Necktie", "src": "shop:60", "c": "3a6fd8", "c2": "ffd23f", "shape": "necktie"},
	{"id": "raincoat", "slot": "body", "name": "Raincoat", "src": "shop:150", "c": "ffd23f", "c2": "e8a317", "shape": "raincoat"},
	{"id": "sweater", "slot": "body", "name": "Cozy sweater", "src": "shop:120", "c": "8fd18a", "c2": "ffffff", "shape": "sweater"},
	{"id": "overalls", "slot": "body", "name": "Overalls", "src": "shop:120", "c": "5b7fc2", "c2": "ffd23f", "shape": "overalls"},
	{"id": "umbrella", "slot": "hand", "name": "Umbrella", "src": "shop:100", "c": "7fb8ff", "c2": "ffffff", "shape": "umbrella"},
	{"id": "fish", "slot": "hand", "name": "Fish snack", "src": "shop:30", "c": "8fb4d8", "c2": "ff8a5b", "shape": "fish"},
	{"id": "backpack", "slot": "back", "name": "Backpack", "src": "shop:110", "c": "ff8a5b", "c2": "fff2c8", "shape": "backpack"},
	{"id": "tote", "slot": "back", "name": "Tote bag", "src": "shop:70", "c": "f4efe6", "c2": "3a6fd8", "shape": "tote"},
	{"id": "shell", "slot": "back", "name": "Snail shell", "src": "shop:130", "c": "e8b878", "c2": "b07a4a", "shape": "shell"},

	# ---- はじめから ----
	{"id": "flower_pin", "slot": "head", "name": "Flower pin", "src": "free", "c": "ffd23f", "c2": "ffffff", "shape": "flower"},
	{"id": "red_scarf", "slot": "neck", "name": "Red scarf", "src": "free", "c": "e8505b", "c2": "e8505b", "shape": "scarf"},

	# ---- 特別な棚（見本・ほかでは手に入らない・遊びの強さは変わらない） ----
	{"id": "kimono", "slot": "body", "name": "Festival yukata", "src": "premium:1.99:300", "c": "3a3f8f", "c2": "ff8fb1", "shape": "yukata"},
	{"id": "astro_helmet", "slot": "head", "name": "Space helmet", "src": "premium:1.99:300", "c": "e6f4ff", "c2": "ff8a5b", "shape": "helmet"},
	{"id": "dragon_tail", "slot": "back", "name": "Dragon wings", "src": "premium:2.99:450", "c": "7fd18a", "c2": "ffd23f", "shape": "dragon_wings"},
]

## マイおばけ猫の体の色（はじめ 3 色は無料、ほかはお店）
const TINTS := [
	{"id": "", "name": "Original", "c": "", "src": "free"},
	{"id": "cream", "name": "Cream", "c": "fff1d6", "src": "free"},
	{"id": "mint", "name": "Mint", "c": "9fe3c8", "src": "free"},
	{"id": "peach", "name": "Peach", "c": "ffb3a0", "src": "shop:50"},
	{"id": "lilac", "name": "Lilac", "c": "c9b8ff", "src": "shop:50"},
	{"id": "night", "name": "Midnight", "c": "4a4f8f", "src": "shop:80"},
]

static var _by_id := {}


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


static func in_slot(slot: String) -> Array:
	var out: Array = []
	for it in ITEMS:
		if it.slot == slot:
			out.append(it)
	return out


static func kind(it: Dictionary) -> String:
	return String(it.src).split(":")[0]


static func price(it: Dictionary) -> int:
	var p: PackedStringArray = String(it.src).split(":")
	return int(p[1]) if p[0] == "shop" else -1


static func tint(id: String) -> Dictionary:
	for t in TINTS:
		if t.id == id:
			return t
	return TINTS[0]


const JOB_NAME := {"register": "Register", "dish": "Dishwashing", "hall": "Hall", "kitchen": "Kitchen", "stock": "Stocking"}


## どうやったら手に入るか（まだ持っていないとき、カードの下に出す）
static func how_to_get(it: Dictionary) -> String:
	var p: PackedStringArray = String(it.src).split(":")
	match p[0]:
		"job":
			return TranslationServer.translate("Do a %s shift once") % TranslationServer.translate(JOB_NAME[p[1]])
		"sleep":
			return TranslationServer.translate("Sleep well %s nights in a row") % p[1]
		"rares":
			return TranslationServer.translate("Meet %s rare obake") % p[1]
		"normal_all":
			return TranslationServer.translate("Meet every common obake")
		"orb":
			return TranslationServer.translate("Hidden in glowing orbs") if p[1] == "common" else TranslationServer.translate("Hidden in rainbow orbs")
		"shop":
			return TranslationServer.translate("%s Paw Coins") % p[1]
		"premium":
			return "$%s / ¥%s" % [p[1], p[2]]
	return ""
