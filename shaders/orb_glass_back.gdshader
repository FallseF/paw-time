shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_front, unshaded, shadows_disabled, fog_disabled;

// 玉のガラスの殻（内側から見た奥の面）。中身の後ろにだけ見える、うっすら色のついた奥の壁と、
// 奥の縁の細い光（ガラスの厚み）。中身は不透明なので、中身の後ろは深度で隠れる。

uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform vec4 accent : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform vec4 pond : source_color = vec4(0.1, 0.2, 0.42, 1.0);

void fragment() {
	// 奥の面の法線は内向き。視線との角度で、奥の縁ほど明るく
	float ndv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = 1.0 - ndv;
	vec3 wn = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	// 奥の底には池の色が溜まる
	float low = smoothstep(0.1, 0.8, wn.y);
	vec3 col = mix(tint.rgb * 0.55, accent.rgb, smoothstep(0.5, 0.95, edge) * 0.6);
	col = mix(col, pond.rgb, low * 0.5);
	ALBEDO = col;
	ALPHA = 0.06 + smoothstep(0.55, 0.98, edge) * 0.22 + low * 0.08;
}
