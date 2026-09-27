extends SceneTree
## バランス確認：戦略ごとに 42 日遊んで、庭の段・図鑑を出す（眠りの仕組みは無い。夜は end_night() で明ける）。
## 玉の中身（Drops の割合）も 30 日ぶん数える：おばネコ（玉から・暮らしのレア）、島の材料、服。
## godot --headless --path . -s tests/sim_b.gd
var fails := 0


func _initialize() -> void:
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		gs = load("res://scripts/game_state.gd").new()
		gs.name = "GameState"
		root.add_child(gs)
	await process_frame
	for strat in ["solo_daily", "solo_some_nights", "data_daily", "data_some_nights"]:
		seed(7)
		gs.reset("data" if strat.begins_with("data") else "solo")
		Wardrobe.reset() # 服・材料・乗り物の持ち物も、戦略ごとにまっさらから
		IslandKit.reset()
		Vehicles.reset()
		var line := []
		var levels := {}
		var tally := {"cat_orb": 0, "cat_life_rare": 0, "material": 0, "cloth": 0, "vehicle": 0, "scooped_obake": 0, "scooped_material": 0, "scooped_cloth": 0, "scooped_vehicle": 0}
		var gap := 0
		var max_gap := 0
		for d in 42:
			var s: Dictionary = gs.today()
			# 川べりへ行く夜：毎晩、または週に 4 夜くらい
			var goes: bool = strat.ends_with("daily") or d % 7 in [0, 2, 4, 6]
			if s.role != "":
				gs.finish_shift()
			# すくい：ポイ 1 本で玉 0.9 個くらい、破れにくさで増える
			var poi := 0
			for k in gs.nets:
				poi += gs.nets[k]
			var orbs: Array = gs.tonight_orbs()
			var got := mini(orbs.size(), int(round(minf(poi, 3) * 0.8 * gs.poi_strength()))) if goes else 0
			if goes:
				gs.scooped_tonight = true
			for i in got:
				gs.orbs.append(orbs[i])
				if d < 30:
					var ck := "scooped_" + String(orbs[i].content.get("kind", "obake"))
					tally[ck] = tally.get(ck, 0) + 1
			for i in (mini(poi, 3) if goes else 0):
				for k in ["kira", "receipt", "bubble", "tray", "pan", "box", "plain"]:
					if gs.nets[k] > 0:
						gs.nets[k] -= 1
						break
			if gs.is_moon_night():
				var lit := 0
				for g in gs.moon_lanterns():
					if g:
						lit += 1
				gs.finish_moon(lit, 0)
			gs.end_night()
			var new_cat := false
			for h in gs.hatched:
				if h.is_new and not h.has("kind"):
					new_cat = true
			gap = 0 if new_cat else gap + 1
			if d >= 7: # 最初の 1 週は図鑑がうまっていく途中なので、救済の間隔はそのあとで見る
				max_gap = maxi(max_gap, gap)
			if d < 30:
				for h in gs.hatched:
					if h.has("kind"):
						tally[h.kind] += 1
					elif Rares.is_rare(h.id) or h.id == "lantern": # 暮らしから来る子（満月のちょうちんも）
						tally.cat_life_rare += 1
					else:
						tally.cat_orb += 1
			if not levels.has(gs.garden_level):
				levels[gs.garden_level] = d + 1
			if d % 7 == 6:
				line.append("w%d:L%d 図%d" % [d / 7 + 1, gs.garden_level, gs.seen.size()])
		var rares := 0
		for id in gs.seen:
			if Rares.is_rare(id):
				rares += 1
		print("%-12s %s | レア%d 通常%d | 段到達日 %s" % [strat, "  ".join(line), rares, gs.seen.size() - rares, levels])
		var scooped: int = tally.scooped_obake + tally.scooped_material + tally.scooped_cloth + tally.scooped_vehicle
		print("   30日ですくった玉 %d 個（中身 おばネコ %d・材料 %d・服 %d）→ かえった：おばネコ %d（玉とそのほか）・暮らしのレア %d | 島の材料 %d・服 %d・乗り物 %d | 新しい子が来ない夜の最長 %d" % [scooped, tally.scooped_obake, tally.scooped_material, tally.scooped_cloth, tally.cat_orb, tally.cat_life_rare, tally.material, tally.cloth, tally.vehicle, max_gap])
		# 眠りが無くても庭は育つ（毎晩すくえば 6 週で満開の手前まで、すくわない夜があっても半分より上）
		var want := 8 if strat.ends_with("daily") else 6
		if gs.garden_level < want:
			fails += 1
			print("FAIL: %s garden only L%d after 42 days (want %d)" % [strat, gs.garden_level, want])
		if rares < 3:
			fails += 1
			print("FAIL: %s only %d rares in 42 days" % [strat, rares])
		if scooped >= 40:
			var mat_share := float(tally.scooped_material + tally.scooped_vehicle) / scooped
			var cat_share := float(tally.scooped_obake) / scooped
			if mat_share < 0.55 or cat_share > 0.25:
				fails += 1
				print("FAIL: drop shares off (material %.2f cat %.2f)" % [mat_share, cat_share])
	print("SIM_B ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
