class_name ChatHub
extends Control
## Where the chats open from.
##   - On the island (screen_garden adds ChatHub.new() in one line): the round Talk button at the top right (IslandHud → talk()),
##     or tap your cat → a "Talk" bubble. Either way the camera zooms in on your cat, then the private chat opens.
##   - From anywhere: ChatHub.open(parent, "me" | "shop:<shift id>" | "list").
##   - During a shift the mainline locks play; only the current shift's shop chat stays open: allowed_during_shift().

var garden: Control
var talk_btn: Button
var talking := false


## Open a chat over parent (the chat covers the whole 360x640 screen and closes itself)
static func open(parent: Node, thread_id: String) -> ScreenChat:
	var s := ScreenChat.new()
	s.thread = thread_id
	parent.add_child(s)
	return s


## While a shift is running, only the chat with that shift's shop may open (e.g. "running late")
static func allowed_during_shift(thread_id: String, now := -1.0) -> bool:
	var cur := Shifts.current(now)
	return not cur.is_empty() and thread_id == ChatShops.thread_id_for(cur) and ChatShops.allowed(thread_id)


func _ready() -> void:
	position = Vector2.ZERO
	size = get_parent().size if get_parent() is Control else Vector2(360, 640)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	garden = get_parent() as Control


## 話す：カメラが相棒に寄って（相棒が大きくなって）から、ふたりのチャットを開く。閉じたら島の眺めに戻る
func talk() -> void:
	if talking or not _free_to_talk():
		return
	talking = true
	if talk_btn and is_instance_valid(talk_btn):
		talk_btn.queue_free()
	if garden.has_method("zoom_to_cat"):
		await garden.zoom_to_cat(tr("R2_TALK_HI"))
	if not is_inside_tree():
		return
	var chat := ChatHub.open(get_parent(), "me")
	chat.tree_exited.connect(func():
		talking = false
		if is_instance_valid(garden) and garden.is_inside_tree() and not garden.is_queued_for_deletion() and garden.has_method("zoom_back"):
			garden.zoom_back())


## Where your cat is on screen (null if the island has no cat right now)
func _cat_screen_pos():
	var host = garden.get("host_node") if garden else null
	var cam = garden.get("cam") if garden else null
	if host == null or cam == null or not is_instance_valid(host) or not (host as Node3D).is_inside_tree():
		return null
	return View3D.unproject(cam as Camera3D, (host as Node3D).global_position + Vector3(0, 0.45, 0))


func _free_to_talk() -> bool:
	if garden == null or garden.get("editing") or garden.get("busy"):
		return false
	for c in get_parent().get_children():
		if c is ScreenChat:
			return false
		var vw = c.get("viewer") # JobDesk's job card / review is open
		if vw != null and is_instance_valid(vw):
			return false
	return true


func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p = _cat_screen_pos()
	if p == null or not _free_to_talk():
		return
	var pos: Vector2 = event.position
	if pos.y < 110 or (p as Vector2).distance_to(pos) > 46.0:
		return
	# only when the tap lands on the island itself (not on a card or button above it)
	var hov := get_viewport().gui_get_hovered_control()
	if hov != null and hov != garden:
		return
	show_talk()


## The small "Talk" bubble over your cat
func show_talk() -> void:
	var p = _cat_screen_pos()
	if p == null:
		return
	if talk_btn and is_instance_valid(talk_btn):
		talk_btn.queue_free()
	talk_btn = Kit.button(tr("CHAT_TALK"), Color(1, 1, 1, 0.96), talk, Color("6a5bd6"), 36, 15)
	talk_btn.custom_minimum_size.x = 84
	add_child(talk_btn)
	talk_btn.size = Vector2(84, 36)
	talk_btn.position = (p as Vector2) + Vector2(-42, -66)
	talk_btn.pivot_offset = Vector2(42, 36)
	talk_btn.scale = Vector2(0.3, 0.3)
	var b := talk_btn
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(4.0)
	tw.tween_property(b, "modulate:a", 0.0, 0.3)
	tw.tween_callback(func(): if is_instance_valid(b): b.queue_free())
	Kit.play(self, "pop", 1.2, -6)


# ---------------------------------------------------------------- for screenshots (OBAKE_SHOT call:)

func demo_tap_cat() -> void:
	show_talk()


func demo_talk() -> void:
	ChatHub.open(get_parent(), "me")


## 島の「話す」札を押したのと同じ（寄ってから、チャット）
func demo_talk_button() -> void:
	talk()


## A real tap (mouse events through the window), to check the tap-on-cat path end to end
func demo_real_tap() -> void:
	var p = _cat_screen_pos()
	if p == null:
		return
	var w: Vector2 = get_viewport().get_final_transform() * (p as Vector2)
	var mv := InputEventMouseMotion.new()
	mv.position = w
	Input.parse_input_event(mv)
	await get_tree().process_frame
	await get_tree().process_frame
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = w
	Input.parse_input_event(e)
	var r := e.duplicate()
	r.pressed = false
	Input.parse_input_event(r)
