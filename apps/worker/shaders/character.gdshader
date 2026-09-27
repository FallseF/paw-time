// おばけの肌（GL Compatibility 用）。
// やわらかく回り込む拡散光を、暖かい光側と少し鮮やかで青みのある影側の色でつなぐ。
// 明暗の境目にだけ赤みを足して「中まで光が透ける」感じを出し、縁には淡いフレネルの光、
// 焼いた AO（頂点色 R）と耳の内側の印（頂点色 G = 1 - 印）を掛ける。
// 頂点色を持たない部品は白なので、AO なし・耳の色なしになる。
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 inner_color : source_color = vec4(0.97, 0.66, 0.68, 1.0);
uniform vec4 shadow_tint : source_color = vec4(0.56, 0.52, 0.80, 1.0);
uniform vec4 light_tint : source_color = vec4(1.0, 0.97, 0.92, 1.0);
uniform vec4 sss_color : source_color = vec4(1.0, 0.42, 0.32, 1.0);
uniform float sss_strength : hint_range(0.0, 1.0) = 0.1;
uniform float wrap : hint_range(0.0, 1.0) = 0.35;
uniform float ramp_center : hint_range(0.0, 1.0) = 0.42;
uniform float ramp_soft : hint_range(0.01, 1.0) = 0.6;
uniform float shadow_level : hint_range(0.0, 1.0) = 0.42;
uniform float shadow_sat : hint_range(0.0, 1.5) = 0.22;
uniform float ao_strength : hint_range(0.0, 1.0) = 0.6;
uniform vec4 rim_color : source_color = vec4(1.0, 0.97, 0.92, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0) = 0.15;
uniform float rim_power = 3.2;
uniform float back_rim : hint_range(0.0, 4.0) = 0.5;
uniform float sheen : hint_range(0.0, 1.0) = 0.05;
uniform float sheen_gloss = 18.0;
uniform float emission_energy = 0.0;
// 1 なら頂点色をそのまま色に使う（地形：芝・砂・岩と AO を Blender で焼いてある）
uniform float vertex_albedo : hint_range(0.0, 1.0) = 0.0;
// 頂点色のガンマを 1 回もどす指数（1 = そのまま）。島の地形は Blender で sRGB → 線形にしてから書き出し、
// 取りこみでもう一度線形として読まれて（二重の線形化）、芝が #79E438 の蛍光色になっていた。1/2.2 で 1 回分もどす
uniform float vertex_gamma = 1.0;
// 地形の芝に、世界座標のまだらを少し足す（近くで見ても単色に見えないように）
uniform float ground_mottle : hint_range(0.0, 0.3) = 0.0;
uniform float shadow_keep : hint_range(0.0, 1.0) = 0.6;
uniform float top_light : hint_range(0.0, 0.5) = 0.07;

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

varying float v_ao;
varying float v_ear_region;
varying vec3 v_col;
varying vec3 v_world;
varying vec3 v_obj;
varying float v_up;

void vertex() {
	v_ao = COLOR.r;
	v_ear_region = 1.0 - COLOR.b;
	v_col = COLOR.rgb;
	v_obj = VERTEX; // 耳の内側の印は、動かす前の形で決める（耳といっしょに動く）
	ear_bend(VERTEX, NORMAL);
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_up = (MODEL_NORMAL_MATRIX * NORMAL).y;
}

// 耳の内側（くぼみ）の距離場。tools/blender/build_cat_obake.py の Shape.ear_sdf と同じ形。
// 頂点色に焼くと三角形の粗さでギザつくので、画素ごとに計算する。
float round_cone(vec3 p, float r1, float r2, float h) {
	vec2 q = vec2(length(p.xz), p.y);
	float b = (r1 - r2) / h;
	float a = sqrt(1.0 - b * b);
	float k = dot(q, vec2(-b, a));
	if (k < 0.0) return length(q) - r1;
	if (k > a * h) return length(q - vec2(0.0, h)) - r2;
	return dot(q, vec2(a, b)) - r1;
}

