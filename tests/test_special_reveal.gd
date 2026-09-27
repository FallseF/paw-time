extends Node
## 特別なレアの動画（scripts/special_reveal.gd）：
## はじめての夜の玉は 6 匹のどれか 1 匹（インストールごと。20 回の新しいインストールで散らばる・読み直しても変わらない）、
## 手に入ったことになる。孵化の画面では割れたあとに動画 → 1 秒後のタップで飛ばせる → いつものカード。2 回目は流さない。
## GameState（autoload）を使うので場面として動かす：OBAKE_NOSAVE=1 godot --headless --path . res://tests/test_special_reveal.tscn

var fails := 0


class FakeMain:
	extends Node
	var went := ""
	func go(n: String, _instant := false) -> void:
		went = n


func _ready() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _run() -> void:
	OS.set_environment("OBAKE_NOSAVE", "1")
	await get_tree().process_frame
	# 20 回の新しいインストール
	var counts := {}
	for i in 20:
		SpecialReveal.reset()
		var p := SpecialReveal.pick()
		_check(p in SpecialReveal.IDS, "install %d picks one of the 6 (%s)" % [i, p])
		_check(SpecialReveal.pick() == p, "install %d: the pick stays the same" % i)
		counts[p] = counts.get(p, 0) + 1
	print("picks over 20 installs: ", counts)
	_check(counts.size() >= 4, "20 installs spread across the 6 (got %d kinds)" % counts.size())
	for id in SpecialReveal.IDS:
		_check(SpecialReveal.has_clip(id), "%s has its frames" % id)
		_check(FileAccess.file_exists("res://assets/reveal/%s/f_%03d.jpg" % [id, SpecialReveal.FRAMES]), "%s has all %d frames" % [id, SpecialReveal.FRAMES])
	# 読み直し（ファイルに保存して、読みこみ直す）
	SpecialReveal.force_save = true
	SpecialReveal.reset(true)
	var kept := SpecialReveal.pick()
	for i in 5:
		SpecialReveal.reset()
		_check(SpecialReveal.pick() == kept, "reload keeps the pick (%s)" % kept)
	SpecialReveal.reset(true)
	SpecialReveal.force_save = false
	SpecialReveal.reset()

	# はじめての夜：すくった玉から、その子がかえる（手に入ったことになる）
	GameState.reset("solo")
	var pick := SpecialReveal.pick()
	var orb: Dictionary = Onboarding.tutorial_orbs()[0]
	_check(String(orb.content.get("special", "")) == pick, "the tutorial orb holds the picked special")
	GameState.orbs = [{"type": orb.type, "rare": orb.rare, "content": orb.content}]
	GameState.end_night()
	var h: Dictionary = GameState.hatched.filter(func(x): return x.id == pick)[0] if GameState.hatched.any(func(x): return x.id == pick) else {}
	_check(not h.is_empty() and h.is_new and h.get("special", false), "the special hatches, new (%s)" % [GameState.hatched])
	_check(GameState.seen.has(pick), "the special counts as obtained")

	# 孵化の画面：割れたあと、猫のひとこと → 動画 → タップで飛ばす → カード
	GameState.hatched = [h]
	var fm := FakeMain.new()
	add_child(fm)
	var scr = load("res://scripts/screen_hatch.gd").new()
	scr.main = fm
	scr.size = Vector2(360, 640)
	add_child(scr)
	var rv: SpecialReveal = null
	for i in 120:
		await get_tree().create_timer(0.1).timeout
		for c in scr.get_children():
			if c is SpecialReveal:
				rv = c
		if rv:
			break
	_check(rv != null, "the reveal plays after the orb cracks")
	if rv:
		await get_tree().create_timer(0.3).timeout
		_check(rv.size.is_equal_approx(scr.size) and rv.size.x > 0.0, "the reveal covers the whole screen (%s vs %s)" % [rv.size, scr.size])
		_check(rv.tex != null and rv._frame >= 1, "frames load one by one (frame %d)" % rv._frame)
		var tap := InputEventMouseButton.new()
		tap.pressed = true
		rv._gui_input(tap)
		_check(not rv._finished, "no tap-skip in the first second")
		await get_tree().create_timer(1.0).timeout
		rv._gui_input(tap)
		_check(rv._finished, "tap skips after 1 s")
		await get_tree().create_timer(1.2).timeout
		_check(not is_instance_valid(rv) or not rv.is_inside_tree(), "the reveal is freed after it fades")
		_check(scr.card.modulate.a > 0.9 and scr.card_title.text == GameState.info(pick).name, "then the usual hatch card (%s)" % scr.card_title.text)
	scr.queue_free()
	# 2 回目（もう持っている）は流さない
	GameState.hatched = [{"id": pick, "is_new": false, "level": 1, "rare": true}]
	var scr2 = load("res://scripts/screen_hatch.gd").new()
	scr2.main = fm
	add_child(scr2)
	var saw := false
	for i in 40:
		await get_tree().create_timer(0.1).timeout
		for c in scr2.get_children():
			if c is SpecialReveal:
				saw = true
	_check(not saw, "no reveal the second time")
	print("SPECIAL REVEAL TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
