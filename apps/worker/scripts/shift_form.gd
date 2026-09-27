class_name ShiftForm
extends Control
## 「自分でシフトを入れる」小さな入力（決まったバイトがある人も、同じ流れで遊べるように）。
## 仕事の名前・場所・日・はじまり・おわりだけ。時給やお金の情報は聞かない。
## 入れたら Shifts.add()（一緒に働く係・働いたあとの評価と同じ置き場）。時刻は見本の求人と同じ町の時刻（日本語＝日本時間、英語＝サンフランシスコ）。
## 使い方: var f := ShiftForm.new(); f.added.connect(...); add_child(f)（画面は 360x640 の固定座標）
## 求人を受けるときと同じく、もう入っているシフトと時間が重なるなら入れない（重なりの知らせと「マイシフトで見る ›」を出す）

signal added(shift: Dictionary)
signal closed
## 重なりの知らせの「マイシフトで見る ›」：at はその重なったシフトのはじまり（開く側がマイシフトのその日へ）
signal see_shifts(at: float)

const INK := Color("2a2233")
const SUB := Color("6a5f70")
const PAPER := Color(1, 0.99, 0.97, 0.98)
const ORANGE := Color("ff8a5b")
const LILAC := Color("6a5bd6")
const DAYS_AHEAD := 13 # 今日から 2 週間先まで
const STEP_MIN := 30

var title_edit: LineEdit
var place_edit: LineEdit
var day_l: Label
var start_l: Label
var end_l: Label
var add_btn: Button
var card: PanelContainer
var clash_box: VBoxContainer # 重なりの知らせ（重なったときだけ出す）

var day_off := 0 # 今日から何日後
var start_min := 17 * 60
var end_min := 21 * 60


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(360, 640)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.1, 0.2, 0.62)
	dim.size = Vector2(360, 640)
	add_child(dim)
	Kit.center_tall(self, dim) # 縦に長い島では、上下のまんなかに（暗幕は画面いっぱい）
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", Kit.pill(PAPER, 24, 0.2, Vector2(18, 14)))
	card.position = Vector2(16, 90)
	card.size = Vector2(328, 0)
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.custom_minimum_size = Vector2(292, 0)
	card.add_child(v)
	v.add_child(I18n.wrap(_text(tr("SHIFT_FORM_TITLE"), 19, INK, true)))
	v.add_child(I18n.wrap(_text(tr("SHIFT_FORM_SUB"), 12, SUB)))
	title_edit = _edit(tr("SHIFT_FORM_WHAT_PH"))
	title_edit.text_changed.connect(func(_t): _refresh())
	v.add_child(_label_row(tr("SHIFT_FORM_WHAT"), title_edit))
	place_edit = _edit(tr("SHIFT_FORM_WHERE_PH"))
	v.add_child(_label_row(tr("SHIFT_FORM_WHERE"), place_edit))
	day_l = _value_label()
	v.add_child(_stepper(tr("SHIFT_FORM_DAY"), day_l, func(d): _step_day(d)))
	start_l = _value_label()
	v.add_child(_stepper(tr("SHIFT_FORM_START"), start_l, func(d): _step_time("start", d)))
	end_l = _value_label()
	v.add_child(_stepper(tr("SHIFT_FORM_END"), end_l, func(d): _step_time("end", d)))
	clash_box = VBoxContainer.new()
	clash_box.add_theme_constant_override("separation", 2)
	clash_box.visible = false
	v.add_child(clash_box)
	add_btn = Kit.button(tr("SHIFT_FORM_ADD"), ORANGE, _add)
	v.add_child(add_btn)
	var cancel := Button.new()
	cancel.text = tr("SHIFT_FORM_CANCEL")
	cancel.flat = true
	cancel.custom_minimum_size = Vector2(0, 34)
	cancel.add_theme_font_override("font", Kit.bold())
	cancel.add_theme_font_size_override("font_size", 14)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		cancel.add_theme_color_override(k, SUB)
	cancel.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	cancel.pressed.connect(close)
	v.add_child(cancel)
	_refresh()


