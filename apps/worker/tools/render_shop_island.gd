extends SceneTree
## お店の島（screen_shop_island.gd）を、店の管理画面（apps/employer）用の静止画に撮る。背景は透明、横長の 3/4 の構図。
##   godot --path . --always-on-top --resolution 480x300 -s tools/render_shop_island.gd
## （ウィンドウが隠れると macOS が描画を止めるので --always-on-top を付ける）
## 島の組み立ては画面のスクリプトをそのまま使う（ゲームの地形・目印・トゥーンの材質・色補正と同じ）。
## 海の平面・海の底・おばネコ・看板の文字（店名は管理画面の側で出す）だけ外して、横長のカメラに差し替える。
## 環境変数: SI_OUT=/path … PNG と island.json の出力先（既定 /tmp/shop_island）。WebP は tools の外で変換する。
## 撮る段は、管理画面の見本のお店（packages/shop-console の見本の評価）で出る島と、何も無い島。

const W := 1600
const H := 1000
const SS := 2
const CAM_AT := Vector3(4.2, 9.6, 14.2)
const LOOK_AT := Vector3(0.2, 0.2, -0.2)
## ぼかしの楕円（絵の幅・高さに対する半径）と、ぼかし始める位置
const FADE_R := Vector2(0.5, 0.56)
const FADE_FROM := 0.72
const SCREEN := "res://scripts/screen_shop_island.gd"

## 管理画面の見本のお店の票（packages/shop-console の buildIsland と同じ集計）と、何も無い島
const STATES := {
	"sample": {"on_time": 46, "breaks": 4, "instructions": 11, "paid": 6, "friendly": 21, "fair": 2, "again": 9},
	"bare": {},
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_environment("SI_OUT") if OS.get_environment("SI_OUT") != "" else "/tmp/shop_island"
	DirAccess.make_dir_recursive_absolute(out)
	var manifest := {}
	for key in STATES:
		manifest[key] = await _shoot(key, STATES[key], out)
	var f := FileAccess.open(out.path_join("island.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "  "))
	f.close()
	print("wrote ", out)
	quit()


## 画面のスクリプトの _ready（評価を読み直す・画面の文字を組む）だけ空にした子。島の組み立ては画面のまま
func _screen_script() -> GDScript:
	var g := GDScript.new()
	g.source_code = 'extends "%s"\n\nfunc _ready() -> void:\n\tpass\n' % SCREEN
	g.reload()
	return g


func _shoot(key: String, tags: Dictionary, out: String) -> Dictionary:
	var scr: Control = _screen_script().new()
	var lms := ShopCulture.landmarks_from({"tags": tags, "count": 0})
	scr.shop_id = ""
	scr.prof = {"name": "", "kind": "cafe", "sign": Color("3f9e8f"), "accent": Color("fdf7ee"), "values": ""}
	scr.totals = {"tags": tags, "count": 0}
	scr.lms = lms
	scr.set_process(false)
	root.add_child(scr)
	scr.call("_build_world")
	var vp: SubViewport = scr.vp
	var world: Node3D = scr.world
	# 画面の器（View3D）から外して、決まった大きさで撮る
	vp.get_parent().remove_child(vp)
	root.add_child(vp)
	for c in scr.get_children():
		c.queue_free()
	vp.size = Vector2i(W * SS, H * SS)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var env: Environment = scr.env
	env.background_mode = Environment.BG_CLEAR_COLOR
	if scr.cat:
		scr.cat.queue_free()
		scr.cat = null
	for l in world.find_children("*", "Label3D", true, false):
		l.queue_free()
	var cam: Camera3D = scr.cam
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.v_offset = 0.0
	cam.fov = 30
	# 構図はどの段でも同じ（いちばん広い段 2 の島が収まる）。段が上がっても、島が広がって見えるように
	cam.position = Vector3(CAM_AT.x, CAM_AT.y, CAM_AT.z)
	cam.look_at(LOOK_AT)
	# 目印の「ぽん」と出る動きが終わるまで待つ
	await create_timer(2.0).timeout
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.resize(W, H, Image.INTERPOLATE_LANCZOS)
	_fade_edges(img, cam.unproject_position(Vector3(0, 0, 0.2)) / Vector2(vp.size))
	img.save_png(out.path_join("island-%s-%d.png" % [key, W]))
	var small := img.duplicate() as Image
	small.resize(W / 2, H / 2, Image.INTERPOLATE_LANCZOS)
	small.save_png(out.path_join("island-%s-%d.png" % [key, W / 2]))
	# 目印の足もとの、絵の上の位置（0〜1）。管理画面の名札の置き場所
	var pins := {}
	var size := Vector2(vp.size)
	for mk in scr.marks:
		var p: Vector2 = cam.unproject_position(_top(mk.node)) / size
		pins[String(mk.data.id)] = [snappedf(p.x, 0.001), snappedf(p.y, 0.001)]
	var sp: Vector2 = cam.unproject_position(scr.SHOP_AT + Vector3(0, 1.98, 0.25)) / size # 屋根の上の看板の板
	pins["shop"] = [snappedf(sp.x, 0.001), snappedf(sp.y, 0.001)]
	var levels := {}
	for lm in lms:
		levels[String(lm.id)] = "s" if lm.sprout else str(int(lm.level))
	vp.queue_free()
	scr.queue_free()
	await process_frame
	print("rendered ", key, " stage ", ShopCulture.stage_for(lms))
	return {"levels": levels, "pins": pins, "stage": ShopCulture.stage_for(lms)}


## 目印のてっぺん（名札はこの上に立てる）
func _top(n: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return Vector3(n.global_position.x, box.end.y + 0.05, n.global_position.z)


## 海と海の底は画面のまま撮って、島のまわりの楕円の外を透明へぼかす。外側は管理画面の背景（海の色）に溶ける
func _fade_edges(img: Image, c: Vector2) -> void:
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		var dy := (float(y) / h - c.y) / FADE_R.y
		for x in w:
			var dx := (float(x) / w - c.x) / FADE_R.x
			var d := sqrt(dx * dx + dy * dy)
			if d <= FADE_FROM:
				continue
			var px := img.get_pixel(x, y)
			px.a *= 1.0 - smoothstep(FADE_FROM, 1.0, d)
			img.set_pixel(x, y, px)
