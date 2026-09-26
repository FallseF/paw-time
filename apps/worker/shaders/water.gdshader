shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled;

// 夜の川の水面。深い藍色に、ゆらぐ光の筋と灯りの映り込み、ポイの波紋を重ねる。

uniform vec4 deep : source_color = vec4(0.04, 0.08, 0.2, 1.0);
uniform vec4 shallow : source_color = vec4(0.1, 0.22, 0.4, 1.0);
uniform vec4 glint : source_color = vec4(1.0, 0.85, 0.55, 1.0);
uniform vec3 ripple_pos = vec3(100.0, 0.0, 100.0);
uniform float ripple_t = 10.0;
uniform vec3 lamp_a = vec3(-2.2, 0.0, -1.6);
uniform vec3 lamp_b = vec3(2.3, 0.0, -2.2);
uniform vec4 orb_pos[6];
uniform vec4 orb_col[6];

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float waves(vec2 p, float t) {
	float w = 0.0;
	w += sin(p.x * 3.1 + t * 1.3) * 0.5;
	w += sin(p.y * 4.3 - t * 1.1 + p.x * 1.7) * 0.35;
	w += sin((p.x + p.y) * 7.0 + t * 2.1) * 0.15;
	return w;
}

void fragment() {
	vec2 p = wpos.xz;
	float t = TIME;
	float w = waves(p, t);
	float edge = smoothstep(3.2, 1.2, length(p * vec2(0.9, 0.75)));
	vec3 col = mix(deep.rgb, shallow.rgb, edge * 0.6 + w * 0.08);

	// 光の筋
	float streak = smoothstep(0.82, 1.0, sin(p.x * 9.0 + w * 2.0 + t * 0.6) * sin(p.y * 6.0 - t * 0.4));
	col += glint.rgb * streak * 0.12;

	// 灯りの映り込み（縦に伸びる）
	for (int i = 0; i < 2; i++) {
		vec3 l = i == 0 ? lamp_a : lamp_b;
		vec2 d = p - l.xz;
		float r = exp(-d.x * d.x * 18.0 - (d.y - 0.6) * (d.y - 0.6) * 1.2);
		r *= 0.75 + 0.25 * sin(p.y * 22.0 + w * 3.0 - t * 3.0);
		col += glint.rgb * r * 0.55;
	}

	// 玉の映り込み
	for (int i = 0; i < 6; i++) {
		vec2 d = p - orb_pos[i].xz;
		float g = exp(-dot(d, d) * 9.0) * orb_pos[i].w;
		float shimmer = 0.8 + 0.2 * sin(p.y * 30.0 + w * 4.0 - t * 4.0);
		col += orb_col[i].rgb * g * 0.9 * shimmer;
		col += orb_col[i].rgb * exp(-d.x * d.x * 40.0 - (d.y - 0.35) * (d.y - 0.35) * 6.0) * 0.35 * orb_pos[i].w;
	}

	// ポイの波紋
	float rd = length(p - ripple_pos.xz);
	float ring = sin(rd * 26.0 - ripple_t * 9.0) * exp(-rd * 2.2) * exp(-ripple_t * 1.6);
	col += vec3(0.6, 0.8, 1.0) * max(ring, 0.0) * 0.5;

	ALBEDO = col;
	ALPHA = 0.93;
}
