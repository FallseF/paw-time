extends SceneTree
## 知らせ（Toasts）は重ならない：いくつ積んでも、画面に出ているのは 1 枚だけ。順番に全部出る。
## godot --headless --path . -s tests/test_toasts.gd

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _panels() -> int:
	var n := 0
	if Toasts._node and is_instance_valid(Toasts._node):
		for c in Toasts._node.get_children():
			if c is PanelContainer and not c.is_queued_for_deletion():
				n += 1
	return n


func _run() -> void:
	Toasts.push("めあて達成", "玉を3個すくう", "goal")
	Toasts.push("庭が育った", "灯籠がともった")
	Toasts.push("新しい服", "麦わら帽子")
	var seen_max := 0
	var t0 := Time.get_ticks_msec()
	while Toasts.busy() and Time.get_ticks_msec() - t0 < 20000:
		await process_frame
		seen_max = maxi(seen_max, _panels())
	_check(seen_max == 1, "only one toast at a time (saw %d)" % seen_max)
	_check(not Toasts.busy(), "all toasts shown")
	print("TOASTS TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
