class_name RareObake3D
extends Obake3D
## レアおばけ。にゃんこ大戦争のノリの平たい絵を、3D 空間に紙人形のように立てて出す。
## 絵は assets/gen/rares/<id>.png。まだ無ければ、ふつうの 3D おばけの形を色違いで出す。

const ART_DIRS := ["res://assets/gen/rares/%s.png", "res://assets/gen/style2/%s.png"]

var sprite: Sprite3D
var _hop := 0.0


static func art_path(id: String) -> String:
	for d in ART_DIRS:
		var p: String = d % id
		if ResourceLoader.exists(p):
			return p
	return ""


func setup(id: String) -> Obake3D:
	var path := art_path(id)
	if path == "":
		return super.setup(id)
	species = id
	body = Node3D.new()
	add_child(body)
	sprite = Sprite3D.new()
	sprite.texture = load(path)
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.shaded = false
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# 高さ約 1.6（ふつうのおばけより大きい）。足元を y=0 にそろえる
	sprite.pixel_size = 1.6 / float(sprite.texture.get_height())
	sprite.offset = Vector2(0, sprite.texture.get_height() * 0.5)
	body.add_child(sprite)
	# 足元の影
	var shadow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.45
	disc.bottom_radius = 0.45
	disc.height = 0.005
	shadow.mesh = disc
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_color = Color(0, 0, 0, 0.22)
	shadow.mesh.surface_set_material(0, sm)
	shadow.position = Vector3(0, 0.01, 0)
	add_child(shadow)
	_t = randf() * TAU
	return self


func set_level(lv: int) -> void:
	if sprite == null:
		super.set_level(lv)


func _process(delta: float) -> void:
	if sprite == null:
		super._process(delta)
		return
	_t += delta
	if bob:
		# 真顔のまま、ぴょこぴょこ跳ねる（にゃんこ大戦争の歩き方）
		_hop = absf(sin(_t * 3.2))
		body.position.y = _hop * 0.08
		body.scale = Vector3(1.0 + (1.0 - _hop) * 0.04, 1.0 - (1.0 - _hop) * 0.04, 1.0)
		body.rotation.z = sin(_t * 1.6) * 0.04
