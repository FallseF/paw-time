extends Control
## 働く条件の入力（はじめての流れの「prefs」、あとから仕事の知らせからも開ける）。
## 地域（自由入力＋候補）・曜日・時間帯・最低時給・受け取り方の希望。保存は JobPrefs（user://job_prefs.json）。
## 口座・カード番号など、本物のお金の情報は聞かない（画面の下にもそう書く）。
## 主ボタンは「この条件で探して」ひとつ。

var main
var screen_name := "prefs"

const INK := Color("2a2233")
const SUB := Color("6a5f70")
const BG := Color("fbf3ea")
const ORANGE := Color("ff8a5b")
const LILAC := Color("8b7bff")

var prefs := {}
var area_edit: LineEdit
var area_chips := {}
var day_chips: Array[Button] = []
var win_chips := {}
var pay_chips := {}
var suggest_chips := {}
var wage_l: Label
var wage_slider: HSlider
var go_btn: Button
var stage: PartnerStage
var scroll: ScrollContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	prefs = JobPrefs.load_prefs()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	scroll = ScrollContainer.new()
	scroll.position = Vector2(0, 0)
	scroll.size = Vector2(360, 556)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var pad := MarginContainer.new()
	pad.custom_minimum_size = Vector2(360, 0)
	for k in ["left", "right"]:
		pad.add_theme_constant_override("margin_" + k, 16)
	pad.add_theme_constant_override("margin_top", 12)
	pad.add_theme_constant_override("margin_bottom", 12)
	scroll.add_child(pad)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	pad.add_child(v)

	# 相棒と見出し
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	stage = PartnerStage.new(Vector2(96, 96))
	head.add_child(stage)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_child(I18n.wrap(Kit.text(tr("PREFS_TITLE"), 20, INK, true)))
	hv.add_child(I18n.wrap(Kit.text(tr("PREFS_SUB") % SpecialObake.pet_name(), 13, SUB)))
	head.add_child(hv)
	v.add_child(head)

	# 地域
	var area_box := _section(v, tr("PREFS_AREA"))
	area_edit = LineEdit.new()
	area_edit.placeholder_text = tr("PREFS_AREA_PH")
	area_edit.max_length = 40
	area_edit.custom_minimum_size = Vector2(0, 42)
	var st := Kit.pill(Color.WHITE, 14, 0.0, Vector2(12, 8))
	st.border_color = Color("e2d6c8")
	st.set_border_width_all(2)
	area_edit.add_theme_stylebox_override("normal", st)
	var stf := st.duplicate() as StyleBoxFlat
	stf.border_color = ORANGE
	area_edit.add_theme_stylebox_override("focus", stf)
	area_edit.add_theme_color_override("font_color", INK)
	area_edit.add_theme_color_override("font_placeholder_color", Color("a89ea6"))
	area_edit.add_theme_font_override("font", Kit.bold())
	area_edit.add_theme_font_size_override("font_size", 15)
	area_edit.text = JobPrefs.area_label(prefs.area) if prefs.area in JobPrefs.AREAS else prefs.area
	area_edit.text_changed.connect(func(_t): _sync_area_chips())
	area_box.add_child(area_edit)
	var af := HFlowContainer.new()
	af.add_theme_constant_override("h_separation", 6)
	af.add_theme_constant_override("v_separation", 6)
	for a in JobPrefs.AREAS:
		var c := _chip(JobPrefs.area_label(a), func():
			area_edit.text = JobPrefs.area_label(a)
			_sync_area_chips())
		area_chips[a] = c
		af.add_child(c)
	area_box.add_child(af)

	# 曜日
	var day_box := _section(v, tr("PREFS_DAYS"))
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 4)
	for i in 7:
		var c := _chip(tr("JOB_WD_%d" % i), func(): _toggle_day(i), 38)
		c.custom_minimum_size = Vector2(0, 38)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		day_chips.append(c)
		dh.add_child(c)
	day_box.add_child(dh)

	# 時間帯
	var win_box := _section(v, tr("PREFS_TIME"))
	var wg := GridContainer.new()
	wg.columns = 2
	wg.add_theme_constant_override("h_separation", 6)
	wg.add_theme_constant_override("v_separation", 6)
	for w in JobPrefs.WINDOW_ORDER:
		var c := _chip(tr("PREFS_WIN_" + w.to_upper()), func(): _toggle_win(w), 40)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		win_chips[w] = c
		wg.add_child(c)
	win_box.add_child(wg)

	# 最低時給
	var wage_box := _section(v, tr("PREFS_WAGE"))
	var wh := HBoxContainer.new()
	wh.add_theme_constant_override("separation", 8)
	wh.add_child(_round_btn("−", func(): _set_wage(int(prefs.min_wage) - 50)))
	wage_l = Kit.text("", 22, INK, true, HORIZONTAL_ALIGNMENT_CENTER)
	wage_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wh.add_child(wage_l)
	wh.add_child(_round_btn("+", func(): _set_wage(int(prefs.min_wage) + 50)))
	wage_box.add_child(wh)
	wage_slider = HSlider.new()
	wage_slider.min_value = JobPrefs.WAGE_MIN
	wage_slider.max_value = JobPrefs.WAGE_MAX
	wage_slider.step = 50
	wage_slider.value = prefs.min_wage
	wage_slider.value_changed.connect(func(x): _set_wage(int(x)))
	wage_box.add_child(wage_slider)

	# 受け取り方の希望
	var pay_box := _section(v, tr("PREFS_PAY"))
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 6)
	for p in ["daily", "weekly", "monthly", "any"]:
		var c := _chip(tr("JOB_PAY_" + p.to_upper()), func(): _set_pay(p), 40)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pay_chips[p] = c
		ph.add_child(c)
	pay_box.add_child(ph)

	# 相棒の毎日の求人の知らせ（決まったバイトがある人は Off にして、自分のシフトだけで遊べる）
	var sug_box := _section(v, tr("PREFS_SUGGEST"))
	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 6)
	for on in [true, false]:
		var c := _chip(tr("PREFS_SUGGEST_ON" if on else "PREFS_SUGGEST_OFF"), func(): _set_suggest(on), 40)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		suggest_chips[on] = c
		sh.add_child(c)
	sug_box.add_child(sh)
	sug_box.add_child(I18n.wrap(Kit.text(tr("PREFS_SUGGEST_NOTE"), 12, SUB)))
	var own := Kit.button(tr("SHIFT_FORM_OPEN"), Color("f3ecff"), open_shift_form, Color("6a5bd6"), 40, 14)
	sug_box.add_child(own)

	# 本物のお金の情報は聞かない
	var note := PanelContainer.new()
	note.add_theme_stylebox_override("panel", Kit.pill(Color("eef6ea"), 14, 0.0, Vector2(12, 8)))
	note.add_child(I18n.wrap(Kit.text(tr("PREFS_SAFE"), 12, Color("3f6a4a"), true)))
	v.add_child(note)

	go_btn = Kit.button(tr("PREFS_GO"), ORANGE, _save)
	go_btn.position = Vector2(24, 570)
	go_btn.size = Vector2(312, 54)
	add_child(go_btn)
	_refresh()
	_sync_area_chips()


