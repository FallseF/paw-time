extends Control
## 朝、光る玉が割れる。1個ずつ震えて、光があふれて、おばけが現れる。
## 待たせない：ぽんと早く割れる。「ぜんぶひらく」で残りをまとめて、「スキップ」ですぐ庭へ（中身はもう手もとにある）。

var main

var vp: SubViewport
var cam: Camera3D
var world: Node3D
var orbs: Array = []
var index := 0
var current_obake: Node3D
var font_bold: FontFile
var font_black: FontFile
var card: PanelContainer
var card_title: Label
var card_sub: Label
var card_desc: Label
var badge: Label
var next_btn: Button
var all_btn: Button
var skip_btn: Button
var header: Label
var flash: ColorRect
var burst: CPUParticles3D
var rays: MeshInstance3D
var sfx := {}
var busy := false
var batch_from := 999
var batch_obs: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	font_bold = load("res://assets/fonts/ZenMaruGothic-Bold.ttf")
	font_black = load("res://assets/fonts/ZenMaruGothic-Black.ttf")
	_build_world()
	_build_ui()
	for n in ["sparkle"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/sfx/%s.wav" % n)
		add_child(p)
		sfx[n] = p
	# おばネコ（新顔・レア）を先に、ひとつずつ大きく。島の材料・服といつもの子は、あとでまとめて一度に（朝が長くならないように）
	var featured: Array = GameState.hatched.filter(func(x): return not x.has("kind") and (x.is_new or x.get("rare", false) or x.get("big", false)))
	var quick: Array = GameState.hatched.filter(func(x): return not featured.has(x))
	GameState.hatched = featured + quick
	var only_cat_dupe: bool = quick.size() == 1 and not quick[0].has("kind")
	batch_from = featured.size() if not quick.is_empty() and not only_cat_dupe else GameState.hatched.size()
	# 特別な子（はじめての夜・3 分デモ）がいる朝は、材料からひとつずつあけて、特別な子をいちばん最後に（大きな見せ場に）
	if GameState.hatched.any(func(x): return x.get("special", false)):
		var sp: Array = GameState.hatched.filter(func(x): return x.get("special", false))
		GameState.hatched = GameState.hatched.filter(func(x): return not x.get("special", false)) + sp
		batch_from = GameState.hatched.size()
	var n_orbs: int = GameState.hatched.size()
	for i in n_orbs:
		var h: Dictionary = GameState.hatched[i]
		var t: String = GameState.info(h.id).type
		if h.has("kind"):
			t = "any"
		var o := Orb3D.new().setup({"type": t if GameState.TYPE_COLOR.has(t) else "rare", "rare": Rares.is_rare(h.id) or h.get("big", false), "weight": 0.3, "content": h.get("content", {"kind": "obake"})})
		o.caught = true
		o.halo_mat.albedo_color.a = 0.08
		# 生まれたおばけが主役なので、棚の玉は控えめに光らせる（照らす光は特に弱く）
		o.energy_scale = 0.7
		o.light_scale = 0.2
		o.position = Vector3((i - (n_orbs - 1) / 2.0) * 0.42, 0.42, 0.2)
		world.add_child(o)
		orbs.append(o)
	header.text = tr("朝だ。光る玉が 1 個") if n_orbs == 1 else tr("朝だ。光る玉が %d 個") % n_orbs
	next_btn.text = "玉をひらく"
	_refresh_buttons()
	_warm_up()
	# 最初の玉は、待たずにひらく（暗転が明けたらすぐ）
	await get_tree().create_timer(0.15).timeout
	if index == 0 and not busy and is_inside_tree():
		_next()


## 割れる演出の材料（破片・光の筋のシェーダー）と、生まれる子の体を、画面を開いたときに一度だけ描いておく。
## WebGL は材料をはじめて描くときに組み立てるので、そのままだと割れた瞬間・子が出た瞬間に止まって見える。
## 壁の裏（カメラの向きの中・壁に隠れる所）に置いて、暗転が明ける前のいちばん初めのコマで一緒に組み立てる
func _warm_up() -> void:
	if orbs.is_empty():
		return
	var hidden_at := Vector3(0, 1.0, -2.2)
	var nodes: Array = []
	var dummy := Orb3D.new().setup({"type": "rare", "rare": true, "weight": 0.3, "content": {"kind": "obake"}})
	dummy.position = hidden_at
	world.add_child(dummy)
	dummy.model.shatter(world, true)
	dummy.model.shatter(world, false)
	nodes.append(dummy)
	for h in GameState.hatched:
		var ob: Node3D = Drops.make_icon(h.content) if h.has("kind") else Obake3D.make(h.id)
		ob.position = hidden_at
		world.add_child(ob)
		nodes.append(ob)
	# はじめての夜の子は、割れたあと自分の猫がひとこと言うので、その猫も
	if GameState.hatched.any(func(x): return x.get("special", false)):
		var me := MyObake3D.from_saved()
		if me:
			me.position = hidden_at
			world.add_child(me)
			nodes.append(me)
	# おばネコが出る瞬間の光（_light_burst）も、足した光で描く組み合わせを先に作っておく（ほとんど見えない明るさ）
	var l := OmniLight3D.new()
	l.omni_range = 4.0
	l.light_energy = 0.001
	l.position = Vector3(0, 0.85, 0.9)
	world.add_child(l)
	nodes.append(l)
	# 3 コマ描いたら片づける（破片は自分で消える）
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	for n in nodes:
		if is_instance_valid(n):
			n.queue_free()


func _build_world() -> void:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	View3D.fit(box, vp)
	world = Node3D.new()
	vp.add_child(world)

	var rig := Look.apply(world, "hatch", Color("2a2233"), false, true)
	var env: Environment = rig.env
	env.glow_enabled = true
	# 壁が #FFFB9B・座布団が #FF4E37 に飛んでいた：グローは明るいところだけ・弱く
	env.glow_intensity = 0.3
	env.glow_hdr_threshold = 1.6

	cam = Camera3D.new()
	cam.position = Vector3(0, 1.35, 3.1)
	cam.fov = 48
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.45, 0))

	# 床と壁
	var floor_m := MeshInstance3D.new()
	var fp := PlaneMesh.new()
	fp.size = Vector2(10, 10)
	floor_m.mesh = fp
	floor_m.material_override = Obake3D.toon(Color("a87250"), 0.05)
	world.add_child(floor_m)
	var wall := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(10, 5, 0.1)
	wall.mesh = wm
	wall.position = Vector3(0, 2.5, -1.4)
	wall.material_override = Obake3D.toon(Color("e8d3bd"), 0.05)
	world.add_child(wall)
	# 朝日の窓
	var win := MeshInstance3D.new()
	var wq := QuadMesh.new()
	wq.size = Vector2(1.4, 1.1)
	win.mesh = wq
	win.position = Vector3(-0.9, 1.7, -1.34)
	var wmat := StandardMaterial3D.new()
	wmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wmat.albedo_color = Color("ffd9a0")
	wmat.emission_enabled = true
	wmat.emission = Color("ffb870")
	wmat.emission_energy_multiplier = 1.0
	win.material_override = wmat
	world.add_child(win)
	for x in [-0.9]:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 1.1, 0.02)
		bar.mesh = bm
		bar.position = Vector3(x, 1.7, -1.32)
		bar.material_override = Obake3D.toon(Color("6b4a3a"), 0.05)
		world.add_child(bar)
	# 光の筋
	rays = MeshInstance3D.new()
	var rb := BoxMesh.new()
	rb.size = Vector3(1.2, 0.01, 3.0)
	rays.mesh = rb
	rays.position = Vector3(-0.4, 0.9, 0.0)
	rays.rotation = Vector3(0.5, 0.35, 0)
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rmat.albedo_color = Color(1.0, 0.8, 0.55, 0.06)
	rays.material_override = rmat
	world.add_child(rays)
	# 座布団
	var cushion := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1.9, 0.16, 1.1)
	cushion.mesh = cm
	cushion.position = Vector3(0, 0.08, 0.2)
	cushion.material_override = Obake3D.toon(Color("b04a55"), 0.2) # 座布団は飛ばない赤（前は #FF4E37 に飽和）
	world.add_child(cushion)
	var cushion2 := MeshInstance3D.new()
	var cm2 := BoxMesh.new()
	cm2.size = Vector3(1.8, 0.04, 1.0)
	cushion2.mesh = cm2
	cushion2.position = Vector3(0, 0.18, 0.2)
	cushion2.material_override = Obake3D.toon(Color("c45c64"), 0.2)
	world.add_child(cushion2)

	burst = CPUParticles3D.new()
	burst.emitting = false
	burst.one_shot = true
	burst.amount = 60
	burst.lifetime = 1.3
	burst.explosiveness = 1.0
	burst.spread = 180
	burst.initial_velocity_min = 1.2
	burst.initial_velocity_max = 2.8
	burst.gravity = Vector3(0, -1.2, 0)
	var bmesh := SphereMesh.new()
	bmesh.radius = 0.03
	bmesh.height = 0.06
	burst.mesh = bmesh
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color("fff2a8")
	gm.emission_enabled = true
	gm.emission = Color("fff2a8")
	gm.emission_energy_multiplier = 3.0
	burst.material_override = gm
	world.add_child(burst)


