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
uniform float ramp_soft : hint_range(0.01, 1.0) = 0.45;
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
uniform float top_light : hint_range(0.0, 0.5) = 0.07;

varying float v_ao;
varying float v_ear;
varying float v_up;

void vertex() {
	v_ao = COLOR.r;
	v_ear = 1.0 - COLOR.g;
	v_up = (MODEL_NORMAL_MATRIX * NORMAL).y;
}

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec3 alb = base_color.rgb * texture(albedo_tex, UV).rgb;
	alb = mix(alb, inner_color.rgb, clamp(v_ear * 1.6, 0.0, 1.0));
	// 上を向いた面ほどわずかに明るく（空からの光）
	alb *= 1.0 + top_light * v_up;
	// AO は暗くするだけでなく、影の色へ寄せる
	float ao = mix(1.0, v_ao, ao_strength);
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
	vec3 shade_lit = light_tint.rgb * (0.86 + 0.14 * w);
	vec3 shade = mix(shade_dark, shade_lit, lit);
	// 明暗の境目の赤み（光が中を透けてくる感じ）
	float term = exp(-pow((w - ramp_center) / (ramp_soft * 0.9), 2.0));
	shade += sss_color.rgb * term * sss_strength;
	// 落ち影（ATTENUATION）は光の全体に掛ける。影の中は環境光だけになる
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * shade * ATTENUATION;
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
