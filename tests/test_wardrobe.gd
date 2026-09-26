extends SceneTree
## キセカエのテスト：手に入れる・玉から出す・買う・着る・シェアのコード（版3と、古い版2）。
##   OBAKE_NOSAVE=1 godot --headless --path . -s tests/test_wardrobe.gd
var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", what)


func _initialize() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	Wardrobe.reset()
	Wallet.reset(0)
	check(WardrobeData.ITEMS.size() >= 40, "40 点以上")
	var ids := {}
	for it in WardrobeData.ITEMS:
		check(not ids.has(it.id), "id の重複 " + it.id)
		ids[it.id] = true
		check(it.slot in WardrobeData.SLOTS, "場所 " + it.id)
		check(Outfit.new().has_method("_b_" + it.shape), "形 " + it.shape)
	# 手に入れる
	check(Wardrobe.grant("beret"), "grant")
	check(not Wardrobe.grant("beret"), "2 回目は false")
	check(not Wardrobe.grant("kimono"), "特別な棚は grant できない")
	var d := Wardrobe.random_drop("common")
	check(WardrobeData.item(d).src == "orb:common", "玉の中身（ふつう）")
	var r := Wardrobe.random_drop("rare")
	check(WardrobeData.item(r).src == "orb:rare", "玉の中身（虹）")
	# 玉の中身は Drops だけが引く：服の枝は Wardrobe.random_drop、手に入れたら持ち物と朝の見せる列へ
	var dc := Drops._roll_cloth("common")
	check(dc.kind == "cloth" and WardrobeData.item(dc.id).src == "orb:common", "Drops の服は玉の服 " + str(dc))
	gs.new_outfits.clear()
	check(Drops.grant(dc) and Wardrobe.has(dc.id) and gs.new_outfits.has(dc.id), "Drops.grant で服が届く")
	check(not Drops.grant(dc), "同じ服は 2 回目は新しくない")
	var coins0 := Wallet.balance()
	gs.orbs = [{"type": "hall", "rare": false, "content": {"kind": "obake"}}]
	gs.sleep(330, 420)
	check((Wallet.balance() - coins0) % 10 == 0, "孵化ではコインは増えない（めあての +10 だけ） %d" % (Wallet.balance() - coins0))
	# 頭に服を着たら、頭の持ち物（オボンのお盆）を隠す。手の服ではお盆は隠さない
	var tray: Obake3D = Outfit.make("tray", {"head": "top_hat"})
	check(not tray.body.get_node("Prop").visible, "お盆は帽子の下に隠れる")
	Outfit.dress(tray, {"hand": "hall_tray"})
	check(tray.body.get_node("Prop").visible, "頭に何も無ければお盆は出る")
	tray.free()
	# 買う
	check(not Wardrobe.buy("top_hat"), "コインが足りない")
	Wallet.reset(500)
	check(Wardrobe.buy("top_hat") and Wallet.balance() == 360, "買う")
	check(not Wardrobe.buy("kimono"), "特別な棚は買えない")
	# 条件
	gs.reset("data")
	gs.roles_seen["kitchen"] = true
	gs.good_hist = [true, true, true]
	var got := Wardrobe.check_unlocks()
	check(got.has("chef_hat") and got.has("chef_scarf") and got.has("nightcap") and not got.has("pajamas"), "仕事と眠り " + str(got))
	# 着る・コード
	Wardrobe.set_outfit(gs.host(), {"head": "top_hat", "neck": "red_scarf", "back": "kimono"})
	check(not Wardrobe.outfit_of(gs.host()).has("back"), "持っていない物は着ない")
	var p := Wardrobe.pack(gs.host())
	check(Wardrobe.unpack(p) == Wardrobe.outfit_of(gs.host()), "7 バイトの往復")
	gs.orbs = [{"type": "hall", "rare": false}]
	gs.sleep(330, 420)
	var code: String = gs.island_code(["flowerbed"])
	var isl: Dictionary = gs.decode_island(code)
	check(isl.outfits.get(gs.host(), {}).get("head", "") == "top_hat", "島のコードに服 " + str(isl.get("outfits")))
	# 古い版2のコード（服の部分がない）も読める
	Wardrobe.set_outfit(gs.host(), {})
	var c2: String = gs.island_code(["flowerbed"])
	var raw := Marshalls.base64_to_raw(_pad(c2))
	raw[0] = 2
	raw = raw.slice(0, raw.size() - 1)
	var old := Marshalls.raw_to_base64(raw).replace("+", "-").replace("/", "_").replace("=", "")
	var od: Dictionary = gs.decode_island(old)
	check(not od.is_empty() and od.outfits.is_empty(), "版2も読める")
	print("code v3 len=", code.length())
	print("test_wardrobe: ", "OK" if fails == 0 else "FAIL", " (", fails, " failures)")
	quit(0 if fails == 0 else 1)


func _pad(c: String) -> String:
	c = c.replace("-", "+").replace("_", "/")
	while c.length() % 4 != 0:
		c += "="
	return c