func _section(parent: VBoxContainer, title: String) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color.WHITE, 18, 0.06, Vector2(12, 10)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.add_child(Kit.text(title, 14, SUB, true))
	p.add_child(v)
	parent.add_child(p)
	return v


func _chip(t: String, cb: Callable, h := 34) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(0, h)
	b.add_theme_font_override("font", Kit.black())
	b.add_theme_font_size_override("font_size", 13)
	b.pressed.connect(func():
		Kit.play(self, "tap", 1.1)
		cb.call())
	_chip_style(b, false)
	return b


func _chip_style(b: Button, on: bool) -> void:
	var bg := LILAC if on else Color("f3ecff")
	for k in ["normal", "hover", "pressed", "focus"]:
		var s := Kit.pill(bg if k != "pressed" else bg.darkened(0.08), 17, 0.0, Vector2(10, 4))
		b.add_theme_stylebox_override(k, s)
	var fg := Color.WHITE if on else Color("6a5bd6")
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fg)


func _round_btn(t: String, cb: Callable) -> Button:
	var b := Kit.button(t, Color("f3ecff"), cb, Color("6a5bd6"), 40, 20)
	b.custom_minimum_size = Vector2(48, 40)
	return b


func _toggle_day(i: int) -> void:
	if prefs.days.has(i):
		prefs.days.erase(i)
	else:
		prefs.days.append(i)
	_refresh()


