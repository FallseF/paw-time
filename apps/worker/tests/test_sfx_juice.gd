extends SceneTree
## ごほうびの音の決まりごと（scripts/sfx.gd）。音は出さず、選ぶ高さ・間合い・BGM の下げ方だけを見る。
##   OBAKE_NOSAVE=1 godot --headless --path . -s tests/test_sfx_juice.gd
## 1. くり返す UI の音は、毎回ほんの少し高さがゆれる（±5% 以内）。音階で上がる音はゆらさない
## 2. すくうたびに高さが F のペンタトニックで上がる（2 倍で頭打ち）。破れたら最初から
## 3. コインの粒：数に応じて 3〜12 粒、だんだん速く、高さは下がらない
## 4. ためる音は、割れる瞬間に頂点がくるよう、後ろから切り出す
## 5. 大きなごほうびの音では BGM を下げ、しばらくしたら戻す
## 6. 鳴らす名前の音がぜんぶある

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _run() -> void:
	# 1
	var lo := 9.0
	var hi := 0.0
	for i in 200:
		var v := Sfx.vary("tap")
		lo = minf(lo, v)
		hi = maxf(hi, v)
	_check(lo >= 0.95 and hi <= 1.05 and hi - lo > 0.02, "tap pitch varies a little (%.3f..%.3f)" % [lo, hi])
	_check(is_equal_approx(Sfx.vary("coin_tick"), 1.0) and is_equal_approx(Sfx.vary("catch"), 1.0), "scale-stepped sounds are not jittered")

	# 2
	Sfx.catch_break()
	var ps: Array = []
	for i in 8:
		ps.append(Sfx.next_catch_pitch())
	_check(is_equal_approx(ps[0], 1.0), "first catch at the base pitch")
	var rising := true
	for i in range(1, ps.size()):
		rising = rising and ps[i] >= ps[i - 1]
	_check(rising and ps[1] > ps[0] and ps[4] > ps[3], "consecutive catches climb (%s)" % str(ps))
	_check(is_equal_approx(ps[7], 2.0), "catch pitch caps at one octave")
	Sfx.catch_break()
	_check(is_equal_approx(Sfx.next_catch_pitch(), 1.0), "a torn poi resets the combo")

	# 3
	var small: Array = Sfx.coin_plan(3)
	var big: Array = Sfx.coin_plan(200)
	_check(small.size() == 3 and big.size() == 12, "coin ticks scale with the amount (%d / %d)" % [small.size(), big.size()])
	var accel := true
	var up := true
	for i in range(2, big.size()):
		accel = accel and (big[i][0] - big[i - 1][0]) <= (big[i - 1][0] - big[i - 2][0]) + 0.0001
	for i in range(1, big.size()):
		up = up and big[i][1] >= big[i - 1][1]
	_check(accel and big[1][0] - big[0][0] > big[11][0] - big[10][0], "coin ticks speed up")
	_check(up and big[11][1] > big[0][1], "coin ticks climb in pitch")
	_check(big[11][0] < 1.0, "a big coin burst stays short (%.2f s)" % big[11][0])

	# 4
	_check(is_equal_approx(Sfx.riser_from(0.4), Sfx.RISER_PEAK - 0.4), "riser starts so its peak hits the crack")
	_check(is_equal_approx(Sfx.riser_from(9.0), 0.0), "long build plays the whole riser")

	# 5
	var m := Music.new()
	root.add_child(m)
	m.set_process(false)
	var node := Node.new()
	root.add_child(node)
	await process_frame
	Sfx.level_up(node)
	for i in 10:
		m.step(0.05)
	_check(m._duck_db < -4.0, "BGM ducks under the level-up stinger (%.1f dB)" % m._duck_db)
	for i in 80:
		m.step(0.05)
	_check(m._duck_db > -0.1, "BGM comes back after the stinger")
	Kit.play(node, "grow")
	for i in 10:
		m.step(0.05)
	_check(m._duck_db < -2.0, "Kit.play of a big stinger also ducks the BGM")
	Kit.play(node, "tap")
	_check(not m._duck.has("sfx:tap"), "UI taps do not duck the BGM")
	m.queue_free()
	node.queue_free()

	# 6
	for n in Sfx.CUE_SOUNDS:
		_check(ResourceLoader.exists("res://assets/sfx/%s.wav" % n), "cue sound %s exists" % n)

	print("test_sfx_juice: ", "OK" if fails == 0 else "%d FAIL" % fails)
	quit(1 if fails else 0)
