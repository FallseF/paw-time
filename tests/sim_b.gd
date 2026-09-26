extends SceneTree
## バランス確認：戦略ごとに 42 日遊んで、庭の段・リズム・図鑑を出す。
## godot --headless --path . -s tests/sim_b.gd
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
			if not levels.has(gs.garden_level):
				levels[gs.garden_level] = d + 1
			if d % 7 == 6:
				line.append("w%d:L%d R%d 図%d" % [d / 7 + 1, gs.garden_level, int(gs.rhythm), gs.seen.size()])
		var rares := 0
		for id in gs.seen:
			if Rares.is_rare(id):
				rares += 1
		print("%-12s %s | レア%d 通常%d | 段到達日 %s" % [strat, "  ".join(line), rares, gs.seen.size() - rares, levels])
	quit()
