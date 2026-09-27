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
var note_top := 62 # 知らせのカードの段（島の上の段・状態の札と丸いボタンの下）
var note_queue: Array = [] # まだ出していない知らせ（知らせは一度に 1 枚。押すか、重ね画面が閉じたら次）
var onboard_end := false # はじめての流れの最後（見つけた仕事）を見ているところ


func _ready() -> void:
	# 画面は 360 幅の固定座標で組む（庭の画面と同じ作法。アンカー任せだと大きさ 0 になることがある）。
	# 高さは島の高さ（縦に長い端末では 640 より大きい）。シートは下に、求人カードは上下のまんなかに
	position = Vector2.ZERO
	size = Vector2(360, _h())
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
			if not focus_job.is_empty():
				_open_focus()
			elif focus_shifts_at >= 0:
				var at := focus_shifts_at
				focus_shifts_at = -1.0
				open_work_menu(at)


## 島の上に、この係の何かが開いているか（シート・吹き出し・求人カード／評価・シフトの入力・チャット）。島の札を隠すのに使う
func overlay_open() -> bool:
	for n in [sheet, speech, viewer]:
		if n and is_instance_valid(n) and not n.is_queued_for_deletion():
			return true
	for c in get_children():
		if (c is ShiftForm or c is ScreenChat) and not c.is_queued_for_deletion():
			return true
	return false


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

## 島の高さ（縦に長い端末では 640 より大きい）と、シートの下端
func _h() -> float:
	return maxf(640.0, garden.size.y) if garden else 640.0


func _bottom() -> float:
	return _h() - 14.0


static func today_key() -> String:
	# 町（言語）が変われば、その町の求人に作り直す
	var d := JobListings.local(Time.get_unix_time_from_system())
	return "%d-%04d%02d%02d-%s" % [GameState.day, d.year, d.month, d.day, JobListings.region()]


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
	var list := today_jobs() # 先に今日の顔ぶれ（保存）を読む。開き直した直後は _board が空
	var dec: Dictionary = _board.get("decided", {})
	return list.filter(func(j): return not dec.has(j.id))


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
## extra は本文の下（例: 曜日のカード）、after は主ボタンの下（例: ほかの選択肢）に入る
func _sheet(who: String, title: String, body: String, btn: String, cb: Callable, dots := -1, of := 0, links: Array = [], extra: Control = null, after: Control = null) -> void:
	if sheet and is_instance_valid(sheet):
		sheet.queue_free()
	sheet = PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", Kit.pill(PAPER, 24, 0.18, Vector2(16, 14)))
	sheet.position = Vector2(14, _h() + 20.0) # 画面の下から。高さが決まったら _sheet_fit で下にそろえる
	sheet.size = Vector2(332, 0)
	add_child(sheet)
	# 画面より高くならないように（長い文でも、ボタンが画面の外へ出ない。はみ出す分はスクロール）
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(300, 0)
	TouchScroll.enable(sc)
	sheet.add_child(sc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	var top := HBoxContainer.new()
	top.add_child(_text(who, 12, Color("8a5bd6"), true))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	if dots > 0:
		top.add_child(_text("%d / %d" % [dots, of], 12, SUB, true))
	v.add_child(top)
	v.add_child(I18n.wrap(_text(title, 19, INK, true)))
	if body != "":
		v.add_child(I18n.wrap(_text(body, 14, SUB)))
	if extra:
		v.add_child(extra)
	var b := Kit.button(btn, ORANGE, cb)
	v.add_child(b)
	if after:
		v.add_child(after)
	for l in links: # [文字, Callable] の小さなリンク
		v.add_child(_link(l[0], l[1]))
	var s := sheet
	Kit.keep_fit(v, func(): _sheet_fit(s, sc, v))
	await get_tree().process_frame
	if is_instance_valid(b):
		Kit.nudge(b)


const SHEET_MAX_H := 600.0
var sheet_tw: Tween


## シートを中身の高さに縮めて、下（_bottom）にそろえる。中身の高さが変わるたびに呼ばれる（Kit.keep_fit）
func _sheet_fit(s: PanelContainer, sc: ScrollContainer, v: Control) -> void:
	if s != sheet or s.is_queued_for_deletion():
		return
	var pad := s.get_theme_stylebox("panel").get_minimum_size().y
	sc.custom_minimum_size.y = minf(v.get_combined_minimum_size().y, SHEET_MAX_H - pad)
	s.size = Vector2(332, 0)
	var y := _bottom() - s.size.y
	if is_equal_approx(s.position.y, y):
		return
	if sheet_tw:
		sheet_tw.kill()
	sheet_tw = create_tween()
	sheet_tw.tween_property(s, "position:y", y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## 相棒の、画面の上での位置（知らせのカードはここから飛んでくる）
func _partner_screen_pos() -> Vector2:
	var host = garden.get("host_node")
	var cam = garden.get("cam")
	if host and cam and is_instance_valid(host) and host.is_inside_tree():
		return View3D.unproject(cam as Camera3D, (host as Node3D).global_position + Vector3(0, 0.9, 0))
	return Vector2(180, 300)


## 相棒のところから、知らせのカードがすべり出る。出ているカードがあれば、順番を待つ（一度に 1 枚）
func _notify(i: int, title: String, sub: String, col: Color, cb: Callable) -> Button:
	if _live_notes() > 0 or i > 0:
		note_queue.append([title, sub, col, cb])
		_sync_note_count()
		return null
	var b := Button.new()
	b.custom_minimum_size = Vector2(328, 54)
	b.size = Vector2(328, 54)
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, Kit.pill(Color(1, 1, 1, 0.97) if k != "pressed" else Color("fff1e0"), 18, 0.18, Vector2(10, 6)))
	b.pressed.connect(func():
		Kit.play(self, "tap", 1.1)
		notes.erase(b)
		b.queue_free()
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
	# あと何枚待っているか（+2 など）
	var more := _text("", 11, Color("8a5bd6"), true)
	more.name = "More"
	more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(more)
	# 相棒の位置から、小さく出て、上の段へ
	var from := _partner_screen_pos() - Vector2(164, 27)
	var to := Vector2(16, note_top)
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
	_sync_note_count.call_deferred()
	return b


func _live_notes() -> int:
	notes = notes.filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion())
	return notes.size()


func _sync_note_count() -> void:
	for n in notes:
		if is_instance_valid(n):
			var m := n.find_child("More", true, false) as Label
			if m:
				m.text = "+%d" % note_queue.size() if not note_queue.is_empty() else ""


## 待っている知らせを、1 枚ずつ（島の上に何も開いていないとき）。何か開いている間（シート・チャット・くわしく・めあて・島づくり）は、出ている知らせも隠す
func _process(_delta: float) -> void:
	if size.y != _h(): # 島の高さに合わせる（縦に長い端末。島の大きさは、この係が入ったあとで決まることがある）
		size = Vector2(360, _h())
	var covered: bool = overlay_open() or garden.overlay_open() or garden.get("editing") or garden.get("cam_hold") \
		or (garden.get("meters") != null and garden.meters.visible) or garden.get("goals_panel") != null
	for n in notes:
		if is_instance_valid(n) and n.visible == covered:
			n.visible = not covered
	if note_queue.is_empty() or _live_notes() > 0 or overlay_open() or garden.get("editing") or garden.get("cam_hold"):
		return
	var n: Array = note_queue.pop_front()
	_notify(0, n[0], n[1], n[2], n[3])


func _clear_notes() -> void:
	for n in notes:
		if is_instance_valid(n):
			n.queue_free()
	notes.clear()
	note_queue.clear()


static func role_color(role: String) -> Color:
	return GameState.TYPE_COLOR.get(role, Color("ffd84d"))


# ---------------------------------------------------------------- 島の説明（はじめての流れ）

var tour_i := 0


func _island_tour() -> void:
	_garden_card(false)
	tour_i = 0
	_tour_step()


## 4 枚の順番（レビュー3：1 枚にひとつのこと、2 行まで）：① 仕事を見つけてくる ② 働くとポイ ③ ポイで玉をすくう ④ 材料とコインで島を育てる
func _tour_step() -> void:
	var pet := SpecialObake.pet_name()
	var n := 4
	tour_i += 1
	match tour_i:
		1:
			_sheet(pet, tr("R2_TOUR_1_TITLE") % pet, tr("R2_TOUR_1_BODY"), tr("TOUR_NEXT"), _tour_step, 1, n)
		2:
			_sheet(pet, tr("R2_TOUR_2_TITLE"), tr("R2_TOUR_2_BODY"), tr("TOUR_NEXT"), _tour_step, 2, n)
		3:
			_sheet(pet, tr("R2_TOUR_3_TITLE"), tr("R2_TOUR_3_BODY"), tr("TOUR_NEXT"), _tour_step, 3, n)
		4:
			_sheet(pet, tr("R2_TOUR_4_TITLE"), tr("R2_TOUR_4_BODY"), tr("TOUR_TO_PREFS") % pet, func():
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
	# 見つけた知らせは一か所だけ：相棒の吹き出し（上の知らせの列と下のシートを、両方は出さない）
	_speech((tr("R3_FOUND_TITLE_1") % pet) if list.size() == 1 else tr("FOUND_TITLE") % [pet, list.size()], tr("FOUND_BODY"), tr("FOUND_SEE"), _open_viewer)


var speech: Control


## 相棒の吹き出し（相棒の頭の上。しっぽは相棒のほうへ）。主ボタンはひとつ
func _speech(title: String, body: String, btn: String, cb: Callable) -> void:
	if speech and is_instance_valid(speech):
		speech.queue_free()
	var at := _partner_screen_pos()
	speech = Control.new()
	speech.size = Vector2(360, _h())
	speech.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(speech)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color("fffaf2"), 22, 0.2, Vector2(16, 12)))
	p.position = Vector2(24, 130)
	p.size = Vector2(312, 0)
	speech.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size = Vector2(280, 0)
	p.add_child(v)
	v.add_child(I18n.wrap(_text(title, 19, INK, true, HORIZONTAL_ALIGNMENT_CENTER)))
	v.add_child(I18n.wrap(_text(body, 14, SUB, false, HORIZONTAL_ALIGNMENT_CENTER)))
	var b := Kit.button(btn, ORANGE, func():
		if speech and is_instance_valid(speech):
			speech.queue_free()
		cb.call())
	v.add_child(b)
	var tail := Polygon2D.new()
	tail.color = Color("fffaf2")
	speech.add_child(tail)
	# 吹き出しは相棒の頭の上。上に入らなければ足もとの下に（しっぽは相棒のほうへ。画面からはみ出さない）
	Kit.keep_fit(p, func():
		p.size.y = 0
		var tx := clampf(at.x, 60.0, 300.0)
		if at.y - 50.0 - p.size.y >= 110.0:
			p.position.y = at.y - 50.0 - p.size.y
			var ty := p.position.y + p.size.y - 2.0
			tail.polygon = PackedVector2Array([Vector2(tx - 12, ty), Vector2(tx + 12, ty), Vector2(tx, ty + 18.0)])
		else:
			p.position.y = minf(at.y + 60.0, _bottom() - p.size.y)
			var ty := p.position.y + 2.0
			tail.polygon = PackedVector2Array([Vector2(tx - 12, ty), Vector2(tx + 12, ty), Vector2(tx, ty - 18.0)]))
	p.pivot_offset = Vector2(156, 80)
	p.scale = Vector2(0.85, 0.85)
	p.modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(p, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 1.0, 0.18)
	Kit.play(self, "pop", 1.0)
	Kit.nudge.call_deferred(b)


