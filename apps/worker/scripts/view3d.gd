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
## Web の上限は端末の拡大率（スマホは約 3）まで上げる。2 倍で描いて 1.5 倍に引き伸ばすと、MSAA をかけても
## 縁の段々と細い輪郭の切れ目がそのまま拡大されてギザギザに見えるため。重くて 40fps を切り続けたら、
## その起動のあいだは CAP_WEB_LOW に下げる（すべての View3D がそろって下がる）。
## SubViewport のピクセルは画面の座標と倍率ぶんずれるので、カメラの写しは次を通す：
##   View3D.unproject(cam, p3)   … 3D の位置 → 画面（コンテナ）の座標
##   View3D.to_vp(cam, pos)      … 画面の座標 → SubViewport のピクセル（project_ray_* / project_position に渡す）

const CAP := 2.0
const CAP_WEB := 3.0
const CAP_WEB_LOW := 2.0
const SLOW_FPS := 40.0 # これを切り続けたら、Web の上限を下げる
const WATCH_AFTER := 3.0 # 画面が出た直後（読み込み・組み立て）の引っかかりは数えない
const WATCH_SPAN := 2.0 # この秒数の平均で見る
const SLOW_SPANS := 2 # 続けてこの回数、遅かったら下げる（一度の引っかかりでは下げない）

static var web_cap := CAP_WEB

var vp: SubViewport
var _age := 0.0
var _span := 0.0
var _frames := 0
var _slow := 0


static func fit(box: SubViewportContainer, sub: SubViewport) -> void:
	var v := View3D.new()
	v.vp = sub
	v.texture = sub.get_texture()
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR # 倍率が画面の拡大率と割り切れないときに、ドットのむらが出ないように
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_to_group("view3d")
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
	if not is_inside_tree() or size.x <= 0.0 or size.y <= 0.0: # 出ていく画面（木から外れた後の大きさの知らせ）は組み直さない
		return
	var cap := web_cap if OS.has_feature("web") else CAP
	var s := clampf(get_viewport().get_final_transform().get_scale().x, 1.0, cap)
	var want := Vector2i((size * s).floor()).max(Vector2i.ONE)
	if vp.size != want:
		vp.size = want


## Web で重いときだけ、上限を CAP_WEB_LOW へ一度だけ下げる（上げ下げをくり返して画面がちらつかないように）
func _process(delta: float) -> void:
	if not OS.has_feature("web") or web_cap <= CAP_WEB_LOW:
		set_process(false)
		return
	if not is_visible_in_tree() or Vector2(vp.size).x <= size.x * CAP_WEB_LOW + 1.0:
		return # 下げても変わらない（画面の拡大率が 2 以下）
	if delta > 0.5: # タブを隠していた・画面の組み立てで止まっていた間は数えない
		_span = 0.0
		_frames = 0
		return
	_age += delta
	if _age < WATCH_AFTER:
		return
	_span += delta
	_frames += 1
	if _span < WATCH_SPAN:
		return
	var fps := _frames / _span
	_span = 0.0
	_frames = 0
	_slow = _slow + 1 if fps < SLOW_FPS else 0
	if _slow >= SLOW_SPANS:
		web_cap = CAP_WEB_LOW
		print("View3D: %.0f fps のため、3D の倍率の上限を %.1f に下げた" % [fps, CAP_WEB_LOW])
		get_tree().call_group("view3d", "_refit")