float inner_ear(vec3 p, float sx) {
	vec3 v = p - vec3(sx * 0.265, 0.9, -0.03);
	// 耳の傾き（Rx(-0.12)・Rz(-sx*0.36)）を戻す
	float ax = 0.12;
	v = vec3(v.x, cos(ax) * v.y - sin(ax) * v.z, sin(ax) * v.y + cos(ax) * v.z);
	float az = sx * 0.36;
	v = vec3(cos(az) * v.x - sin(az) * v.y, sin(az) * v.x + cos(az) * v.y, v.z);
	vec3 l2 = v * vec3(1.0, 1.0, 1.45);
	vec3 ip = l2 - vec3(0.0, -0.03, 0.16);
	ip.z += (l2.y + 0.03) * 0.42;
	float inner = round_cone(ip, 0.088, 0.016, 0.2) / 1.45;
	float d = 0.012 - inner;
	float w = fwidth(d) + 0.003;
	return smoothstep(-w, w, d) * smoothstep(-0.005, 0.02, v.z);
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec3 alb = base_color.rgb * texture(albedo_tex, UV).rgb;
	if (vertex_albedo > 0.5) {
		alb = base_color.rgb * pow(max(v_col, vec3(0.0)), vec3(vertex_gamma));
		if (ground_mottle > 0.0) {
			vec2 q = v_world.xz;
			float n = sin(q.x * 2.3 + sin(q.y * 1.7)) * sin(q.y * 2.9 + sin(q.x * 1.3));
			n += 0.5 * sin(q.x * 7.1 + q.y * 5.3) * sin(q.y * 6.7 - q.x * 3.1);
			alb *= 1.0 + ground_mottle * n;
		}
	}
	if (v_ear_region > 0.01 && vertex_albedo < 0.5) {
		float ear = max(inner_ear(v_obj, -1.0), inner_ear(v_obj, 1.0)) * clamp(v_ear_region * 2.0, 0.0, 1.0);
		alb = mix(alb, inner_color.rgb, ear);
	}
	// 上を向いた面ほどわずかに明るく（空からの光）
	alb *= 1.0 + top_light * v_up;
	// AO は暗くするだけでなく、影の色へ寄せる
	float ao = mix(1.0, v_ao, ao_strength * (1.0 - vertex_albedo));
	vec3 ao_col = mix(shadow_tint.rgb * 0.75, vec3(1.0), ao);
	ALBEDO = alb * ao_col;
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fr = pow(1.0 - ndv, rim_power);
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float sky = smoothstep(-0.4, 0.7, wn.y);
	EMISSION = mix(alb, rim_color.rgb, 0.45) * fr * rim_strength * sky * ao;
	EMISSION += alb * emission_energy;
	ROUGHNESS = 0.6;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	if (!LIGHT_IS_DIRECTIONAL) {
		// 点光源・スポット：距離で弱まる、ふつうの回り込む拡散光だけ（影側の色づけは平行光に任せる）
		float wl = clamp((ndl + wrap * 0.5) / (1.0 + wrap * 0.5), 0.0, 1.0);
		DIFFUSE_LIGHT += LIGHT_COLOR / PI * wl * ATTENUATION;
	} else {
	float w = (ndl + wrap) / (1.0 + wrap);
	float lit = smoothstep(ramp_center - ramp_soft * 0.5, ramp_center + ramp_soft * 0.5, w);
	// 影側：青みを足し、色を少し鮮やかに
	float l = max(luma(ALBEDO), 0.001);
	vec3 sat = max(mix(vec3(l), ALBEDO, 1.0 + shadow_sat), vec3(0.0));
	vec3 sat_ratio = clamp(sat / max(ALBEDO, vec3(0.001)), vec3(0.0), vec3(2.0));
	vec3 shade_dark = shadow_tint.rgb * shadow_level * sat_ratio * clamp(w * 1.4, 0.35, 1.0);
	vec3 shade_lit = light_tint.rgb * (0.66 + 0.34 * clamp(w, 0.0, 1.0));
	vec3 shade = mix(shade_dark, shade_lit, lit);
	// 明暗の境目の赤み（光が中を透けてくる感じ）
	float term = exp(-pow((w - ramp_center) / (ramp_soft * 0.9), 2.0));
	shade += sss_color.rgb * term * sss_strength;
	// 落ち影（ATTENUATION）は光の全体に掛ける。ただし自分の影で真っ暗にならないよう、影の中にも少し残す
	float att = mix(shadow_keep, 1.0, ATTENUATION);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * shade * att;
	// やわらかいつや
	vec3 h = normalize(LIGHT + VIEW);
	float spec = pow(clamp(dot(NORMAL, h), 0.0, 1.0), sheen_gloss);
	SPECULAR_LIGHT += LIGHT_COLOR / PI * spec * sheen * lit * ATTENUATION;
	// うしろからの光は、縁を明るく縁取る
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float edge = pow(1.0 - ndv, 2.5);
	float behind = clamp(-dot(LIGHT, VIEW) * 0.6 + 0.4, 0.0, 1.0);
	SPECULAR_LIGHT += LIGHT_COLOR / PI * rim_color.rgb * edge * behind * clamp(ndl + 0.35, 0.0, 1.0) * back_rim * ATTENUATION * mix(vec3(1.0), ALBEDO, 0.5);
	}
}
