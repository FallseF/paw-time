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

	print("SCOOP ASSIST TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
