extends Node
## 「自分でシフトを入れる」も、求人を受けるときと同じく、時間の重なるシフトは入れない。
## 重なったら、求人と同じ知らせ（時間がかぶってるよ・どのシフトと重なるか）と「マイシフトで見る ›」を出す。
##   OBAKE_NOSAVE=1 godot --headless --path . res://tests/test_shift_form_overlap.tscn

var fails := 0


func check(ok: bool, what: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", what)


func _texts(n: Node) -> String:
	var out := ""
	for c in n.find_children("*", "", true, false):
		if (c is Label or c is Button) and c.is_visible_in_tree():
			out += c.text + "\n"
	return out


func _link(n: Node, t: String) -> Button:
	for c in n.find_children("*", "Button", true, false):
		if c.text == t and c.is_visible_in_tree():
			return c
	return null


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var root := get_tree().root
	await get_tree().process_frame
	if OS.get_environment("OBAKE_NOSAVE") == "":
		print("run with OBAKE_NOSAVE=1")
		get_tree().quit(2)
		return
	for lang in ["en", "ja"]:
		TranslationServer.set_locale(lang)
		Shifts.reset()
		var f := ShiftForm.new()
		root.add_child(f)
		await get_tree().process_frame
		f.demo_fill() # あした 18:00–22:00
		var first := f.build_shift()
		first["id"] = "mine1"
		Shifts.add(first)
		# 同じ日の 20:00–23:00：重なる
		f.start_min = 20 * 60
		f.end_min = 23 * 60
		f._refresh()
		var added := []
		f.added.connect(func(s): added.append(s))
		var seen := []
		if f.has_signal("see_shifts"):
			f.connect("see_shifts", func(at): seen.append(at))
		f._add()
		await get_tree().process_frame
		check(Shifts.all().size() == 1, "[%s] an overlapping manual shift is not added (%d)" % [lang, Shifts.all().size()])
		check(added.is_empty(), "[%s] no 'added' for an overlapping shift" % lang)
		check(is_instance_valid(f) and not f.is_queued_for_deletion(), "[%s] the form stays open on a clash" % lang)
		var shown := _texts(f)
		check(shown.contains(tr("R3_OVERLAP_TITLE")), "[%s] the clash title is shown" % lang)
		check(shown.contains(tr("R3_OVERLAP_BODY") % JobDesk.shift_label(Shifts.all()[0])), "[%s] the clash names the other shift" % lang)
		var l := _link(f, tr("R3_SEE_MY_SHIFTS"))
		check(l != null, "[%s] the My shifts link is shown" % lang)
		if l:
			l.pressed.emit()
			await get_tree().process_frame
			check(seen.size() == 1 and is_equal_approx(float(seen[0]), float(first.start)), "[%s] the link goes to that day in My shifts (%s)" % [lang, seen])
		check(not is_instance_valid(f) or f.is_queued_for_deletion(), "[%s] the link closes the form" % lang)
		# 時刻を変えたら知らせは消える。終わりちょうどに始まるのは重ならない：22:00–23:30 は入る
		var f2 := ShiftForm.new()
		root.add_child(f2)
		await get_tree().process_frame
		f2.demo_fill()
		var added2 := []
		f2.added.connect(func(s): added2.append(s))
		f2.start_min = 21 * 60
		f2._refresh()
		f2._add()
		check(_texts(f2).contains(tr("R3_OVERLAP_TITLE")), "[%s] a second clash is shown" % lang)
		f2.start_min = 22 * 60
		f2.end_min = 23 * 60 + 30
		f2._refresh()
		check(not _texts(f2).contains(tr("R3_OVERLAP_TITLE")), "[%s] changing the time clears the clash note" % lang)
		f2._add()
		await get_tree().process_frame
		check(Shifts.all().size() == 2 and added2.size() == 1, "[%s] a shift right after the other one is added (%d)" % [lang, Shifts.all().size()])
		for c in root.get_children():
			if c is ShiftForm:
				c.queue_free()
		await get_tree().process_frame
	Shifts.reset()
	print("test_shift_form_overlap: ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
