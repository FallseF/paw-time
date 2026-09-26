extends SceneTree
## 島のコードの往復テスト：encode → decode で同じ配置に戻るか。godot --headless --path . -s tests/island_code.gd
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
	var code: String = gs.island_code(present)
	var d: Dictionary = gs.decode_island(code)
	var ok := true
	ok = ok and d.level == gs.garden_level
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
