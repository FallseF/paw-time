extends Control
## キセカエの部屋。大きなおばけが回り台に立ち、場所のタブと、服の並びから選ぶ。
## 選ぶと、持っていない服もその場で試着できる。持っている服だけを「保存」で着る。
## お店の服は肉球コインで買う。特別な棚（premium）は見本で、押すと「準備中」を出す。

var main

const BG := Color("f6efe6")
const INK := Color("2a2233")
const SUB := Color("8a7a88")
const ACCENT := Color("ff8a5b")
const GOLD := Color("e8a317")

var who_list: Array = []
var who_i := 0
var draft := {} # いま試している姿 {slot: id}（体の色は変えない：猫はそれぞれの色のまま）
var slot := "head"
var selected := ""

var vp: SubViewport
var world: Node3D
var stand: Node3D
var ob: Obake3D
var yaw := 0.4
var drag_x := -1.0
var spin_hold := 0.0

var who_label: Label
var coin_label: Label
var tabs: HBoxContainer
var grid: GridContainer
var scroll: ScrollContainer
var info_label: Label
var action_btn: Button
var note_label: Label
var popup: Control

# 服の小さな絵（1 回だけ撮って使い回す）
static var thumbs := {}
var thumb_vp: SubViewport
var thumb_world: Node3D
var thumb_cam: Camera3D
var thumb_queue: Array = []
var thumb_busy := false
var cards := {}


func _ready() -> void:
	_demo_setup()
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	who_list = []
	var gs = _gs()
	if gs and not gs.my_obake.is_empty():
		who_list.append("my")
	if gs:
		for o in gs.owned:
			if not who_list.has(o.id):
				who_list.append(o.id)
	if who_list.is_empty():
		who_list.append("receipt")
	var got := Wardrobe.check_unlocks()
	_build_stage()
	_build_ui()
	_load_who()
	_build_thumb_stage()
	if not got.is_empty():
		OutfitReveal.open(self, got[0], who_list[0])


func _gs():
	return get_tree().root.get_node_or_null("GameState")


# ---------------------------------------------------------------- 回り台

func _build_stage() -> void:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.position = Vector2(0, 84)
	box.size = Vector2(360, 262)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.gui_input.connect(_on_stage_input)
	add_child(box)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	View3D.fit(box, vp)
	world = Node3D.new()
	vp.add_child(world)
	# 透明な SubViewport でキーライトの影を付けると、AAA の体が白く飛ぶ（2026-09 確認）。影なしにする
	Look.apply(world, "studio", Color(0, 0, 0, 0), true, false)
	var cam := Camera3D.new()
	cam.fov = 30
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.45, 4.3), Vector3(0, 0.66, 0))
	# 回り台（丸い台）
	var plate := MeshInstance3D.new()
	plate.mesh = Obake3D.lathe(0.95, 1.0, 0.12, 48, 0.04)
	plate.material_override = Obake3D.prop(Color("e6d3bb"), 0.2)
	plate.position = Vector3(0, -0.06, 0)
	world.add_child(plate)
	var rim := MeshInstance3D.new()
	rim.mesh = Obake3D.lathe(1.02, 1.02, 0.04, 48, 0.01)
	rim.material_override = Obake3D.prop(Color("ff8a5b"), 0.2)
	rim.position = Vector3(0, -0.1, 0)
	world.add_child(rim)
	stand = Node3D.new()
	world.add_child(stand)


func _on_stage_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		drag_x = e.position.x if e.pressed else -1.0
	elif e is InputEventMouseMotion and drag_x >= 0.0:
		yaw += (e.position.x - drag_x) * 0.012
		drag_x = e.position.x
		spin_hold = 3.0


func _process(delta: float) -> void:
	spin_hold -= delta
	if spin_hold <= 0.0 and drag_x < 0.0:
		yaw += delta * 0.5
	stand.rotation.y = yaw
	_pump_thumbs()


