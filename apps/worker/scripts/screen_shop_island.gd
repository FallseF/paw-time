extends Control
## お店の島（実績で育つ島）。行き先は GameState.visit.shop（求人カードの「島を見にいく」・働いたお店の一覧から）。
## 島の目印は、働いた人の評価のタグだけで育つ（ShopCulture）。お店が決めたのは看板の名前・色・ひとことだけ。
## 自分のおばネコが歩ける（地面をタップ）。目印をタップすると「働いた人の声：時間どおりに帰れる ×23」のカード。
## よいものが足されるだけ：減る・枯れる・順位は出さない。見本のデータであることを画面に出す。

var main

const INK := Color("2a2233")
const SUB := Color("6a5f70")
const GREEN := Color("3f8a55")
const PAPER := Color(1, 0.99, 0.97, 0.96)
## 目印の置き場所（段 0 の島（半径 3.9）に収まる）。お店はうしろの丘、灯りの小道はまんなか、アーチは岸辺
const SLOTS := {
	"clock_tower": Vector3(-2.45, 0, -1.3),
	"rest_grove": Vector3(2.25, 0, -1.25),
	"guide_post": Vector3(-1.5, 0, 1.2),
	"payday_bell": Vector3(1.55, 0, 1.25),
	"lantern_path": Vector3(0, 0, 0.1),
	"fair_fountain": Vector3(-2.75, 0, 0.35),
	"welcome_arch": Vector3(0, 0, 2.55),
}
const SHOP_AT := Vector3(0, 0, -3.1)
const PIER_DIR := Vector3(0.93, 0, 0.36)

var shop_id := ""
var prof := {}
var lms: Array = []
var totals := {}
var vp: SubViewport
var world: Node3D
var cam: Camera3D
var env: Environment
var sun: DirectionalLight3D
var sea_mat: StandardMaterial3D
var R := 3.9
var marks: Array = [] # {data, node, anchor}
var cat: Obake3D
var cat_target := Vector3.ZERO
var cat_speed := 1.3
var card: PanelContainer
var card_box: VBoxContainer
var openings: Array = [] # このお店のいまの募集
var jobs_btn: Button
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	shop_id = String(GameState.visit.get("shop", Invites.SAMPLE_LISTING))
	Telemetry.track("shop_island_visit", JobListings.telemetry_shop(shop_id))
	prof = ShopCulture.profile(shop_id)
	totals = Reviews.totals(shop_id)
	lms = ShopCulture.landmarks_from(totals)
	_build_world()
	_build_ui()


