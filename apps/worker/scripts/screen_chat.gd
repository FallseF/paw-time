class_name ScreenChat
extends Control
## Chats. thread = "me" (the private chat with your own cat), "shop:<shift id>" (your cat and the shop's cat),
## or "list" (your cat + a thread for each accepted shift).
## Works as a screen (main.go("chat"), OBAKE_CHAT picks the thread) and as an overlay (ChatHub.open(parent, thread)).
## Logic lives in ChatMe / ChatShops / ChatOutbox; this file only draws and animates.

const INK := Color("2a2233")
const SUB := Color("6a5f70")
const ORANGE := Color("ff8a5b")
const PURPLE := Color("6a5bd6")
const ME_BG := Color("8b7bff")
const BUBBLE_W := 262
const TYPING := 0.45

var main # set when this is a main screen
var screen_name := ""
var thread := ""
var _back_to: Array = [] # where the back button goes (threads opened from inside a chat)
var stage: ChatStage
var scroll: ScrollContainer
var log_box: VBoxContainer
var chip_box: HFlowContainer
var input: LineEdit
var menu: Control
var protect: Control
var held_note: Control
var busy := false
var _rendered := {} # shop: message index -> true
var _poll := 0.0


func _ready() -> void:
	# 360-wide fixed coordinates (same as the other screens). As an overlay on the island the height follows the
	# island (taller than 640 on tall phones): header at the top, the input at the bottom
	position = Vector2.ZERO
	size = Vector2(360, _h())
	mouse_filter = Control.MOUSE_FILTER_STOP
	if thread == "":
		thread = OS.get_environment("OBAKE_CHAT") if OS.get_environment("OBAKE_CHAT") != "" else "me"
	if OS.get_environment("OBAKE_CHAT_SEED") != "":
		seed_demo_shifts()
	if thread == "shop:next":
		var l := ChatShops.list()
		thread = l[0].id if not l.is_empty() else "list"
	_build()
	_opened()


## A chat with your cat or a shop was opened (the list is not counted)
func _opened() -> void:
	if thread == "me" or thread.begins_with("shop:"):
		Telemetry.track("chat_open", {"kind": "me" if thread == "me" else "shop"})


## Sample shifts for demos and screenshots (only when there are none): tomorrow at a café, yesterday at an izakaya
static func seed_demo_shifts() -> void:
	if not ChatShops.list().is_empty():
		return
	var now := ChatShops.now()
	var day0 := JobListings.day0(now)
	for d in [["demo_chat_next", "cafe_komorebi", "register", 1, 10], ["demo_chat_past", "izk_torimaru", "hall", -1, 17]]:
		var st: float = JobListings.at_hour(JobListings.next_day0(day0, int(d[3])), int(d[4]))
		var j := JobListings.demo_pay({"id": d[0], "listing": d[1], "role": d[2], "area": "shibuya", "start": st, "end": st + 4 * 3600, "pay": "weekly", "sample": true})
		JobListings.localize(j)
		Shifts.add(j)


static func cat_name() -> String:
	var gs := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("GameState")
	if gs and gs.my_obake.get("special", "") == "" and not SpecialObake.has_custom_name():
		var tid: String = gs.my_obake.get("type_id", "")
		if QuizData.TYPES.has(tid):
			return QuizData.type_name(tid)
	return SpecialObake.pet_name()


# ---------------------------------------------------------------- building

func _clear() -> void:
	for c in get_children():
		c.queue_free()
	stage = null
	menu = null
	protect = null
	held_note = null
	_rendered = {}


func _h() -> float:
	var p := get_parent() as Control
	return maxf(640.0, p.size.y) if p else 640.0


