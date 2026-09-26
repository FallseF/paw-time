class_name Orb3D
extends Node3D
## 水面をただよう光る玉。中身のおばけは朝まで分からない。
## 色で仕事の種類、性格（kind）で動きが違う：
##   normal 素直 / school 群れ（小さい） / shy 人見知り（速いポイから逃げる） / jumper 跳ねる / heavy 重い
##   rainbow 虹（少しのあいだだけ浮かぶ） / gold 祭りの金の玉

const KIND_SIZE := {"normal": 1.0, "school": 0.62, "shy": 0.9, "jumper": 0.95, "heavy": 1.35, "rainbow": 1.1, "gold": 1.15}
const KIND_WEIGHT := {"normal": 0.4, "school": 0.17, "shy": 0.34, "jumper": 0.36, "heavy": 0.7, "rainbow": 0.45, "gold": 0.4}
const KIND_SPEED := {"normal": 0.32, "school": 0.4, "shy": 0.3, "jumper": 0.36, "heavy": 0.16, "rainbow": 0.5, "gold": 0.4}

var data: Dictionary
var kind := "normal"
var vel := Vector3.ZERO
var core: MeshInstance3D
var halo: MeshInstance3D
var light: OmniLight3D
var core_mat: StandardMaterial3D
var halo_mat: StandardMaterial3D
var _t := 0.0
var caught := false
var leader: Orb3D # 群れの先頭
var offset := Vector3.ZERO
var air := 0.0 # 跳ねている残り時間（> 0 のあいだはすくえない）
var hop_timer := 0.0
var life := -1.0 # 虹の玉：残り時間
var alarmed := 0.0 # 人見知りが驚いている時間
var sinking := false
var highlight := false # ポイの上に乗っている


func setup(d: Dictionary) -> Orb3D:
	data = d
	kind = d.get("kind", "normal")
	var col: Color = GameState.TYPE_COLOR.get(d.type, Color.WHITE)
	if kind == "gold":
		col = GameState.TYPE_COLOR.gold
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
	halo_mat.albedo_color = Color(col.r, col.g, col.b, 0.14)
	halo.material_override = halo_mat
	add_child(halo)

	# 重い玉は、殻の輪がついている
	if kind == "heavy":
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.11
		tm.outer_radius = 0.14
		ring.mesh = tm
		ring.rotation.x = 0.5
		ring.material_override = Obake3D.toon(col.darkened(0.35), 0.2)
		core.add_child(ring)

	light = OmniLight3D.new()
	light.light_color = col
	light.light_energy = 0.8
	light.omni_range = 1.0
	light.position = Vector3(0, 0.15, 0)
	add_child(light)
	scale = Vector3.ONE * KIND_SIZE.get(kind, 1.0)
	_t = randf() * TAU
	hop_timer = randf_range(2.5, 5.0)
	vel = Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	return self


func weight() -> float:
	return KIND_WEIGHT.get(kind, 0.28)


func max_speed() -> float:
	return KIND_SPEED.get(kind, 0.3)


func catchable() -> bool:
	return not caught and air <= 0.0 and not sinking


func _process(delta: float) -> void:
	_t += delta
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	if kind == "rainbow":
		var c := Color.from_hsv(fmod(_t * 0.35, 1.0), 0.5, 1.0)
		core_mat.emission = c
		halo_mat.albedo_color = Color(c.r, c.g, c.b, 0.2)
		light.light_color = c
	elif kind == "gold":
		pulse = 0.5 + 0.5 * sin(_t * 6.0)
	if alarmed > 0.0:
		alarmed -= delta
		pulse = 1.0
	core_mat.emission_energy_multiplier = (1.0 + pulse * 0.6) if caught else (1.5 + pulse * 0.9)
	halo.scale = Vector3.ONE * (0.9 + pulse * 0.25)
	if highlight and not caught:
		core_mat.emission_energy_multiplier = 3.2
		halo.scale = Vector3.ONE * (1.25 + 0.1 * sin(_t * 12.0))
	if caught:
		return
	core.position.y = 0.06 + sin(_t * 1.7) * 0.03
	# 跳ねる玉は、跳ぶ前にぐっと縮む（見ていれば読める）
	if kind == "jumper" and air <= 0.0 and hop_timer < 0.45:
		core.scale = Vector3(1.25, 0.65, 1.25)
	else:
		core.scale = Vector3.ONE
	# 人見知りは、驚くと震える
	core.position.x = sin(_t * 60.0) * 0.025 if alarmed > 0.0 else 0.0
	halo.position.y = core.position.y
