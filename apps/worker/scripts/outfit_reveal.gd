class_name OutfitReveal
extends Control
## 「新しい服！」の演出。光る玉が割れて、服を着たおばけがくるっと回って出てくる。
##   OutfitReveal.open(parent, item_id, who)  … parent（画面）の上にかぶせる。閉じると自分で消える。
## 「着てみる」を押すと、その子にその服を着せて保存する（持っている服だけ）。

signal closed

var item_id := ""
var who := "my"
var vp: SubViewport
var world: Node3D
var ob: Obake3D
var orb: Node3D
var _t := 0.0
var card: PanelContainer


static func open(parent: Node, id: String, who_id := "my") -> OutfitReveal:
	var r := OutfitReveal.new()
	r.item_id = id
	r.who = who_id
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.size = Vector2(360, 640)
	parent.add_child(r)
	return r


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var it := WardrobeData.item(item_id)
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.09, 0.2, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	Kit.center_tall(self, dim) # 縦に長い島では、上下のまんなかに（暗幕は画面いっぱい）
	var box := SubViewportContainer.new()
	box.stretch = true
	box.position = Vector2(30, 90)
	box.size = Vector2(300, 300)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	View3D.fit(box, vp)
	world = Node3D.new()
	vp.add_child(world)
	Look.apply(world, "studio", Color(0, 0, 0, 0), true)
	var cam := Camera3D.new()
	cam.fov = 32
	world.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.3, 4.0), Vector3(0, 0.7, 0))
	# 玉（割れる前）
	orb = Node3D.new()
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.55
	s.height = 1.1
	m.mesh = s
	m.material_override = Kit.glow(Color("fff2a8"), 2.2)
	orb.add_child(m)
	orb.position = Vector3(0, 0.75, 0)
	world.add_child(orb)
	var title := Kit.text(tr("New outfit!"), 28, Color("ffe27a"), true, HORIZONTAL_ALIGNMENT_CENTER)
	title.position = Vector2(0, 40)
	title.size = Vector2(360, 44)
	add_child(title)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", Kit.pill(Color("fff8ef"), 24, 0.2, Vector2(18, 14)))
	card.position = Vector2(30, 400)
	card.size = Vector2(300, 0)
	card.modulate.a = 0.0
	add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	v.add_child(Kit.text(tr(it.get("name", "")), 22, Color("2a2233"), true, HORIZONTAL_ALIGNMENT_CENTER))
	var how := WardrobeData.how_to_get(it)
	if WardrobeData.kind(it) == "orb":
		how = tr("Found inside a glowing orb")
	v.add_child(Kit.text(how, 12, Color("8a7a88"), false, HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var later := Kit.button(tr("Later"), Color("e6ddd2"), _close, Color("4a3f52"), 44, 14)
	later.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(later)
	var wear := Kit.button(tr("Wear it"), Color("ff8a5b"), _wear, Color.WHITE, 44, 15)
	wear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(wear)
	_play()


func _play() -> void:
	Sfx.hatch_build(self, 0.72)
	var tw := create_tween()
	for i in 3:
		tw.tween_property(orb, "scale", Vector3.ONE * (1.0 + 0.08 * (i + 1)), 0.12)
		tw.tween_property(orb, "scale", Vector3.ONE, 0.12)
	await tw.finished
	Sfx.hatch_release(self)
	orb.queue_free()
	var o := Wardrobe.outfit_of(who).duplicate()
	o[WardrobeData.item(item_id).slot] = item_id
	ob = Outfit.make(who, o)
	ob.scale = Vector3.ONE * 0.05
	world.add_child(ob)
	var tw2 := create_tween().set_parallel()
	tw2.tween_property(ob, "scale", Vector3.ONE * (1.0 if not Rares.is_rare(who) else 0.85), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw2.tween_property(card, "modulate:a", 1.0, 0.3).set_delay(0.3)
	Sfx.reveal(self)


func _process(delta: float) -> void:
	_t += delta
	if ob and is_instance_valid(ob):
		ob.rotation.y = _t * 1.4


func _wear() -> void:
	var o := Wardrobe.outfit_of(who).duplicate()
	o[WardrobeData.item(item_id).slot] = item_id
	Wardrobe.set_outfit(who, o)
	Wardrobe.fresh.erase(item_id)
	Wardrobe.save()
	Sfx.equip(self)
	_close()


func _close() -> void:
	closed.emit()
	queue_free()