func _build() -> void:
	_clear()
	if thread != "me" and thread != "list" and not ChatShops.allowed(thread):
		thread = "list"
	var bg := ColorRect.new()
	bg.color = Color("fbf4ec") if thread == "me" else Color("f2f5fb")
	bg.size = Vector2(360, _h())
	add_child(bg)
	var v := VBoxContainer.new()
	v.position = Vector2.ZERO
	v.size = Vector2(360, _h())
	v.add_theme_constant_override("separation", 0)
	add_child(v)
	if thread == "list":
		_build_list(v)
		return
	var shop := thread != "me"
	var th := ChatShops.thread(thread) if shop else {}
	var shift := ChatShops.shift_of(thread) if shop else {}
	var title := cat_name() if not shop else String(shift.get("store", JobListings.store_name(th.shop_id)))
	var sub := mode_text() if not shop else JobListings.when_text(shift)
	if shop and ChatShops.swap_requested(thread):
		sub += "  ·  " + tr("CHAT_SWAP_BADGE")
	v.add_child(_header(title, sub, not shop))
	# the cats
	var top := Control.new()
	top.custom_minimum_size = Vector2(360, 140 if not shop else 122)
	v.add_child(top)
	stage = ChatStage.new("me" if not shop else "duo", String(th.get("shop_id", "")), top.custom_minimum_size)
	top.add_child(stage)
	if shop:
		_nameplate(top, tr("CHAT_YOU_VIA") % cat_name(), 14, ME_BG, false)
		_nameplate(top, tr("CHAT_SHOP_CAT") % title, 346, ChatShops.sign_color(th.shop_id), true)
		var pb := _link(tr("CHAT_PROTECT_LINK"), _toggle_protect, Color("3b7a57"), 12)
		pb.custom_minimum_size = Vector2(0, 20)
		v.add_child(pb)
	# messages
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(scroll)
	v.add_child(scroll)
	var pad := MarginContainer.new()
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in ["margin_left", "margin_right"]:
		pad.add_theme_constant_override(k, 12)
	pad.add_theme_constant_override("margin_top", 6)
	pad.add_theme_constant_override("margin_bottom", 8)
	scroll.add_child(pad)
	log_box = VBoxContainer.new()
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_box.add_theme_constant_override("separation", 8)
	pad.add_child(log_box)
	# quick replies + free text
	var cp := MarginContainer.new()
	for k in ["margin_left", "margin_right"]:
		cp.add_theme_constant_override(k, 10)
	cp.add_theme_constant_override("margin_top", 6)
	v.add_child(cp)
	chip_box = HFlowContainer.new()
	chip_box.add_theme_constant_override("h_separation", 5)
	chip_box.add_theme_constant_override("v_separation", 5)
	cp.add_child(chip_box)
	v.add_child(_input_row(shop))
	if shop:
		_render_shop(false)
	else:
		var first := ChatMe.start()
		_render_me_all()
		if not first.is_empty():
			stage.mood("me", first[-1].get("mood", "happy"))
		else:
			var h := ChatMe.history()
			stage.mood("me", h[-1].get("mood", "calm") if not h.is_empty() else "calm")
	_refresh_chips()
	_scroll_end()
	if not shop and ChatMe.needs_consent():
		_consent_card()


## The header line of the chat with your cat: what your cat does with the chat
static func mode_text() -> String:
	return I18n.t("CHAT_MODE_PRIVATE") if ChatMe.is_private() else I18n.t("CHAT_MODE_SHARED")


## First open: say in one or two lines what your cat remembers, and let the worker choose "Just between us".
## The full text is in My page ("Details" opens it at Privacy)
func _consent_card() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.1, 0.2, 0.55)
	dim.size = Vector2(360, _h())
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color.WHITE, 22, 0.2, Vector2(18, 14)))
	p.position = Vector2(24, 180)
	p.size = Vector2(312, 0)
	dim.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var t := I18n.wrap(Kit.text(tr("CHAT_CONSENT_TITLE"), 17, INK, true))
	t.custom_minimum_size = Vector2(276, 0)
	v.add_child(t)
	# 1〜2 行だけ。くわしい説明はマイページのプライバシー（「くわしく」）
	var b := I18n.wrap(Kit.text(tr("CHAT_CONSENT_BODY"), 14, SUB))
	b.custom_minimum_size = Vector2(276, 0)
	v.add_child(b)
	var pick := func(private: bool):
		ChatMe.set_consent(private)
		dim.queue_free()
		_build()
	v.add_child(Kit.button(tr("CHAT_CONSENT_OK"), PURPLE, pick.bind(false), Color.WHITE, 42, 15))
	v.add_child(_link(tr("CHAT_CONSENT_PRIVATE"), pick.bind(true), Color("3b7a57"), 14))
	var more := _link(tr("CHAT_CONSENT_DETAILS") + " ›", func(): SettingsScreen.open(self, "privacy"), SUB, 12)
	more.custom_minimum_size.y = 28
	v.add_child(more)
	Kit.keep_fit(p, func():
		p.size.y = 0
		p.position.y = (_h() - p.size.y) / 2.0)


