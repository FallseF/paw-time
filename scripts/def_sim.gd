class_name DefSim
extends RefCounted
## 大ピーク防衛の戦い（見た目なしの計算だけ）。画面は events を読んで演出する。
## ヘッドレスのバランス検証（tests/sim_defense.gd）と、宣伝用の自動操作でも同じものを使う。

const BASE_E_X := 0.6 # 困りごとの渦の前
const KB_TIME := 0.45
const KB_DIST := 1.4
const CANNON_TIME := 22.0
const CANNON_REACH := 11.0
const MAX_ENEMIES := 40
const WARN_TIME := 3.0 # 増援の予告
const WALLET_MAX_LV := 8

var L: float = DefData.LANE
var base_a_x: float = L - 0.6

var t := 0.0
var entities: Array = []
var events: Array = []
var _uid := 0

var energy := 0.0
var wallet_lv := 1
var regen_mult := 1.0
var cannon := 0.0
var base_hp := 2000.0
var base_max := 2000.0
var ebase_hp := 1000.0
var ebase_max := 1000.0
var result := ""
var slots: Array = [] # {id, lv, cost, cd, left}
var spawners: Array = []
var job_buff := {} # job → 倍率（シフトの応援）
var lap_mult := 1.0
var kills := 0
var deployed := 0
var boss_uid := -1
var weekly := {} # 今週のお題
var swarm_queue: Array = [] # [出る時刻, lv]


## deck: [{id, lv}], boost: {start_energy, regen, job, job_mult}
func setup(shop_i: int, stage_i: int, deck: Array, boost: Dictionary, lap := 1) -> void:
	var st: Dictionary = DefData.stage(shop_i, stage_i)
	lap_mult = DefData.lap_mult(lap) * DefData.HARD[shop_i][stage_i]
	ebase_max = st.base * lap_mult
	ebase_hp = ebase_max
	energy = 100.0 + boost.get("start_energy", 0.0)
	regen_mult = boost.get("regen", 1.0)
	if boost.get("job", "") != "":
		job_buff[boost.job] = boost.get("job_mult", 1.0)
	weekly = boost.get("weekly", {})
	if not weekly.is_empty():
		job_buff[weekly.job] = job_buff.get(weekly.job, 1.0) * weekly.job_mult
	for d in deck:
		var u: Dictionary = DefData.unit(d.id)
		if u.is_empty():
			continue
		slots.append({"id": d.id, "lv": d.lv, "cost": u.cost, "cd": u.cd, "left": 0.0})
	for s in st.spawn:
		spawners.append({"id": s[0], "start": float(s[1]), "every": float(s[2]), "count": int(s[3]), "trigger": float(s[4]), "mult": float(s[5]), "on": false, "next": 0.0, "done": 0})


func energy_max() -> float:
	return 300.0 + 150.0 * (wallet_lv - 1)


func energy_rate() -> float:
	var r := (14.0 + 4.0 * (wallet_lv - 1)) * regen_mult
	for e in entities:
		if e.side == 0 and e.ability == "sunrise":
			return r * 1.4
	return r


func wallet_cost() -> int:
	return 60 + 50 * (wallet_lv - 1)


func can_wallet() -> bool:
	return wallet_lv < WALLET_MAX_LV and energy >= wallet_cost()


func wallet_up() -> bool:
	if not can_wallet():
		return false
	energy -= wallet_cost()
	wallet_lv += 1
	events.append({"type": "wallet", "lv": wallet_lv})
	return true


func can_deploy(i: int) -> bool:
	if result != "" or i < 0 or i >= slots.size():
		return false
	var s: Dictionary = slots[i]
	return s.left <= 0.0 and energy >= s.cost


func deploy(i: int) -> bool:
	if not can_deploy(i):
		return false
	var s: Dictionary = slots[i]
	energy -= s.cost
	s.left = s.cd
	var e := _spawn_ally(s.id, s.lv)
	deployed += 1
	if e.ability == "swarm":
		for k in 100:
			swarm_queue.append([t + 0.15 + k * 0.035, s.lv])
	return true


