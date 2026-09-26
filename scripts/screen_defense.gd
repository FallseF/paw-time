extends Control
## 大ピーク防衛。おばけを下のボタンから出して、店のカウンターを困りごとから守る。
## やる気（下のメーター）は勝手にたまる。困りごとの渦を崩せば勝ち。
## 計算は DefSim、ここは見た目と操作だけ。

var main

const VIEW_H := 462.0
const JOB_COLOR := {"register": Color("ffc23d"), "dish": Color("5fc4ff"), "hall": Color("a98bff"), "kitchen": Color("ff7a45"), "stock": Color("e8b878"), "": Color("ff8fb1")}

var sim: DefSim
var si := 0
var st := 0
var shop: Dictionary
var stage: Dictionary
var boost: Dictionary

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var cam_x := 16.5
var cam_hold := 0.0
var shake := 0.0
var views := {}
var fx_pools := {}
var fx_i := {}
var ebase_node: Node3D
var base_node: Node3D
var boss_seen := false
var _t := 0.0
var acc := 0.0
var speed := 1
var paused := false
var ended := false
var auto := false
var demo := false
var pops_alive := 0
var dmg_by_enemy := {}

# UI
var e_hp: ProgressBar
var a_hp: ProgressBar
var e_lbl: Label
var a_lbl: Label
var energy_bar: ProgressBar
var energy_lbl: Label
var wallet_btn: Button
var slot_btns: Array = []
var cannon_btn: Button
var cannon_fill: ColorRect
var minimap: Control
var banner: Label
var flash: ColorRect
var hint: PanelContainer
var hint_label: Label
var hint_target: Control
var hint_key := ""
var hint_time := 0.0
var overlay: Control
var retreated := false
var weak_tag: PanelContainer
var weak_tag_label: Label
var weak_uid := -1
var boss_bar: PanelContainer
var boss_hp: ProgressBar
var speed_btn: Button
var drag_from := -1.0
var drag_cam := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	demo = OS.get_environment("OBAKE_DEMO") != ""
	auto = demo or OS.get_environment("OBAKE_AUTO") != ""
	var pb: Dictionary = GameState.pending_battle
	si = int(pb.get("shop", 0))
	st = int(pb.get("stage", 0))
	shop = DefData.shop(si)
	stage = DefData.stage(si, st)
	boost = GameState.battle_boost(shop.id)
	sim = DefSim.new()
	var deck: Array = GameState.deck_for_battle()
	sim.setup(si, st, deck, boost, GameState.lap)
	cam_x = DefData.LANE - 3.0
	_build_world()
	_build_ui()
	Kit.music("c_battle_loop")
	speed = int(GameState.get_meta("speed", 1)) if not demo else 1
	if OS.get_environment("OBAKE_SPEED") != "":
		speed = int(OS.get_environment("OBAKE_SPEED"))
	speed_btn.text = "×%d" % speed
	Kit.make_portraits(GameState.deck.duplicate())
	_intro()


# ---------- 世界 ----------

func _build_world() -> void:
	var box := SubViewportContainer.new()
	box.stretch = true
	box.position = Vector2.ZERO
	box.size = Vector2(360, VIEW_H)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(shop.sky)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff1e0")
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 0.75
	sun.light_color = Color("fff0dc")
	world.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 40
	world.add_child(cam)
	_place_cam()

	# 背景の絵（なければ空の色だけ）。空と床の色は絵からとって、つなぎ目を消す
	var floor_col := Color(shop.floor)
	var bg_path := "res://assets/gen/c/bg_%s.png" % shop.id
	if ResourceLoader.exists(bg_path):
		var bg := Sprite3D.new()
		bg.texture = load(bg_path)
		bg.shaded = false
		bg.pixel_size = 40.0 / bg.texture.get_width()
		bg.position = Vector3(DefData.LANE * 0.5, 7.2, -22.0)
		world.add_child(bg)
		var img := bg.texture.get_image()
		if img:
			if img.is_compressed():
				img.decompress()
			env.background_color = img.get_pixel(4, 4)
			floor_col = img.get_pixel(4, img.get_height() - 6)
	else:
		for i in 14:
			var h := randf_range(2.0, 5.0)
			_box(Vector3(randf_range(1.6, 2.6), h, 1.0), Vector3(-2.0 + i * 1.9, h * 0.5, -5.0), Color(shop.sky).darkened(0.15 + randf() * 0.1))
	# 床
	_box(Vector3(40, 0.3, 12.0), Vector3(DefData.LANE * 0.5, -0.15, 1.6), floor_col)
	_box(Vector3(40, 0.04, 0.08), Vector3(DefData.LANE * 0.5, 0.005, 1.45), floor_col.darkened(0.2))
	_box(Vector3(40, 0.04, 0.08), Vector3(DefData.LANE * 0.5, 0.005, -0.85), floor_col.lightened(0.1))

	# 困りごとの渦（左）と、店のカウンター（右）
	ebase_node = _sprite_node(Kit.enemy_tex("uzu"), 3.4)
	ebase_node.position = Vector3(-0.2, 0, -0.3)
	world.add_child(ebase_node)
	var counter := Kit.cropped("res://assets/gen/c/counter.png")
	if counter:
		base_node = _sprite_node(counter, 2.6)
		base_node.position = Vector3(DefData.LANE + 0.5, 0, -0.3)
		world.add_child(base_node)
	else:
		base_node = Node3D.new()
		base_node.position = Vector3(DefData.LANE + 0.6, 0, -0.2)
		world.add_child(base_node)
		_box(Vector3(1.4, 1.1, 1.4), Vector3(0, 0.55, 0), Color("f4efe6"), base_node)
		_box(Vector3(1.6, 0.12, 1.6), Vector3(0, 1.15, 0), Color(shop.color), base_node)
		_box(Vector3(0.5, 0.35, 0.4), Vector3(0.1, 1.38, 0), Color("4a4a52"), base_node)
		_box(Vector3(1.8, 0.1, 1.2), Vector3(-0.3, 2.3, 0), Color(shop.color).lightened(0.2), base_node)
		_box(Vector3(0.08, 1.2, 0.08), Vector3(0.6, 1.7, 0.5), Color("7a5238"), base_node)

	for kind in ["hit", "puff", "zap", "heal", "gold", "weak", "job"]:
		fx_pools[kind] = []
		fx_i[kind] = 0
		for i in 6:
			fx_pools[kind].append(_make_fx(kind))


func _box(size: Vector3, pos: Vector3, c: Color, parent: Node3D = null) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = Obake3D.toon(c, 0.05)
	(parent if parent else world).add_child(m)
	return m


func _sprite_node(tex: Texture2D, h: float) -> Node3D:
	var n := Node3D.new()
	var inner := Node3D.new()
	inner.name = "inner"
	n.add_child(inner)
	if tex == null:
		var ob := Obake3D.new().setup("receipt")
		ob.scale = Vector3.ONE * h * 0.5
		inner.add_child(ob)
		return n
	var s := Sprite3D.new()
	s.name = "spr"
	s.texture = tex
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.pixel_size = h / float(tex.get_height())
	s.offset = Vector2(0, tex.get_height() * 0.5)
	inner.add_child(s)
	return n


