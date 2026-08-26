shader_type canvas_item;

// Fangmoot token lift: a warm top rim light + a faint cool separation halo so
// the parent game's DARK top-down mob sprites read as sculpted pieces standing
// on a dark board (the #1 "lifts off the floor" fix). COLOR arrives
// PREMULTIPLIED (modulate x texture); we only ADD light and reuse COLOR.a,
// never re-multiply COLOR (the phantom_charge trap). Rim is TOP-biased so it
// stays consistent under flip_h (the left band is mirrored).
uniform vec3 rim_color : source_color = vec3(1.0, 0.82, 0.5);   // warm key light
uniform vec3 sep_color : source_color = vec3(0.55, 0.64, 0.85);  // cool separation
uniform float rim_strength : hint_range(0.0, 2.0) = 0.85;
uniform float sep_strength : hint_range(0.0, 2.0) = 0.30;
uniform float width : hint_range(0.5, 4.0) = 1.6;

void fragment() {
	float a = texture(TEXTURE, UV).a;
	vec2 px = TEXTURE_PIXEL_SIZE * width;
	// directional rim: alpha drops as we step toward the light (up), so the
	// top-facing edge lights up. Vertical => unaffected by flip_h.
	float up = texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	float rim = clamp(a - up, 0.0, 1.0);
	// perimeter separation: bright wherever any 4-neighbour is more transparent
	// than the centre — a thin lighter ring just inside the whole silhouette.
	float a0 = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
	float a1 = texture(TEXTURE, UV - vec2(px.x, 0.0)).a;
	float a2 = texture(TEXTURE, UV + vec2(0.0, px.y)).a;
	float a3 = texture(TEXTURE, UV - vec2(0.0, px.y)).a;
	float amin = min(min(a0, a1), min(a2, a3));
	float sep = clamp(a - amin, 0.0, 1.0);
	COLOR.rgb += (rim * rim_strength * rim_color + sep * sep_strength * sep_color) * COLOR.a;
}
