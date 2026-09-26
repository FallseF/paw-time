extends SceneTree
## 診断カードの軸の割合が、実際の答えの割合（3問中いくつ）になっていること。
## godot --headless --path . -s tests/test_quiz_axes.gd
func _initialize():
	var fails := 0
	var cases := {"ABBAABBAABBA": [1.0, 0.0, 0.0, 1.0], "AAABBBAAABBB": [2.0 / 3, 1.0 / 3, 2.0 / 3, 1.0 / 3]}
	for a in cases:
		var r = QuizData.score(a)
		for i in 4:
			if absf(r.axes[i] - cases[a][i]) > 0.01:
				fails += 1
				print("MISMATCH ", a, " axis ", i, " got ", r.axes[i], " want ", cases[a][i])
		# 古い保存（縮めた値）でも、カードは答えから出し直す
		var old := {"type_id": r.type_id, "answers": a, "axes": [0.92, 0.92, 0.92, 0.92]}
		var fixed: Array = QuizCard.axes_of(old)
		for i in 4:
			if absf(fixed[i] - cases[a][i]) > 0.01:
				fails += 1
				print("OLD SAVE MISMATCH ", a, " axis ", i, " got ", fixed[i])
	print("PASS" if fails == 0 else "FAIL")
	quit(0 if fails == 0 else 1)
