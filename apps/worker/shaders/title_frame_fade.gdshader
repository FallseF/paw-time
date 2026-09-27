// タイトルの縦の枠（3D の絵）を重ねるとき、左右のふちを fade（枠の幅に対する割合）だけ透明へぼかす。
// 3D は透明の背景に描いてあるので、色は透明度を掛けた状態（premultiplied）で重ねる。
shader_type canvas_item;
render_mode blend_premul_alpha;

uniform float fade = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (fade > 0.0) {
		float e = min(UV.x, 1.0 - UV.x);
		c *= smoothstep(0.0, fade, e);
	}
	COLOR = c;
}