func _make_fx(kind: String) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	var col := Color.WHITE
	var sz := 0.05
	match kind:
		"hit":
			p.amount = 8
			p.lifetime = 0.35
			p.initial_velocity_min = 1.5
			p.initial_velocity_max = 3.0
			p.gravity = Vector3(0, -4, 0)
			col = Color("fff6e0")
			sz = 0.05
		"puff":
			p.amount = 16
			p.lifetime = 0.7
			p.initial_velocity_min = 0.6
			p.initial_velocity_max = 1.8
			p.gravity = Vector3(0, 0.8, 0)
			col = Color("ffffff")
			sz = 0.12
		"zap":
			p.amount = 18
			p.lifetime = 0.5
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 4.0
			p.gravity = Vector3(0, -3, 0)
			col = Color("ffe14d")
			sz = 0.05
		"heal":
			p.amount = 10
			p.lifetime = 0.9
			p.initial_velocity_min = 0.3
			p.initial_velocity_max = 0.8
			p.gravity = Vector3(0, 1.2, 0)
			col = Color("8fe0a8")
			sz = 0.06
		"gold":
			p.amount = 8
			p.lifetime = 0.6
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 2.2
			p.gravity = Vector3(0, -5, 0)
			col = Color("ffd23f")
			sz = 0.06
		"job":
			p.amount = 10
			p.lifetime = 0.4
			p.initial_velocity_min = 1.2
			p.initial_velocity_max = 2.6
			p.gravity = Vector3(0, -2, 0)
			sz = 0.07
		"weak":
			p.amount = 14
			p.lifetime = 0.45
			p.initial_velocity_min = 2.0
			p.initial_velocity_max = 3.5
			p.gravity = Vector3(0, -3, 0)
			col = Color("ff8a5b")
			sz = 0.06
	p.direction = Vector3(0, 1, 0)
	p.spread = 80
	var m := SphereMesh.new()
	m.radius = sz
	m.height = sz * 2.0
	m.radial_segments = 6
	m.rings = 3
	p.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	p.material_override = mat
	world.add_child(p)
	return p


func _fx(kind: String, pos: Vector3, col := Color(0, 0, 0, 0)) -> void:
	var pool: Array = fx_pools[kind]
	var p: CPUParticles3D = pool[fx_i[kind] % pool.size()]
	fx_i[kind] += 1
	if col.a > 0:
		(p.material_override as StandardMaterial3D).albedo_color = col
	p.position = pos
	p.restart()
	p.emitting = true


func _place_cam() -> void:
	var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake * 0.25
	cam.position = Vector3(cam_x, 2.5, 12.0) + off
	cam.look_at(Vector3(cam_x, 2.35, 0) + off)


# ---------- おばけと困りごとの見た目 ----------