func can_cannon() -> bool:
	return cannon >= 1.0 and result == ""


func cannon_targets() -> int:
	var n := 0
	for e in entities:
		if e.side == 1 and e.x >= L - CANNON_REACH:
			n += 1
	return n


func fire_cannon() -> bool:
	if not can_cannon() or cannon_targets() == 0:
		return false
	cannon = 0.0
	var hit := 0
	var stun := false
	for e in entities:
		if e.side == 1 and e.x >= L - CANNON_REACH:
			hit += 1
			_damage(e, 60.0 + e.max_hp * 0.06, null)
			if e.hp > 0 and not e.boss:
				_knock(e)
			elif e.hp > 0 and e.boss:
				# 大ピークは押し返せないが、チャイムで1.5秒ひるむ
				e.sleep = 1.5
				stun = true
	events.append({"type": "cannon", "hit": hit, "boss_stun": stun})
	return true


func _new_entity(side: int, id: String) -> Dictionary:
	_uid += 1
	return {"uid": _uid, "side": side, "id": id, "x": 0.0, "z": 0.0, "hp": 1.0, "max_hp": 1.0, "atk": 0.0, "rate": 1.0, "range": 1.0,
		"speed": 1.0, "kb": 1, "kb_done": 0, "cd": 0.3, "state": "walk", "st": 0.0, "area": false, "guard": 0.0, "ability": "",
		"job": "", "weak": "", "drop": 0, "tiny": false, "sleep": 0.0, "slow": 0.0, "hop_cd": 0.0, "boss": false, "split": "",
		"drain": 0, "attacking": false, "lv": 1}


func _spawn_ally(id: String, lv: int) -> Dictionary:
	var u: Dictionary = DefData.unit(id)
	var e := _new_entity(0, id)
	var m := DefData.unit_mult(lv) * (0.8 if not DefData.UNITS.has(id) else 1.0)
	var job: String = u.get("job", "")
	var jm: float = job_buff.get(job, 1.0) if job != "" else 1.0
	e.lv = lv
	e.x = L - 0.9
	e.z = randf_range(0.0, 0.5)
	e.max_hp = u.hp * m * jm
	e.hp = e.max_hp
	e.atk = u.atk * m * jm
	e.rate = u.rate
	e.range = u.range
	e.speed = u.speed
	e.kb = u.kb
	e.area = u.get("area", false)
	e.guard = u.get("guard", 0.0)
	e.ability = u.get("ability", "")
	e.job = job
	e.cd = u.rate * 0.4
	entities.append(e)
	events.append({"type": "spawn", "uid": e.uid})
	return e


func _spawn_tiny(lv: int) -> void:
	var e := _new_entity(0, "tiny")
	var m := DefData.level_mult(lv)
	e.tiny = true
	e.x = L - 0.9 - randf() * 0.4
	e.z = randf_range(-0.2, 0.8)
	e.max_hp = 10.0 * m
	e.hp = e.max_hp
	e.atk = 4.0 * m
	e.rate = 0.7
	e.range = 0.5
	e.speed = randf_range(1.8, 2.8)
	e.kb = 1
	e.cd = randf() * 0.5
	entities.append(e)
	events.append({"type": "spawn", "uid": e.uid})


func _spawn_enemy(id: String, mult: float) -> Dictionary:
	var d: Dictionary = DefData.ENEMIES[id]
	var e := _new_entity(1, id)
	var m := mult * lap_mult
	if not weekly.is_empty() and weekly.enemy == id:
		m *= weekly.enemy_mult
	e.x = BASE_E_X + randf() * 0.3
	e.z = randf_range(0.0, 0.5)
	e.max_hp = d.hp * m
	e.hp = e.max_hp
	e.atk = d.atk * (0.5 + 0.5 * m)
	e.rate = d.rate
	e.range = d.range
	e.speed = d.speed
	e.kb = d.kb
	e.area = d.get("area", false)
	e.weak = d.weak
	e.drop = d.drop
	e.boss = d.get("boss", false)
	e.split = d.get("split", "")
	e.drain = d.get("drain", 0)
	e.cd = d.rate * 0.5
	if e.boss:
		e.z = 0.25
		boss_uid = e.uid
	entities.append(e)
	events.append({"type": "spawn", "uid": e.uid, "boss": e.boss})
	return e