# ---------------------------------------------------------------- 毎日

func _daily() -> void:
	note_top = 62
	# 一緒に働いた勤務（WorkTogether）が終わったら、その場でひとこと評価を開く（受け渡しは pop_ended の一度だけ）
	WorkTogether.sync()
	var just := Reviews.target_for_ended(WorkTogether.pop_ended())
	if not just.is_empty():
		_open_review(just)
		return
	# 前の晩・当日の朝のひとこと（Reminders）がいちばん上
	var slot := _reminder_note(0)
	var rev := Reviews.pending()
	if not rev.is_empty():
		var s: Dictionary = rev[0]
		_notify(slot, tr("NOTE_REVIEW") % String(s.get("store", s.get("place", ""))), tr("NOTE_REVIEW_SUB"), Color("ffd23f"), func(): _open_review(s))
		return
	# 求人の知らせを Off にした人には、毎日の求人カードを出さない（自分で入れたシフトの評価は出す）
	if not JobPrefs.suggest_on():
		return
	# 「また来てほしいな」のおさそい（Invites）。相棒が持ってきて、求人カードのいちばん前に並ぶ
	Invites.seed_sample()
	var inv := Invites.pending()
	if not inv.is_empty():
		_notify(slot, tr("INVITE_NOTE") % inv[0].store, JobListings.when_text(inv[0]), Color("ff8fb1"), _open_viewer)
		slot += 1
	var left := undecided()
	if left.is_empty():
		return
	_notify(slot, (tr("R3_NOTE_DAILY_1") % SpecialObake.pet_name()) if left.size() == 1 else tr("NOTE_DAILY") % [SpecialObake.pet_name(), left.size()], tr("NOTE_DAILY_SUB") % JobListings.wage_text(left[0]), role_color(left[0].role), _open_viewer)


## 前の晩（島の夜）と当日の朝（島の朝・昼）の、相棒のひとこと。出したら次の段の番号を返す
func _reminder_note(slot: int) -> int:
	var eve := GameState.phase == "evening"
	var s := Reminders.evening() if eve else Reminders.morning()
	if s.is_empty():
		return slot
	var tx: Array = Reminders.evening_text(s) if eve else Reminders.morning_text(s)
	_notify(slot, tx[0], tx[1], Color("9fb4ff"), func(): _reminder_sheet(tx, eve))
	return slot + 1


func _reminder_sheet(tx: Array, eve: bool) -> void:
	if viewer:
		return
	_garden_card(false)
	_sheet(SpecialObake.pet_name(), tx[0], "%s\n%s" % [tx[1], tr("REMIND_EVE_BODY" if eve else "REMIND_AM_BODY")], tr("REMIND_OK"), _close_sheet)


