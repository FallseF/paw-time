class_name TouchScroll
## スクロールの中を、どこからでも指でなぞって動かせるようにする（レビュー3：スマホでは右端のバーしかつかめなかった）。
## ScrollContainer の指のスクロールは、中のボタン（mouse_filter が STOP）の上で止まってしまう。
## 中のボタン・パネルを PASS にして、押した入力がスクロールにも届くようにする。
## なぞり始めると ScrollContainer が中に NOTIFICATION_SCROLL_BEGIN を送り、ボタンは押しかけを取り消す（なぞっただけでは押されない）。
## あとから足された中身（曜日のカード・チャットの吹き出しなど）にも効く。
## スライダー・文字の入力・スクロールバーは今までどおり（横になぞる・文字を選ぶのを邪魔しない）。


static func enable(sc: ScrollContainer) -> void:
	if sc.has_meta("touch_scroll"):
		return
	sc.set_meta("touch_scroll", true)
	sc.child_entered_tree.connect(func(n: Node): _watch(sc, n))
	for c in sc.get_children():
		_watch(sc, c)


## 中身の木に足されたものも PASS に（孫より下も。子が足されるたびに見る）
static func _watch(sc: ScrollContainer, n: Node) -> void:
	if n is ScrollBar or not n is Control or n.has_meta("touch_scroll_watch"):
		return
	n.set_meta("touch_scroll_watch", true)
	_pass_one(n)
	n.child_entered_tree.connect(func(c: Node): _watch(sc, c))
	for c in n.get_children():
		_watch(sc, c)


static func _pass_one(n: Node) -> void:
	if not n is Control or n is ScrollBar or n is Range or n is LineEdit or n is TextEdit or n is ScrollContainer:
		return
	var c := n as Control
	if c.mouse_filter == Control.MOUSE_FILTER_STOP:
		c.mouse_filter = Control.MOUSE_FILTER_PASS
