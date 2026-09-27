class_name SettingsScreen
extends Control
## マイページ（設定）。相棒の名前・言語・音楽（音量と消音）・チャットの「ふたりだけのひみつ」・匿名の利用データ（送る／送らない・ID・削除）・
## プライバシーについて・はじめからやり直す。働く条件の画面から、利用データの項目はここへ移した。
##
## 開き方は 2 通り：
##   SettingsScreen.open(parent)            … いまの画面の上に重ねる（島のボタン・チャットの「くわしく」から）。「‹」で閉じる
##   SettingsScreen.open(parent, "privacy") … プライバシーの項目までスクロールして開く
##   main.go("settings")                    … 画面として開く（閉じると島へ）
## 言語を変えたら、閉じるときに下の画面を作り直す（その言語で出し直すため）。

var main # main.go("settings") で開いたときだけ入る
var screen_name := "settings"
var focus := "" # "privacy" ならその項目まで

const INK := Color("2a2233")
const SUB := Color("6a5f70")
const BG := Color("fbf3ea")
const LILAC := Color("8b7bff")
const PURPLE := Color("6a5bd6")
const RED := Color("c0504a")
## はじめからやり直しても残すもの：利用データの ID と送る設定、そのお知らせを見たこと（言語は settings.cfg で、これも残る）
const KEEP_ON_RESET := ["telemetry.json", "telemetry_notice.json"]

var scroll: ScrollContainer
var list: VBoxContainer
var privacy_box: Control
var name_edit: LineEdit
var name_status: Label
var tm_status: Label
var id_l: Label
var chips := {} # "lang:en" / "chat:true" / "tm:false" … → Button
var confirm: Control
var lang_changed := false
var music_slider: HSlider
var sfx_slider: HSlider


## いまの画面の上にマイページを重ねる。section = "privacy" でプライバシーの項目から
static func open(parent: Node, section := "") -> SettingsScreen:
	var s := SettingsScreen.new()
	s.focus = section
	parent.add_child(s)
	return s


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT) # 重ねて開いたときも、親いっぱいに
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	chips.clear()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# 見出し：もどる・マイページ
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.94), 0, 0.08, Vector2(8, 6)))
	head.position = Vector2(0, 0)
	head.size = Vector2(360, 66)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 6)
	head.add_child(hh)
	var back := _link("‹", close, INK, 28)
	back.custom_minimum_size = Vector2(44, 44)
	hh.add_child(back)
	var title := Kit.text(tr("SETTINGS_TITLE"), 19, INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(title)

	scroll = ScrollContainer.new()
	scroll.position = Vector2(0, 66)
	scroll.size = Vector2(360, maxf(574.0, size.y - 66.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(scroll)
	add_child(scroll)
	add_child(head)
	var pad := MarginContainer.new()
	pad.custom_minimum_size = Vector2(360, 0)
	for k in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + k, 16)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 24)
	scroll.add_child(pad)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	pad.add_child(list)

	_name_section()
	_lang_section()
	_music_section()
	_chat_section()
	_usage_section()
	_privacy_section()
	_reset_section()
	_refresh()
	if focus == "privacy":
		_scroll_to_privacy.call_deferred()


func _scroll_to_privacy() -> void:
	# 折り返すラベルの高さが決まってから
	for i in 3:
		await get_tree().process_frame
	if is_instance_valid(privacy_box):
		scroll.scroll_vertical = int(privacy_box.position.y)


# ---------------------------------------------------------------- 部品（働く条件の画面と同じ系統）

func _section(title: String) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color.WHITE, 18, 0.06, Vector2(14, 12)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(Kit.text(title, 14, SUB, true))
	p.add_child(v)
	list.add_child(p)
	return v


func _note(t: String, size := 12, color := SUB) -> Label:
	var l := I18n.wrap(Kit.text(t, size, color))
	l.custom_minimum_size = Vector2(290, 0)
	return l


func _chip(key: String, t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, 40)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Kit.black())
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(func():
		Kit.play(self, "toggle")
		cb.call())
	chips[key] = b
	return b


func _chip_style(b: Button, on: bool) -> void:
	var bg := LILAC if on else Color("f3ecff")
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, Kit.pill(bg if k != "pressed" else bg.darkened(0.08), 18, 0.0, Vector2(10, 4)))
	var fg := Color.WHITE if on else PURPLE
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fg)


func _row(items: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for it in items:
		h.add_child(it)
	return h


func _link(t: String, cb: Callable, color := PURPLE, fs := 14) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 34)
	b.add_theme_font_override("font", Kit.black())
	b.add_theme_font_size_override("font_size", fs)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, color)
	b.pressed.connect(func():
		Kit.play(self, "tap", 1.1)
		cb.call())
	return b


# ---------------------------------------------------------------- 項目

