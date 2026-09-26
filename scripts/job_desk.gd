class_name JobDesk
extends Control
## 島（screen_garden）の上に重ねる、相棒の「仕事の知らせ」係。庭の画面からは add_child(JobDesk.new()) の1行だけで入る。
##   Onboarding "island" … 島の育ち方の説明（ひとつずつ）→ 働く条件の入力へ
##   Onboarding "found"  … 相棒が条件に合う仕事を見つけて、知らせのカードが相棒のところから飛んでくる
##   それ以降（毎日）     … 働き終えたシフトがあれば、まず職場のひとこと評価。つぎに今日の求人 3〜4 件の知らせ
## 求人は見本（JobListings、MOCK）。受けたら Shifts.add()（一緒に働く係と共有する唯一の約束）と、カレンダーに入れる選択肢。
## 今日の求人の顔ぶれは user://job_board.json（{key, jobs, decided}）。key はゲームの日と、日本時間の日付。

const BOARD_PATH := "user://job_board.json"
const INK := Color("2a2233")
const SUB := Color("6a5f70")
const PAPER := Color(1, 0.99, 0.97, 0.98)
const ORANGE := Color("ff8a5b")
const GREEN := Color("3f8a55")

var garden: Control
var notes: Array = []
var sheet: PanelContainer
var viewer: Control
var stage: PartnerStage
var bubble_l: Label
var card: PanelContainer
var card_box: VBoxContainer
var jobs: Array = []
var index := 0
var accepted := 0
var busy := false


func _ready() -> void:
	# 画面は 360x640 固定の座標で組む（庭の画面と同じ作法。アンカー任せだと大きさ 0 になることがある）
	position = Vector2.ZERO
	size = Vector2(360, 640)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	garden = get_parent() as Control
	_start.call_deferred()


func _start() -> void:
	match Onboarding.step():
		"island":
			_island_tour()
		"prefs":
			_go("prefs")
		"found":
			_found_jobs()
		"done":
			_daily()


func _go(screen: String) -> void:
	var m = garden.get("main")
	if m:
		m.go(screen)


## 庭のカード（昼・夜の予定）を隠す／戻す
func _garden_card(show: bool) -> void:
	for k in ["card", "handle"]:
		var c = garden.get(k)
		if c and is_instance_valid(c):
			c.visible = show


# ---------------------------------------------------------------- 今日の求人（保存）

static func today_key() -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + JobListings.JST)
	return "%d-%04d%02d%02d" % [GameState.day, d.year, d.month, d.day]


static func _load_board() -> Dictionary:
	if OS.get_environment("OBAKE_NOSAVE") == "" and FileAccess.file_exists(BOARD_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(BOARD_PATH))
		if d is Dictionary:
			return d
	return {}


static func _save_board(b: Dictionary) -> void:
	if OS.get_environment("OBAKE_NOSAVE") != "":
		return
	var f := FileAccess.open(BOARD_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(b))


static var _board := {}


## 今日の 3〜4 件（無ければ条件から作る）
static func today_jobs() -> Array:
	var key := today_key()
	if _board.is_empty():
		_board = _load_board()
	if _board.get("key", "") != key:
		var n := 3 + (hash(key) % 2)
		_board = {"key": key, "jobs": JobListings.generate(JobPrefs.load_prefs(), n, hash(key)), "decided": {}}
		_save_board(_board)
	# 表示の言語に合わせて、名前と相棒のひとことを入れ直す
	for j in _board.jobs:
		JobListings.localize(j)
	return _board.jobs


static func undecided() -> Array:
	var dec: Dictionary = _board.get("decided", {})
	return today_jobs().filter(func(j): return not dec.has(j.id))


static func decide(job_id: String, what: String) -> void:
	today_jobs()
	_board.decided[job_id] = what
	_save_board(_board)


static func clear_today() -> void:
	_board = {}
	if FileAccess.file_exists(BOARD_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BOARD_PATH))


# ---------------------------------------------------------------- 部品