func _make_view(e: Dictionary) -> void:
	var root := Node3D.new()
	root.position = Vector3(e.x, 0, e.z)
	var inner := Node3D.new()
	root.add_child(inner)
	var v := {"root": root, "inner": inner, "spr": null, "ob": null, "side": e.side, "id": e.id, "zz": null, "t": randf() * TAU, "busy": false}
	if e.side == 0:
		if e.tiny:
			var sp := _sprite(Kit.tiny_tex(), 0.34)
			inner.add_child(sp)
			v.spr = sp
		else:
			var tex := Kit.rare_tex(e.id) if Rares.is_rare(e.id) else null
			var aura := {"lantern": [3.0, Color(1.0, 0.75, 0.3, 0.22)], "shield": [2.5, Color(0.6, 0.8, 1.0, 0.22)], "dream": [3.0, Color(0.6, 1.0, 0.75, 0.2)], "sunrise": [1.6, Color(1.0, 0.55, 0.45, 0.22)]}
			if aura.has(e.ability):
				# 能力の届く範囲を、足元の光の輪で見せる
				var disc := MeshInstance3D.new()
				var cm := CylinderMesh.new()
				cm.top_radius = aura[e.ability][0]
				cm.bottom_radius = aura[e.ability][0]
				cm.height = 0.01
				disc.mesh = cm
				var dm := StandardMaterial3D.new()
				dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				dm.albedo_color = aura[e.ability][1]
				disc.material_override = dm
				disc.scale = Vector3(1, 1, 0.35)
				disc.position = Vector3(0, 0.02, 0.2)
				root.add_child(disc)
			if tex:
				var sp2 := _sprite(tex, 1.45)
				inner.add_child(sp2)
				v.spr = sp2
			else:
				var ob := Obake3D.make(e.id)
				ob.scale = Vector3.ONE * 0.78
				ob.rotation.y = -1.0
				inner.add_child(ob)
				v.ob = ob
	else:
		var d: Dictionary = DefData.ENEMIES[e.id]
		var sp3 := _sprite(Kit.enemy_tex(e.id), d.h)
		inner.add_child(sp3)
		v.spr = sp3
	world.add_child(root)
	views[e.uid] = v
	# 出てくるときに、ぽよんと
	inner.scale = Vector3(0.3, 1.5, 1) if not e.tiny else Vector3.ONE * 0.5
	var tw := inner.create_tween()
	tw.tween_property(inner, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _sprite(tex: Texture2D, h: float) -> Sprite3D:
	var s := Sprite3D.new()
	if tex == null:
		tex = Kit.tiny_tex()
	s.texture = tex
	s.shaded = false
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.pixel_size = h / float(tex.get_height())
	s.offset = Vector2(0, tex.get_height() * 0.5)
	return s


func _sync_views(delta: float) -> void:
	var live := {}
	for e in sim.entities:
		live[e.uid] = true
		if not views.has(e.uid):
			_make_view(e)
		var v: Dictionary = views[e.uid]
		var root: Node3D = v.root
		root.position.x = lerpf(root.position.x, e.x, minf(1.0, 14.0 * delta))
		var inner: Node3D = v.inner
		v.t += delta
		if e.state == "kb":
			inner.rotation.z = (0.35 if e.side == 1 else -0.35)
			inner.position.y = 0.15
		elif e.sleep > 0:
			inner.rotation.z = 0.0
			inner.position.y = 0.0
		else:
			inner.rotation.z = lerpf(inner.rotation.z, 0.0, minf(1.0, 10.0 * delta))
			if v.spr and not v.busy:
				var hop := absf(sin(v.t * (7.0 if e.tiny else 4.5)))
				inner.position.y = (hop * (0.1 if e.tiny else 0.07)) if not e.attacking else 0.0
				if e.side == 1 and not e.attacking:
					inner.rotation.z = sin(v.t * 4.5) * 0.05
		if e.sleep > 0 and v.zz == null:
			var z := _label3d("Zz", Color("8fb4ff"), 40)
			z.position = Vector3(0, 1.1, 0.2)
			root.add_child(z)
			v.zz = z
		elif e.sleep <= 0 and v.zz != null:
			v.zz.queue_free()
			v.zz = null
	for uid in views.keys():
		if not live.has(uid):
			var v2: Dictionary = views[uid]
			views.erase(uid)
			_vanish(v2)


func _vanish(v: Dictionary) -> void:
	var root: Node3D = v.root
	if not is_instance_valid(root):
		return
	var tw := root.create_tween().set_parallel()
	if v.side == 0:
		tw.tween_property(root, "position:y", 1.2, 0.5)
	else:
		tw.tween_property(root, "position:x", root.position.x - 0.6, 0.35)
	tw.tween_property(root, "scale", Vector3(1.3, 0.1, 1), 0.35).set_delay(0.1)
	tw.chain().tween_callback(root.queue_free)


func _label3d(t: String, c: Color, size := 48) -> Label3D:
	var l := Label3D.new()
	l.text = t
	l.font = Kit.font_black
	l.font_size = size
	l.pixel_size = 0.006
	l.modulate = c
	l.outline_modulate = Color("2a2233")
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 5
	l.outline_render_priority = 4
	return l


## 3D の位置に、2D の文字をぽんと出す（縁取りがくっきり出るので 2D にした）
func _popup(t: String, pos: Vector3, c: Color, size := 48) -> void:
	if pops_alive > 14 or cam.is_position_behind(pos):
		return
	pops_alive += 1
	var l := Kit.text(t, int(size / 2.3), c, true)
	l.add_theme_color_override("font_outline_color", Kit.INK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	move_child(l, 2)
	l.reset_size()
	var sp := cam.unproject_position(pos)
	l.position = sp - l.size / 2
	l.pivot_offset = l.size / 2
	l.scale = Vector2(0.5, 0.5)
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y - 30, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.4)
	tw.tween_callback(func():
		pops_alive -= 1
		l.queue_free())


func _flash_view(v: Dictionary, c: Color) -> void:
	if v.spr:
		var s: Sprite3D = v.spr
		s.modulate = c
		s.create_tween().tween_property(s, "modulate", Color.WHITE, 0.18)
	var inner: Node3D = v.inner
	if not v.busy:
		inner.scale = Vector3(1.12, 0.9, 1)
		inner.create_tween().tween_property(inner, "scale", Vector3.ONE, 0.15)


func _lunge(v: Dictionary, dir: float, far := 0.28) -> void:
	var inner: Node3D = v.inner
	if v.busy:
		return
	v.busy = true
	var tw := inner.create_tween()
	tw.tween_property(inner, "position:x", dir * far, 0.07)
	tw.tween_property(inner, "position:x", 0.0, 0.16)
	tw.tween_callback(func(): v.busy = false)


# ---------- UI ----------

func _build_ui() -> void:
	# 3D を触ってカメラを動かす
	var drag := Control.new()
	drag.position = Vector2(0, 92)
	drag.size = Vector2(360, VIEW_H - 92)
	drag.mouse_filter = Control.MOUSE_FILTER_STOP
	drag.gui_input.connect(_on_drag)
	add_child(drag)

	var top := HBoxContainer.new()
	top.position = Vector2(8, 8)
	top.size = Vector2(344, 36)
	top.add_theme_constant_override("separation", 6)
	add_child(top)
	var pause := Kit.button("||", Color(1, 1, 1, 0.92), _pause, Kit.INK, 36, 15)
	pause.custom_minimum_size = Vector2(44, 36)
	top.add_child(pause)
	var tp := PanelContainer.new()
	tp.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.92), 18))
	tp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var num := ("%d-%d " % [si + 1, st + 1]) if not stage.get("boss_stage", false) else ""
	var tl := Kit.text(num + stage.name + ("" if GameState.lap <= 1 else "（%d周目）" % GameState.lap), 14, Kit.INK, true)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tl.clip_text = true
	tp.add_child(tl)
	top.add_child(tp)
	speed_btn = Kit.button("×1", Color(1, 1, 1, 0.92), _toggle_speed, Kit.INK, 36, 15)
	speed_btn.custom_minimum_size = Vector2(48, 36)
	top.add_child(speed_btn)

	# 体力（左：困りごとの渦、右：お店）
	var hp_row := HBoxContainer.new()
	hp_row.position = Vector2(8, 50)
	hp_row.size = Vector2(344, 22)
	hp_row.add_theme_constant_override("separation", 10)
	add_child(hp_row)
	var lp := VBoxContainer.new()
	lp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lp.add_theme_constant_override("separation", 0)
	e_lbl = Kit.text("", 11, Color.WHITE, true)
	e_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	e_lbl.add_theme_constant_override("outline_size", 4)
	lp.add_child(e_lbl)
	e_hp = Kit.bar(1.0, Color("ff6b5b"), Color(0, 0, 0, 0.3), 8)
	lp.add_child(e_hp)
	# 増援が来る目盛り
	var ticks := {}
	for sp_ in stage.spawn:
		if sp_[4] < 100:
			ticks[sp_[4]] = true
	for tk in ticks:
		var m := ColorRect.new()
		m.color = Color.WHITE
		m.size = Vector2(2, 8)
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		e_hp.add_child(m)
		e_hp.resized.connect(func(): m.position = Vector2(e_hp.size.x * tk / 100.0 - 1, 0))
	hp_row.add_child(lp)
	var rp := VBoxContainer.new()
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rp.add_theme_constant_override("separation", 0)
	a_lbl = Kit.text("", 11, Color.WHITE, true)
	a_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	a_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	a_lbl.add_theme_constant_override("outline_size", 4)
	rp.add_child(a_lbl)
	a_hp = Kit.bar(1.0, Color("7bdc6b"), Color(0, 0, 0, 0.3), 8)
	a_hp.fill_mode = ProgressBar.FILL_END_TO_BEGIN
	rp.add_child(a_hp)
	hp_row.add_child(rp)

	minimap = Control.new()
	minimap.position = Vector2(8, 78)
	minimap.size = Vector2(344, 12)
	minimap.draw.connect(_draw_minimap)
	minimap.gui_input.connect(_on_minimap)
	add_child(minimap)

	boss_bar = PanelContainer.new()
	boss_bar.add_theme_stylebox_override("panel", Kit.pill(Color(0.16, 0.13, 0.2, 0.85), 14, 0.0))
	boss_bar.position = Vector2(60, 96)
	boss_bar.size = Vector2(240, 0)
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bbv := VBoxContainer.new()
	bbv.add_theme_constant_override("separation", 2)
	var bbl := Kit.text("金曜の大ピーク", 12, Color("ffb07a"), true)
	bbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bbv.add_child(bbl)
	boss_hp = Kit.bar(1.0, Color("ff8a3d"), Color(1, 1, 1, 0.15), 10)
	boss_hp.custom_minimum_size = Vector2(210, 10)
	bbv.add_child(boss_hp)
	boss_bar.add_child(bbv)
	boss_bar.visible = false
	add_child(boss_bar)

	# 下のパネル
	var panel := Panel.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("fff8ef")
	ps.corner_radius_top_left = 22
	ps.corner_radius_top_right = 22
	ps.shadow_color = Color(0, 0, 0, 0.25)
	ps.shadow_size = 10
	panel.add_theme_stylebox_override("panel", ps)
	panel.position = Vector2(0, VIEW_H - 8)
	panel.size = Vector2(360, 640 - VIEW_H + 8)
	add_child(panel)

	var er := HBoxContainer.new()
	er.position = Vector2(10, VIEW_H + 2)
	er.size = Vector2(340, 42)
	er.add_theme_constant_override("separation", 8)
	add_child(er)
	var ev := VBoxContainer.new()
	ev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ev.add_theme_constant_override("separation", 2)
	var eh := HBoxContainer.new()
	eh.add_child(Kit.text("やる気", 13, Color("e8792f"), true))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eh.add_child(sp)
	energy_lbl = Kit.text("", 13, Kit.INK, true)
	eh.add_child(energy_lbl)
	ev.add_child(eh)
	energy_bar = Kit.bar(0.0, Color("ffb13d"), Color(0, 0, 0, 0.08), 12)
	ev.add_child(energy_bar)
	er.add_child(ev)
	wallet_btn = Kit.button("", Color("ffb13d"), _wallet, Color.WHITE, 42, 12)
	wallet_btn.custom_minimum_size = Vector2(112, 42)
	er.add_child(wallet_btn)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.position = Vector2(8, VIEW_H + 50)
	grid.size = Vector2(344, 124)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	add_child(grid)
	for i in 7:
		var b := _slot_button(i)
		grid.add_child(b)
		slot_btns.append(b)
	cannon_btn = Button.new()
	cannon_btn.custom_minimum_size = Vector2(81, 59)
	cannon_btn.clip_contents = true
	for k in ["normal", "hover", "pressed", "disabled", "focus"]:
		var cs := Kit.pill(Color("5b6fc2"), 16, 0.12)
		cs.content_margin_top = 2
		cs.content_margin_bottom = 2
		if k == "focus":
			cs.bg_color = Color(0, 0, 0, 0)
		cannon_btn.add_theme_stylebox_override(k, cs)
	cannon_btn.pressed.connect(_cannon)
	cannon_fill = ColorRect.new()
	cannon_fill.color = Color(1, 1, 1, 0.25)
	cannon_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cannon_btn.add_child(cannon_fill)
	var cl := Kit.text("休憩の\nチャイム", 12, Color.WHITE, true)
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cannon_btn.add_child(cl)
	grid.add_child(cannon_btn)

	banner = Kit.text("", 34, Color.WHITE, true)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_color_override("font_outline_color", Kit.INK)
	banner.add_theme_constant_override("outline_size", 12)
	banner.position = Vector2(0, 170)
	banner.size = Vector2(360, 110)
	banner.pivot_offset = Vector2(180, 55)
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(banner)

	flash = ColorRect.new()
	flash.color = Color.WHITE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.modulate.a = 0.0
	add_child(flash)

	hint = PanelContainer.new()
	hint.add_theme_stylebox_override("panel", Kit.pill(Color("2a2233"), 16, 0.3))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label = Kit.text("", 14, Color.WHITE, true)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_child(hint_label)
	hint.visible = false
	add_child(hint)
	_refresh_ui()


