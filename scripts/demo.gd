extends Node
## 宣伝動画用の自動操作。OBAKE_DEMO=<場面> で起動すると、その場面を自動で見せる。
## 場面：rush（百鬼と雷の大乱戦）/ boss（大ピーク来店→守りきる）/ scoop / hatch / room / crew / map
## 録画は tools/make_promo.sh がまとめて行う。

var main
var scene := ""


func _ready() -> void:
	scene = OS.get_environment("OBAKE_DEMO")
	_setup_rich()
	match scene:
		"rush":
			GameState.pending_battle = {"shop": 2, "stage": 3}
			await main.go("defense", true)
			_rush()
		"boss":
			GameState.pending_battle = {"shop": 3, "stage": 0}
			await main.go("defense", true)
			_boss()
		"scoop":
			GameState.nets["pan"] = 3
			await main.go("catch", true)
			_scoop()
		"hatch":
			GameState.orbs = [{"type": "kitchen", "rare": false}]
			GameState.sleep(8, "")
			GameState.hatched.push_front({"id": "hyakki", "is_new": true, "level": 1, "rare": true})
			await main.go("hatch", true)
			_hatch()
		"crew":
			await main.go("crew", true)
			_crew()
		"map":
			await main.go("map", true)
			await get_tree().create_timer(1.2).timeout
			main.current.demo_open_next()
		_:
			GameState.boost = {"store": "カフェ こもれび", "role": "register", "hours": 4}
			GameState.shift_done_today = true
			await main.go("room", true)


func _setup_rich() -> void:
	for id in ["tray", "bubble", "pan", "hyakki", "kaminari", "amagasa", "nemurin", "yomise", "kirari", "asayake", "yumemi"]:
		GameState.add_obake(id)
	for o in GameState.owned:
		o.level = 9
	GameState.deck = ["receipt", "box", "tray", "bubble", "pan", "kaminari", "hyakki"]
	GameState.coins = 2480
	for si in 3:
		for st in DefData.shop(si).stages.size():
			GameState.cleared[DefData.stage_key(si, st)] = 1
	GameState.regen_bonus = 1.25
	GameState.total_battles = 12
	GameState.scooped_tonight = false


func _process(_d: float) -> void:
	if OS.get_environment("OBAKE_FPS") != "" and Engine.get_process_frames() % 60 == 0:
		print("[FPS] %d  entities=%d" % [Engine.get_frames_per_second(), main.current.sim.entities.size() if main.current and "sim" in main.current else 0])


func _screen():
	return main.current


## 大乱戦：少し進めた状態から、百鬼があふれ、雷が落ち、チャイムが鳴る
func _rush() -> void:
	var s = _screen()
	var sim: DefSim = s.sim
	s.auto = false
	sim.energy = 1500
	sim.wallet_lv = 6
	sim.cannon = 0.6
	# 前もって少し戦わせておく
	for i in 30 * 14:
		sim.ai_step(1.0 / 30.0, 1.0)
		sim.tick(1.0 / 30.0)
	sim.pop_events()
	s.cam_x = 9.0
	s.cam_hold = 1.0
	s.auto = true
	await get_tree().create_timer(1.0).timeout
	sim.energy = sim.energy_max()
	var hy := _slot(sim, "hyakki")
	sim.slots[hy].left = 0
	s._deploy(hy)
	s.cam_x = DefData.LANE - 3.0
	s.cam_hold = 2.2
	await get_tree().create_timer(2.6).timeout
	var kz := _slot(sim, "kaminari")
	sim.slots[kz].left = 0
	sim.energy = sim.energy_max()
	s._deploy(kz)
	await get_tree().create_timer(2.0).timeout
	sim.cannon = 1.0
	s._cannon()


func _boss() -> void:
	var s = _screen()
	var sim: DefSim = s.sim
	s.auto = true
	s.speed = 1
	sim.wallet_lv = 7
	for i in 30 * 30:
		sim.ai_step(1.0 / 30.0, 1.0)
		sim.tick(1.0 / 30.0)
	sim.pop_events()
	sim.ebase_hp = sim.ebase_max * 0.86
	await get_tree().create_timer(0.8).timeout
	sim.ebase_hp = sim.ebase_max * 0.84 # ここで大ピークが来る
	await get_tree().create_timer(3.0).timeout
	# 大ピークが「！」でためた瞬間にチャイム
	for k in 40:
		var b := sim.find(sim.boss_uid)
		if not b.is_empty() and b.winding and b.x >= DefData.LANE - DefSim.CANNON_REACH:
			break
		await get_tree().create_timer(0.1).timeout
	sim.cannon = 1.0
	s._cannon()
	await get_tree().create_timer(1.5).timeout
	# 大ピークを弱らせて、見せ場を早める
	for e in sim.entities:
		if e.boss:
			e.hp = minf(e.hp, 500)
	sim.energy = sim.energy_max()
	var kz := _slot(sim, "kaminari")
	sim.slots[kz].left = 0
	s._deploy(kz)
	await get_tree().create_timer(3.0).timeout
	sim.ebase_hp = minf(sim.ebase_hp, 300)
	while sim.result == "":
		await get_tree().create_timer(0.2).timeout
		sim.ebase_hp -= 60


func _slot(sim: DefSim, id: String) -> int:
	for i in sim.slots.size():
		if sim.slots[i].id == id:
			return i
	return 0


func _scoop() -> void:
	await get_tree().create_timer(1.2).timeout
	_screen().demo_hold()
	await get_tree().create_timer(0.9).timeout
	_screen().demo_lift()


func _hatch() -> void:
	await get_tree().create_timer(0.8).timeout
	_screen()._next()


func _crew() -> void:
	await get_tree().create_timer(1.5).timeout
	var s = _screen()
	var tw: Tween = s.create_tween()
	tw.tween_property(s.scroll, "scroll_vertical", 900, 4.0).set_trans(Tween.TRANS_SINE)
