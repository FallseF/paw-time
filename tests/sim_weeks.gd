extends SceneTree
## 何週間か「そのまま遊ぶ人」を自動で通して、進み方を比べる。
## godot --headless --path . -s tests/sim_weeks.gd
## 比べる3人：記録なし（シフトを受け取らず6時間睡眠）／ふつう（シフト＋7時間）／よく寝る（シフト＋8時間）

func _initialize() -> void:
	OS.set_environment("OBAKE_DEMO", "1") # セーブを書かない
	for plan in [["記録なし", false, 6], ["シフト+7h", true, 7], ["シフト+8h", true, 8]]:
		var wins := []
		for seed in 3:
			seed(seed * 101 + 7)
			wins.append(await _run(plan))
		print("%s" % plan[0])
		for w in wins:
			print("   ", w)
	quit()


func _run(plan: Array) -> String:
	var gs = load("res://scripts/game_state.gd").new()
	gs.name = "GameState"
	root.add_child(gs)
	await process_frame
	gs.reset()
	var cleared_day := {}
	for d in 28:
		var s: Dictionary = gs.today()
		if plan[1] and s.role != "":
			gs.finish_shift()
		# 1日に最大6回戦う（新しいステージ優先、負けたら強化して再挑戦）
		for attempt in 6:
			var nx: Array = gs.next_stage()
			var si: int = nx[0]
			var st: int = nx[1]
			if gs.is_cleared(si, st):
				break
			var sim := ShopSim.new()
			sim.setup(si, st, gs.deck_for_battle(), gs.battle_boost(DefData.shop(si).id), gs.lap)
			while sim.result == "":
				sim.ai_step(0.1, 0.5)
				sim.tick(0.1)
				sim.pop_events()
			var r: Dictionary = gs.record_battle(si, st, sim.result == "win", {"time": sim.t, "kills": sim.solved, "stars": sim.stars()})
			if r.won:
				cleared_day["%s%d-%d" % ["" if gs.lap == 1 else "L%d:" % gs.lap, si + 1, st + 1]] = d + 1
			if gs.best_lap > gs.lap:
				gs.lap = gs.best_lap
			# 強化：安いものから
			var done := false
			while not done:
				done = true
				var best := ""
				var bc := 999999
				for id in gs.deck:
					var c: int = gs.upgrade_cost(id)
					if c >= 0 and c < bc:
						bc = c
						best = id
				if best != "" and gs.coins >= bc:
					gs.upgrade(best)
					done = false
		# すくい：今夜の玉の半分くらい
		var tonight: Array = gs.tonight_orbs()
		var poi := 0
		for k in gs.nets:
			poi += gs.nets[k]
		for o in tonight:
			if poi <= 0:
				break
			if randf() < 0.6:
				gs.orbs.append({"type": o.type, "rare": o.rare})
			poi -= 1
			for k in gs.nets:
				if gs.nets[k] > 0:
					gs.nets[k] -= 1
					break
		gs.sleep(plan[2], "")
	var lv := 0
	for o in gs.owned:
		if not Rares.is_rare(o.id):
			lv += o.level
	var rares := 0
	for o in gs.owned:
		if Rares.is_rare(o.id):
			rares += 1
	var keys := ["1-4", "2-4", "3-4", "4-1", "L2:2-4", "L2:4-1", "L3:4-1"]
	var parts := []
	for k in keys:
		parts.append("%s:%s日目" % [k, str(cleared_day.get(k, "-"))])
	var out := "  ".join(parts) + "  ふつうLv合計%d  レア%d体  まかない%d" % [lv, rares, gs.coins]
	gs.queue_free()
	return out
