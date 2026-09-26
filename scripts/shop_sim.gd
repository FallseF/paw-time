class_name ShopSim
extends RefCounted
## 「店を回す」の計算（見た目なし）。困りごとが持ち場に出て、待てる時間が切れると店の余裕が減る。
## おばけを持ち場に置くと、そこの困りごとを片づける。つかれたら休憩室で休んで、同じ持ち場に戻る。
## 画面は events を読んで演出する。バランス検証（tests/sim_shift.gd）と宣伝の自動操作も同じものを使う。

const MAX_PER_STATION := 4
const OVERDUE_DRAIN := 1.2 # 待ちきれない困りごと1つで、1秒に減る余裕
const OVERFLOW_HIT := 8.0 # 持ち場からあふれたとき
const SOLVE_GAIN := 1.0
const SWEEP_EVERY := 12.0

var t := 0.0
var duration := 90.0
var yoyu := 100.0
var yoyu_max := 100.0
var result := ""
var stations: Array = []
var kinds: Array = []
var every_a := 6.0
var every_b := 4.0
var next_spawn := 2.0
var surges: Array = [] # [時刻, 数, 予告済み]
var troubles: Array = [] # {uid, kind, station, work, left, patience, max_patience}
var crew: Array = [] # {uid, id, lv, job, help, rate, multi, stamina, stamina_max, state, station, target, x, z, rest, sweep}
var events: Array = []
var hard := 1.0
var job_buff := {}
var stamina_mult := 1.0
var weekly := {}
var solved := 0
var overflowed := 0
var rush := false
var _uid := 0


## deck: [{id, lv}]、boost: GameState.battle_boost
func setup(si: int, st: int, deck: Array, boost: Dictionary, lap := 1) -> void:
	var s: Dictionary = ShopData.stage(si, st)
	stations = s.stations.duplicate()
	kinds = s.kinds.duplicate()
	every_a = s.every[0]
	every_b = s.every[1]
	duration = s.time
	rush = s.get("rush", false)
	for sg in s.surges:
		surges.append([float(sg[0]), int(sg[1]), false])
	hard = ShopData.HARD[si][st] * (1.0 + 0.8 * (lap - 1))
	yoyu_max = 100.0 + boost.get("start_bonus", 0.0)
	yoyu = yoyu_max
	stamina_mult = boost.get("regen", 1.0)
	if boost.get("job", "") != "":
		job_buff[boost.job] = boost.get("job_mult", 1.0)
	weekly = boost.get("weekly", {})
	if not weekly.is_empty():
		job_buff[weekly.job] = job_buff.get(weekly.job, 1.0) * weekly.job_mult
	for d in deck:
		_add_crew(d.id, d.lv)


func _add_crew(id: String, lv: int) -> void:
	_uid += 1
	var w: Dictionary = ShopData.worker(id)
	var job := ShopData.job_of(id)
	var m := DefData.unit_mult(lv)
	var sm := (1.0 + 0.08 * (lv - 1)) * stamina_mult
	var jm: float = job_buff.get(job, 1.0) if job != "" else 1.0
	crew.append({"uid": _uid, "id": id, "lv": lv, "job": job, "help": ShopData.help_of(id),
		"rate": w.rate * m * jm, "multi": w.multi, "stamina": w.stamina * sm, "stamina_max": w.stamina * sm,
		"state": "idle", "station": "", "x": ShopData.BREAK_POS.x + (crew.size() - 3) * 0.45, "z": ShopData.BREAK_POS.y + 0.3,
		"rest": 0.0, "sweep": SWEEP_EVERY * 0.5})


func station_pos(sid: String) -> Vector2:
	return ShopData.STATIONS[sid].pos


## i 番目のおばけを持ち場へ（"" で休憩室へ下げる）
func assign(i: int, sid: String) -> bool:
	if i < 0 or i >= crew.size() or result != "":
		return false
	var c: Dictionary = crew[i]
	if sid != "" and not sid in stations:
		return false
	c.station = sid
	if c.state == "rest":
		return true # 休み終わったら、そこへ行く
	c.state = "walk" if sid != "" else "walk_break"
	events.append({"type": "assign", "uid": c.uid, "station": sid})
	return true


