class_name Look
extends RefCounted
## 画面ごとの光と空気（キー・フィル・リムの 3 灯、トーンマップ、ゆるい色調整）。
## GL Compatibility で使える機能だけで組む（SSAO / SSR / SDFGI は使わない）。
##   var rig := Look.apply(world, "room", Color("241c2b"))
## 返り値は {"env": Environment, "key": DirectionalLight3D, "fill": ..., "rim": ...}。
## 画面側で明るさを変えたいときは、返ったライトを直接いじる。
## フィル・リムは CHAR_LAYER（おばけだけが乗る層）にしか当てないので、
## 床や壁の明るさは今までどおりキーと環境光だけで決まる。

const CHAR_LAYER := 2

## 色の仕上げ（Look を使う全画面に共通）。強さはここだけで変える。on = false か各値 0 で切れる。トーンマップは LINEAR のまま
const GRADE := {
	"on": true,
	"warm": 0.035, # 明るいところを少し暖かく、暗いところを少し青紫に
	"tame": 0.14, # 強すぎる緑・水色（色相 70°〜205°くらい）の彩度を下げる割合。黄色・橙・桃は触らない
	"vignette": 0.2, # 四隅をわずかに落とす（3D の上だけ。背景が透明な舞台には付けない）
}
const _LUT_N := 17
static var _lut: ImageTexture3D
static var _lut_title: ImageTexture3D # タイトルの仕上げ（暗部の底上げなし。タイトルは見た目の基準なので変えない）
## 暗いところの底（真っ黒の #0000xx につぶれないように）。これより暗い色は持ち上げ、暗いほど彩度を落とす
const DARK_FLOOR := Color(0.07, 0.07, 0.12)
const DARK_LUMA := 0.15
static var _vignette: Shader

