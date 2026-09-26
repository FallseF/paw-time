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
	# 中身のヒント：材料・服なら、眠る子猫の影の代わりに小さな影
	var c: Dictionary = d.get("content", {})
	# おばネコの玉（中身の決まった玉だけ。夢の泡・夜の玉は別の見た目）は、強く・ちがう色で光る
	cat = c.get("kind", "") == "obake" and not d.type in ["sleep", "night"]
	if cat:
		model.mark_cat()
	if c.get("kind", "obake") != "obake" and model.sleeper:
		model.sleeper.visible = false
		var ic := Drops.make_icon(c, true)
		ic.scale = Vector3.ONE * 0.2
		ic.position = model.sleeper.position
		model.add_child(ic)
	_t = randf() * TAU
	vel = Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3))
	return self


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