func _rebuild_obake() -> void:
	if ob and is_instance_valid(ob):
		ob.queue_free()
	ob = Outfit.make(who_list[who_i], draft)
	ob.scale = Vector3.ONE * (1.05 if Rares.is_rare(who_list[who_i]) else 1.25)
	stand.add_child(ob)


# ---------------------------------------------------------------- 画面

func _build_ui() -> void:
	var top := HBoxContainer.new()
	top.position = Vector2(12, 12)
	top.size = Vector2(336, 40)
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	var back := Kit.button(tr("Done"), Color.WHITE, _back, INK, 38, 14)
	back.custom_minimum_size.x = 70
	top.add_child(back)
	var t := Kit.text(tr("Wardrobe"), 20, INK, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(t)
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", Kit.pill(Color.WHITE, 18, 0.08, Vector2(12, 6)))
	coin_label = Kit.text("", 13, GOLD, true)
	cp.add_child(coin_label)
	top.add_child(cp)

	var wr := HBoxContainer.new()
	wr.position = Vector2(40, 56)
	wr.size = Vector2(280, 30)
	wr.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(wr)
	var lb := _arrow("<", func(): _step_who(-1))
	wr.add_child(lb)
	who_label = Kit.text("", 13, INK, true, HORIZONTAL_ALIGNMENT_CENTER)
	who_label.custom_minimum_size = Vector2(190, 28)
	who_label.clip_text = true
	wr.add_child(who_label)
	wr.add_child(_arrow(">", func(): _step_who(1)))

	tabs = HBoxContainer.new()
	tabs.position = Vector2(8, 348)
	tabs.size = Vector2(344, 32)
	tabs.add_theme_constant_override("separation", 4)
	add_child(tabs)

	scroll = ScrollContainer.new()
	scroll.position = Vector2(8, 384)
	scroll.size = Vector2(344, 168)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.enable(scroll)
	add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)

	info_label = Kit.text("", 12, SUB, false, HORIZONTAL_ALIGNMENT_CENTER)
	info_label.position = Vector2(8, 554)
	info_label.size = Vector2(344, 20)
	add_child(info_label)

	var row := HBoxContainer.new()
	row.position = Vector2(12, 578)
	row.size = Vector2(336, 48)
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var rnd := Kit.button(tr("Random"), Color.WHITE, _randomize, INK, 46, 14)
	rnd.custom_minimum_size.x = 86
	row.add_child(rnd)
	action_btn = Kit.button("", ACCENT, _on_action, Color.WHITE, 46, 14)
	action_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 英語の長い文（Pick something to try など）でも横にはみ出さないよう、2 行まで折り返す
	action_btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	action_btn.custom_minimum_size.x = 120
	row.add_child(action_btn)
	var sv := Kit.button(tr("Save"), Color("8b7bff"), _save, Color.WHITE, 46, 15)
	sv.custom_minimum_size.x = 86
	row.add_child(sv)


func _arrow(t: String, cb: Callable) -> Button:
	var b := Kit.button(t, Color(1, 1, 1, 0.9), cb, INK, 30, 15)
	b.custom_minimum_size.x = 40
	return b


func _step_who(d: int) -> void:
	who_i = posmod(who_i + d, who_list.size())
	_load_who()


func _load_who() -> void:
	var id: String = who_list[who_i]
	draft = Wardrobe.outfit_of(id).duplicate()
	who_label.text = _who_name(id)
	selected = ""
	_build_tabs()
	_rebuild_obake()
	_fill_grid()


func _who_name(id: String) -> String:
	var gs = _gs()
	if id == "my" and gs and not gs.my_obake.is_empty():
		# とくべつな子は呼び名で、そうでなければタイプの名前（どちらも strings.csv）
		if gs.my_obake.get("special", "") != "" or SpecialObake.has_custom_name():
			return SpecialObake.pet_name() # 自分でつけた名前も、ここから
		return QuizData.type_name(gs.my_obake.type_id) if QuizData.TYPES.has(gs.my_obake.get("type_id", "")) else tr("Your cat obake")
	return tr(gs.info(id).name) if gs else id


