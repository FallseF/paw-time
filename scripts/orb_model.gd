class_name OrbModel
extends Node3D
## 光る玉の見た目（作り込み版）。ガラスの殻の中で光が渦を巻き、丸まって眠る子猫おばけの影が透ける。
## color: 仕事の色。rare: 虹色に流れ、星が多い。radius: 殻の半径（既定 0.17）。

var radius := 0.17
var light: OmniLight3D
var shell: MeshInstance3D
var core: MeshInstance3D
var core_mat: ShaderMaterial
var shell_mat: ShaderMaterial
var sleeper: Node3D
var sparkles: CPUParticles3D
var _t := 0.0
var rare := false


func setup(color: Color, is_rare := false, r := 0.17) -> OrbModel:
	radius = r
	rare = is_rare
	_t = randf() * TAU

	# 中の光
	core = MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = r * 0.86
	cm.height = r * 1.72
	cm.radial_segments = 32
	cm.rings = 16
	core.mesh = cm
	core_mat = ShaderMaterial.new()
	core_mat.shader = load("res://shaders/orb_core.gdshader")
	core_mat.set_shader_parameter("glow", color)
	core_mat.set_shader_parameter("rare", 1.0 if is_rare else 0.0)
	core_mat.set_shader_parameter("seed", randf() * 10.0)
	core.material_override = core_mat
	add_child(core)

	# 丸まって眠る子猫おばけの影
	sleeper = Node3D.new()
	var sil := StandardMaterial3D.new()
	sil.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sil.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sil.albedo_color = Color(color.darkened(0.55), 0.55)
	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = r * 0.36
	bm.height = r * 0.6
	body.mesh = bm
	body.material_override = sil
	sleeper.add_child(body)
	for sx in [-1.0, 1.0]:
		var ear := MeshInstance3D.new()
		var em := CylinderMesh.new()
		em.top_radius = 0.0
		em.bottom_radius = r * 0.11
		em.height = r * 0.2
		ear.mesh = em
		ear.material_override = sil
		ear.position = Vector3(sx * r * 0.17, r * 0.26, r * 0.05)
		ear.rotation.z = -sx * 0.4
		sleeper.add_child(ear)
	var tail := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 0.3
	tm.outer_radius = r * 0.38
	tail.mesh = tm
	tail.material_override = sil
	tail.position = Vector3(0, -r * 0.12, 0)
	tail.scale = Vector3(1.0, 0.5, 1.0)
	sleeper.add_child(tail)
	sleeper.position = Vector3(0, -r * 0.1, 0)
	add_child(sleeper)

	# ガラスの殻
	shell = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 40
	sm.rings = 20
	shell.mesh = sm
	shell_mat = ShaderMaterial.new()
	shell_mat.shader = load("res://shaders/orb_glass.gdshader")
	shell_mat.set_shader_parameter("tint", color.lightened(0.35))
	shell.material_override = shell_mat
	shell.sorting_offset = 1.0
	add_child(shell)

	# 小さなきらめき
	sparkles = CPUParticles3D.new()
	sparkles.amount = 14 if is_rare else 6
	sparkles.lifetime = 1.6
	sparkles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparkles.emission_sphere_radius = r * 1.3
	sparkles.gravity = Vector3(0, 0.05, 0)
	sparkles.initial_velocity_min = 0.0
	sparkles.initial_velocity_max = 0.05
	sparkles.scale_amount_min = 0.5
	sparkles.scale_amount_max = 1.0
	var qm := SphereMesh.new()
	qm.radius = r * 0.05
	qm.height = r * 0.1
	sparkles.mesh = qm
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = Color(1, 1, 1)
	pm.emission_enabled = true
	pm.emission = color.lightened(0.5)
	pm.emission_energy_multiplier = 3.0
	sparkles.material_override = pm
	add_child(sparkles)

	light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.1
	light.omni_range = r * 7.0
	add_child(light)
	return self


## おばネコの入った玉（いまはレア）：子猫の影をはっきり、金色の輪ときらめきを足す
var cat_ring: MeshInstance3D


func mark_cat() -> void:
	for m in sleeper.get_children():
		var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
		mat.albedo_color = Color(mat.albedo_color, 0.9)
	sleeper.scale = Vector3.ONE * 1.2
	var gold := Color("ffe27a")
	cat_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius * 1.18
	tm.outer_radius = radius * 1.32
	tm.rings = 32
	cat_ring.mesh = tm
	cat_ring.material_override = Kit.glow(gold, 2.4)
	cat_ring.rotation.x = 0.25
	add_child(cat_ring)
	sparkles.amount = 20
	(sparkles.material_override as StandardMaterial3D).emission = gold
	light.omni_range = radius * 9.0


## e は玉の中の光の強さ。light_k はまわりを照らす光の倍率（1 で今までどおり）。
func set_energy(e: float, light_k := 1.0) -> void:
	core_mat.set_shader_parameter("energy", e)
	light.light_energy = e * 0.7 * light_k


func _process(delta: float) -> void:
	_t += delta
	# 中の子猫はゆっくり寝息を立てて、殻はわずかに回る
	sleeper.scale = Vector3.ONE * (1.0 + sin(_t * 1.8) * 0.05)
	sleeper.rotation.y = sin(_t * 0.4) * 0.6
	shell.rotation.y += delta * 0.3
	if cat_ring:
		cat_ring.rotation.y += delta * 1.2
		cat_ring.scale = Vector3.ONE * (1.0 + sin(_t * 3.0) * 0.06)
	if rare:
		light.light_color = Color.from_hsv(fmod(_t * 0.2, 1.0), 0.5, 1.0)