func _slot_button(i: int) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(81, 59)
	b.clip_contents = true
	var has: bool = i < sim.slots.size()
	var job := ""
	if has:
		job = DefData.unit(sim.slots[i].id).get("job", "")
	for k in ["normal", "hover", "pressed", "disabled", "focus"]:
		var s := Kit.pill(Color.WHITE if has else Color(0, 0, 0, 0.05), 16, 0.1 if has else 0.0)
		s.content_margin_top = 0
		s.content_margin_bottom = 0
		if has:
			s.border_color = JOB_COLOR.get(job, Color("ff8fb1"))
			s.set_border_width_all(3)
		if k == "focus":
			s.bg_color = Color(0, 0, 0, 0)
			s.set_border_width_all(0)
			s.shadow_size = 0
		b.add_theme_stylebox_override(k, s)
	if not has:
		b.disabled = true
		var el := Kit.text("あき", 12, Color(0, 0, 0, 0.25))
		el.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		el.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_child(el)
		return b
	var id: String = sim.slots[i].id
	var pic := TextureRect.new()
	pic.name = "pic"
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.position = Vector2(12, 1)
	pic.size = Vector2(57, 42)
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.texture = Kit.portrait(id)
	b.add_child(pic)
	var cost := Kit.text(str(sim.slots[i].cost), 13, Kit.INK, true)
	cost.name = "cost"
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.position = Vector2(0, 40)
	cost.size = Vector2(81, 18)
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cost)
	var lv := Kit.text(("★Lv%d" if sim.slots[i].lv >= DefData.VETERAN_LV else "Lv%d") % sim.slots[i].lv, 10, Color("e8792f") if sim.slots[i].lv >= DefData.VETERAN_LV else Kit.SUB, true)
	lv.position = Vector2(6, 2)
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lv)
	var cd := ColorRect.new()
	cd.name = "cd"
	cd.color = Color(0.16, 0.13, 0.2, 0.55)
	cd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cd.size = Vector2(81, 0)
	b.add_child(cd)
	b.pressed.connect(func(): _deploy(i))
	return b


func _refresh_ui() -> void:
	e_lbl.text = "困りごとの渦 %d" % maxi(0, int(ceil(sim.ebase_hp)))
	a_lbl.text = "お店 %d" % maxi(0, int(ceil(sim.base_hp)))
	e_hp.value = sim.ebase_hp / sim.ebase_max
	a_hp.value = sim.base_hp / sim.base_max
	var mx := sim.energy_max()
	energy_lbl.text = "%d / %d" % [int(sim.energy), int(mx)]
	energy_bar.value = sim.energy / mx
	if sim.wallet_lv >= DefSim.WALLET_MAX_LV:
		wallet_btn.text = "やる気Lv MAX"
		wallet_btn.disabled = true
	else:
		wallet_btn.text = "やる気Lv%d → %d\n%d" % [sim.wallet_lv, sim.wallet_lv + 1, sim.wallet_cost()]
		wallet_btn.disabled = not sim.can_wallet()
	for i in slot_btns.size():
		if i >= sim.slots.size():
			continue
		var b: Button = slot_btns[i]
		var s: Dictionary = sim.slots[i]
		var cd: ColorRect = b.get_node("cd")
		var frac: float = s.left / s.cd if s.cd > 0 else 0.0
		cd.size = Vector2(81, 59 * frac)
		var ok := sim.can_deploy(i)
		if ok and not b.get_meta("ok", false):
			Kit.pop(b, 1.1)
		b.set_meta("ok", ok)
		b.modulate = Color.WHITE if ok else Color(0.82, 0.8, 0.84)
		var cost: Label = b.get_node("cost")
		cost.add_theme_color_override("font_color", Kit.INK if sim.energy >= s.cost else Color("d9534f"))
		if s.left > 0:
			cost.text = "%.0f秒" % ceil(s.left)
		elif sim.energy < s.cost:
			cost.text = "あと%d" % int(ceil(s.cost - sim.energy))
		else:
			cost.text = str(s.cost)
		# 前の困りごとに効く仕事なら、枠を光らせる
		var job: String = DefData.unit(s.id).get("job", "")
		var glow := weak_job != "" and job == weak_job
		b.self_modulate = Color(1.0, 0.92, 0.75) if glow and sin(_t * 8.0) > 0 else Color.WHITE
		var pic: TextureRect = b.get_node("pic")
		if pic.texture == null:
			pic.texture = Kit.portrait(s.id)
	cannon_fill.size = Vector2(81, 59)
	cannon_fill.position = Vector2(0, 59 * (1.0 - sim.cannon))
	cannon_fill.size.y = 59 * sim.cannon
	cannon_btn.modulate = Color.WHITE if sim.can_cannon() else Color(0.75, 0.75, 0.82)
	if sim.can_cannon():
		cannon_btn.scale = Vector2.ONE * (1.0 + 0.04 * sin(_t * 8.0))
		cannon_btn.pivot_offset = Vector2(40, 30)
	else:
		cannon_btn.scale = Vector2.ONE
	minimap.queue_redraw()
	_update_weak_label()
	var boss := sim.find(sim.boss_uid) if sim.boss_uid >= 0 else {}
	boss_bar.visible = not boss.is_empty()
	if not boss.is_empty():
		boss_hp.value = boss.hp / boss.max_hp


var weak_job := ""


