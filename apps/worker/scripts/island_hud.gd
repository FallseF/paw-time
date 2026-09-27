class_name IslandHud
extends Control
## 島の HUD（レビュー：「ボタンが AI 生成っぽい」「情報量が多い」への作り直し）。庭の画面から add_child(IslandHud.new(self)) の 1 行で入る。
##   下：5 つのタブ（島・しごと・すくう・キセカエ・図鑑）。えらんだタブは、うす紫の丸にのって少し浮く
##   左上：曜日と島 Lv の札（ボタンではなく状態。タップで育ちの欄。何週目かもそこ）
##   右上：丸いボタン 3 つ（めあて・話す・マイページ）。文字はなし。はじめて一度だけ、名前の吹き出し
##   右下：✎（島をつくる。広げる・カタログ・シェアはその中）
## 重ね画面（しごとのシート・求人カード・チャット・カタログ…）が開いている間・島づくり・話す間は、下へ引っこむ（garden.hud_wanted()）。
## 大きさは 360 幅の画面の座標（390pt の図面 × 0.923）。下のタブは画面の下にそろえる（縦に長い画面でも）

const TABS := ["island", "jobs", "scoop", "closet", "book"]
const TAB_KEYS := {"island": "HUD_TAB_ISLAND", "jobs": "HUD_TAB_JOBS", "scoop": "HUD_TAB_SCOOP", "closet": "HUD_TAB_CLOSET", "book": "HUD_TAB_BOOK"}
const ICONS := {
	"island": preload("res://assets/ui/nav/island.png"),
	"jobs": preload("res://assets/ui/nav/jobs.png"),
	"scoop": preload("res://assets/ui/nav/scoop.png"),
	"closet": preload("res://assets/ui/nav/closet.png"),
	"book": preload("res://assets/ui/nav/book.png"),
	"goals": preload("res://assets/ui/nav/goals.png"),
	"talk": preload("res://assets/ui/nav/talk.png"),
	"me": preload("res://assets/ui/nav/cat_face.png"),
	"edit": preload("res://assets/ui/nav/edit.png"),
}
const LEAF := preload("res://assets/ui/nav/leaf.png")

const NAV_X := 11.0
const NAV_W := 338.0
const NAV_H := 81.0
const NAV_GAP := 9.0 # 画面の下とのすき間
const TAB_W := NAV_W / 5.0
const LIFT := 18.0 # えらんだ丸が、帯の上に出る分（タブの押せる所も、そこまで上へ）
const ICON := 46.0
const ICON_SEL := 54.0
const ICON_Y := 33.0 # 帯の上から、アイコンのまんなかまで
const BUB := 66.0 # えらんだタブの丸
const BUB_UP := 14.0 # 丸が帯の上に出る分（えらんだアイコンも、同じだけ浮く）
const BTN := 41.0 # 丸いボタン（押せる所は 44）
const HIT := 44.0

var garden
var nav: Control
var bubble: Panel
var tabs := {} # id → Button
var faces := {} # id → Control（押したときに縮む）
var icons := {} # id → TextureRect
var labels := {} # id → Label
var badges := {} # id → Badge
var selected := "island"
var status_chip: Button
var round_btns := {} # goals / talk / me → Button
var goals_ring: Ring
var fab: Button
var top_row: Control
var scoop_chip: PanelContainer
var scoop_glow: Panel
var coach: Control
var shown := true
var _tw: Tween
var _sel_tw: Tween
var _badge_t := 0.0


func _init(g = null) -> void:
	garden = g


func _ready() -> void:
	position = Vector2.ZERO
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit_size()
	get_viewport().size_changed.connect(_layout)
	_build_top()
	_build_nav()
	_build_fab()
	_layout()
	refresh()
	_coach.call_deferred()


func _fit_size() -> void:
	size = get_viewport_rect().size


func _h() -> float:
	return get_viewport_rect().size.y


## 下のタブの帯の上端（出ているとき）
func nav_top() -> float:
	return _h() - NAV_GAP - NAV_H


## 今日のカードなど、帯の上に置く物の下端
func card_bottom() -> float:
	return nav_top() - 11.0


## ✎ の左上（カードの右にならぶ。✎ が無い日は画面の右はしまで）
func fab_rect() -> Rect2:
	if fab == null or not fab.visible:
		return Rect2(360.0 - 12.0, card_bottom(), 0, 0)
	return Rect2(fab.position, fab.size)


# ---------------------------------------------------------------- 下のタブ