func tick(dt: float) -> void:
	if result != "":
		return
	t += dt
	_spawn(dt)
	var time_mult := 1.0
	for c in crew:
		if c.help == "time" and c.state == "work":
			time_mult = 1.3
	# 困りごとの待ち時間
	for tr in troubles:
		var calm := false
		for c in crew:
			if c.help == "calm" and c.state == "work" and c.station == tr.station:
				calm = true
		if not calm:
			tr.patience -= dt / time_mult
		if tr.patience <= 0:
			if not tr.late:
				tr.late = true
				events.append({"type": "late", "uid": tr.uid})
			yoyu -= OVERDUE_DRAIN * dt
	for c in crew:
		_step_crew(c, dt)
	if yoyu <= 0:
		yoyu = 0
		result = "lose"
		events.append({"type": "lose"})
	elif t >= duration:
		result = "win"
		events.append({"type": "win"})


func progress() -> float:
	return clampf(t / duration, 0.0, 1.0)


func _spawn(dt: float) -> void:
	for sg in surges:
		if not sg[2] and t >= sg[0] - 3.0:
			sg[2] = true
			events.append({"type": "surge_warn", "n": sg[1]})
		if sg[2] and sg[1] > 0 and t >= sg[0]:
			for k in sg[1]:
				_new_trouble()
			sg[1] = 0
	if t >= next_spawn and t < duration - 3.0:
		_new_trouble()
		next_spawn = t + lerpf(every_a, every_b, progress())


func _new_trouble() -> void:
	var kind: String = kinds.pick_random()
	var d: Dictionary = ShopData.TROUBLES[kind]
	var sid: String = d.station
	if not sid in stations:
		sid = stations.pick_random()
	var here := 0
	for tr in troubles:
		if tr.station == sid:
			here += 1
	if here >= MAX_PER_STATION:
		# あふれた：いちばん古いものを押し出して、余裕がどっと減る
		yoyu -= OVERFLOW_HIT
		overflowed += 1
		events.append({"type": "overflow", "station": sid})
		return
	_uid += 1
	var wm := hard
	if not weekly.is_empty() and weekly.enemy == kind:
		wm *= weekly.enemy_mult
	var pat: float = d.patience / (1.0 + 0.25 * (hard - 1.0))
	var tr := {"uid": _uid, "kind": kind, "station": sid, "work": d.work * wm, "left": d.work * wm, "patience": pat, "max_patience": pat, "late": false}
	troubles.append(tr)
	events.append({"type": "trouble", "uid": tr.uid, "station": sid, "kind": kind})


