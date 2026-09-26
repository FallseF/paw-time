// 顔の線と色（ほっぺ・鼻・ωの口・閉じた目・ひげ・足元の影）を、距離関数で描く小さな板。
// 縁はピクセル幅でなめらかにするので、どの大きさでもくっきり見える。
// 頭の少し内側に置いた曲面に貼り、奥行きだけカメラ側へずらして頭に埋もれないようにする。
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

// 0 ほっぺ（ぼかし） 1 鼻 2 ωの口 3 閉じた目（下向きの弧） 4 ひげ（先細りの線） 5 足元の影
uniform int shape = 0;
uniform vec4 color : source_color = vec4(0.18, 0.13, 0.18, 1.0);
uniform vec4 color2 : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec2 half_size = vec2(0.1, 0.1);  // 板の半分の大きさ（頭の単位）
uniform float stroke = 0.012;
uniform float depth_bias = 0.045;

void vertex() {
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	float d = length(vp.xyz);
	// 奥行きのずらし幅は、置いた先の縮尺に合わせる（小さなおばけで効きすぎない）
	float bias = depth_bias * length(MODEL_MATRIX[0].xyz);
	vp.xyz *= max(d - bias, 0.01) / d;
	POSITION = PROJECTION_MATRIX * vp;
}

float fill(float d) {
	float aa = max(fwidth(d), 1e-5) * 0.85;
	return 1.0 - smoothstep(-aa, aa, d);
}

// 下半分の弧（中心 c・半径 r）までの距離
float lower_arc(vec2 q, vec2 c, float r) {
	vec2 p = q - c;
	if (p.y <= 0.0) {
		return abs(length(p) - r);
	}
	return min(length(p - vec2(r, 0.0)), length(p + vec2(r, 0.0)));
}

float tri_down(vec2 p, float w, float h, float rr) {
	// 下向きの二等辺三角形（上辺の幅 2w、高さ h）を丸めたもの
	p.y = -p.y + h * 0.5;
	p.x = abs(p.x);
	vec2 q = vec2(w, h);
	vec2 a = p - q * clamp(dot(p, q) / dot(q, q), 0.0, 1.0);
	vec2 b = p - q * vec2(clamp(p.x / q.x, 0.0, 1.0), 1.0);
	float k = sign(q.y);
	float d = min(dot(a, a), dot(b, b));
	float s = max(k * (p.x * q.y - p.y * q.x), k * (p.y - q.y));
	return sqrt(d) * sign(s) - rr;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	vec2 q = uv * half_size;
	float a = 0.0;
	vec3 col = color.rgb;
	if (shape == 0) {
		float r = length(uv);
		a = smoothstep(1.0, 0.1, r);
	} else if (shape == 1) {
		float d = tri_down(q, half_size.x * 0.62, half_size.y * 1.05, half_size.y * 0.32);
		a = fill(d);
		// 上のふちに小さな光
		float hl = length((q - vec2(-half_size.x * 0.18, half_size.y * 0.3)) / vec2(half_size.x * 0.22, half_size.y * 0.16)) - 1.0;
		col = mix(col, color2.rgb, fill(hl * half_size.y * 0.2) * 0.8);
	} else if (shape == 2) {
		float r = half_size.x * 0.46;
		vec2 qq = vec2(q.x, q.y * 1.15);
		float d = min(lower_arc(qq, vec2(-r, half_size.y * 0.3), r), lower_arc(qq, vec2(r, half_size.y * 0.3), r));
		a = fill(d - stroke * 0.5);
	} else if (shape == 3) {
		float r = half_size.x * 0.8;
		vec2 qq = vec2(q.x, q.y * 1.6);
		float d = lower_arc(qq, vec2(0.0, half_size.y * 0.55), r);
		a = fill(d - stroke * 0.5);
	} else if (shape == 4) {
		float t = UV.x;
		float wdt = stroke * 0.5 * mix(1.0, 0.25, t);
		float d = abs(q.y) - wdt;
		d = max(d, abs(uv.x) - 0.96);
		a = fill(d);
	} else {
		float r = length(uv);
		a = pow(clamp(1.0 - r, 0.0, 1.0), 1.4);
	}
	ALBEDO = col;
	ALPHA = a * color.a;
}
