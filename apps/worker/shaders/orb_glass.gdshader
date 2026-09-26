shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

// 玉のガラスの殻。縁ほど光り、2つのハイライトと、下からの照り返しが入る。
uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform float rim_power = 2.2;
uniform float time_offset = 0.0;

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float fres = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), rim_power);
	// 左上の大きなハイライトと、右下の小さなハイライト（ビュー空間の法線で決める）
	float h1 = smoothstep(0.93, 0.985, dot(n, normalize(vec3(-0.45, 0.6, 0.66))));
	float h2 = smoothstep(0.975, 0.995, dot(n, normalize(vec3(0.5, -0.35, 0.8))));
	// 下からの照り返し（水面の色）
	float bounce = smoothstep(0.2, -0.8, n.y) * 0.35;
	vec3 col = tint.rgb * (0.25 + fres * 1.4) + vec3(1.0) * (h1 * 0.95 + h2 * 0.5) + tint.rgb * bounce;
	ALBEDO = col;
	ALPHA = clamp(0.12 + fres * 0.75 + h1 * 0.9 + h2 * 0.6, 0.0, 1.0);
}
