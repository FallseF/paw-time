class_name ObakeView
extends Control
## おばけ1体の表示。ふわふわ揺れて、ときどき瞬きする。

var species := "receipt"
var px_scale := 3
var bob := true
var _tex: Texture2D
var _t := 0.0
var _blink := 0.0
var flash := 0.0


func setup(id: String, scale := 3, do_bob := true) -> ObakeView:
	species = id
	px_scale = scale
	bob = do_bob
	_tex = load("res://assets/sprites/obake_%s.png" % id)
	custom_minimum_size = Vector2(32, 32) * scale
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t = randf() * TAU
	return self


func _process(delta: float) -> void:
	_t += delta
	_blink -= delta
	if _blink < -3.0 + randf() * 0.5:
		_blink = 0.12
	flash = max(0.0, flash - delta * 3.0)
	queue_redraw()


func _draw() -> void:
	if _tex == null:
		return
	var y := sin(_t * 2.2) * 2.0 * px_scale / 3.0 if bob else 0.0
	var src := Rect2(32 if _blink > 0 else 0, 0, 32, 32)
	var dst := Rect2(Vector2(0, y), Vector2(32, 32) * px_scale)
	draw_texture_rect_region(_tex, dst, src, Color(1, 1, 1, 1).lerp(Color(3, 3, 3, 1), flash))