# ---------------------------------------------------------------- 3D

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
	var rig := Look.apply(world, "island", Color("bfe4f4"), false, true)
	env = rig.env
	sun = rig.key
	Look.island_time(Look.island_rig(world), env, sun, 0.12)
	var stage := ShopCulture.stage_for(lms)
	R = IslandKit.STAGES[stage].radius
	_build_sea()
	_build_terrain(stage)
	var shop := ShopLandmarks.build_shop(prof.sign, prof.accent)
	shop.position = SHOP_AT
	world.add_child(shop)
	_shop_sign(shop)
	# 島のふちの木（見本の島の、いつもの景色。評価とは関係ない）
	for at in [Vector3(-3.2, 0, -2.4), Vector3(3.3, 0, -2.3), Vector3(-3.5, 0, 1.7)]:
		var tr_ := IslandProps.build("tree_round" if at.x < 0 else "tree_pine")
		tr_.position = at
		tr_.scale = Vector3.ONE * 0.9
		world.add_child(tr_)
	# 桟橋（庭の島と同じ向き：右手前）。おばネコはここから上がってくる
	var pier := IslandProps.build("pier")
	pier.position = PIER_DIR * (R + 0.2)
	pier.rotation.y = atan2(PIER_DIR.x, PIER_DIR.z)
	world.add_child(pier)
	# 目印：票が集まったタグだけ。段 0 は芽（票が 1〜2）か、何も置かない
	var i := 0
	for lm in lms:
		if int(lm.level) == 0 and not lm.sprout:
			continue
		var n := ShopLandmarks.build_landmark(lm.id, int(lm.level))
		var at := _slot(lm.id)
		n.position = at
		if lm.id in ["clock_tower", "fair_fountain"]:
			n.rotation.y = 0.45
		elif lm.id in ["rest_grove"]:
			n.rotation.y = -0.4
		world.add_child(n)
		var h: float = 0.5 if int(lm.level) == 0 else [0.9, 1.3, 1.8][int(lm.level) - 1]
		marks.append({"data": lm, "node": n, "anchor": at + Vector3(0, h, 0)})
		# 着いたら、ひとつずつ、ぽんと出る
		n.scale = Vector3.ONE * 0.01
		var tw := create_tween()
		tw.tween_interval(0.3 + i * 0.12)
		tw.tween_property(n, "scale", Vector3.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		i += 1
	for l in world.find_children("*", "OmniLight3D", true, false):
		(l as OmniLight3D).light_energy = 0.35
	_build_cat()
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.fov = 50
	var k := lerpf(1.0, R / 3.9, 0.6)
	cam.position = Vector3(0, 6.3, 6.9) * k
	cam.v_offset = -0.75
	world.add_child(cam)
	cam.look_at(Vector3(0, 0, -0.5))


## 目印の置き場所。島が広いほど（地形の段 1・2）、左右と手前へ少し広げる
func _slot(id: String) -> Vector3:
	var at: Vector3 = SLOTS.get(id, Vector3.ZERO)
	var k := R / 3.9
	return Vector3(at.x * k, 0, at.z * k if at.z > 0 else at.z)


func _build_sea() -> void:
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	sea.mesh = pm
	sea_mat = StandardMaterial3D.new()
	sea_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sea_mat.albedo_color = Color(0.2, 0.62, 0.74, 0.72)
	sea_mat.metallic_specular = 0.6
	sea_mat.roughness = 0.25
	sea.material_override = sea_mat
	sea.position.y = -0.14
	world.add_child(sea)


## 島の地形（庭の画面と同じ Blender の地形・同じ材質）と、深い海の底
func _build_terrain(stage: int) -> void:
	var m := Obake3D.skin(Color.WHITE, 0.0, null, 0.06, 0.0, false, 0.02).duplicate() as ShaderMaterial
	m.set_shader_parameter("vertex_albedo", 1.0)
	IslandProps.terrain_look(m)
	m.set_shader_parameter("ground_mottle", 0.07)
	m.set_shader_parameter("top_light", 0.0)
	var t := MeshInstance3D.new()
	t.mesh = IslandProps.glb("terrain_s%d" % stage)
	t.material_override = m
	world.add_child(t)
	var arr := t.mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var c: PackedColorArray = arr[Mesh.ARRAY_COLOR]
	if v.is_empty() or c.size() != v.size():
		return
	var lo := 0
	for i in v.size():
		if v[i].y < v[lo].y:
			lo = i
	var bed := MeshInstance3D.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := 200.0
	var corners := [Vector3(-h, 0, -h), Vector3(h, 0, -h), Vector3(h, 0, h), Vector3(-h, 0, h)]
	for idx in [0, 1, 2, 0, 2, 3]:
		st.set_color(c[lo])
		st.set_normal(Vector3.UP)
		st.add_vertex(corners[idx])
	bed.mesh = st.commit()
	bed.material_override = m
	bed.position.y = v[lo].y - 0.004
	world.add_child(bed)


## 屋根の上の看板に、お店が決めた名前
func _shop_sign(shop: Node3D) -> void:
	var l := Kit.label3d(prof.name, 40, prof.sign.darkened(0.45))
	l.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	l.no_depth_test = false
	l.outline_size = 0
	var w := l.font.get_string_size(prof.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	l.pixel_size = minf(0.006, 1.6 / maxf(1.0, w))
	l.position = Vector3(0, 1.98, 0.27)
	shop.add_child(l)


## 自分のおばネコ（乗り物の場面と同じ子）。桟橋から上がってくる
func _build_cat() -> void:
	var h: String = GameState.host()
	if h == "my" and not GameState.my_obake.is_empty():
		cat = Outfit.make("my")
	else:
		cat = Outfit.make(h if h != "my" and h != "" else "receipt")
	cat.scale = Vector3.ONE * 0.62
	cat.position = PIER_DIR.normalized() * (R - 0.4)
	world.add_child(cat)
	cat_target = Vector3(0.5, 0, 1.9)


func _process(delta: float) -> void:
	_t += delta
	if cat == null:
		return
	var d := cat_target - cat.position
	d.y = 0
	if d.length() > 0.05:
		cat.position += d.normalized() * minf(d.length(), cat_speed * delta)
		cat.position.y = absf(sin(_t * 9.0)) * 0.06
		cat.rotation.y = lerp_angle(cat.rotation.y, atan2(d.x, d.z), 6.0 * delta)
	else:
		cat.position.y = move_toward(cat.position.y, 0.0, delta)


## 島の上か（地形の段の円・うしろの丘のお店には入らない）
func _walkable(p: Vector3) -> bool:
	return Vector2(p.x, p.z).length() < R - 0.55 and p.z > SHOP_AT.z + 1.3


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var pos: Vector2 = event.position
	if pos.y < 150 or (card and is_instance_valid(card) and card.get_global_rect().has_point(pos)):
		return
	# 目印の近くなら、その目印の声
	var best = null
	var bd := 56.0
	for mk in marks:
		var sp := View3D.unproject(cam, mk.anchor)
		var dist := sp.distance_to(pos)
		if dist < bd:
			bd = dist
			best = mk
	if best != null:
		open_mark(best)
		walk_to(best.anchor * Vector3(1, 0, 1) + Vector3(0, 0, 0.7))
		return
	# 地面なら、そこへ歩く
	var from := cam.project_ray_origin(View3D.to_vp(cam, pos))
	var dir := cam.project_ray_normal(View3D.to_vp(cam, pos))
	if absf(dir.y) < 0.001:
		return
	var p := from + dir * (-from.y / dir.y)
	walk_to(p)


func walk_to(p: Vector3) -> void:
	p.y = 0
	if not _walkable(p):
		var v := Vector2(p.x, p.z).limit_length(R - 0.6)
		p = Vector3(v.x, 0, maxf(v.y, SHOP_AT.z + 1.35))
	cat_target = p
	Kit.play(self, "tap", 1.2, -8)


# ---------------------------------------------------------------- 画面の文字

func _build_ui() -> void:
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", Kit.pill(PAPER, 20, 0.16, Vector2(14, 10)))
	top.position = Vector2(12, 12)
	top.size = Vector2(336, 0)
	add_child(top)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.custom_minimum_size = Vector2(308, 0)
	top.add_child(v)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(14, 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ds := StyleBoxFlat.new()
	ds.bg_color = prof.sign
	ds.set_corner_radius_all(7)
	dot.add_theme_stylebox_override("panel", ds)
	row.add_child(dot)
	var nm := Kit.text(prof.name, 18, INK, true)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(nm)
	var home := Kit.button(tr("SHOP_HOME"), Color("f3ecff"), go_home, Color("6a5bd6"), 32, 13)
	home.custom_minimum_size.x = 64
	row.add_child(home)
	v.add_child(row)
	v.add_child(I18n.wrap(Kit.text(tr("SHOP_IN_THEIR_WORDS") % prof.values, 12, SUB)))
	var cred := PanelContainer.new()
	cred.add_theme_stylebox_override("panel", Kit.pill(Color("f1f7f1"), 10, 0.0, Vector2(8, 3)))
	cred.add_child(I18n.wrap(Kit.text(tr("SHOP_BASED_ON") % int(totals.count), 12, GREEN, true)))
	v.add_child(cred)
	v.add_child(I18n.wrap(Kit.text(tr("SHOP_RULE"), 11, SUB)))
	var hint := Kit.text(tr("SHOP_HINT"), 12, Color(1, 1, 1, 0.92), true, HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, 596)
	hint.size = Vector2(360, 20)
	hint.add_theme_color_override("font_outline_color", Color(0.1, 0.2, 0.3, 0.6))
	hint.add_theme_constant_override("outline_size", 4)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	# いまの募集（このお店の、今の言語の町の見本の求人）。押すと一覧のカード
	openings = open_jobs()
	if not openings.is_empty():
		jobs_btn = Kit.button(tr("SHOP_JOBS_BTN") % openings.size(), Color("ff8a5b"), open_jobs_card, Color.WHITE, 40, 14)
		jobs_btn.position = Vector2(14, 546)
		jobs_btn.size = Vector2(0, 40)
		add_child(jobs_btn)
	var note := Kit.text(tr("SHOP_SAMPLE_NOTE"), 10, Color(1, 1, 1, 0.8), false, HORIZONTAL_ALIGNMENT_CENTER)
	note.position = Vector2(0, 616)
	note.size = Vector2(360, 16)
	note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(note)


## このお店のいまの募集（今の言語の町の見本。今日の求人の知らせに出ているものが先。受けた・決めたものは出さない）
func open_jobs() -> Array:
	var out: Array = JobDesk.today_jobs().filter(func(j): return j.listing == shop_id)
	for j in JobListings.shop_openings(shop_id, 3, hash(shop_id + JobDesk.today_key())):
		if out.size() < 3 and not out.any(func(x): return x.start == j.start):
			out.append(j)
	var mine := Shifts.all().map(func(x): return x.id)
	var dec: Dictionary = JobDesk._board.get("decided", {})
	out = out.filter(func(j): return not mine.has(j.id) and not dec.has(j.id))
	out.sort_custom(func(a, b): return a.start < b.start)
	return out


## いまの募集のカード：1 件ずつの行。押すと島へ戻って、その仕事のくわしいカード（受けるのはそこから）
func open_jobs_card() -> void:
	var box := _new_card()
	var row := HBoxContainer.new()
	var t := Kit.text(tr("SHOP_JOBS_TITLE"), 18, INK, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(t)
	row.add_child(_close_btn())
	box.add_child(row)
	for j in openings:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 56)
		for k in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(k, Kit.pill(Color("fff1e0") if k == "pressed" else Color.WHITE, 14, 0.1, Vector2(10, 6)))
		var h := HBoxContainer.new()
		h.set_anchors_preset(Control.PRESET_FULL_RECT)
		h.offset_left = 12
		h.offset_right = -10
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(h)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		v.add_theme_constant_override("separation", 0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(Kit.text(String(j.title), 14, INK, true))
		v.add_child(Kit.text(JobListings.when_text(j), 12, SUB, true))
		h.add_child(v)
		var w := Kit.text(JobListings.wage_text(j), 18, Color("e0663a"), true)
		w.add_theme_font_override("font", Kit.black())
		w.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(w)
		var job: Dictionary = j
		b.pressed.connect(func(): see_job(job))
		box.add_child(b)
	box.add_child(I18n.wrap(Kit.text(tr("SHOP_JOBS_NOTE"), 11, SUB)))
	_show_card()


## 島へ戻って、その仕事のくわしいカードを開く
func see_job(j: Dictionary) -> void:
	Kit.play(self, "tap", 1.1)
	JobDesk.focus_job = j
	go_home()


func _new_card() -> VBoxContainer:
	close_card()
	Kit.play(self, "pop", 1.1, -4)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", Kit.pill(PAPER, 22, 0.2, Vector2(16, 12)))
	card.position = Vector2(14, 640)
	card.size = Vector2(332, 0)
	add_child(card)
	card_box = VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 5)
	card_box.custom_minimum_size = Vector2(300, 0)
	card.add_child(card_box)
	if jobs_btn:
		jobs_btn.visible = false
	return card_box


func _close_btn() -> Button:
	var close := Button.new()
	close.text = tr("SHOP_CLOSE")
	close.flat = true
	close.add_theme_font_override("font", Kit.bold())
	close.add_theme_font_size_override("font_size", 12)
	close.add_theme_color_override("font_color", SUB)
	close.pressed.connect(close_card)
	return close


## 目印のカード：「働いた人の声：時間どおりに帰れる ×23」
func open_mark(mk: Dictionary) -> void:
	var lm: Dictionary = mk.data
	_new_card()
	var row := HBoxContainer.new()
	var lv := int(lm.level)
	var chip_t := tr("SHOP_SPROUT") if lv == 0 else tr("SHOP_LEVEL") % [lv, ShopCulture.LEVELS.size()]
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", Kit.pill(Color("fff1d6") if lv > 0 else Color("e9f3ea"), 10, 0.0, Vector2(8, 2)))
	chip.add_child(Kit.text(chip_t, 11, Color("b07a1a") if lv > 0 else GREEN, true))
	row.add_child(chip)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	row.add_child(_close_btn())
	card_box.add_child(row)
	card_box.add_child(I18n.wrap(Kit.text(tr("SHOP_LM_" + String(lm.id).to_upper()), 19, INK, true)))
	var said := PanelContainer.new()
	said.add_theme_stylebox_override("panel", Kit.pill(Color("f1f7f1"), 12, 0.0, Vector2(10, 5)))
	said.add_child(I18n.wrap(Kit.text(tr("SHOP_WORKERS_SAID") % [tr("REVIEW_TAG_" + String(lm.tag).to_upper()), int(lm.votes)], 14, GREEN, true)))
	card_box.add_child(said)
	card_box.add_child(I18n.wrap(Kit.text(tr("SHOP_LM_" + String(lm.id).to_upper() + "_BODY") if lv > 0 else tr("SHOP_SPROUT_BODY"), 13, SUB)))
	_show_card()


## カードの高さが決まってから、下からすべり出す
func _show_card() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(card):
		return
	card.size.y = 0
	await get_tree().process_frame
	if not is_instance_valid(card):
		return
	var y := 584.0 - card.size.y
	create_tween().tween_property(card, "position:y", y, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close_card() -> void:
	if card and is_instance_valid(card):
		card.queue_free()
	card = null
	if jobs_btn:
		jobs_btn.visible = true


func go_home() -> void:
	GameState.visit = {}
	if main and not main.busy:
		main.go("garden")


# ---------------------------------------------------------------- 確認用（OBAKE_SHOT の call:）

## いちばん育った目印（カードに隠れない、島の奥のもの）のカードを開く
func demo_tap() -> void:
	var best = null
	for mk in marks:
		if mk.anchor.z > 0.5:
			continue
		if best == null or int(mk.data.level) > int(best.data.level) or (int(mk.data.level) == int(best.data.level) and int(mk.data.votes) > int(best.data.votes)):
			best = mk
	if best != null:
		open_mark(best)
		cat.position = best.anchor * Vector3(1, 0, 1) + Vector3(0.95, 0, 0.9)
		cat_target = cat.position


func demo_jobs() -> void:
	open_jobs_card()


func demo_walk() -> void:
	cat.position = Vector3(0.6, 0, 1.6)
	cat_target = cat.position
