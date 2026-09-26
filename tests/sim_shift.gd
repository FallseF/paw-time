extends SceneTree
## 「店を回す」を自動操作で回して、面ごとに要る Lv と星を出す。
## godot --headless --path . -s tests/sim_shift.gd   （SIM_ONLY="0-0,3-0" で絞れる）

func _run(si: int, st: int, ids: Array, lv: int, skill: float, n: int) -> Array:
	var w := 0
	var stars := 0
	var yoyu := 0.0
	for r in n:
		var sim := ShopSim.new()
		var deck := []
		for id in ids:
			deck.append({"id": id, "lv": lv})
		sim.setup(si, st, deck, {})
		while sim.result == "":
			sim.ai_step(0.1, skill)
			sim.tick(0.1)
			sim.pop_events()
		if sim.result == "win":
			w += 1
			stars += sim.stars()
			yoyu += sim.yoyu
	return [w, stars, yoyu / maxf(1, w)]


func _initialize() -> void:
	var only := OS.get_environment("SIM_ONLY")
	for sk in [0.3, 0.7]:
		var r := _run(0, 0, ["receipt", "tray"], 1, sk, 5)
		print("1-1 はじめて（レシートン+オボン Lv1）skill%.1f: %d/5勝 星%d 余裕%d" % [sk, r[0], r[1], int(r[2])])
	var full := ["receipt", "box", "tray", "bubble", "pan"]
	var rich := ["receipt", "box", "tray", "bubble", "pan", "nemurin", "kaminari"]
	for si in ShopData.STAGES.size():
		for st in ShopData.STAGES[si].size():
			if only != "" and not ("%d-%d" % [si, st]) in only.split(","):
				continue
			var ids: Array = full
			if si == 0 and st <= 1:
				ids = ["receipt", "tray"]
			elif si == 0 and st == 2:
				ids = ["receipt", "tray", "pan"]
			elif si == 0 and st == 3:
				ids = ["receipt", "tray", "pan", "bubble"]
			var line := "%d-%d:" % [si + 1, st + 1]
			for lv in [1, 3, 5, 7, 9]:
				var r := _run(si, st, ids, lv, 0.5, 4)
				line += "  Lv%d %d/4(★%d)" % [lv, r[0], r[1]]
			if si == 3:
				for lv in [5, 7, 9]:
					var r2 := _run(si, st, rich, lv, 0.5, 4)
					line += "  +レアLv%d %d/4" % [lv, r2[0]]
			print(line)
	quit()
