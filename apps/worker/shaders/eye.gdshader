// つやのある目。上が濃く下が少し明るい黒目に、大小ふたつのキャッチライトと、下側の淡い映り込み。
// メッシュは半径 radius の球（正面 +Z）。まばたきで縦につぶれたら、光を消す。
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled, fog_disabled;

uniform vec4 iris_top : source_color = vec4(0.13, 0.09, 0.14, 1.0);
uniform vec4 iris_bottom : source_color = vec4(0.36, 0.24, 0.32, 1.0);
uniform vec4 glint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float radius = 0.07;
uniform float rest_ratio = 1.5;  // ふだんの 縦/横 の縮尺

varying vec3 v_p;
varying float v_open;

void vertex() {
	v_p = VERTEX / radius;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	v_open = clamp((sy / max(sx, 1e-4)) / rest_ratio, 0.0, 1.0);
}

float disc(vec2 p, vec2 c, vec2 r) {
	float d = length((p - c) / r) - 1.0;
	float aa = fwidth(d) * 1.2;
	return 1.0 - smoothstep(-aa, aa, d);
}

void fragment() {
	vec2 p = v_p.xy;
	float g = smoothstep(-0.9, 0.7, p.y);
	vec3 col = mix(iris_bottom.rgb, iris_top.rgb, g);
	// 縁を少し締める
	col *= mix(0.78, 1.0, 1.0 - smoothstep(0.55, 1.0, length(p)));
	// 下の淡い映り込み（三日月）
	float cres = disc(p, vec2(0.0, -0.18), vec2(0.78, 0.7)) * (1.0 - disc(p, vec2(0.0, 0.02), vec2(0.8, 0.78)));
	col = mix(col, mix(iris_bottom.rgb, glint.rgb, 0.45), cres * 0.2);
	float vis = smoothstep(0.45, 0.8, v_open);
	float big = disc(p, vec2(0.28, 0.4), vec2(0.25, 0.22));
	float small = disc(p, vec2(-0.3, -0.36), vec2(0.1, 0.09));
	col = mix(col, glint.rgb, max(big, small * 0.9) * vis);
	ALBEDO = col;
}
