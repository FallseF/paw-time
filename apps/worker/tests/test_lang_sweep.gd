extends Node
## 言語のまざり（レビュー3：「日本語の画面に、ときどき英語が出る」）を、本物の画面を順に開いて探す。
## 日本語の画面に英語の語（3 文字以上）が、英語の画面にかな・漢字が出ていたら FAIL（決まった固有名は除く）。
## 見るのは、画面に出ている Label / Button / RichTextLabel / LineEdit の字（自動の翻訳を通したあと）と Label3D。
## LANG_SWEEP=ja|en で片方だけ。既定は両方（同じ起動で言語を切りかえ、画面を作り直す）。
## OBAKE_NOSAVE=1 godot --headless --path . res://tests/test_lang_sweep.tscn   （--quit-after は付けない。全部の画面を回るのに 1 分ほど）

var fails := 0
var main
var seen := {} # 同じ字は一度だけ知らせる

## 日本語の画面に出てよい英字（ブランド・固有名・記号）
const JA_OK := ["Paw Time", "PawTime", "Google", ".ics", "Recruit", "English", "Lv", "OK", "Q", "SNS", "LINE", "URL", "AI", "MBTI"]
## 英語の画面に出てよい日本語（言語の切りかえ・日本の相談窓口の名前）
const EN_OK := ["日本語", "まもろうよ こころ"]


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _ready() -> void:
	for kv in [["OBAKE_NOSAVE", "1"], ["OBAKE_START", "garden"], ["OBAKE_ONBOARD", "done"], ["OBAKE_MODE", "solo"], ["OBAKE_FF", "3"], ["OBAKE_NO_REVEAL", "1"]]:
		OS.set_environment(kv[0], kv[1])
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	_run.call_deferred()


func _frames(n := 3) -> void:
	for i in n:
		await get_tree().process_frame


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


## 画面に出ている字（自動の翻訳を通したもの）
func _shown(n: Node) -> Array:
	var out: Array = []
	for c in n.find_children("*", "", true, false):
		var t := ""
		if c is Label3D:
			t = c.atr(c.text) if c.visible else ""
		elif c is Control and not c.is_visible_in_tree():
			continue
		elif c is Label or c is Button or c is RichTextLabel:
			t = c.atr(c.text) if c.auto_translate_mode != Node.AUTO_TRANSLATE_MODE_DISABLED else c.text
			if c is RichTextLabel:
				t = c.get_parsed_text()
		elif c is LineEdit:
			t = c.atr(c.placeholder_text) + " " + c.text
		if t.strip_edges() != "":
			out.append([t, c])
	return out


static func _strip(t: String, ok: Array) -> String:
	for w in ok:
		t = t.replace(w, "")
	return t


static var _latin := RegEx.create_from_string("[A-Za-z]{3,}")
static var _kana := RegEx.create_from_string("[\\x{3040}-\\x{30ff}\\x{4e00}-\\x{9fff}]")


func _scan(where: String) -> void:
	var lang := TranslationServer.get_locale().left(2)
	var extra_ok: Array = []
	if lang == "ja":
		# 診断のタイプの英語名は、日本語の画面でも小見出しとして出す（決まり）
		for id in QuizData.TYPES:
			extra_ok.append(QuizData.type_name_en(id))
	for p in _shown(main):
		var t: String = p[0]
		var bad := false
		if lang == "ja":
			bad = _latin.search(_strip(_strip(t, extra_ok), JA_OK)) != null
		else:
			bad = _kana.search(_strip(t, EN_OK)) != null
		var key: String = lang + "|" + t
		if bad and not seen.has(key):
			seen[key] = true
			_check(false, "[%s] %s: %s  (%s %s)" % [lang, where, t.replace("\n", " / ").left(90), p[1].get_class(), p[1].get_path().get_concatenated_names().right(60)])


func _go(screen: String) -> void:
	main.busy = false
	await main.go(screen, true)
	await _wait(1.4)


func _call(who: Node, m: String, args := []) -> void:
	if who and who.has_method(m):
		who.callv(m, args)
		await _wait(0.8)


func _desk() -> JobDesk:
	for c in main.current.get_children():
		if c is JobDesk:
			return c
	return null


func _run() -> void:
	await _wait(2.0)
	var langs := ["ja", "en"] if OS.get_environment("LANG_SWEEP") == "" else [OS.get_environment("LANG_SWEEP")]
	for lang in langs:
		TranslationServer.set_locale(lang)
		GameState.set_my_obake(SpecialObake.apply(QuizData.score(QuizData.answers_for("OFHK"))))
		Shifts.reset()
		JobDesk.clear_today()
		# タイトル
		await _go("title")
		_scan("title")
		# 島と、しごとの係
		await _go("garden")
		_scan("garden")
		var d := _desk()
		await _call(d, "demo_open")
		_scan("job list")
		await _call(d, "demo_detail")
		_scan("job detail")
		await _call(d, "demo_accept")
		_scan("job accepted")
		d._close_viewer()
		await _call(d, "demo_work")
		_scan("my shifts")
		if d and not Shifts.all().is_empty():
			d.open_shift_detail(Shifts.all()[0])
			await _wait(0.6)
			_scan("shift detail")
		d._close_sheet()
		await _call(d, "demo_shops")
		_scan("shops sheet")
		d._close_sheet()
		await _call(d, "demo_review")
		_scan("review")
		await _call(d, "demo_stars")
		await _call(d, "demo_send")
		_scan("review sent")
		d._close_viewer()
		await _call(d, "demo_shift_form")
		_scan("shift form")
		await _go("garden")
		d = _desk()
		d.tour_i = 0
		for i in 4:
			d._tour_step()
			await _wait(0.4)
			_scan("tour %d" % (i + 1))
		d._close_sheet()
		for m in ["demo_catalog", "demo_expand_card", "demo_share", "demo_rest"]:
			await _go("garden")
			await _call(main.current, m)
			_scan("garden " + m)
		# ほかの画面
		for s in ["prefs", "work", "wardrobe", "zukan", "skills", "settings", "moon", "night", "catch", "hatch", "practice", "chat", "quiz"]:
			await _go(s)
			_scan(s)
			if s == "chat":
				await _wait(3.0) # 返事の吹き出しが出きってから次の画面へ
		await _call(main.current, "demo_start") # quiz にはないので何もしない
		await _go("work")
		await _call(main.current, "demo_start")
		_scan("work started")
		await _call(main.current, "demo_stop")
		await _wait(1.0)
		_scan("work stopped")
		await _go("zukan")
		await _call(main.current, "demo_detail")
		_scan("zukan detail")
		await _go("prefs")
		await _call(main.current, "demo_fill")
		await _call(main.current, "demo_scroll_end")
		_scan("prefs end")
		await _go("chat")
		for m in ["demo_today", "demo_list"]:
			await _call(main.current, m)
			_scan("chat " + m)
			await _wait(3.0) # 返事の吹き出しが出きってから次へ
		GameState.visit = ShopCulture.visit_data("cafe_komorebi")
		await _go("shop_island")
		_scan("shop island")
		await _call(main.current, "demo_tap")
		_scan("shop landmark")
		await _call(main.current, "demo_jobs")
		_scan("shop jobs")
		GameState.visit = {}
		for st in ["onboard"]:
			Onboarding._step = "shift"
			await _go(st)
			_scan(st)
			await _call(main.current, "demo_start")
			await _wait(1.0)
			_scan(st + " started")
		Onboarding._step = "done"
	print("LANG SWEEP ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