func _header(title: String, sub: String, private: bool) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.9), 0, 0.08, Vector2(8, 6)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	p.add_child(h)
	var back := _link("‹", _back, INK, 26)
	back.custom_minimum_size = Vector2(36, 40)
	h.add_child(back)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tl := Kit.text(title, 17, INK, true)
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tl.clip_text = true
	tv.add_child(tl)
	var sl := Kit.text(sub, 11, Color("3b7a57") if private else SUB)
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sl.clip_text = true
	tv.add_child(sl)
	h.add_child(tv)
	var mb := _link("•••", _toggle_menu, SUB, 16)
	mb.custom_minimum_size = Vector2(44, 40)
	h.add_child(mb)
	return p


func _nameplate(parent: Control, t: String, x: float, c: Color, right: bool) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(c, 10, 0.0, Vector2(8, 1)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(Kit.text(t, 11, Color.WHITE, true))
	p.position = Vector2(x, parent.custom_minimum_size.y - 22)
	parent.add_child(p)
	await get_tree().process_frame
	if is_instance_valid(p) and right:
		p.position.x = x - p.size.x


func _input_row(shop: bool) -> Control:
	var m := MarginContainer.new()
	for k in ["margin_left", "margin_right"]:
		m.add_theme_constant_override(k, 10)
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 10)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	m.add_child(h)
	input = LineEdit.new()
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.custom_minimum_size = Vector2(0, 38)
	input.placeholder_text = tr("CHAT_INPUT_SHOP") if shop else tr("CHAT_INPUT_ME")
	input.add_theme_font_override("font", Kit.bold())
	input.add_theme_font_size_override("font_size", 14)
	input.add_theme_color_override("font_color", INK)
	input.add_theme_color_override("font_placeholder_color", Color("a79daa"))
	input.add_theme_stylebox_override("normal", Kit.pill(Color.WHITE, 19, 0.06, Vector2(14, 4)))
	input.add_theme_stylebox_override("focus", Kit.pill(Color.WHITE, 19, 0.1, Vector2(14, 4)))
	input.max_length = 200
	input.text_submitted.connect(func(_t): _send_text())
	h.add_child(input)
	var send := Kit.button(tr("CHAT_SEND"), PURPLE, _send_text, Color.WHITE, 38, 14)
	send.custom_minimum_size.x = 64
	h.add_child(send)
	return m


# ---------------------------------------------------------------- bubbles

func _bubble(text: String, mine: bool, caption := "") -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	var row := HBoxContainer.new()
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var p := PanelContainer.new()
	var st := Kit.pill(ME_BG if mine else Color.WHITE, 16, 0.08, Vector2(12, 7))
	if mine:
		st.corner_radius_bottom_right = 4
	else:
		st.corner_radius_bottom_left = 4
	p.add_theme_stylebox_override("panel", st)
	var l := Kit.text(text, 14, Color.WHITE if mine else INK)
	var w := Kit.bold().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 4
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(minf(w, BUBBLE_W), 0)
	p.add_child(l)
	if mine:
		row.add_child(sp)
		row.add_child(p)
	else:
		row.add_child(p)
		row.add_child(sp)
	col.add_child(row)
	if caption != "":
		var cr := HBoxContainer.new()
		cr.alignment = BoxContainer.ALIGNMENT_END if mine else BoxContainer.ALIGNMENT_BEGIN
		cr.add_theme_constant_override("separation", 8)
		cr.add_child(Kit.text(caption, 10, SUB))
		col.add_child(cr)
	log_box.add_child(col)
	_pop(p, mine)
	return col


func _pop(c: Control, right: bool) -> void:
	c.modulate.a = 0.0
	await get_tree().process_frame
	if not is_instance_valid(c):
		return
	c.pivot_offset = Vector2(c.size.x if right else 0.0, c.size.y)
	c.scale = Vector2(0.85, 0.85)
	var tw := c.create_tween().set_parallel()
	tw.tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, 0.12)


func _typing() -> Control:
	var b := _bubble("• • •", false)
	return b


