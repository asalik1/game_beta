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
// Extra darkening at full rest ("slightly darker"); 0 = authored sprite.
uniform float dark_dip : hint_range(0.0, 1.0) = 0.19;

void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	// Pale spectre at full charge (owner dialed back from near-pure white).
	vec3 lit = min(vec3(0.90, 0.96, 1.00) * (0.74 + 0.30 * lum), vec3(1.0));
	vec3 rested = t.rgb * (1.0 - dark_dip);
	COLOR = vec4(mix(rested, lit, charge), t.a * COLOR.a);
}
