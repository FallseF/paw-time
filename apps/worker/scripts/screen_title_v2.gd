extends "res://scripts/screen_title.gd"
## タイトル（夕方の港）。ゲームの 3D の部品（猫おばけ・島の置き物・乗り物）だけで組んだ一枚の絵に、
## ロゴと 2 つのボタン、言語の切りかえを重ねる。ボタンの行き先は前のタイトル（screen_title.gd）と同じ関数。
## 絵の置き場所は縦 1080x1920 の設計の割合（横 fx・縦 fy）で決め、3D の位置はカメラの光線から逆算する。
## 縦長の端末では画面いっぱい、横長（PC）では縦の枠を真ん中に置き、空と海だけを左右へのばす。

const SKY := preload("res://assets/title/sky.png")
const LOGO := preload("res://assets/title/logo.png")
## 3D のロゴ（別の席が作る。あれば使い、なければ平らなロゴ）。logo_turntable_0..11 は出だしで回して見せる
const LOGO3D := "res://assets/title/logo3d/"
const LOGO3D_W := 0.78 * 1480.0 / 1334.0 # 絵の幅 ÷ 字の幅（tools/blender/logo/crop_a.py で切り出した余白）
const SEA_SHADER := preload("res://shaders/title_sea.gdshader")
const FRAME_FADE := preload("res://shaders/title_frame_fade.gdshader")

const HORIZON := 0.38 # 画面の水平線（上からの割合）
const SKY_HORIZON := 0.72 # 空の絵のこの高さを HORIZON に合わせる（絵の水平線 58% より下の桃色まで使い、ラベンダーを減らす）
const FOV := 46.0 # 縦の画角
const CAM_H := 2.4 # 海面近くからのカメラの高さ（手前の島の上の芝と岸の縁が見える、見下ろし 12〜15°）
const SEA_Y := -0.14 # 島の画面と同じ海面の高さ
const GROUND_Y := 0.32 # 手前の岬の芝の高さ（崖の段が海から立ち上がって見える）
const TERRAIN_SEA := 0.8 # 岬（terrain_title.glb）の芝から海面までの高さ（tools/blender/build_island_kit.py の TITLE_SEA）
const FAR_SWAY := 0.1 # 遠くの島は、カメラのゆれの 1 割だけ動かす（枠の 52〜92% から出ないように）
const SIDE_LAYER := 1 << 9 # 横長の画面で、縦の枠の外にも描くもの（海・海の底・ヘリ）
const CREAM := Color("fff6e6")

## タイトルの間だけ、縦横比を「のばす」にする（ほかの画面は 360x640 の枠のまま）
static var _open := 0
static var _prev_aspect := Window.CONTENT_SCALE_ASPECT_KEEP

var box: SubViewportContainer # 画面いっぱい：枠の外の海と空の物だけ（横長の画面のとき）
var frame_box: SubViewportContainer # 縦の枠：ぜんぶ
var frame_vp: SubViewport
var world: Node3D
var cam: Camera3D
var cam_wide: Camera3D
var sky_rects: Array[TextureRect] = []
var sky_warm: TextureRect
var cat: MyObake3D
var cat_mat: ShaderMaterial
var island: Node3D
var pier: Node3D
var raft: Node3D
var heli: Node3D
var far_isles: Array[Node3D] = []
var far_root: Node3D # 遠くの島の入れ物（カメラの位置を軸に、ゆれを打ち消す）
var props: Array[Node3D] = [] # 岬の上の小物（掲示板・物干し）
var lamp: Node3D # 桟橋の根元の灯り
var spinners: Array = []
var logo: TextureRect
const TAGLINE_AT := 0.86 # ロゴの絵の高さのうち、ひとことを置く位置（字の下の影の余白に重ねる）
var logo_glow: TextureRect # 3D のロゴのにじみ（加算）。無ければ null
var logo_shadow: TextureRect
var logo_main: Texture2D
var logo_frames: Array[Texture2D] = []
var tap_label: Label
var tagline: Label # ロゴの下の小さなひとこと「いっしょにはたらこう」
var row: HBoxContainer # 「島へおでかけ ・ English」の小さな行
var visit_btn: Button
var lang_btn: Button
var veil: ColorRect # 出だしの暗幕
var fx_back: TitleFx
var fx_front: TitleFx
var far_lights: Array[Node3D] = []
## 出だしの演出の時間（読み込みの引っかかりで飛ばないよう、1 フレームの進みに上限）。2 回目以降（言語の切りかえ）は演出なし
var _rv := 0.0
static var _revealed := false
var _leaving := false
var cat_rect := Rect2() # 猫が映っている場所（キャンバスの座標）
var frame := Rect2(0, 0, 360, 640)
var pitch := 0.0
var logo_y := 0.0
var heli_fx := 0.86
var heli_depth := 30.0
var raft_y := 0.0
var _blink_in := 2.5
var _blink := 0.0
var _twitch_in := 3.0
var _twitch := -1.0
var _twitch_side := 1
var _twitch_hold := false


func _enter_tree() -> void:
	var win := get_tree().root
	if _open == 0:
		_prev_aspect = win.content_scale_aspect
	_open += 1
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND


func _exit_tree() -> void:
	if resized.is_connected(_layout):
		resized.disconnect(_layout) # 縦横比を戻すと大きさが変わる。出ていく画面は組み直さない
	_open -= 1
	if _open == 0:
		get_tree().root.content_scale_aspect = _prev_aspect


