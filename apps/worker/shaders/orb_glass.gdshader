shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled, fog_disabled;

// 玉のガラスの殻（表側）。中身が読めるよう、正面はほぼ透明にして、厚いガラスらしさは縁で出す。
//  ・縁：フレネルの明るい輪と、その内側のわずかに暗い屈折の帯（厚みの見せかけ）
//  ・ハイライト：左上の窓形のやわらかい光と、右下の小さな光
//  ・薄い虹色（薄膜の干渉）、ガラスの中を漂う細かな塵、下半分に映る池の色と揺れる光
//  ・accent：種類の縁の色（おばネコ＝金、材料＝青白、服＝淡いピンク）。filament で金の細い筋
//  ・crack：0..1 でひびが広がる（孵化）
// SCREEN_TEXTURE は使わない（Web の Compatibility でも同じに見えるよう、屈折は見せかけ）。

uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform vec4 accent : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform vec4 pond : source_color = vec4(0.1, 0.2, 0.42, 1.0);
uniform float rim_power = 2.6;
uniform float iridescence = 0.35;
uniform float filament = 0.0;
uniform float dust = 1.0;
uniform float rare = 0.0;
uniform float crack = 0.0;
uniform float seed = 0.0;
uniform float glint = 1.0;

varying vec3 lpos;
varying vec3 to_cam;

void vertex() {
	lpos = normalize(VERTEX);
	// 物体の空間での、カメラへの向き（塵の奥行きに使う）
	to_cam = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz - VERTEX;
}

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

