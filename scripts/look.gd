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
	# 孵化：暗い部屋にスポットの暖かい光
	"hatch": {
		"ambient": Color("c9a8b8"), "ambient_energy": 0.25,
		"key": [Vector3(-30, 40, 0), Color("ffc98f"), 0.6],
		"fill": [Vector3(-10, -140, 0), Color("9fb0ff"), 0.22],
		"rim": [Vector3(-18, 172, 0), Color("ffd9b0"), 0.8],
		"exposure": 1.0, "contrast": 1.06, "saturation": 1.05,
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
	var we := WorldEnvironment.new()
	we.name = "LookEnvironment"
	we.environment = env
	world.add_child(we)
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