func _card_panel(bg: Color) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(bg, 16, 0.1, Vector2(14, 10)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	log_box.add_child(p)
	return v


func _wrap_text(t: String, size: int, c: Color, heavy := false) -> Label:
	var l := I18n.wrap(Kit.text(t, size, c, heavy))
	l.custom_minimum_size = Vector2(300, 0)
	return l


func _scroll_end() -> void:
	for i in 3:
		await get_tree().process_frame
	if is_instance_valid(scroll):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


# ---------------------------------------------------------------- my cat

func _render_me_all() -> void:
	for c in log_box.get_children():
		c.queue_free()
	var h := ChatMe.history()
	for i in h.size():
		_render_me(h[i], i)


func _render_me(m: Dictionary, index: int) -> void:
	_bubble(ChatMe.text_of(m), m.who == "me")
	var card: Dictionary = m.get("card", {})
	match card.get("kind", ""):
		"tell":
			_tell_card(card, index)
		"crisis":
			_crisis_card()


func _tell_card(card: Dictionary, index: int) -> void:
	var v := _card_panel(Color("fff8ef"))
	if card.shop_id != "":
		if card.done == "":
			v.add_child(Kit.button(tr("CHAT_TELL_YES"), ORANGE, func(): _answer(index, "yes"), Color.WHITE, 40, 14))
			v.add_child(_link(tr("CHAT_TELL_NO"), func(): _answer(index, "no"), SUB, 13))
		else:
			v.add_child(_wrap_text(tr("CHAT_TELL_DONE_YES") if card.done == "yes" else tr("CHAT_TELL_DONE_NO"), 12, Color("3b7a57"), true))
	if card.support:
		if card.support_done:
			v.add_child(_wrap_text(tr("CHAT_SUPPORT_DONE"), 12, Color("3b7a57"), true))
		else:
			var sb := _link(tr("CHAT_SUPPORT"), func(): _answer(index, "support"), PURPLE, 13)
			v.add_child(sb)
	v.add_child(_wrap_text(tr("CHAT_TELL_NOTE"), 10, SUB))


func _crisis_card() -> void:
	var v := _card_panel(Color("eef6ff"))
	v.add_child(_wrap_text(tr("CHAT_CRISIS_TITLE"), 15, INK, true))
	v.add_child(_wrap_text(tr("CHAT_CRISIS_BODY"), 12, SUB))
	v.add_child(Kit.button(tr("CHAT_CRISIS_OPEN"), Color("3b6fd6"), ChatMe.open_resources, Color.WHITE, 40, 14))
	v.add_child(_wrap_text(tr("CHAT_CRISIS_NOTE"), 11, SUB))


func _pick_me(chip: String) -> void:
	if busy:
		return
	if chip == "ask_shop":
		_open_thread("shop:next")
		return
	await _play_me(ChatMe.pick(chip))


func _answer(index: int, choice: String) -> void:
	if busy:
		return
	var out := ChatMe.answer(index, choice)
	if out.is_empty():
		return
	busy = true
	_render_me_all()
	busy = false
	stage.mood("me", out[-1].get("mood", "proud"))
	Kit.play(self, "chime", 1.1, -6)
	_refresh_chips()
	_scroll_end()


func _play_me(out: Array) -> void:
	if out.is_empty():
		return
	busy = true
	_refresh_chips()
	var start := ChatMe.history().size() - out.size()
	for i in out.size():
		var m: Dictionary = out[i]
		if m.who == "cat":
			var t := _typing()
			_scroll_end()
			await get_tree().create_timer(TYPING).timeout
			if not is_instance_valid(t):
				return
			t.queue_free()
			stage.mood("me", m.get("mood", "calm"))
		_render_me(m, start + i)
		Kit.play(self, "pop", 1.0 if m.who == "cat" else 1.2, -8)
		_scroll_end()
	busy = false
	_refresh_chips()


# ---------------------------------------------------------------- shop

## Draw the shop messages you can see now (animated = typing dots before the shop's lines)
func _render_shop(animated: bool) -> void:
	var th := ChatShops.thread(thread)
	var t := ChatShops.now()
	var new_ones: Array = []
	for i in th.messages.size():
		var m: Dictionary = th.messages[i]
		if not _rendered.has(i) and float(m.get("deliver_at", 0)) <= t:
			new_ones.append(i)
	if new_ones.is_empty():
		_update_held()
		return
	busy = animated
	for i in new_ones:
		_rendered[i] = true
		var m: Dictionary = th.messages[i]
		if animated and m.who == "shop":
			var ty := _typing()
			_scroll_end()
			await get_tree().create_timer(TYPING).timeout
			if not is_instance_valid(ty):
				return
			ty.queue_free()
		_shop_bubble(m, i)
		if m.who == "shop" and stage:
			stage.talk("shop")
			stage.mood("shop", "happy" if m.kind != "staff" else "proud")
		if animated:
			Kit.play(self, "pop", 1.0 if m.who == "shop" else 1.2, -8)
	busy = false
	_update_held()
	_refresh_chips()
	_scroll_end()


func _shop_bubble(m: Dictionary, index: int) -> void:
	var mine: bool = m.who == "me"
	var cap := ""
	if mine:
		cap = (tr("CHAT_NICE") if m.get("nice", false) else tr("CHAT_RELAYED")) % cat_name()
	elif m.kind == "staff":
		cap = tr("CHAT_FROM_STAFF")
		if float(m.deliver_at) > float(m.t) + 1.0:
			cap += "  ·  " + tr("CHAT_DELIVERED_AT") % ChatShops.clock_text(float(m.deliver_at))
	else:
		# answers from the shop's info vs. the shop cat's own little replies ("I'll ask the manager")
		var k0 := String(m.get("parts", [[""]])[0][0])
		cap = tr("CHAT_AUTO") if k0.get_slice("_", 1) in ["WEAR", "DOOR", "BREAK"] else tr("CHAT_AUTO_CAT")
	var col := _bubble(ChatShops.text_of(m), mine, cap)
	if not mine and m.kind == "staff":
		if m.get("reported", false):
			col.get_child(-1).add_child(Kit.text(tr("CHAT_REPORTED"), 10, Color("b0463b")))
		else:
			var r := _link(tr("CHAT_REPORT"), func():
				ChatShops.report(thread, index)
				r_done(col), Color("b0463b"), 10)
			r.custom_minimum_size = Vector2(0, 16)
			col.get_child(-1).add_child(r)


func r_done(col: VBoxContainer) -> void:
	var cr := col.get_child(-1)
	cr.get_child(-1).queue_free()
	cr.add_child(Kit.text(tr("CHAT_REPORTED"), 10, Color("b0463b")))


func _update_held() -> void:
	if held_note and is_instance_valid(held_note):
		held_note.queue_free()
		held_note = null
	var h := ChatShops.held(thread)
	if h.is_empty():
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color("e7ecf7"), 14, 0.0, Vector2(12, 7)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	p.add_child(v)
	var l := I18n.wrap(Kit.text(tr("CHAT_HELD") % ChatShops.clock_text(float(h[0].deliver_at)), 12, Color("3b5ba5"), true, HORIZONTAL_ALIGNMENT_CENTER))
	l.custom_minimum_size = Vector2(300, 0)
	v.add_child(l)
	var l2 := I18n.wrap(Kit.text(tr("CHAT_HELD_WHY"), 10, SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
	l2.custom_minimum_size = Vector2(300, 0)
	v.add_child(l2)
	log_box.add_child(p)
	held_note = p


func _pick_shop(chip: String, text := "") -> void:
	if busy:
		return
	var out := ChatShops.ask(thread, chip, text)
	if out.is_empty():
		return
	if chip == "swap":
		_build() # the header shows "swap requested"
		return
	await _render_shop(true)


func _process(delta: float) -> void:
	if thread.begins_with("shop:") and log_box and not busy:
		_poll += delta
		if _poll > 0.5:
			_poll = 0.0
			_render_shop(true)


# ---------------------------------------------------------------- chips and text

func _refresh_chips() -> void:
	if chip_box == null or not is_instance_valid(chip_box):
		return
	for c in chip_box.get_children():
		c.queue_free()
	var ids: Array = ChatMe.chips() if thread == "me" else ChatShops.CHIPS
	for id in ids:
		var label := ChatMe.chip_label(id) if thread == "me" else tr("CS_CHIP_" + String(id).to_upper())
		var b := Button.new()
		b.text = label
		b.custom_minimum_size = Vector2(0, 29)
		b.disabled = busy
		b.add_theme_font_override("font", Kit.black())
		b.add_theme_font_size_override("font_size", 12)
		var crisis: bool = String(id).begins_with("crisis")
		var bgc := Color("fff") if not crisis else Color("eef6ff")
		for k in ["normal", "hover", "focus"]:
			b.add_theme_stylebox_override(k, Kit.pill(bgc, 16, 0.06, Vector2(10, 2)))
		b.add_theme_stylebox_override("pressed", Kit.pill(Color("ece6ff"), 16, 0.0, Vector2(10, 2)))
		b.add_theme_stylebox_override("disabled", Kit.pill(Color(1, 1, 1, 0.5), 16, 0.0, Vector2(10, 2)))
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, PURPLE)
		b.add_theme_color_override("font_disabled_color", Color("b8b0c8"))
		b.pressed.connect(func():
			Kit.play(self, "tap", 1.1)
			if thread == "me":
				_pick_me(id)
			else:
				_pick_shop(id))
		chip_box.add_child(b)


func _send_text() -> void:
	if busy or input == null:
		return
	var t := input.text.strip_edges()
	if t == "":
		return
	input.text = ""
	if thread == "me":
		await _play_me(ChatMe.say_text(t))
	else:
		await _pick_shop("", t)


# ---------------------------------------------------------------- menu, protection note, list

func _toggle_menu() -> void:
	if menu and is_instance_valid(menu):
		menu.queue_free()
		menu = null
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color.WHITE, 16, 0.2, Vector2(10, 8)))
	p.position = Vector2(150, 50)
	p.size = Vector2(200, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	if thread == "me":
		v.add_child(_link(tr("CHAT_MENU_SHOPS"), func(): _open_thread("list"), INK, 14))
		# 「ふたりだけのひみつ」：オンのあいだは、相棒は何も覚えず、何も送らない
		v.add_child(_link(tr("CHAT_MENU_PRIVATE_ON") if ChatMe.is_private() else tr("CHAT_MENU_PRIVATE_OFF"), func():
			ChatMe.set_private(not ChatMe.is_private())
			_build(), Color("3b7a57"), 14))
		v.add_child(_link(tr("CHAT_MENU_DELETE"), _confirm_delete, Color("b0463b"), 14))
	else:
		v.add_child(_link(tr("CHAT_MENU_ALL"), func(): _open_thread("list"), INK, 14))
		v.add_child(_link(tr("CHAT_PROTECT_LINK"), func():
			_toggle_menu()
			_toggle_protect(), INK, 14))
	v.add_child(_link(tr("CHAT_CLOSE"), _toggle_menu, SUB, 14))
	add_child(p)
	menu = p


func _confirm_delete() -> void:
	_toggle_menu()
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.1, 0.2, 0.55)
	dim.size = Vector2(360, _h())
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color.WHITE, 22, 0.2, Vector2(18, 14)))
	p.position = Vector2(24, 220)
	p.size = Vector2(312, 0)
	dim.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var t := I18n.wrap(Kit.text(tr("CHAT_DELETE_TITLE"), 17, INK, true))
	t.custom_minimum_size = Vector2(276, 0)
	v.add_child(t)
	var b := I18n.wrap(Kit.text(tr("CHAT_DELETE_BODY"), 13, SUB))
	b.custom_minimum_size = Vector2(276, 0)
	v.add_child(b)
	v.add_child(Kit.button(tr("CHAT_DELETE_YES"), Color("d9534f"), func():
		ChatMe.clear()
		_build(), Color.WHITE, 42, 15))
	v.add_child(_link(tr("CHAT_DELETE_NO"), dim.queue_free, SUB, 14))


