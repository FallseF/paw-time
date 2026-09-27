extends SceneTree
## 眠りの仕組みはやめた（働きすぎを止めるのは、猫が疲れることだけ）。画面に出る文字に、眠り・夢が残っていないか確かめる。
##   1. i18n/strings.csv の英語・日本語（意図して残すものは ALLOW に）
##   2. scripts/*.gd の文字列（コメント以外）の日本語
##   3. 眠りの画面・夢の画面・スヤリ・眠りの条件のレア／服が無い
## godot --headless --path . -s tests/test_no_sleep.gd

## 意図して残す行（キー）
const ALLOW := []
## 意図して残す、スクリプトの中の文字列：相棒とのチャットで、働く人が打つかもしれない言葉（聞き取るための言葉。画面には出ない）
const ALLOW_LITERALS := ["\"眠い\"", "\"ねむい\""]
const EN_WORDS := ["sleep", "slept", "dream", "bedtime", "nap ", "asleep", "good night"]
const JA_WORDS := ["眠", "寝", "夢", "おやすみ", "ねむ"]

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _run() -> void:
	# 1. 翻訳の表
	var f := FileAccess.open("res://i18n/strings.csv", FileAccess.READ)
	f.get_csv_line()
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 3 or row[0] in ALLOW:
			continue
		var en := row[1].to_lower()
		for w in EN_WORDS:
			_check(not en.contains(w), "en mentions '%s': %s = %s" % [w, row[0], row[1]])
		for w in JA_WORDS:
			_check(not row[2].contains(w), "ja mentions '%s': %s = %s" % [w, row[0], row[2]])
	# 2. スクリプトの中の文字列（コメントの行は見ない）
	var re := RegEx.new()
	re.compile("\"([^\"\\\\]|\\\\.)*\"")
	for file in DirAccess.get_files_at("res://scripts/"):
		if not file.ends_with(".gd"):
			continue
		var lines := FileAccess.get_file_as_string("res://scripts/" + file).split("\n")
		for i in lines.size():
			var ln := lines[i].strip_edges()
			if ln.begins_with("#"):
				continue
			var code := ln.split(" # ")[0]
			for m in re.search_all(code):
				var lit := m.get_string()
				if lit in ALLOW_LITERALS:
					continue
				for w in JA_WORDS:
					_check(not lit.contains(w), "%s:%d says %s" % [file, i + 1, lit])
	# 3. 仕組みそのもの
	_check(not ResourceLoader.exists("res://scripts/screen_sleep.gd") and not ResourceLoader.exists("res://scripts/screen_dream.gd"), "no sleep/dream screens")
	var gs = root.get_node("GameState")
	_check(not gs.NORMAL.has("nemuri") and not gs.SPECIES.has("nemuri"), "no dream obake")
	_check(not gs.has_method("sleep") and gs.has_method("end_night"), "night ends without a sleep input")
	for w in WardrobeData.ITEMS:
		_check(not String(w.src).begins_with("sleep"), "outfit %s unlocks from sleep" % w.id)
	var ctx: Dictionary = gs.rare_context(gs.today())
	for k in ctx:
		_check(not String(k).contains("sleep") and not String(k).contains("bed"), "rare condition uses %s" % k)
	print("NO SLEEP TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