func _name_section() -> void:
	# GameState は名前で引く（チャットのテストの -s 実行では、自動読み込みより先にこのスクリプトが読まれるため）
	var gs := get_node_or_null("/root/GameState")
	if gs == null or gs.my_obake.is_empty():
		return
	var v := _section(tr("SETTINGS_NAME"))
	name_edit = LineEdit.new()
	name_edit.text = SpecialObake.pet_name()
	name_edit.max_length = SpecialObake.NAME_MAX
	name_edit.custom_minimum_size = Vector2(0, 42)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := Kit.pill(Color.WHITE, 14, 0.0, Vector2(12, 8))
	st.border_color = Color("e2d6c8")
	st.set_border_width_all(2)
	name_edit.add_theme_stylebox_override("normal", st)
	var stf := st.duplicate() as StyleBoxFlat
	stf.border_color = Color("ff8a5b")
	name_edit.add_theme_stylebox_override("focus", stf)
	name_edit.add_theme_font_override("font", Kit.black())
	name_edit.add_theme_font_size_override("font_size", 16)
	name_edit.add_theme_color_override("font_color", INK)
	name_edit.text_submitted.connect(func(_t): save_name())
	var save := Kit.button(tr("SETTINGS_NAME_SAVE"), Color("ff8a5b"), save_name, Color.WHITE, 42, 14)
	save.custom_minimum_size.x = 84
	v.add_child(_row([name_edit, save]))
	name_status = _note("")
	name_status.visible = false # 保存したときだけ
	v.add_child(name_status)


func save_name() -> void:
	SpecialObake.set_partner_name(name_edit.text)
	name_edit.text = SpecialObake.pet_name()
	name_edit.release_focus()
	name_status.text = tr("SETTINGS_SAVED")
	name_status.visible = true


func _lang_section() -> void:
	var v := _section(tr("SETTINGS_LANG"))
	# 言語の名前は、その言語のまま書く（どちらの表示でも読めるように）
	var en := _chip("lang:en", "English", func(): set_lang("en"))
	var ja := _chip("lang:ja", "日本語", func(): set_lang("ja"))
	for b in [en, ja]:
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.add_child(_row([en, ja]))


func set_lang(lang: String) -> void:
	if Kit.is_en() == (lang == "en"):
		return
	Kit.save_lang(lang)
	lang_changed = true
	_build()


## 音楽：鳴らす／消す と音量（scripts/music.gd）。その下に効果音の音量（scripts/sfx.gd）。どちらも settings.cfg の [audio] に残る
func _music_section() -> void:
	Music.load_prefs()
	var v := _section(tr("R3_MUSIC"))
	v.add_child(_row([
		_chip("music:true", tr("PREFS_SUGGEST_ON"), func(): set_music_on(true)),
		_chip("music:false", tr("PREFS_SUGGEST_OFF"), func(): set_music_on(false)),
	]))
	music_slider = HSlider.new()
	music_slider.min_value = 0.0
	music_slider.max_value = 1.0
	music_slider.step = 0.05
	music_slider.value = Music.volume
	music_slider.custom_minimum_size = Vector2(0, 32)
	music_slider.focus_mode = Control.FOCUS_NONE
	music_slider.value_changed.connect(set_music_volume)
	v.add_child(music_slider)
	Sfx.load_prefs()
	v.add_child(Kit.text("Sound effects" if Kit.is_en() else "効果音", 13, SUB, true))
	sfx_slider = HSlider.new()
	sfx_slider.min_value = 0.0
	sfx_slider.max_value = 1.0
	sfx_slider.step = 0.05
	sfx_slider.value = Sfx.volume
	sfx_slider.custom_minimum_size = Vector2(0, 32)
	sfx_slider.focus_mode = Control.FOCUS_NONE
	sfx_slider.value_changed.connect(set_sfx_volume)
	v.add_child(sfx_slider)


func set_music_on(on: bool) -> void:
	Music.set_muted(not on)
	_refresh()


## つまみを動かしたら、消していても鳴らす
func set_music_volume(x: float) -> void:
	Music.set_volume(x)
	if Music.muted and x > 0.0:
		Music.set_muted(false)
		_refresh()


## 効果音の大きさ。動かしたら、その大きさで 1 つ鳴らして聞かせる（連打は Kit.play が間引く）
func set_sfx_volume(x: float) -> void:
	Sfx.set_volume(x)
	Kit.play(self, "tap")


func _chat_section() -> void:
	var v := _section(tr("SETTINGS_CHAT"))
	v.add_child(_row([
		_chip("chat:false", tr("SETTINGS_CHAT_REMEMBER"), func(): set_chat_private(false)),
		_chip("chat:true", tr("CHAT_CONSENT_PRIVATE"), func(): set_chat_private(true)),
	]))
	v.add_child(_note(tr("SETTINGS_CHAT_HINT")))