func _pill(bg: Color, radius := 20) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(Tokens.SHADOW, 0.25)
	s.shadow_size = 10
	s.shadow_offset = Vector2(0, 4)
	return s


func _text(t: String, size: int, color := Color("2a2233"), font: FontFile = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", font if font else font_bold)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _build_ui() -> void:
	header = _text("", 20, Color("fff6e8"), font_black)
	header.autowrap_mode = TextServer.AUTOWRAP_OFF
	# 黒い縁取りではなく、やわらかい影（墨色）
	header.add_theme_color_override("font_shadow_color", Color(Tokens.SHADOW, 0.45))
	header.add_theme_constant_override("shadow_offset_x", 0)
	header.add_theme_constant_override("shadow_offset_y", 2)
	header.add_theme_constant_override("shadow_outline_size", 6)
	header.position = Vector2(0, 30)
	header.size = Vector2(360, 40)
	add_child(header)

	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", _pill(Color(1, 0.98, 0.95, 0.96), 24))
	card.position = Vector2(24, 372)
	card.size = Vector2(312, 140)
	card.modulate.a = 0.0
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	badge = _text(tr("R3_NEW"), 13, Color("ffffff"), font_black)
	badge.autowrap_mode = TextServer.AUTOWRAP_OFF
	var bp := PanelContainer.new()
	bp.add_theme_stylebox_override("panel", _pill(Color("ff6b5b"), 10))
	bp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bp.add_child(badge)
	v.add_child(bp)
	card_title = _text("", 28, Color("2a2233"), font_black)
	v.add_child(card_title)
	card_sub = _text("", 14, Color("8a7a88"))
	v.add_child(card_sub)
	card_desc = _text("", 13, Color("4a3f52"))
	v.add_child(card_desc)

	next_btn = Button.new()
	next_btn.position = Vector2(80, 576)
	next_btn.size = Vector2(200, 50)
	next_btn.add_theme_font_override("font", font_black)
	next_btn.add_theme_font_size_override("font_size", 18)
	for k in ["normal", "hover", "pressed"]:
		next_btn.add_theme_stylebox_override(k, _pill(Color("ff8a5b"), 25))
	next_btn.add_theme_stylebox_override("disabled", _pill(Color(1.0, 0.54, 0.36, 0.55), 25))
	next_btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.8))
	next_btn.add_theme_color_override("font_color", Color.WHITE)
	next_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	next_btn.pressed.connect(_next)
	add_child(next_btn)
	# 残りをまとめてひらく（2 個以上残っているとき）
	all_btn = Button.new()
	all_btn.text = tr("ぜんぶひらく")
	all_btn.flat = true
	all_btn.position = Vector2(230, 582)
	all_btn.size = Vector2(110, 40)
	all_btn.add_theme_font_override("font", font_bold)
	all_btn.add_theme_font_size_override("font_size", 14)
	all_btn.add_theme_color_override("font_color", Color("fff6e8"))
	all_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	all_btn.pressed.connect(_open_all)
	all_btn.visible = false
	add_child(all_btn)
	# すぐ庭へ（割れる演出を飛ばす）
	skip_btn = Button.new()
	skip_btn.text = tr("スキップ ›")
	skip_btn.flat = true
	skip_btn.position = Vector2(266, 72)
	skip_btn.size = Vector2(90, 36)
	skip_btn.add_theme_font_override("font", font_bold)
	skip_btn.add_theme_font_size_override("font_size", 14)
	skip_btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	skip_btn.pressed.connect(_to_garden)
	add_child(skip_btn)

	flash = ColorRect.new()
	flash.color = Color("fff6d8")
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate.a = 0.0
	add_child(flash)