func _toggle_win(w: String) -> void:
	if prefs.windows.has(w):
		prefs.windows.erase(w)
	else:
		prefs.windows.append(w)
	_refresh()


func _set_wage(n: int) -> void:
	prefs.min_wage = clampi(n, JobPrefs.WAGE_MIN, JobPrefs.WAGE_MAX)
	_refresh()


func _set_pay(p: String) -> void:
	prefs.pay = p
	_refresh()


func _set_suggest(on: bool) -> void:
	prefs.suggest = on
	_refresh()


## 自分でシフトを入れる（入れたら相棒がよろこぶ）
func open_shift_form() -> void:
	var f := ShiftForm.new()
	f.added.connect(func(_s): stage.joy())
	add_child(f)


func _sync_area_chips() -> void:
	for a in area_chips:
		_chip_style(area_chips[a], area_edit.text.strip_edges() == JobPrefs.area_label(a))


func _refresh() -> void:
	for i in 7:
		_chip_style(day_chips[i], prefs.days.has(i))
	for w in win_chips:
		_chip_style(win_chips[w], prefs.windows.has(w))
	for p in pay_chips:
		_chip_style(pay_chips[p], prefs.pay == p)
	for on in suggest_chips:
		_chip_style(suggest_chips[on], bool(prefs.suggest) == on)
	wage_l.text = tr("PREFS_WAGE_VAL") % JobListings._commas(int(prefs.min_wage))
	if wage_slider and int(wage_slider.value) != int(prefs.min_wage):
		wage_slider.set_value_no_signal(prefs.min_wage)
	var ok: bool = not prefs.days.is_empty() and not prefs.windows.is_empty()
	if not prefs.suggest:
		ok = true # 知らせを受けないなら、曜日・時間帯は空でもよい
	go_btn.disabled = not ok
	go_btn.text = (tr("PREFS_GO") if prefs.suggest else tr("PREFS_SAVE")) if ok else tr("PREFS_NEED")


## 地域：候補の表示名と同じなら候補の ID で持つ（言語を変えても読める）
func _area_value() -> String:
	var t := area_edit.text.strip_edges()
	for a in JobPrefs.AREAS:
		if t == JobPrefs.area_label(a):
			return a
	return t


func _save() -> void:
	prefs.area = _area_value()
	JobPrefs.save_prefs(prefs)
	stage.joy()
	Kit.play(self, "sparkle")
	go_btn.disabled = true
	# 条件が変わったので、今日の求人を選び直す
	JobDesk.clear_today()
	if Onboarding.at("prefs"):
		# 知らせを Off にした人は、見つけた知らせの場面を飛ばして、いつもの島へ
		Onboarding.advance("found" if prefs.suggest else "done")
	await get_tree().create_timer(0.7).timeout
	main.go("garden")


# ---------------------------------------------------------------- 確認用

func demo_fill() -> void:
	area_edit.text = JobPrefs.area_label("shibuya")
	_sync_area_chips()
	prefs.days = [0, 2, 4, 5]
	prefs.windows = ["day", "evening"]
	prefs.min_wage = 1250
	prefs.pay = "weekly"
	_refresh()


func demo_scroll_end() -> void:
	scroll.scroll_vertical = 10000


func demo_suggest_off() -> void:
	_set_suggest(false)


func demo_shift_form() -> void:
	open_shift_form()
	await get_tree().process_frame
	for c in get_children():
		if c is ShiftForm:
			c.demo_fill()