func _ready() -> void:
	for i in 5:
		var r := TextureRect.new()
		r.texture = SKY
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.flip_h = i % 2 == 1 # 真ん中から交互に鏡に映して、雲を切れ目なくつなぐ
		r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		sky_rects.append(r)
	# 上の空を、暖かい桃色へ少し寄せる（光らせない、ただの薄い色の重ね）
	var g := Gradient.new()
	g.set_color(0, Color(0.98, 0.8, 0.66, 0.42))
	g.set_color(1, Color(0.98, 0.8, 0.66, 0.0))
	g.add_point(0.6, Color(0.98, 0.8, 0.66, 0.16))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 128
	sky_warm = TextureRect.new()
	sky_warm.texture = gt
	sky_warm.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky_warm.stretch_mode = TextureRect.STRETCH_SCALE
	sky_warm.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sky_warm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky_warm)
	fx_back = TitleFx.new("back")
	add_child(fx_back)
	_build_world()
	fx_front = TitleFx.new("front")
	add_child(fx_front)
	_build_ui()
	veil = ColorRect.new()
	veil.color = Color("0b1026")
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(veil)
	# どこをタップしても、はじめる（下の小さな行のボタンをのぞく）
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _revealed:
		_rv = 10.0
	_revealed = true
	resized.connect(_layout)
	_layout()


# ---------------------------------------------------------------- 3D

func _build_world() -> void:
	# 透明の背景に描いた 3D は、色に透明度が掛かった状態（premultiplied）。そのまま重ねると縁が黒ずむ
	var pm := CanvasItemMaterial.new()
	pm.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	box = SubViewportContainer.new()
	box.stretch = false
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.material = pm
	add_child(box)
	vp = SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true # 空は下の絵（sky.png）
	vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(vp)
	world = Node3D.new()
	vp.add_child(world)
	Look.apply(world, "title_golden", Color(0, 0, 0, 0), true, false)
	cam_wide = _camera()
	cam_wide.cull_mask = SIDE_LAYER
	world.add_child(cam_wide)
	# 縦の枠は、同じ世界を別のカメラで（枠の外に島や陸を出さない）
	frame_box = SubViewportContainer.new()
	frame_box.stretch = false
	frame_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 横長の画面では、枠の左右のふちを少しぼかして、枠の外の海へなじませる（島がすぱっと切れて見えないように）
	var fm := ShaderMaterial.new()
	fm.shader = FRAME_FADE
	frame_box.material = fm
	add_child(frame_box)
	frame_vp = SubViewport.new()
	frame_vp.world_3d = vp.find_world_3d()
	frame_vp.transparent_bg = true
	frame_vp.msaa_3d = Viewport.MSAA_4X
	frame_box.add_child(frame_vp)
	cam = _camera()
	frame_vp.add_child(cam)
	# 浅瀬の底（半透明の海の下。島の岸の外側も同じ色）
	var bed := MeshInstance3D.new()
	var bp := PlaneMesh.new()
	bp.size = Vector2(160, 160)
	bed.mesh = bp
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color("2a6d86")
	bed.material_override = bm
	bed.position.y = -0.56
	bed.layers = 1 | SIDE_LAYER
	world.add_child(bed)
	var sea := MeshInstance3D.new()
	var sp := PlaneMesh.new()
	sp.size = Vector2(3000, 3000)
	sea.mesh = sp
	sea.material_override = ShaderMaterial.new()
	(sea.material_override as ShaderMaterial).shader = SEA_SHADER
	sea.position.y = SEA_Y
	sea.name = "Sea"
	sea.layers = 1 | SIDE_LAYER
	world.add_child(sea)
	# 手前の自分の島（左下を切り取る）と桟橋
	# 手前の岬：島の置き物キットの地形（段のある砂岩の崖・芝のふち）。水ぎわに小石、左のふちに低い茂み
	island = Node3D.new()
	world.add_child(island)
	var land := MeshInstance3D.new()
	land.mesh = IslandProps.glb("terrain_title")
	var lm := _ground_mat(Color("e9dcc3"))
	lm.set_shader_parameter("ground_mottle", 0.0) # 崖の面に縦の筋が出るので、まだらは付けない
	land.material_override = lm
	island.add_child(land)
	var kit := IslandProps.new()
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 11
	for deg in [4.0, 16.0, 29.0, 43.0]: # 見えている崖（猫の右〜桟橋の下）の水ぎわだけ
		var th := deg_to_rad(deg)
		var rr := 4.5 * (1.0 + 0.045 * sin(3.0 * th + 1.1) + 0.03 * sin(5.0 * th + 0.3)) + rnd.randf_range(0.55, 0.7) # 崖の下の棚（水ぎわ）
		kit.add(island, IslandProps.glb("rock"), IslandProps.m(Color("b39a86").darkened(rnd.randf() * 0.15)),
			Vector3(cos(th) * rr, -TERRAIN_SEA + 0.05, sin(th) * rr), Vector3(0, rnd.randf() * 3.0, 0), Vector3.ONE * rnd.randf_range(0.2, 0.3))
	for i in 2:
		var b := IslandProps.build("bush")
		b.name = "Bush%d" % i
		island.add_child(b)
	_build_props()
	pier = IslandProps.build("pier")
	world.add_child(pier)
	raft = VehicleProps.build_vehicle("raft")
	world.add_child(raft)
	# 自分の猫（診断の子。まだなら生成りの子）
	cat = _make_cat()
	world.add_child(cat)
	# 遠くの 2 つの島：カフェ（赤い瓦としま模様の日よけ）と、角のお店（緑の屋根）
	far_root = Node3D.new()
	world.add_child(far_root)
	far_isles.append(_far_isle(Color("e0674f"), Color("fff1dc"), "tree_round", "cup"))
	far_isles.append(_far_isle(Color("6fae6a"), Color("fff6e6"), "tree_round", "apple"))
	heli = VehicleProps.build_vehicle("helicopter")
	world.add_child(heli)
	# 横長の画面では、ヘリと手前の岬（小物ごと）も枠の外へ続ける（枠のふちで切れないように）
	for n in [heli, island]:
		for m in (n as Node3D).find_children("*", "GeometryInstance3D", true, false):
			(m as VisualInstance3D).layers |= SIDE_LAYER
	for v in [raft, heli]:
		for n in (v as Node3D).find_children("*", "Node3D", true, false):
			if n.has_meta("spin"):
				spinners.append(n)


