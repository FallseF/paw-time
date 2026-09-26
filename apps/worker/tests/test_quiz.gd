extends SceneTree
## マイおばけ猫 診断の決まりごとを確かめる（画面は要らない）。
##   godot --headless --path . -s tests/test_quiz.gd
## 1. 16 タイプ全部に、たどり着く答えがある  2. 各タイプの中身がそろっている（相性の相手は相互）
## 3. 見た目の持ち物・しぐさが MyObake3D にある  4. 画面に出す文字が Zen Maru Gothic に全部ある
## 5. QuizResult の保存 → 読み込みで戻る

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _run() -> void:
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
		for k in ["name", "line", "en_name", "en_line", "job", "match", "look"]:
			_check(t.has(k), "%s missing %s" % [id, k])
		_check(QuizData.JOBS.has(t.job), "%s job %s" % [id, t.job])
		_check(QuizData.TYPES.has(t.match) and QuizData.TYPES[t.match].match == id, "%s match not mutual" % id)
		_check(t.line.length() <= 20, "%s line too long (%d)" % [id, t.line.length()])
		# 3. 見た目
		_check(MyObake3D.ACCESSORIES.has(t.look.accessory), "%s accessory %s" % [id, t.look.accessory])
		_check(MyObake3D.MOTIONS.has(t.look.motion), "%s motion %s" % [id, t.look.motion])
		accs[t.look.accessory] = true
		var ob := MyObake3D.new().setup_look(t.look)
		_check(ob.acc.get_child_count() > 0, "%s accessory built nothing" % id)
		ob.free()
	_check(accs.size() == 16, "accessories should be unique per type (%d)" % accs.size())
	for q in QuizData.QUESTIONS:
		for k in ["q", "a", "b"]:
			_check(q[k].length() <= 20, "question too long: %s" % q[k])

	# 4. 文字（画面とカードで使う文字列を全部集めて、フォントに字があるか）
	var texts: Array = ["Paw Time", "マイおばけ猫 診断", "あなたのおばけ猫を\nさがそう", "12の質問で、相棒の猫おばけが決まる。", "バイトと休みの、ゆるい質問だよ。",
		"はじめる", "1分くらい ・ 答えはあとで変えられる", "ひとつ戻る", "Q0123456789", "あなたのマイおばけ猫は", "わたしのマイおばけ猫は",
		"向いてる仕事：", "相性のいいタイプ：", "この子と はじめる", "結果をシェア", "画像を保存", "シェア文をコピー", "カードを作っています…",
		"画像を保存して、SNSに貼ってね", "シェア文をコピーしました", "画像をダウンロードしました", "保存しました：", "保存できませんでした", "とじる", "%AB",
		QuizData.SITE_URL]
	for q in QuizData.QUESTIONS:
		texts.append_array([q.q, q.a, q.b])
	for ax in QuizData.AXES:
		texts.append_array([ax.a, ax.b, ax.a_en, ax.b_en])
	for j in QuizData.JOBS.values():
		texts.append_array([j.ja, j.en])
	for id in QuizData.TYPES:
		var t: Dictionary = QuizData.TYPES[id]
		texts.append_array([t.name, t.line, t.en_name, t.en_line, QuizData.share_text(id)])
	for f in ["Bold", "Black"]:
		var font: FontFile = load("res://assets/fonts/ZenMaruGothic-%s.ttf" % f)
		var missing := {}
		for s: String in texts:
			for i in s.length():
				var c := s.unicode_at(i)
				if c > 32 and not font.has_char(c):
					missing[s[i]] = true
		_check(missing.is_empty(), "ZenMaru %s lacks: %s" % [f, "".join(missing.keys())])

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