const PRESETS := {
	# 図鑑カード・棚：明るいスタジオ。影は青紫、光は暖かい
	"studio": {
		"ambient": Color("d9cde6"), "ambient_energy": 0.42,
		"key": [Vector3(-38, 32, 0), Color("fff0dc"), 1.05],
		"fill": [Vector3(-12, -140, 0), Color("b9c8ff"), 0.28],
		"rim": [Vector3(-25, 165, 0), Color("fff4e6"), 0.75],
		"exposure": 1.0, "contrast": 1.04, "saturation": 1.06,
	},
	# 休憩室：夕方の室内。暖かいキーと、窓からの青いフィル
	"room": {
		"ambient": Color("ffe9d6"), "ambient_energy": 0.35,
		"key": [Vector3(-40, 35, 0), Color("ffe0bf"), 0.6],
		"fill": [Vector3(-15, -135, 0), Color("a9bcff"), 0.25],
		"rim": [Vector3(-20, 170, 0), Color("ffe6c8"), 0.6],
		"exposure": 1.0, "contrast": 1.05, "saturation": 1.05,
	},
	# 島（昼）：外の光。夜は画面側でキーと環境光を青く寄せる
	"island": {
		"ambient": Color("ffe9d6"), "ambient_energy": 0.4,
		"key": [Vector3(-42, 30, 0), Color("ffe0bf"), 0.75],
		"fill": [Vector3(-15, -140, 0), Color("b9c8ff"), 0.25],
		"rim": [Vector3(-22, 170, 0), Color("fff0dc"), 0.6],
		"exposure": 1.05, "contrast": 1.04, "saturation": 1.06,
	},
	# 夢：ラベンダーの空気、やわらかいキー
	"dream": {
		"ambient": Color("d8c8ff"), "ambient_energy": 0.55,
		"key": [Vector3(-30, 20, 0), Color("ffe0f0"), 0.55],
		"fill": [Vector3(-10, -140, 0), Color("c8d8ff"), 0.3],
		"rim": [Vector3(-18, 170, 0), Color("fff0ff"), 0.7],
		"exposure": 1.05, "contrast": 1.03, "saturation": 1.05,
	},
	# 満月の夜：月明かりのリム
	"moon": {
		"ambient": Color("4a5498"), "ambient_energy": 0.9,
		"key": [Vector3(-35, 160, 0), Color("aab8ff"), 0.6],
		"fill": [Vector3(-15, 20, 0), Color("ffd9a0"), 0.25],
		"rim": [Vector3(-20, -10, 0), Color("fff1c8"), 0.8],
		"exposure": 1.05, "contrast": 1.05, "saturation": 1.05,
	},
	# タイトル：夜の小島
	"title": {
		"ambient": Color("7a84c8"), "ambient_energy": 0.6,
		"key": [Vector3(-35, 30, 0), Color("c8d4ff"), 0.5],
		"fill": [Vector3(-10, -140, 0), Color("ffd9b0"), 0.25],
		"rim": [Vector3(-20, 170, 0), Color("dfe6ff"), 0.8],
		"exposure": 1.05, "contrast": 1.05, "saturation": 1.05,
	},
	# タイトル（夕方）：遠くの島のうしろ、右奥の低い太陽。左からラベンダーのフィル、猫の縁を読ませるリム
	"title_golden": {
		"ambient": Color("d9c2d0"), "ambient_energy": 0.5,
		"key": [Vector3(-16, 115, 0), Color("ffd0a2"), 1.0],
		"fill": [Vector3(-17, -62, 0), Color("b3a6ff"), 0.32],
		"rim": [Vector3(-20, 160, 0), Color("ffd3a0"), 0.95],
		"exposure": 1.02, "contrast": 1.03, "saturation": 0.93,
	},
	# 島：昼（高い太陽、白っぽい暖かいキー、空色のフィル）
	"island_day": {
		"ambient": Color("dfe9f2"), "ambient_energy": 0.42,
		"key": [Vector3(-48, 32, 0), Color("fff4e2"), 0.95],
		"fill": [Vector3(-15, -145, 0), Color("a9d4ff"), 0.3],
		"rim": [Vector3(-22, 168, 0), Color("fff6ea"), 0.55],
		"exposure": 1.0, "contrast": 1.03, "saturation": 1.06,
	},
	# 島：夕方（低い橙の太陽、紫のフィル、強めのリム）
	"island_evening": {
		"ambient": Color("e7c0c6"), "ambient_energy": 0.36,
		"key": [Vector3(-16, 58, 0), Color("ffb77a"), 0.95],
		"fill": [Vector3(-12, -130, 0), Color("a58cff"), 0.3],
		"rim": [Vector3(-12, 175, 0), Color("ffc890"), 0.9],
		"exposure": 1.0, "contrast": 1.05, "saturation": 1.08,
	},
	# 島：夜（青い月明かり、灯りが主役）
	"island_night": {
		"ambient": Color("5a64a8"), "ambient_energy": 0.5,
		"key": [Vector3(-55, -30, 0), Color("a9bcff"), 0.32],
		"fill": [Vector3(-10, 140, 0), Color("6f7fd6"), 0.18],
		"rim": [Vector3(-20, 175, 0), Color("c9d8ff"), 0.45],
		"exposure": 1.0, "contrast": 1.05, "saturation": 1.0,
	},
	# 孵化：暗い部屋にスポットの暖かい光
	"hatch": {
		"ambient": Color("c9a8b8"), "ambient_energy": 0.25,
		"key": [Vector3(-30, 40, 0), Color("ffc98f"), 0.6],
		"fill": [Vector3(-10, -140, 0), Color("9fb0ff"), 0.22],
		"rim": [Vector3(-18, 172, 0), Color("ffd9b0"), 0.8],
		"exposure": 0.8, "contrast": 1.04, "saturation": 0.97,
	},
}


static func apply(world: Node, preset := "studio", bg := Color(0, 0, 0, 0), transparent := false, key_shadow := false) -> Dictionary:
	var p: Dictionary = PRESETS[preset]
	var env := Environment.new()
	if transparent:
		env.background_mode = Environment.BG_CLEAR_COLOR
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = p.ambient
	env.ambient_light_energy = p.ambient_energy
	# 色味（仕事ごとのパステル色）をそのまま残すため、トーンマップは線形にして露出を少し下げる。
	# Filmic / AgX は明るい黄色が白っぽく抜けるので使わない。
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.tonemap_exposure = p.exposure * 0.88
	env.adjustment_enabled = true
	env.adjustment_contrast = p.contrast
	env.adjustment_saturation = p.saturation
	if GRADE.on:
		env.adjustment_color_correction = _grade_lut(not preset.begins_with("title"))
	var we := WorldEnvironment.new()
	we.name = "LookEnvironment"
	we.environment = env
	world.add_child(we)
	if GRADE.on and GRADE.vignette > 0.0 and not transparent:
		world.add_child(_vignette_layer())
	var rig := {"env": env}
	var char_bits := 1 << (CHAR_LAYER - 1)
	for k in ["key", "fill", "rim"]:
		var d: Array = p[k]
		var l := DirectionalLight3D.new()
		l.name = "Look" + k.capitalize()
		l.rotation_degrees = d[0]
		l.light_color = d[1]
		l.light_energy = d[2]
		l.light_specular = 0.6 if k == "key" else 0.2
		l.shadow_enabled = key_shadow and k == "key"
		if k != "key":
			l.light_cull_mask = char_bits
		world.add_child(l)
		rig[k] = l
	return rig


