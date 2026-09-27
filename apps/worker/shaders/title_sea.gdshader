// タイトルの夕方の海。島の画面の海（半透明の青緑）と同じ色味を、夕日の側へ寄せる。
// 近くは少し透けて浅瀬の砂が見え、遠くほど空の映り込みと水平線のもやに溶ける。
// 太陽は島の向こうの低い位置（sun_dir）。その方向にだけ、細かいきらめきの道ができる。
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 near_col : source_color = vec4(0.34, 0.55, 0.62, 1.0);
uniform vec4 far_col : source_color = vec4(0.48, 0.56, 0.68, 1.0);
uniform vec4 sky_col : source_color = vec4(0.80, 0.70, 0.80, 1.0);
uniform vec4 horizon_col : source_color = vec4(0.97, 0.73, 0.64, 1.0);
uniform vec4 sun_col : source_color = vec4(1.0, 0.86, 0.62, 1.0);
uniform vec3 sun_dir = vec3(0.6, 0.12, -0.8);
uniform float haze_start = 30.0;
uniform float haze_end = 260.0;
uniform float near_alpha : hint_range(0.0, 1.0) = 0.8;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// ゆるいうねり（高さの傾き）。遠くでは細かい波を消して、ちらつかせない
vec2 slope(vec2 p, float t, float fade) {
	vec2 g = vec2(0.0);
	g += vec2(0.9, 0.35) * cos(p.x * 0.9 + p.y * 0.35 + t * 0.55) * 0.05;
	g += vec2(-0.3, 1.1) * cos(-p.x * 0.3 + p.y * 1.1 + t * 0.7) * 0.04;
	g += vec2(2.3, 1.7) * cos(p.x * 2.3 + p.y * 1.7 - t * 1.1) * 0.018 * fade;
	g += vec2(-3.1, 4.2) * cos(-p.x * 3.1 + p.y * 4.2 + t * 1.4) * 0.01 * fade;
	return g;
}

void fragment() {
	vec3 to_cam = CAMERA_POSITION_WORLD - wpos;
	float dist = length(to_cam.xz);
	vec3 v = normalize(to_cam);
	float fade = 1.0 - smoothstep(8.0, 40.0, dist);
	vec2 g = slope(wpos.xz, TIME, fade) * mix(0.35, 1.0, fade);
	vec3 n = normalize(vec3(-g.x, 1.0, -g.y));
	float fres = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 4.0);
	vec3 col = mix(near_col.rgb, far_col.rgb, smoothstep(4.0, 60.0, dist));
	col = mix(col, sky_col.rgb, clamp(fres * 0.6, 0.0, 0.5));
	// 夕日の道：映った太陽の方向に近いほど、細かく明るく
	vec3 r = reflect(-v, n);
	float toward = max(dot(r, normalize(sun_dir)), 0.0);
	col += sun_col.rgb * (pow(toward, 1400.0) * 0.55 + pow(toward, 90.0) * 0.06);
	// 水平線のもや（空の水平線の色へ）
	float haze = smoothstep(haze_start, haze_end, dist);
	col = mix(col, horizon_col.rgb, pow(haze, 0.7));
	ALBEDO = col;
	ALPHA = mix(near_alpha, 1.0, smoothstep(5.0, 25.0, dist));
}