func _build_nav() -> void:
	nav = Control.new()
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nav.size = Vector2(360, NAV_H + LIFT)
	add_child(nav)
	var cap := Panel.new()
	cap.mouse_filter = Control.MOUSE_FILTER_STOP # 帯の上のタップは、島に通さない
	cap.position = Vector2(NAV_X, LIFT)
	cap.size = Vector2(NAV_W, NAV_H)
	var st := Tokens.round_box(Tokens.CREAM, int(NAV_H / 2), Color(0, 0, 0, 0), 0, 2)
	st.border_color = Tokens.EDGE
	st.border_width_bottom = 1
	cap.add_theme_stylebox_override("panel", st)
	nav.add_child(cap)
	# 上のふちの、うすい光（1.5pt 白 70%）
	var hi := Panel.new()
	hi.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hi.position = cap.position
	hi.size = cap.size
	var hs := StyleBoxFlat.new()
	hs.draw_center = false
	hs.set_corner_radius_all(int(NAV_H / 2))
	hs.border_color = Color(1, 1, 1, 0.7)
	hs.border_width_top = 1
	hi.add_theme_stylebox_override("panel", hs)
	nav.add_child(hi)
	# えらんだタブの丸（Ø66・ふち 3 のクリーム）。帯の上に 14 出る。アイコンは丸のまんなかへ浮く
	bubble = Panel.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.size = Vector2(BUB, BUB)
	var bs := Tokens.round_box(Tokens.SELECT, int(BUB / 2), Tokens.CREAM, 3, 0)
	bs.shadow_color = Color(Tokens.SHADOW, 0.15)
	bs.shadow_size = 5
	bs.shadow_offset = Vector2(0, 3)
	bubble.add_theme_stylebox_override("panel", bs)
	nav.add_child(bubble)
	for i in TABS.size():
		_build_tab(TABS[i], i)
	_select(selected, false)


func _build_tab(id: String, i: int) -> void:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for k in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	b.position = Vector2(NAV_X + i * TAB_W, 0)
	b.size = Vector2(TAB_W, NAV_H + LIFT)
	b.tooltip_text = tr(TAB_KEYS[id])
	nav.add_child(b)
	tabs[id] = b
	var face := Control.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.size = b.size
	face.pivot_offset = Vector2(TAB_W / 2, LIFT + ICON_Y)
	b.add_child(face)
	faces[id] = face
	if id == "scoop":
		scoop_glow = Panel.new()
		scoop_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		scoop_glow.size = Vector2(54, 54)
		scoop_glow.position = Vector2(TAB_W / 2 - 27, LIFT + ICON_Y - 27)
		scoop_glow.add_theme_stylebox_override("panel", Tokens.round_box(Color(Tokens.BUTTER, 0.55), 27, Color(0, 0, 0, 0), 0, 0))
		scoop_glow.visible = false
		face.add_child(scoop_glow)
	var ic := TextureRect.new()
	ic.texture = ICONS[id]
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.size = Vector2(ICON_SEL, ICON_SEL)
	ic.pivot_offset = ic.size / 2
	face.add_child(ic)
	icons[id] = ic
	var l := Kit.text(tr(TAB_KEYS[id]), 11, Tokens.INK, true, HORIZONTAL_ALIGNMENT_CENTER)
	l.position = Vector2(0, LIFT + 60)
	l.size = Vector2(TAB_W, 16)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(l)
	labels[id] = l
	if id == "scoop":
		scoop_chip = PanelContainer.new()
		scoop_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cs := Tokens.round_box(Tokens.BUTTER, 7, Tokens.CREAM, 1, 0)
		cs.content_margin_left = 4
		cs.content_margin_right = 4
		scoop_chip.add_theme_stylebox_override("panel", cs)
		scoop_chip.add_child(Kit.text(tr("HUD_SCOOP_CHIP"), 9, Color("7a5a16"), true, HORIZONTAL_ALIGNMENT_CENTER))
		scoop_chip.position = Vector2(TAB_W / 2 + 4, LIFT + 6)
		face.add_child(scoop_chip)
	var bd := Badge.new()
	bd.position = Vector2(TAB_W / 2 + 12, LIFT + ICON_Y - 26)
	face.add_child(bd)
	badges[id] = bd
	b.button_down.connect(func(): _press(face, true))
	b.button_up.connect(func(): _press(face, false))
	b.pressed.connect(func(): _on_tab(id))