## 色補正の表（3D の LUT）。色の値（sRGB）→ 仕上げた色
static func _grade_lut(floor_darks := true) -> ImageTexture3D:
	if floor_darks and _lut:
		return _lut
	if not floor_darks and _lut_title:
		return _lut_title
	var slices: Array[Image] = []
	for bi in _LUT_N:
		var img := Image.create(_LUT_N, _LUT_N, false, Image.FORMAT_RGB8)
		for gi in _LUT_N:
			for ri in _LUT_N:
				var c := Color(ri, gi, bi) / (_LUT_N - 1.0)
				img.set_pixel(ri, gi, _grade(Color(c, 1.0), floor_darks))
		slices.append(img)
	var lut := ImageTexture3D.new()
	lut.create(Image.FORMAT_RGB8, _LUT_N, _LUT_N, _LUT_N, false, slices)
	if floor_darks:
		_lut = lut
	else:
		_lut_title = lut
	return lut


static func _grade(c: Color, floor_darks := true) -> Color:
	var h := c.h * 360.0
	var w := smoothstep(58.0, 80.0, h) * (1.0 - smoothstep(190.0, 215.0, h))
	c = Color.from_hsv(c.h, c.s * (1.0 - GRADE.tame * w), c.v)
	var l := c.get_luminance()
	c.r += GRADE.warm * l
	c.g += GRADE.warm * 0.35 * l
	c.b += GRADE.warm * (0.5 * (1.0 - l) - l)
	if floor_darks:
		# 暗部：ごく暗い色ほど彩度を落とし（紺や紫のにじみを抑える）、底を #12121F に
		var l2 := c.get_luminance()
		if l2 < DARK_LUMA:
			c = Color.from_hsv(c.h, minf(c.s, lerpf(0.6, 0.85, l2 / DARK_LUMA)), c.v)
		c = Color(maxf(c.r, DARK_FLOOR.r), maxf(c.g, DARK_FLOOR.g), maxf(c.b, DARK_FLOOR.b))
	return c.clamp()


## 周辺減光：SubViewport の中の 2D の層（3D の上、UI の下）
static func _vignette_layer() -> CanvasLayer:
	if _vignette == null:
		_vignette = Shader.new()
		_vignette.code = """shader_type canvas_item;
uniform float strength = 0.2;
void fragment() {
	float d = length((UV - 0.5) * vec2(1.0, 0.9));
	COLOR = vec4(0.08, 0.05, 0.14, smoothstep(0.38, 0.72, d) * strength);
}"""
	var layer := CanvasLayer.new()
	layer.name = "LookVignette"
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	m.shader = _vignette
	m.set_shader_parameter("strength", GRADE.vignette)
	r.material = m
	layer.add_child(r)
	return layer


## 島の画面用：フィルとリム（おばけの層だけに当てる）を足して返す。キーは画面の太陽をそのまま使う
static func island_rig(world: Node) -> Dictionary:
	var rig := {}
	var char_bits := 1 << (CHAR_LAYER - 1)
	for k in ["fill", "rim"]:
		var l := DirectionalLight3D.new()
		l.name = "LookIsland" + k.capitalize()
		l.light_cull_mask = char_bits
		l.light_specular = 0.2
		world.add_child(l)
		rig[k] = l
	return rig


## n = 0 昼 / 0.5 夕方 / 1 夜。島の 3 つの光を混ぜて、太陽・環境光・フィル・リムに入れる
static func island_time(rig: Dictionary, env: Environment, sun: DirectionalLight3D, n: float) -> void:
	var a: Dictionary = PRESETS.island_day
	var b: Dictionary = PRESETS.island_evening
	var t := n * 2.0
	if n > 0.5:
		a = PRESETS.island_evening
		b = PRESETS.island_night
		t = (n - 0.5) * 2.0
	t = clampf(t, 0.0, 1.0)
	env.ambient_light_color = (a.ambient as Color).lerp(b.ambient, t)
	env.ambient_light_energy = lerpf(a.ambient_energy, b.ambient_energy, t)
	if sun:
		sun.rotation_degrees = (a.key[0] as Vector3).lerp(b.key[0], t)
		sun.light_color = (a.key[1] as Color).lerp(b.key[1], t)
		sun.light_energy = lerpf(a.key[2], b.key[2], t)
	for k in ["fill", "rim"]:
		var l: DirectionalLight3D = rig.get(k)
		if l:
			l.rotation_degrees = (a[k][0] as Vector3).lerp(b[k][0], t)
			l.light_color = (a[k][1] as Color).lerp(b[k][1], t)
			l.light_energy = lerpf(a[k][2], b[k][2], t)
