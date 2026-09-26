extends SceneTree
## 島のコードの往復テスト：encode → decode で同じ配置に戻るか。godot --headless --path . -s tests/island_code.gd
var ok_kit := true


func _pad(c: String) -> String:
	while c.length() % 4 != 0:
		c += "="
	return c


func _initialize() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.reset("data")
	for d in 12:
		if gs.today().role != "":
			gs.finish_shift()
		gs.orbs = [{"type": "hall", "rare": false}]
		gs.sleep(330, 420)
	gs.nickname = "みか"
	gs.layout = {"flowerbed": {"x": 1.5, "z": -0.75, "r": 3}, "deco_hall": {"x": -1.0, "z": 0.5, "r": 0}, "pond": {"h": true}}
	var present := ["flowerbed", "lantern", "pond", "deco_hall", "deco_register"]
	# 置き物キット：買って置いた物（版3のコードに入る）
	IslandKit.reset()
	Wallet.reset(500)
	ok_kit = IslandKit.buy("bench") == true # はじめの材料で買える
	ok_kit = ok_kit and IslandKit.buy("lighthouse") == false # 材料が足りない
	ok_kit = ok_kit and IslandKit.buy("festival_yagura") == false # 見本の有料は買えない
	ok_kit = ok_kit and Wallet.balance() == 500 - 15
	IslandKit.place("bench", 1.25, -0.5, 2)
	IslandKit.place("flower_pot", -2.0, 1.75, 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var drop := IslandKit.random_drop(rng)
	ok_kit = ok_kit and IslandKit.MATERIALS.has(drop.kind) and drop.n >= 1
	var code: String = gs.island_code(present)
	var d: Dictionary = gs.decode_island(code)
	var ok := ok_kit
	ok = ok and d.level == gs.garden_level
	ok = ok and d.kit.size() == 2 and d.kit[0].id == "bench" and absf(d.kit[0].x - 1.25) < 0.05 and absf(d.kit[0].z + 0.5) < 0.05 and d.kit[0].r == 2
	ok = ok and d.kit[1].id == "flower_pot" and absf(d.kit[1].x + 2.0) < 0.05
	# 版2のコード（置き物キットが無い）も読める
	var raw := Marshalls.base64_to_raw(_pad(code.replace("-", "+").replace("_", "/")))
	raw = raw.slice(0, raw.size() - 2 - 4 * 2)
	raw[0] = 2
	var v2 := Marshalls.raw_to_base64(raw).replace("+", "-").replace("/", "_").replace("=", "")
	var dv2: Dictionary = gs.decode_island(v2)
	ok = ok and dv2.get("name", "") == "みか" and dv2.kit.is_empty() and dv2.layout.has("flowerbed")
	ok = ok and d.name == "みか"
	ok = ok and d.host == gs.host()
	ok = ok and d.residents.size() == mini(12, gs.owned.size())
	ok = ok and absf(d.layout.flowerbed.x - 1.5) < 0.06 and absf(d.layout.flowerbed.z + 0.75) < 0.06 and d.layout.flowerbed.r == 3
	ok = ok and not d.items.has("pond") # しまった物はコードに入らない
	ok = ok and d.items.has("lantern") and not d.layout.has("lantern") # 動かしていない物は元の場所
	ok = ok and d.decos.get("hall", 0) >= 1
	var d2: Dictionary = gs.decode_island("https://obake-breakroom-b-sleep.vercel.app/#island=" + code)
	ok = ok and d2.name == "みか"
	ok = ok and gs.decode_island("こわれた").is_empty() and gs.decode_island("AAAA").is_empty()
	print("code=", code, " len=", code.length())
	print("ISLAND ROUNDTRIP ", "OK" if ok else "FAIL", " ", d)
	quit(0 if ok else 1)