func _camera() -> Camera3D:
	var c := Camera3D.new()
	c.keep_aspect = Camera3D.KEEP_HEIGHT
	c.fov = FOV
	c.near = 0.1
	c.far = 3000.0
	return c


## 地形と同じ塗り（頂点色の芝・砂・ぬれた砂）。tint は夕方の色へ寄せる掛け色
func _ground_mat(tint := Color("f4ead8")) -> ShaderMaterial:
	var m := Obake3D.skin(Color.WHITE, 0.0, null, 0.06, 0.0, false, 0.02).duplicate() as ShaderMaterial
	m.set_shader_parameter("vertex_albedo", 1.0)
	m.set_shader_parameter("top_light", 0.12)
	m.set_shader_parameter("ground_mottle", 0.06)
	m.set_shader_parameter("base_color", tint) # 夕方の芝（少し落ち着いた黄緑へ）
	return m


func _make_cat() -> MyObake3D:
	var look: Dictionary = GameState.my_obake.get("look", {})
	if look.is_empty():
		look = QuizResult.load_result().get("look", {})
	if look.is_empty():
		look = {"color": "fff3df", "accessory": "", "accent": "e0674f", "motion": "bob"}
	var c := MyObake3D.new().setup_look(look)
	# 耳を動かすために、この子の体だけ材質を分ける（ほかの子と共有しない）
	var b := c.body.find_child("Body", true, false) as MeshInstance3D
	if b and b.material_override is ShaderMaterial:
		cat_mat = b.material_override.duplicate() as ShaderMaterial
		if cat_mat.next_pass:
			cat_mat.next_pass = cat_mat.next_pass.duplicate()
		b.material_override = cat_mat
	c.bob = false
	c.set_process(false) # 息・まばたき・耳はここで動かす（しぐさで体がゆれないように）
	c.rotation.y = 0.44 # 右（遠くの島）を向いた 3/4。両目・ω の口・ひげが読める向き
	# しっぽは体の右がわ（画面の左）へ回して、輪郭からのぞかせる
	var tail := c.body.find_child("Tail", true, false) as Node3D
	if tail:
		tail.rotation.y = 1.25
	return c


func _far_isle(sign_c: Color, accent: Color, tree_id: String, icon: String) -> Node3D:
	var n := Node3D.new()
	var land := MeshInstance3D.new()
	land.mesh = IslandProps.land_lobe(1.35, 7)
	land.name = "Land" # 水の下まで広がる板なので、横の広がりを測るときは数えない
	land.material_override = _ground_mat()
	n.add_child(land)
	var shop := ShopLandmarks.build_shop(sign_c, accent)
	shop.scale = Vector3.ONE * 0.8
	shop.position = Vector3(0, 0, -0.2)
	n.add_child(shop)
	_sign_icon(shop, icon)
	var tree := IslandProps.build(tree_id)
	tree.position = Vector3(0.75, 0, -0.85) # お店のうしろ寄り（横にはみ出さない）
	tree.scale = Vector3.ONE * 0.85
	n.add_child(tree)
	var pr := IslandProps.build("pier")
	pr.scale = Vector3(0.6, 0.6, 0.35)
	pr.position = Vector3(-0.6, -0.1, 1.7)
	pr.rotation.y = -0.35
	n.add_child(pr)
	# 小さな灯り（窓の明かりと、店先の灯）
	for p in [Vector3(-0.44, 0.62, 0.52), Vector3(0.95, 0.5, 0.9)]:
		var g := MeshInstance3D.new()
		g.mesh = IslandProps.new().sph(0.07)
		g.material_override = Kit.glow(Color("ffd98a"), 1.6)
		g.position = p
		n.add_child(g)
		far_lights.append(g)
	far_root.add_child(n)
	return n


## お店の屋根の看板に、ひと目でわかる印（カフェはコーヒーカップ、角のお店はりんご）
func _sign_icon(shop: Node3D, icon: String) -> void:
	var k := IslandProps.new()
	var at := Vector3(0, 1.98, 0.3) # 看板の板の前（ShopLandmarks._shop）
	var icon_root := k.node(shop, at)
	icon_root.scale = Vector3.ONE * 1.35
	at = Vector3.ZERO
	if icon == "cup":
		var brown := IslandProps.m(Color("6e3f2a"))
		k.add(icon_root, k.cyl(0.13, 0.1, 0.2), brown, at + Vector3(-0.03, 0.0, 0))
		k.add(icon_root, k.torus(0.04, 0.075), brown, at + Vector3(0.12, 0.01, 0), Vector3(PI / 2, 0, 0))
		k.add(icon_root, k.cyl(0.19, 0.19, 0.025), IslandProps.m(Color("b9784f")), at + Vector3(-0.03, -0.11, 0))
		k.add(icon_root, k.cyl(0.11, 0.11, 0.012), IslandProps.m(Color("3a2218")), at + Vector3(-0.03, 0.1, 0))
	else:
		k.add(icon_root, k.sph(0.14), IslandProps.m(Color("d8453b"), 0.4), at + Vector3(0, -0.02, 0), Vector3.ZERO, Vector3(1.05, 0.95, 0.8))
		k.add(icon_root, k.cyl(0.012, 0.015, 0.09), IslandProps.m(Color("5a3a24")), at + Vector3(0.0, 0.14, 0.02), Vector3(0, 0, -0.3))
		k.add(icon_root, k.box(Vector3(0.1, 0.02, 0.05)), IslandProps.m(Color("5fae4f")), at + Vector3(0.06, 0.15, 0.02), Vector3(0, 0, 0.35))