## しごと：まず今日からの自分のシフトを曜日のカードで。下に、ほかの選択肢
## （自分でシフトを入れる・働く条件・お店の島・シフトのチャット・求人を見る）
## at：はじめに見せる日（その時刻の日。-1 なら今日から）
func open_work_menu(at := -1.0) -> void:
	if viewer:
		return
	_garden_card(false)
	var pet := SpecialObake.pet_name()
	var now := Time.get_unix_time_from_system()
	# 今の言語の町のシフトだけ（英語＝SF・日本語＝日本の見本がまざらないように）
	var tz := JobListings.tz_of_region()
	var mine: Array = Shifts.all().filter(func(x): return float(x.end) > now and JobListings.tz_of(x) == tz)
	var days := VBoxContainer.new()
	days.add_theme_constant_override("separation", 6)
	var groups := day_groups(mine, day0_of(now), 7)
	var d_at := day0_of(at) if at >= 0 else -1
	_days(days, groups, "shifts", maxi(0, groups.find_custom(func(g): return g.d0 == d_at)))
	var opts := HFlowContainer.new()
	opts.alignment = FlowContainer.ALIGNMENT_CENTER
	opts.add_theme_constant_override("h_separation", 6)
	opts.add_theme_constant_override("v_separation", 6)
	# 島にあった札（マイスキル・仕事に行ってくる）も、ここに（下のタブの「しごと」から開く）
	for o in [[tr("R2_WORK_MENU_JOBS"), _jobs_from_menu], [tr("I'm going to work"), func(): _go("work")], [tr("SK_PILL"), func(): _go("skills")], [tr("WORK_MENU_PREFS"), func(): _go("prefs")], [tr("WORK_MENU_SHOPS"), open_shops], [tr("CHAT_MENU_SHOPS"), func(): ChatHub.open(self, "list")]]:
		opts.add_child(Kit.button(o[0], Color("f3ecff"), o[1], Color("6a5bd6"), 34, 13))
	# 説明の文は出さない（シートが上の札にかからない高さに）
	_sheet(pet, tr("WORK_MENU_TITLE"), "", tr("SHIFT_FORM_OPEN"), open_shift_form, -1, 0,
		[[tr("WORK_MENU_CLOSE"), _close_sheet]], days, opts)


## しごとの「求人を見る」：シートを閉じて、今日の求人の曜日のカードへ
func _jobs_from_menu() -> void:
	if sheet and is_instance_valid(sheet):
		sheet.queue_free()
	_open_viewer()


## 自分のシフトの 1 行（時刻を大きく、店と仕事）。押すと、そのシフトのくわしいカード
func _shift_row(sh: Dictionary) -> Button:
	var p := Button.new()
	p.custom_minimum_size = Vector2(0, 44)
	for k in ["normal", "hover", "pressed", "focus"]:
		p.add_theme_stylebox_override(k, Kit.pill(Color("fff1e0") if k == "pressed" else Color.WHITE, 14, 0.08, Vector2(12, 6)))
	p.pressed.connect(func():
		Kit.play(self, "tap", 1.1)
		open_shift_detail(sh))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_right = -10
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(h)
	var tl := _text(clock_range(sh), 16, INK, true)
	tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(tl)
	var nm := String(sh.get("store", ""))
	if String(sh.get("title", "")) != "" and String(sh.get("title", "")) != nm:
		nm = "%s · %s" % [sh.title, nm] if nm != "" else String(sh.title)
	var l := _text(nm, 13, SUB, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.clip_text = true
	h.add_child(l)
	var ar := _text("›", 18, SUB, true)
	ar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ar)
	return p


var cancel_armed := false # 取り消しは二度押し（一度目で確かめる）


## マイシフトの 1 件のくわしいカード（求人のカードと同じ中身：店・時間・場所・時給・地図・お店のチャット・取り消し）
func open_shift_detail(sh: Dictionary) -> void:
	cancel_armed = false
	var now := Time.get_unix_time_from_system()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	if sh.has("role") and not sh.get("manual", false):
		top.add_child(_chip(tr("JOB_ROLE_" + String(sh.role).to_upper()), role_color(sh.role).darkened(0.25)))
	if String(sh.get("pay", "")) in JobPrefs.PAYS and not sh.get("manual", false):
		top.add_child(_chip(tr("JOB_PAY_" + String(sh.pay).to_upper()), Color("e9f3ea"), GREEN))
	if float(sh.start) <= now and now < float(sh.end):
		top.add_child(_chip(tr("R3_SHIFT_NOW"), Color("3f8a55")))
	if top.get_child_count() > 0:
		box.add_child(top)
	var place := String(sh.get("place", ""))
	if place != "":
		var pr := HBoxContainer.new()
		pr.add_theme_constant_override("separation", 6)
		var pl := I18n.wrap(_text(place, 14, SUB))
		pr.add_child(pl)
		if String(sh.get("listing", "")) != "" or String(sh.get("store", "")) != "":
			var mp := _small_link(tr("JOB_MAP") + " ›", func(): OS.shell_open(JobListings.maps_url(sh)), Color("3b5ba5"))
			mp.autowrap_mode = TextServer.AUTOWRAP_OFF
			mp.size_flags_horizontal = Control.SIZE_SHRINK_END
			pr.add_child(mp)
		box.add_child(pr)
	var row := HBoxContainer.new()
	row.add_child(_text(JobListings.when_text(sh), 15, INK, true))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	if float(sh.get("wage", 0)) > 0:
		row.add_child(_text(JobListings.wage_text(sh), 18, Color("e0663a"), true))
	box.add_child(row)
	if sh.get("manual", false):
		box.add_child(_text(tr("R3_SHIFT_MANUAL"), 12, SUB))
	var tid := ChatShops.thread_id_for(sh)
	if ChatShops.allowed(tid):
		box.add_child(_small_link(tr("CHAT_ASK_SHOP") + " ›", func(): ChatHub.open(self, tid), Color("6a5bd6")))
	var after := VBoxContainer.new()
	if float(sh.start) > now:
		var cancel := _link(tr("R3_SHIFT_CANCEL"), func(): pass, Color("b0502a"))
		cancel.pressed.connect(func():
			if not cancel_armed:
				cancel_armed = true
				cancel.text = tr("R3_SHIFT_CANCEL_SURE")
				return
			_cancel_shift(sh))
		after.add_child(cancel)
	var nm := String(sh.get("title", ""))
	if String(sh.get("store", "")) != "" and String(sh.get("store", "")) != nm:
		nm = "%s · %s" % [nm, sh.store] if nm != "" else String(sh.store)
	_sheet(SpecialObake.pet_name(), nm, "", "‹ " + tr("WORK_MENU_TITLE"), func(): open_work_menu(float(sh.start)), -1, 0,
		[[tr("WORK_MENU_CLOSE"), _close_sheet]], box, after)


func _cancel_shift(sh: Dictionary) -> void:
	Shifts.remove(String(sh.id))
	Kit.play(self, "tap", 0.8)
	open_work_menu(float(sh.start))


