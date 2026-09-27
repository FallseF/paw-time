class_name SkillBadge
extends Control
## スキルのバッジ（丸いメダル）。仕事の色の円に、仕事の絵と星（★1〜★3）。まだなら、うすい灰色の輪だけ。
##   SkillBadge.make("register", 2, 96)

var role := "register"
var stars := 0
var px := 96.0


static func make(r: String, st: int, size_px := 96) -> SkillBadge:
	var b := SkillBadge.new()
	b.role = r
	b.stars = st
	b.px = size_px
	b.custom_minimum_size = Vector2(size_px, size_px)
	b.size = Vector2(size_px, size_px)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _draw() -> void:
	var c := Vector2(px, px) / 2.0
	var r := px / 2.0
	var col: Color = GameState.TYPE_COLOR.get(role, Color("ffc23d"))
	if stars <= 0:
		draw_circle(c, r - 2, Color(1, 1, 1, 0.55))
		draw_arc(c, r - 3, 0, TAU, 48, Color(0.55, 0.5, 0.58, 0.55), 3.0, true)
		_icon(c + Vector2(0, -r * 0.08), r * 0.42, Color(0.6, 0.56, 0.62, 0.7))
		return
	# 影・金の縁・仕事の色・内側の光
	draw_circle(c + Vector2(0, r * 0.06), r - 1, Color(Tokens.SHADOW, 0.16))
	draw_circle(c, r - 2, Color("f2b233"))
	draw_circle(c, r * 0.84, col.darkened(0.12))
	draw_circle(c, r * 0.76, col)
	draw_circle(c + Vector2(-r * 0.2, -r * 0.24), r * 0.28, Color(1, 1, 1, 0.22))
	# ぎざぎざの縁（メダルらしく）
	for i in 24:
		var a := TAU * i / 24.0
		draw_circle(c + Vector2(cos(a), sin(a)) * (r - 3), r * 0.07, Color("ffd46a"))
	_icon(c + Vector2(0, -r * 0.14), r * 0.4, Color(1, 1, 1, 0.95))
	# 星（下にリボンのように並べる）
	var f: Font = Kit.black()
	var fs := int(r * 0.34)
	var t := "★".repeat(stars)
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var band := Rect2(c.x - w / 2 - 6, c.y + r * 0.3, w + 12, fs * 1.05)
	draw_style_box(Kit.pill(Color("2a2233", 0.78), int(fs * 0.5), 0.0), band)
	draw_string(f, Vector2(c.x - w / 2, c.y + r * 0.3 + fs * 0.86), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffe27a"))


## 仕事の絵（線の簡単な形。字は使わない）
func _icon(c: Vector2, s: float, ink: Color) -> void:
	var lw := maxf(2.0, s * 0.12)
	match role:
		"register": # レジ：台と画面
			draw_rect(Rect2(c.x - s * 0.8, c.y - s * 0.05, s * 1.6, s * 0.75), ink, false, lw)
			draw_rect(Rect2(c.x - s * 0.45, c.y - s * 0.7, s * 0.9, s * 0.45), ink, false, lw)
			draw_line(c + Vector2(-s * 0.4, s * 0.3), c + Vector2(s * 0.4, s * 0.3), ink, lw)
		"dish": # お皿と泡
			draw_arc(c + Vector2(0, s * 0.1), s * 0.7, 0, TAU, 32, ink, lw, true)
			draw_arc(c + Vector2(0, s * 0.1), s * 0.35, 0, TAU, 24, ink, lw * 0.7, true)
			draw_arc(c + Vector2(s * 0.75, -s * 0.6), s * 0.18, 0, TAU, 16, ink, lw * 0.7, true)
		"hall": # お盆とクローシュ
			draw_arc(c + Vector2(0, s * 0.25), s * 0.6, PI, TAU, 24, ink, lw, true)
			draw_line(c + Vector2(-s * 0.85, s * 0.28), c + Vector2(s * 0.85, s * 0.28), ink, lw)
			draw_circle(c + Vector2(0, -s * 0.42), s * 0.1, ink)
		"kitchen": # フライパン
			draw_arc(c + Vector2(-s * 0.15, s * 0.05), s * 0.55, 0, TAU, 28, ink, lw, true)
			draw_line(c + Vector2(s * 0.38, -s * 0.2), c + Vector2(s * 0.95, -s * 0.6), ink, lw * 1.3)
		_: # 品出し：箱
			draw_rect(Rect2(c.x - s * 0.7, c.y - s * 0.4, s * 1.4, s * 1.0), ink, false, lw)
			draw_line(c + Vector2(-s * 0.7, -s * 0.05), c + Vector2(s * 0.7, -s * 0.05), ink, lw * 0.8)
			draw_line(c + Vector2(0, -s * 0.4), c + Vector2(0, -s * 0.05), ink, lw * 0.8)
