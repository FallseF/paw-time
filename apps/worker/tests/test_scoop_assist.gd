extends SceneTree
## おばけすくいの手助けの計算（ScoopAssist）：磁石・ばねの追いかけ・当たりの広さ・破れやすさ・タップの判定。
## OBAKE_NOSAVE=1 godot --headless --path . -s tests/test_scoop_assist.gd
var fails := 0


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _initialize() -> void:
	# 磁石：近い玉ほど強く寄る。遠い玉には寄らない。いちばん近い玉を選ぶ
	var orbs := [Vector2(1.0, 0.0), Vector2(-2.0, 0.0)]
	var far := ScoopAssist.magnet(Vector2(0.0, 0.0), orbs, 0.6, 0.5)
	_check(far == Vector2.ZERO, "no pull when no orb is within the radius (%s)" % far)
	var near := ScoopAssist.magnet(Vector2(0.7, 0.0), orbs, 0.6, 0.5)
	_check(near.x > 0.7 and near.x < 1.0, "pulls toward the nearest orb (%s)" % near)
	var nearer := ScoopAssist.magnet(Vector2(0.9, 0.0), orbs, 0.6, 0.5)
	_check(nearer.distance_to(orbs[0]) < 0.1 * 0.8, "pull grows closer to the orb (%s)" % nearer)
	_check(ScoopAssist.magnet(Vector2(0.9, 0.0), [], 0.6, 0.5) == Vector2(0.9, 0.0), "no orbs, no pull")

	# ばね：行きすぎず、なめらかに追いつく（60 fps で 0.3 秒）
	var p := Vector2.ZERO
	var v := Vector2.ZERO
	var target := Vector2(1.0, 0.5)
	var over := false
	var prev_d := INF
	var mono := true
	for i in 18:
		var r := ScoopAssist.follow(p, target, v, 0.06, 1.0 / 60.0)
		p = r[0]
		v = r[1]
		over = over or (p.x > target.x + 1e-4)
		var d := p.distance_to(target)
		mono = mono and d <= prev_d + 1e-6
		prev_d = d
	_check(not over, "the poi does not overshoot the finger")
	_check(mono, "distance to the finger only shrinks (no jitter)")
	_check(p.distance_to(target) < 0.02, "catches up within 0.3 s (%.3f)" % p.distance_to(target))
	# 1 コマ目で飛びつかない（なめらか）
	var r1 := ScoopAssist.follow(Vector2.ZERO, target, Vector2.ZERO, 0.06, 1.0 / 60.0)
	_check((r1[0] as Vector2).length() < target.length() * 0.5, "first frame moves only part way")

	# はじめのうちは破れにくく、当たりが広い。日がたつと、ふつうへ
	_check(ScoopAssist.wear_scale(0, 0) <= 0.35, "first scoops barely wear the net")
	_check(ScoopAssist.wear_scale(5, 1) <= 0.6, "the first nights are gentle")
	_check(is_equal_approx(ScoopAssist.wear_scale(40, 6), 1.0), "normal wear later")
	var ramp := true
	for d in range(1, 8):
		ramp = ramp and ScoopAssist.wear_scale(40, d + 1) >= ScoopAssist.wear_scale(40, d)
	_check(ramp, "difficulty eases in day by day")
	_check(ScoopAssist.hit_radius(0, 0) > ScoopAssist.hit_radius(40, 6), "wider hit ring for beginners")
	_check(ScoopAssist.hit_radius(40, 6) > ScoopAssist.POI_R, "hit ring is a bit wider than the rim")

	# タップ：短く、ほとんど動かさずに離した
	_check(ScoopAssist.is_tap(0.15, 4.0), "short, still press is a tap")
	_check(not ScoopAssist.is_tap(0.6, 4.0), "long press is not a tap")
	_check(not ScoopAssist.is_tap(0.15, 40.0), "a slide is not a tap")
	var scr := [Vector2(100, 400), Vector2(200, 380)]
	_check(ScoopAssist.tap_pick(Vector2(190, 390), scr) == 1, "tap picks the orb under the finger")
	_check(ScoopAssist.tap_pick(Vector2(300, 200), scr) == -1, "tap on open water picks nothing")

	# 新しい玉の浮かぶ所：ポイの陰（宙〜水面の輪）と指の下をよけ、空いた水面を選ぶ
	var poi_air := Vector2(180, 360)
	var poi_water := Vector2(180, 410)
	var avoid := [[poi_air, poi_water, 60.0], [poi_water, poi_water + Vector2(0, 110), 50.0]]
	_check(ScoopAssist.clearance(Vector2(180, 385), avoid) < 0.0, "a point under the lifted poi is inside the avoid zone")
	_check(ScoopAssist.clearance(Vector2(180, 500), avoid) < 0.0, "a point under the thumb is inside the avoid zone")
	_check(ScoopAssist.clearance(Vector2(60, 320), avoid) > 0.0, "open water is outside")
	_check(ScoopAssist.clearance(Vector2(60, 320), []) == INF, "nothing to avoid")
	var cands := [Vector2(185, 380), Vector2(175, 470), Vector2(300, 330), Vector2(60, 480)]
	_check(ScoopAssist.pick_spawn(cands, avoid) == 2, "picks the first candidate on free water (%d)" % ScoopAssist.pick_spawn(cands, avoid))
	_check(ScoopAssist.pick_spawn([Vector2(180, 380), Vector2(215, 400)], avoid) == 1, "if all are covered, picks the one closest to free water")
	_check(ScoopAssist.pick_spawn([], avoid) == -1, "no candidates")
	var others := [[Vector2(300, 330), Vector2(300, 330), 27.0]]
	_check(ScoopAssist.pick_spawn(cands, avoid, others) == 3, "prefers water away from other orbs too")
	_check(ScoopAssist.pick_spawn([Vector2(185, 380), Vector2(300, 330)], avoid, others) == 1, "the poi rule wins over orb spacing")
	# ばらばらな候補（画面いっぱい）から選ぶと、いつもポイの陰から離れる
	var worst := INF
	for n in 300:
		var cs: Array = []
		for i in 40:
			cs.append(Vector2(randf_range(30, 330), randf_range(300, 522)))
		var k := ScoopAssist.pick_spawn(cs, avoid)
		worst = minf(worst, ScoopAssist.clearance(cs[k], avoid))
	_check(worst >= 0.0, "spawns keep a minimum distance from the poi and thumb (worst %.1f px)" % worst)

	print("SCOOP ASSIST TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
