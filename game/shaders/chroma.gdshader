shader_type canvas_item;
// Chroma (palette-swap) shader: recolors armor/clothing pixels based on
// a three-stop luminance gradient (primary=dark, trim=mid, accent=light)
// while preserving skin tones and near-black outlines.

uniform float chroma_active : hint_range(0.0, 1.0) = 0.0;
uniform vec3 chroma_primary = vec3(0.1, 0.1, 0.1);
uniform vec3 chroma_trim    = vec3(0.25, 0.25, 0.25);
uniform vec3 chroma_accent  = vec3(0.69, 0.69, 0.69);
// How much of the original color bleeds through (0 = full recolor,
// 1 = original untouched). 0.15 keeps light shading variation.
uniform float original_keep : hint_range(0.0, 1.0) = 0.15;

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	// Skip transparent or inactive
	if (chroma_active < 0.5 || col.a < 0.01) {
		COLOR = col;
		return;
	}

	float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));

	// Preserve near-black outlines
	if (lum < 0.12) {
		COLOR = col;
		return;
	}

	// Preserve skin tones: warm hue (roughly 15-50 deg), moderate
	// saturation, not too dark. In pixel art skin sits in a narrow band.
	vec3 hsv = rgb_to_hsv(col.rgb);
	float hue = hsv.x;    // 0..1 (0 = red, wraps)
	float sat = hsv.y;
	float val = hsv.z;
	// Hue 0.04-0.14 = ~15-50 degrees (peach/tan skin range)
	if (hue > 0.04 && hue < 0.14 && sat > 0.15 && sat < 0.55 && val > 0.45) {
		COLOR = col;
		return;
	}

	// Map luminance to the three-stop chroma gradient
	vec3 chroma_color;
	if (lum < 0.35) {
		chroma_color = mix(chroma_primary, chroma_trim, lum / 0.35);
	} else {
		chroma_color = mix(chroma_trim, chroma_accent, clamp((lum - 0.35) / 0.55, 0.0, 1.0));
	}

	// Blend: keep a fraction of the original art for natural shading
	vec3 result = mix(chroma_color, col.rgb, original_keep);
	COLOR = vec4(result, col.a);
}
