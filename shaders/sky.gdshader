shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;

// 夜空のグラデーション（上は深い藍、地平線はほんのり紫と灯り色）
uniform vec4 top_col : source_color = vec4(0.03, 0.05, 0.14, 1.0);
uniform vec4 mid_col : source_color = vec4(0.10, 0.10, 0.28, 1.0);
uniform vec4 low_col : source_color = vec4(0.30, 0.20, 0.36, 1.0);

void fragment() {
	float y = UV.y; // 0 = 上, 1 = 下
	vec3 c = mix(top_col.rgb, mid_col.rgb, smoothstep(0.0, 0.6, y));
	c = mix(c, low_col.rgb, smoothstep(0.55, 1.0, y));
	ALBEDO = c;
}