## 岬の上の小物：仕事の掲示板（紙が 2 枚）、エプロンを干した短い物干し、桟橋のそばの灯り
func _build_props() -> void:
	var k := IslandProps.new()
	var board := Node3D.new()
	board.name = "JobBoard"
	for x in [-0.4, 0.4]:
		k.add(board, k.cyl(0.035, 0.035, 1.05), IslandProps.m(IslandProps.WOOD_D), Vector3(x, 0.52, 0))
	k.add(board, k.box(Vector3(0.9, 0.56, 0.05)), IslandProps.m(Color("c69a6c")), Vector3(0, 0.74, 0))
	k.add(board, k.box(Vector3(1.0, 0.07, 0.16), 0.02), IslandProps.m(Color("8a5a3c")), Vector3(0, 1.06, 0))
	for i in 2:
		var x := -0.18 + i * 0.36
		k.add(board, k.box(Vector3(0.26, 0.3, 0.01), 0.004), IslandProps.m([Color("fff6e0"), Color("ffe6d6")][i]), Vector3(x, 0.72 + i * 0.03, 0.035), Vector3(0, 0, (i - 0.5) * 0.12))
		for j in 3:
			k.add(board, k.box(Vector3(0.16, 0.012, 0.004)), IslandProps.m(Color("b9a58e")), Vector3(x, 0.78 - j * 0.06 + i * 0.03, 0.043), Vector3(0, 0, (i - 0.5) * 0.12))
		k.add(board, k.sph(0.018), IslandProps.m(IslandProps.RED), Vector3(x, 0.85 + i * 0.03, 0.05))
	props.append(board)
	var line := Node3D.new()
	line.name = "Clothesline"
	for x in [-0.55, 0.55]:
		k.add(line, k.cyl(0.03, 0.035, 0.95), IslandProps.m(IslandProps.WOOD_D), Vector3(x, 0.47, 0))
	k.add(line, k.cyl(0.008, 0.008, 1.12), IslandProps.m(Color("e8dcc0")), Vector3(0, 0.88, 0), Vector3(0, 0, PI / 2))
	# 小さなエプロン（猫のカフェのエプロン）：胸当て・ポケット・ひも、洗濯ばさみ 2 つ
	var ap := Color("d9774f")
	k.add(line, k.box(Vector3(0.3, 0.34, 0.015), 0.006), IslandProps.m(ap), Vector3(0.05, 0.68, 0))
	k.add(line, k.box(Vector3(0.16, 0.08, 0.02), 0.004), IslandProps.m(ap), Vector3(0.05, 0.86, 0))
	k.add(line, k.box(Vector3(0.14, 0.08, 0.02), 0.004), IslandProps.m(Color("fff1dc")), Vector3(0.05, 0.64, 0.012))
	for x in [-0.03, 0.13]:
		k.add(line, k.box(Vector3(0.02, 0.06, 0.03)), IslandProps.m(Color("f2c14e")), Vector3(x, 0.89, 0.01))
	k.add(line, k.box(Vector3(0.12, 0.14, 0.012), 0.004), IslandProps.m(Color("9fc6e8")), Vector3(-0.3, 0.8, 0)) # 小さな手ぬぐい
	props.append(line)
	for pr in props:
		island.add_child(pr)
	lamp = IslandProps.build("paper_lantern")
	lamp.name = "Lantern"
	for l in lamp.find_children("*", "OmniLight3D", true, false):
		(l as OmniLight3D).light_energy = 0.9
		(l as OmniLight3D).omni_range = 1.4
	world.add_child(lamp)


# ---------------------------------------------------------------- 置き場所

## 画面の割合（枠の中の fx, fy）から、カメラの光線の向き（ゆれの前）
func _ray(fx: float, fy: float) -> Vector3:
	var vs := size
	var px := frame.position.x + fx * frame.size.x
	var py := frame.position.y + fy * frame.size.y
	var tv := tan(deg_to_rad(FOV * 0.5))
	var th := tv * vs.x / vs.y
	var d := Vector3((px / vs.x * 2.0 - 1.0) * th, (1.0 - py / vs.y * 2.0) * tv, -1.0)
	return Basis(Vector3.RIGHT, pitch) * d.normalized()


## その割合の光線が、高さ y の平らな面に当たる場所
func _on_plane(fx: float, fy: float, y: float) -> Vector3:
	var d := _ray(fx, fy)
	var o := Vector3(0, CAM_H, 0)
	return o + d * ((y - o.y) / minf(d.y, -0.0001))


## 場所 p で、枠の幅の frac ぶんに見える長さ（世界の単位）
func _world_w(p: Vector3, frac: float) -> float:
	var d := (Basis(Vector3.RIGHT, pitch).inverse() * (p - Vector3(0, CAM_H, 0))).z * -1.0
	return frac * frame.size.x * 2.0 * d * tan(deg_to_rad(FOV * 0.5)) / frame.size.y


## 世界の点が映る場所（キャンバスの座標）。枠のカメラで
func _proj(p: Vector3) -> Vector2:
	return cam.unproject_position(p) * frame.size.y / float(frame_vp.size.y) + frame.position


func _on_plane_px(p: Vector2, y: float) -> Vector3:
	return _on_plane((p.x - frame.position.x) / frame.size.x, (p.y - frame.position.y) / frame.size.y, y)


