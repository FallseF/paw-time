class_name Orb3D
extends Node3D
## 水面をただよう光る玉。中身のおばけは朝まで分からない。色で仕事の種類、虹色の揺らぎでレアが分かる。

var data: Dictionary
var vel := Vector3.ZERO
var core: MeshInstance3D
var halo: MeshInstance3D
var light: OmniLight3D
var core_mat: StandardMaterial3D
var halo_mat: StandardMaterial3D
var _t := 0.0
var caught := false


func setup(d: Dictionary) -> Orb3D:
	data = d
	var col: Color = GameState.TYPE_COLOR.get(d.type, Color.WHITE)
	core = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.1
	s.height = 0.2
	core.mesh = s
	core_mat = StandardMaterial3D.new()
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_mat.albedo_color = col.lightened(0.4)
	core_mat.emission_enabled = true
	core_mat.emission = col
	core_mat.emission_energy_multiplier = 3.0
	core.material_override = core_mat
	add_child(core)

	halo = MeshInstance3D.new()
	var h := SphereMesh.new()
	h.radius = 0.26
	h.height = 0.52
	halo.mesh = h
	halo_mat = StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	halo_mat.albedo_color = Color(col.r, col.g, col.b, 0.25)
	halo.material_override = halo_mat
	add_child(halo)

	light = OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.2
	light.omni_range = 1.1
	light.position = Vector3(0, 0.15, 0)
	add_child(light)
	_t = randf() * TAU
	vel = Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	return self


func _process(delta: float) -> void:
	_t += delta
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	if data.rare:
		var c := Color.from_hsv(fmod(_t * 0.25, 1.0), 0.45, 1.0)
		core_mat.emission = c
		halo_mat.albedo_color = Color(c.r, c.g, c.b, 0.3)
		light.light_color = c
	core_mat.emission_energy_multiplier = 2.4 + pulse * 1.6
	halo.scale = Vector3.ONE * (0.9 + pulse * 0.25)
	if caught:
		return
	core.position.y = 0.06 + sin(_t * 1.7) * 0.03
	halo.position.y = core.position.y
