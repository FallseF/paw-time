extends Control
## 働く条件の入力（はじめての流れの「prefs」、あとから仕事の知らせからも開ける）。
## 地域（候補のチップをいくつでも＋自由入力、どれかに合えばよい）・週のマス（曜日×時間帯）・最低時給・受け取り方の希望。保存は JobPrefs（user://job_prefs.json）。
## 口座・カード番号など、本物のお金の情報は聞かない。
## 主ボタンは「この条件で探して」ひとつ。

var main
var screen_name := "prefs"

const INK := Color("2a2233")
const SUB := Color("6a5f70")
const BG := Color("fbf3ea")
const ORANGE := Color("ff8a5b")
const LILAC := Color("8b7bff")

var prefs := {}
var area_edit: LineEdit # 候補にない地域（「、」「,」で区切っていくつでも）
var area_chips := {}
var area_on: Array = [] # えらんだ候補の地域（ID）
var cells := {} # "<曜日>:<時間帯>" → Button（週のマス）
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
	# 候補のチップにある地域はチップで、それ以外（自由入力・ほかの町の地区）は入力欄に
	var chip_ids: Array = JobPrefs.areas().slice(0, 6)
	area_on = prefs.areas.filter(func(a): return a in chip_ids)
	area_edit.text = ", ".join(prefs.areas.filter(func(a): return not a in chip_ids).map(func(a): return JobPrefs.area_label(a)))
	var af := HFlowContainer.new()
	af.add_theme_constant_override("h_separation", 6)
	af.add_theme_constant_override("v_separation", 6)
	for a in chip_ids:
		var c := _chip(JobPrefs.area_label(a), func(): _toggle_area(a))
		area_chips[a] = c
		af.add_child(c)
	area_box.add_child(af)
	area_box.add_child(area_edit)

	# 週のマス（曜日 × 時間帯）。選んだマスは塗りとチェック、選んでいないマスは白と枠
	var week_box := _section(v, tr("PREFS_WEEK"))
	var g := GridContainer.new()
	g.columns = 8
	g.add_theme_constant_override("h_separation", 3)
	g.add_theme_constant_override("v_separation", 4)
	g.add_child(Control.new())
	for i in 7:
		var dh := _head(tr("JOB_WD_%d" % i), func(): _toggle_column(i))
		g.add_child(dh)
	for w in JobPrefs.WINDOW_ORDER:
		var wl := _head(tr("PREFS_WIN_S_" + w.to_upper()), func(): _toggle_row(w))
		wl.custom_minimum_size = Vector2(46, 34)
		g.add_child(wl)
		for i in 7:
			var key := "%d:%s" % [i, w]
			var c := _cell(func(): _toggle_slot(key))
			cells[key] = c
			g.add_child(c)
	week_box.add_child(g)
	week_box.add_child(I18n.wrap(Kit.text(tr("PREFS_WIN_HOURS"), 11, SUB)))

	# 最低時給
	var wage_box := _section(v, tr("PREFS_WAGE"))
	var wh := HBoxContainer.new()
	wh.add_theme_constant_override("separation", 8)
	wh.add_child(_round_btn("−", func(): _step_wage(-1)))
	wage_l = Kit.text("", 22, INK, true, HORIZONTAL_ALIGNMENT_CENTER)
	wage_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wh.add_child(wage_l)
	wh.add_child(_round_btn("+", func(): _step_wage(1)))
	wage_box.add_child(wh)
	wage_slider = HSlider.new()
	# 英語＝SF（US ドル、50 セント刻み）、日本語＝円（50 円刻み）
	wage_slider.min_value = JobPrefs.WAGE_MIN_USD if _usd() else JobPrefs.WAGE_MIN
	wage_slider.max_value = JobPrefs.WAGE_MAX_USD if _usd() else JobPrefs.WAGE_MAX
	wage_slider.step = JobPrefs.WAGE_STEP_USD if _usd() else 50
	wage_slider.value = _wage()
	wage_slider.value_changed.connect(func(x): _set_wage(x))
	wage_box.add_child(wage_slider)

	# 受け取り方の希望
	var pay_box := _section(v, tr("PREFS_PAY"))
	# 4 つを 1 行に。英語は語が長く（Biweekly pay など）1 行では 360 幅からはみ出すので、2 つずつ 2 行に
	var ph := GridContainer.new()
	ph.columns = 2 if Kit.is_en() else 4
	ph.add_theme_constant_override("h_separation", 6)
	ph.add_theme_constant_override("v_separation", 6)
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

	TouchScroll.enable(scroll) # まん中のボタンの上からでも、指でなぞってスクロール
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


## 週のマスの見出し（曜日・時間帯）。タップで、その列・その行をまとめて切りかえ
func _head(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.custom_minimum_size = Vector2(33, 26)
	b.add_theme_font_override("font", Kit.black())
	b.add_theme_font_size_override("font_size", 12)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, SUB)
	# 見出しは字だけ（ボタンの余白を 0 に：英語の Mon・Night などで列が広がり、カードが 360 幅からはみ出さないように）
	for k in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	b.pressed.connect(func():
		Kit.play(self, "tap", 1.1)
		cb.call())
	return b


## 週のマスひとつ。選んだらチェック（字ではなく線で描く。字形に ✓ が無いため）
func _cell(cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(33, 34)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func():
		Kit.play(self, "tap", 1.15)
		cb.call())
	var mark := Control.new()
	mark.name = "Check"
	mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.draw.connect(func():
		var c := mark.size / 2.0
		mark.draw_polyline(PackedVector2Array([c + Vector2(-7, 0), c + Vector2(-2, 5), c + Vector2(8, -6)]), Color.WHITE, 3.0, true))
	b.add_child(mark)
	return b