func _build_tabs() -> void:
	for c in tabs.get_children():
		c.queue_free()
	var list: Array = WardrobeData.SLOTS.duplicate()
	for s in list:
		var on: bool = s == slot
		var name: String = tr(WardrobeData.SLOT_NAME[s])
		var b := Kit.button(name, ACCENT if on else Color.WHITE, func():
			slot = s
			selected = ""
			_build_tabs()
			_fill_grid(), Color.WHITE if on else INK, 30, 11)
		for k in ["normal", "hover", "pressed", "focus", "disabled"]:
			var st := b.get_theme_stylebox(k).duplicate() as StyleBoxFlat
			st.content_margin_left = 3
			st.content_margin_right = 3
			b.add_theme_stylebox_override(k, st)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(b)


# ---------------------------------------------------------------- 並び

func _fill_grid() -> void:
	for c in grid.get_children():
		c.queue_free()
	cards.clear()
	coin_label.text = tr("%d Paw Coins") % Wallet.balance()
	grid.add_child(_none_card())
	var items: Array = WardrobeData.in_slot(slot)
	# 持っている → お店 → まだ → 特別な棚 の順
	items.sort_custom(func(a, b): return _order(a) < _order(b))
	for it in items:
		var c := _card(it)
		grid.add_child(c)
		cards[it.id] = c
	_update_action()


func _order(it: Dictionary) -> int:
	if Wardrobe.has(it.id):
		return 0
	match WardrobeData.kind(it):
		"shop":
			return 1
		"premium":
			return 3
	return 2


func _card_style(on: bool, border: Color) -> StyleBoxFlat:
	var s := Kit.pill(Color.WHITE, 14, 0.06, Vector2(4, 4))
	s.border_color = ACCENT if on else border
	s.set_border_width_all(3 if on else (2 if border.a > 0 else 0))
	return s


func _none_card() -> Control:
	var on: bool = not draft.has(slot)
	var b := Button.new()
	b.custom_minimum_size = Vector2(81, 88)
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, _card_style(on, Color(0, 0, 0, 0)))
	var l := Kit.text(tr("None"), 13, SUB, true, HORIZONTAL_ALIGNMENT_CENTER)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(l)
	b.pressed.connect(func():
		Kit.play(self, "tap")
		draft.erase(slot)
		selected = ""
		_rebuild_obake()
		_fill_grid())
	return b


func _card(it: Dictionary) -> Control:
	var have := Wardrobe.has(it.id)
	var kind := WardrobeData.kind(it)
	var on: bool = draft.get(slot, "") == it.id
	var border := Color(GOLD, 1) if kind == "premium" else Color(0, 0, 0, 0)
	var b := Button.new()
	b.custom_minimum_size = Vector2(81, 88)
	b.clip_contents = true
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, _card_style(on, border))
	var pic := TextureRect.new()
	pic.name = "pic"
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.position = Vector2(6, 4)
	pic.size = Vector2(69, 58)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.texture = thumbs.get(it.id)
	if not have and kind != "shop" and kind != "premium":
		pic.modulate = Color(0.35, 0.3, 0.4, 0.45)
	b.add_child(pic)
	if pic.texture == null:
		thumb_queue.append(it.id)
	var sub := ""
	var col := SUB
	if have:
		sub = tr("Owned")
	elif kind == "shop":
		sub = "%d" % WardrobeData.price(it)
		col = GOLD
	elif kind == "premium":
		sub = tr("Special")
		col = GOLD
	else:
		sub = tr("Locked")
	var nl := Kit.text(tr(it.name), 10, INK, true, HORIZONTAL_ALIGNMENT_CENTER)
	_name_row(nl)
	nl.clip_text = true
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(nl)
	var sl := Kit.text(sub, 9, col, true, HORIZONTAL_ALIGNMENT_CENTER)
	sl.position = Vector2(0, 73)
	sl.size = Vector2(81, 12)
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(sl)
	if Wardrobe.fresh.has(it.id):
		var nb := PanelContainer.new()
		nb.add_theme_stylebox_override("panel", Kit.pill(Color("ff6b5b"), 8, 0.0, Vector2(5, 1)))
		nb.add_child(Kit.text(tr("R3_NEW"), 9, Color.WHITE, true))
		nb.position = Vector2(4, 4)
		nb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(nb)
	b.pressed.connect(func(): _pick(it))
	return b


