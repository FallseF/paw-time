class_name FriendIslands
## コードで遊びに行った友だちの島（いかだの行き先えらびに並ぶ一覧）。新しい順・同じ島は 1 つ。
## 保存は user://friend_islands.json（ゲーム本体のセーブとは別。Shifts / Skills と同じ作法。OBAKE_NOSAVE ならメモリだけ）。
## GameState（autoload）には触れない（画面なしのテストから使えるように）。

const PATH := "user://friend_islands.json"
const MAX := 12

static var _loaded := false
static var _list: Array = [] # [{code, name, level, at}]


static func _nosave() -> bool:
	return OS.get_environment("OBAKE_NOSAVE") != ""


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_list = []
	if _nosave() or not FileAccess.file_exists(PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if d is Array:
		_list = d.filter(func(e): return e is Dictionary and String(e.get("code", "")) != "")


static func _save() -> void:
	if _nosave():
		return
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_list))


## 貼られたリンクやコードから、コードの部分だけ（前後の空白・#island= より前を落とす）
static func parse_code(text: String) -> String:
	var c := text.strip_edges()
	if c.contains("#island="):
		c = c.split("#island=")[1]
	return c.strip_edges()


## 友だちの島に着いたとき（おでかけ先 GameState.visit：{code, name, level, ...}）。お店の島は数えない
static func record(visit: Dictionary, now := -1.0) -> void:
	_ensure()
	var code := parse_code(String(visit.get("code", "")))
	if code == "" or visit.has("shop"):
		return
	_list = _list.filter(func(e): return e.code != code)
	var t := now if now >= 0 else Time.get_unix_time_from_system()
	_list.push_front({"code": code, "name": String(visit.get("name", "?")), "level": int(visit.get("level", 0)), "at": t})
	if _list.size() > MAX:
		_list.resize(MAX)
	_save()


static func all() -> Array:
	_ensure()
	return _list.duplicate(true)


static func reset() -> void:
	_loaded = true
	_list = []
	_save()
