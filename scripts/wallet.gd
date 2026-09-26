class_name Wallet
## 肉球コイン（Paw Coins）の財布。島づくり・キセカエに使う共通の通貨。
## ふやし方: おばネコが一緒に働く（work_together）、すくい、めあて など。
## 使い道: 島の置き物（island_kit）、服（wardrobe）。
## 保存は user://wallet.json（ほかのセーブと独立）。

const PATH := "user://wallet.json"

static var _loaded := false
static var _coins := 0
static var _log: Array = [] # 直近の出入り {t, n, why}


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if OS.get_environment("OBAKE_NOSAVE") != "" or not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		_coins = int(d.get("coins", 0))
		_log = d.get("log", [])


static func _save() -> void:
	if OS.get_environment("OBAKE_NOSAVE") != "":
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"coins": _coins, "log": _log.slice(-30)}))


static func balance() -> int:
	_ensure()
	return _coins


static func add(n: int, why := "") -> void:
	_ensure()
	if n <= 0:
		return
	_coins += n
	_log.append({"t": Time.get_unix_time_from_system(), "n": n, "why": why})
	_save()


## 足りなければ false を返し、何も減らさない
static func spend(n: int, why := "") -> bool:
	_ensure()
	if n < 0 or _coins < n:
		return false
	_coins -= n
	_log.append({"t": Time.get_unix_time_from_system(), "n": -n, "why": why})
	_save()
	return true


## テストや「はじめから」用
static func reset(to := 0) -> void:
	_loaded = true
	_coins = to
	_log = []
	_save()