func enemy_count() -> int:
	var n := 0
	for e in entities:
		if e.side == 1:
			n += 1
	return n


func tick(dt: float) -> void:
	if result != "":
		return
	t += dt
	energy = minf(energy_max(), energy + energy_rate() * dt)
	cannon = minf(1.0, cannon + dt / CANNON_TIME)
	for s in slots:
		s.left = maxf(0.0, s.left - dt)
	while not swarm_queue.is_empty() and swarm_queue[0][0] <= t:
		_spawn_tiny(swarm_queue.pop_front()[1])
	_run_spawners()
	for e in entities.duplicate():
		if e.hp <= 0:
			continue
		_step(e, dt)
	# 倒れたものを片づける
	var alive: Array = []
	for e in entities:
		if e.hp > 0:
			alive.append(e)
	entities = alive
	if ebase_hp <= 0:
		ebase_hp = 0
		result = "win"
		events.append({"type": "win"})
	elif base_hp <= 0:
		base_hp = 0
		result = "lose"
		events.append({"type": "lose"})


func _run_spawners() -> void:
	var pct := ebase_hp / ebase_max * 100.0
	for s in spawners:
		if not s.on:
			if pct <= s.trigger:
				s.on = true
				s.next = t + (s.start if s.trigger >= 100.0 else WARN_TIME)
				if s.trigger < 100.0:
					events.append({"type": "surge_warn", "id": s.id, "boss": DefData.ENEMIES[s.id].get("boss", false)})
			else:
				continue
		if s.count > 0 and s.done >= s.count:
			continue
		if t >= s.next and enemy_count() < MAX_ENEMIES:
			_spawn_enemy(s.id, s.mult)
			s.done += 1
			s.next = t + s.every


## x 方向：味方は -1（左へ）、困りごとは +1（右へ）
func _dir(e: Dictionary) -> float:
	return -1.0 if e.side == 0 else 1.0


## 射程内の相手（近い順）。base_in は相手の拠点が射程内か
func _targets(e: Dictionary, reach: float) -> Array:
	var out: Array = []
	for o in entities:
		if o.side == e.side or o.hp <= 0:
			continue
		var d: float = (e.x - o.x) if e.side == 0 else (o.x - e.x)
		if d >= -0.4 and d <= reach:
			out.append(o)
	out.sort_custom(func(a, b): return absf(a.x - e.x) < absf(b.x - e.x))
	return out


func _base_in(e: Dictionary, reach: float) -> bool:
	if e.side == 0:
		return e.x - reach <= BASE_E_X
	return e.x + reach >= base_a_x


func _step(e: Dictionary, dt: float) -> void:
	e.cd = maxf(0.0, e.cd - dt)
	e.hop_cd = maxf(0.0, e.hop_cd - dt)
	e.slow = maxf(0.0, e.slow - dt)
	if e.sleep > 0:
		e.sleep -= dt
		return
	if e.state == "kb":
		e.st -= dt
		e.x -= _dir(e) * (KB_DIST / KB_TIME) * dt
		e.x = clampf(e.x, BASE_E_X - 0.2, L - 0.5)
		if e.st <= 0:
			e.state = "walk"
		return
	var targets := _targets(e, e.range)
	var base_hit := _base_in(e, e.range)
	if e.ability == "dream":
		# 治す係は、困りごとが近づいたら止まって、まわりを治す
		var near := _targets(e, 3.5)
		if near.is_empty() and not base_hit:
			_walk(e, dt)
		if e.cd <= 0 and (not near.is_empty() or base_hit):
			e.cd = e.rate
			_heal_around(e)
		return
	if targets.is_empty() and not base_hit:
		e.attacking = false
		_walk(e, dt)
		return
	e.attacking = true
	# 傘は、前の困りごとを飛びこえる
	if e.ability == "hop" and e.hop_cd <= 0 and not targets.is_empty():
		var over: Dictionary = targets[0]
		var to: float = over.x - 1.6
		e.x = maxf(BASE_E_X + 0.8, to)
		e.hop_cd = 7.0
		e.cd = 0.25
		events.append({"type": "hop", "uid": e.uid})
		return
	if e.cd > 0:
		return
	e.cd = e.rate
	_attack(e, targets, base_hit)