func set_chat_private(on: bool) -> void:
	ChatMe.set_private(on)
	_refresh()


func _usage_section() -> void:
	var v := _section(tr("TELEMETRY_TOGGLE"))
	v.add_child(_row([
		_chip("tm:true", tr("PREFS_SUGGEST_ON"), func(): set_usage(true)),
		_chip("tm:false", tr("PREFS_SUGGEST_OFF"), func(): set_usage(false)),
	]))
	v.add_child(_note(tr("TELEMETRY_TOGGLE_HINT")))
	id_l = _note(tr("TELEMETRY_ID") % Telemetry.install_id(), 10)
	v.add_child(id_l)
	v.add_child(Kit.button(tr("TELEMETRY_DELETE"), Color("f3ecff"), delete_usage, PURPLE, 40, 14))
	tm_status = _note("", 11)
	tm_status.visible = false # 削除したときだけ
	v.add_child(tm_status)


func set_usage(on: bool) -> void:
	Telemetry.set_enabled(on)
	_refresh()


func delete_usage() -> void:
	Telemetry.request_deletion()
	tm_status.text = tr("TELEMETRY_DELETED")
	tm_status.visible = true
	id_l.text = tr("TELEMETRY_ID") % Telemetry.install_id()


func _privacy_section() -> void:
	var v := _section(tr("SETTINGS_PRIVACY"))
	privacy_box = v.get_parent()
	v.add_child(Kit.text(tr("SETTINGS_PRIVACY_CHAT"), 13, INK, true))
	v.add_child(_note(tr("PRIVACY_CHAT"), 13))
	v.add_child(Kit.text(tr("SETTINGS_PRIVACY_USAGE"), 13, INK, true))
	v.add_child(_note(tr("TELEMETRY_NOTICE"), 13))
	v.add_child(_link(tr("TELEMETRY_NOTICE_MORE") + " ›", func(): OS.shell_open(TelemetryNotice.PRIVACY_URL)))


func _reset_section() -> void:
	var v := _section(tr("SETTINGS_RESET"))
	v.add_child(_note(tr("SETTINGS_RESET_BODY")))
	v.add_child(Kit.button(tr("SETTINGS_RESET"), Color("fdecea"), ask_reset, RED, 40, 14))


func _refresh() -> void:
	var state := {"lang:en": Kit.is_en(), "lang:ja": not Kit.is_en(), "chat:true": ChatMe.is_private(), "chat:false": not ChatMe.is_private(),
		"tm:true": Telemetry.is_enabled(), "tm:false": not Telemetry.is_enabled(), "music:true": not Music.muted, "music:false": Music.muted}
	for k in chips:
		_chip_style(chips[k], state.get(k, false))


# ---------------------------------------------------------------- はじめからやり直す

func ask_reset() -> void:
	if confirm and is_instance_valid(confirm):
		return
	confirm = ColorRect.new()
	(confirm as ColorRect).color = Color(0.12, 0.1, 0.2, 0.55)
	confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(confirm)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color.WHITE, 22, 0.2, Vector2(18, 14)))
	p.position = Vector2(24, 220)
	p.size = Vector2(312, 0)
	confirm.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(Kit.text(tr("SETTINGS_RESET_Q"), 18, INK, true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_note(tr("SETTINGS_RESET_BODY"), 13))
	v.add_child(Kit.button(tr("SETTINGS_RESET_YES"), RED, reset_game, Color.WHITE, 44, 15))
	v.add_child(_link(tr("SETTINGS_CANCEL"), func():
		confirm.queue_free()
		confirm = null, SUB))
	Kit.keep_fit(p, func():
		p.size.y = 0
		p.position.y = (size.y - p.size.y) / 2.0)


## この端末のゲームの記録を消して、はじめから（診断から）。利用データの ID・送る設定・言語は残す
func reset_game() -> void:
	SettingsScreen.erase_saves()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("location.hash = ''; location.reload()")
	else:
		OS.set_restart_on_exit(true, OS.get_cmdline_args())
		get_tree().quit()


## user:// の記録（.json）を消す。dir はテスト用
static func erase_saves(dir := "user://") -> Array:
	var gone: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == "json" and not KEEP_ON_RESET.has(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(f)))
			gone.append(f)
	return gone


# ---------------------------------------------------------------- 閉じる

func close() -> void:
	if main:
		main.go("garden")
		return
	var m := _find_main()
	queue_free()
	# 言語を変えたら、下の画面をその言語で作り直す
	if lang_changed and m:
		m.go(m.current_name, true)


func _find_main() -> Node:
	var n := get_parent()
	while n:
		if n.has_method("go") and "current_name" in n:
			return n
		n = n.get_parent()
	return null


# ---------------------------------------------------------------- 確認用

func demo_privacy() -> void:
	focus = "privacy"
	_scroll_to_privacy()


func demo_reset() -> void:
	ask_reset()
