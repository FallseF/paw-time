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
	GameState.deck = ["receipt", "box", "tray", "bubble", "pan", "nemurin", "kaminari"]
	GameState.coins = 2480
	for si in 3:
		for st in DefData.shop(si).stages.size():
			GameState.cleared[DefData.stage_key(si, st)] = 1
	GameState.regen_bonus = 1.25
	GameState.total_battles = 12
	GameState.scooped_tonight = false


func _screen():
	return main.current


## 店を回す：少し進めた状態から、自動で回す
func _rush() -> void:
	var s = _screen()
	s.auto = true
	s.speed = 1


func _boss() -> void:
	var s = _screen()
	s.auto = true
	s.speed = 2


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
