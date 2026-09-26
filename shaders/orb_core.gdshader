shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded;

// 玉の中で渦を巻く光。rare なら虹色が流れる。中心ほど明るく、縁はやわらかく消える。
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
	for (int i = 0; i < 4; i++) {
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
	lpos = VERTEX;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float facing = clamp(dot(n, v), 0.0, 1.0);
	float t = TIME * 0.35 + seed;
	// ゆっくり回る渦
	float ang = t * 1.3;
	mat2 r = mat2(vec2(cos(ang), -sin(ang)), vec2(sin(ang), cos(ang)));
	vec3 p = lpos * 5.0;
	p.xz = r * p.xz;
	float swirl = fbm(p + vec3(0.0, t, 0.0));
	float wisps = smoothstep(0.45, 0.9, fbm(p * 1.7 - vec3(t * 0.8, 0.0, t)));
	vec3 base = glow.rgb;
	if (rare > 0.5) {
		base = mix(hue(fract(swirl * 0.8 + t * 0.15)), vec3(1.0), 0.25);
	}
	float core = pow(facing, 2.2);
	vec3 col = base * (core * (0.6 + swirl * 0.8) + wisps * 0.55);
	// 小さな星（レアは多め）
	float star = step(0.985 - rare * 0.01, noise(lpos * 60.0 + vec3(0.0, 0.0, floor(TIME * 3.0 + seed))));
	col += vec3(1.0) * star * (0.6 + rare);
	ALBEDO = col * energy;
}
