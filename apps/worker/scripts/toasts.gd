class_name Toasts
extends CanvasLayer
## 小さな知らせ（めあて達成・庭が育った・おみやげ など）を、ひとつずつ順番に出す。重ねない。
## どの画面からでも Toasts.push(見出し, 本文, 種類)。はじめての push で、画面の上に一枚だけ置かれる（画面を替えても残る）。
##   kind "goal" … 上から降りてくる明るい札（めあて）
##   kind "info" … 画面のまん中の、暗い札（庭・おみやげ・手紙）

const SHOW_SEC := 2.2

static var _node: Toasts
static var _queue: Array = []
static var _showing := false


static func push(title: String, body: String, kind := "info") -> void:
	_queue.append([title, body, kind])
	_ensure()
	if not _showing:
		_showing = true # 先に印をつける（木に入るのを待つ間に、もう一枚出さないように）
		_node._next()


## 知らせを出しているところか、まだ待っている知らせがあるか（キセカエの見せ場などは、終わるまで待つ）
static func busy() -> bool:
	return _showing or not _queue.is_empty()


static func clear() -> void:
	_queue.clear()


static func _ensure() -> void:
	if _node and is_instance_valid(_node):
		return
	_node = Toasts.new()
	_node.layer = 40
	(Engine.get_main_loop() as SceneTree).root.add_child.call_deferred(_node)


func _next() -> void:
	if not is_inside_tree():
		await ready
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var t: Array = _queue.pop_front()
	var goal: bool = t[2] == "goal"
	if not goal and not Sfx.recently(0.3): # めあては main.gd がごほうびの音を鳴らす。ボタンの音の直後にも重ねない
		Kit.play(self, "toast")
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if goal:
		p.add_theme_stylebox_override("panel", Kit.pill(Color("fff6d8"), 18, 0.25, Vector2(14, 8)))
	else:
		p.add_theme_stylebox_override("panel", Kit.pill(Color(0.16, 0.13, 0.26, 0.92), 20, 0.2, Vector2(16, 10)))
	p.position = Vector2(30, -80 if goal else 360)
	p.size = Vector2(300, 0)
	add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.custom_minimum_size = Vector2(268, 0)
	p.add_child(v)
	v.add_child(I18n.wrap(Kit.text(t[0], 12 if goal else 18, Color("b07a1a") if goal else Color("ffe27a"), true, HORIZONTAL_ALIGNMENT_CENTER)))
	if String(t[1]) != "":
		v.add_child(I18n.wrap(Kit.text(t[1], 14 if goal else 13, Color("2a2233") if goal else Color("f3eeff"), goal, HORIZONTAL_ALIGNMENT_CENTER)))
	var tw := p.create_tween()
	if goal:
		tw.tween_property(p, "position:y", 56.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(SHOW_SEC)
		tw.tween_property(p, "position:y", -100.0, 0.3).set_trans(Tween.TRANS_SINE)
	else:
		p.pivot_offset = Vector2(150, 30)
		p.scale = Vector2(0.6, 0.6)
		tw.tween_property(p, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(SHOW_SEC)
		tw.tween_property(p, "modulate:a", 0.0, 0.4)
	await tw.finished
	p.queue_free()
	_next()