## いちばん前の困りごとの頭に、弱点をひと言だけ出す（2D の札を 3D の位置に重ねる）
func _update_weak_label() -> void:
	var front := {}
	for e in sim.entities:
		if e.side == 1 and (front.is_empty() or e.x > front.x):
			front = e
	weak_job = ""
	if weak_tag == null:
		weak_tag = PanelContainer.new()
		weak_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		weak_tag_label = Kit.text("", 11, Color.WHITE, true)
		weak_tag.add_child(weak_tag_label)
		add_child(weak_tag)
		move_child(weak_tag, 2)
	if front.is_empty() or not views.has(front.uid) or front.weak == "" or ended:
		weak_tag.visible = false
		return
	weak_job = front.weak
	var v: Dictionary = views[front.uid]
	var h: float = DefData.ENEMIES[front.id].h
	var p3: Vector3 = v.root.position + Vector3(0, h + 0.25, 0)
	if cam.is_position_behind(p3):
		weak_tag.visible = false
		return
	var sp := cam.unproject_position(p3)
	weak_tag.visible = sp.x > -20 and sp.x < 380
	var st := Kit.pill(DefData.job_color(front.weak), 10, 0.15)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	weak_tag.add_theme_stylebox_override("panel", st)
	weak_tag_label.text = "弱点 %s" % GameState.ROLE_LABEL[front.weak]
	weak_tag.reset_size()
	weak_tag.position = sp - Vector2(weak_tag.size.x / 2, weak_tag.size.y)


func _draw_minimap() -> void:
	var w := minimap.size.x
	var s := Kit.pill(Color(0, 0, 0, 0.28), 6, 0.0)
	minimap.draw_style_box(s, Rect2(Vector2.ZERO, minimap.size))
	var L := DefData.LANE
	var half := 3.3
	var r := Rect2(Vector2((cam_x - half) / L * w, 0), Vector2(half * 2 / L * w, 12))
	minimap.draw_rect(r, Color(1, 1, 1, 0.25))
	if sim.can_cannon():
		var cr := Rect2(Vector2((L - DefSim.CANNON_REACH) / L * w, 0), Vector2(DefSim.CANNON_REACH / L * w, 12))
		minimap.draw_rect(cr, Color(0.55, 0.6, 1.0, 0.35 + 0.15 * sin(_t * 6.0)))
	for e in sim.entities:
		var x: float = clampf(e.x / L, 0, 1) * w
		var c := Color("ffffff") if e.side == 0 else Color("ff6b5b")
		if e.boss:
			minimap.draw_circle(Vector2(x, 6), 5, Color("ff8a3d"))
		elif not e.tiny:
			minimap.draw_circle(Vector2(x, 6), 2.5, c)
	minimap.draw_circle(Vector2(3, 6), 4, Color("b9a7ff"))
	minimap.draw_circle(Vector2(w - 3, 6), 4, Color("7bdc6b"))


func _on_minimap(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.pressed) or ev is InputEventMouseMotion and ev.button_mask & MOUSE_BUTTON_MASK_LEFT:
		cam_x = clampf(ev.position.x / minimap.size.x * DefData.LANE, 2.6, DefData.LANE - 2.4)
		cam_hold = 3.0


func _on_drag(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			drag_from = ev.position.x
			drag_cam = cam_x
		else:
			drag_from = -1.0
	elif ev is InputEventMouseMotion and drag_from >= 0.0:
		cam_x = clampf(drag_cam - (ev.position.x - drag_from) / 52.0, 2.6, DefData.LANE - 2.4)
		cam_hold = 3.0


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k: int = ev.keycode
		if k >= KEY_1 and k <= KEY_7:
			_deploy(k - KEY_1)
		elif k == KEY_SPACE:
			_cannon()
		elif k == KEY_W:
			_wallet()
		elif k == KEY_ESCAPE and not paused:
			_pause()


func _show_hint(key: String, text: String, target: Control, once := true) -> void:
	if once and GameState.tutorial.has(key):
		return
	if demo:
		return
	if hint.visible and hint_key != key:
		return # ほかの案内を出している間は、あとで出す
	GameState.tutorial[key] = true
	hint_key = key
	hint_label.text = text
	hint_target = target
	hint.visible = true
	hint_time = 0.0
	hint.modulate.a = 0.0
	hint.reset_size()
	hint.create_tween().tween_property(hint, "modulate:a", 1.0, 0.25)


func _hide_hint(key: String) -> void:
	if hint_key == key and hint.visible:
		hint.visible = false
		hint_key = ""


func _update_hint() -> void:
	if not hint.visible or hint_target == null:
		return
	hint_time += get_process_delta_time()
	# 出しっぱなしにしない：8秒で消える。チャイムの案内は、チャイムが空になったら消える
	if (hint_time > 8.0 and hint_key != "t_deploy") or (hint_key == "t_cannon" and not sim.can_cannon()) or (hint_key == "t_deploy" and sim.deployed > 0):
		_hide_hint(hint_key)
		return
	var r := hint_target.get_global_rect()
	hint.reset_size()
	var p := Vector2(clampf(r.get_center().x - hint.size.x / 2, 8, 352 - hint.size.x), r.position.y - hint.size.y - 10 + sin(_t * 6.0) * 3.0)
	hint.position = p


# ---------- 操作 ----------

func _deploy(i: int) -> void:
	if ended or paused:
		return
	if sim.deploy(i):
		Kit.sfx("c_pop", randf_range(0.95, 1.1))
		if Rares.is_rare(sim.slots[i].id):
			_callout(sim.slots[i].id)
		Kit.pop(slot_btns[i], 0.88)
		_hide_hint("t_deploy")
		if not GameState.tutorial.has("t_energy"):
			_show_hint("t_energy", "やる気は勝手にたまる。どんどん出そう", energy_bar)
			get_tree().create_timer(3.5).timeout.connect(func(): _hide_hint("t_energy"))
	elif i < sim.slots.size():
		Kit.sfx("c_deny")
		_shake_ui(slot_btns[i])


func _wallet() -> void:
	if ended or paused:
		return
	if sim.wallet_up():
		Kit.sfx("c_levelup")
		_hide_hint("t_wallet")
		_popup_ui("やる気Lv%d！" % sim.wallet_lv, wallet_btn)
	else:
		Kit.sfx("c_deny")
		_shake_ui(wallet_btn)


func _cannon() -> void:
	if ended or paused:
		return
	if sim.fire_cannon():
		_hide_hint("t_cannon")
	elif sim.can_cannon():
		Kit.sfx("c_deny")
		_popup_ui("届くところに困りごとがいない", cannon_btn)
	else:
		Kit.sfx("c_deny")
		_shake_ui(cannon_btn)


## レアを出したときに、名前と能力をひと言だけ見せる
func _callout(id: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.96), 18, 0.2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var pic := TextureRect.new()
	pic.texture = Kit.portrait(id)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(44, 44)
	h.add_child(pic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.add_child(Kit.text(GameState.info(id).name, 16, Kit.INK, true))
	var sk := Kit.text(DefData.unit(id).get("skill", ""), 11, Kit.SUB)
	sk.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	sk.custom_minimum_size = Vector2(230, 0)
	v.add_child(sk)
	h.add_child(v)
	p.add_child(h)
	p.position = Vector2(-340, 100)
	add_child(p)
	var tw := p.create_tween()
	tw.tween_property(p, "position:x", 14.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.8)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)
	Kit.sfx("c_whoosh", 1.2)


## はじめて会う困りごと：絵と弱点をひと言
func _enemy_intro(id: String) -> void:
	var d: Dictionary = DefData.ENEMIES[id]
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Color(0.16, 0.13, 0.2, 0.92), 18, 0.2))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var pic := TextureRect.new()
	pic.texture = Kit.enemy_tex(id)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(48, 48)
	h.add_child(pic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.add_child(Kit.text("はじめての困りごと：" + d.name, 14, Color.WHITE, true))
	var sk := Kit.text(d.line, 11, Color("e8e2ff"))
	sk.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	sk.custom_minimum_size = Vector2(230, 0)
	v.add_child(sk)
	h.add_child(v)
	p.add_child(h)
	p.position = Vector2(380, 104)
	add_child(p)
	var tw := p.create_tween()
	tw.tween_property(p, "position:x", 14.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


func _shake_ui(c: Control) -> void:
	var x := c.position.x
	var tw := c.create_tween()
	for k in 3:
		tw.tween_property(c, "position:x", x + 4, 0.03)
		tw.tween_property(c, "position:x", x - 4, 0.03)
	tw.tween_property(c, "position:x", x, 0.03)


func _popup_ui(t: String, near: Control) -> void:
	var l := Kit.text(t, 18, Color("ffb13d"), true)
	l.add_theme_color_override("font_outline_color", Color.WHITE)
	l.add_theme_constant_override("outline_size", 8)
	var r := near.get_global_rect()
	l.position = Vector2(r.position.x, r.position.y - 26)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 30, 0.7)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.3)
	tw.tween_callback(l.queue_free)