func _cell_style(b: Button, on: bool) -> void:
	for k in ["normal", "hover", "pressed"]:
		var st := StyleBoxFlat.new()
		st.set_corner_radius_all(9)
		if on:
			st.bg_color = LILAC if k != "pressed" else LILAC.darkened(0.08)
		else:
			st.bg_color = Color.WHITE if k != "pressed" else Color("f3ecff")
			st.border_color = Color("d9cfe0")
			st.set_border_width_all(2)
		b.add_theme_stylebox_override(k, st)
	b.get_node("Check").visible = on


func _round_btn(t: String, cb: Callable) -> Button:
	var b := Kit.button(t, Color("f3ecff"), cb, Color("6a5bd6"), 40, 20)
	b.custom_minimum_size = Vector2(48, 40)
	return b


func _toggle_slot(key: String) -> void:
	if prefs.slots.has(key):
		prefs.slots.erase(key)
	else:
		prefs.slots.append(key)
	_refresh()


## 列（曜日）をまとめて：全部ついていれば消す、そうでなければ全部つける
func _toggle_column(i: int) -> void:
	_toggle_many(JobPrefs.WINDOW_ORDER.map(func(w): return "%d:%s" % [i, w]))


func _toggle_row(w: String) -> void:
	_toggle_many(range(7).map(func(i): return "%d:%s" % [i, w]))


func _toggle_many(keys: Array) -> void:
	var all_on := keys.all(func(k): return prefs.slots.has(k))
	for k in keys:
		prefs.slots.erase(k)
		if not all_on:
			prefs.slots.append(k)
	_refresh()


func _usd() -> bool:
	return Money.current() == Money.USD


## 今の言語の町の最低時給（円 or ドル）
func _wage() -> float:
	return JobPrefs.min_wage_in(prefs, Money.current())


func _step_wage(d: int) -> void:
	_set_wage(_wage() + d * (JobPrefs.WAGE_STEP_USD if _usd() else 50.0))


func _set_wage(n: float) -> void:
	if _usd():
		prefs.min_wage_usd = clampf(snappedf(n, 0.25), JobPrefs.WAGE_MIN_USD, JobPrefs.WAGE_MAX_USD)
	else:
		prefs.min_wage = clampi(int(n), JobPrefs.WAGE_MIN, JobPrefs.WAGE_MAX)
	_refresh()


func _set_pay(p: String) -> void:
	prefs.pay = p
	_refresh()


func _set_suggest(on: bool) -> void:
	prefs.suggest = on
	Telemetry.track("suggestions_toggled", {"on": on})
	_refresh()


## 自分でシフトを入れる（入れたら相棒がよろこぶ）
func open_shift_form() -> void:
	var f := ShiftForm.new()
	f.added.connect(func(_s): stage.joy())
	f.see_shifts.connect(func(at: float):
		JobDesk.focus_shifts_at = at # マイシフトは島のしごとのシートにある
		main.go("garden"))
	add_child(f)


## 候補の地域のチップ：押すたびに入れる／外す（いくつでも）
func _toggle_area(a: String) -> void:
	if area_on.has(a):
		area_on.erase(a)
	else:
		area_on.append(a)
	_sync_area_chips()


func _sync_area_chips() -> void:
	for a in area_chips:
		_chip_style(area_chips[a], area_on.has(a))


func _refresh() -> void:
	for key in cells:
		_cell_style(cells[key], prefs.slots.has(key))
	for p in pay_chips:
		_chip_style(pay_chips[p], prefs.pay == p)
	for on in suggest_chips:
		_chip_style(suggest_chips[on], bool(prefs.suggest) == on)
	wage_l.text = Money.fmt_wage(_wage())
	if wage_slider and not is_equal_approx(wage_slider.value, _wage()):
		wage_slider.set_value_no_signal(_wage())
	var ok: bool = not prefs.slots.is_empty()
	if not prefs.suggest:
		ok = true # 知らせを受けないなら、曜日・時間帯は空でもよい
	go_btn.disabled = not ok
	go_btn.text = (tr("PREFS_GO") if prefs.suggest else tr("PREFS_SAVE")) if ok else tr("PREFS_NEED")


## 地域：えらんだチップ（候補の順）＋入力欄（「、」「,」で区切る）。候補の表示名と同じなら候補の ID で持つ（言語を変えても読める）
func _area_values() -> Array:
	var out: Array = JobPrefs.areas().filter(func(a): return area_on.has(a))
	for part in area_edit.text.replace("、", ",").replace("，", ",").split(","):
		var t := part.strip_edges()
		if t == "":
			continue
		for a in JobPrefs.AREAS + JobPrefs.AREAS_SF:
			if t == JobPrefs.area_label(a):
				t = a
		if not out.has(t):
			out.append(t)
	return out


func _save() -> void:
	prefs.areas = _area_values()
	prefs.area = prefs.areas[0] if not prefs.areas.is_empty() else ""
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
	area_on = [JobPrefs.areas()[0], JobPrefs.areas()[1]] if Kit.is_en() else ["shibuya", "shinjuku"]
	area_edit.text = ""
	_sync_area_chips()
	prefs.slots = JobPrefs.grid([0, 2, 4], ["day", "evening"]) + ["5:morning", "5:day"]
	prefs.min_wage = 1250
	prefs.min_wage_usd = 21.5
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
