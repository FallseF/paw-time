// 細くなめらかな輪郭（裏返した殻）。ノードの縮尺に左右されないよう、視点空間で世界の長さだけふくらませる。
// 色は体の色を暗くした色を渡す（真っ黒より柔らかく見える）。
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, blend_mix, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.2, 0.14, 0.2, 1.0);
uniform float width = 0.0075;

// 耳をぴくっと動かす（タイトルの猫だけが使う。0 なら何もしない）。x が左耳、y が右耳の角度（ラジアン）。
// 体のメッシュの座標（足元 y=0、耳の付け根 y≈0.84、x=±0.26）で、耳の先ほど大きく回す。
uniform vec2 ear_twitch = vec2(0.0);

void ear_bend(inout vec3 v, inout vec3 n) {
	for (int i = 0; i < 2; i++) {
		float sx = i == 0 ? -1.0 : 1.0;
		float ang = i == 0 ? ear_twitch.x : ear_twitch.y;
		if (abs(ang) < 0.0001) {
			continue;
		}
		float w = smoothstep(0.76, 0.95, v.y) * smoothstep(0.05, 0.16, v.x * sx);
		vec3 piv = vec3(sx * 0.26, 0.84, -0.03);
		float a = -ang * w * sx;
		float b = ang * w * 0.5;
		mat3 rz = mat3(vec3(cos(a), sin(a), 0.0), vec3(-sin(a), cos(a), 0.0), vec3(0.0, 0.0, 1.0));
		mat3 rx = mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cos(b), sin(b)), vec3(0.0, -sin(b), cos(b)));
		mat3 r = rx * rz;
		v = piv + r * (v - piv);
		n = r * n;
	}
}

void vertex() {
	vec3 vtx = VERTEX;
	vec3 nrm = NORMAL;
	ear_bend(vtx, nrm); // 肌と同じだけ耳を動かす（殻がずれないように）
	vec4 vp = MODELVIEW_MATRIX * vec4(vtx, 1.0);
	// 縮尺がそろっていない部品でも、法線は正しい行列で回す
	vec3 vn = normalize(mat3(VIEW_MATRIX) * (MODEL_NORMAL_MATRIX * nrm));
	// 遠くでも細くなりすぎないよう、距離で少し太らせる
	float d = max(-vp.z, 0.1);
	float wdt = width * clamp(d / 3.0, 0.8, 2.2);
	vp.xyz += vn * wdt;
	vp.z -= wdt * 5.0;  // 奥へ逃がして、くぼみ（耳の内側など）から殻が顔を出さないように
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	ALBEDO = color.rgb;
}
