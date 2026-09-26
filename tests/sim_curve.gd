extends SceneTree
## ステージごとに「ふつうのおばけだけで、何Lvあれば勝てるか」を探す（自動操作 skill 0.6、3回中2勝）。
## godot --headless --path . -s tests/sim_curve.gd

func _initialize() -> void:
	var line := []
	for si in DefData.SHOPS.size():
		for st in DefData.shop(si).stages.size():
			var ids := ["receipt", "box", "tray", "bubble", "pan"]
			if si == 0 and st == 0:
				ids = ["receipt", "box"]
			elif si == 0 and st == 1:
				ids = ["receipt", "box", "tray"]
			var need := -1
			var tsum := 0.0
			for lv in range(1, 21):
				var w := 0
				for r in 3:
					var sim := DefSim.new()
					var deck := []
					for id in ids:
						deck.append({"id": id, "lv": lv})
					sim.setup(si, st, deck, {})
					while sim.result == "" and sim.t < 300.0:
						sim.ai_step(1.0 / 20.0, 0.6)
						sim.tick(1.0 / 20.0)
						sim.pop_events()
					if sim.result == "win":
						w += 1
						tsum = sim.t
					if w >= 2 or (r - w) >= 2:
						break
				if w >= 2:
					need = lv
					break
			line.append("%d-%d:Lv%d(%ds)" % [si + 1, st + 1, need, int(tsum)])
			print(line[-1])
	quit()
