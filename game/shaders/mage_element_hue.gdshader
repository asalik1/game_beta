shader_type canvas_item;

// Base Mage themes keep each ability's original painted silhouette. Replace
// the colored pixels' hue while preserving their saturation, value, highlights,
// outlines, and alpha so Ice/Wind read as real elemental art rather than a
// differently sized sprite surrounded by a tinted aura.
uniform float target_hue : hint_range(0.0, 1.0) = 0.0;

vec3 rgb_to_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	vec3 hsv = rgb_to_hsv(source.rgb);
	if (source.a > 0.0 && hsv.y > 0.02) {
		hsv.x = target_hue;
	}
	// COLOR is premultiplied on entry. Reusing only its alpha preserves sprite
	// fades without multiplying the texture into itself and darkening the art.
	COLOR = vec4(hsv_to_rgb(hsv), COLOR.a);
}
