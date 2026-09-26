extends SceneTree
## バランス確認：戦略ごとに 42 日遊んで、庭の段・リズム・図鑑を出す。
## 玉の中身（Drops の割合）も 30 日ぶん数える：おばネコ（玉から・暮らしのレア・夢）、島の材料、服。
## godot --headless --path . -s tests/sim_b.gd
var fails := 0


func _initialize() -> void:
	var gs = root.get_node_or_null("GameState")
	if gs == null:
		gs = load("res://scripts/game_state.gd").new()
		gs.name = "GameState"
		root.add_child(gs)
	await process_frame
	for strat in ["solo_steady", "solo_chaos", "solo_owl", "data_record", "data_steady"]:
		seed(7)
		gs.reset("data" if strat.begins_with("data") else "solo")
		var line := []
		var levels := {}
		var tally := {"cat_orb": 0, "cat_life_rare": 0, "cat_dream": 0, "material": 0, "cloth": 0, "scooped_obake": 0, "scooped_material": 0, "scooped_cloth": 0}
		var gap := 0
		var max_gap := 0
		for d in 42:
			var s: Dictionary = gs.today()
			if s.role != "":
				gs.finish_shift()
			# すくい：ポイ 1 本で玉 0.9 個くらい、破れにくさで増える
			var poi := 0
			for k in gs.nets:
				poi += gs.nets[k]
			var orbs: Array = gs.tonight_orbs()
			var got := mini(orbs.size(), int(round(minf(poi, 3) * 0.8 * gs.poi_strength())))
			for i in got:
				gs.orbs.append(orbs[i])
				if d < 30:
					var ck := "scooped_" + String(orbs[i].content.get("kind", "obake"))
					tally[ck] = tally.get(ck, 0) + 1
			for i in mini(poi, 3):
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
			var bed := 330
			var wake: int = gs.wake_for_tomorrow()
			match strat:
				"solo_steady", "data_steady":
					bed = gs.plan_bed("usual")
				"solo_chaos":
					bed = [300, 390, 330, 450, 360, 420, 300][d % 7]
				"solo_owl":
					bed = gs.plan_bed("market") if d % 2 == 0 else gs.plan_bed("usual")
				"data_record":
					var r: Dictionary = gs.recorded_sleep()
					bed = r.bed
					wake = r.wake
			gs.sleep(bed, wake)
			if gs.dream_pending:
				gs.finish_dream(7)
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
					elif h.get("dream", false):
						tally.cat_dream += 1
					elif Rares.is_rare(h.id) or h.id == "lantern": # 暮らしから来る子（夜ふかしのランタンも）
						tally.cat_life_rare += 1
					else:
						tally.cat_orb += 1
			if not levels.has(gs.garden_level):
				levels[gs.garden_level] = d + 1
			if d % 7 == 6:
				line.append("w%d:L%d R%d 図%d" % [d / 7 + 1, gs.garden_level, int(gs.rhythm), gs.seen.size()])
		var rares := 0
		for id in gs.seen:
			if Rares.is_rare(id):
				rares += 1
		print("%-12s %s | レア%d 通常%d | 段到達日 %s" % [strat, "  ".join(line), rares, gs.seen.size() - rares, levels])
		var scooped: int = tally.scooped_obake + tally.scooped_material + tally.scooped_cloth
		print("   30日ですくった玉 %d 個（中身 おばネコ %d・材料 %d・服 %d）→ かえった：おばネコ %d（玉とそのほか）・暮らしのレア %d・夢のスヤリ %d | 島の材料 %d・服 %d | 新しい子が来ない夜の最長 %d" % [scooped, tally.scooped_obake, tally.scooped_material, tally.scooped_cloth, tally.cat_orb, tally.cat_life_rare, tally.cat_dream, tally.material, tally.cloth, max_gap])
		if scooped >= 40:
			var mat_share := float(tally.scooped_material) / scooped
			var cat_share := float(tally.scooped_obake) / scooped
			if mat_share < 0.55 or cat_share > 0.25:
				fails += 1
				print("FAIL: drop shares off (material %.2f cat %.2f)" % [mat_share, cat_share])
	print("SIM_B ", "OK" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
