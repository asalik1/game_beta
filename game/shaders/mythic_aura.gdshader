shader_type canvas_item;

// Mythic skin aura: animated emissive on the sprite's outline ring plus an
// optional interior color push. A chroma can only remap HUE; light and motion
// are the tier language a recolor can't fake, so every mythic carries a
// signature rim glow. Params are data-driven from Skins.AURA (skins.gd);
// applied by Skins.apply_aura on the hero sprite.
uniform float aura_active : hint_range(0.0, 1.0) = 0.0;
uniform vec3 aura_color = vec3(0.4, 0.85, 1.0);
uniform float aura_strength : hint_range(0.0, 1.0) = 0.5;
uniform float pulse_speed = 2.0;
// Slow rim hue rotation in revolutions/sec (prismatic refraction — Crystal
// Archmage). 0 = fixed signature color.
uniform float hue_drift = 0.0;
// Interior push: luminance-shaded mix toward tint_color (a multiply could
// only darken; this shifts hue while keeping the sprite's own shading).
uniform vec3 tint_color = vec3(1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;

vec3 hue_rotate(vec3 c, float a) {
	const vec3 k = vec3(0.57735, 0.57735, 0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float out_a = col.a >= 0.5 ? 1.0 : col.a;
	vec3 rgb = col.rgb;
	if (aura_active >= 0.5 && col.a >= 0.01) {
		float lum = dot(rgb, vec3(0.299, 0.587, 0.114));
		if (tint_amount > 0.001) {
			vec3 tinted = tint_color * (0.35 + 0.85 * lum);
			rgb = mix(rgb, tinted, tint_amount);
		}
		// Outline ring: opaque pixel with a transparent 4-neighbour. Hero
		// strips keep a transparent margin per frame cell, so cross-frame
		// samples still read empty space, not the next frame's body.
		vec2 px = TEXTURE_PIXEL_SIZE;
		float na = min(
			min(texture(TEXTURE, UV + vec2(px.x, 0.0)).a,
				texture(TEXTURE, UV - vec2(px.x, 0.0)).a),
			min(texture(TEXTURE, UV + vec2(0.0, px.y)).a,
				texture(TEXTURE, UV - vec2(0.0, px.y)).a));
		if (col.a >= 0.5 && na < 0.4) {
			vec3 rim = aura_color;
			if (hue_drift > 0.0) {
				rim = hue_rotate(rim, TIME * hue_drift * 6.2831853);
			}
			float pulse = 0.7 + 0.3 * sin(TIME * pulse_speed);
			rgb = mix(rgb, rim, aura_strength * pulse);
		}
	}
	COLOR = vec4(rgb, out_a);
}