func _toggle_protect() -> void:
	if protect and is_instance_valid(protect):
		protect.queue_free()
		protect = null
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color("f1f8f2"), 18, 0.2, Vector2(16, 12)))
	p.position = Vector2(16, 214)
	p.size = Vector2(328, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var t := I18n.wrap(Kit.text(tr("CHAT_PROTECT_TITLE"), 15, Color("2f6b4a"), true))
	t.custom_minimum_size = Vector2(296, 0)
	v.add_child(t)
	for i in 4:
		var l := I18n.wrap(Kit.text("· " + tr("CHAT_PROTECT_%d" % (i + 1)), 12, INK))
		l.custom_minimum_size = Vector2(296, 0)
		v.add_child(l)
	v.add_child(_link(tr("CHAT_CLOSE"), _toggle_protect, SUB, 13))
	add_child(p)
	protect = p


func _build_list(v: VBoxContainer) -> void:
	v.add_child(_header(tr("CHAT_LIST_TITLE"), tr("CHAT_LIST_SUB"), false))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(sc)
	v.add_child(sc)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for k in ["margin_left", "margin_right", "margin_top"]:
		m.add_theme_constant_override(k, 14)
	sc.add_child(m)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	m.add_child(box)
	box.add_child(_row(cat_name(), mode_text(), ME_BG, tr("CHAT_TALK"), func(): _open_thread("me")))
	var list := ChatShops.list()
	box.add_child(Kit.text(tr("CHAT_LIST_SHIFTS"), 13, SUB, true))
	if list.is_empty():
		var l := I18n.wrap(Kit.text(tr("CHAT_LIST_NONE"), 13, SUB))
		l.custom_minimum_size = Vector2(320, 0)
		box.add_child(l)
	var now_id := ChatShops.thread_id_for(Shifts.current(ChatShops.now()))
	for th in list:
		var s: Dictionary = th.shift
		var sub := JobListings.when_text(s)
		if th.id == now_id:
			sub = tr("CHAT_NOW") + "  ·  " + sub
		elif th.past:
			sub = tr("CHAT_PAST") + "  ·  " + sub
		if ChatShops.swap_requested(th.id):
			sub += "  ·  " + tr("CHAT_SWAP_BADGE")
		var tid: String = th.id
		box.add_child(_row(String(s.get("store", "")), sub, ChatShops.sign_color(String(s.listing)), tr("CHAT_ASK_SHOP"), func(): _open_thread(tid)))
	var note := I18n.wrap(Kit.text(tr("CHAT_LIST_NOTE"), 11, SUB))
	note.custom_minimum_size = Vector2(320, 0)
	box.add_child(note)


func _row(title: String, sub: String, c: Color, btn: String, cb: Callable) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color.WHITE, 16, 0.08, Vector2(12, 8)))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(26, 26)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ds := StyleBoxFlat.new()
	ds.bg_color = c
	ds.set_corner_radius_all(13)
	dot.add_theme_stylebox_override("panel", ds)
	h.add_child(dot)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tl := Kit.text(title, 14, INK, true)
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tl.clip_text = true
	v.add_child(tl)
	var sl := Kit.text(sub, 11, SUB)
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sl.clip_text = true
	v.add_child(sl)
	h.add_child(v)
	var b := Kit.button(btn, PURPLE, cb, Color.WHITE, 32, 12)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return p


