shader_type canvas_item;

// Phantom spectral charge (owner-designed, 2026-07-24): sustained motion
// bleaches the body toward ghost-white; standing still settles him back
// down. `charge` is driven per-frame by the Phantom's SkinAmbient
// (player_combat.gd): 0 = fully settled, 1 = fully charged.
// Owner spec: settled reads SLIGHTLY darker than the authored sprite,
// full charge reads ALMOST WHITE.
//
// TRAP (bit this shader's first version): in fragment(), COLOR arrives
// already premultiplied (modulate x TEXTURE sample). Writing `result *
// COLOR` multiplies the texture in TWICE and everything darkens — the
// owner saw "only gets darker, never white". Reuse ONLY COLOR.a
// (silhouette.gdshader convention).
uniform float charge : hint_range(0.0, 1.0) = 0.0;
// Extra darkening at full rest; 0 = authored sprite. Owner-set: 30%.
uniform float dark_dip : hint_range(0.0, 1.0) = 0.30;
// Cap on the white blend at full charge. Owner-set: 30%.
uniform float max_light : hint_range(0.0, 1.0) = 0.30;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	vec3 lit = min(vec3(0.90, 0.96, 1.00) * (0.74 + 0.30 * lum), vec3(1.0));
	// The dip fades out as charge rises, so full charge lightens the TRUE
	// authored colors (the rest-darkness must not leak into max lightness).
	vec3 base = t.rgb * (1.0 - dark_dip * (1.0 - charge));
	COLOR = vec4(mix(base, lit, max_light * charge), t.a * COLOR.a);
}
