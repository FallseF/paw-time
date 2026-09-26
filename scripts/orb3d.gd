class_name Orb3D
extends Node3D
## 水面をただよう光る玉。中身のおばけは朝まで分からない。
## 色で仕事の種類、性格（kind）で動きが違う：
##   normal 素直 / school 群れ（小さい） / shy 人見知り（速いポイから逃げる） / jumper 跳ねる / heavy 重い
##   rainbow 虹（少しのあいだだけ浮かぶ） / gold 祭りの金の玉

const KIND_SIZE := {"normal": 1.0, "school": 0.72, "shy": 0.9, "jumper": 0.95, "heavy": 1.35, "rainbow": 1.1, "gold": 1.15}
const KIND_WEIGHT := {"normal": 0.4, "school": 0.17, "shy": 0.34, "jumper": 0.36, "heavy": 0.7, "rainbow": 0.45, "gold": 0.4}
const KIND_SPEED := {"normal": 0.32, "school": 0.4, "shy": 0.3, "jumper": 0.36, "heavy": 0.16, "rainbow": 0.5, "gold": 0.4}

var data: Dictionary
var kind := "normal"
var vel := Vector3.ZERO
var model: OrbModel
var core: Node3D
var light: OmniLight3D
var dim_energy := -1.0
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
	# 見た目は OrbModel（ガラスの殻・渦を巻く光・中で眠る子猫の影）
	model = OrbModel.new().setup(col, kind == "rainbow", 0.15)
	model.position = Vector3(0, 0.1, 0)
	add_child(model)
	core = model
	light = model.light
	# 水面の映り込みはシェーダーが描くので、明かりは特別な玉だけ（Webで軽く）
	light.visible = kind in ["rainbow", "gold"]

	# 重い玉は、殻に輪がかかっている
	if kind == "heavy":
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.155
		tm.outer_radius = 0.185
		ring.mesh = tm
		ring.rotation.x = 0.5
		ring.material_override = Obake3D.toon(col.darkened(0.35), 0.2)
		model.add_child(ring)
	scale = Vector3.ONE * KIND_SIZE.get(kind, 1.0)
	_t = randf() * TAU
	hop_timer = randf_range(2.5, 5.0)
	vel = Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	return self


## 朝の部屋で並べるときなど、光を落ち着かせる
func dim(e := 0.8) -> void:
	dim_energy = e


func weight() -> float:
	return KIND_WEIGHT.get(kind, 0.28)


func max_speed() -> float:
	return KIND_SPEED.get(kind, 0.3)


func catchable() -> bool:
	return not caught and air <= 0.0 and not sinking


func _process(delta: float) -> void:
	_t += delta
	var pulse := 0.5 + 0.5 * sin(_t * 2.4)
	if kind == "gold":
		pulse = 0.5 + 0.5 * sin(_t * 6.0)
	if alarmed > 0.0:
		alarmed -= delta
		pulse = 1.0
	var e := (1.3 + pulse * 0.5) if caught else (1.9 + pulse * 0.7)
	if highlight and not caught:
		e = 3.4 + 0.4 * sin(_t * 12.0) # ポイに乗っている
	if dim_energy >= 0.0:
		e = dim_energy + pulse * 0.3
	model.set_energy(e)
	if not light.visible:
		light.light_energy = 0.0
	if caught:
		return
	# 水面にぷかぷか浮いて、少し傾く
	model.position.y = 0.1 + sin(_t * 1.7) * 0.025
	model.rotation.z = sin(_t * 1.1) * 0.12
	# 跳ねる玉は、跳ぶ前にぐっと縮む（見ていれば読める）
	if kind == "jumper" and air <= 0.0 and hop_timer < 0.45:
		model.scale = Vector3(1.25, 0.65, 1.25)
	else:
		model.scale = Vector3.ONE
	# 人見知りは、驚くと震える
	model.position.x = sin(_t * 60.0) * 0.025 if alarmed > 0.0 else 0.0