func _refresh_buttons() -> void:
	var left := orbs.size() - index
	# 特別な子がまだ残っている朝は「ぜんぶ」を出さない（特別な子は、ひとつだけで大きく見せる）
	var special_left: bool = GameState.hatched.slice(index).any(func(x): return x.get("special", false))
	all_btn.visible = left >= 2 and index < batch_from and not special_left
	# 真ん中の主ボタンは、「ぜんぶ」があるときは少し左へ
	next_btn.position.x = 30 if all_btn.visible else 80


## のこりの玉を、まとめて一度にひらく
func _open_all() -> void:
	if busy or index >= orbs.size():
		return
	batch_from = index
	busy = true
	next_btn.disabled = true
	all_btn.visible = false
	await _open_batch()


## すぐ庭へ。中身は夜が明けたときに、もう手もとに入っている
func _to_garden() -> void:
	index = orbs.size()
	busy = false
	_next()


func _next() -> void:
	if busy:
		return
	if index >= orbs.size():
		GameState.newcomers = []
		for hh in GameState.hatched:
			if hh.is_new and not hh.has("kind") and not GameState.newcomers.has(hh.id):
				GameState.newcomers.append(hh.id)
		GameState.hatched = []
		GameState.save()
		main.go("garden")
		return
	busy = true
	next_btn.disabled = true
	if index >= batch_from:
		await _open_batch()
		return
	var tw0 := create_tween()
	tw0.tween_property(card, "modulate:a", 0.0, 0.12)
	if current_obake:
		tw0.parallel().tween_property(current_obake, "position:x", -3.0, 0.2)
	await tw0.finished
	if current_obake:
		current_obake.queue_free()
		current_obake = null
	var orb: Orb3D = orbs[index]
	var h: Dictionary = GameState.hatched[index]
	_track_hatch(h)
	# 玉が前に出て、震える
	var tw := create_tween()
	tw.tween_property(orb, "position", Vector3(0, 0.75, 0.6), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	# おばネコはいまレアなので、ひと震え多く（震えるたびに光が強くなる）。材料と服は、ぽんと。待たせないよう短く
	var is_cat: bool = not h.has("kind")
	var shakes := 2 if is_cat else 1
	# 音：震えてから割れるまで「ためる」音をのせ、割れる瞬間に頂点がくるように（いつもの 0・レア 1・特別なレア 2）
	var tier := 0 if not is_cat else (2 if SpecialReveal.has_clip(h.id) and h.is_new else (1 if Rares.is_rare(h.id) or h.get("big", false) else 0))
	Sfx.hatch_build(self, shakes * 0.2 + (0.34 if is_cat else 0.12), tier)
	for i in shakes:
		var amp := 0.03 + i * 0.035
		var tw2 := create_tween()
		tw2.tween_property(orb, "position:x", amp, 0.05)
		tw2.tween_property(orb, "position:x", -amp, 0.06)
		tw2.tween_property(orb, "position:x", 0.0, 0.05)
		tw2.parallel().tween_property(orb, "scale", Vector3.ONE * (1.0 + i * 0.25), 0.16)
		if is_cat:
			orb.energy_scale = 0.8 + i * 0.6
			orb.light_scale = 0.3 + i * 0.5
		await tw2.finished
		await get_tree().create_timer(0.04).timeout
	# 割れる：殻にひびが走り、破片と光の筋（OrbModel.hatch_vfx。おばネコは大きく、材料と服はぽんと）。画面の閃光は控えめに
	await orb.model.hatch_vfx(world, is_cat)
	_flash(0.18 if is_cat else 0.1)
	if is_cat:
		_light_burst(orb.position)
	Sfx.hatch_release(self, tier)
	if h.id == "kirari":
		sfx["sparkle"].play()
	Input.vibrate_handheld(60)
	burst.position = orb.position
	burst.restart()
	burst.emitting = true
	orb.queue_free()
	if h.has("kind"):
		await _reveal_item(h)
		return
	# 特別なレア 6 匹は、はじめて会ったときだけ動画で（はじめての夜の子は、猫がひとこと言ってから）
	if SpecialReveal.has_clip(h.id) and (h.is_new or OS.get_environment("OBAKE_REVEAL") == h.id):
		if h.get("special", false):
			await _cat_says(tr("Whoa… a rare one!"))
		await SpecialReveal.play(self, h.id)
	current_obake = Obake3D.make(h.id)
	current_obake.position = Vector3(0, 0.55, 0.3)
	current_obake.scale = Vector3.ONE * 0.05
	world.add_child(current_obake)
	var tw3 := create_tween()
	tw3.tween_property(current_obake, "scale", Vector3.ONE * 0.5, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await tw3.finished
	Sfx.reveal(self, tier)
	if Rares.is_rare(h.id):
		Kit.shake(cam, 0.07, 0.4)
	var sp: Dictionary = GameState.info(h.id)
	card_title.text = sp.name
	badge.get_parent().visible = h.is_new
	card_sub.text = (tr("レア ・ %s") % tr(sp.group)) if Rares.is_rare(h.id) else (tr("Lv%d ・ %s") % [h.level, tr(_type_label(sp.type))])
	card_desc.text = sp.desc
	card.position.y = 400
	var tw4 := create_tween().set_parallel()
	tw4.tween_property(card, "modulate:a", 1.0, 0.25)
	tw4.tween_property(card, "position:y", 372.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	index += 1
	next_btn.text = "つぎの玉" if index < orbs.size() else "庭へ"
	next_btn.disabled = false
	busy = false
	_refresh_buttons()


## いつもの子たちの玉は、まとめて一度にひらく
func _open_batch() -> void:
	var tw0 := create_tween()
	tw0.tween_property(card, "modulate:a", 0.0, 0.12)
	if current_obake:
		tw0.parallel().tween_property(current_obake, "position:x", -3.0, 0.2)
	await tw0.finished
	if current_obake:
		current_obake.queue_free()
		current_obake = null
	var rest: Array = orbs.slice(index)
	var tw := create_tween().set_parallel()
	for i in rest.size():
		tw.tween_property(rest[i], "position", Vector3((i - (rest.size() - 1) / 2.0) * 0.36, 0.6, 0.5), 0.25)
	await tw.finished
	for k in 2:
		var tw2 := create_tween().set_parallel()
		for o in rest:
			tw2.tween_property(o, "scale", Vector3.ONE * (1.2 + k * 0.2), 0.1)
		await tw2.finished
		await get_tree().create_timer(0.04).timeout
	_flash(0.3)
	Sfx.pops(self, orbs.size() - index)
	var counts := {}
	var levels := {}
	var n_items := 0
	for i in rest.size():
		var h: Dictionary = GameState.hatched[index + i]
		_track_hatch(h)
		counts[h.id] = counts.get(h.id, 0) + (int(h.content.get("n", 1)) if h.has("kind") else 1) # 材料は 1 玉で何こか
		levels[h.id] = h.level
		if h.has("kind"):
			n_items += 1
		var o: Orb3D = rest[i]
		var item: bool = h.has("kind")
		var ob: Node3D = Drops.make_icon(h.content) if item else Obake3D.make(h.id)
		ob.position = o.position + Vector3(0, -0.2 if not item else -0.05, 0)
		ob.scale = Vector3.ONE * 0.05
		world.add_child(ob)
		batch_obs.append(ob)
		o.model.shatter(world)
		o.queue_free()
		create_tween().tween_property(ob, "scale", Vector3.ONE * (0.3 if not item else 0.28), 0.5).set_delay(i * 0.06).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	burst.position = Vector3(0, 0.6, 0.5)
	burst.restart()
	burst.emitting = true
	await get_tree().create_timer(0.5).timeout
	Sfx.reveal(self)
	var lines: Array = []
	var names := {}
	for i in rest.size():
		var hh: Dictionary = GameState.hatched[index + i]
		names[hh.id] = tr(Drops.info(hh.content).get("name", hh.id)) if hh.has("kind") else tr(GameState.info(hh.id).name)
	for id in counts:
		lines.append(("%s ×%d" % [names[id], counts[id]]) if _is_item_id(id, index, rest.size()) else ("%s ×%d（Lv%d）" % [names[id], counts[id], levels[id]]))
	badge.get_parent().visible = false
	if n_items == rest.size():
		card_title.text = "島の材料と服"
		card_sub.text = "島づくりと着がえに使える"
	elif n_items == 0:
		card_title.text = "いつもの子たち"
		card_sub.text = "なかまが増えて、少し育った"
	else:
		card_title.text = "今朝の見つけもの"
		card_sub.text = "島の材料と服、いつもの子たち"
	card_desc.text = "\n".join(lines)
	card.position.y = 400
	var tw4 := create_tween().set_parallel()
	tw4.tween_property(card, "modulate:a", 1.0, 0.25)
	tw4.tween_property(card, "position:y", 372.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	index = orbs.size()
	next_btn.text = "庭へ"
	next_btn.disabled = false
	busy = false
	_refresh_buttons()


## おばネコが出る瞬間の光（まわりを一度だけ強く照らす）
func _light_burst(at: Vector3) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color("ffe9b0")
	l.omni_range = 4.0
	l.light_energy = 0.0
	l.position = at + Vector3(0, 0.1, 0.3)
	world.add_child(l)
	Kit.shake(cam, 0.05, 0.35)
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.8, 0.12)
	tw.tween_property(l, "light_energy", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(l.queue_free)


func _is_item_id(id: String, from: int, n: int) -> bool:
	for i in n:
		var hh: Dictionary = GameState.hatched[from + i]
		if hh.id == id:
			return hh.has("kind")
	return false


func _type_label(t: String) -> String:
	return {"register": "レジの経験", "dish": "皿洗いの経験", "hall": "ホールの経験", "kitchen": "キッチンの経験", "stock": "品出しの経験", "night": "満月の夜", "rare": "はじめての経験"}.get(t, "")


## 画面の閃光（控えめに。黄色くならないよう白に近い色で、短く）
func _flash(a: float) -> void:
	flash.color = Color("fffcf5")
	flash.modulate.a = a * 0.6
	create_tween().tween_property(flash, "modulate:a", 0.0, 0.35)


## 自分の猫が、ひとこと（はじめての夜のレア）。猫は右下からのぞいて、吹き出しで話す
func _cat_says(line: String) -> void:
	var me := MyObake3D.from_saved()
	if me:
		me.position = Vector3(0.95, 0.2, 0.9)
		me.scale = Vector3.ONE * 0.05
		me.rotation.y = -0.5
		world.add_child(me)
		create_tween().tween_property(me, "scale", Vector3.ONE * 0.32, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", _pill(Color(1, 0.98, 0.95, 0.97), 20))
	bubble.add_child(_text(line, 18, Color("2a2233"), font_black))
	bubble.position = Vector2(40, 440)
	bubble.size = Vector2(280, 0)
	bubble.modulate.a = 0.0
	add_child(bubble)
	var tw := create_tween()
	tw.tween_property(bubble, "modulate:a", 1.0, 0.2)
	sfx["sparkle"].play()
	await get_tree().create_timer(0.9).timeout
	var tw2 := create_tween()
	tw2.tween_property(bubble, "modulate:a", 0.0, 0.2)
	if me:
		tw2.parallel().tween_property(me, "scale", Vector3.ONE * 0.01, 0.2)
	await tw2.finished
	bubble.queue_free()
	if me:
		me.queue_free()


## テレメトリー：ひらいた玉 1 つにつき 1 件（猫・材料・服）
func _track_hatch(h: Dictionary) -> void:
	var kind := "cat"
	if h.has("kind"):
		kind = "clothes" if h.content.get("kind", "") == "cloth" else "material"
	Telemetry.track("hatch", {"kind": kind})


func demo_open() -> void:
	_next()


## 玉から出たのが、島の材料や服だったとき
func _reveal_item(h: Dictionary) -> void:
	var c: Dictionary = h.content
	current_obake = Drops.make_icon(c)
	current_obake.position = Vector3(0, 0.75, 0.3)
	current_obake.scale = Vector3.ONE * 0.05
	world.add_child(current_obake)
	var tw3 := create_tween().set_parallel()
	tw3.tween_property(current_obake, "scale", Vector3.ONE * 0.55, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw3.tween_property(current_obake, "rotation:y", TAU, 0.7).set_trans(Tween.TRANS_SINE)
	await tw3.finished
	Sfx.reveal(self)
	card_title.text = tr(Drops.info(c).get("name", ""))
	badge.get_parent().visible = h.is_new
	card_sub.text = tr({"material": "島の材料", "cloth": "服", "vehicle": "乗り物"}.get(c.kind, "島の材料"))
	card_desc.text = tr({"material": "島をつくるときに使える", "cloth": "おばけに着せられる", "vehicle": "おでかけのときに乗れる（見た目だけ）"}.get(c.kind, ""))
	card.position.y = 400
	var tw4 := create_tween().set_parallel()
	tw4.tween_property(card, "modulate:a", 1.0, 0.25)
	tw4.tween_property(card, "position:y", 372.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	index += 1
	next_btn.text = "つぎの玉" if index < orbs.size() else "庭へ"
	next_btn.disabled = false
	busy = false
	_refresh_buttons()


## 玉がまわりを照らす光は、合わせて ORB_LIGHT_MAX まで（玉が 3 つ光っても、壁と座布団が白く飛ばないように）
const ORB_LIGHT_MAX := 1.2


func _process(_delta: float) -> void:
	process_priority = 100 # 玉（Orb3D）が光を決めたあとで、合計を抑える
	var total := 0.0
	var ls: Array = []
	for o in orbs:
		if is_instance_valid(o) and o.model and o.model.light and o.model.light.is_visible_in_tree():
			ls.append(o.model.light)
			total += o.model.light.light_energy
	if total > ORB_LIGHT_MAX:
		for l in ls:
			l.light_energy *= ORB_LIGHT_MAX / total