func _toggle_speed() -> void:
	speed = 2 if speed == 1 else 1
	speed_btn.text = "×%d" % speed
	GameState.set_meta("speed", speed)


func _pause() -> void:
	if ended or paused:
		return
	paused = true
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.15, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Kit.pill(Kit.CREAM, 24))
	p.position = Vector2(40, 200)
	p.size = Vector2(280, 0)
	overlay.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var t := Kit.text("ひと休み", 22, Kit.INK, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for line in _stage_tips():
		var l := Kit.text(line, 12, Kit.SUB)
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		v.add_child(l)
	v.add_child(Kit.button("つづける", Kit.ACCENT, func():
		paused = false
		overlay.queue_free()
		overlay = null))
	var mb := Kit.button("音楽：%s" % ("ON" if Kit.music_on else "OFF"), Color.WHITE, func(): pass, Kit.INK, 40, 14)
	mb.pressed.connect(func():
		Kit.set_music_on(not Kit.music_on)
		GameState.settings["music"] = Kit.music_on
		GameState.save_game()
		mb.text = "音楽：%s" % ("ON" if Kit.music_on else "OFF"))
	v.add_child(mb)
	v.add_child(Kit.button("あきらめて帰る", Color("b0a4b8"), func():
		overlay.queue_free()
		overlay = null
		paused = false
		retreated = true
		sim.base_hp = 0
		sim.tick(0.0)))


func _stage_tips() -> Array:
	var ids := {}
	for s in stage.spawn:
		ids[s[0]] = true
	var out: Array = []
	for id in ids:
		var d: Dictionary = DefData.ENEMIES[id]
		if d.weak != "":
			var sp: String = GameState.info(GameState.species_for_type(d.weak)).name
			out.append("・%s は %s（%s）に弱い" % [d.name, GameState.ROLE_LABEL[d.weak], sp])
		else:
			out.append("・%s に弱点はない" % d.name)
	return out


# ---------- 進行 ----------

func _intro() -> void:
	_banner("ピーク開始！", Color("ffd23f"))
	Kit.sfx("c_bell", 1.2, -6)
	if not boost.lines.is_empty():
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", Kit.pill(Color(1, 1, 1, 0.95), 16))
		p.position = Vector2(20, 104)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.add_child(Kit.text("今日の応援", 12, Color("e8792f"), true))
		for line in boost.lines:
			var bl := Kit.text(line, 12, Kit.INK)
			bl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			bl.custom_minimum_size = Vector2(290, 0)
			v.add_child(bl)
		p.add_child(v)
		add_child(p)
		p.modulate.a = 0.0
		var tw := p.create_tween()
		tw.tween_property(p, "modulate:a", 1.0, 0.3)
		tw.tween_interval(4.5)
		tw.tween_property(p, "modulate:a", 0.0, 0.5)
		tw.tween_callback(p.queue_free)
	if si == 0 and st == 0:
		get_tree().create_timer(1.2).timeout.connect(func():
			if sim.slots.size() > 0:
				_show_hint("t_deploy", "タップで、レシートンを出す", slot_btns[0]))


func _process(delta: float) -> void:
	_t += delta
	if not paused and not ended:
		if auto:
			sim.ai_step(delta * speed, 0.8)
		acc += delta * speed
		var dt := 1.0 / 30.0
		var steps := 0
		while acc >= dt and steps < 8 * speed:
			sim.tick(dt)
			acc -= dt
			steps += 1
		_handle_events(sim.pop_events())
	_sync_views(delta)
	# カメラ：触っていなければ前線を追う
	cam_hold -= delta
	if cam_hold <= 0 and not ended:
		var target := clampf(sim.front_x(), 2.6, DefData.LANE - 2.4)
		cam_x = lerpf(cam_x, target, minf(1.0, 1.6 * delta))
	shake = maxf(0.0, shake - delta * 2.5)
	_place_cam()
	_refresh_ui()
	_update_hint()
	# チュートリアル：やる気Lv とチャイム
	if not ended and sim.t > 10.0 and sim.can_wallet() and sim.wallet_lv == 1:
		_show_hint("t_wallet", "やる気Lvを上げると、たまるのが速くなる", wallet_btn)
	if not ended and sim.can_cannon():
		_show_hint("t_cannon", "チャイムがたまった！押すと困りごとを押し返す", cannon_btn)


func _handle_events(evs: Array) -> void:
	var hits := 0
	for ev in evs:
		match ev.type:
			"spawn":
				var se := sim.find(ev.uid)
				if not se.is_empty() and se.side == 1:
					_fx("puff", Vector3(se.x, 0.6, se.z + 0.3))
				if not se.is_empty() and se.side == 1 and not demo:
					if not GameState.enemies_seen.has(se.id) and not se.boss:
						_enemy_intro(se.id)
					GameState.enemies_seen[se.id] = true
				if ev.get("boss", false):
					_boss_arrives()
			"attack":
				var e := sim.find(ev.uid)
				if views.has(ev.uid) and not e.is_empty():
					var v: Dictionary = views[ev.uid]
					_lunge(v, -1.0 if e.side == 0 else 1.0, 0.18 if e.side == 1 else 0.28)
					if ev.bolt:
						_bolt(ev.tx)
					elif e.side == 0 and not e.tiny and e.job != "":
						# 仕事ごとの色で、攻撃が当たった場所にしぶき（泡・油・レシート…）
						_fx("job", Vector3(ev.tx + 0.2, 0.55, 0.45), JOB_COLOR.get(e.job, Color.WHITE).lightened(0.2))
			"hit":
				if views.has(ev.uid):
					var v2: Dictionary = views[ev.uid]
					_flash_view(v2, Color(1, 0.55, 0.55) if v2.side == 1 else Color(1, 0.7, 0.7))
					var pos: Vector3 = v2.root.position + Vector3(0, 0.5, 0.3)
					if hits < 6:
						_fx("weak" if ev.weak else "hit", pos)
						Kit.sfx("c_heavy" if ev.dmg >= 80 else "c_hit", randf_range(0.9, 1.2), -4 if ev.dmg < 80 else 0)
					hits += 1
					if ev.weak:
						_popup("効く！", pos + Vector3(0, 0.5, 0), Color("ff8a5b"), 40)
					elif ev.dmg >= 60:
						_popup(str(int(ev.dmg)), pos + Vector3(0, 0.4, 0), Color.WHITE, 44)
			"kb":
				if views.has(ev.uid):
					var v3: Dictionary = views[ev.uid]
					_fx("puff", v3.root.position + Vector3(0, 0.4, 0.3))
			"die":
				var pos2 := Vector3(ev.x, 0.5, 0.4)
				_fx("puff", pos2)
				if ev.side == 1:
					Kit.sfx("c_coin", randf_range(0.95, 1.1), -6)
					_popup(DefData.RESOLVED.get(ev.id, "解決"), Vector3(ev.x, 1.5, 0.5), Color.WHITE, 34)
				elif randf() < 0.5:
					Kit.sfx("c_pop", 0.55, -10)
				if ev.boss:
					shake = 1.2
					_flash(0.8)
					_banner("大ピーク、\n落ちついた！", Color("ffd23f"))
			"gain":
				_fx("gold", Vector3(ev.x, 0.6, 0.4))
				_popup("+%d" % int(ev.amount), Vector3(ev.x, 1.0, 0.5), Color("ffd23f"), 36)
			"ebase":
				_flash_view_node(ebase_node)
				if randf() < 0.3:
					_fx("hit", ebase_node.position + Vector3(0.6, 1.2, 0.5))
			"base":
				_flash_view_node(base_node)
				shake = maxf(shake, 0.35)
				Kit.sfx("c_crash", randf_range(0.9, 1.1), -6)
				_flash(0.12, Color("ff6b5b"))
			"cannon":
				_cannon_fx()
				if ev.get("stopped", 0) > 0:
					_hitstop()
					_banner("大技を止めた！", Color("ffd23f"))
				elif ev.get("boss_stun", false):
					_popup("ひるんだ！", Vector3(cam_x, 3.2, 0.5), Color("ff8a3d"), 60)
				if ev.hit >= 3:
					_banner("%d体、押し返した！" % ev.hit, Color("fff6e0"))
				else:
					_popup_ui("%d体 押し返した" % ev.hit, cannon_btn)
			"hop":
				if views.has(ev.uid):
					var v4: Dictionary = views[ev.uid]
					v4.busy = true
					var inner: Node3D = v4.inner
					var tw := inner.create_tween()
					tw.tween_property(inner, "position:y", 1.3, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
					tw.tween_property(inner, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
					tw.tween_callback(func(): v4.busy = false)
					Kit.sfx("c_whoosh")
			"heal":
				if views.has(ev.uid):
					_fx("heal", views[ev.uid].root.position + Vector3(0, 0.8, 0.3))
			"sleep":
				pass
			"gift":
				_popup_ui("やる気 +250 おすそわけ", energy_lbl)
				Kit.sfx("c_coin", 1.3)
			"drain":
				_popup_ui("やる気 -%d" % 20, energy_lbl)
			"surge_warn":
				if ev.boss:
					_banner("大ピークまで\nあと3秒", Color("ff8a3d"))
				else:
					_banner("%s、\nあと3秒で押し寄せる" % DefData.ENEMIES[ev.id].name, Color("ff8a5b"))
				Kit.sfx("c_drum", 1.3, -4)
			"refill":
				if views.has(ev.uid):
					_popup("補充！", views[ev.uid].root.position + Vector3(0, 1.1, 0.3), Color("e8b878"), 40)
			"wallet":
				pass
			"windup":
				if views.has(ev.uid):
					var vw: Dictionary = views[ev.uid]
					var ent := sim.find(ev.uid)
					if vw.spr and not ent.is_empty():
						var sp: Sprite3D = vw.spr
						var tw := sp.create_tween()
						tw.tween_property(sp, "modulate", Color(1, 0.45, 0.4), 0.25)
						tw.tween_property(sp, "modulate", Color.WHITE, 0.25)
						tw.tween_property(sp, "modulate", Color(1, 0.45, 0.4), 0.25)
						tw.tween_property(sp, "modulate", Color.WHITE, 0.25)
						Kit.sfx("c_drum", 2.2, -10)
						_popup("!", vw.root.position + Vector3(0, DefData.ENEMIES[ent.id].h + 0.2, 0.3), Color("ff6b5b"), 90)
						if sim.can_cannon() and not GameState.tutorial.has("t_windup") and ent.x >= DefData.LANE - DefSim.CANNON_REACH:
							_show_hint("t_windup", "「！」のあいだにチャイムを当てると、大技が止まる", cannon_btn)
							get_tree().create_timer(3.0).timeout.connect(func(): _hide_hint("t_windup"))
			"closing":
				_banner("閉店時間が近い。\n渦が弱ってきた", Color("b9c4ff"))
			"win":
				_end(true)
			"lose":
				_end(false)


func _flash_view_node(n: Node3D) -> void:
	var inner: Node3D = n.get_node_or_null("inner")
	if inner == null:
		return
	inner.scale = Vector3(1.06, 0.95, 1)
	inner.create_tween().tween_property(inner, "scale", Vector3.ONE, 0.2)
	var spr: Sprite3D = inner.get_node_or_null("spr")
	if spr:
		spr.modulate = Color(1, 0.6, 0.6)
		spr.create_tween().tween_property(spr, "modulate", Color.WHITE, 0.25)


func _bolt(tx: float) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.14, 9.0, 0.14)
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("fff27a")
	m.material_override = mat
	m.position = Vector3(tx, 4.5, 0.4)
	m.rotation.z = randf_range(-0.08, 0.08)
	world.add_child(m)
	_fx("zap", Vector3(tx, 0.3, 0.4))
	Kit.sfx("c_zap", randf_range(0.9, 1.1))
	_flash(0.25, Color("fff6c0"))
	shake = maxf(shake, 0.3)
	var tw := m.create_tween()
	tw.tween_property(m, "scale:x", 0.2, 0.25)
	tw.tween_callback(m.queue_free)


func _cannon_fx() -> void:
	Kit.sfx("c_bell")
	shake = 0.8
	_flash(0.5, Color("fff6e0"))
	var wave := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.5, 3.0, 2.6)
	wave.mesh = b
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 0.97, 0.85, 0.7)
	wave.material_override = mat
	wave.position = Vector3(DefData.LANE - 0.5, 1.5, 0.3)
	world.add_child(wave)
	var tw := wave.create_tween().set_parallel()
	tw.tween_property(wave, "position:x", DefData.LANE - DefSim.CANNON_REACH, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.7)
	tw.chain().tween_callback(wave.queue_free)
	_popup("キーンコーン", Vector3(cam_x, 2.6, 0.5), Color("fff6e0"), 70)
	cam_hold = 0.0


