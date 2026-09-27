shader_type spatial;
render_mode blend_add, depth_draw_never, cull_front, unshaded, shadows_disabled, fog_disabled;

// 玉の中の光。中身を塗りつぶす明るい球ではなく、中身の「後ろ」でゆらめく霧の渦。
// 奥半分（cull_front）だけを描くので、中身は光の前に浮かんで見え、形と色が読める。
// 中心ほど淡く、奥の縁に沿って渦が回る。rare なら虹色が流れる。
uniform vec4 glow : source_color = vec4(1.0, 0.8, 0.4, 1.0);
uniform float rare = 0.0;
uniform float energy = 1.6;
uniform float seed = 0.0;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
				   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
				   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

vec3 hue(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

varying vec3 lpos;

void vertex() {
	lpos = normalize(VERTEX);
}

void fragment() {
	float ndv = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float t = TIME * 0.3 + seed;
	float ang = t * 1.2;
	mat2 r = mat2(vec2(cos(ang), -sin(ang)), vec2(sin(ang), cos(ang)));
	vec3 p = lpos * 1.6;
	p.xz = r * p.xz;
	float swirl = fbm(p + vec3(0.0, t, 0.0));
	float wisps = smoothstep(0.38, 0.8, fbm(p * 1.4 - vec3(t * 0.7, 0.0, t)));
	vec3 base = glow.rgb;
	if (rare > 0.5) {
		base = mix(hue(fract(swirl * 0.8 + t * 0.15)), vec3(1.0), 0.3);
	}
	// 中心（中身の真後ろ）はやわらかい後光、縁に近いほど霧の渦
	// 遠くの玉は、中身の後ろの光を広く強めて「光る玉」に見せる
	float far = smoothstep(2.8, 6.0, length(VERTEX));
	float halo = pow(ndv, mix(1.2, 0.6, far)) * (0.85 + far * 0.6);
	float ring = smoothstep(0.0, 0.5, 1.0 - ndv) * smoothstep(1.0, 0.75, 1.0 - ndv);
	vec3 col = base * (halo * (0.7 + swirl * 0.35) + ring * wisps * 0.6 + wisps * 0.1);
	// 光が強まっても白く飛ばないよう、やわらかく頭打ちにする
	ALBEDO = col * (1.0 - exp(-energy * 0.4)) * 1.15;
}
