class_name QuizCard
## シェア用の結果カード（1080x1350 の PNG）。SubViewport に 2D のカードと 3D のマイおばけ猫を組んで撮る。
## 使い方: var img: Image = await QuizCard.render(self, result)
##        QuizCard.deliver(img, type_id) … web ならダウンロード、デスクトップなら user:// に保存（戻り値は案内文）

const W := 1080
const H := 1350
const INK := Color("2a2233")
const SUB := Color("6a5f70")
const CREAM := Color("fbf3ea")


static func render(host: Node, result: Dictionary) -> Image:
	QuizData.setup_i18n()
	var type_id: String = result.type_id
	var t: Dictionary = QuizData.TYPES[type_id]
	var col := QuizData.tone(type_id)
	var black: FontFile = load("res://assets/fonts/ZenMaruGothic-Black.ttf")
	var bold: FontFile = load("res://assets/fonts/ZenMaruGothic-Bold.ttf")

	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	host.add_child(vp)

	var bg := ColorRect.new()
	bg.color = CREAM
	bg.size = Vector2(W, H)
	vp.add_child(bg)

	# ロゴ
	var logo := _label("Paw Time", black, 64, INK)
	logo.position = Vector2(0, 52)
	logo.size = Vector2(W, 80)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vp.add_child(logo)
	var kicker := _label(QuizData.t("QUIZ_CARD_KICKER"), bold, 32, col.darkened(0.45))
	kicker.position = Vector2(0, 136)
	kicker.size = Vector2(W, 44)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vp.add_child(kicker)

	# おばけの舞台（色付きの角丸）
	var stage := Panel.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = col.lightened(0.62)
	ss.set_corner_radius_all(64)
	stage.add_theme_stylebox_override("panel", ss)
	stage.position = Vector2(90, 206)
	stage.size = Vector2(900, 560)
	vp.add_child(stage)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.position = stage.position
	box.size = stage.size
	vp.add_child(box)
	var vp3 := SubViewport.new()
	vp3.own_world_3d = true
	vp3.transparent_bg = true
	vp3.msaa_3d = Viewport.MSAA_4X
	vp3.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	box.add_child(vp3)
	var ob := _stage3d(vp3, t.look)
	# 舞台の中の小さなタグ（向いてる仕事）
	var job := _chip(QuizData.t("QUIZ_CARD_JOB") % QuizData.job_name(t.job), bold, 30, Color.WHITE, col.darkened(0.35))
	job.position = Vector2(126, 238)
	vp.add_child(job)

	# タイプ名と一言。英語の長い名前は幅に合わせて文字を小さくする。
	var pre := _label(QuizData.t("QUIZ_CARD_MINE"), bold, 34, SUB)
	pre.position = Vector2(0, 790)
	pre.size = Vector2(W, 48)
	pre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vp.add_child(pre)
	var name_text := QuizData.type_name(type_id)
	var name_l := _label(name_text, black, QuizData.fit_size(black, name_text, W - 120, 84, 52), INK)
	name_l.position = Vector2(0, 836)
	name_l.size = Vector2(W, 112)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vp.add_child(name_l)
	# 日本語のときだけ、英語の名前を小見出しに添える（英語のときは一言を少し上げる）
	var line_y := 962
	if QuizData.is_ja():
		var en := _label(QuizData.type_name_en(type_id), bold, 30, col.darkened(0.4))
		en.position = Vector2(0, 946)
		en.size = Vector2(W, 42)
		en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vp.add_child(en)
		line_y = 1000
	var line_text := QuizData.type_line(type_id)
	var line := _label(line_text, bold, QuizData.fit_size(bold, line_text, W - 120, 42, 30), INK)
	line.position = Vector2(0, line_y)
	line.size = Vector2(W, 60)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vp.add_child(line)

	# 4 つの軸（2 列 × 2 段）
	var axes: Array = result.get("axes", [0.5, 0.5, 0.5, 0.5])
	for i in 4:
		var bar := _axis_bar(i, axes[i], col, bold, 30, Vector2(420, 18))
		bar.position = Vector2(90 + (i % 2) * 480, 1086 + (i / 2) * 78)
		vp.add_child(bar)

	# フッター
	var url := _label(QuizData.SITE_URL.replace("https://", ""), bold, 28, SUB)
	url.position = Vector2(0, 1262)
	url.size = Vector2(W, 40)
	url.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vp.add_child(url)

	# 3D と文字が描かれるまで数フレーム待つ
	for i in 4:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	ob.queue_free()
	vp.queue_free()
	return img