func _boss_arrives() -> void:
	if boss_seen:
		return
	boss_seen = true
	Kit.sfx("c_drum")
	shake = 1.0
	_banner("金曜の大ピーク、\n来た。", Color("ff8a3d"))
	cam_x = 3.0
	cam_hold = 1.5


func _banner(t: String, c: Color) -> void:
	banner.text = t
	banner.add_theme_color_override("font_color", c)
	banner.modulate.a = 1.0
	banner.scale = Vector2(0.4, 0.4)
	var tw := banner.create_tween()
	tw.tween_property(banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.1)
	tw.tween_property(banner, "modulate:a", 0.0, 0.4)


func _flash(a: float, c := Color.WHITE) -> void:
	flash.color = c
	flash.modulate.a = a
	flash.create_tween().tween_property(flash, "modulate:a", 0.0, 0.35)


func _end(won: bool) -> void:
	if ended:
		return
	ended = true
	_hide_hint(hint_key)
	Kit.music("")
	var stats := {"time": sim.t, "kills": sim.kills, "deployed": sim.deployed, "base": sim.base_hp / sim.base_max, "retreat": retreated}
	var r: Dictionary = GameState.record_battle(si, st, won, stats) if not demo else {"won": won, "coins": stage.reward, "first": true, "orb": false, "lap_up": false, "stats": stats}
	if won:
		Kit.sfx("c_fanfare")
		shake = 1.0
		_flash(0.9)
		# 渦がしぼんで消える
		var inner: Node3D = ebase_node.get_node("inner")
		var tw := inner.create_tween()
		tw.tween_property(inner, "scale", Vector3(1.3, 0.2, 1), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		for k in 4:
			_fx("puff", Vector3(randf_range(-0.4, 0.8), randf_range(0.5, 2.5), 0.5))
		for uid in views:
			var v: Dictionary = views[uid]
			if v.side == 1:
				_fx("puff", v.root.position + Vector3(0, 0.5, 0.3))
				v.root.visible = false
		cam_hold = 5.0
		cam_x = 3.0
		_banner("守りきった！", Color("ffd23f"))
		_confetti()
	else:
		Kit.sfx("c_lose")
		shake = 1.2
		_banner("お店が\nパンクした…", Color("b9c4ff"))
		cam_hold = 5.0
		cam_x = DefData.LANE - 2.4
	await get_tree().create_timer(1.8).timeout
	if demo:
		return
	_result(r)


## ヒットストップ：一瞬だけ時間を止める
func _hitstop() -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.07, true, false, true).timeout
	Engine.time_scale = 1.0