## 働いたお店の一覧（お店の島へ）。まだ無ければ、見本のお店
func open_shops() -> void:
	if viewer:
		return
	_garden_card(false)
	var ids := ShopCulture.worked_shops()
	var body := tr("SHOPS_BODY")
	var sample := ids.is_empty()
	if sample:
		ids = [Invites.SAMPLE_LISTING, "cvs_machikado", "bk_komugi"]
		body = tr("SHOPS_EMPTY")
	var links: Array = []
	for id in ids.slice(0, 4):
		var lid: String = id
		var nm := JobListings.store_name(lid) + ("  (%s)" % tr("SHOPS_SAMPLE") if sample else "")
		links.append(["%s  ·  %s" % [nm, tr("SHOPS_VISIT")], func(): _visit_shop(lid)])
	links.append([tr("WORK_MENU_CLOSE"), _close_sheet])
	_sheet(SpecialObake.pet_name(), tr("SHOPS_TITLE"), body, tr("SHOPS_VISIT") + ": " + JobListings.store_name(ids[0]), func(): _visit_shop(ids[0]), -1, 0, links.slice(1))


## お店の島へ（乗り物で海を渡ってから。screen_travel → screen_shop_island）
func _visit_shop(listing_id: String) -> void:
	GameState.visit = ShopCulture.visit_data(listing_id)
	_go("travel")


func _close_sheet() -> void:
	if sheet and is_instance_valid(sheet):
		sheet.queue_free()
	_garden_card(true)


## 自分でシフトを入れる（決まったバイトがある人向け）。入れたら相棒のひとこと
func open_shift_form() -> void:
	if sheet and is_instance_valid(sheet):
		sheet.queue_free()
	var f := ShiftForm.new()
	f.added.connect(func(s: Dictionary):
		var pet := SpecialObake.pet_name()
		_sheet(pet, tr("SHIFT_ADDED_TITLE"), tr("SHIFT_ADDED_BODY") % [s.title, pet], tr("WORK_MENU_CLOSE"), _close_sheet))
	f.see_shifts.connect(func(at: float): open_work_menu(at))
	f.closed.connect(func():
		if not (sheet and is_instance_valid(sheet) and not sheet.is_queued_for_deletion()):
			_garden_card(true))
	add_child(f)


# ---------------------------------------------------------------- 求人カード（1 件ずつ）

func _build_viewer() -> void:
	_clear_notes()
	if speech and is_instance_valid(speech):
		speech.queue_free()
	if sheet and is_instance_valid(sheet):
		sheet.queue_free()
	_garden_card(false)
	size = Vector2(360, _h())
	viewer = Control.new()
	viewer.size = Vector2(360, 640)
	viewer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(viewer)
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.1, 0.2, 0.62)
	dim.size = Vector2(360, 640)
	viewer.add_child(dim)
	Kit.center_tall(viewer, dim) # 縦に長い島では、カードは上下のまんなか・暗幕は画面いっぱい
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
		onboard_end = true
	jobs = ([] if DemoRoute.active else Invites.pending()) + undecided() # 3 分デモは求人 1 枚だけ
	Telemetry.track("job_cards_shown", {"n": mini(jobs.size(), 50)})
	index = 0
	accepted = 0
	done_ids = {}
	job_day = -1
	_build_viewer()
	_show_list()


var done_ids := {} # この知らせの中で、受けた・見送った仕事

## お店の島の「いまの募集」から選んだ仕事。島に戻ったら、そのくわしいカードを開く（受けるのはここから）
static var focus_job := {}
## ほかの画面（しごとの条件）で「マイシフトで見る ›」を押した：島に戻ったら、マイシフトのその日を開く
static var focus_shifts_at := -1.0


func _open_focus() -> void:
	var j: Dictionary = focus_job
	focus_job = {}
	if viewer:
		return
	JobListings.localize(j)
	Telemetry.track("job_cards_shown", {"n": 1})
	jobs = [j]
	index = 0
	accepted = 0
	done_ids = {}
	job_day = -1
	_build_viewer()
	_show_job()


## 並べて比べる：残りの仕事を曜日のカードに（翌日から 1 週間。スワイプか ‹ › で日を送る）。
## 1 日のカードには、その日の仕事（時給を大きく）。タップで詳しく、受けるのは詳しい方から
func _show_list() -> void:
	_clear_card()
	var left: Array = jobs.filter(func(j): return not done_ids.has(j.id))
	if left.is_empty():
		_show_end()
		return
	_say(tr("JOB_LIST_SAY"))
	stage.talk()
	card_box.add_child(_text(tr("R3_JOB_LIST_TITLE_1") if left.size() == 1 else tr("JOB_LIST_TITLE") % left.size(), 17, INK, true))
	var groups := day_groups(left, day0_of(Time.get_unix_time_from_system()) + 86400, 7)
	# はじめて開いたときは、仕事のある最初の日から。受けた・見送ったあとは、同じ日に戻る
	if job_day < 0 or job_day >= groups.size() or groups[job_day].items.is_empty():
		job_day = maxi(0, groups.find_custom(func(g): return not g.items.is_empty()))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card_box.add_child(box)
	_days(box, groups, "jobs", job_day)
	card_box.add_child(_link(tr("JOB_LIST_LATER"), _close_viewer))
	_pop_card()


var job_day := -1 # 求人の曜日のカードの、いま見ている日