## 札の名前の行（札の幅いっぱい・写真の下）。入らない長さなら字を小さくして全部見せる（日本語の長い名前が切れないように）。
## 幅は札に合わせる（アンカー）。木に入る前のラベルは既定の字の大きさで測られて、固定の幅だと横に伸びたまま残るため
func _name_row(l: Label) -> void:
	var f := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	while fs > 7 and f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > 77:
		fs -= 1
	l.add_theme_font_size_override("font_size", fs)
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = 60
	l.offset_bottom = 74


func _pick(it: Dictionary) -> void:
	Kit.play(self, "tap")
	selected = it.id
	draft[slot] = it.id
	Wardrobe.fresh.erase(it.id)
	_rebuild_obake()
	_fill_grid()


## 下の大きなボタン：いま選んでいる物に合わせて「着る・外す・買う・準備中」
func _update_action() -> void:
	action_btn.disabled = false
	info_label.text = ""
	if selected == "":
		action_btn.text = tr("Pick something to try")
		action_btn.disabled = true
		info_label.text = tr("Drag to spin. Tap an item to try it on.")
		return
	var it := WardrobeData.item(selected)
	var kind := WardrobeData.kind(it)
	if Wardrobe.has(selected):
		action_btn.text = tr("Take off")
		info_label.text = tr("Tap Save to keep this look")
	elif kind == "shop":
		action_btn.text = tr("Buy · %d") % WardrobeData.price(it)
		action_btn.disabled = Wallet.balance() < WardrobeData.price(it)
		info_label.text = tr("Trying it on. Buy to keep it.")
	elif kind == "premium":
		action_btn.text = WardrobeData.how_to_get(it)
		info_label.text = tr("Special look only. Changes nothing in play.")
	else:
		action_btn.text = tr("Not yet")
		action_btn.disabled = true
		info_label.text = WardrobeData.how_to_get(it)


func _on_action() -> void:
	var it := WardrobeData.item(selected)
	if it.is_empty():
		return
	if Wardrobe.has(selected):
		draft.erase(slot)
		selected = ""
		_rebuild_obake()
		_fill_grid()
	elif WardrobeData.kind(it) == "shop":
		if Wardrobe.buy(selected):
			Kit.play(self, "chime")
			_fill_grid()
	elif WardrobeData.kind(it) == "premium":
		_coming_soon(it)


func _randomize() -> void:
	var rng_draft := {}
	for s in WardrobeData.SLOTS:
		var mine: Array = []
		for it in WardrobeData.in_slot(s):
			if Wardrobe.has(it.id):
				mine.append(it.id)
		if not mine.is_empty() and randf() < 0.7:
			rng_draft[s] = mine.pick_random()
	draft = rng_draft
	selected = ""
	Kit.play(self, "tap")
	_rebuild_obake()
	_fill_grid()


func _save() -> void:
	var id: String = who_list[who_i]
	var dropped := 0
	for s in WardrobeData.SLOTS:
		if draft.has(s) and not Wardrobe.has(draft[s]):
			draft.erase(s)
			dropped += 1
	Wardrobe.set_outfit(id, draft)
	Wardrobe.save()
	Telemetry.track("outfit_change")
	Sfx.equip(self)
	_rebuild_obake()
	_fill_grid()
	info_label.text = tr("Saved!") if dropped == 0 else tr("Saved. Items you don't own were left off.")


func _back() -> void:
	Wardrobe.save()
	if main:
		main.go("garden")


