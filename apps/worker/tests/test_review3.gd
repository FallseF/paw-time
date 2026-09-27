extends SceneTree
## ユーザーレビュー3の決まりごと：
##   OBAKE_NOSAVE=1 godot --headless --path . -s tests/test_review3.gd
## 1. 働く条件の画面：まん中（ボタンの上）を指でなぞってもスクロールする。なぞっただけではボタンは押されない
## 2. 重なるシフトは受けられない（同じ町の時刻で重なるものだけ）
## 3. 地域は複数えらべる（どれかに合えばよい）。古い保存（area ひとつ）もそのまま読める
## 4. 呼び名：「おばねこ」「Obaneko」にそろえる。「相棒」「cat-obake」「おばけ猫」は画面の文字に残さない

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _run() -> void:
	TranslationServer.set_locale("en")
	if OS.get_environment("OBAKE_NOSAVE") == "":
		print("run with OBAKE_NOSAVE=1")
		quit(2)
		return
	await _scroll()
	_overlap()
	_areas()
	_naming()
	_openings()
	_lang()
	print("REVIEW3 TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)


# ---------------------------------------------------------------- 1. なぞってスクロール

func _mouse(at: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(e, true)


func _move(from: Vector2, to: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = to
	e.global_position = to
	e.relative = to - from
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(e, true)


## from から to へ、指でなぞる（数フレームかけて）
func _drag(from: Vector2, to: Vector2) -> void:
	_mouse(from, true)
	await process_frame
	var last := from
	for i in range(1, 9):
		var p := from.lerp(to, i / 8.0)
		_move(last, p)
		last = p
		await process_frame
	_mouse(to, false)
	await process_frame


func _scroll() -> void:
	# 指で触る端末と同じにする（ヘッドレスでは、マウスから指の入力を作る設定で）
	Input.emulate_touch_from_mouse = true
	var s: Control = load("res://scripts/screen_job_prefs.gd").new()
	root.add_child(s)
	await process_frame
	await process_frame
	var sc: ScrollContainer = s.scroll
	# まん中あたりの、押せるもの（週のマス）の上から上へなぞる
	var cell: Button = s.cells["2:day"]
	var at := cell.get_global_rect().get_center()
	_check(at.y > 100 and at.y < 500, "a week cell is in the middle of the screen (%s)" % at)
	var was: Array = s.prefs.slots.duplicate()
	await _drag(at, at - Vector2(0, 220))
	_check(sc.scroll_vertical > 100, "dragging in the middle scrolls (scroll %d)" % sc.scroll_vertical)
	_check(s.prefs.slots == was, "dragging over a cell does not toggle it")
	# なぞらずに押せば、今までどおりボタンが効く
	var chip: Button = s.pay_chips["daily"]
	var c := chip.get_global_rect().get_center()
	_mouse(c, true)
	await process_frame
	_mouse(c, false)
	await process_frame
	_check(s.prefs.pay == "daily", "a plain tap still presses the chip (pay %s)" % s.prefs.pay)
	# 地域のチップは押すたびに入れる／外す（いくつでも）。入力欄は「、」「,」で区切る
	var ids: Array = JobPrefs.areas().slice(0, 3)
	for a in ids:
		s._toggle_area(a)
	s._toggle_area(ids[1])
	s.area_edit.text = "Bernal Heights、 %s ,," % JobPrefs.area_label("shibuya")
	_check(s._area_values() == [ids[0], ids[2], "Bernal Heights", "shibuya"], "area chips toggle and free text splits %s" % [s._area_values()])
	_check(s.area_chips[ids[0]].get_theme_stylebox("normal").bg_color == s.LILAC and s.area_chips[ids[1]].get_theme_stylebox("normal").bg_color != s.LILAC, "chip on/off looks")
	s.queue_free()
	await process_frame
	Input.emulate_touch_from_mouse = false


# ---------------------------------------------------------------- 2. 重なるシフト

func _overlap() -> void:
	Shifts.reset()
	var t0 := 1790000000.0
	var a := {"id": "a", "title": "Hall", "store": "Cafe", "start": t0, "end": t0 + 4 * 3600, "tz": JobListings.TZ_JP}
	Shifts.add(a)
	var inside := {"id": "b", "start": t0 + 3600, "end": t0 + 2 * 3600, "tz": JobListings.TZ_JP}
	var tail := {"id": "c", "start": t0 + 3 * 3600, "end": t0 + 6 * 3600, "tz": JobListings.TZ_JP}
	var after := {"id": "d", "start": t0 + 4 * 3600, "end": t0 + 6 * 3600, "tz": JobListings.TZ_JP}
	var other_town := {"id": "e", "start": t0 + 3600, "end": t0 + 2 * 3600, "tz": JobListings.TZ_SF}
	var old_save := {"id": "f", "start": t0 - 3600, "end": t0 + 60} # tz の無い古い保存＝日本時間
	_check(Shifts.overlapping(inside).get("id", "") == "a", "a shift inside another overlaps")
	_check(Shifts.overlapping(tail).get("id", "") == "a", "a shift that starts before the other ends overlaps")
	_check(Shifts.overlapping(after).is_empty(), "back-to-back shifts do not overlap")
	_check(Shifts.overlapping(other_town).is_empty(), "only shifts in the same town (tz) are compared")
	_check(Shifts.overlapping(old_save).get("id", "") == "a", "old saves without tz count as Japan time")
	_check(Shifts.overlapping(a).is_empty(), "a shift does not overlap itself")
	Shifts.reset()


# ---------------------------------------------------------------- 3. 地域をいくつも

func _areas() -> void:
	# 古い保存（area ひとつ）は、そのまま一つえらんだ形で読める
	var old := JobPrefs.normalize({"area": "shibuya", "days": [1]})
	_check(old.get("areas", []) == ["shibuya"] and old.area == "shibuya", "old save: area -> areas %s" % [old.get("areas")])
	_check(JobPrefs.normalize({"area": ""}).get("areas", null) == [], "no area -> no areas")
	var was := JobPrefs.path
	JobPrefs.path = "user://test_review3_prefs.json"
	var f := FileAccess.open(JobPrefs.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"area": "中野", "days": [1, 3], "windows": ["day"], "min_wage": 1100, "pay": "any"}))
	f.close()
	var loaded := JobPrefs.load_prefs()
	_check(loaded.get("areas", []) == ["中野"] and loaded.area == "中野", "old prefs file loads as one area %s" % [loaded.get("areas")])
	DirAccess.remove_absolute(ProjectSettings.globalize_path(JobPrefs.path))
	JobPrefs.path = was
	# いくつも：重なりと空は落とす。area は先頭（ほかの係の読み方はそのまま）
	var many := JobPrefs.normalize({"areas": ["shibuya", " umeda ", "shibuya", "", "中野"]})
	_check(many.areas == ["shibuya", "umeda", "中野"] and many.area == "shibuya", "areas normalized %s" % [many.areas])
	# 日本：どの仕事も、えらんだ地域のどれか。いくつかの seed で、どの地域も出てくる
	TranslationServer.set_locale("ja")
	var base := 1790000000.0
	var seen := {}
	for n in 30:
		for j in JobListings.generate({"areas": ["shibuya", "umeda", "中野"], "days": [], "windows": [], "min_wage": 1000, "pay": "any"}, 4, n * 7 + 1, base):
			_check(j.area in ["shibuya", "umeda", "中野"], "jp job area is one of the chosen (%s)" % j.area)
			seen[j.area] = true
	_check(seen.size() == 3, "every chosen jp area shows up %s" % [seen.keys()])
	# SF：えらんだ地区のどれかの店が先に
	TranslationServer.set_locale("en")
	var sf := JobListings.generate({"areas": ["dogpatch", "bayview"], "days": [], "windows": [], "min_wage_usd": 20.0, "pay": "any"}, 4, 3, base)
	_check(sf.size() == 4 and sf.all(func(j): return j.area in ["dogpatch", "bayview"]), "sf: chosen neighborhoods first %s" % [sf.map(func(j): return j.area)])
	var sf2 := JobListings.generate({"areas": ["mission", "soma"], "days": [], "windows": [], "min_wage_usd": 20.0, "pay": "any"}, 4, 5, base)
	_check(sf2.all(func(j): return j.area in ["mission", "soma"]), "sf: all jobs from either chosen neighborhood when there are enough %s" % [sf2.map(func(j): return j.area)])


# ---------------------------------------------------------------- 4. 呼び名

## strings.csv の行（[key, en, ja]）
static func csv_rows(path := "res://i18n/strings.csv") -> Array:
	var f := FileAccess.open(path, FileAccess.READ)
	var out: Array = []
	if f == null:
		return out
	f.get_csv_line() # 見出し
	while not f.eof_reached():
		var r := f.get_csv_line()
		if r.size() >= 3 and r[0] != "":
			out.append(r)
	return out


const OLD_NAMES_EN := ["cat-obake", "obake cat", "cat obake", "my cat obake"]
const OLD_NAMES_JA := ["おばけ猫", "猫おばけ", "ねこおばけ", "おばネコ", "相棒", "あいぼう"]


func _naming() -> void:
	var rows := csv_rows()
	_check(rows.size() > 1000, "strings.csv read (%d rows)" % rows.size())
	for r in rows:
		for w in OLD_NAMES_EN:
			_check(not String(r[1]).to_lower().contains(w), "old name '%s' in en of %s: %s" % [w, r[0].left(30), r[1].left(60)])
		for w in OLD_NAMES_JA:
			_check(not String(r[2]).contains(w), "old name '%s' in ja of %s: %s" % [w, r[0].left(30), r[2].left(60)])
	# 画面に出る呼び名
	TranslationServer.set_locale("ja")
	_check(tr("QUIZ_UI_YOURS").contains("おばねこ") and tr("ONB_NAME_TITLE").contains("パートナー"), "ja: おばねこ / パートナー")
	_check(tr("ONB_SPECIAL_PET") == "はじめまして！", "ja: quiz result says はじめまして！")
	TranslationServer.set_locale("en")
	_check(tr("QUIZ_UI_YOURS").contains("Obaneko") and tr("ONB_NAME_TITLE").contains("partner"), "en: Obaneko / partner")
	_check(tr("ONB_SPECIAL_PET") == "Nice to meet you!", "en: quiz result says Nice to meet you!")


# ---------------------------------------------------------------- 5. お店の島の、いまの募集

func _openings() -> void:
	var base := 1790000000.0
	for lang in ["en", "ja"]:
		TranslationServer.set_locale(lang)
		var a := JobListings.shop_openings("cafe_komorebi", 3, 11, base)
		var b := JobListings.shop_openings("cafe_komorebi", 3, 11, base)
		_check(a.size() == 3 and a.map(func(j): return j.id) == b.map(func(j): return j.id), "%s: 3 openings, same seed same list" % lang)
		for j in a:
			_check(j.listing == "cafe_komorebi" and float(j.start) > base and j.currency == JobListings.currency_of_region(), "%s: opening is this shop, in the future, in the current town's money %s" % [lang, j])
		_check(a[0].start <= a[1].start and a[1].start <= a[2].start, "%s: sorted by start" % lang)
	TranslationServer.set_locale("en")
	_check(JobListings.shop_openings("nope", 3, 1, base).is_empty(), "unknown shop has no openings")


# ---------------------------------------------------------------- 6. 言語：画面の字は strings.csv を通す。英語の見本（SF）の名前が日本語の画面に残らない

## 英語と日本語が同じでよい行（記号・数字の形・ブランドなど）
const SAME_OK := ["JOB_COUNT", "QUIZ_UI_QNUM", "SHIFT_FORM_DATE", "OK", "PR_REWARD_POI", "CHAT_CONSENT_OK", "R2_DAY", "TELEMETRY_NOTICE_OK"]


func _lang() -> void:
	var jp := RegEx.create_from_string("[\\x{3040}-\\x{30ff}\\x{4e00}-\\x{9fff}]")
	var latin := RegEx.create_from_string("[A-Za-z]{3,}")
	for r in csv_rows():
		_check(String(r[1]).strip_edges() != "" and String(r[2]).strip_edges() != "", "empty en or ja: %s" % r[0])
		_check(r[1] != r[2] or r[0] in SAME_OK, "ja is the same as en (not translated?): %s = %s" % [r[0].left(30), r[1].left(40)])
		# 日本語の欄には、かな・漢字が入っている（英語のままになっていない）
		if latin.search(r[2]) and not r[0] in SAME_OK:
			_check(jp.search(r[2]) != null, "ja looks English: %s = %s" % [r[0].left(30), r[2].left(40)])
	# 英語で受けた見本のシフトは、日本語の画面では日本語の名前で出る（保存はそのまま）
	TranslationServer.set_locale("en")
	Shifts.reset()
	var st := 1790000000.0
	var j := JobListings.localize(JobListings.demo_pay({"id": "lang1", "listing": "cafe_komorebi", "role": "hall", "area": "soma", "start": st, "end": st + 3600, "pay": "weekly", "line_n": 1}, "sf"))
	Shifts.add(JobListings.as_shift(j))
	_check(Shifts.all()[0].store == "Sunlit Pages Bookstore Café", "en store name")
	TranslationServer.set_locale("ja")
	var sj: Dictionary = Shifts.all()[0]
	_check(sj.store == I18n.t("JOB_STORE_CAFE_KOMOREBI") and jp.search(sj.store) != null and jp.search(sj.title) != null, "ja shows the shift in Japanese: %s / %s" % [sj.store, sj.title])
	_check(Shifts.current(st + 60).store == sj.store and Shifts.upcoming(st - 60)[0].store == sj.store, "current/upcoming are localized too")
	TranslationServer.set_locale("en")
	Shifts.reset()