func _open_thread(t: String) -> void:
	_back_to.append(thread)
	thread = t
	if thread == "shop:next":
		var l := ChatShops.list().filter(func(x): return not x.past)
		thread = l[0].id if not l.is_empty() else "list"
	busy = false
	_build()
	_opened()


func _back() -> void:
	if not _back_to.is_empty():
		thread = _back_to.pop_back()
		busy = false
		_build()
		return
	close()


func close() -> void:
	if main:
		main.go("garden")
	else:
		queue_free()


func _link(t: String, cb: Callable, color := SUB, fs := 14) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.custom_minimum_size = Vector2(0, 34)
	b.add_theme_font_override("font", Kit.black())
	b.add_theme_font_size_override("font_size", fs)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, color)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(func():
		Kit.play(self, "tap", 1.1)
		cb.call())
	return b


# ---------------------------------------------------------------- for screenshots (OBAKE_SHOT call:)

func demo_today() -> void:
	await _pick_me("today")
	await _pick_me("today_good")


func demo_problem() -> void:
	await _pick_me("problem")
	await _pick_me("prob_yelled")


func demo_tell_yes() -> void:
	var h := ChatMe.history()
	for i in range(h.size() - 1, -1, -1):
		if h[i].get("card", {}).get("kind", "") == "tell":
			_answer(i, "yes")
			return


func demo_crisis() -> void:
	input.text = "I want to disappear" if Kit.is_en() else "消えたい"
	await _send_text()


func demo_wear() -> void:
	await _pick_shop("wear")


func demo_entrance() -> void:
	await _pick_shop("entrance")


func demo_other() -> void:
	input.text = tr("CHAT_DEMO_Q")
	await _send_text()


func demo_late() -> void:
	await _pick_shop("late")


func demo_swap() -> void:
	await _pick_shop("swap")


func demo_protect() -> void:
	_toggle_protect()


func demo_list() -> void:
	_open_thread("list")


func demo_menu() -> void:
	_toggle_menu()


func demo_tired() -> void:
	await _pick_me("tired")