func _coming_soon(it: Dictionary) -> void:
	if popup:
		popup.queue_free()
	popup = Control.new()
	popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(popup)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.15, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	popup.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color("fff8ef"), 24, 0.2, Vector2(18, 16)))
	p.position = Vector2(36, 210)
	p.size = Vector2(288, 0)
	popup.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(Kit.text(tr("Coming soon"), 20, INK, true, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(Kit.text(tr(it.name) + "  " + WardrobeData.how_to_get(it), 13, GOLD, true, HORIZONTAL_ALIGNMENT_CENTER))
	var l := Kit.wrap(Kit.text(tr("This is a sample store. No payment happens. Special items only change looks."), 12, SUB, false, HORIZONTAL_ALIGNMENT_CENTER))
	l.custom_minimum_size = Vector2(250, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	v.add_child(Kit.button(tr("OK"), ACCENT, func():
		popup.queue_free()
		popup = null, Color.WHITE, 42, 15))


# ---------------------------------------------------------------- 服の小さな絵

func _build_thumb_stage() -> void:
	thumb_vp = SubViewport.new()
	thumb_vp.size = Vector2i(138, 116)
	thumb_vp.own_world_3d = true
	thumb_vp.transparent_bg = true
	thumb_vp.msaa_3d = Viewport.MSAA_4X
	thumb_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(thumb_vp)
	thumb_world = Node3D.new()
	thumb_vp.add_child(thumb_world)
	Look.apply(thumb_world, "studio", Color(0, 0, 0, 0), true)
	thumb_cam = Camera3D.new()
	thumb_cam.fov = 30
	thumb_world.add_child(thumb_cam)


func _pump_thumbs() -> void:
	if thumb_busy or thumb_queue.is_empty() or DisplayServer.get_name() == "headless":
		return
	_shoot(thumb_queue.pop_front())


func _shoot(id: String) -> void:
	if thumbs.has(id):
		_apply_thumb(id)
		return
	thumb_busy = true
	var helper := Obake3D.new()
	var node := Outfit.build(helper, WardrobeData.item(id))
	thumb_world.add_child(node)
	# 物の大きさに合わせてカメラを寄せる
	var box := AABB()
	var first := true
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var t := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != node:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var b := t * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var c := box.get_center()
	var r := maxf(box.size.length() * 0.5, 0.12)
	var dir := Vector3(0.45, 0.35, 1.0).normalized()
	if WardrobeData.item(id).slot == "back":
		dir = Vector3(0.6, 0.35, -1.0).normalized()
	thumb_cam.look_at_from_position(c + dir * r / tan(deg_to_rad(15.0)) * 1.05, c)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	thumbs[id] = ImageTexture.create_from_image(thumb_vp.get_texture().get_image())
	node.queue_free()
	helper.free()
	thumb_busy = false
	_apply_thumb(id)


func _apply_thumb(id: String) -> void:
	if cards.has(id) and is_instance_valid(cards[id]):
		var pic: TextureRect = cards[id].get_node("pic")
		pic.texture = thumbs[id]


# ---------------------------------------------------------------- 確認用

## OBAKE_WARDROBE_DEMO=1：診断の子・何点かの服・コインを用意して開く（撮影用）
func _demo_setup() -> void:
	if OS.get_environment("OBAKE_WARDROBE_DEMO") == "":
		return
	var gs = _gs()
	if gs and gs.my_obake.is_empty():
		gs.my_obake = QuizData.score("ABBAABBAABBA")
	Wardrobe.reset()
	for id in ["reg_vest", "chef_hat", "nightcap", "star_glasses", "balloon", "angel_wings", "beanie", "striped_scarf"]:
		Wardrobe.grant(id)
	Wallet.reset(240)
	Wardrobe.set_outfit("my", {"head": "chef_hat", "neck": "striped_scarf"})


func demo_pick(id: String = "crown") -> void:
	var it := WardrobeData.item(id)
	slot = it.slot
	_build_tabs()
	_pick(it)


func demo_premium() -> void:
	demo_pick("astro_helmet")
	_on_action()


func demo_reveal() -> void:
	OutfitReveal.open(self, "moon_cape", who_list[who_i])