func _step_crew(c: Dictionary, dt: float) -> void:
	match c.state:
		"idle":
			return
		"walk", "walk_break":
			var to: Vector2 = ShopData.BREAK_POS if c.state == "walk_break" else station_pos(c.station)
			var here := Vector2(c.x, c.z)
			var d := to - here
			var step: float = ShopData.WALK_SPEED * dt
			if d.length() <= step:
				c.x = to.x
				c.z = to.y
				if c.state == "walk_break":
					c.state = "rest" if c.stamina < c.stamina_max * 0.99 else "idle"
					c.rest = ShopData.REST_TIME
					if c.state == "idle":
						c.station = ""
				else:
					c.state = "work"
			else:
				var v := d.normalized() * step
				c.x += v.x
				c.z += v.y
		"rest":
			c.rest -= dt
			c.stamina = minf(c.stamina_max, c.stamina + c.stamina_max / ShopData.REST_TIME * dt)
			if c.rest <= 0:
				c.stamina = c.stamina_max
				events.append({"type": "rested", "uid": c.uid})
				c.state = "walk" if c.station != "" else "idle"
		"work":
			var mine: Array = []
			for tr in troubles:
				if tr.station == c.station:
					mine.append(tr)
			if mine.is_empty():
				return # 何もなければ、つかれない
			mine.sort_custom(func(a, b): return a.patience < b.patience)
			var rate: float = c.rate
			var sj: String = ShopData.STATIONS[c.station].job
			if c.help == "":
				if c.job != sj:
					rate *= ShopData.WRONG_STATION
			if c.help == "crowd":
				rate *= 3.0
			for o in crew:
				if o.uid != c.uid and o.help == "cheer" and o.state == "work" and o.station == c.station:
					rate *= 1.5
					break
			var n: int = mini(c.multi, mine.size())
			for k in n:
				var tr: Dictionary = mine[k]
				tr.left -= rate * dt
				if tr.left <= 0:
					_solve(tr, c)
			var tire := dt * (2.0 if c.help == "crowd" else 1.0)
			c.stamina -= tire
			if c.help == "sweep":
				c.sweep -= dt
				if c.sweep <= 0 and not troubles.is_empty():
					c.sweep = SWEEP_EVERY
					var worst: Dictionary = troubles[0]
					for tr2 in troubles:
						if tr2.patience < worst.patience:
							worst = tr2
					events.append({"type": "sweep", "uid": c.uid, "station": worst.station})
					_solve(worst, c)
			if c.stamina <= 0:
				c.stamina = 0
				c.state = "walk_break"
				events.append({"type": "tired", "uid": c.uid})


func _solve(tr: Dictionary, by: Dictionary) -> void:
	if not troubles.has(tr):
		return
	troubles.erase(tr)
	solved += 1
	var gain := SOLVE_GAIN * (3.0 if by.help == "tip" else 1.0)
	yoyu = minf(yoyu_max, yoyu + gain)
	events.append({"type": "solved", "uid": tr.uid, "station": tr.station, "kind": tr.kind, "by": by.uid, "late": tr.late})


func stars() -> int:
	if result != "win":
		return 0
	var r := yoyu / yoyu_max
	return 3 if r >= 0.7 else (2 if r >= 0.35 else 1)


func pop_events() -> Array:
	var ev := events
	events = []
	return ev


func count_at(sid: String) -> int:
	var n := 0
	for tr in troubles:
		if tr.station == sid:
			n += 1
	return n


# ---------- 自動操作（検証と宣伝用） ----------

var _ai_t := 0.0


func ai_step(dt: float, skill := 1.0) -> void:
	_ai_t -= dt
	if _ai_t > 0 or result != "":
		return
	_ai_t = lerpf(2.5, 0.6, skill)
	var need := {}
	var staff := {}
	for sid in stations:
		need[sid] = 0.0
		staff[sid] = 0
	for tr in troubles:
		need[tr.station] += 1.0 + 3.0 / maxf(0.5, tr.patience)
	for c in crew:
		if c.station != "" and staff.has(c.station):
			staff[c.station] += 1
	for i in crew.size():
		var c: Dictionary = crew[i]
		if c.state in ["rest", "walk_break", "walk"]:
			continue
		var own := ""
		for sid in stations:
			if ShopData.STATIONS[sid].job == c.job:
				own = sid
		var best := ""
		if c.state == "idle":
			# まず自分の仕事の持ち場。なければ、人の少ない忙しい持ち場
			if own != "" and staff[own] == 0:
				best = own
			else:
				var sc := -99.0
				for sid in stations:
					var v: float = need[sid] - staff[sid] * 1.5 + (1.0 if sid == own else 0.0)
					if v > sc:
						sc = v
						best = sid
		elif skill > 0.5 and count_at(c.station) == 0:
			# うまい人：暇になったら、いちばん忙しいところへ手伝いに
			var sc2 := 2.5
			for sid in stations:
				var v2: float = need[sid] - staff[sid] * 1.2
				if v2 > sc2:
					sc2 = v2
					best = sid
		if best != "" and best != c.station:
			if c.station != "":
				staff[c.station] -= 1
			staff[best] += 1
			assign(i, best)
			return
