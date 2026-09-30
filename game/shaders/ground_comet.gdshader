shader_type canvas_item;
render_mode unshaded;

// World-space analytic geometry, not a sampled low-resolution ring. The local
// derivative gives the rim one screen pixel of antialiasing at any camera zoom.
uniform float radius = 80.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool fill_only = false;
uniform float signal_alpha = 1.0;
uniform float rim_width;
uniform float halo_width;
uniform float rim_alpha;
uniform float rim_value;
uniform float halo_alpha;
uniform float band_width;
uniform float band_alpha;
uniform float fill_alpha;
varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	float distance_from_center = length(local_position);
	float aa = max(fwidth(distance_from_center), 0.001);
	float edge = abs(distance_from_center - radius);
	float alpha;
	vec3 color;
	if (fill_only) {
		alpha = (1.0 - smoothstep(radius - aa, radius + aa,
			distance_from_center)) * fill_alpha;
		color = COLOR.rgb;
	} else {
		// Reject transparent interior/exterior fragments before halo
		// exponential work. At two halo widths the old halo was already <0.0024
		// alpha; both contributions are below one 8-bit alpha step. fwidth is
		// computed above, never inside this divergent branch. The inner band
		// (band_width) stays well inside that distance.
		if (edge > halo_width * 2.0 + aa) {
			discard;
		}
		float rim = 1.0 - smoothstep(rim_width * 0.5, rim_width * 0.5 + aa, edge);
		float halo = exp(-pow(edge / halo_width, 2.0));
		float inside = radius - distance_from_center;
		float band = smoothstep(-aa, aa, inside)
			* (1.0 - smoothstep(band_width - aa, band_width + aa, inside));
		// Urgency is uniform around the entire footprint. No angular time read.
		// A thin, dark chromatic keyline marks the exact boundary on pale ice
		// and lava glow alike; the colored band just inside it and the soft
		// halo carry the pale-to-bold urgency color.
		alpha = max(max(rim * rim_alpha, band * band_alpha), halo * halo_alpha) * signal_alpha;
		color = mix(tint.rgb, tint.rgb * rim_value, rim);
	}
	// Polygon2D has no texture. COLOR is only its incoming canvas modulation;
	// do not multiply a texture sample into the analytic edge a second time.
	COLOR = vec4(color, clamp(alpha, 0.0, 1.0) * COLOR.a);
}
