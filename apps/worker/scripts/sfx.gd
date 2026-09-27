class_name Sfx
## 効果音の係。効果音はぜんぶ「SFX」のバスに流し、マイページのつまみ（効果音）でまとめて大きさを変える。
##   - Kit.play が鳴らす音も、画面が自分で作る AudioStreamPlayer（孵化・クイズ・すくう・夜の庭の環境音）も SFX へ。
##     後者は木に入ったときに振り分ける（install）。BGM（Music の子）は振り分けない
##   - 同じ音が MIN_GAP 秒より短い間隔で続くときは鳴らさない（連打・ドラッグ中に鳴りっぱなしにしない）
##   - 大きさは settings.cfg の [audio] sfx（0..1）。つまみは耳の感じに合わせて 2 乗
## 音の種類（assets/sfx。tools/gen_sfx.py で作る。やわらかい木琴・カリンバ・泡の音でそろえてある）
##   tap 選ぶ / confirm 決める（Kit.button） / back もどる・やめる・とじる / toggle 切りかえ / tab タブ・日付
##   open カードを開く / close カードを閉じる / error まちがい / coin ごほうび / toast 小さな知らせ
##   pop・chime・bell・sparkle・splash・hatch・lift・tear・grow・night・dream 見せ場 / night_amb・river_loop 環境音のループ

const BUS := &"SFX"
const MIN_GAP := 0.06
const SETTINGS := "user://settings.cfg"
## Kit.button の文字がこれなら「もどる」の音
const BACK_KEYS := ["KIT_UI_CLOSE", "QUIZ_UI_CLOSE", "WORK_MENU_CLOSE", "SHOP_CLOSE", "CHAT_CLOSE", "SETTINGS_CANCEL", "SHIFT_FORM_CANCEL", "QUIZ_UI_BACK", "END_BACK", "JOB_BACK_LIST"]

static var volume := 0.8 # 0..1（マイページのつまみ）
static var _prefs_loaded := false
static var _last := {} # 音の名前 → 最後に鳴らした時刻（ミリ秒）
static var _installed: SceneTree


## SFX のバスを用意して、その名前を返す（無ければ作る。Master へ流す）
static func bus() -> StringName:
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, BUS)
		AudioServer.set_bus_send(i, &"Master")
		load_prefs()
		_apply()
	return BUS


## 画面が自分で作る AudioStreamPlayer も SFX へ流す（main.gd と Kit.play から呼ぶ。何度呼んでもよい）
static func install(tree: SceneTree) -> void:
	bus()
	if tree == null or _installed == tree:
		return
	_installed = tree
	tree.node_added.connect(_route)


static func _route(n: Node) -> void:
	if n is AudioStreamPlayer and n.bus == &"Master" and not (n.get_parent() is Music):
		n.bus = BUS


## 同じ音が続けて鳴りすぎないか（鳴らしてよければ時刻を覚えて true）
static func allow(name: String) -> bool:
	var now := Time.get_ticks_msec()
	if now - int(_last.get(name, -100000)) < int(MIN_GAP * 1000.0):
		return false
	_last[name] = now
	return true


## ほかの効果音が secs 秒以内に鳴ったか（小さな知らせの音を、ほかの音と重ねないため）
static func recently(secs: float) -> bool:
	var now := Time.get_ticks_msec()
	for k in _last:
		if now - int(_last[k]) < int(secs * 1000.0):
			return true
	return false


## Kit.button の文字から音を選ぶ（とじる・やめる・もどる → back、ほかは confirm）
static func for_label(t: String) -> String:
	for k in BACK_KEYS:
		if t == TranslationServer.translate(k):
			return "back"
	return "confirm"


# ---------------------------------------------------------------- 大きさ（マイページ）

static func load_prefs() -> void:
	if _prefs_loaded:
		return
	_prefs_loaded = true
	var c := ConfigFile.new()
	if OS.get_environment("OBAKE_NOSAVE") == "" and c.load(SETTINGS) == OK:
		volume = clampf(float(c.get_value("audio", "sfx", volume)), 0.0, 1.0)


static func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	bus()
	_apply()
	if OS.get_environment("OBAKE_NOSAVE") != "":
		return
	var c := ConfigFile.new()
	c.load(SETTINGS)
	c.set_value("audio", "sfx", volume)
	c.save(SETTINGS)


static func bus_db() -> float:
	var i := AudioServer.get_bus_index(BUS)
	return AudioServer.get_bus_volume_db(i) if i >= 0 else 0.0


static func _apply() -> void:
	var i := AudioServer.get_bus_index(BUS)
	if i < 0:
		return
	var a := volume * volume
	AudioServer.set_bus_mute(i, a <= 0.0001)
	AudioServer.set_bus_volume_db(i, linear_to_db(a) if a > 0.0001 else -80.0)
