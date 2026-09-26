class_name PartnerStage
extends SubViewportContainer
## 相棒（マイおばけ猫）だけを映す小さな舞台。仕事の知らせ・求人カード・条件の入力で使う。
## joy()＝受けたとき（跳ねて、くるっと回って、きらきら）、shrug()＝見送ったとき（首をかしげて、肩をすくめる）。

var vp: SubViewport
var world: Node3D
var cam: Camera3D
var ob: MyObake3D
var sparkle: CPUParticles3D
var home := Vector3.ZERO


func _init(px := Vector2(200, 180), bg := Color(0, 0, 0, 0)) -> void:
	stretch = true
	custom_minimum_size = px
	size = px
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = bg.a < 0.01
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR if bg.a < 0.01 else Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("fff2e6")
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 30, 0)
	sun.light_color = Color("fff0dc")
	sun.light_energy = 0.8
	world.add_child(sun)
	cam = Camera3D.new()
	cam.fov = 30
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	# まだツリーの外なので look_at は使えない。向きを直接つくる
	var eye := Vector3(0, 0.8, 3.6)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.62, 0) - eye), eye)
	world.add_child(cam)
	ob = MyObake3D.from_saved()
	if ob == null:
		ob = MyObake3D.new().setup_look(QuizData.TYPES["IFHY"].look)
	ob.rotation.y = 0.25
	world.add_child(ob)
	sparkle = CPUParticles3D.new()
	sparkle.emitting = false
	sparkle.one_shot = true
	sparkle.amount = 36
	sparkle.lifetime = 1.0
	sparkle.explosiveness = 1.0
	sparkle.spread = 180
	sparkle.initial_velocity_min = 1.0
	sparkle.initial_velocity_max = 2.2
	sparkle.gravity = Vector3(0, -2.0, 0)
	var sm := SphereMesh.new()
	sm.radius = 0.03
	sm.height = 0.06
	sparkle.mesh = sm
	sparkle.material_override = Kit.glow(Color("ffe27a"), 2.5)
	sparkle.position = Vector3(0, 0.7, 0)
	world.add_child(sparkle)


## うれしい！（跳ねて、くるっと回って、きらきら）
func joy() -> void:
	sparkle.restart()
	sparkle.emitting = true
	var tw := create_tween()
	tw.tween_property(ob, "position:y", 0.45, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ob, "rotation:y", ob.rotation.y + TAU, 0.42).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ob, "position:y", 0.0, 0.24).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_property(ob, "position:y", 0.18, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ob, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


## まあいいか（首をかしげて、肩をすくめる。罰はない）
func shrug() -> void:
	var tw := create_tween()
	tw.tween_property(ob, "rotation:z", 0.28, 0.16).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(ob, "scale", Vector3(1.06, 0.92, 1.06), 0.16)
	tw.tween_property(ob, "rotation:z", -0.2, 0.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ob, "rotation:z", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(ob, "scale", Vector3.ONE, 0.2)


## ひとことしゃべる（小さくうなずく）
func talk() -> void:
	var tw := create_tween()
	tw.tween_property(ob, "scale", Vector3(0.95, 1.06, 0.95), 0.1)
	tw.tween_property(ob, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
