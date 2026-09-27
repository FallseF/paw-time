class_name Music
extends Node
## 音楽の係（BGM）。main.gd が 1 つ持ち、画面が変わるたびに play_for(画面の名前) を呼ぶ。
##   - 画面 → 曲は SCREEN_TRACK（無ければ島の曲）。同じ曲の画面どうしでは鳴らしなおさない
##   - 曲のかわり目は等パワーのクロスフェード（XFADE 秒）。はじめの 1 曲はゆっくり立ち上げる
##   - 数分以内に戻ってきた曲は、止めたところの続きから（RESUME_WITHIN）
##   - ループの継ぎ目は曲のファイルに焼きこみ済み（tools/bake_music.py）。ファイルの終わり → TRACKS.loop へ戻れば切れ目なし
##   - 孵化の画面・めあての鐘・特別なレアの動画の間は、BGM を少し下げる（duck）
##   - Web は最初のタップまで音が出せないので、その時に鳴らしはじめる
## 鳴らし方は 2 通り。状態（どの曲をどれだけ出すか・位置）はどちらも同じで、最後の「鳴らす・大きさ・止める」だけが違う。
##   Web … ブラウザの Web Audio で直接（web_bgm.js 相当を _JS で入れる）。Godot の Web の音（sample）はループの位置を無視して
##          頭から鳴らしなおし、長い曲を最初に鳴らすときに画面が止まるため。デコードはブラウザが裏でする
##   ほか … AudioStreamPlayer（loop_offset で切れ目なし）。Web でブラウザが OGG を読めなかったときもこちら
## 曲のファイルは import せず（.import の importer="keep"）そのまま書き出し、どちらもそのバイト列から読む。
## 曲は Google Lyria 3 で作り、-16 LUFS にそろえてある（assets/music/）。db は画面での聞こえ方の調整だけ。
## 音量と消音は settings.cfg の [audio]（マイページで変える）。

const TRACKS := {
	"title": {"path": "res://assets/music/title.ogg", "loop": 17.389977, "db": -5.0},
	"island": {"path": "res://assets/music/island.ogg", "loop": 35.987029, "db": -6.0},
	"night": {"path": "res://assets/music/night.ogg", "loop": 55.107302, "db": -7.0},
	"work": {"path": "res://assets/music/work.ogg", "loop": 21.422313, "db": -7.0},
	"reveal": {"path": "res://assets/music/reveal.ogg", "loop": -1.0, "db": -4.0}, # ファンファーレ（ループしない）
}
const DEFAULT_TRACK := "island"
## 画面の名前（main.gd の SCREENS）→ 曲。ここに無い画面は島の曲
const SCREEN_TRACK := {
	"title": "title",
	"catch": "night",
	"night": "night",
	"moon": "night",
	"work": "work",
	"practice": "work",
}
## この画面の間は BGM を下げる（孵化はジングルが続くので）
const SCREEN_DUCK := {"hatch": -6.0}
const XFADE := 1.5
const FIRST_FADE := 2.5
const FANFARE_FADE := 0.8
const RESUME_WITHIN := 180.0
const SETTINGS := "user://settings.cfg"

static var inst: Music
static var volume := 0.8 # 0..1（マイページのつまみ）
static var muted := false
static var _prefs_loaded := false
static var _log_on := -1 # 確認用のログ（_log）。-1 はまだ調べていない

## 鳴っている／消えかけている声。
## {id, p（0..1 の出方）, dir（+1 上げる・-1 下げる）, dur, pos（曲の中の秒）, player（Godot）| js（Web の声の番号。0 はデコード待ち）}
var voices: Array = []
var current := "" # いま鳴らしたい曲
var unlocked := true # Web は最初の入力まで false
var web := false # ブラウザの Web Audio で鳴らす
var _resume := {} # 曲 → {pos, at}
var _duck := {} # 名前 → [db, 残り秒（0 なら手で外すまで）]
var _duck_db := 0.0
var _now := 0.0
var _last_ms := -1
var _streams := {}
var _lengths := {}
var _used := {} # 曲 → 最後に鳴っていた時刻（Web で、長く使わない曲のデコード済みの音を手放す）
var _fan := {} # ファンファーレの声（voices と同じ形）。left = 残り秒
var _js: JavaScriptObject
var _js_go: JavaScriptObject