## 求人の 1 行（レビュー3：背の高いカードの形）：左に色の帯、仕事・店と場所・時間と評判の 3 段、右に時給（大きく太く）と受け取り方
func _list_row(j: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 80)
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, Kit.pill(Color("fff1e0") if k == "pressed" else Color.WHITE, 16, 0.14, Vector2(10, 8)))
	b.pressed.connect(func():
		Kit.play(self, "tap", 1.1)
		index = jobs.find(j)
		_show_job())
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -10
	h.offset_top = 8
	h.offset_bottom = -8
	h.add_theme_constant_override("separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(6, 0)
	dot.size_flags_vertical = Control.SIZE_FILL
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ds := StyleBoxFlat.new()
	ds.bg_color = Color("ff8fb1") if Invites.is_invite(j) else role_color(j.role)
	ds.set_corner_radius_all(3)
	dot.add_theme_stylebox_override("panel", ds)
	h.add_child(dot)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := Reviews.summary(j.listing)
	var lines := [
		[("%s  " % tr("INVITE_CHIP") if Invites.is_invite(j) else "") + String(j.title), 15, INK, true],
		[String(j.place), 12, SUB, false],
		["%s · ★%.1f" % [clock_range(j), sm.stars], 13, INK, true],
	]
	for ln in lines:
		var l := _text(ln[0], ln[1], ln[2], ln[3])
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
		v.add_child(l)
	h.add_child(v)
	var rv := VBoxContainer.new()
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.add_theme_constant_override("separation", 0)
	rv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wl := _text(JobListings.wage_text(j), 20, Color("e0663a"), true, HORIZONTAL_ALIGNMENT_RIGHT)
	wl.add_theme_font_override("font", Kit.black())
	rv.add_child(wl)
	if String(j.get("pay", "")) in JobPrefs.PAYS:
		rv.add_child(_text(tr("JOB_PAY_" + String(j.pay).to_upper()), 11, GREEN, true, HORIZONTAL_ALIGNMENT_RIGHT))
	h.add_child(rv)
	return b


# ---------------------------------------------------------------- 曜日のカード（求人・自分のシフト）

## 見本の町（今の言語）の、その日の 0 時（unix 秒）
static func day0_of(t: float) -> int:
	return JobListings.day0(t)


## 仕事・シフトを日ごとのカードに分ける。first_d0 から n 日は毎日カードを出し（何もない日も）、それ以外の日は何かあれば足す。
## 日付の順、中は始まりの順。返り値 [{d0, items}]
static func day_groups(list: Array, first_d0: int, n: int) -> Array:
	var by := {}
	for i in n:
		by[JobListings.next_day0(first_d0, i)] = []
	for it in list:
		var d := day0_of(float(it.start))
		if not by.has(d):
			by[d] = []
		by[d].append(it)
	var keys: Array = by.keys()
	keys.sort()
	var out: Array = []
	for d in keys:
		var items: Array = by[d]
		items.sort_custom(func(a, b): return float(a.start) < float(b.start))
		out.append({"d0": int(d), "items": items})
	return out


## 例: 「火 9/29」「Tue 9/29」
static func day_label(d0: int) -> String:
	var d := JobListings.local(d0)
	return I18n.t("R2_DAY") % [I18n.t("JOB_WD_%d" % JobListings.weekday_mon(d0)), d.month, d.day]


## 例: 「12:00–17:00」（そのシフトの町の時刻）
static func clock_range(it: Dictionary) -> String:
	var s := JobListings.local(it.start, JobListings.tz_of(it))
	var e := JobListings.local(it.end, JobListings.tz_of(it))
	return "%02d:%02d–%02d:%02d" % [s.hour, s.minute, e.hour, e.minute]


var day_box: VBoxContainer # いま見せている曜日のカード（スワイプを受ける）
var day_list: Array = []
var day_kind := ""
var day_i := 0
var swipe_from := Vector2(-1, -1)


## 曜日のカードを box に。kind = "jobs"（求人）/ "shifts"（自分のシフト）
func _days(box: VBoxContainer, groups: Array, kind: String, start: int) -> void:
	day_box = box
	day_list = groups
	day_kind = kind
	day_i = clampi(start, 0, maxi(0, groups.size() - 1))
	_fill_day()


func _fill_day() -> void:
	if not (day_box and is_instance_valid(day_box)) or day_list.is_empty():
		return
	for c in day_box.get_children():
		c.queue_free()
	var g: Dictionary = day_list[day_i]
	var today := day0_of(Time.get_unix_time_from_system())
	# 見出し：‹ 火 9/29（2 件）›
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 4)
	head.add_child(_day_arrow("‹", -1))
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", -2)
	var lbl := day_label(g.d0)
	if g.d0 == today:
		lbl = tr("R2_TODAY") + " · " + lbl
	mid.add_child(_text(lbl, 18, INK, true, HORIZONTAL_ALIGNMENT_CENTER))
	if day_kind == "jobs":
		mid.add_child(_text(tr("R2_DAY_JOBS_1") if g.items.size() == 1 else tr("R2_DAY_JOBS") % g.items.size(), 11, SUB, true, HORIZONTAL_ALIGNMENT_CENTER))
	head.add_child(mid)
	head.add_child(_day_arrow("›", 1))
	day_box.add_child(head)
	# 曜日の札（月〜日。何かある日は色つき）。押すとその日へ
	if day_list.size() <= 8:
		var strip := HBoxContainer.new()
		strip.alignment = BoxContainer.ALIGNMENT_CENTER
		strip.add_theme_constant_override("separation", 3)
		for i in day_list.size():
			strip.add_child(_day_tab(i))
		day_box.add_child(strip)
	# その日の中身
	if g.items.is_empty():
		var none := I18n.wrap(_text(tr("R2_DAY_NONE") if day_kind == "jobs" else tr("R2_SHIFT_NONE"), 13, SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
		none.custom_minimum_size = Vector2(0, 44)
		day_box.add_child(none)
	for it in g.items:
		day_box.add_child(_list_row(it) if day_kind == "jobs" else _shift_row(it))


func _day_arrow(t: String, d: int) -> Button:
	var b := Kit.button(t, Color("f3ecff"), func(): _go_day(d), Color("6a5bd6"), 36, 22)
	b.custom_minimum_size.x = 40
	var at_end := (day_i == 0 and d < 0) or (day_i == day_list.size() - 1 and d > 0)
	b.disabled = at_end
	b.modulate.a = 0.35 if at_end else 1.0
	return b


func _day_tab(i: int) -> Button:
	var g: Dictionary = day_list[i]
	var on := i == day_i
	var has: bool = not g.items.is_empty()
	var b := Button.new()
	b.text = I18n.t("JOB_WD_%d" % JobListings.weekday_mon(g.d0))
	b.custom_minimum_size = Vector2(36, 30)
	b.add_theme_font_override("font", Kit.black())
	b.add_theme_font_size_override("font_size", 12)
	var bg := Color("ff8a5b") if on else (Color("ffe3d3") if has else Color("f4f0f5"))
	var fg := Color.WHITE if on else (Color("b0502a") if has else Color("b8aeb6"))
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, Kit.pill(bg, 10, 0.0, Vector2(4, 2)))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fg)
	b.pressed.connect(func():
		if i != day_i:
			Kit.play(self, "tab")
			_set_day(i))
	return b


func _go_day(d: int) -> void:
	var n := clampi(day_i + d, 0, day_list.size() - 1)
	if n == day_i:
		return
	Kit.play(self, "tab", 1.0 + 0.06 * d)
	_set_day(n)


func _set_day(n: int) -> void:
	day_i = n
	if day_kind == "jobs":
		job_day = n
	_fill_day()
	if day_box and is_instance_valid(day_box):
		day_box.modulate.a = 0.4
		create_tween().tween_property(day_box, "modulate:a", 1.0, 0.18)


## 曜日のカードの上を横にすべらせたら、となりの日へ（ボタンの上から始めても。押したことにはしない）
func _input(event: InputEvent) -> void:
	if not (day_box and is_instance_valid(day_box) and day_box.is_visible_in_tree()):
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	if event.pressed:
		swipe_from = event.position if day_box.get_global_rect().grow(8).has_point(event.position) else Vector2(-1, -1)
		return
	if swipe_from.x < 0:
		return
	var d: Vector2 = event.position - swipe_from
	swipe_from = Vector2(-1, -1)
	if absf(d.x) > 48.0 and absf(d.x) > absf(d.y) * 1.5:
		get_viewport().set_input_as_handled()
		_go_day(-1 if d.x > 0 else 1)


func _clear_card() -> void:
	for c in card_box.get_children():
		c.queue_free()


