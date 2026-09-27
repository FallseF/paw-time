class_name View3D
extends TextureRect
## 3D の SubViewport を、画面の実際の解像度で描く（見た目の大きさは今のまま）。
## SubViewportContainer.stretch だけだと、3D は基準の 360x640 で描かれて、スマホでは約3倍に引き伸ばされる。
##   box.add_child(vp)
##   View3D.fit(box, vp)
## SubViewportContainer は SubViewport の大きさを自分の大きさに固定する（stretch を切ると、今度は自分が SubViewport の
## 大きさまで広がる）ので、SubViewport をこの TextureRect の子に移し、ここでコンテナいっぱいに描く。
## コンテナは置き場所と入力（キセカエの回転台）のためにそのまま残る。
## 倍率は「画面の実際の拡大率」と「上限」（CAP、Web は CAP_WEB）の小さい方。ウィンドウの大きさが変わったら追従する。
## SubViewport のピクセルは画面の座標と倍率ぶんずれるので、カメラの写しは次を通す：
##   View3D.unproject(cam, p3)   … 3D の位置 → 画面（コンテナ）の座標
##   View3D.to_vp(cam, pos)      … 画面の座標 → SubViewport のピクセル（project_ray_* / project_position に渡す）

const CAP := 2.0
const CAP_WEB := 2.0

var vp: SubViewport


static func fit(box: SubViewportContainer, sub: SubViewport) -> void:
	var v := View3D.new()
	v.vp = sub
	v.texture = sub.get_texture()
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR # 倍率が画面の拡大率と割り切れないときに、ドットのむらが出ないように
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.remove_child(sub)
	v.add_child(sub)
	box.add_child(v, false, Node.INTERNAL_MODE_FRONT)


static func to_vp(cam: Camera3D, pos: Vector2) -> Vector2:
	return pos * _ratio(cam)


static func unproject(cam: Camera3D, p: Vector3) -> Vector2:
	return cam.unproject_position(p) / _ratio(cam)


## SubViewport のピクセル ÷ 画面の上の大きさ（View3D を通していなければ 1）
static func _ratio(cam: Camera3D) -> Vector2:
	var sub := cam.get_viewport()
	var v := sub.get_parent() as View3D
	if v == null or v.size.x <= 0.0 or v.size.y <= 0.0:
		return Vector2.ONE
	return Vector2(sub.size) / v.size


func _ready() -> void:
	resized.connect(_refit)
	get_viewport().size_changed.connect(_refit)
	_refit()


func _refit() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var cap := CAP_WEB if OS.has_feature("web") else CAP
	var s := clampf(get_viewport().get_final_transform().get_scale().x, 1.0, cap)
	var want := Vector2i((size * s).floor()).max(Vector2i.ONE)
	if vp.size != want:
		vp.size = want