func _ready() -> void:
	inst = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_prefs()
	unlocked = not OS.has_feature("web")
	if OS.has_feature("web"):
		_js = _install_js()
		web = _js != null
	_log("ready web=%s" % web)
	# 確認用（?musiclog=1 のときだけ）：ブラウザから window.pawMusicGo("catch") で画面を変える
	if _log_on == 1 and OS.has_feature("web") and get_parent().has_method("go"):
		_js_go = JavaScriptBridge.create_callback(func(args): get_parent().go(String(args[0]), true))
		JavaScriptBridge.get_interface("window").pawMusicGo = _js_go


func _exit_tree() -> void:
	if inst == self:
		inst = null
	for v in voices:
		_b_stop(v)
	voices.clear()
	if not _fan.is_empty():
		_b_stop(_fan)


static func track_for(screen_name: String) -> String:
	return SCREEN_TRACK.get(screen_name, DEFAULT_TRACK)


# ---------------------------------------------------------------- 画面から

## 画面に合わせて曲を変える（同じ曲ならそのまま）
func play_for(screen_name: String) -> void:
	set_duck("screen", SCREEN_DUCK.get(screen_name, 0.0))
	if screen_name == "hatch":
		_prepare("reveal") # 特別なレアの動画のファンファーレを先に（Web のデコード）
	play(track_for(screen_name))


func play(id: String) -> void:
	if not TRACKS.has(id):
		return
	if id == current and (not unlocked or _voice(id) != null):
		return
	current = id
	_prepare(id)
	if not unlocked:
		return # 最初のタップで鳴らす
	var fade := XFADE if _audible_count() > 0 else FIRST_FADE
	for v in voices:
		if v.id != id and v.dir > 0:
			v.dir = -1
			v.dur = XFADE
	var v = _voice(id)
	if v != null:
		# 消えかけていた同じ曲を、そこから戻す（鳴らしなおさない）
		v.dir = 1
		v.dur = fade
		return
	var from := 0.0
	var r = _resume.get(id)
	if r != null and _now - float(r.at) <= RESUME_WITHIN:
		from = float(r.pos)
	var nv := {"id": id, "p": 0.0, "dir": 1, "dur": fade, "pos": from}
	_b_start(nv)
	voices.append(nv)


## いまの曲の位置（秒）。テストと確認用
func position_of(id: String) -> float:
	var v = _voice(id)
	return float(v.pos) if v != null else -1.0


func _voice(id: String):
	for v in voices:
		if v.id == id:
			return v
	return null


func _audible_count() -> int:
	var n := 0
	for v in voices:
		if v.p > 0.001:
			n += 1
	return n


func length_of(id: String) -> float:
	if not _lengths.has(id):
		var s := _stream(id)
		_lengths[id] = s.get_length() if s else 0.0
	return _lengths[id]


# ---------------------------------------------------------------- 下げる（duck）

## name の分だけ下げる（db は負）。secs > 0 ならその秒数で自然に外れる。0 dB で外す
func set_duck(name: String, db: float, secs := 0.0) -> void:
	if db >= 0.0:
		_duck.erase(name)
	else:
		_duck[name] = [db, secs]


static func duck(name: String, db: float, secs := 0.0) -> void:
	if inst:
		inst.set_duck(name, db, secs)


## 特別なレアの動画のファンファーレ。BGM は動画の間 10 dB 下げる
static func fanfare() -> void:
	if inst:
		inst._play_fanfare()


## 動画が終わった（飛ばした）。残りが長ければ 0.8 秒で消す、短ければ鳴り終わるまで
static func fanfare_end() -> void:
	if inst and not inst._fan.is_empty() and inst._fan.left > 1.2 and inst._fan.dir > 0:
		inst._fan.dir = -1
		inst._fan.dur = FANFARE_FADE


func _play_fanfare() -> void:
	if not unlocked:
		return
	if not _fan.is_empty():
		_b_stop(_fan)
	_fan = {"id": "reveal", "p": 1.0, "dir": 1, "dur": 0.01, "pos": 0.0, "left": length_of("reveal")}
	_b_start(_fan)
	set_duck("reveal", -10.0)


# ---------------------------------------------------------------- 毎フレーム

func _process(_delta: float) -> void:
	var ms := Time.get_ticks_msec()
	var dt := 0.0 if _last_ms < 0 else (ms - _last_ms) / 1000.0
	_last_ms = ms
	step(minf(dt, 0.25))


