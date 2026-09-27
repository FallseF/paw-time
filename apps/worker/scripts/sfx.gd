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
##   press ボタンを押しこむ（離すと confirm・back）
## ごほうびの見せ場は、下の「ごほうびの音」の関数で鳴らす（重ねる・高さを変える・間合いをとる・BGM を下げる）
##   catch すくえた（続けるほど高く） / coins コインがじゃらっ（だんだん速く・高く） / hatch_build → hatch_release 玉がためて割れる
##   reveal 出てきた / level_up 島が広がる / place 島に置く / equip 着がえ

const BUS := &"SFX"
const MIN_GAP := 0.06
const SETTINGS := "user://settings.cfg"
## Kit.button の文字がこれなら「もどる」の音
const BACK_KEYS := ["KIT_UI_CLOSE", "QUIZ_UI_CLOSE", "WORK_MENU_CLOSE", "SHOP_CLOSE", "CHAT_CLOSE", "SETTINGS_CANCEL", "SHIFT_FORM_CANCEL", "QUIZ_UI_BACK", "END_BACK", "JOB_BACK_LIST"]
## くり返し鳴る UI の音は、毎回ほんの少し高さをゆらす（機械っぽくしない）。± の幅
const JITTER := {"tap": 0.04, "toggle": 0.04, "tab": 0.03, "confirm": 0.025, "back": 0.025, "open": 0.03, "close": 0.03, "pop": 0.035, "toast": 0.02, "press": 0.05, "place": 0.03, "error": 0.015}
## この音が鳴ったら BGM を下げる：[dB, 秒]。下げるのは Music の duck（すぐ下がって、ゆっくり戻る）
const DUCK := {
	"chime": [-3.0, 1.0], "grow": [-4.0, 1.6], "hatch": [-4.0, 1.6], "coin": [-4.0, 1.2], "bell": [-3.0, 1.2], "sparkle": [-2.5, 0.9],
	"catch": [-4.0, 1.0], "crack": [-4.0, 1.2], "crack_big": [-6.0, 2.0], "boom": [-8.0, 2.6], "reveal": [-4.0, 1.4], "reveal_rare": [-6.0, 2.2],
	"levelup": [-6.0, 2.2], "equip": [-3.0, 1.0],
}
## F のペンタトニック（F G A C D F）。すくう音は F から、ここを 1 段ずつ上がる
const PENTA := [1.0, 9.0 / 8.0, 5.0 / 4.0, 3.0 / 2.0, 5.0 / 3.0, 2.0]
## コインの粒は C から（C D F G A）。どれも曲の音階の中
const COIN_STEPS := [1.0, 9.0 / 8.0, 4.0 / 3.0, 3.0 / 2.0, 5.0 / 3.0]
## すくう・コインの粒の「続けて」は、この秒数あいたら最初から
const CATCH_WINDOW := 30.0
const TICK_WINDOW := 1.2
## ためる音（riser.wav）の頂点の位置（秒）。gen_sfx.py の s_riser の長さ
const RISER_PEAK := 1.2
## ごほうびの音の関数が鳴らす音（テストが、ファイルがあるか見る）
const CUE_SOUNDS := ["press", "catch", "chime", "coin_tick", "coin", "riser", "crack", "crack_big", "boom", "sparkle", "reveal", "reveal_rare", "pop", "levelup", "place", "equip"]

static var volume := 0.8 # 0..1（マイページのつまみ）
static var _prefs_loaded := false
static var _last := {} # 音の名前 → 最後に鳴らした時刻（ミリ秒）
static var _installed: SceneTree
static var _streams := {} # 音の名前 → AudioStream
static var _catch_n := 0
static var _catch_at := -100000
static var _tick_n := 0
static var _tick_at := -100000
static var _coins_until := -100000


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


# ---------------------------------------------------------------- 鳴らす

