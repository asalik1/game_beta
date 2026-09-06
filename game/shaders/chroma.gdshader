shader_type canvas_item;

uniform float chroma_active : hint_range(0.0, 1.0) = 0.0;
uniform vec3 chroma_primary = vec3(0.1, 0.1, 0.1);
uniform vec3 chroma_trim    = vec3(0.25, 0.25, 0.25);
uniform vec3 chroma_accent  = vec3(0.69, 0.69, 0.69);
uniform float original_keep : hint_range(0.0, 1.0) = 0.08;
// The body colour the game paints on the sprite (rage / downed / ghost). It
// CANNOT ride on the node's modulate here: this shader replaces the texture
// RGB outright, and modulate.rgb is unrecoverable from the premultiplied input
// (dividing it back out explodes on near-black texels -- see the canvas_item
// trap in CLAUDE.md, "reuse ONLY COLOR.a"). So the CPU writes it here instead
// whenever this material is live. 1,1,1 = untinted.
uniform vec3 body_tint = vec3(1.0);

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
	float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	vec3 hsv = rgb_to_hsv(col.rgb);
	float hue = hsv.x;
	float sat = hsv.y;
	float val = hsv.z;

	bool is_active = chroma_active >= 0.5;
	bool is_opaque = col.a >= 0.01;
	bool is_warm_skin = hue > 0.02 && hue < 0.14 && sat > 0.08 && sat < 0.55 && val > 0.20;
	bool is_alpha_masked = col.a > 0.995 && col.a < 0.999;
	bool is_protected = is_warm_skin || is_alpha_masked;

	// Incoming COLOR is PREMULTIPLIED (modulate x TEXTURE), so the node's
	// modulate.a is COLOR.a / col.a -- recover it or every fade the game runs on
	// this sprite (ghost 0.4, downed 0.85, hurt flash) is silently dropped.
	float mod_a = col.a > 0.001 ? COLOR.a / col.a : 0.0;
	float out_a = (col.a >= 0.5 ? 1.0 : col.a) * mod_a;

	if (is_active && is_opaque && !is_protected) {
		vec3 chroma_color;
		if (lum < 0.5) {
			chroma_color = mix(chroma_primary, chroma_trim, lum * 2.0);
		} else {
			chroma_color = mix(chroma_trim, chroma_accent, (lum - 0.5) * 2.0);
		}
		float chroma_lum = dot(chroma_color, vec3(0.299, 0.587, 0.114));
		if (chroma_lum > 0.001) {
			chroma_color = min(chroma_color * (lum / chroma_lum), vec3(1.0));
		}
		vec3 result = mix(chroma_color, col.rgb, original_keep);
		COLOR = vec4(result * body_tint, out_a);
	} else {
		COLOR = vec4(col.rgb * body_tint, out_a);
	}
}
