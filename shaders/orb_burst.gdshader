shader_type spatial;
render_mode blend_add, depth_draw_never, depth_test_disabled, cull_disabled, unshaded, shadows_disabled, fog_disabled;

// 玉が割れた瞬間の光：カメラを向いた板に、放射状の光の筋・中心の閃光・広がる輪を描く。
// progress は 0→1（寿命の割合）。strength は明るさ（おばネコは大きく、材料・服は控えめ）。
uniform vec4 color : source_color = vec4(1.0, 0.9, 0.6, 1.0);
uniform float progress = 0.0;
uniform float strength = 1.0;
uniform float rays = 14.0;
uniform float seed = 0.0;

void vertex() {
	// いつもカメラを向く（縮尺はそのまま）
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

float hash(float n) {
	return fract(sin(n * 127.1 + seed * 311.7) * 43758.5453);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float d = length(q);
	float a = atan(q.y, q.x) / 6.2832 + 0.5;
	float p = progress;
	// 放射状の筋：本数分の区間ごとに長さ・太さを変える
	float k = a * rays;
	float id = floor(k);
	float f = fract(k) - 0.5;
	float len = mix(0.45, 1.0, hash(id)) * smoothstep(0.0, 0.25, p);
	float wdt = mix(0.08, 0.22, hash(id + 5.0)) * (1.0 - d * 0.6);
	float ray = (1.0 - smoothstep(0.0, wdt, abs(f))) * (1.0 - smoothstep(len * 0.6, len, d)) * smoothstep(0.0, 0.08, d);
	ray *= 0.7 + 0.3 * sin(TIME * 7.0 + id * 1.7);
	// 中心の閃光
	float core = exp(-d * d * 40.0) * (1.0 - smoothstep(0.0, 0.35, p)) * 1.4;
	float glow_v = exp(-d * d * 10.0) * 0.3;
	// 広がる輪
	float rr = mix(0.1, 0.95, sqrt(p));
	float ring = exp(-pow((d - rr) / 0.035, 2.0)) * (1.0 - p) * 0.9;
	float fade = 1.0 - smoothstep(0.55, 1.0, p);
	vec3 c = color.rgb * (ray * 0.6 * fade + glow_v * fade + ring * 0.7) + vec3(1.0, 0.98, 0.92) * core;
	ALBEDO = c * strength * (1.0 - smoothstep(0.9, 1.0, d));
}
