extends SceneTree
## マイおばけ猫 16 タイプのシェアカード（1080x1350）を撮り、一覧（コンタクトシート）も作る。
## 画面が要るので、ウィンドウ付きで起動する:
##   godot --path . --resolution 360x640 -s tests/render_quiz_cards.gd
## 環境変数: QUIZ_CARD_OUT=/tmp/dir … 出力先（既定は res://ui_review/quiz_cards）
##          QUIZ_CARD_IDS=OPHK,IFMY … 一部だけ撮る


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := OS.get_environment("QUIZ_CARD_OUT")
	if out == "":
		out = ProjectSettings.globalize_path("res://ui_review/quiz_cards")
	DirAccess.make_dir_recursive_absolute(out)
	var ids: Array = QuizData.TYPES.keys()
	var only := OS.get_environment("QUIZ_CARD_IDS")
	if only != "":
		ids = Array(only.split(","))
	var shots: Array[Image] = []
	for id in ids:
		var r := QuizData.score(QuizData.answers_for(id))
		assert(r.type_id == id)
		var img: Image = await QuizCard.render(root, r)
		img.save_png(out.path_join("%s.png" % id))
		shots.append(img)
		print("rendered ", id)
	if shots.size() > 1:
		_sheet(shots).save_png(out.path_join("_sheet.png"))
	quit()


## 4 列の一覧。1 枚を 1/4 に縮める（270x338）。
func _sheet(shots: Array[Image]) -> Image:
	var cw := QuizCard.W / 4
	var ch := QuizCard.H / 4
	var cols := 4
	var rows := ceili(shots.size() / float(cols))
	var gap := 12
	var sheet := Image.create(cols * cw + (cols + 1) * gap, rows * ch + (rows + 1) * gap, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("2a2233"))
	for i in shots.size():
		var s := shots[i].duplicate() as Image
		s.convert(Image.FORMAT_RGBA8)
		s.resize(cw, ch, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(s, Rect2i(0, 0, cw, ch), Vector2i(gap + (i % cols) * (cw + gap), gap + (i / cols) * (ch + gap)))
	return sheet
