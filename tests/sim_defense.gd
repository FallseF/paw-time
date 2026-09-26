extends SceneTree
## 全ステージを自動操作で戦わせて、勝率と時間を出す（バランス確認）。
## godot --headless --path . -s tests/sim_defense.gd
## 環境変数 SIM_RUNS（1条件あたりの回数）

func _initialize() -> void:
	var runs := int(OS.get_environment("SIM_RUNS")) if OS.get_environment("SIM_RUNS") != "" else 6
	# 章ごとに「そのころの手持ち」を想定する
	var decks := [
		[["receipt", "box"], [1, 2]],
		[["receipt", "box", "tray", "bubble", "pan"], [2, 3]],
		[["receipt", "box", "tray", "bubble", "pan"], [4, 5]],
		[["receipt", "box", "tray", "bubble", "pan", "kaminari", "nemurin"], [6, 7]],
	]
	for si in DefData.SHOPS.size():
		var shop: Dictionary = DefData.SHOPS[si]
		for st in shop.stages.size():
			var deck_ids: Array = decks[si][0]
			if si == 0 and st >= 1:
				deck_ids = ["receipt", "box", "tray", "bubble"] if st >= 2 else ["receipt", "box", "tray"]
			for lv in decks[si][1]:
				for skill in [0.4, 1.0]:
					var wins := 0
					var times := 0.0
					var hp_left := 0.0
					for r in runs:
						var sim := DefSim.new()
						var deck: Array = []
						for id in deck_ids:
							deck.append({"id": id, "lv": lv})
						sim.setup(si, st, deck, {})
						var dt := 1.0 / 30.0
						while sim.result == "" and sim.t < 400.0:
							sim.ai_step(dt, skill)
							sim.tick(dt)
							sim.pop_events()
						if sim.result == "win":
							wins += 1
							hp_left += sim.base_hp / sim.base_max
						times += sim.t
					print("%-8s %-14s Lv%d skill%.1f  win %d/%d  avg %.0fs  base %.0f%%" % [shop.id, shop.stages[st].name, lv, skill, wins, runs, times / runs, 100.0 * hp_left / max(1, wins)])
	quit()
