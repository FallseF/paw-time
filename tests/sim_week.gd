extends SceneTree
## 仕事と睡眠の組み合わせで、4週間の図鑑とレベルの伸びを比べる（すくいは簡易モデル）。
## 本物のすくい画面で回すなら：OBAKE_AUTOPLAY=28 godot --headless --path . --fixed-fps 60
## godot --headless --path . -s tests/sim_week.gd
func _initialize() -> void:
	var gs = root.get_node_or_null("GameState")
	await process_frame
	for pattern in [[7], [8, 7, 7, 6, 8, 9, 7], [5], [6, 5, 7, 4, 6, 5, 6]]:
		gs.reset()
		gs.fast_forward(28, pattern)
		var lv := []
		for id in gs.NORMAL_IDS:
			lv.append(gs.level_of(id))
		print("睡眠 %s → 図鑑 %d/%d  Lv %s  すくい累計 %d" % [str(pattern), gs.seen.size(), gs.ALL.size(), str(lv), gs.records.total])
	quit()
