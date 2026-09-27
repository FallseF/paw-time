extends SceneTree
## スキルの記録とおさらいの決まりごとを確かめる（画面は要らない）。
##   OBAKE_NOSAVE=1 godot --headless --path . -s tests/test_skills.gd
## 1. バッジの段：★1 → ★2 → ★3 の順にだけ上がる。飛ばせない。もう一度クリアしても星はふえない
## 2. ごほうび：その段をはじめてクリアしたときだけ（★1 は制服、★2・★3 はポイ 1 本）。コインは出さない
## 3. 本物のシフトは 1 回＝経験 1。1 時間でも 10 時間でも同じ。同じシフトは 2 回数えない
## 4. 記録は保存して読み直せる（店を移っても同じ記録）
## 5. おさらいの問題：おつりの計算・皿洗いの順番・席の選び方・手洗いが最初・先入れ先出し
## 6. 画面の文字（おさらい・スキル）が英語と日本語の両方にある

var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", what)


func _initialize() -> void:
	await process_frame
	if OS.get_environment("OBAKE_NOSAVE") == "":
		print("run with OBAKE_NOSAVE=1")
		quit(2)
		return
	TranslationServer.set_locale("en")
	var gs = root.get_node("GameState")
	gs.reset("solo")
	Skills.reset()
	Wardrobe.reset()
	Wallet.reset(0)
	WorkTogether.reset()

	# 1. バッジの段
	check(Skills.stars("register") == 0, "はじめは星なし")
	check(Skills.level_open("register", 1) and not Skills.level_open("register", 2), "★2 はまだ開いていない")
	check(Skills.record_practice("register", 2).is_empty(), "★2 は ★1 の前にクリアできない")
	check(Skills.stars("register") == 0, "飛ばしても星はふえない")
	var r1 := Skills.record_practice("register", 1)
	check(r1.new_star and r1.stars == 1, "★1 をクリア " + str(r1))
	check(Skills.level_open("register", 2), "★1 のあと ★2 が開く")
	var r1b := Skills.record_practice("register", 1)
	check(not r1b.new_star and r1b.stars == 1 and r1b.reward.is_empty(), "もう一度 ★1：星もごほうびもふえない " + str(r1b))
	var r2 := Skills.record_practice("register", 2)
	var r3 := Skills.record_practice("register", 3)
	check(r2.stars == 2 and r3.stars == 3, "★2 → ★3")
	check(Skills.record_practice("register", 4).is_empty(), "★4 はない")
	check(Skills.stars("register") == 3 and Skills.clears("register") == 4, "星 3・クリア 4 回")
	check(Skills.record_practice("cashier", 1).is_empty(), "知らない仕事は記録しない")
	check(Skills.stars("dish") == 0, "ほかの仕事には影響しない")

	# 2. ごほうび（はじめての段だけ。コインは出さない）
	check(r1.reward.get("kind", "") == "cloth" and WardrobeData.item(r1.reward.id).src == "job:register", "★1 は制服 " + str(r1.reward))
	check(Wardrobe.has(r1.reward.id), "制服が手に入る")
	check(r2.reward.get("kind", "") == "poi" and r2.reward.get("id", "") == "receipt", "★2 はレジのポイ " + str(r2.reward))
	check(int(r2.reward.get("n", 0)) <= Skills.REWARD_POI and int(r3.reward.get("n", 0)) <= Skills.REWARD_POI, "ポイは 1 本まで")
	check(Wallet.balance() == 0, "おさらいで肉球コインは出ない（%d）" % Wallet.balance())
	for r in [r1, r2, r3, r1b]:
		check(not r.reward.has("coins") and r.reward.get("kind", "") != "coins", "ごほうびにコインがない")
	# ポイの上限（4 本）はこえない
	gs.nets["bubble"] = 4
	Skills.record_practice("dish", 1)
	var d2 := Skills.record_practice("dish", 2)
	check(gs.nets["bubble"] == 4 and int(d2.reward.get("n", -1)) == 0, "ポイは 4 本まで")
	# 制服を全部持っていたら、★1 は小さなポイ
	for it in WardrobeData.ITEMS:
		if it.src == "job:stock":
			Wardrobe.grant(it.id)
	var s1 := Skills.record_practice("stock", 1)
	check(s1.reward.get("kind", "") == "poi", "制服がそろっていればポイ " + str(s1.reward))

	# 3. シフトは回数だけ（時間は見ない）
	Wallet.reset(0)
	check(Skills.shifts("hall") == 0, "シフトはまだ")
	var t0 := 1790000000.0
	WorkTogether.start("hall", "Cafe A", t0)
	WorkTogether.stop(t0 + 3600.0) # 1 時間
	check(Skills.shifts("hall") == 1, "1 時間のシフトで経験 1（%d）" % Skills.shifts("hall"))
	WorkTogether.start("hall", "Diner B", t0 + 86400.0 * 2)
	WorkTogether.stop(t0 + 86400.0 * 2 + 36000.0) # 10 時間
	check(Skills.shifts("hall") == 2, "10 時間のシフトでも経験 1（%d）" % Skills.shifts("hall"))
	check(Skills.record_shift("kitchen", "shift-42") and not Skills.record_shift("kitchen", "shift-42"), "同じシフトは 2 回数えない")
	check(Skills.shifts("kitchen") == 1, "キッチン 1 回")
	check(not Skills.record_shift("cashier", "x"), "知らない仕事は数えない")
	check(Skills.stars("hall") == 0, "シフトで星はふえない（星はおさらいだけ）")
	check(Skills.badge_text("hall") == "Hall · 2 shifts", "バッジの字 " + Skills.badge_text("hall"))
	check(Skills.badge_text("register") == "Register ★★★", "星だけのバッジ " + Skills.badge_text("register"))
	check(Skills.badge_text("dish") == "Dishwashing ★★", "皿洗いのバッジ " + Skills.badge_text("dish"))
	# 見本の記録（GameState.finish_shift）も 1 回＝1（早送り中は数えない）
	gs.reset("data")
	var before := Skills.shifts(gs.today().role) if gs.today().role != "" else 0
	var role0: String = gs.today().role
	gs.finish_shift()
	if role0 != "" and not gs.today().get("chore", false):
		check(Skills.shifts(role0) == before + 1, "見本のシフトで経験 1")
		gs.shift_done_today = false
		gs.finish_shift()
		check(Skills.shifts(role0) == before + 1, "同じ日のシフトは 2 回数えない")
	# 「2 分のおさらい、する？」は、はじめての仕事だけ
	check(Skills.suggest_practice("kitchen") == false, "キッチンは経験があるので出さない")
	check(Skills.suggest_practice("dish"), "シフトがまだの仕事には出す（★2 でも）")
	check(not Skills.suggest_practice("register"), "★3 までとった仕事には出さない")
	check(not Skills.suggest_practice("hall"), "シフトをした仕事には出さない")

	# 4. 保存と読み直し（店を移っても同じ記録）
	var snap := Skills.to_dict()
	var path := "user://test_skills_roundtrip.json"
	check(Skills.save_to(path), "保存できる")
	Skills.reset()
	check(Skills.stars("register") == 0, "消したら空")
	check(Skills.load_from(path), "読める")
	check(Skills.stars("register") == 3 and Skills.shifts("hall") == 2 and Skills.shifts("kitchen") == 1, "読み直しても同じ " + str(Skills.to_dict()))
	check(JSON.stringify(Skills.to_dict()) == JSON.stringify(snap), "中身がそのまま")
	check(not Skills.record_shift("kitchen", "shift-42"), "読み直しても、数えたシフトは覚えている")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# 壊れた値は丸める
	Skills.from_dict({"roles": {"register": {"stars": 9, "shifts": -3}, "ninja": {"stars": 2}}})
	check(Skills.stars("register") == 3 and Skills.shifts("register") == 0 and Skills.stars("ninja") == 0, "壊れた値は丸める")

	# 5. おさらいの問題
	for lv in [1, 2, 3]:
		for seed in 30:
			for cur in [Money.JPY, Money.USD]:
				for o in PracticeData.register_orders(lv, seed, cur):
					var ch := PracticeData.change_for(o)
					# 円は 10 円単位、ドルは 25¢ 単位（おつりの皿の小銭で作れる）
					check(ch > 0 and ch < 1000 and ch % (25 if cur == Money.USD else 10) == 0, "おつり %d (lv%d %s)" % [ch, lv, cur])
					check(PracticeData.change_ok(o, [ch]) and not PracticeData.change_ok(o, [ch + 10]), "おつりの判定")
					check(o.currency == cur, "注文の通貨")
					var sum := 0
					for it in o.items:
						sum += PracticeData.price_of(it.id, cur) * int(it.qty)
					check(sum == o.total, "合計")
			var dishes := PracticeData.dish_items(lv, seed)
			check(dishes[0] != "glass" and dishes.count("glass") >= 1 and dishes.count("pan") >= 1, "洗い物がまざっている")
			check(PracticeData.dish_next(dishes) == "glass", "グラスから")
			check(PracticeData.dish_next(["pan", "plate"]) == "plate", "お皿がフライパンより先")
			var hall := PracticeData.hall_rounds(lv, seed)
			for h in hall:
				if h.kind == "seat":
					for t in h.ok:
						check(int(PracticeData.TABLES[t]) >= int(h.size), "席に座れる")
			var kt: Dictionary = PracticeData.kitchen_tickets(lv, seed)[0]
			check(kt.steps[0] == "wash", "キッチンは手洗いから")
			check(not kt.avoid in kt.adds, "アレルギーの材料は入れる物にない")
			check((kt.avoid != "") == (lv == 3), "★3 だけアレルギーのメモ")
			var st := PracticeData.stock_rounds(lv, seed)
			for b in st:
				if b.kind == "box":
					check(b.ok == ("front" if b.date < b.shelf_date else "back"), "先入れ先出し")
	check(PracticeData.seat_ok(2, [1, 2, 3]) == [1, 3], "2 人は 2 席の席へ")
	check(PracticeData.seat_ok(3, [1, 2, 3]) == [2], "3 人は 4 席へ")
	check(PracticeData.seat_ok(2, [2]) == [2], "あいていなければ大きい席でも")
	check(PracticeData.register_orders(2, 5) == PracticeData.register_orders(2, 5), "同じ seed は同じ問題")
	# レジのお金：英語＝ドル、日本語＝円（英語の画面に ¥ を出さない）
	check(PracticeData.register_orders(1, 3)[0].currency == Money.USD, "英語のレジはドル")
	check(PracticeData.money_text(1075, Money.USD) == "$10.75" and PracticeData.money_text(1080, Money.JPY) == "¥1,080", "レジのお金の字")
	check(PracticeData.price_of("coffee", Money.USD) == 450 and PracticeData.price_of("coffee") == 300, "品の値段（ドル・円）")

	# 6. 文字（おさらい・スキル）
	for loc in ["en", "ja"]:
		TranslationServer.set_locale(loc)
		var f := FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
		f.get_csv_line()
		while not f.eof_reached():
			var row := f.get_csv_line()
			if row.size() >= 3 and (row[0].begins_with("PR_") or row[0].begins_with("SK_") or row[0].begins_with("SKILL_")):
				var tx := String(TranslationServer.translate(row[0]))
				check(tx != row[0] and tx != "", "訳がない %s [%s]" % [row[0], loc])
	TranslationServer.set_locale("en")

	print("test_skills: ", "OK" if fails == 0 else "FAIL", " (%d failures)" % fails)
	quit(0 if fails == 0 else 1)
