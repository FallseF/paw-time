class_name ChatStage
extends SubViewportContainer
## The cats at the top of a chat. "me": your cat's face, close up. "duo": your cat (left) and the shop's cat (right)
## facing each other. mood() gives a cat an expression: eyes (squint, wide, sleepy), a tilt or hop, and a small mark.

const EYES := {"happy": Vector2(1.0, 0.42), "love": Vector2(1.0, 0.42), "proud": Vector2(1.05, 0.6), "calm": Vector2(1.0, 1.0),
	"worried": Vector2(0.9, 0.8), "surprised": Vector2(1.2, 1.3), "sleepy": Vector2(1.05, 0.22)}
const MARK := {"happy": "♪", "love": "♡", "proud": "★", "worried": "…", "surprised": "!", "sleepy": "z", "calm": ""}

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var mine: Obake3D
var shop: Obake3D
var _moods := {}
var _marks := {}
var sparkle: CPUParticles3D


func _init(mode := "me", shop_id := "", px := Vector2(360, 150)) -> void:
	stretch = true
	custom_minimum_size = px
	size = px
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_priority = 100 # after the cats' own _process (their blink), so our eye shapes win
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	Look.apply(world, "studio", Color(0, 0, 0, 0), true)
	cam = Camera3D.new()
	cam.fov = 30
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	world.add_child(cam)
	mine = MyObake3D.from_saved()
	if mine == null:
		mine = MyObake3D.new().setup_look(QuizData.TYPES["IFHY"].look)
	world.add_child(mine)
	var eye := Vector3(0, 0.8, 2.3)
	var at := Vector3(0, 0.66, 0)
	if mode == "duo":
		shop = Obake3D.make_custom(ChatShops.cat_look(shop_id))
		world.add_child(shop)
		mine.position = Vector3(-0.72, 0, 0)
		mine.rotation.y = 0.55
		shop.position = Vector3(0.72, 0, 0)
		shop.rotation.y = -0.55
		eye = Vector3(0, 0.9, 3.6)
		at = Vector3(0, 0.55, 0)
	else:
		mine.rotation.y = 0.12
	cam.transform = Transform3D(Basis.looking_at(at - eye), eye)
	for ob in [mine, shop]:
		if ob == null:
			continue
		var l := Kit.label3d("", 64, Color("ffe27a"))
		l.pixel_size = 0.004
		l.position = Vector3(0.42, 1.12, 0)
		ob.add_child(l)
		_marks[ob] = l
		_moods[ob] = "calm"
	sparkle = CPUParticles3D.new()
	sparkle.emitting = false
	sparkle.one_shot = true
	sparkle.amount = 24
	sparkle.lifetime = 0.9
	sparkle.explosiveness = 1.0
	sparkle.spread = 180
	sparkle.initial_velocity_min = 0.8
	sparkle.initial_velocity_max = 1.8
	sparkle.gravity = Vector3(0, -2.0, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.025
	sm.height = 0.05
	sparkle.mesh = sm
	sparkle.material_override = Kit.glow(Color("ffe27a"), 2.5)
	world.add_child(sparkle)


## who = "me" or "shop"
func mood(who: String, m: String) -> void:
	var ob: Obake3D = shop if who == "shop" and shop else mine
	if not EYES.has(m):
		m = "calm"
	_moods[ob] = m
	var mark: Label3D = _marks[ob]
	mark.text = MARK[m]
	mark.modulate = Color("ff8fb1") if m == "love" else (Color("b9c7ff") if m in ["sleepy", "worried"] else Color("ffe27a"))
	var tw := create_tween()
	match m:
		"happy", "love", "proud":
			sparkle.position = ob.position + Vector3(0, 0.7, 0)
			sparkle.restart()
			sparkle.emitting = true
			tw.tween_property(ob, "rotation:z", 0.0, 0.1)
			tw.tween_property(ob, "position:y", 0.22, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(ob, "position:y", 0.0, 0.26).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"surprised":
			tw.tween_property(ob, "position:y", 0.14, 0.08)
			tw.tween_property(ob, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"worried":
			tw.tween_property(ob, "rotation:z", 0.16 if ob == mine else -0.16, 0.3).set_trans(Tween.TRANS_SINE)
		"sleepy":
			tw.tween_property(ob, "rotation:z", 0.1, 0.5).set_trans(Tween.TRANS_SINE)
		_:
			tw.tween_property(ob, "rotation:z", 0.0, 0.25).set_trans(Tween.TRANS_SINE)
			tw.tween_property(ob, "scale", Vector3(0.96, 1.05, 0.96), 0.1)
			tw.tween_property(ob, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A small nod while talking
func talk(who := "me") -> void:
	var ob: Obake3D = shop if who == "shop" and shop else mine
	var tw := create_tween()
	tw.tween_property(ob, "scale", Vector3(0.95, 1.06, 0.95), 0.1)
	tw.tween_property(ob, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(_delta: float) -> void:
	# The cats blink by setting eye scale.y each frame; we shape the eyes on top of that
	for ob in _moods:
		var k: Vector2 = EYES[_moods[ob]]
		for e in ob.eyes:
			e.scale.x = Obake3D.EYE_SCALE.x * k.x
			e.scale.y = minf(e.scale.y, Obake3D.EYE_SCALE.y) * k.y