## 1 つ鳴らす（間引かない。間引くのは呼ぶ側：Kit.play や下の関数）。root の子に作り、鳴り終わったら消す。
## delay 秒あとに（スローモーションでも実時間で）、from 秒の所から
static func emit(node: Node, name: String, pitch := 1.0, db := 0.0, delay := 0.0, from := 0.0) -> void:
	if node == null or not node.is_inside_tree():
		return
	var tree := node.get_tree()
	install(tree)
	if not _streams.has(name):
		var path := "res://assets/sfx/%s.wav" % name
		if not ResourceLoader.exists(path):
			return
		_streams[name] = load(path)
	if delay > 0.0:
		tree.create_timer(delay, true, false, true).timeout.connect(func(): _spawn(tree, name, pitch, db, from))
	else:
		_spawn(tree, name, pitch, db, from)


static func _spawn(tree: SceneTree, name: String, pitch: float, db: float, from: float) -> void:
	if tree == null or tree.root == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = _streams[name]
	p.pitch_scale = pitch
	p.volume_db = db
	p.bus = BUS
	p.finished.connect(p.queue_free)
	p.tree_entered.connect(func(): p.play(from), CONNECT_ONE_SHOT)
	tree.root.add_child.call_deferred(p)


## くり返す UI の音の高さのゆれ（1.0 のまわり）。音階で上がる音（すくう・コインの粒）はゆらさない
static func vary(name: String) -> float:
	var j: float = JITTER.get(name, 0.0)
	return 1.0 + randf_range(-j, j) if j > 0.0 else 1.0


## 大きな音の下で BGM を下げる（DUCK に無い音は何もしない）。同じ音が続けば、下げる時間を延ばすだけ
static func duck_for(name: String, extra := 0.0) -> void:
	if DUCK.has(name):
		Music.duck("sfx:" + name, DUCK[name][0], DUCK[name][1] + extra)


static func _ok(node: Node, cue: String) -> bool:
	return node != null and node.is_inside_tree() and allow(cue)


# ---------------------------------------------------------------- ごほうびの音

## ボタンを押しこんだ（離したときに Kit.button が confirm・back を鳴らす）
static func press(node: Node) -> void:
	if _ok(node, "press"):
		emit(node, "press", vary("press"), -2.0)


## すくえた。続けてすくうほど 1 段ずつ高く（F のペンタトニック、2 倍まで）。3 つめからは鐘を小さく重ねる
static func catch(node: Node, perfect := false) -> void:
	if not _ok(node, "catch"):
		return
	var p := next_catch_pitch()
	emit(node, "catch", p)
	if _catch_n >= 3:
		emit(node, "chime", p, -9.0, 0.09)
	if perfect:
		emit(node, "coin_tick", p * 1.5, -6.0, 0.05)
	duck_for("catch")


## つぎにすくったときの高さ（続きを数える）
static func next_catch_pitch() -> float:
	var now := Time.get_ticks_msec()
	if now - _catch_at > int(CATCH_WINDOW * 1000.0):
		_catch_n = 0
	_catch_at = now
	_catch_n += 1
	return PENTA[mini(_catch_n - 1, PENTA.size() - 1)]


## ポイが破れた（すくう音の高さは最初から）
static func catch_break() -> void:
	_catch_n = 0
	_catch_at = -100000


## コインがじゃらっ：粒の [秒, 高さ] の並び。数に応じて 3〜12 粒、だんだん速く、高さは C D F G A と上がる
static func coin_plan(amount: int) -> Array:
	var n := clampi(ceili(amount / 5.0), 3, 12)
	var out: Array = []
	var t := 0.0
	var gap := 0.11
	for i in n:
		var step := int(round(float(i) * (COIN_STEPS.size() - 1) / float(maxi(n - 1, 1))))
		out.append([t, COIN_STEPS[step]])
		t += gap
		gap = maxf(0.045, gap * 0.86)
	return out


