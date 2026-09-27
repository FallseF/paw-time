class_name SpecialReveal
extends Control
## 特別なレア 6 匹の「はじめまして」の動画（コマ送り）。はじめてその子が生まれたときだけ、玉が割れたあとに流す。
## コマは assets/reveal/<id>/f_001..062.jpg（12 fps、そのまま書き出す）。1 コマずつ読んで同じテクスチャに上書きし、終わったら手放す。
## 右上の「スキップ」と、1 秒たってからの画面タップで飛ばせる。音はファンファーレ（Music.fanfare、BGM は下げる）。
## はじめての夜の玉は、この 6 匹のどれか 1 匹（インストールごとに決まって、読み直しても変わらない）。
## 確認用：OBAKE_REVEAL=<id> で、その子の孵化の画面から

signal done

const IDS := ["sakura", "yomise", "amagasa", "kazaguruma", "mangetsu", "hyakki"]
const FRAMES := 62
const FPS := 12.0
const PATH := "user://special_reveal.json"
const SKIP_AFTER := 1.0

static var _loaded := false
static var _pick := ""
## テストで、OBAKE_NOSAVE のままファイルへの保存と読み直しを確かめるとき
static var force_save := false

var rid := ""
var tex: ImageTexture
var pic: TextureRect
var skip_btn: Button
var _t := 0.0
var _frame := -1
var _finished := false


# ---------------------------------------------------------------- 1 匹の決まり（インストールごと）

static func is_special(id: String) -> bool:
	return id in IDS


static func has_clip(id: String) -> bool:
	return is_special(id) and FileAccess.file_exists(_frame_path(id, 1))


static func _frame_path(id: String, i: int) -> String:
	return "res://assets/reveal/%s/f_%03d.jpg" % [id, i]


static func _nosave() -> bool:
	return OS.get_environment("OBAKE_NOSAVE") != "" and not force_save


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if _nosave() or not FileAccess.file_exists(PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if d is Dictionary:
		var p := String(d.get("pick", ""))
		p = Rares.RENAMED.get(p, p)
		if p in IDS:
			_pick = p


## はじめての夜の玉からかえる子（このインストールで一度だけ決めて、覚えておく）
static func pick() -> String:
	_ensure()
	if _pick == "":
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_pick = IDS[rng.randi_range(0, IDS.size() - 1)]
		if not _nosave():
			var f := FileAccess.open(PATH, FileAccess.WRITE)
			if f:
				f.store_string(JSON.stringify({"pick": _pick}))
	return _pick


## 新しいインストールのふり（テスト用）。forget_file なら保存したものも消す
static func reset(forget_file := false) -> void:
	_loaded = false
	_pick = ""
	if forget_file and FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


# ---------------------------------------------------------------- 流す

## 画面いっぱいに流して、終わる（飛ばす）まで待つ。parent は孵化の画面など
static func play(parent: Control, id: String) -> void:
	if not has_clip(id):
		return
	var r := SpecialReveal.new()
	r.rid = id
	parent.add_child(r)
	await r.done
	# 下の孵化のカードへ、やわらかく溶ける
	var tw := r.create_tween()
	tw.tween_property(r, "modulate:a", 0.0, 0.45)
	tw.tween_callback(r.queue_free)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var back := ColorRect.new()
	back.color = Color(0.07, 0.06, 0.12, 0.92)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)
	pic = TextureRect.new()
	pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pic)
	skip_btn = Button.new()
	skip_btn.text = tr("スキップ ›")
	skip_btn.focus_mode = Control.FOCUS_NONE
	skip_btn.anchor_left = 1.0
	skip_btn.anchor_right = 1.0
	skip_btn.offset_left = -92
	skip_btn.offset_right = -8
	skip_btn.offset_top = 10
	skip_btn.offset_bottom = 44
	skip_btn.add_theme_font_override("font", Kit.bold())
	skip_btn.add_theme_font_size_override("font_size", 14)
	for k in ["normal", "hover", "pressed"]:
		skip_btn.add_theme_stylebox_override(k, Kit.pill(Color(0, 0, 0, 0.35), 16, 0.0, Vector2(12, 4)))
	skip_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	skip_btn.pressed.connect(_finish)
	add_child(skip_btn)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.25)
	_show_frame(0)
	Music.fanfare()


func _process(delta: float) -> void:
	if _finished:
		return
	_t += delta
	var want := int(_t * FPS)
	if want >= FRAMES:
		_finish()
		return
	if want != _frame:
		_show_frame(want)


## 1 コマ読んで、同じテクスチャに上書き（コマを溜めない）
func _show_frame(i: int) -> void:
	_frame = i
	var bytes := FileAccess.get_file_as_bytes(_frame_path(rid, i + 1))
	if bytes.is_empty():
		return
	var img := Image.new()
	if img.load_jpg_from_buffer(bytes) != OK:
		return
	if tex == null or tex.get_size() != Vector2(img.get_size()):
		tex = ImageTexture.create_from_image(img)
		pic.texture = tex
	else:
		tex.update(img)


func _gui_input(e: InputEvent) -> void:
	var tap: bool = (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed)
	if tap and _t >= SKIP_AFTER:
		accept_event()
		_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	skip_btn.disabled = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Music.fanfare_end()
	done.emit()


func _exit_tree() -> void:
	pic.texture = null
	tex = null
