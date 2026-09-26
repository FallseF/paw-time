extends SceneTree
## 日曜の夜に寝て週が変わっても、できていた「今週のおねがい」のごほうびが消えないこと。
## godot --headless --path . -s tests/test_week_rollover.gd
func _initialize() -> void:
	await process_frame
	var gs = root.get_node("GameState")
	gs.reset()
	gs.day = 6 # 日曜
	var qs: Array = gs.week_quests()
	# 3つとも、できた状態にする
	gs.records.rainbow += 5
	gs.records.clean += 99
	gs.records.nights += 9
	for t in gs.TYPE_LABEL:
		gs.records["t_" + t] = 99
	gs.week_best = {"combo": 30, "festival": 30}
	for r in ["nemurin", "yumemi", "asayake"]:
		gs.seen[r] = true
	var rainbow_before: int = gs.shards.rainbow
	gs.sleep(7)
	var all_claimed: bool = qs.all(func(q): return gs.claimed.has(q.key))
	var reported: bool = gs.morning_report.any(func(l): return String(l).begins_with("先週のおねがい"))
	var ok: bool = all_claimed and reported and gs.shards.rainbow > rainbow_before
	print("claimed=", all_claimed, " reported=", reported, " rainbow ", rainbow_before, "→", gs.shards.rainbow, " → ", "PASS" if ok else "FAIL")
	quit(0 if ok else 1)