## コインをもらった（amount 枚）。粒がだんだん速く・高く → 最後にコインの音。delay 秒あとから
static func coins(node: Node, amount: int, delay := 0.0) -> void:
	if not _ok(node, "coins"):
		return
	var now := Time.get_ticks_msec()
	if now < _coins_until: # まだ前のじゃらっが鳴っている：重ねず、コインの音だけ
		emit(node, "coin", 1.0, -3.0, delay)
		return
	var plan := coin_plan(amount)
	for k in plan:
		emit(node, "coin_tick", k[1], -1.0, delay + k[0])
	var end: float = delay + plan[-1][0] + 0.06
	emit(node, "coin", 1.0, 0.0, end)
	_coins_until = now + int((end + 0.3) * 1000.0)
	duck_for("coin", end)


## コインが 1 枚とどいた（仕事のトレイ）。続けて届くほど 1 段ずつ高く。delay 秒あとに
static func coin_tick(node: Node, delay := 0.0) -> void:
	if not _ok(node, "coin_tick"):
		return
	var now := Time.get_ticks_msec()
	_tick_n = _tick_n + 1 if now - _tick_at < int(TICK_WINDOW * 1000.0) else 0
	_tick_at = now
	emit(node, "coin_tick", COIN_STEPS[mini(_tick_n, COIN_STEPS.size() - 1)], 0.0, delay)


## ためる音をどこから鳴らすか（secs 秒後に割れるとき、頂点がそこへくるように）
static func riser_from(secs: float) -> float:
	return maxf(0.0, RISER_PEAK - secs)


## 玉がためる（secs 秒後に割れる）。tier 0 いつもの・1 レア・2 特別なレア
static func hatch_build(node: Node, secs: float, tier := 0) -> void:
	if not _ok(node, "riser"):
		return
	emit(node, "riser", 1.0, -1.0 if tier > 0 else -3.0, 0.0, riser_from(secs))
	Music.duck("sfx:riser", -2.0 - 1.5 * tier, secs + 0.2)


## 玉が割れた。いつもの・材料はぱきっ、レアは大きく、特別なレアはいちばん大きく（下に低い音をしく）
static func hatch_release(node: Node, tier := 0) -> void:
	if not _ok(node, "crack"):
		return
	if tier <= 0:
		emit(node, "crack")
		duck_for("crack")
		return
	emit(node, "crack_big")
	emit(node, "sparkle", 1.0, -4.0, 0.12)
	duck_for("crack_big")
	if tier >= 2:
		emit(node, "boom", 1.0, 0.0)
		emit(node, "sparkle", 1.26, -6.0, 0.3)
		duck_for("boom")


## まとめて割れた（n 個）。ぽこぽこぽこっと上がって、最後にぱきっ
static func pops(node: Node, n: int) -> void:
	if not _ok(node, "pops"):
		return
	var k := mini(n, 8)
	for i in k:
		emit(node, "pop", PENTA[mini(i, PENTA.size() - 1)], -3.0, i * 0.055)
	emit(node, "crack", 1.0, -2.0, k * 0.055)
	duck_for("crack")


## 中身が出てきた（おばけ・島の材料・服）。tier 1 以上はレアの大きな和音
static func reveal(node: Node, tier := 0) -> void:
	if not _ok(node, "reveal"):
		return
	var n := "reveal_rare" if tier > 0 else "reveal"
	emit(node, n)
	duck_for(n)


## 島が広がる・育った
static func level_up(node: Node) -> void:
	if not _ok(node, "levelup"):
		return
	emit(node, "levelup")
	emit(node, "sparkle", 1.0, -6.0, 0.5)
	duck_for("levelup")


## 島に置いた
static func place(node: Node) -> void:
	if _ok(node, "place"):
		emit(node, "place", vary("place"))


## 着がえた（服を決めた）
static func equip(node: Node) -> void:
	if not _ok(node, "equip"):
		return
	emit(node, "equip")
	duck_for("equip")


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
