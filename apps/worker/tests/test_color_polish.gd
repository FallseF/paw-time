extends SceneTree
## 色の仕上げ（2026-09-27 の見直し）が戻っていないか：
##   - 主なボタンは 1 色（#E2603C）。前の青・紫・オレンジで白い字のボタンも、その色で描く。白い字とのコントラスト 3.5:1 以上
##   - 影は墨色 #3A2E40（真っ黒の影を使わない）。押せないボタンは同じ色の 40%（灰色を混ぜない）
##   - 島の地形：頂点色のガンマを 1 回もどす（二重の線形化で芝が #79E438 の蛍光色になっていた）
##   - 暗部の底：色の仕上げで #0000xx につぶれない。タイトルの仕上げは変えない
## godot --headless --path . -s tests/test_color_polish.gd

var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, msg: String) -> void:
	if not ok:
		fails += 1
		print("FAIL ", msg)


func _lum(c: Color) -> float:
	var l := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * l.call(c.r) + 0.7152 * l.call(c.g) + 0.0722 * l.call(c.b)


func _run() -> void:
	# 主なボタン
	var ratio := 1.05 / (_lum(Tokens.PRIMARY) + 0.05)
	_check(ratio >= 3.5, "white on the primary is at least 3.5:1 (%.2f)" % ratio)
	for c in [Color("ff8a5b"), Color("5b6fc2"), Color("8b7bff")]:
		var b := Kit.button("x", c, func(): pass)
		var st := b.get_theme_stylebox("normal") as StyleBoxFlat
		_check(st.bg_color.is_equal_approx(Tokens.PRIMARY), "legacy primary %s draws as #E2603C (%s)" % [c.to_html(false), st.bg_color.to_html(false)])
		_check(st.shadow_color.is_equal_approx(Tokens.PRIMARY_LO) and st.shadow_offset.y >= 2.0, "primary has the 2pt bevel")
		var dis := b.get_theme_stylebox("disabled") as StyleBoxFlat
		_check(is_equal_approx(dis.bg_color.a, 0.4) and dis.bg_color.r > dis.bg_color.b, "disabled = same hue at 40%")
		b.free()
	var sec := Kit.button("x", Color("f3ecff"), func(): pass, Color("6a5bd6"))
	_check((sec.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.is_equal_approx(Color("f3ecff")), "secondary buttons keep their colour")
	sec.free()
	# 影
	var p := Kit.pill(Color.WHITE, 20, 0.25)
	_check(Color(p.shadow_color, 1.0).is_equal_approx(Tokens.SHADOW), "panel shadows are plum, not black (%s)" % p.shadow_color.to_html())
	_check(p.corner_radius_top_left == Tokens.R_M, "panel radius snaps to 16 (%d)" % p.corner_radius_top_left)
	# 地形の色
	_check(IslandProps.TERRAIN_GAMMA < 0.6 and IslandProps.TERRAIN_GAIN < 1.0, "terrain vertex colours undo the double linearisation")
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/character.gdshader")
	IslandProps.terrain_look(m)
	_check(float(m.get_shader_parameter("vertex_gamma")) < 0.6, "terrain_look sets vertex_gamma")
	# 暗部の底と、タイトルは変えない
	var black := Look._grade(Color(0, 0, 0))
	_check(black.r >= Look.DARK_FLOOR.r - 0.001 and black.b >= Look.DARK_FLOOR.b - 0.001, "darks floor lifts black (%s)" % black.to_html(false))
	var navy := Look._grade(Color(0.0, 0.0, 0.12))
	_check(navy.s <= 0.86, "very dark colours lose some saturation (%.2f)" % navy.s)
	var t_black := Look._grade(Color(0, 0, 0), false)
	_check(t_black.r < 0.05, "the title grade is unchanged (%s)" % t_black.to_html(false))
	print("COLOR POLISH TEST ", "OK" if fails == 0 else "FAIL (%d)" % fails)
	quit(0 if fails == 0 else 1)