func _confetti() -> void:
	for k in 3:
		var p := CPUParticles2D.new()
		p.position = Vector2(60 + k * 120, -10)
		p.amount = 40
		p.lifetime = 2.6
		p.one_shot = true
		p.explosiveness = 0.8
		p.direction = Vector2(0, 1)
		p.spread = 50
		p.initial_velocity_min = 120
		p.initial_velocity_max = 260
		p.gravity = Vector2(0, 240)
		p.angular_velocity_min = -300
		p.angular_velocity_max = 300
		p.scale_amount_min = 4
		p.scale_amount_max = 7
		var g := Gradient.new()
		g.set_color(0, Color("ffd23f"))
		g.set_color(1, Color("ff6b5b"))
		g.add_point(0.5, Color("5fc4ff"))
		p.color_initial_ramp = g
		add_child(p)
		p.emitting = true
		get_tree().create_timer(3.0).timeout.connect(p.queue_free)


func _result(r: Dictionary) -> void:
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.1, 0.08, 0.15, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var p := PanelContainer.new()
	var ps := Kit.pill(Kit.CREAM, 26)
	ps.content_margin_top = 18
	ps.content_margin_bottom = 18
	ps.content_margin_left = 18
	ps.content_margin_right = 18
	p.add_theme_stylebox_override("panel", ps)
	p.position = Vector2(24, 150)
	p.size = Vector2(312, 0)
	overlay.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	var won: bool = r.won
	var t := Kit.text("守りきった！" if won else "お店がパンクした…", 26, Kit.INK, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := Kit.text("%s　%s" % [shop.name, stage.name], 13, Kit.SUB)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var coin_l := Kit.text("まかない +0", 22, Color("e8792f"), true)
	coin_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(coin_l)
	coin_l.visible = r.coins > 0
	var target: int = r.coins
	var tw := coin_l.create_tween()
	tw.tween_method(func(x: float):
		coin_l.text = "まかない +%d" % int(x), 0.0, float(target), 0.8)
	for k in 5:
		get_tree().create_timer(0.1 + k * 0.15).timeout.connect(func(): Kit.sfx("c_coin", 1.0 + k * 0.06, -4))
	var notes: Array = []
	if won:
		if r.first:
			notes.append(["はじめてクリア！", Color("ff6b5b")])
		if r.get("join", "") != "":
			var ju: Dictionary = DefData.unit(r.join)
			notes.append(["%sが仲間になった（%s：%s）" % [GameState.info(r.join).name, ju.role, ju.line], Color("8b7bff")])
		if r.get("perfect", false):
			notes.append(["★ お店は無傷！ まかない +30%", Color("e8a317")])
		if r.get("focus", "") != "":
			notes.append(["%sに経験 +%d（育てたい一体）" % [GameState.info(r.focus).name, GameState.FOCUS_XP], Color("8b7bff")])
		if r.get("daily", false):
			notes.append(["今日のお手伝い +60", Color("e8792f")])
		if r.orb:
			notes.append([shop.get("thanks", ""), Kit.INK])
			notes.append(["虹色の玉をもらった（明日の朝かえる）", Color("8b7bff")])
		if r.lap_up:
			notes.append(["%d周目がひらいた：もっと混む" % GameState.best_lap, Color("8b7bff")])
		var nx := GameState.next_stage()
		if r.first and not r.lap_up and not (nx[0] == si and nx[1] == st):
			notes.append(["つぎ：%s" % DefData.stage(nx[0], nx[1]).name, Kit.INK])
		if not r.first:
			notes.append(["くり返しのまかないは半分（その日4勝目からは4分の1）", Kit.SUB])
	else:
		notes.append(["困りごとには、効く仕事がある", Kit.INK])
		for line in _stage_tips():
			notes.append([line, Kit.SUB])
		notes.append(["強化すると、おばけが強くなる", Kit.INK])
	for n in notes:
		var l := Kit.text(n[0], 13, n[1], true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		v.add_child(l)
	var s: Dictionary = r.stats
	var st_l := Kit.text("%d秒　たおした困りごと %d　出したおばけ %d" % [int(s.time), s.kills, s.deployed], 11, Kit.SUB)
	st_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st_l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	if won:
		var to_room: bool = GameState.day == 0 and not GameState.scooped_tonight and GameState.total_battles >= 2
		if to_room:
			var tl := Kit.text("夜は川べりで、新しい仲間をすくおう", 13, Color("5b6fc2"), true)
			tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(tl)
			v.move_child(tl, v.get_child_count() - 2)
		var b1 := Kit.button("休憩室へ" if to_room else ("つぎへ" if r.first else "地図へ"), Kit.ACCENT, func():
			GameState.set_meta("open_next", r.first)
			main.go("room" if to_room else "map"))
		b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b1)
		var b2 := Kit.button("もう一回", Color("b0a4b8"), func(): main.go("defense"))
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b2)
	else:
		var b3 := Kit.button("強化する", Kit.PURPLE, func(): main.go("crew"))
		b3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b3)
		var b4 := Kit.button("もう一回", Kit.ACCENT, func(): main.go("defense"))
		b4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b4)
		var b5 := Kit.button("地図へ", Color("b0a4b8"), func(): main.go("map"), Color.WHITE, 40, 14)
		v.add_child(b5)
	p.scale = Vector2(0.8, 0.8)
	p.pivot_offset = Vector2(156, 150)
	p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------- 確認用 ----------

func demo_rush() -> void:
	# 画面確認用：少し進めて、にぎやかにする
	auto = true
	speed = 2