func _walk(e: Dictionary, dt: float) -> void:
	var sp: float = e.speed * (0.4 if e.slow > 0 else 1.0)
	e.x += _dir(e) * sp * dt
	e.x = clampf(e.x, BASE_E_X, base_a_x)


func _atk_of(e: Dictionary) -> float:
	var a: float = e.atk
	if e.side == 0:
		for o in entities:
			if o.side == 0 and o.ability == "lantern" and o.uid != e.uid and absf(o.x - e.x) <= 3.0:
				a *= 1.3
				break
	return a


func _attack(e: Dictionary, targets: Array, base_hit: bool) -> void:
	var hits: Array = []
	if e.area:
		hits = targets
	elif not targets.is_empty():
		hits = [targets[0]]
	var a := _atk_of(e)
	var times := 2 if e.ability == "double" else 1
	events.append({"type": "attack", "uid": e.uid, "bolt": e.ability == "bolt", "tx": (hits[0].x if not hits.is_empty() else (BASE_E_X if e.side == 0 else base_a_x))})
	for k in times:
		for o in hits:
			if o.hp <= 0:
				continue
			var dmg := a
			if e.side == 0 and e.job != "" and e.job == o.weak:
				dmg *= 1.5
			_damage(o, dmg, e)
			if o.hp > 0:
				match e.ability:
					"sleep":
						o.sleep = 0.5 if o.boss else 1.6
						events.append({"type": "sleep", "uid": o.uid})
					"slow":
						o.slow = 3.0
					"burst":
						if not o.boss:
							_knock(o)
		if hits.is_empty() or e.area:
			if base_hit:
				_hit_base(e, a)
	if e.side == 1 and e.drain > 0 and not hits.is_empty():
		# 品出しのおばけが受けとめると、棚が埋まって、やる気は減らない
		if hits[0].job == "stock":
			events.append({"type": "refill", "uid": hits[0].uid})
		else:
			energy = maxf(0.0, energy - e.drain)
			events.append({"type": "drain", "uid": e.uid})


func _hit_base(e: Dictionary, a: float) -> void:
	if e.side == 0:
		ebase_hp -= a
		events.append({"type": "ebase", "dmg": a})
	else:
		base_hp -= a
		events.append({"type": "base", "dmg": a})


func _damage(o: Dictionary, dmg: float, by) -> void:
	if o.side == 0:
		var red: float = o.guard
		for s in entities:
			if s.side == 0 and s.ability == "shield" and absf(s.x - o.x) <= 2.5:
				red = maxf(red, 0.2) + (0.1 if s.uid == o.uid else 0.0)
				break
		if by != null and o.job != "" and o.job == by.weak:
			red += 0.25
		dmg *= maxf(0.2, 1.0 - red)
	var before: float = o.hp
	o.hp -= dmg
	events.append({"type": "hit", "uid": o.uid, "dmg": dmg, "weak": by != null and by.side == 0 and by.job != "" and by.job == o.weak})
	if o.hp <= 0:
		_die(o, by)
		return
	# ノックバック：体力が区切りを下回るたびに押し戻される
	var n: int = o.kb
	var step: float = o.max_hp / n
	var crossed := int(floor((o.max_hp - o.hp) / step)) > int(floor((o.max_hp - before) / step))
	if crossed and o.kb_done < n - 1:
		o.kb_done += 1
		_knock(o)