// 3D のボロノイの境目までの距離（ひび）と、そのセルの乱数
vec2 voronoi_edge(vec3 x) {
	vec3 n = floor(x);
	vec3 f = fract(x);
	float md = 8.0;
	vec3 mr = vec3(0.0);
	vec3 mg = vec3(0.0);
	for (int k = -1; k <= 1; k++)
	for (int j = -1; j <= 1; j++)
	for (int i = -1; i <= 1; i++) {
		vec3 g = vec3(float(i), float(j), float(k));
		vec3 r = g + hash33(n + g + seed) - f;
		float d = dot(r, r);
		if (d < md) { md = d; mr = r; mg = g; }
	}
	float ed = 8.0;
	for (int k = -1; k <= 1; k++)
	for (int j = -1; j <= 1; j++)
	for (int i = -1; i <= 1; i++) {
		vec3 g = mg + vec3(float(i), float(j), float(k));
		vec3 r = g + hash33(n + g + seed) - f;
		if (dot(mr - r, mr - r) > 0.00001) {
			ed = min(ed, dot(0.5 * (mr + r), normalize(r - mr)));
		}
	}
	return vec2(ed, hash3(n + mg + seed));
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float ndv = clamp(dot(n, v), 0.0, 1.0);
	float edge = 1.0 - ndv;
	float fres = pow(edge, rim_power);
	vec3 base_tint = tint.rgb;
	if (rare > 0.5) {
		base_tint = mix(hue(fract(TIME * 0.08 + lpos.y * 0.3 + seed)), vec3(1.0), 0.35);
	}
	vec3 acc = accent.rgb;

	// 厚いガラスの縁：外側の明るい輪、その内側の屈折の帯（少し暗く、色が濃い）
	float rim = smoothstep(0.5, 1.0, edge);
	float band = smoothstep(0.32, 0.55, edge) * (1.0 - smoothstep(0.62, 0.8, edge));
	vec3 col = mix(base_tint, acc, 0.55) * (0.35 + rim * 0.9);
	float a = 0.05 + rim * 0.72 + band * 0.12;
	col = mix(col, base_tint * 0.35, band * 0.5);

	// 薄い虹色：縁寄りに、見る角度で色が回る
	vec3 ir = 0.5 + 0.5 * cos(6.2832 * (edge * 1.6 + lpos.y * 0.25 + vec3(0.0, 0.33, 0.67) + seed));
	col += ir * iridescence * smoothstep(0.25, 0.85, edge) * 0.45;

	// ハイライト（視点空間の法線で決めるので、玉が回っても窓の位置は動かない）
	vec3 l1 = normalize(vec3(-0.5, 0.62, 0.62));
	float h1d = dot(n, l1);
	// 縦長の窓形（縦に伸ばして、角をやわらかく）
	vec2 hp = (n.xy - l1.xy) * vec2(1.0, 0.55);
	float h1 = 1.0 - smoothstep(0.075, 0.12, length(hp));
	// 窓の桟：細い線で 4 つに割る
	vec2 hb = (n.xy - l1.xy) * 14.0;
	float bars = smoothstep(0.08, 0.2, abs(hb.x + hb.y * 0.25)) * smoothstep(0.08, 0.2, abs(hb.y - hb.x * 0.15));
	h1 *= mix(1.0, bars, 0.8);
	float h1soft = smoothstep(0.75, 0.97, h1d) * 0.12;
	vec3 l2 = normalize(vec3(0.55, -0.4, 0.73));
	float h2 = smoothstep(0.982, 0.995, dot(n, l2));
	float hl = (h1 * 0.8 + h2 * 0.6) * glint;
	col += vec3(1.0) * (hl * 1.15 + h1soft);
	a += hl * 0.8 + h1soft * 0.6;

	// 下半分に映る池：深い藍と、揺れる光の筋
	vec3 wn = (INV_VIEW_MATRIX * vec4(n, 0.0)).xyz;
	float low = smoothstep(-0.05, -0.75, wn.y);
	float wave = sin(wn.x * 19.0 + sin(wn.z * 11.0 + TIME * 1.3) * 1.8 + TIME * 0.7);
	float glints = smoothstep(0.93, 0.995, wave) * smoothstep(-0.35, -0.7, wn.y) * smoothstep(0.35, 0.8, edge);
	col = mix(col, pond.rgb * 0.9 + base_tint * 0.12, low * 0.55);
	col += mix(base_tint, vec3(1.0), 0.5) * glints * 0.6;
	a += low * 0.16 * edge + glints * 0.25;

	// ガラスの中の細かな塵（視線に沿って 2 層の奥行き）：ゆっくり漂って、ときどき光る
	if (dust > 0.0) {
		vec3 vo = normalize(to_cam);
		float motes = 0.0;
		for (int i = 0; i < 2; i++) {
			vec3 q = lpos - vo * (0.35 + float(i) * 0.5);
			q += vec3(0.0, TIME * 0.05 * (1.0 + float(i)), 0.0);
			vec3 cell = floor(q * 7.0);
			vec3 fp = fract(q * 7.0) - 0.5;
			vec3 o = hash33(cell + seed * 3.1) - 0.5;
			float d = length(fp - o * 0.6);
			float tw = 0.5 + 0.5 * sin(TIME * (1.5 + hash3(cell) * 2.0) + hash3(cell + 7.0) * 6.28);
			motes += smoothstep(0.07, 0.0, d) * step(0.72, hash3(cell + 1.7)) * tw;
		}
		col += mix(base_tint, vec3(1.0), 0.6) * motes * dust * 0.7;
		a += motes * dust * 0.35;
	}

	// 金の細い筋（おばネコの玉）：経線がゆるくねじれた線
	if (filament > 0.0) {
		float th = atan(lpos.x, lpos.z);
		float f1 = abs(sin(th * 4.0 + lpos.y * 3.2 + sin(lpos.y * 7.0 + seed) * 0.4));
		float f2 = abs(sin(th * 3.0 - lpos.y * 4.0 + 1.3));
		float w = fwidth(th * 4.0) * 1.2 + 0.035;
		float line_v = (1.0 - smoothstep(0.0, w, f1)) + (1.0 - smoothstep(0.0, w * 0.8, f2)) * 0.6;
		float fade = smoothstep(0.1, 0.6, edge) * (0.6 + 0.4 * sin(TIME * 1.1 + lpos.y * 5.0));
		col = mix(col, acc * 1.15, clamp(line_v * fade * filament, 0.0, 1.0) * 0.9);
		a += line_v * fade * filament * 0.35;
	}

	// ひび：ボロノイの境目。crack が増えるほど多くのセルの縁が光る
	if (crack > 0.0) {
		vec2 vd = voronoi_edge(lpos * 3.2);
		// 正面の少し上から走り出して、全体へ広がる（セルごとに少しずつ遅れる）
		float from_hit = acos(clamp(dot(lpos, normalize(vec3(0.25, 0.45, 0.86))), -1.0, 1.0)) / 3.1416;
		float on = step(from_hit * 0.8 + vd.y * 0.35, crack * 1.2);
		float w = fwidth(vd.x) * 1.5 + 0.012;
		float line_c = (1.0 - smoothstep(0.0, w, vd.x)) * on;
		vec3 hot = mix(acc, vec3(1.0, 0.97, 0.88), 0.6);
		col = mix(col, hot * (1.2 + crack), line_c);
		a = max(a, line_c);
		// 割れる直前は、ひびの間のガラスも曇る
		a += crack * crack * 0.25;
		col = mix(col, hot, crack * crack * 0.3);
	}

	// 遠くの玉（すくいの画面の奥）は縁が細すぎて玉に見えないので、殻を少し濃く・縁を明るくする
	float far = smoothstep(2.8, 6.0, length(VERTEX));
	col = mix(col, mix(base_tint, acc, 0.4) * (0.6 + rim), far * 0.5);
	a += far * (0.1 + rim * 0.35);

	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
}
