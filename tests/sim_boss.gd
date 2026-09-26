extends SceneTree
## 大ピークと1-1を「ふつうの手持ち」で試す。godot --headless --path . -s tests/sim_boss.gd
func _run(si: int, st: int, ids: Array, lv: int, skill: float, n: int) -> String:
	var w := 0
	var ts := 0.0
	var base := 0.0
	for r in n:
		var sim := DefSim.new()
		var deck := []
		for id in ids:
			deck.append({"id": id, "lv": lv})
		sim.setup(si, st, deck, {})
		while sim.result == "" and sim.t < 400.0:
			sim.ai_step(1.0 / 20.0, skill)
			sim.tick(1.0 / 20.0)
			sim.pop_events()
		if sim.result == "win":
			w += 1
			base += sim.base_hp / sim.base_max
		ts += sim.t
	return "win %d/%d avg %ds base %d%%" % [w, n, int(ts / n), int(100 * base / max(1, w))]


func _initialize() -> void:
	print("1-1 Lv1 レシートン+ダンボ skill0.3: ", _run(0, 0, ["receipt", "box"], 1, 0.3, 4))
	print("1-1 Lv1 レシートン+ダンボ skill0.8: ", _run(0, 0, ["receipt", "box"], 1, 0.8, 4))
	var roster := ["receipt", "box", "tray", "bubble", "pan", "nemurin", "amagasa"]
	for lv in [7, 8, 9, 10]:
		for sk in [0.3, 0.6, 1.0]:
			print("大ピーク Lv%d ふつう5+レア2 skill%.1f: " % [lv, sk], _run(3, 0, roster, lv, sk, 3))
	quit()