## dt 秒ぶん進める（テストはこれを直接呼ぶ）
func step(dt: float) -> void:
	_now += dt
	# 下げる量：一番深いもの。下げるのは速く（0.25 秒）、戻すのはゆっくり（0.8 秒）
	var want := 0.0
	for k in _duck.keys():
		var d: Array = _duck[k]
		want = minf(want, d[0])
		if d[1] > 0.0:
			d[1] -= dt
			if d[1] <= 0.0:
				_duck.erase(k)
	var rate := (40.0 if want < _duck_db else 12.5) * dt
	_duck_db = move_toward(_duck_db, want, rate)
	# デコード待ちの声があれば、消えていく声もそこで待つ（無音のすき間を作らない）
	var waiting := false
	for v in voices:
		if not _b_started(v):
			_b_start(v)
			waiting = waiting or not _b_started(v)
	for v in voices.duplicate():
		if not _b_started(v) or (waiting and v.dir < 0):
			if _b_started(v):
				_advance(v, dt)
			continue
		v.p = clampf(v.p + v.dir * dt / maxf(v.dur, 0.01), 0.0, 1.0)
		_advance(v, dt)
		_used[v.id] = _now
		if v.dir < 0 and v.p <= 0.0:
			_resume[v.id] = {"pos": v.pos, "at": _now}
			_b_stop(v)
			voices.erase(v)
			continue
		# 等パワー：出方 p を sin で振幅に
		_b_gain(v, _amp_db(sin(v.p * PI * 0.5)) + TRACKS[v.id].db + _duck_db)
	_step_fanfare(dt)
	if web:
		_forget_idle()


func _advance(v: Dictionary, dt: float) -> void:
	v.pos += dt
	var lo: float = TRACKS[v.id].loop
	var length := length_of(v.id)
	if lo >= 0.0 and length > lo and v.pos >= length:
		v.pos = lo + fmod(v.pos - lo, length - lo)


func _step_fanfare(dt: float) -> void:
	if _fan.is_empty():
		return
	if not _b_started(_fan):
		_b_start(_fan)
		if not _b_started(_fan):
			return
	_fan.left -= dt
	if _fan.dir < 0:
		_fan.p = clampf(_fan.p - dt / _fan.dur, 0.0, 1.0)
	if _fan.left <= 0.0 or _fan.p <= 0.0:
		_b_stop(_fan)
		_fan = {}
		set_duck("reveal", 0.0)
		return
	_b_gain(_fan, _amp_db(_fan.p) + TRACKS.reveal.db)


func _amp_db(amp: float) -> float:
	var a := amp * (0.0 if muted else volume * volume) # つまみは耳の感じに合わせて 2 乗
	return linear_to_db(a) if a > 0.0001 else -80.0


# ---------------------------------------------------------------- 鳴らし方（Godot / Web Audio）

func _bytes(id: String) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(TRACKS[id].path)


func _stream(id: String) -> AudioStream:
	if not _streams.has(id):
		var s := AudioStreamOggVorbis.load_from_buffer(_bytes(id))
		if s:
			s.loop = TRACKS[id].loop >= 0.0
			s.loop_offset = maxf(TRACKS[id].loop, 0.0)
		_streams[id] = s
	return _streams[id]


## 鳴らす前の下ごしらえ（Web はデコードを始めておく）
func _prepare(id: String) -> void:
	if web and String(_js.status(id)) == "none":
		_js.load(id, Marshalls.raw_to_base64(_bytes(id)))
		_log("decode " + id)


func _b_started(v: Dictionary) -> bool:
	return v.has("player") or int(v.get("js", 0)) > 0


func _b_start(v: Dictionary) -> void:
	if web:
		_prepare(v.id)
		var st := String(_js.status(v.id))
		if st == "ready":
			v.js = int(_js.play(v.id, v.pos, TRACKS[v.id].loop))
			_log("play %s from %.1f (web)" % [v.id, v.pos])
			return
		if st != "error":
			v.js = 0 # デコード待ち。次のフレームでもう一度
			return
		v.erase("js") # ブラウザが読めなかった：Godot で鳴らす
	var pl := AudioStreamPlayer.new()
	pl.stream = _stream(v.id)
	pl.volume_db = -80.0
	add_child(pl)
	pl.play(v.pos)
	v.player = pl
	_log("play %s from %.1f" % [v.id, v.pos])


func _b_gain(v: Dictionary, db: float) -> void:
	if v.has("player"):
		v.player.volume_db = db
	elif int(v.get("js", 0)) > 0:
		_js.gain(v.js, db_to_linear(db) if db > -79.0 else 0.0)


func _b_stop(v: Dictionary) -> void:
	if v.has("player"):
		v.player.stop()
		v.player.queue_free()
	elif int(v.get("js", 0)) > 0:
		_js.stop(v.js)