## 押したとき：0.92 に縮んで（70ms）、ばねのように戻る（140ms）
func _press(c: Control, down: bool) -> void:
	var tw := c.create_tween()
	if down:
		Sfx.press(c)
		tw.tween_property(c, "scale", Vector2(0.92, 0.92), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(c, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## タブをえらぶ：丸がそのタブへ動き、アイコンが少し大きくなって浮く（160ms）
func _select(id: String, anim := true) -> void:
	selected = id
	if _sel_tw:
		_sel_tw.kill()
	var i := TABS.find(id)
	var bx := NAV_X + (i + 0.5) * TAB_W - BUB / 2
	if anim:
		_sel_tw = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for t in TABS:
		var on: bool = t == id
		var ic: TextureRect = icons[t]
		var k := 1.0 if on else ICON / ICON_SEL
		var pos := Vector2(TAB_W / 2 - ICON_SEL / 2, (LIFT - BUB_UP + BUB / 2 - ICON_SEL / 2) if on else (LIFT + ICON_Y - ICON_SEL / 2))
		var col: Color = Tokens.SELECT_INK if on else Tokens.INK
		if anim:
			_sel_tw.tween_property(ic, "scale", Vector2(k, k), 0.16)
			_sel_tw.tween_property(ic, "position", pos, 0.16)
		else:
			ic.scale = Vector2(k, k)
			ic.position = pos
		(labels[t] as Label).add_theme_color_override("font_color", col)
	if anim:
		_sel_tw.tween_property(bubble, "position", Vector2(bx, LIFT - BUB_UP), 0.16)
	else:
		bubble.position = Vector2(bx, LIFT - BUB_UP)


func _on_tab(id: String) -> void:
	if not shown or garden == null:
		return
	if id == "island":
		_select("island")
		garden.recenter() # 島にいるときは、家の前へ（音も recenter が鳴らす）
		return
	Kit.play(self, "tap", 1.1)
	_select(id)
	await get_tree().create_timer(0.14).timeout
	if not is_inside_tree():
		return
	match id:
		"jobs":
			var desk = garden.desk()
			if desk:
				desk.open_work_menu()
		"scoop":
			garden.go_scoop()
		"closet":
			garden.main.go("wardrobe")
		"book":
			garden.main.go("zukan")
	# 島の上で開く物（しごとのシート）が閉じたら、島にもどす。ほかの画面へ行くなら、この HUD ごと消える
	await get_tree().create_timer(0.3).timeout
	if is_inside_tree() and shown:
		_select("island")


# ---------------------------------------------------------------- 上の段

func _build_top() -> void:
	top_row = Control.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.size = Vector2(360, 64)
	add_child(top_row)
	# 状態の札（ボタンの形にはしない。タップで育ちの欄）
	status_chip = Button.new()
	status_chip.focus_mode = Control.FOCUS_NONE
	status_chip.icon = LEAF
	status_chip.expand_icon = false
	status_chip.add_theme_constant_override("icon_max_width", 15)
	status_chip.add_theme_constant_override("h_separation", 5)
	status_chip.add_theme_font_override("font", Kit.black())
	status_chip.add_theme_font_size_override("font_size", 13)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		status_chip.add_theme_color_override(k, Tokens.INK)
	for k in ["normal", "hover", "pressed", "focus"]:
		var s := Tokens.round_box(Color(Tokens.CREAM, 0.88 if k != "pressed" else 1.0), 15, Color(0, 0, 0, 0), 0, 0)
		s.content_margin_left = 10
		s.content_margin_right = 12
		status_chip.add_theme_stylebox_override(k, s)
	status_chip.position = Vector2(12, 14)
	status_chip.custom_minimum_size = Vector2(0, 30)
	status_chip.pressed.connect(func():
		if garden:
			garden._toggle_meters())
	top_row.add_child(status_chip)
	# 丸いボタン（右から：マイページ・話す・めあて）
	var x := 360.0 - 12.0 - HIT
	for id in ["me", "talk", "goals"]:
		var b := _round_button(id, ICONS[id])
		b.position = Vector2(x, 12)
		x -= HIT + 4.0
		top_row.add_child(b)
		round_btns[id] = b
	round_btns.goals.pressed.connect(func():
		if garden:
			GameState.tut["goals_seen"] = "%d:%d" % [GameState.day, GameState.goals_done()]
			garden._toggle_goals()
			refresh())
	round_btns.talk.pressed.connect(func():
		GameState.tut["talk_seen"] = GameState.day
		var hub = garden.hub() if garden else null
		if hub:
			hub.talk()
		refresh())
	round_btns.me.pressed.connect(func():
		if garden:
			SettingsScreen.open(garden))
	goals_ring = Ring.new()
	goals_ring.size = Vector2(BTN, BTN)
	goals_ring.position = Vector2((HIT - BTN) / 2, (HIT - BTN) / 2)
	goals_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(round_btns.goals.get_meta("face") as Control).add_child(goals_ring)


## 丸いボタン（Ø41、押せる所は 44）：クリームの地・ふち 1・影 e1。アイコンだけ
func _round_button(id: String, tex: Texture2D) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	b.size = Vector2(HIT, HIT)
	b.tooltip_text = tr({"goals": "HUD_COACH_GOALS", "talk": "HUD_COACH_TALK", "me": "HUD_COACH_ME", "edit": "HUD_COACH_EDIT"}[id])
	var face := Control.new()
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.size = b.size
	face.pivot_offset = b.size / 2
	b.add_child(face)
	var disc := Panel.new()
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.size = Vector2(BTN, BTN)
	disc.position = Vector2((HIT - BTN) / 2, (HIT - BTN) / 2)
	var s := Tokens.round_box(Tokens.CREAM, int(BTN / 2), Tokens.EDGE, 1, 0)
	s.shadow_color = Color(Tokens.SHADOW, 0.16)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 3)
	disc.add_theme_stylebox_override("panel", s)
	face.add_child(disc)
	var ic := TextureRect.new()
	ic.texture = tex
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var isz := 30.0 if id == "me" else 27.0
	ic.size = Vector2(isz, isz)
	ic.position = (b.size - ic.size) / 2 + (Vector2(0, 1) if id == "me" else Vector2.ZERO)
	face.add_child(ic)
	var bd := Badge.new()
	bd.position = Vector2(HIT - 9, 5)
	face.add_child(bd)
	badges[id] = bd
	b.button_down.connect(func(): _press(face, true))
	b.button_up.connect(func(): _press(face, false))
	b.set_meta("face", face)
	return b


# ---------------------------------------------------------------- ✎（島をつくる）

func _build_fab() -> void:
	fab = _round_button("edit", ICONS.edit)
	add_child(fab)
	fab.pressed.connect(func():
		if garden:
			Kit.play(self, "tap", 1.1)
			garden._enter_edit())


# ---------------------------------------------------------------- 置き直し・出し入れ

func _layout() -> void:
	_fit_size()
	nav.position = Vector2(0, (nav_top() - LIFT) if shown else _h() + 12.0)
	fab.position = Vector2(360.0 - 12.0 - HIT + (HIT - BTN) / 2, card_bottom() - HIT + (HIT - BTN) / 2)


## 出す／引っこめる（下のタブは下へすべって 220ms。上の段と ✎ はうすくなって消える）
func set_shown(on: bool, anim := true) -> void:
	if on == shown:
		return
	shown = on
	if _tw:
		_tw.kill()
	var y := (nav_top() - LIFT) if on else _h() + 12.0
	if on:
		_select("island", false)
		for c in [top_row, fab]:
			c.visible = true
		fab.visible = _fab_wanted()
		_sync_round()
	if not anim:
		nav.position.y = y
		for c in [top_row, fab]:
			c.modulate.a = 1.0 if on else 0.0
			c.visible = c.visible and on
		return
	_tw = create_tween().set_parallel()
	_tw.tween_property(nav, "position:y", y, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if on else Tween.EASE_IN)
	for c in [top_row, fab]:
		_tw.tween_property(c, "modulate:a", 1.0 if on else 0.0, 0.16)
	if not on:
		_tw.chain().tween_callback(func():
			if not shown:
				top_row.visible = false
				fab.visible = false)


func _fab_wanted() -> bool:
	return GameState.day >= 1


func _sync_round() -> void:
	round_btns.goals.visible = GameState.day >= 2 # めあては 2 日目から
	round_btns.talk.visible = garden != null and garden.hub() != null


## 毎フレーム（庭の _process から）：出す・引っこめる、しるし（数字・点）を 0.5 秒ごとに
func sync(delta: float) -> void:
	var want: bool = garden != null and garden.hud_wanted()
	if want != shown:
		set_shown(want)
	_badge_t -= delta
	if _badge_t <= 0.0:
		_badge_t = 0.5
		refresh()


## 字としるしを、今の状態に合わせる
func refresh() -> void:
	var wd: String = tr(GameState.WEEKDAYS[GameState.weekday()])
	status_chip.text = tr("HUD_STATUS") % [wd, GameState.garden_level + 1]
	status_chip.size = Vector2(0, 30)
	if shown:
		_sync_round()
		fab.visible = _fab_wanted()
	var eve := GameState.phase == "evening" or GameState.ANYTIME
	var open_now := eve and not GameState.scooped_tonight
	(icons.scoop as TextureRect).modulate.a = 1.0 if eve else 0.6
	scoop_chip.visible = not eve
	if scoop_glow.visible != open_now:
		scoop_glow.visible = open_now
		if open_now:
			var tw := scoop_glow.create_tween().set_loops()
			scoop_glow.modulate.a = 0.35
			tw.tween_property(scoop_glow, "modulate:a", 1.0, 1.0).set_trans(Tween.TRANS_SINE)
			tw.tween_property(scoop_glow, "modulate:a", 0.35, 1.0).set_trans(Tween.TRANS_SINE)
	# しごと：新しい求人の数（知らせを Off にした人は出さない）。評価を待つシフトがあれば点
	var n := 0
	if JobPrefs.suggest_on() and Onboarding.at("done"):
		n = JobDesk.undecided().size() + Invites.pending().size()
	(badges.jobs as Badge).set_count(n if n > 0 else (0 if Reviews.pending().is_empty() else -1))
	(badges.closet as Badge).set_count(-1 if not Wardrobe.fresh.is_empty() else 0)
	(badges.scoop as Badge).set_count(0)
	(badges.book as Badge).set_count(0)
	(badges.island as Badge).set_count(0)
	# めあて：3 つの輪。まだ見ていない達成があれば数字
	var done := GameState.goals_done()
	goals_ring.done = done
	goals_ring.queue_redraw()
	var seen := String(GameState.tut.get("goals_seen", ""))
	var seen_n := int(seen.get_slice(":", 1)) if seen.begins_with("%d:" % GameState.day) else 0
	(badges.goals as Badge).set_count(maxi(0, done - seen_n))
	# 話す：その日まだ話していなければ点
	(badges.talk as Badge).set_count(-1 if int(GameState.tut.get("talk_seen", -1)) != GameState.day else 0)
	(badges.me as Badge).set_count(0)
	(badges.edit as Badge).set_count(-1 if garden != null and garden.expand_ready() else 0)


# ---------------------------------------------------------------- はじめて一度だけ：丸いボタンの名前

func _coach() -> void:
	if GameState.tut.has("hud_coach") or not shown or not Onboarding.at("done") or OS.get_environment("OBAKE_SHOT") != "":
		return
	GameState.tut["hud_coach"] = true
	coach = Control.new()
	coach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(coach)
	for id in ["goals", "talk", "me"]:
		var b: Button = round_btns[id]
		if not b.visible:
			continue
		var p := PanelContainer.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var s := Tokens.round_box(Tokens.INK, 10, Color(0, 0, 0, 0), 0, 1)
		s.content_margin_left = 7
		s.content_margin_right = 7
		s.content_margin_top = 2
		s.content_margin_bottom = 3
		p.add_theme_stylebox_override("panel", s)
		p.add_child(Kit.text(tr({"goals": "HUD_COACH_GOALS", "talk": "HUD_COACH_TALK", "me": "HUD_COACH_ME"}[id]), 11, Tokens.CREAM, true))
		coach.add_child(p)
		var bx := b.position.x + HIT / 2
		Kit.keep_fit(p, func():
			p.size = Vector2.ZERO
			p.position = Vector2(clampf(bx - p.size.x / 2, 8.0, 352.0 - p.size.x), 60.0 + float(p.get_index()) * 0.0))
	var tw := coach.create_tween()
	coach.modulate.a = 0.0
	tw.tween_property(coach, "modulate:a", 1.0, 0.25)
	tw.tween_interval(4.5)
	tw.tween_property(coach, "modulate:a", 0.0, 0.4)
	tw.tween_callback(coach.queue_free)


# ---------------------------------------------------------------- 部品

## しるし：数字（Ø15・赤・クリームのふち 2・白い字）か、点だけ（Ø9）。0 で消える
class Badge:
	extends Control
	var n := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false

	func set_count(v: int) -> void:
		if v == n and visible == (v != 0):
			return
		n = v
		visible = v != 0
		queue_redraw()

	func _draw() -> void:
		var r := 4.5 if n < 0 else 7.5
		draw_circle(Vector2.ZERO, r + 2.0, Tokens.CREAM, true, -1.0, true)
		draw_circle(Vector2.ZERO, r, Tokens.BADGE, true, -1.0, true)
		if n > 0:
			var f := Kit.black()
			var t := str(n) if n < 10 else "9+"
			var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			draw_string(f, Vector2(-w / 2, 3.4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)


## めあての 3 つの輪（達成した分は金色）
class Ring:
	extends Control
	var done := 0

	func _draw() -> void:
		var c := size / 2
		var r := size.x / 2 - 1.5
		for i in 3:
			var a0 := -PI / 2 + i * TAU / 3 + 0.16
			var a1 := a0 + TAU / 3 - 0.32
			draw_arc(c, r, a0, a1, 18, Tokens.GOLD if i < done else Tokens.EDGE, 3.0, true)
