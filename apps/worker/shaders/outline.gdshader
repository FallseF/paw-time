// 細くなめらかな輪郭（裏返した殻）。ノードの縮尺に左右されないよう、視点空間で世界の長さだけふくらませる。
// 色は体の色を暗くした色を渡す（真っ黒より柔らかく見える）。
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, blend_mix, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(0.2, 0.14, 0.2, 1.0);
uniform float width = 0.0075;
uniform float min_px = 0.8;
// 殻のふくらませ方。0 = 法線の向き（なめらかな形）、1 = 箱（面ごとに法線が割れた BoxMesh）、2 = 円柱・円すい（CylinderMesh）。
// 法線の割れた角で法線どおりに押すと、殻が面ごとにばらけて、細い柱の横に途切れた線が出る。
// 箱と円柱は、中心からの向きで押して、殻をひと続きの形のまま太らせる。
uniform int hull = 0;
// true なら距離で太らせず、いつも width の太さ（StandardMaterial3D の grow と同じ）。奥へは逃がさない
uniform bool fixed_width = false;

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
	float wdt = fixed_width ? width : width * clamp(d / 3.0, 0.8, 2.2);
	float push = fixed_width ? 0.0 : wdt * 5.0;
	if (hull > 0) {
		// 物の軸（縮尺は除く）を視点空間へ。箱は 3 軸とも、円柱は横は中心から外へ・縦は上下へ
		mat3 mv = mat3(MODELVIEW_MATRIX);
		vec3 ax = normalize(mv[0]);
		vec3 ay = normalize(mv[1]);
		vec3 az = normalize(mv[2]);
		vec3 sg = sign(vtx);
		if (hull == 1) {
			vn = ax * sg.x + ay * sg.y + az * sg.z;
		} else {
			vec2 rad = vtx.xz;
			vec2 rn = dot(rad, rad) > 1e-8 ? normalize(rad) : vec2(0.0);
			vn = ax * rn.x + az * rn.y + ay * sg.y;
		}
	}
	// さらに、画面の上で min_px（360 幅の画面の点）より細くしない。1 画素を切る輪郭は、画素に乗ったり乗らなかったりして
	// 点線のように途切れ、MSAA でもつながらない（引いた島の持ち物・遠くの猫）。VIEWPORT_SIZE.x / 360 が描く倍率。
	float px_scale = clamp(VIEWPORT_SIZE.x / 360.0, 1.0, 4.0);
	float world_per_px = 2.0 * mix(d, 1.0, PROJECTION_MATRIX[3][3]) / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
	wdt = max(wdt, min_px * px_scale * world_per_px);
	vp.xyz += vn * wdt;
	vp.z -= push;  // 奥へ逃がして、くぼみ（耳の内側など）から殻が顔を出さないように
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	ALBEDO = color.rgb;
}
