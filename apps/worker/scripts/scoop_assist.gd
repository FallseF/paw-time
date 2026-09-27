class_name ScoopAssist
## おばけすくいの「手助け」の計算（画面 screen_scoop.gd から使う。tests/test_scoop_assist.gd で確かめる）。
##   - ポイは指（マウス）の位置へ、なめらかに追いかける（ばねのように。行きすぎず、ぶるぶるしない）
##   - 水の中では、いちばん近い玉へ、そっと寄せる（磁石）
##   - はじめのうちは、当たりの輪が広く、破れにくい。日がたつと、ふつうの手ごたえへ
##   - さっと押して離した（タップ）なら、ポイが玉まですべって、すくう

## ポイの縁の半径（screen_scoop.gd の POI_R と同じ）
const POI_R := 0.3
## タップとみなす：押して離すまでの時間（秒）と、動いた距離（画面の 360 基準の px）
const TAP_SEC := 0.28
const TAP_SLOP := 14.0
## タップした点から、これだけ近い玉へすべっていく（画面の px）
const TAP_PICK_PX := 84.0


## はじめのうちか（すくった数が少ない・はじめの 2 晩）
static func beginner(total_scooped: int, day: int) -> bool:
	return total_scooped < 8 or day < 2


## 破れやすさの倍率（1 = ふつう）。はじめの数回はとても破れにくく、日がたつにつれて、ふつうへ
static func wear_scale(total_scooped: int, day: int) -> float:
	var s := clampf(0.55 + 0.15 * (day - 1), 0.55, 1.0)
	if total_scooped < 3:
		s = minf(s, 0.35)
	elif total_scooped < 8:
		s = minf(s, 0.6)
	return s


## 離したときに、すくえる輪の半径（見えない当たり。ポイの縁より少し広い）
static func hit_radius(total_scooped: int, day: int) -> float:
	return POI_R * (1.5 if beginner(total_scooped, day) else 1.3)


## 磁石の強さ（0〜1。寄せる割合のいちばん強いところ）と、効く広さ
static func magnet_strength(total_scooped: int, day: int) -> float:
	return 0.6 if beginner(total_scooped, day) else 0.4


const MAGNET_R := 0.6


## 磁石：狙っている点 aim の近く（radius の中）に玉があれば、いちばん近い玉のほうへ寄せた点を返す。
## 近いほど強く寄る（ふちでは 0、玉の真上で strength）。玉が無ければ aim のまま
static func magnet(aim: Vector2, orbs: Array, radius := MAGNET_R, strength := 0.5) -> Vector2:
	var best := Vector2.ZERO
	var bd := INF
	for o in orbs:
		var p: Vector2 = o
		var d := aim.distance_to(p)
		if d < bd:
			bd = d
			best = p
	if bd >= radius:
		return aim
	var k := strength * (1.0 - bd / radius)
	return aim.lerp(best, k)


## ばね（行きすぎない、なめらかな追いかけ）。smooth は、だいたい追いつくまでの時間（秒）。
## 返り値は [新しい位置, 新しい速さ]
static func follow(cur: Vector2, target: Vector2, vel: Vector2, smooth: float, dt: float) -> Array:
	var omega := 2.0 / maxf(smooth, 0.0001)
	var x := omega * dt
	var e := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := cur - target
	var temp := (vel + omega * change) * dt
	var v := (vel - omega * temp) * e
	var out := target + (change + temp) * e
	# 行きすぎたら、目標で止める
	if (target - cur).dot(out - target) > 0.0:
		out = target
		v = Vector2.ZERO
	return [out, v]


## 押して離したのが、タップだったか
static func is_tap(held_sec: float, moved_px: float) -> bool:
	return held_sec <= TAP_SEC and moved_px <= TAP_SLOP


## タップした画面の点に近い玉の番号（screen は玉の画面の位置の並び）。無ければ -1
static func tap_pick(at: Vector2, screen: Array, pick_px := TAP_PICK_PX) -> int:
	var best := -1
	var bd := pick_px
	for i in screen.size():
		var d := at.distance_to(screen[i])
		if d < bd:
			bd = d
			best = i
	return best


## 新しい玉の浮かぶ所：ポイの陰・指の下・手の見本の下をよける（画面の px）。
## よける所は、カプセル [a: Vector2, b: Vector2, r: float]（線分 a〜b から r の内側）の並び
## 点から、よける所のふちまでの、いちばん近い距離（px。負なら、どれかの内側。よける所が無ければ INF）
static func clearance(p: Vector2, avoid: Array) -> float:
	var best := INF
	for c in avoid:
		var q := Geometry2D.get_closest_point_to_segment(p, c[0], c[1])
		best = minf(best, p.distance_to(q) - float(c[2]))
	return best


## 候補（画面の点の並び。ばらばらな順）から、浮かべる所の番号を選ぶ。avoid は必ずよける所（ポイの陰・指・手の見本）、
## soft はできればよける所（ほかの玉）。両方から離れた候補があれば、はじめのそれ（いつもの気まぐれさのまま）。
## 無ければ、avoid から離れたはじめの候補。それも無ければ、avoid からいちばん離れた候補。候補が無ければ -1
static func pick_spawn(cands: Array, avoid: Array, soft: Array = []) -> int:
	var free := -1
	var best := -1
	var bd := -INF
	for i in cands.size():
		var c := clearance(cands[i], avoid)
		if c >= 0.0:
			if clearance(cands[i], soft) >= 0.0:
				return i
			if free < 0:
				free = i
		if c > bd:
			bd = c
			best = i
	return free if free >= 0 else best
