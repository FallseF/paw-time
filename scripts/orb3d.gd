class_name Orb3D
extends Node3D
## 水面をただよう光る玉。中身のおばけは朝まで分からない。色で仕事の種類、虹色の揺らぎでレアが分かる。
## 見た目は OrbModel（ガラスの殻・渦を巻く光・中で眠る子猫の影）。

var data: Dictionary
var vel := Vector3.ZERO
var model: OrbModel
var light: OmniLight3D
var halo_mat: StandardMaterial3D # 互換用（旧画面が透明度を触る）。見た目には使わない
var _t := 0.0
var caught := false
var hop := 0.0 # すくい画面の「はねる玉」用
## 画面ごとの明るさの倍率。light_energy を直接いじっても毎フレーム _process が上書きするので、こちらで絞る。
## energy_scale は玉の中の光（輝き・グロー）、light_scale は玉がまわりを照らす光。
var energy_scale := 1.0
var light_scale := 1.0
var cat := false # 中身がおばネコ（強く光る）


func setup(d: Dictionary) -> Orb3D:
	data = d
	var col: Color = GameState.TYPE_COLOR.get(d.type, Color.WHITE)
	model = OrbModel.new().setup(col, d.get("rare", false))
	model.position = Vector3(0, 0.12, 0)
	add_child(model)
	light = model.light
	halo_mat = StandardMaterial3D.new()
	# 中身（すくう前から決まっている）を、玉の中に小さく本物の形で見せる。
	# おばネコは、孵る子の色（仕事の種類で決まる子。虹の玉はまだ分からないのでクリーム色）
	var c: Dictionary = d.get("content", {})
	model.set_contents(c if not c.is_empty() else {"kind": "obake"}, _cat_color(d.type))
	# おばネコの玉（中身の決まった玉だけ。夢の泡・夜の玉は別の見た目）は、金の縁と粒で光る
	cat = c.get("kind", "") == "obake" and not d.type in ["sleep", "night"]
	if cat:
		model.mark_cat()
	_t = randf() * TAU
	vel = Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	return self


static func _cat_color(t: String) -> Color:
	var gs = Engine.get_main_loop().root.get_node_or_null("GameState") if Engine.get_main_loop() else null
	if gs and t != "rare" and gs.TYPE_SPECIES.has(t):
		return Obake3D.COLORS.get(gs.species_for_type(t), Color("fff1c8"))
	return Color("fff1c8")


func _process(delta: float) -> void:
	_t += delta
	var pulse := 0.5 + 0.5 * sin(_t * 2.4)
	var boost := 1.4 if cat else 1.0
	model.set_energy(((1.3 + pulse * 0.5) if caught else (2.4 + pulse * 0.9)) * energy_scale * boost, light_scale * boost)
	if caught:
		return
	# 水面にぷかぷか浮いて、少し傾く
	model.position.y = 0.12 + sin(_t * 1.7) * 0.025 + hop
	model.rotation.z = sin(_t * 1.1) * 0.12
	model.rotation.x = cos(_t * 0.9) * 0.1