## 3D の舞台（光・カメラ・おばけ・足元の影）を組む
static func _stage3d(vp3: SubViewport, look: Dictionary) -> MyObake3D:
	var world := Node3D.new()
	vp3.add_child(world)
	# 図鑑カードと同じ明るいスタジオの光（Look）。背景は透明にして、カードの色の舞台を透かす。
	Look.apply(world, "studio", Color(0, 0, 0, 0), true)
	var cam := Camera3D.new()
	cam.fov = 29
	cam.position = Vector3(0, 0.95, 3.4)
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.64, 0))
	var ob := MyObake3D.new().setup_look(look)
	ob.rotation.y = 0.35
	world.add_child(ob)
	ob.hold_still()
	return ob


static func _label(text: String, font: FontFile, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func _chip(text: String, font: FontFile, size: int, bg: Color, fg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(40)
	s.content_margin_left = 26
	s.content_margin_right = 26
	s.content_margin_top = 8
	s.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", s)
	p.add_child(_label(text, font, size, fg))
	return p


## 軸の棒。上に「外へ ◯◯% / 内へ」、下に 2 色の棒。reveal 画面でも使うので寸法を渡せるようにする。
static func _axis_bar(axis: int, ratio: float, col: Color, font: FontFile, size: int, bar_size: Vector2) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", int(size * 0.2))
	var row := HBoxContainer.new()
	var lean_a := ratio >= 0.5
	var la := _label(QuizData.axis_label(axis, "A"), font, size, INK if lean_a else SUB.lightened(0.3))
	var lb := _label(QuizData.axis_label(axis, "B"), font, size, INK if not lean_a else SUB.lightened(0.3))
	var pct := _label("%d%%" % roundi((ratio if lean_a else 1.0 - ratio) * 100), font, size, col.darkened(0.35))
	pct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(la)
	row.add_child(pct)
	row.add_child(lb)
	row.custom_minimum_size.x = bar_size.x
	v.add_child(row)
	var track := Panel.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = Color(0.16, 0.13, 0.2, 0.1)
	ts.set_corner_radius_all(int(bar_size.y / 2))
	track.add_theme_stylebox_override("panel", ts)
	track.custom_minimum_size = bar_size
	v.add_child(track)
	var fill := Panel.new()
	var fs := StyleBoxFlat.new()
	fs.bg_color = col.darkened(0.15)
	fs.set_corner_radius_all(int(bar_size.y / 2))
	fill.add_theme_stylebox_override("panel", fs)
	# 前の極は左から、後ろの極は右から伸ばす
	var w := bar_size.x * (ratio if lean_a else 1.0 - ratio)
	fill.size = Vector2(w, bar_size.y)
	fill.position = Vector2(0.0 if lean_a else bar_size.x - w, 0)
	track.add_child(fill)
	return v


## 画像を手元に届ける。web はダウンロード、それ以外は user:// に保存。戻り値は画面に出す案内文。
static func deliver(img: Image, type_id: String) -> String:
	var file := "paw_time_my_obake_%s_%s.png" % [type_id, TranslationServer.get_locale().left(2)]
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(img.save_png_to_buffer(), file, "image/png")
		return QuizData.t("QUIZ_UI_DOWNLOADED")
	var path := "user://" + file
	var err := img.save_png(path)
	if err != OK:
		return QuizData.t("QUIZ_UI_SAVE_FAILED") % error_string(err)
	return QuizData.t("QUIZ_UI_SAVED") % ProjectSettings.globalize_path(path)