func _knock(o: Dictionary) -> void:
	o.state = "kb"
	o.st = KB_TIME
	o.cd = maxf(o.cd, 0.3)
	events.append({"type": "kb", "uid": o.uid})


func _die(o: Dictionary, by) -> void:
	o.hp = 0
	events.append({"type": "die", "uid": o.uid, "side": o.side, "x": o.x, "boss": o.boss})
	if o.side == 1:
		kills += 1
		var gain: float = o.drop * (2.0 if by != null and by.ability == "gold" else 1.0)
		energy = minf(energy_max(), energy + gain)
		events.append({"type": "gain", "x": o.x, "amount": gain})
		if o.split != "":
			for k in 2:
				var s := _spawn_enemy(o.split, 1.2)
				s.x = o.x - 0.3 * k


func _heal_around(e: Dictionary) -> void:
	var amount := 30.0 * DefData.level_mult(e.lv)
	for o in entities:
		if o.side == 0 and o.hp > 0 and absf(o.x - e.x) <= e.range:
			o.hp = minf(o.max_hp, o.hp + amount)
	events.append({"type": "heal", "uid": e.uid})


func pop_events() -> Array:
	var ev := events
	events = []
	return ev


func find(uid: int) -> Dictionary:
	for e in entities:
		if e.uid == uid:
			return e
	return {}


## 前線（いちばん進んでいる味方と困りごとの間）。カメラが追う
func front_x() -> float:
	var ally := L
	var enemy := 0.0
	for e in entities:
		if e.tiny:
			continue
		if e.side == 0:
			ally = minf(ally, e.x)
		else:
			enemy = maxf(enemy, e.x)
	if enemy <= 0.0:
		return ally
	return (ally + enemy) * 0.5 if ally < L else enemy


# ---------- 自動操作（検証と宣伝用） ----------

var _ai_t := 0.0


func ai_step(dt: float, skill := 1.0) -> void:
	_ai_t -= dt
	if _ai_t > 0 or result != "":
		return
	_ai_t = lerpf(1.2, 0.35, skill)
	var threat := 0
	var boss_near := false
	for e in entities:
		if e.side == 1 and e.x >= L - CANNON_REACH:
			threat += 1
			if e.boss:
				boss_near = true
	if can_cannon() and cannon_targets() > 0 and (threat >= 4 or boss_near):
		fire_cannon()
		return
	# 最初はやる気Lvを上げる（うまい人ほど早く）
	if wallet_lv < 3 + int(skill * 2) and can_wallet() and (energy >= energy_max() * 0.8 or t < 6.0):
		wallet_up()
		return
	# 壁が前に足りなければ安いものを。そうでなければ、いちばん高いものを狙って貯める
	var walls := 0
	for e in entities:
		if e.side == 0 and not e.tiny and e.max_hp >= 300 * 1.0 and e.x < L - 1.5:
			walls += 1
	var cheapest := -1
	var priciest := -1
	for i in slots.size():
		if slots[i].left > 0:
			continue
		if cheapest < 0 or slots[i].cost < slots[cheapest].cost:
			cheapest = i
		if slots[i].cost <= energy_max() and (priciest < 0 or slots[i].cost > slots[priciest].cost):
			priciest = i
	if threat > 0 and walls < 2 and cheapest >= 0 and can_deploy(cheapest):
		deploy(cheapest)
		return
	if priciest >= 0 and can_deploy(priciest):
		deploy(priciest)
		return
	# 高いものが遠いときは、手ごろなものを混ぜる
	if priciest >= 0 and energy < slots[priciest].cost * 0.5:
		var cands: Array = []
		for i in slots.size():
			if can_deploy(i):
				cands.append(i)
		if not cands.is_empty() and randf() < 0.5:
			deploy(cands.pick_random())
			return
	if can_wallet() and energy >= energy_max() * 0.95:
		wallet_up()
