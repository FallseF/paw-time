// 細くなめらかな輪郭（裏返した殻）。ノードの縮尺に左右されないよう、視点空間で世界の長さだけふくらませる。
// 色は体の色を暗くした色を渡す（真っ黒より柔らかく見える）。
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, blend_mix, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.2, 0.14, 0.2, 1.0);
uniform float width = 0.0075;

void vertex() {
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	// 縮尺がそろっていない部品でも、法線は正しい行列で回す
	vec3 vn = normalize(mat3(VIEW_MATRIX) * (MODEL_NORMAL_MATRIX * NORMAL));
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
