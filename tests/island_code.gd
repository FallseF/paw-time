extends SceneTree
## 島のコードの往復テスト：encode → decode で同じ配置に戻るか。版5（服＋置き物＋広げた場所＋乗り物）と、版1〜4（キセカエの版3・島キットの版3の両方）を読む。
##godot --headless --path . -s tests/island_code.gd
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
	# 島を広げる（右手前の陸と、手前の小島）と、乗り物
	IslandKit.grant_material("wood", 30)
	IslandKit.grant_material("stone", 30)
	IslandKit.grant_material("shell", 5)
	ok_kit = ok_kit and IslandKit.expand("plot_front_right") and IslandKit.expand("islet_front")
	ok_kit = ok_kit and not IslandKit.expand("plot_front_right") # 同じ所は 2 回広げない
	Vehicles.reset(["raft", "seaplane"], "seaplane")
	ok_kit = ok_kit and not Vehicles.grant("giant_koi") # 見本の有料は渡せない
	ok_kit = ok_kit and Vehicles.grant("rowboat") and Vehicles.owned().has("rowboat")
	Vehicles.set_current("seaplane")
	# キセカエ：あるじに服を着せる（版5 に入る）
	Wardrobe.reset()
	Wardrobe.grant("beret")
	Wardrobe.set_outfit(gs.host(), {"head": "beret"})
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
	ok = ok and d.expansions == ["plot_front_right", "islet_front"] and d.vehicle == "seaplane"
	ok = ok and d.outfits.get(gs.host(), {}).get("head", "") == "beret"
	# 古い版を、今のコードの後ろの部分を組みかえて作る（あと＝服 9・置き物 2+4×2・広げた場所 3・乗り物 1）
	var raw := Marshalls.base64_to_raw(_pad(code.replace("-", "+").replace("_", "/")))
	var outfit_b := PackedByteArray([1, 255])
	outfit_b.append_array(Wardrobe.pack(gs.host()))
	var kit_b := IslandKit.encode(IslandKit.placed)
	var exp_b := IslandKit.encode_expansions(IslandKit.expansions())
	var veh_b := PackedByteArray([Vehicles.index_of(Vehicles.current())])
	var base := raw.slice(0, raw.size() - outfit_b.size() - kit_b.size() - exp_b.size() - veh_b.size())
	ok = ok and base + outfit_b + kit_b + exp_b + veh_b == raw
	# 版2（服も置き物も無い）
	var dv2: Dictionary = gs.decode_island(_code(2, base))
	ok = ok and dv2.get("name", "") == "みか" and dv2.kit.is_empty() and dv2.outfits.is_empty() and dv2.expansions.is_empty() and dv2.vehicle == "raft" and dv2.layout.has("flowerbed")
	# キセカエの版3（服だけ）
	var dw3: Dictionary = gs.decode_island(_code(3, base + outfit_b))
	ok = ok and dw3.outfits.get(gs.host(), {}).get("head", "") == "beret" and dw3.kit.is_empty()
	# 島キットの版3（置き物だけ）
	var dk3: Dictionary = gs.decode_island(_code(3, base + kit_b))
	ok = ok and dk3.kit.size() == 2 and dk3.outfits.is_empty() and dk3.expansions.is_empty()
	# 島キットの版4（置き物・広げた場所・乗り物）
	var dk4: Dictionary = gs.decode_island(_code(4, base + kit_b + exp_b + veh_b))
	ok = ok and dk4.kit.size() == 2 and dk4.expansions == ["plot_front_right", "islet_front"] and dk4.vehicle == "seaplane" and dk4.outfits.is_empty()
	print("versions: v2 %s / wardrobe v3 %s / kit v3 %s / kit v4 %s" % [not dv2.is_empty(), dw3.outfits.size(), dk3.kit.size(), dk4.vehicle])
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


func _code(ver: int, bytes: PackedByteArray) -> String:
	var r := bytes.duplicate()
	r[0] = ver
	return Marshalls.raw_to_base64(r).replace("+", "-").replace("/", "_").replace("=", "")
