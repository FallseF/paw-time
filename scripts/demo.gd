extends Node
## 自動で遊ぶ。
## OBAKE_AUTOPLAY=日数 OBAKE_SKILL=0〜1 OBAKE_WORK=0/1 OBAKE_SLEEP=7,8,6… で、本物のすくい画面を自動で回し、夜ごとの成績を出す（バランス確認）。
## godot --headless --path . --fixed-fps 60 で速く回せる。

var main


func run(m) -> void:
	main = m
	var days := int(OS.get_environment("OBAKE_AUTOPLAY"))
	if days > 0:
		await autoplay(days)
		get_tree().quit()


func autoplay(days: int) -> void:
	var skill := float(OS.get_environment("OBAKE_SKILL")) if OS.get_environment("OBAKE_SKILL") != "" else 0.8
	var work := OS.get_environment("OBAKE_WORK") != "0"
	var pattern: Array = []
	for x in (OS.get_environment("OBAKE_SLEEP") if OS.get_environment("OBAKE_SLEEP") != "" else "7").split(","):
		pattern.append(int(x))
	var total := 0
	for d in days:
		var s := GameState.today()
		if work and s.role != "":
			GameState.finish_shift()
		var mods := GameState.night_mods()
		var pois_before := GameState.total_pois()
		await main.go("catch", true)
		var scoop = main.current
		scoop.start_auto(skill)
		var frames := 0
		while not scoop.ended and frames < 60 * 240:
			await get_tree().process_frame
			frames += 1
		if not scoop.ended:
			print("  自動すくいが時間切れ: busy=%s pressed=%s in_hand=%s sel=%s state=%s supply=%d vis=%d pois=%s tele=%.1f" % [scoop.busy, scoop.pressed, scoop.in_hand, scoop.selected, scoop.auto_state, scoop.supply, scoop._visible_count(), str(GameState.pois), scoop.telegraph_left])
		var t: Dictionary = GameState.tonight
		total += t.get("count", 0)
		var h: int = pattern[d % pattern.size()]
		print("D%02d %s曜 %s %s%s | ポイ%2d 使%2d | すくい%2d コンボ%2d ていねい%2d 虹%d | %4.0f秒 | 寝%d" % [d + 1, s.day, s.weather, s.moon if s.moon != "" else "--", " 祭" if mods.festival else "", pois_before, pois_before - GameState.total_pois(), t.get("count", 0), t.get("best_combo", 0), t.get("clean", 0), t.get("rainbow", 0), frames / 60.0, h])
		var kinds := {}
		for o in GameState.orbs:
			kinds[o.kind] = kinds.get(o.kind, 0) + 1
		GameState.sleep(h)
		if OS.get_environment("OBAKE_VERBOSE") != "":
			var hs := {}
			for x in GameState.hatched:
				hs[x.id] = hs.get(x.id, 0) + 1
			print("      玉 ", kinds, " → ", hs)
		var lv := []
		for id in GameState.NORMAL_IDS:
			lv.append(GameState.level_of(id))
		var news := []
		for x in GameState.hatched:
			if x.is_new:
				news.append(GameState.info(x.id).name)
		if news.size() > 0:
			print("      NEW: ", ", ".join(news))
		for key in GameState.claimable():
			GameState.claim(key)
		for u in ["fuchi", "wa", "kami"]:
			if GameState.upgrade(u):
				print("      工房: %s Lv%d" % [u, GameState.upgrades[u]])
		if d % 7 == 6:
			print("   -- 週末: 図鑑 %d/%d  Lv %s  かけら %s  累計すくい %d" % [GameState.seen.size(), GameState.ALL.size(), str(lv), str(GameState.shards), total])
	print("== 終了: 図鑑 %d/%d 最高コンボ %d 累計 %d" % [GameState.seen.size(), GameState.ALL.size(), GameState.records.best_combo, total])