## 猫の見た目（耳の先から、手前の裾まで）が縦 top_fy〜bottom_fy、真ん中が横 fx に来るよう、
## 置き場所と縮尺を映した位置から詰める。返り値は足元
func _fit_cat(fx: float, top_fy: float, bottom_fy: float) -> Vector3:
	var box := AABB()
	var first := true
	cat.scale = Vector3.ONE
	cat.position = Vector3.ZERO
	for m in cat.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.name == "ContactShadow" or mi.mesh == null:
			continue
		var b := (cat.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var c := box.get_center()
	# 耳の先（上）・手前の裾（下）・左右のふち。箱の角は丸い体より外なので使わない
	var probes := [Vector3(c.x, box.end.y, c.z), Vector3(c.x, box.position.y, box.end.z),
		Vector3(box.position.x, c.y, c.z), Vector3(box.end.x, c.y, c.z)]
	var want_top := frame.position.y + top_fy * frame.size.y
	var want_bottom := frame.position.y + bottom_fy * frame.size.y
	var want_x := frame.position.x + fx * frame.size.x
	var foot := _on_plane(fx, bottom_fy, GROUND_Y)
	var s := _fit_height(foot, fx, top_fy, box.end.y)
	for i in 6:
		cat.position = foot
		cat.scale = Vector3.ONE * s
		var pts: Array[Vector2] = []
		for p in probes:
			pts.append(_proj(cat.to_global(p)))
		var top := pts[0].y
		var bottom := pts[1].y
		var mid := (pts[2].x + pts[3].x) * 0.5
		s *= (want_bottom - want_top) / maxf(bottom - top, 1.0)
		foot = _on_plane_px(_proj(foot) + Vector2(want_x - mid, want_bottom - bottom), GROUND_Y)
	cat.position = foot
	cat.scale = Vector3.ONE * s
	cat_rect = Rect2(want_x - (want_bottom - want_top) * 0.62, want_top, (want_bottom - want_top) * 1.24, want_bottom - want_top)
	return foot


## 足元 foot に立つ高さ h の物の頭が、縦の割合 top_fy に来る縮尺
func _fit_height(foot: Vector3, fx: float, top_fy: float, h: float) -> float:
	var d := _ray(fx, top_fy)
	var o := Vector3(0, CAM_H, 0)
	var t := Vector2(foot.x - o.x, foot.z - o.z).length() / maxf(Vector2(d.x, d.z).length(), 0.0001)
	return maxf((o.y + d.y * t - foot.y) / h, 0.01)


func _layout() -> void:
	var vs := size
	if vs.x < 2.0 or vs.y < 2.0:
		return
	var fw := minf(vs.x, vs.y * 9.0 / 16.0)
	frame = Rect2((vs.x - fw) * 0.5, 0, fw, vs.y)
	# 空：高さに合わせて縦横比を保ち、真ん中に。左右は鏡でのばす。
	# 絵の水平線（58%）を画面の水平線（38%）へ上げて、下の暖かい桃色を水平線のすぐ上に置く
	var sw := vs.y * 9.0 / 16.0
	var sx := (vs.x - sw) * 0.5
	for i in 5:
		sky_rects[i].position = Vector2(sx + (i - 2) * sw, (HORIZON - SKY_HORIZON) * vs.y)
		sky_rects[i].size = Vector2(sw, vs.y)
	sky_warm.position = Vector2.ZERO
	sky_warm.size = Vector2(vs.x, HORIZON * vs.y)
	# 3D は画面の実際の画素で描く（キャンバスの拡大でぼやけないように）
	var k := clampf(get_viewport().get_final_transform().x.x, 1.0, 2.0 if OS.has_feature("web") else 3.0)
	frame_vp.size = Vector2i(ceili(frame.size.x * k), ceili(frame.size.y * k))
	frame_box.size = Vector2(frame_vp.size)
	frame_box.scale = Vector2.ONE / k
	frame_box.position = frame.position
	# 枠の外（横長の画面）は、海とヘリだけを画面いっぱいに。縦長なら描かない
	var wide := vs.x > frame.size.x + 1.0
	box.visible = wide
	vp.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if wide else SubViewport.UPDATE_DISABLED
	(frame_box.material as ShaderMaterial).set_shader_parameter("fade", 28.0 / frame.size.x if wide else 0.0)
	if wide:
		vp.size = Vector2i(ceili(vs.x * k), ceili(vs.y * k))
		box.size = Vector2(vp.size)
		box.scale = Vector2.ONE / k
	# 水平線が 38% に来るよう、カメラを下へ向ける
	var tv := tan(deg_to_rad(FOV * 0.5))
	pitch = atan((HORIZON - 0.5) * 2.0 * tv)
	for c in [cam, cam_wide]:
		(c as Camera3D).position = Vector3(0, CAM_H, 0)
		(c as Camera3D).rotation = Vector3(pitch, 0, 0)
	_place_world()
	_layout_ui()


func _place_world() -> void:
	# 猫：体ぜんぶ。真ん中が横 32%、耳の先 48%・しっぽの下 70%（画面の高さの 22%）
	_fit_cat(0.32, 0.48, 0.70)
	# 手前の岬：芝の縁は左下から上がり、猫の右（47%, 72%）へ。その下は海（ボタンは海の上）。
	# 岬の崖は +X+Z の 40° の弧（terrain_title）。半径 4.5 の地形を、芝から海までが TERRAIN_SEA になるよう縮める
	var a := _on_plane(0.47, 0.72, GROUND_Y)
	var q := absf(a.x - _on_plane(0.0, 0.72, GROUND_Y).x) / 1.876 # 横の見え方（9:16 で 1）
	var ts := (GROUND_Y - SEA_Y) / TERRAIN_SEA
	# 手前は奥へ詰めて、ボタンの左はしの裏に崖がかからないように（前後だけ 0.8 倍、中心を奥へ）
	island.position = Vector3(a.x - 2.45 * q, GROUND_Y, a.z - 1.3)
	island.scale = Vector3(ts * q, ts, ts * 0.8)
	# 小物：猫の左うしろ（猫にはかぶせない）。茂みは左のふち
	var cs := cat.scale.x
	var spots := {"JobBoard": [0.07, 0.64, 0.7, 0.3], "Clothesline": [0.1, 0.72, 0.5, 0.2],
		"Bush0": [0.0, 0.765, 0.5, 0.0], "Bush1": [0.2, 0.775, 0.38, 1.0]}
	for key in spots:
		var n := island.get_node(key) as Node3D
		var sp: Array = spots[key]
		var wp := _on_plane(sp[0], sp[1], GROUND_Y)
		n.position = island.to_local(wp)
		# 岬の縮尺（横と奥で少し違う）を打ち消して、猫に対する大きさで置く
		n.scale = Vector3(cs * sp[2] / island.scale.x, cs * sp[2] / island.scale.y, cs * sp[2] / island.scale.z)
		n.rotation.y = sp[3]
	# 短い桟橋：猫の右の岸から右奥へ。いかだはその手前に横づけ (62%, 70%)
	var shore := _on_plane(0.44, 0.685, GROUND_Y)
	var tip := _on_plane(0.74, 0.655, SEA_Y)
	var dir := Vector3(tip.x - shore.x, 0, tip.z - shore.z)
	var ws := _world_w(shore, 0.08) / 0.8
	pier.scale = Vector3(ws, ws, dir.length() / 2.2)
	pier.rotation.y = atan2(dir.x, dir.z)
	pier.position = (shore + tip) * 0.5
	pier.position.y = GROUND_Y + 0.02 - 0.14 * ws
	# 灯り：桟橋の根元の、手前がわのふち（猫にはかからない）
	var side := Vector3(dir.z, 0, -dir.x).normalized()
	if side.z < 0.0:
		side = -side
	lamp.position = shore + dir * 0.3 + side * 0.36 * ws + Vector3(0, 0.02, 0)
	lamp.scale = Vector3.ONE * cs * 0.5
	lamp.rotation.y = atan2(dir.x, dir.z) + PI * 0.5
	var rp := _on_plane(0.62, 0.70, SEA_Y)
	raft_y = SEA_Y + 0.01
	raft.position = Vector3(rp.x, raft_y, rp.z)
	raft.scale = Vector3.ONE * _world_w(rp, 0.2) / 1.3
	raft.rotation.y = pier.rotation.y - PI * 0.5
	# 遠くの島：カフェ（左）と角のお店（右）。水平線に乗り、屋根の上が 30% くらい。
	# ふたつ合わせた横の広がりを 53〜91% に収める（ゆれを足しても 52〜92%）
	far_root.position = Vector3(0, CAM_H, 0)
	far_root.rotation = Vector3.ZERO
	var fx := [0.66, 0.79] # 角のお店はカフェの右うしろに半分ほど重ねる（2 回目の大きさのまま 52〜92% に収める）
	var tops := [0.326, 0.323] # 2 回目の大きさ（屋根・日よけ・看板の印が読める）。角のお店は少し奥で、カフェのうしろに重ねる
	var bases := [0.447, 0.437]
	for it in 4:
		for i in far_isles.size():
			var fp := _on_plane(fx[i], bases[i], SEA_Y)
			var isle := far_isles[i]
			isle.global_position = Vector3(fp.x, SEA_Y + 0.1, fp.z)
			isle.scale = Vector3.ONE * _fit_height(isle.global_position, fx[i], tops[i], 2.1)
			isle.rotation.y = atan2(-fp.x, -fp.z) + (0.3 if i == 0 else -0.25)
		var lo := 1.0
		var hi := 0.0
		for isle in far_isles:
			for m in isle.find_children("*", "MeshInstance3D", true, false):
				var mi := m as MeshInstance3D
				if mi.name == "Land":
					continue
				var bb := mi.global_transform * mi.get_aabb()
				for c in 8:
					var px := (_proj(bb.get_endpoint(c)).x - frame.position.x) / frame.size.x
					lo = minf(lo, px)
					hi = maxf(hi, px)
		# 大きさはそのまま、真ん中を 73.5% に寄せる（左の砂浜の端まで 52% の内に）
		var mid := (lo + hi) * 0.5
		for i in 2:
			fx[i] += 0.735 - mid
	var sm := (world.get_node("Sea") as MeshInstance3D).material_override as ShaderMaterial
	sm.set_shader_parameter("sun_dir", _ray(0.76, 0.35))
	# ヘリ：右上 (86%, 22%) から左へゆっくり
	heli_depth = 34.0
	var hw := 0.11 * frame.size.x * 2.0 * heli_depth * tan(deg_to_rad(FOV * 0.5)) / frame.size.y
	heli.scale = Vector3.ONE * hw / 2.6
	_place_heli(0.0)


func _place_heli(t: float) -> void:
	# 高さ 22.5%：ロゴの下の縁（18.6%）にかからない
	heli.position = Vector3(0, CAM_H, 0) + _ray(heli_fx, 0.225 + sin(t * 0.9) * 0.004) * heli_depth
	heli.rotation = Vector3(0, PI - 0.35, 0.05) # 左（-X）へ進む。少しこちらへ振って形を読ませる


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	logo_main = LOGO
	if ResourceLoader.exists(LOGO3D + "logo_main.png"):
		logo_main = load(LOGO3D + "logo_main.png")
		for i in 12:
			var f := LOGO3D + "logo_turntable_%d.png" % i
			if ResourceLoader.exists(f):
				logo_frames.append(load(f))
		logo_shadow = _logo_rect(LOGO3D + "logo_shadow.png")
		logo_glow = _logo_rect(LOGO3D + "logo_glow.png") # にじみだけ（字入りの絵を大きく重ねると、字が二重に見える）
		if logo_glow:
			var add := CanvasItemMaterial.new()
			add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			logo_glow.material = add
	logo = TextureRect.new()
	logo.texture = logo_main
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	# ロゴの下の小さなひとこと（同じ字の系統で、控えめに）
	tagline = Kit.text(tr("R3_TAGLINE"), 16, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	tagline.add_theme_color_override("font_shadow_color", Color(0.1, 0.07, 0.16, 0.6))
	tagline.add_theme_constant_override("shadow_offset_y", 1)
	tagline.add_theme_constant_override("shadow_outline_size", 5)
	tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tagline.modulate.a = 0.0
	add_child(tagline)
	# 「タップしてはじめる」：ゆっくり息をする一行
	tap_label = Kit.text("タップしてはじめる", 18, CREAM, false, HORIZONTAL_ALIGNMENT_CENTER)
	tap_label.add_theme_color_override("font_shadow_color", Color(0.1, 0.07, 0.16, 0.55))
	tap_label.add_theme_constant_override("shadow_offset_y", 1)
	tap_label.add_theme_constant_override("shadow_outline_size", 5)
	tap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tap_label)
	# 下の小さな行：島へおでかけ ・ 言語
	row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	add_child(row)
	visit_btn = _text_button("島へおでかけ")
	visit_btn.pressed.connect(func():
		_ask_code()
		_center_dialog())
	row.add_child(visit_btn)
	# 審査員用の3分デモ（前のタイトルにあった入口を、この行に残す）
	for i in 2:
		var dot := Kit.text(tr("R3_SEP").strip_edges(), 13, Color(CREAM, 0.6), false, HORIZONTAL_ALIGNMENT_CENTER)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(dot)
		if i == 0:
			var demo_btn := _text_button(tr("DEMO3_BUTTON"))
			demo_btn.pressed.connect(_demo)
			row.add_child(demo_btn)
	lang_btn = _text_button("日本語" if Kit.is_en() else "English")
	lang_btn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	lang_btn.pressed.connect(func():
		Kit.save_lang("ja" if Kit.is_en() else "en")
		main.go("title", true))
	row.add_child(lang_btn)


func _logo_rect(path: String) -> TextureRect:
	if not ResourceLoader.exists(path):
		return null
	var r := TextureRect.new()
	r.texture = load(path)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(r)
	return r


## 文字だけの静かなボタン（大きな丸い板は使わない）
func _text_button(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", Kit.bold())
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", Color(CREAM, 0.82))
	b.add_theme_color_override("font_hover_color", CREAM)
	b.add_theme_color_override("font_pressed_color", Color(CREAM, 0.6))
	b.add_theme_color_override("font_shadow_color", Color(0.1, 0.07, 0.16, 0.45))
	b.add_theme_constant_override("shadow_outline_size", 4)
	for k in ["normal", "hover", "pressed", "focus"]:
		var e := StyleBoxEmpty.new()
		e.content_margin_left = 8
		e.content_margin_right = 8
		e.content_margin_top = 6
		e.content_margin_bottom = 6
		b.add_theme_stylebox_override(k, e)
	return b


## はじめる：つづきがあれば、つづきから。なければ前のタイトルの「はじめる」と同じ流れ
func _start() -> void:
	if _leaving:
		return
	_leaving = true
	Kit.play(self, "confirm")
	if GameState.has_save():
		_continue()
	else:
		_new("data")


## 画面のどこかをタップ：出だしの途中なら演出を終わらせ、終わっていれば、はじめる
func _tap() -> void:
	if confirm != null:
		return
	if _rv < 2.6:
		_rv = 2.6
		return
	_start()


func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
		accept_event()
		_tap()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_accept"):
		_tap()


## 端末の切り欠き（上・下）。キャンバスの長さで
func _safe_insets() -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Vector2.ZERO
	var k := maxf(get_viewport().get_final_transform().x.x, 0.01)
	return Vector2(maxf(safe.position.y, 0) / k, maxf(win.y - safe.end.y, 0) / k)


func _layout_ui() -> void:
	var f := frame
	var inset := _safe_insets()
	# 字の幅が画面の 78%（3D のロゴ（案 A・1 行）は影とにじみの余白ぶん、絵を少し大きく）
	var lw := f.size.x * (LOGO3D_W if logo_main != LOGO else 0.78)
	logo.size = Vector2(lw, lw * float(logo_main.get_height()) / logo_main.get_width())
	logo_y = maxf(f.size.y * 0.07, inset.x + 44.0)
	logo.position = Vector2(f.position.x + (f.size.x - lw) * 0.5, logo_y)
	logo.pivot_offset = logo.size * 0.5
	for r in [logo_glow, logo_shadow]:
		if r:
			(r as Control).size = logo.size
			(r as Control).position = logo.position - ((r as Control).size - logo.size) * 0.5 + (Vector2(0, 6) if r == logo_shadow else Vector2.ZERO)
			(r as Control).pivot_offset = (r as Control).size * 0.5
	tagline.size = Vector2(f.size.x, 24)
	tagline.position = Vector2(f.position.x, logo_y + logo.size.y * TAGLINE_AT)
	var bottom := minf(f.size.y * 0.95, f.size.y - inset.y - 8.0)
	row.size = Vector2(f.size.x, 30)
	row.position = Vector2(f.position.x, bottom - 30)
	tap_label.size = Vector2(f.size.x, 28)
	tap_label.position = Vector2(f.position.x, f.size.y * 0.88 - 14)
	for fx in [fx_back, fx_front]:
		(fx as TitleFx).position = Vector2.ZERO
		(fx as TitleFx).size = size
		(fx as TitleFx).frame = f
		(fx as TitleFx).horizon = HORIZON
		(fx as TitleFx).sun = f.position + Vector2(0.74, 0.365) * f.size


## 前のタイトルの入力の小窓は 360x640 の位置で組んである。縦の枠の真ん中へ寄せる
func _center_dialog() -> void:
	if confirm == null:
		return
	for c in confirm.get_children():
		if c is PanelContainer:
			(c as Control).position += Vector2(frame.position.x + (frame.size.x - 360.0) * 0.5, (frame.size.y - 640.0) * 0.4)


# ---------------------------------------------------------------- うごき

func _process(delta: float) -> void:
	_t += delta
	_rv += minf(delta, 1.0 / 20.0)
	# カメラ：出だしは 6 秒かけてゆっくり寄り（最後は静かに止まる）、そのあと 12 秒で ±1.5° ゆっくり左右に
	var sway := smoothstep(4.5, 6.5, _rv)
	cam.rotation = Vector3(pitch, deg_to_rad(1.5) * sin(_t * TAU / 12.0) * sway, 0)
	var dolly := pow(1.0 - clampf(_rv / 6.0, 0.0, 1.0), 3.0)
	cam.position = Vector3(0, CAM_H, 0) + Basis.from_euler(cam.rotation) * Vector3(0, 0.35, 1.0) * 2.6 * dolly
	cam_wide.rotation = cam.rotation
	cam_wide.position = cam.position
	far_root.rotation.y = cam.rotation.y * (1.0 - FAR_SWAY)
	_animate_reveal()
	raft.position.y = raft_y + sin(_t * 1.1) * 0.025 * cat.scale.x
	raft.rotation.z = sin(_t * 0.8 + 0.6) * 0.03
	raft.rotation.x = sin(_t * 0.95) * 0.025
	# ヘリ：86% から左へ（20 秒ほどで画面の外）、右から戻ってくる
	heli_fx -= minf(delta, 0.1) * 0.044 # 読み込みで止まった間に飛んでいかないよう
	if heli_fx < -0.14:
		heli_fx = 1.14
	_place_heli(_t)
	for n in spinners:
		(n as Node3D).rotate_object_local(n.get_meta("spin_axis"), float(n.get_meta("spin")) * delta)
	_animate_cat(delta)


## 出だし：暗幕が 0.6 秒で明け、1.2 秒でロゴが少し弾んで出る（3D のロゴなら回って止まる）。
## そのあと「タップしてはじめる」が息をしはじめ、光の筋と粒がゆっくり満ちる。以降は静か
func _animate_reveal() -> void:
	veil.modulate.a = 1.0 - clampf(_rv / 0.6, 0.0, 1.0)
	var p := clampf((_rv - 1.2) / 0.9, 0.0, 1.0)
	var c1 := 1.70158 * 0.8
	var back := 1.0 + (c1 + 1.0) * pow(p - 1.0, 3.0) + c1 * pow(p - 1.0, 2.0)
	var idle := smoothstep(2.2, 3.5, _rv)
	logo.modulate.a = clampf((_rv - 1.2) / 0.45, 0.0, 1.0)
	logo.scale = Vector2.ONE * (0.72 + 0.28 * back)
	logo.rotation = sin(_t * 0.9) * 0.01 * idle
	logo.position.y = logo_y + sin(_t * TAU / 5.0) * 4.0 * idle
	if not logo_frames.is_empty():
		logo.texture = logo_main if p >= 1.0 else logo_frames[mini(int(p * logo_frames.size()), logo_frames.size() - 1)]
	if logo_shadow:
		logo_shadow.modulate.a = logo.modulate.a * 0.55
		logo_shadow.scale = logo.scale
		logo_shadow.position.y = logo.position.y + 6.0 - (logo_shadow.size.y - logo.size.y) * 0.5
	if logo_glow:
		var bloom := exp(-pow((_rv - 1.7) / 0.5, 2.0))
		logo_glow.modulate.a = logo.modulate.a * (0.22 + 0.5 * bloom)
		logo_glow.scale = logo.scale
		logo_glow.rotation = logo.rotation
		logo_glow.position.y = logo.position.y - (logo_glow.size.y - logo.size.y) * 0.5
	tagline.modulate.a = smoothstep(2.0, 2.8, _rv)
	tagline.position.y = logo.position.y + logo.size.y * TAGLINE_AT
	var breathe := 0.5 + 0.5 * sin(_t * TAU / 2.6)
	tap_label.modulate.a = smoothstep(2.4, 3.0, _rv) * (0.62 + 0.38 * breathe)
	row.modulate.a = smoothstep(2.8, 3.4, _rv)
	fx_back.t = _t
	fx_front.t = _t
	fx_back.shafts = smoothstep(0.6, 2.8, _rv)
	fx_front.motes = smoothstep(2.0, 4.0, _rv)
	var u := frame.size.x / 360.0
	var hs: Array = []
	for l in lamp.find_children("*", "MeshInstance3D", true, false):
		if (l as MeshInstance3D).mesh is SphereMesh:
			hs.append([_proj((l as Node3D).global_position), 16.0 * u, 0.32])
	for l in far_lights:
		hs.append([_proj(l.global_position), 5.0 * u, 0.3])
	fx_front.halos = hs
	fx_front.avoid = cat_rect


## 息（ゆっくりふくらむ）、まばたき、6 秒ほどごとに耳がぴくっ
func _animate_cat(delta: float) -> void:
	var br := sin(_t * TAU / 3.8)
	cat.body.scale = Vector3(1.0 - br * 0.006, 1.0 + br * 0.014, 1.0 - br * 0.006)
	cat.body.position.y = br * 0.004
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink = Obake3D.BLINK_TIME
		_blink_in = randf_range(2.6, 5.0)
	var k := 0.0
	if _blink > 0.0:
		_blink -= delta
		k = sin((1.0 - maxf(_blink, 0.0) / Obake3D.BLINK_TIME) * PI)
	for e in cat.eyes:
		e.scale.y = lerpf(Obake3D.EYE_SCALE.y, 0.1, k)
	if cat_mat == null:
		return
	_twitch_in -= delta
	if _twitch_in <= 0.0:
		_twitch = 0.0
		_twitch_in = randf_range(5.2, 6.8)
		_twitch_side = -_twitch_side
	var a := 0.0
	if _twitch >= 0.0:
		_twitch += delta
		# ぴくっ、ぴく（2 回、だんだん小さく）
		var p := _twitch / 0.42
		if p >= 1.0:
			_twitch = -1.0
		else:
			a = sin(p * TAU) * (1.0 - p) * 0.32
	if _twitch_hold:
		a = 0.32
	var tw := Vector2(a, 0.0) if _twitch_side < 0 else Vector2(0.0, a)
	cat_mat.set_shader_parameter("ear_twitch", tw)
	if cat_mat.next_pass:
		(cat_mat.next_pass as ShaderMaterial).set_shader_parameter("ear_twitch", tw)


## 確認用：耳がぴくっとした瞬間で止める（OBAKE_SHOT=wait2,call:demo_twitch）
func demo_twitch() -> void:
	_twitch_hold = true