## 折り返しの高さが決まってから、中身に合わせて縮める（2 フレーム待つ。庭の _card_fit と同じ）
func _fit(p: Control) -> void:
	if not p.has_meta("keep_fit"):
		p.set_meta("keep_fit", true)
		Kit.keep_fit(p, func():
			p.size.y = 0
			if p == card: # 長いカードは、下の「見本の求人です」（614）にかからないよう、上へずらす
				card.position.y = minf(222.0, 606.0 - card.size.y))
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
	if index < 0 or index >= jobs.size() or done_ids.has(jobs[index].id):
		_show_list()
		return
	var j: Dictionary = jobs[index]
	Telemetry.track("job_card_open", JobListings.telemetry_shop(j.get("listing"), {"invited": Invites.is_invite(j)}))
	_say(tr("INVITE_SAY") % j.store if Invites.is_invite(j) else j.line)
	stage.talk()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	_invite_chip(top, j)
	top.add_child(_chip(tr("JOB_ROLE_" + String(j.role).to_upper()), role_color(j.role).darkened(0.25)))
	top.add_child(_chip(tr("JOB_PAY_" + String(j.pay).to_upper()), Color("e9f3ea"), GREEN))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	card_box.add_child(top)
	card_box.add_child(I18n.wrap(_text(j.title, 21, INK, true)))
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 6)
	var pl := I18n.wrap(_text(j.place, 14, SUB))
	pr.add_child(pl)
	var mp := _small_link(tr("JOB_MAP") + " ›", func(): OS.shell_open(JobListings.maps_url(j)), Color("3b5ba5"))
	mp.autowrap_mode = TextServer.AUTOWRAP_OFF
	mp.size_flags_horizontal = Control.SIZE_SHRINK_END
	pr.add_child(mp)
	card_box.add_child(pr)
	var when_t := JobListings.when_text(j)
	var wage_t := JobListings.wage_text(j)
	var row := HBoxContainer.new()
	row.add_child(_text(when_t, 15, INK, true))
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp2)
	# 日付と時給が一行に入らない（日本語の「〜」「／時」など）ときは、時給を次の行の右へ。カードが横にはみ出さないように
	if Kit.black().get_string_size(when_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + Kit.black().get_string_size(wage_t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 8 > 292:
		card_box.add_child(row)
		row = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(_text(wage_t, 20, Color("e0663a"), true))
	card_box.add_child(row)
	# 働いた人の声（見本の集計＋自分の評価）
	var voice := PanelContainer.new()
	voice.add_theme_stylebox_override("panel", Kit.pill(Color("f1f7f1"), 12, 0.0, Vector2(10, 5)))
	voice.add_child(I18n.wrap(_text(Reviews.summary_text(j.listing), 12, GREEN, true)))
	card_box.add_child(voice)
	_skill_row(j)
	_visit_island_link(j)
	var acc := Kit.button(tr("JOB_ACCEPT"), ORANGE, _accept)
	card_box.add_child(acc)
	var bot := HBoxContainer.new()
	bot.alignment = BoxContainer.ALIGNMENT_CENTER
	bot.add_theme_constant_override("separation", 18)
	bot.add_child(_link("‹ " + tr("JOB_BACK_LIST"), _show_list))
	bot.add_child(_link(tr("JOB_PASS"), _pass))
	card_box.add_child(bot)
	_pop_card()


## おさそい（Invites）の印
func _invite_chip(top: HBoxContainer, j: Dictionary) -> void:
	if Invites.is_invite(j):
		top.add_child(_chip(tr("INVITE_CHIP"), Color("ff8fb1").darkened(0.15)))


## 「このお店の島を見にいく」（お店の島：働いた人の評価で育つ島）
func _visit_island_link(j: Dictionary) -> void:
	card_box.add_child(_small_link(tr("JOB_VISIT_ISLAND") + "  ›", func(): _visit_shop(j.listing), Color("3b8a7a")))


## カードの中の小さなリンク（おさらい・お店の島）。長ければ折り返して、カードの幅を広げない
func _small_link(t: String, cb: Callable, color: Color) -> Button:
	var b := _link(t, cb, color)
	b.custom_minimum_size = Vector2(0, 26)
	b.add_theme_font_size_override("font_size", 12)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return b


## スキルの記録（feature/skills）：その仕事の自分のバッジ（例: Register ★2 · 3 shifts）。
## はじめての仕事の「おさらい、する？」は、ここではなく受けたあとのカードで聞く（求人を見ている間は分かりにくい、というレビュー）
func _skill_row(j: Dictionary) -> void:
	var role := String(j.role)
	var txt := Skills.badge_text(role)
	if txt != "":
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(SkillBadge.make(role, Skills.stars(role), 24))
		row.add_child(_text(tr("SK_CARD_YOURS") % txt, 12, Color("3b5ba5"), true))
		card_box.add_child(row)


func _accept() -> void:
	if busy:
		return
	busy = true
	var j: Dictionary = jobs[index]
	# 一緒に働く係と共有する約束：Shifts の 1 件の形
	var s := JobListings.as_shift(j)
	# もう入っているシフトと時間が重なる仕事は受けない（両方は働けない）
	var clash := Shifts.overlapping(s)
	if not clash.is_empty():
		_show_overlap(clash)
		busy = false
		return
	var invited := Invites.is_invite(j)
	if invited:
		s = Invites.accept(j)
	else:
		Shifts.add(s)
		decide(j.id, "accept")
	var acc := {"role": j.role, "invited": invited}
	if String(j.get("pay", "")) in JobPrefs.PAYS:
		acc["pay_style"] = j.pay
	Telemetry.track("job_accept", JobListings.telemetry_shop(j.get("listing"), acc))
	accepted += 1
	done_ids[j.id] = true
	stage.joy()
	Kit.play(self, "sparkle")
	Kit.play(self, "chime", 1.1, -4)
	_say(tr("JOY_%d" % (accepted % 3 + 1)))
	_clear_card()
	card_box.add_child(_text(tr("JOB_ADDED"), 18, GREEN, true))
	card_box.add_child(I18n.wrap(_text("%s · %s" % [j.title, j.store], 14, INK, true)))
	card_box.add_child(_text(JobListings.when_text(j), 14, SUB))
	card_box.add_child(_small_link(tr("JOB_MAP") + " ›", func(): OS.shell_open(JobListings.maps_url(j)), Color("3b5ba5")))
	# アプリの中のカレンダー（マイシフト）に入ったことを、はっきり。すぐ見に行けるリンク
	var mine := PanelContainer.new()
	mine.add_theme_stylebox_override("panel", Kit.pill(Color("e9f3ea"), 12, 0.0, Vector2(10, 6)))
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 0)
	mv.add_child(I18n.wrap(_text(tr("R3_IN_MY_SHIFTS"), 13, GREEN, true)))
	mv.add_child(_small_link(tr("R3_SEE_MY_SHIFTS"), func(): _to_my_shifts(float(s.start)), GREEN))
	mine.add_child(mv)
	card_box.add_child(mine)
	var cal := Kit.button(tr("CAL_GOOGLE"), Color("eef3ff"), func():
		Telemetry.track("calendar_add", {"kind": "google"})
		CalendarLink.open_google(s), Color("3b5ba5"), 44, 15)
	card_box.add_child(cal)
	var status := I18n.wrap(_text("", 11, SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
	card_box.add_child(_link(tr("CAL_ICS"), func():
		Telemetry.track("calendar_add", {"kind": "ics"})
		status.text = CalendarLink.save_ics(s), Color("3b5ba5")))
	card_box.add_child(status)
	card_box.add_child(_link(tr("CHAT_ASK_SHOP"), func(): ChatHub.open(self, ChatShops.thread_id_for(s)), Color("6a5bd6"))) # お店の猫に聞く（feature/cat-chat）
	# はじめての仕事なら、シフトの前のおさらい（任意。受けたあとにだけ聞く）
	var role := String(j.role)
	if Skills.suggest_practice(role):
		card_box.add_child(_small_link(tr("R2_ACCEPT_PRACTICE"), func():
			Skills.practice_role = role
			_go("practice"), Color("3b5ba5")))
	var more := jobs.any(func(x): return not done_ids.has(x.id))
	card_box.add_child(Kit.button(tr("JOB_BACK_LIST") if more else tr("JOB_DONE"), ORANGE, _next))
	_pop_card()
	busy = false


## 重なるシフトがあって受けられないとき：どのシフトと重なるか、と、マイシフトへのリンク
func _show_overlap(clash: Dictionary) -> void:
	stage.shrug()
	Kit.play(self, "tap", 0.8)
	_say(tr("R3_OVERLAP_SAY"))
	_clear_card()
	card_box.add_child(_text(tr("R3_OVERLAP_TITLE"), 18, Color("b0502a"), true))
	card_box.add_child(I18n.wrap(_text(tr("R3_OVERLAP_BODY") % shift_label(clash), 14, INK)))
	card_box.add_child(_small_link(tr("R3_SEE_MY_SHIFTS"), func(): _to_my_shifts(float(clash.start)), Color("3b5ba5")))
	card_box.add_child(Kit.button("‹ " + tr("JOB_BACK_LIST"), ORANGE, _show_list))
	_pop_card()


## 「火 9/29 12:00–17:00（カフェ こもれび）」：重なりの知らせなどに使う、シフトの短い名前
static func shift_label(sh: Dictionary) -> String:
	var nm := String(sh.get("store", ""))
	if nm == "":
		nm = String(sh.get("title", sh.get("place", "")))
	return I18n.t("R3_SHIFT_LABEL") % [day_label(day0_of(float(sh.start))), clock_range(sh), nm] if nm != "" else "%s %s" % [day_label(day0_of(float(sh.start))), clock_range(sh)]


## 求人のカードを閉じて、マイシフト（しごとのシート）のその日へ
func _to_my_shifts(at: float) -> void:
	if viewer:
		viewer.queue_free()
		viewer = null
	if onboard_end: # はじめての流れの終わり（知らせは次に島を開いたとき。しごとは下のタブから）
		onboard_end = false
	open_work_menu(at)


func _pass() -> void:
	if busy:
		return
	busy = true
	var j: Dictionary = jobs[index]
	Telemetry.track("job_pass", JobListings.telemetry_shop(j.get("listing"), {"role": j.role, "invited": Invites.is_invite(j)}))
	if Invites.is_invite(j):
		Invites.decline(j)
	else:
		decide(j.id, "pass")
	done_ids[j.id] = true
	stage.shrug()
	_say(tr("SHRUG_%d" % (index % 2 + 1)))
	var tw := create_tween().set_parallel()
	tw.tween_property(card, "position:x", -360.0, 0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw.finished
	card.position.x = 16
	busy = false
	_show_list()


func _next() -> void:
	_show_list()


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
	# はじめての流れが終わったところ：開き直さなくても、毎日の形（しごとボタン・知らせ）に
	if onboard_end:
		onboard_end = false
		_daily()


# ---------------------------------------------------------------- 働いたあとの、ひとこと評価（10 秒）

var rv_stars := 0
var rv_tags := {}
var rv_issues := {} # 大変だったこと（Reviews.ISSUES）。島には出ない。お店には匿名の集計（5 人以上）だけ
var rv_support := false # 失礼な扱い：Paw Time の窓口にも知らせる
var rv_star_btns: Array[Button] = []
var rv_send: Button
var rv_support_btn: Button


var rv_shift := {}


func _open_review(s: Dictionary) -> void:
	if viewer:
		return
	rv_shift = s
	_build_viewer()
	rv_stars = 0
	rv_tags = {}
	rv_issues = {}
	rv_support = false
	rv_star_btns.clear()
	# よかったこと・大変だったことの 2 群が 360x640 に収まるよう、相棒を小さく・カードを上に
	stage.scale = Vector2(0.5, 0.5)
	stage.position = Vector2(8, 4)
	var bub := bubble_l.get_parent() as Control
	bub.position = Vector2(84, 24)
	bub.size = Vector2(268, 0)
	bubble_l.custom_minimum_size = Vector2(244, 0)
	card.position.y = 96
	card_box.add_theme_constant_override("separation", 4)
	_say(tr("REVIEW_ASK") % String(s.get("store", s.get("place", ""))))
	card_box.add_child(_text(tr("REVIEW_TITLE"), 17, INK, true))
	card_box.add_child(I18n.wrap(_text(tr("REVIEW_WHY"), 11, SUB)))
	var sr := HBoxContainer.new()
	sr.alignment = BoxContainer.ALIGNMENT_CENTER
	sr.add_theme_constant_override("separation", 4)
	for i in 5:
		var b := Button.new()
		b.text = "★"
		b.flat = true
		b.custom_minimum_size = Vector2(46, 40)
		b.add_theme_font_override("font", Kit.black())
		b.add_theme_font_size_override("font_size", 30)
		b.pressed.connect(func():
			Kit.play(self, "tap", 1.0 + i * 0.08)
			rv_stars = i + 1
			_review_refresh())
		sr.add_child(b)
		rv_star_btns.append(b)
	card_box.add_child(sr)
	card_box.add_child(_text(tr("REVIEW_GOOD"), 12, INK, true))
	card_box.add_child(_review_chips(Reviews.TAGS, "tag"))
	card_box.add_child(_text(tr("REVIEW_BAD"), 12, INK, true))
	card_box.add_child(_review_chips(Reviews.ISSUES, "issue"))
	rv_support_btn = Button.new()
	rv_support_btn.text = tr("REVIEW_SUPPORT")
	rv_support_btn.custom_minimum_size = Vector2(0, 28)
	rv_support_btn.add_theme_font_override("font", Kit.black())
	rv_support_btn.add_theme_font_size_override("font_size", 11)
	rv_support_btn.pressed.connect(func():
		Kit.play(self, "toggle")
		rv_support = not rv_support
		_review_refresh())
	card_box.add_child(rv_support_btn)
	card_box.add_child(I18n.wrap(_text(tr("REVIEW_BAD_NOTE"), 10, SUB)))
	rv_send = Kit.button(tr("REVIEW_SEND") % Reviews.BONUS_POI, ORANGE, func(): _send_review(s))
	card_box.add_child(rv_send)
	card_box.add_child(_link(tr("REVIEW_SKIP"), func():
		Reviews.skip(s)
		_close_viewer()
		_daily()))
	_review_refresh()
	_pop_card()


## 評価のチップの群（kind: "tag" よかったこと / "issue" 大変だったこと）
func _review_chips(ids: Array, kind: String) -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 5)
	flow.add_theme_constant_override("v_separation", 5)
	flow.set_meta("kind", kind)
	for id in ids:
		var c := Button.new()
		c.text = tr(("REVIEW_TAG_" if kind == "tag" else "REVIEW_ISSUE_") + String(id).to_upper())
		c.custom_minimum_size = Vector2(0, 28)
		c.add_theme_font_override("font", Kit.black())
		c.add_theme_font_size_override("font_size", 11)
		c.set_meta("tag", id)
		c.pressed.connect(func():
			Kit.play(self, "toggle")
			var d: Dictionary = rv_tags if kind == "tag" else rv_issues
			d[id] = not d.get(id, false)
			_review_refresh())
		flow.add_child(c)
	return flow


func _review_refresh() -> void:
	for i in rv_star_btns.size():
		var on := i < rv_stars
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			rv_star_btns[i].add_theme_color_override(k, Color("ffb42e") if on else Color("e2d9e6"))
	for c in card_box.get_children():
		if c is HFlowContainer:
			var good: bool = c.get_meta("kind", "tag") == "tag"
			# よかったこと＝紫、大変だったこと＝落ち着いた灰青（赤で警告しない）
			var sel: Dictionary = rv_tags if good else rv_issues
			var on_c := Color("8b7bff") if good else Color("7d8aa6")
			var off_c := Color("f3ecff") if good else Color("eef0f4")
			var ink_c := Color("6a5bd6") if good else Color("5b6478")
			for b: Button in c.get_children():
				var on: bool = sel.get(b.get_meta("tag"), false)
				for k in ["normal", "hover", "pressed", "focus"]:
					b.add_theme_stylebox_override(k, Kit.pill(on_c if on else off_c, 14, 0.0, Vector2(9, 2)))
				for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
					b.add_theme_color_override(k, Color.WHITE if on else ink_c)
	# 失礼な扱いを選んだときだけ、窓口に知らせる選択肢
	if rv_support_btn and is_instance_valid(rv_support_btn):
		rv_support_btn.visible = rv_issues.get("rude", false)
		if not rv_support_btn.visible:
			rv_support = false
		for k in ["normal", "hover", "pressed", "focus"]:
			rv_support_btn.add_theme_stylebox_override(k, Kit.pill(Color("5b6478") if rv_support else Color("fffaf2"), 14, 0.0, Vector2(9, 2)))
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			rv_support_btn.add_theme_color_override(k, Color.WHITE if rv_support else Color("5b6478"))
		rv_support_btn.text = ("✓ " if rv_support else "") + tr("REVIEW_SUPPORT")
	rv_send.disabled = rv_stars == 0


func _send_review(s: Dictionary) -> void:
	if rv_stars == 0 or busy:
		return
	busy = true
	var tags: Array = []
	for tg in rv_tags:
		if rv_tags[tg]:
			tags.append(tg)
	var issues: Array = []
	for i in Reviews.ISSUES:
		if rv_issues.get(i, false):
			issues.append(i)
	Reviews.add(s, rv_stars, tags, issues)
	# review_submitted の tags はよいタグだけ（API の決まり）。大変だったことは anon_issue_sent（ChatOutbox.tell_shop）で匿名の箱へ
	Telemetry.track("review_submitted", JobListings.telemetry_shop(s.get("listing"), {"tag_count": tags.size(), "tags": tags, "stars": rv_stars}))
	Reviews.send_issues(s, issues, rv_support)
	var told_support := rv_support and "rude" in issues
	Invites.after_review(s, rv_stars) # よい評価なら、そのお店から「また来てほしいな」のおさそい
	# ごほうびはポイ（すくいの網）。働いた時間とは関係なく、1 回 1 本
	GameState.nets["plain"] = GameState.nets.get("plain", 0) + Reviews.BONUS_POI
	GameState.save()
	stage.joy()
	Kit.play(self, "sparkle")
	_say(tr("REVIEW_THANKS") % Reviews.BONUS_POI)
	_clear_card()
	card_box.add_child(_text(tr("REVIEW_DONE"), 18, GREEN, true, HORIZONTAL_ALIGNMENT_CENTER))
	card_box.add_child(I18n.wrap(_text(tr("REVIEW_DONE_BODY"), 13, SUB, false, HORIZONTAL_ALIGNMENT_CENTER)))
	if not issues.is_empty():
		card_box.add_child(I18n.wrap(_text(tr("REVIEW_BAD_NOTE"), 11, SUB, false, HORIZONTAL_ALIGNMENT_CENTER)))
	if told_support:
		card_box.add_child(I18n.wrap(_text(tr("REVIEW_SUPPORT_SENT"), 11, SUB, false, HORIZONTAL_ALIGNMENT_CENTER)))
	card_box.add_child(Kit.button(tr("TOUR_NEXT"), ORANGE, func():
		_close_viewer()
		_daily()))
	_pop_card()
	busy = false


# ---------------------------------------------------------------- 確認用（OBAKE_SHOT の call:）

func demo_tour_next() -> void:
	_tour_step()


## 島の説明の最後のボタンと同じ（働く条件の入力へ）
func demo_tour_done() -> void:
	Onboarding.advance("prefs")
	_go("prefs")


func demo_work() -> void:
	open_work_menu()


func demo_shift_form() -> void:
	open_shift_form()
	await get_tree().process_frame
	for c in get_children():
		if c is ShiftForm:
			c.demo_fill()


func demo_shift_add() -> void:
	for c in get_children():
		if c is ShiftForm:
			c._add()


func demo_open() -> void:
	_open_viewer()


## 曜日のカードを次の日へ（› を押したのと同じ）
func demo_day_next() -> void:
	_go_day(1)


## 求人カードの「このお店の島を見にいく」と同じ
func demo_visit() -> void:
	_visit_shop(jobs[index].listing if index < jobs.size() else Invites.SAMPLE_LISTING)


func demo_shops() -> void:
	open_shops()


## いちばん上の知らせ（前の晩・当日の朝のひとこと）を押す
func demo_remind() -> void:
	if not notes.is_empty() and is_instance_valid(notes[0]):
		notes[0].pressed.emit()


## 一覧の先頭の仕事をくわしく
func demo_detail() -> void:
	index = 0
	_show_job()


func demo_accept() -> void:
	_accept()


func demo_next() -> void:
	_next()


func demo_pass() -> void:
	_pass()


func demo_review() -> void:
	# 終わったばかりの見本のシフトを1件入れて、評価を開く
	var now := Time.get_unix_time_from_system()
	var e: Array = JobListings.LIST[0]
	var j := JobListings.demo_pay({"id": "demo_review", "listing": e[0], "role": "register", "area": "shibuya", "start": now - 5 * 3600, "end": now - 3600, "pay": "weekly", "line_n": 1})
	JobListings.localize(j)
	var s := JobListings.as_shift(j)
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


## 大変だったことも選んだ形（失礼な扱い＋窓口）
func demo_issues() -> void:
	rv_stars = 3
	rv_tags = {"friendly": true}
	rv_issues = {"no_break": true, "rude": true}
	rv_support = true
	_review_refresh()