## Web：しばらく鳴らしていない曲のデコード済みの音を手放す（1 曲 30 MB ほどあるため）
func _forget_idle() -> void:
	for id in _used.keys():
		if id != current and _voice(id) == null and _now - float(_used[id]) > RESUME_WITHIN:
			_js.drop(id)
			_used.erase(id)
			_log("drop " + id)


const _JS := """
(function () {
	if (window.pawBgm) return window.pawBgm;
	var AC = window.AudioContext || window.webkitAudioContext;
	if (!AC) return null;
	var ctx = new AC();
	var out = ctx.createGain();
	out.connect(ctx.destination);
	var bufs = {}, state = {}, voices = {}, next = 1;
	var unlock = function () { if (ctx.state !== 'running') ctx.resume(); };
	['pointerdown', 'touchend', 'mousedown', 'keydown'].forEach(function (e) { document.addEventListener(e, unlock, true); });
	window.pawBgm = {
		ctx: ctx,
		status: function (id) { return state[id] || 'none'; },
		load: function (id, b64) {
			state[id] = 'loading';
			var bin = atob(b64), u = new Uint8Array(bin.length);
			for (var i = 0; i < bin.length; i++) u[i] = bin.charCodeAt(i);
			ctx.decodeAudioData(u.buffer).then(function (b) { if (state[id] === 'loading') { bufs[id] = b; state[id] = 'ready'; } },
				function () { state[id] = 'error'; });
		},
		drop: function (id) { delete bufs[id]; delete state[id]; },
		play: function (id, offset, loopStart) {
			var b = bufs[id];
			if (!b) return 0;
			var s = ctx.createBufferSource(), g = ctx.createGain();
			s.buffer = b;
			if (loopStart >= 0) { s.loop = true; s.loopStart = loopStart; s.loopEnd = b.duration; }
			g.gain.value = 0;
			s.connect(g); g.connect(out);
			s.start(0, Math.min(Math.max(offset, 0), b.duration - 0.05));
			var v = next++;
			voices[v] = { s: s, g: g, id: id };
			return v;
		},
		gain: function (v, x) { var o = voices[v]; if (o) o.g.gain.setTargetAtTime(x, ctx.currentTime, 0.015); },
		stop: function (v) {
			var o = voices[v];
			if (!o) return;
			try { o.s.stop(); } catch (e) {}
			o.s.disconnect(); o.g.disconnect();
			delete voices[v];
		},
		playing: function () { return Object.keys(voices).map(function (k) { return voices[k].id; }).join(','); },
	};
	return window.pawBgm;
})()
"""


func _install_js() -> JavaScriptObject:
	JavaScriptBridge.eval(_JS, true)
	var w := JavaScriptBridge.get_interface("window")
	return w.pawBgm if w and w.pawBgm else null


# ---------------------------------------------------------------- Web：最初のタップで鳴らす

func _input(e: InputEvent) -> void:
	if unlocked:
		return
	var tap: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed) or (e is InputEventKey and e.pressed)
	if tap:
		unlock()


func unlock() -> void:
	if unlocked:
		return
	unlocked = true
	_log("unlock")
	var id := current
	current = ""
	play(id)


# ---------------------------------------------------------------- 音量（マイページ）

static func load_prefs() -> void:
	if _prefs_loaded:
		return
	_prefs_loaded = true
	var c := ConfigFile.new()
	if OS.get_environment("OBAKE_NOSAVE") == "" and c.load(SETTINGS) == OK:
		volume = clampf(float(c.get_value("audio", "music", volume)), 0.0, 1.0)
		muted = bool(c.get_value("audio", "music_muted", muted))


static func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_save_prefs()


static func set_muted(on: bool) -> void:
	muted = on
	_save_prefs()


static func _save_prefs() -> void:
	if OS.get_environment("OBAKE_NOSAVE") != "":
		return
	var c := ConfigFile.new()
	c.load(SETTINGS)
	c.set_value("audio", "music", volume)
	c.set_value("audio", "music_muted", muted)
	c.save(SETTINGS)


## 確認用：OBAKE_MUSIC_LOG=1（Web は ?musiclog=1）で、何を鳴らしたかを出す
func _log(s: String) -> void:
	if _log_on < 0:
		_log_on = 1 if OS.get_environment("OBAKE_MUSIC_LOG") != "" else 0
		if OS.has_feature("web"):
			var q = JavaScriptBridge.eval("location.search", true)
			if typeof(q) == TYPE_STRING and String(q).contains("musiclog=1"):
				_log_on = 1
	if _log_on == 1:
		print("[music] ", s)