func _text(t: String, size: int, color := INK, heavy := false, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Kit.text(t, size, color, heavy, align)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _link(t: String, cb: Callable, color := SUB) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.custom_minimum_size = Vector2(0, 36)
	b.add_theme_font_override("font", Kit.bold())
	b.add_theme_font_size_override("font_size", 14)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, color)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func():
		Kit.play(self, "tap", 1.1)
		cb.call())
	return b


func _chip(t: String, bg: Color, fg := Color.WHITE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(bg, 11, 0.0, Vector2(9, 2)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(_text(t, 11, fg, true))
	return p


## 下からの説明シート（島の説明・見つけた知らせ）。主ボタンはひとつ
func _sheet(who: String, title: String, body: String, btn: String, cb: Callable, dots := -1, of := 0) -> void:
	if sheet and is_instance_valid(sheet):
		sheet.queue_free()
	sheet = PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", Kit.pill(PAPER, 24, 0.18, Vector2(16, 14)))
	sheet.position = Vector2(14, 420)
	sheet.size = Vector2(332, 0)
	add_child(sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size = Vector2(300, 0)
	sheet.add_child(v)
	var top := HBoxContainer.new()
	top.add_child(_text(who, 12, Color("8a5bd6"), true))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	if dots > 0:
		top.add_child(_text("%d / %d" % [dots, of], 12, SUB, true))
	v.add_child(top)
	v.add_child(I18n.wrap(_text(title, 19, INK, true)))
	v.add_child(I18n.wrap(_text(body, 14, SUB)))
	var b := Kit.button(btn, ORANGE, cb)
	v.add_child(b)
	await get_tree().process_frame
	if not is_instance_valid(sheet):
		return
	sheet.size.y = 0
	await get_tree().process_frame
	if not is_instance_valid(sheet):
		return
	sheet.position.y = 626 - sheet.size.y
	var y := sheet.position.y
	sheet.position.y = 660
	create_tween().tween_property(sheet, "position:y", y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Kit.nudge(b)


## 相棒の、画面の上での位置（知らせのカードはここから飛んでくる）
func _partner_screen_pos() -> Vector2:
	var host = garden.get("host_node")
	var cam = garden.get("cam")
	if host and cam and is_instance_valid(host) and host.is_inside_tree():
		return (cam as Camera3D).unproject_position((host as Node3D).global_position + Vector3(0, 0.9, 0))
	return Vector2(180, 300)


## 相棒のところから、知らせのカードがすべり出る
func _notify(i: int, title: String, sub: String, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(328, 54)
	b.size = Vector2(328, 54)
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, Kit.pill(Color(1, 1, 1, 0.97) if k != "pressed" else Color("fff1e0"), 18, 0.18, Vector2(10, 6)))
	b.pressed.connect(func():
		Kit.play(self, "tap", 1.1)
		cb.call())
	add_child(b)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -10
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(30, 30)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ds := StyleBoxFlat.new()
	ds.bg_color = col
	ds.set_corner_radius_all(15)
	dot.add_theme_stylebox_override("panel", ds)
	h.add_child(dot)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tl := _text(title, 14, INK, true)
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tl.clip_text = true
	v.add_child(tl)
	var sl := _text(sub, 12, SUB)
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sl.clip_text = true
	v.add_child(sl)
	h.add_child(v)
	# 相棒の位置から、小さく出て、上の段へ
	var from := _partner_screen_pos() - Vector2(164, 27)
	var to := Vector2(16, 62 + i * 62)
	b.position = from
	b.pivot_offset = Vector2(164, 27)
	b.scale = Vector2(0.2, 0.2)
	b.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(b, "position", to, 0.5).set_delay(i * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2.ONE, 0.45).set_delay(i * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "modulate:a", 1.0, 0.2).set_delay(i * 0.35)
	tw.tween_callback(func(): Kit.play(self, "pop", 1.0 + i * 0.1, -4)).set_delay(i * 0.35)
	notes.append(b)
	return b


func _clear_notes() -> void:
	for n in notes:
		if is_instance_valid(n):
			n.queue_free()
	notes.clear()


static func role_color(role: String) -> Color:
	return GameState.TYPE_COLOR.get(role, Color("ffd84d"))


# ---------------------------------------------------------------- 島の説明（はじめての流れ）

var tour_i := 0


func _island_tour() -> void:
	_garden_card(false)
	tour_i = 0
	_tour_step()


func _tour_step() -> void:
	var pet := SpecialObake.pet_name()
	var n := 4
	tour_i += 1
	match tour_i:
		1:
			_sheet(pet, tr("TOUR_1_TITLE"), tr("TOUR_1_BODY") % pet, tr("TOUR_NEXT"), _tour_step, 1, n)
		2:
			_sheet(pet, tr("TOUR_2_TITLE"), tr("TOUR_2_BODY"), tr("TOUR_NEXT"), _tour_step, 2, n)
		3:
			_sheet(pet, tr("TOUR_3_TITLE"), tr("TOUR_3_BODY"), tr("TOUR_NEXT"), _tour_step, 3, n)
		4:
			_sheet(pet, tr("TOUR_4_TITLE") % Wallet.balance(), tr("TOUR_4_BODY") % pet, tr("TOUR_TO_PREFS") % pet, func():
				Onboarding.advance("prefs")
				_go("prefs"), 4, n)


# ---------------------------------------------------------------- 見つけた！（条件を入れた直後）

func _found_jobs() -> void:
	_garden_card(false)
	await get_tree().create_timer(0.8).timeout
	if viewer:
		return
	var list := today_jobs()
	var pet := SpecialObake.pet_name()
	if list.is_empty():
		_sheet(pet, tr("FOUND_NONE_TITLE"), tr("FOUND_NONE_BODY"), tr("FOUND_EDIT"), func(): _go("prefs"))
		return
	for i in mini(3, list.size()):
		var j: Dictionary = list[i]
		_notify(i, tr("NOTE_MATCH") % j.title, "%s · %s" % [JobListings.wage_text(j), j.store], role_color(j.role), _open_viewer)
	await get_tree().create_timer(0.35 * mini(3, list.size()) + 0.4).timeout
	if viewer:
		return
	_sheet(pet, tr("FOUND_TITLE") % [pet, list.size()], tr("FOUND_BODY"), tr("FOUND_SEE"), _open_viewer)


# ---------------------------------------------------------------- 毎日

func _daily() -> void:
	var rev := Reviews.pending()
	if not rev.is_empty():
		var s: Dictionary = rev[0]
		_notify(0, tr("NOTE_REVIEW") % String(s.get("store", s.get("place", ""))), tr("NOTE_REVIEW_SUB"), Color("ffd23f"), func(): _open_review(s))
		return
	var left := undecided()
	if left.is_empty():
		return
	_notify(0, tr("NOTE_DAILY") % [SpecialObake.pet_name(), left.size()], tr("NOTE_DAILY_SUB") % JobListings.wage_text(left[0]), role_color(left[0].role), _open_viewer)


# ---------------------------------------------------------------- 求人カード（1 件ずつ）

func _build_viewer() -> void:
	_clear_notes()
	if sheet and is_instance_valid(sheet):
		sheet.queue_free()
	_garden_card(false)
	viewer = Control.new()
	viewer.size = Vector2(360, 640)
	viewer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(viewer)
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.1, 0.2, 0.62)
	dim.size = Vector2(360, 640)
	viewer.add_child(dim)
	stage = PartnerStage.new(Vector2(170, 150))
	stage.position = Vector2(95, 18)
	viewer.add_child(stage)
	var bub := PanelContainer.new()
	bub.add_theme_stylebox_override("panel", Kit.pill(Color("fffaf2"), 16, 0.14, Vector2(12, 6)))
	bub.position = Vector2(30, 166)
	bub.size = Vector2(300, 0)
	bub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_l = I18n.wrap(_text("", 14, INK, true, HORIZONTAL_ALIGNMENT_CENTER))
	bubble_l.custom_minimum_size = Vector2(276, 0)
	bub.add_child(bubble_l)
	viewer.add_child(bub)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", Kit.pill(PAPER, 24, 0.2, Vector2(18, 14)))
	card.position = Vector2(16, 222)
	card.size = Vector2(328, 0)
	viewer.add_child(card)
	card_box = VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 6)
	card_box.custom_minimum_size = Vector2(292, 0) # 折り返すラベルが幅 0 で縦に伸びないように
	card.add_child(card_box)
	var note := _text(tr("JOB_SAMPLE_NOTE"), 11, Color(1, 1, 1, 0.75), false, HORIZONTAL_ALIGNMENT_CENTER)
	note.position = Vector2(0, 614)
	note.size = Vector2(360, 18)
	viewer.add_child(note)


func _say(t: String) -> void:
	bubble_l.text = t
	var bub := bubble_l.get_parent() as Control
	_fit(bub)
	bub.pivot_offset = Vector2(150, 16)
	bub.scale = Vector2(0.9, 0.9)
	create_tween().tween_property(bub, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _open_viewer() -> void:
	if viewer:
		return
	if Onboarding.at("found"):
		Onboarding.advance("done")
	jobs = undecided()
	index = 0
	accepted = 0
	_build_viewer()
	_show_job()


func _clear_card() -> void:
	for c in card_box.get_children():
		c.queue_free()


## 折り返しの高さが決まってから、中身に合わせて縮める（2 フレーム待つ。庭の _card_fit と同じ）
func _fit(p: Control) -> void:
	for i in 2:
		await get_tree().process_frame
		if is_instance_valid(p):
			p.size.y = 0


func _pop_card() -> void:
	_fit(card)
	card.pivot_offset = Vector2(164, 120)
	card.scale = Vector2(0.95, 0.95)
	card.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(card, "modulate:a", 1.0, 0.18)


func _show_job() -> void:
	_clear_card()
	if index >= jobs.size():
		_show_end()
		return
	var j: Dictionary = jobs[index]
	_say(j.line)
	stage.talk()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.add_child(_chip(tr("JOB_ROLE_" + String(j.role).to_upper()), role_color(j.role).darkened(0.25)))
	top.add_child(_chip(tr("JOB_PAY_" + String(j.pay).to_upper()), Color("e9f3ea"), GREEN))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	top.add_child(_text(tr("JOB_COUNT") % [index + 1, jobs.size()], 12, SUB, true))
	card_box.add_child(top)
	card_box.add_child(I18n.wrap(_text(j.title, 21, INK, true)))
	card_box.add_child(I18n.wrap(_text(j.place, 14, SUB)))
	var row := HBoxContainer.new()
	row.add_child(_text(JobListings.when_text(j), 15, INK, true))
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp2)
	row.add_child(_text(JobListings.wage_text(j), 20, Color("e0663a"), true))
	card_box.add_child(row)
	# 働いた人の声（見本の集計＋自分の評価）
	var voice := PanelContainer.new()
	voice.add_theme_stylebox_override("panel", Kit.pill(Color("f1f7f1"), 12, 0.0, Vector2(10, 5)))
	voice.add_child(I18n.wrap(_text(Reviews.summary_text(j.listing), 12, GREEN, true)))
	card_box.add_child(voice)
	var acc := Kit.button(tr("JOB_ACCEPT"), ORANGE, _accept)
	card_box.add_child(acc)
	card_box.add_child(_link(tr("JOB_PASS"), _pass))
	_pop_card()


func _accept() -> void:
	if busy:
		return
	busy = true
	var j: Dictionary = jobs[index]
	# 一緒に働く係と共有する約束：Shifts の 1 件の形
	var s := {"id": j.id, "title": j.title, "place": j.place, "store": j.store, "role": j.role, "start": j.start, "end": j.end,
		"wage": j.wage, "pay": j.pay, "listing": j.listing, "sample": true}
	Shifts.add(s)
	decide(j.id, "accept")
	accepted += 1
	stage.joy()
	Kit.play(self, "sparkle")
	Kit.play(self, "chime", 1.1, -4)
	_say(tr("JOY_%d" % (accepted % 3 + 1)))
	_clear_card()
	card_box.add_child(_text(tr("JOB_ADDED"), 18, GREEN, true))
	card_box.add_child(I18n.wrap(_text("%s · %s" % [j.title, j.store], 14, INK, true)))
	card_box.add_child(_text(JobListings.when_text(j), 14, SUB))
	var cal := Kit.button(tr("CAL_GOOGLE"), Color("eef3ff"), func(): CalendarLink.open_google(s), Color("3b5ba5"), 44, 15)
	card_box.add_child(cal)
	var status := I18n.wrap(_text("", 11, SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
	card_box.add_child(_link(tr("CAL_ICS"), func(): status.text = CalendarLink.save_ics(s), Color("3b5ba5")))
	card_box.add_child(status)
	index += 1
	card_box.add_child(Kit.button(tr("JOB_NEXT") if index < jobs.size() else tr("JOB_DONE"), ORANGE, _next))
	_pop_card()
	busy = false


func _pass() -> void:
	if busy:
		return
	busy = true
	var j: Dictionary = jobs[index]
	decide(j.id, "pass")
	stage.shrug()
	_say(tr("SHRUG_%d" % (index % 2 + 1)))
	var tw := create_tween().set_parallel()
	tw.tween_property(card, "position:x", -360.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	card.position.x = 16
	index += 1
	busy = false
	_show_job()


func _next() -> void:
	_show_job()


func _show_end() -> void:
	_clear_card()
	var pet := SpecialObake.pet_name()
	_say(tr("END_SAY") if accepted > 0 else tr("END_SAY_NONE"))
	card_box.add_child(_text(tr("END_TITLE"), 20, INK, true))
	card_box.add_child(I18n.wrap(_text(tr("END_BODY") % [accepted, pet] if accepted > 0 else tr("END_BODY_NONE") % pet, 14, SUB)))
	card_box.add_child(Kit.button(tr("END_BACK"), ORANGE, _close_viewer))
	card_box.add_child(_link(tr("END_EDIT"), func(): _go("prefs")))
	_pop_card()


func _close_viewer() -> void:
	if viewer:
		viewer.queue_free()
		viewer = null
	_garden_card(true)


# ---------------------------------------------------------------- 働いたあとの、ひとこと評価（10 秒）

var rv_stars := 0
var rv_tags := {}
var rv_star_btns: Array[Button] = []
var rv_send: Button


var rv_shift := {}


func _open_review(s: Dictionary) -> void:
	if viewer:
		return
	rv_shift = s
	_build_viewer()
	rv_stars = 0
	rv_tags = {}
	rv_star_btns.clear()
	_say(tr("REVIEW_ASK") % String(s.get("store", s.get("place", ""))))
	card_box.add_child(_text(tr("REVIEW_TITLE"), 18, INK, true))
	card_box.add_child(_text(tr("REVIEW_WHY"), 12, SUB))
	var sr := HBoxContainer.new()
	sr.alignment = BoxContainer.ALIGNMENT_CENTER
	sr.add_theme_constant_override("separation", 4)
	for i in 5:
		var b := Button.new()
		b.text = "★"
		b.flat = true
		b.custom_minimum_size = Vector2(48, 46)
		b.add_theme_font_override("font", Kit.black())
		b.add_theme_font_size_override("font_size", 34)
		b.pressed.connect(func():
			Kit.play(self, "tap", 1.0 + i * 0.08)
			rv_stars = i + 1
			_review_refresh())
		sr.add_child(b)
		rv_star_btns.append(b)
	card_box.add_child(sr)
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	for tg in Reviews.TAGS:
		var c := Button.new()
		c.text = tr("REVIEW_TAG_" + tg.to_upper())
		c.custom_minimum_size = Vector2(0, 32)
		c.add_theme_font_override("font", Kit.black())
		c.add_theme_font_size_override("font_size", 12)
		c.set_meta("tag", tg)
		c.pressed.connect(func():
			Kit.play(self, "tap", 1.1)
			rv_tags[tg] = not rv_tags.get(tg, false)
			_review_refresh())
		flow.add_child(c)
	card_box.add_child(flow)
	rv_send = Kit.button(tr("REVIEW_SEND") % Reviews.BONUS_POI, ORANGE, func(): _send_review(s))
	card_box.add_child(rv_send)
	card_box.add_child(_link(tr("REVIEW_SKIP"), func():
		Reviews.skip(s)
		_close_viewer()
		_daily()))
	_review_refresh()
	_pop_card()


func _review_refresh() -> void:
	for i in rv_star_btns.size():
		var on := i < rv_stars
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			rv_star_btns[i].add_theme_color_override(k, Color("ffb42e") if on else Color("e2d9e6"))
	for c in card_box.get_children():
		if c is HFlowContainer:
			for b: Button in c.get_children():
				var on: bool = rv_tags.get(b.get_meta("tag"), false)
				for k in ["normal", "hover", "pressed", "focus"]:
					b.add_theme_stylebox_override(k, Kit.pill(Color("8b7bff") if on else Color("f3ecff"), 16, 0.0, Vector2(10, 3)))
				for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
					b.add_theme_color_override(k, Color.WHITE if on else Color("6a5bd6"))
	rv_send.disabled = rv_stars == 0


func _send_review(s: Dictionary) -> void:
	if rv_stars == 0 or busy:
		return
	busy = true
	var tags: Array = []
	for tg in rv_tags:
		if rv_tags[tg]:
			tags.append(tg)
	Reviews.add(s, rv_stars, tags)
	# ごほうびはポイ（すくいの網）。働いた時間とは関係なく、1 回 1 本
	GameState.nets["plain"] = GameState.nets.get("plain", 0) + Reviews.BONUS_POI
	GameState.save()
	stage.joy()
	Kit.play(self, "sparkle")
	_say(tr("REVIEW_THANKS") % Reviews.BONUS_POI)
	_clear_card()
	card_box.add_child(_text(tr("REVIEW_DONE"), 18, GREEN, true, HORIZONTAL_ALIGNMENT_CENTER))
	card_box.add_child(I18n.wrap(_text(tr("REVIEW_DONE_BODY"), 13, SUB, false, HORIZONTAL_ALIGNMENT_CENTER)))
	card_box.add_child(Kit.button(tr("TOUR_NEXT"), ORANGE, func():
		_close_viewer()
		_daily()))
	_pop_card()
	busy = false


# ---------------------------------------------------------------- 確認用（OBAKE_SHOT の call:）

func demo_open() -> void:
	_open_viewer()


func demo_accept() -> void:
	_accept()


func demo_pass() -> void:
	_pass()


func demo_review() -> void:
	# 終わったばかりの見本のシフトを1件入れて、評価を開く
	var now := Time.get_unix_time_from_system()
	var e: Array = JobListings.LIST[0]
	var s := {"id": "demo_review", "title": I18n.t("JOB_TITLE_REGISTER"), "store": e[1], "place": "%s (%s)" % [e[1], JobPrefs.area_label("shibuya")],
		"role": "register", "start": now - 5 * 3600, "end": now - 3600, "wage": 1200, "pay": "weekly", "listing": e[0], "sample": true}
	if not Reviews.is_reviewed("demo_review"):
		Shifts.add(s)
	_clear_notes()
	_open_review(s)


func demo_send() -> void:
	_send_review(rv_shift)


func demo_stars() -> void:
	rv_stars = 4
	rv_tags = {"breaks": true, "friendly": true, "again": true}
	_review_refresh()