func _text(t: String, size: int, color := INK, heavy := false, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Kit.text(t, size, color, heavy, align)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _edit(ph: String) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = ph
	e.max_length = 40
	e.custom_minimum_size = Vector2(0, 38)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var st := Kit.pill(Color.WHITE, 12, 0.0, Vector2(10, 6))
	st.border_color = Color("e2d6c8")
	st.set_border_width_all(2)
	e.add_theme_stylebox_override("normal", st)
	var stf := st.duplicate() as StyleBoxFlat
	stf.border_color = ORANGE
	e.add_theme_stylebox_override("focus", stf)
	e.add_theme_color_override("font_color", INK)
	e.add_theme_color_override("font_placeholder_color", Color("a89ea6"))
	e.add_theme_font_override("font", Kit.bold())
	e.add_theme_font_size_override("font_size", 14)
	return e


func _label_row(label: String, field: Control) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", 2)
	b.add_child(_text(label, 12, SUB, true))
	b.add_child(field)
	return b


func _value_label() -> Label:
	var l := _text("", 16, INK, true, HORIZONTAL_ALIGNMENT_CENTER)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## 「はじまり  ‹ 17:00 ›」の一行
func _stepper(label: String, value: Label, cb: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var nl := _text(label, 12, SUB, true)
	nl.custom_minimum_size = Vector2(84, 0)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(nl)
	h.add_child(_round("‹", func(): cb.call(-1)))
	h.add_child(value)
	h.add_child(_round("›", func(): cb.call(1)))
	return h


func _round(t: String, cb: Callable) -> Button:
	var b := Kit.button(t, Color("f3ecff"), cb, LILAC, 36, 20)
	b.custom_minimum_size = Vector2(44, 36)
	return b


func _step_day(d: int) -> void:
	day_off = clampi(day_off + d, 0, DAYS_AHEAD)
	_refresh()


func _step_time(which: String, d: int) -> void:
	if which == "start":
		start_min = posmod(start_min + d * STEP_MIN, 24 * 60)
	else:
		end_min = posmod(end_min + d * STEP_MIN, 24 * 60)
	_refresh()


## 見本の町（今の言語）の、今日から day_off 日後の 0 時（unix 秒）
func _day_start() -> int:
	return JobListings.next_day0(JobListings.day0(Time.get_unix_time_from_system()), day_off)


## 入力から Shifts の 1 件を作る。おわりがはじまり以前なら、日をまたぐ（夜勤）
func build_shift() -> Dictionary:
	var start := JobListings.at_hour(_day_start(), start_min / 60.0)
	var mins := end_min - start_min
	if mins <= 0:
		mins += 24 * 60
	var title := title_edit.text.strip_edges()
	var place := place_edit.text.strip_edges()
	return {"title": title, "place": place, "store": place if place != "" else title, "role": _role(),
		"start": start, "end": start + mins * 60, "manual": true, "tz": JobListings.tz_of_region()}


## 仕事の種類は聞かない（入力を増やさない）。一緒に働く職場とポイの種類は、相棒の向いてる仕事で
func _role() -> String:
	var gs := get_node_or_null("/root/GameState")
	var tid: String = gs.my_obake.get("type_id", "") if gs else ""
	return QuizData.TYPES[tid].job if QuizData.TYPES.has(tid) else "hall"


func _refresh() -> void:
	var s := build_shift()
	var wd := JobListings.weekday_mon(s.start)
	var d := JobListings.local(s.start)
	day_l.text = tr("SHIFT_FORM_DATE") % [tr("JOB_WD_%d" % wd), d.month, d.day]
	start_l.text = "%02d:%02d" % [start_min / 60, start_min % 60]
	var over := end_min <= start_min
	end_l.text = ("%02d:%02d" % [end_min / 60, end_min % 60]) + (tr("SHIFT_FORM_NEXT_DAY") if over else "")
	add_btn.disabled = title_edit.text.strip_edges() == ""
	_hide_clash() # 日や時刻を変えたら、前の重なりの知らせは消す


func _add() -> void:
	if add_btn.disabled:
		return
	var s := build_shift()
	# もう入っているシフトと時間が重なるなら入れない（求人を受けるときと同じ決まり・同じ知らせ）
	var clash := Shifts.overlapping(s)
	if not clash.is_empty():
		_show_clash(clash)
		return
	Shifts.add(s)
	Kit.play(self, "sparkle")
	added.emit(s)
	close()


func close() -> void:
	closed.emit()
	queue_free()


## 重なりの知らせ：求人を受けるときと同じ文（時間がかぶってるよ／〜と時間が重なるから…）と、マイシフトへのリンク
func _show_clash(clash: Dictionary) -> void:
	_hide_clash()
	Kit.play(self, "tap", 0.8)
	clash_box.add_child(I18n.wrap(_text(tr("R3_OVERLAP_TITLE"), 15, Color("b0502a"), true)))
	# JobDesk は GameState（autoload）を使うので、名前で参照せず実行時に読む（-s のテストでも ShiftForm を読めるように）
	var jd: GDScript = load("res://scripts/job_desk.gd")
	clash_box.add_child(I18n.wrap(_text(tr("R3_OVERLAP_BODY") % jd.shift_label(clash), 13, INK)))
	var link := Button.new()
	link.text = tr("R3_SEE_MY_SHIFTS")
	link.flat = true
	link.alignment = HORIZONTAL_ALIGNMENT_LEFT
	link.custom_minimum_size = Vector2(0, 26)
	link.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	link.add_theme_font_override("font", Kit.bold())
	link.add_theme_font_size_override("font_size", 12)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		link.add_theme_color_override(k, Color("3b5ba5"))
	link.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var at := float(clash.start)
	link.pressed.connect(func():
		Kit.play(self, "tap", 1.1)
		see_shifts.emit(at)
		close())
	clash_box.add_child(link)
	clash_box.visible = true


func _hide_clash() -> void:
	if clash_box == null:
		return
	for c in clash_box.get_children():
		clash_box.remove_child(c)
		c.queue_free()
	clash_box.visible = false


# ---------------------------------------------------------------- 確認用（OBAKE_SHOT の call:）

func demo_fill() -> void:
	title_edit.text = tr("SHIFT_FORM_DEMO_TITLE")
	place_edit.text = tr("SHIFT_FORM_DEMO_PLACE")
	day_off = 1
	start_min = 18 * 60
	end_min = 22 * 60
	_refresh()
