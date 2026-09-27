extends SceneTree
## マイおばけ猫 診断の決まりごとを確かめる（画面は要らない）。
##   godot --headless --path . -s tests/test_quiz.gd
## 1. 16 タイプ全部に、たどり着く答えがある  2. 各タイプの中身がそろっている（相性の相手は相互）
## 3. 見た目の持ち物・しぐさが MyObake3D にある
## 4. i18n/strings.csv の QUIZ_… キーが en・ja の両方にあり、その文字が Zen Maru Gothic に全部ある（日本語は 1 行 20 字以内）
## 5. QuizResult の保存 → 読み込みで戻る

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _run() -> void:
	TranslationServer.set_locale("en")
	# 1. 答え → タイプ（全 4096 通りを回し、16 タイプが全部出るか）
	var seen := {}
	for bits in 4096:
		var s := ""
		for i in 12:
			s += "A" if (bits >> i) & 1 == 0 else "B"
		seen[QuizData.score(s).type_id] = true
	_check(seen.size() == 16, "reachable types %d" % seen.size())
	for id in QuizData.TYPES:
		var r := QuizData.score(QuizData.answers_for(id))
		_check(r.type_id == id, "answers_for(%s) -> %s" % [id, r.type_id])
		_check(r.axes.size() == 4, "axes size")

	# 2. タイプの中身
	var accs := {}
	for id in QuizData.TYPES:
		var t: Dictionary = QuizData.TYPES[id]
		for k in ["job", "match", "look"]:
			_check(t.has(k), "%s missing %s" % [id, k])
		_check(QuizData.JOBS.has(t.job), "%s job %s" % [id, t.job])
		_check(QuizData.TYPES.has(t.match) and QuizData.TYPES[t.match].match == id, "%s match not mutual" % id)
		# 3. 見た目
		_check(MyObake3D.ACCESSORIES.has(t.look.accessory), "%s accessory %s" % [id, t.look.accessory])
		_check(MyObake3D.MOTIONS.has(t.look.motion), "%s motion %s" % [id, t.look.motion])
		accs[t.look.accessory] = true
		var ob := MyObake3D.new().setup_look(t.look)
		_check(ob.acc.get_child_count() > 0, "%s accessory built nothing" % id)
		ob.free()
	_check(accs.size() == 16, "accessories should be unique per type (%d)" % accs.size())

	# 4. 文字：コードが使うキーを全部集め、両方の言語で訳があるか・フォントに字があるかを見る
	var keys: Array = ["QUIZ_UI_KICKER", "QUIZ_UI_TITLE", "QUIZ_UI_SUB", "QUIZ_UI_START", "QUIZ_UI_NOTE", "QUIZ_UI_QNUM",
		"QUIZ_UI_BACK", "QUIZ_UI_YOURS", "QUIZ_UI_JOB", "QUIZ_UI_MATCH", "QUIZ_UI_BEGIN", "QUIZ_UI_SHARE", "QUIZ_UI_SHARE_TITLE",
		"QUIZ_UI_SAVE", "QUIZ_UI_COPY", "QUIZ_UI_MAKING", "QUIZ_UI_READY", "QUIZ_UI_COPIED", "QUIZ_UI_DOWNLOADED",
		"QUIZ_UI_SAVED", "QUIZ_UI_SAVE_FAILED", "QUIZ_UI_CLOSE", "QUIZ_CARD_KICKER", "QUIZ_CARD_JOB", "QUIZ_CARD_MINE", "QUIZ_SHARE_TEXT"]
	var short_ja: Array = [] # 画面に 1 行で出す日本語（20 字以内）
	for i in QuizData.QUESTIONS.size():
		for part in ["", "_A", "_B"]:
			keys.append("QUIZ_Q%d%s" % [i + 1, part])
			short_ja.append("QUIZ_Q%d%s" % [i + 1, part])
	for i in QuizData.AXES.size():
		keys.append_array(["QUIZ_AX%d_A" % i, "QUIZ_AX%d_B" % i])
	for j in QuizData.JOBS:
		keys.append("QUIZ_JOB_" + j.to_upper())
	for id in QuizData.TYPES:
		keys.append_array(["QUIZ_T_%s_NAME" % id, "QUIZ_T_%s_LINE" % id])
		short_ja.append("QUIZ_T_%s_LINE" % id)
	var fonts: Array[FontFile] = [load("res://assets/fonts/ZenMaruGothic-Bold.ttf"), load("res://assets/fonts/ZenMaruGothic-Black.ttf")]
	for loc in QuizData.LOCALES:
		TranslationServer.set_locale(loc)
		var texts: Array = ["Paw Time", "0123456789%", QuizData.SITE_URL]
		for k in keys:
			var v := QuizData.t(k)
			_check(v != k and v != "", "[%s] no translation for %s" % [loc, k])
			texts.append(v)
			if loc == "ja" and k in short_ja:
				_check(v.length() <= 20, "[ja] too long %s (%d)" % [k, v.length()])
		for id in QuizData.TYPES:
			texts.append(QuizData.share_text(id))
		for font in fonts:
			var missing := {}
			for s: String in texts:
				for i in s.length():
					var c := s.unicode_at(i)
					if c > 32 and not font.has_char(c):
						missing[s[i]] = true
			_check(missing.is_empty(), "[%s] %s lacks: %s" % [loc, font.resource_path.get_file(), "".join(missing.keys())])
	# 既定は英語
	_check(ProjectSettings.get_setting("internationalization/locale/fallback") == "en", "fallback locale should be en")
	TranslationServer.set_locale("en")
	_check(QuizData.share_text("OPHK").begins_with("My Obaneko is") or OS.get_environment("OBAKE_LANG") != "", "share text in English")
	_check(QuizData.share_text("OPHK").contains(QuizData.SITE_URL), "share text has the URL")

	# 5. 保存と読み込み（本物の結果には触れない）
	QuizResult.path = "user://my_obake_test.json"
	QuizResult.clear()
	_check(QuizResult.load_result().is_empty(), "empty before save")
	var r := QuizData.score(QuizData.answers_for("IPMK"))
	_check(QuizResult.save(r), "save")
	var back := QuizResult.load_result()
	_check(back.get("type_id") == "IPMK" and back.get("answers") == r.answers, "roundtrip %s" % back)
	_check(back.look.accessory == "headband", "look restored")
	var f := FileAccess.open(QuizResult.path, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	_check(QuizResult.load_result().is_empty(), "broken file ignored")
	QuizResult.clear()
	QuizResult.path = QuizResult.PATH

	print("test_quiz: %s (%d failures)" % ["OK" if fails == 0 else "NG", fails])
	quit(1 if fails else 0)
