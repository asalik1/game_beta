shader_type canvas_item;
render_mode unshaded;

// World-space analytic geometry, not a sampled low-resolution ring. The local
// derivative gives the rim one screen pixel of antialiasing at any camera zoom.
uniform float radius = 80.0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool fill_only = false;
uniform bool orbit_only = false;
uniform float signal_alpha = 1.0;
uniform float rim_width;
uniform float halo_width;
uniform float rim_alpha;
uniform float rim_value;
uniform float halo_alpha;
uniform float sweep_width;
uniform float sweep_alpha;
uniform float head_width;
uniform float tail_turns;
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
		// Reject transparent interior/exterior fragments before angular and
		// exponential work. At two halo widths the old halo was already <0.0024
		// alpha; both contributions are below one 8-bit alpha step. fwidth is
		// computed above, never inside this divergent branch.
		if (edge > halo_width * 2.0 + aa) {
			discard;
		}
		float turn = mod(atan(local_position.y, local_position.x) / TAU + 0.25 + 1.0, 1.0);
		float behind = mod(progress - turn + 1.0, 1.0);
		float angular_aa = aa / max(radius, aa) / TAU;
		float completed = 1.0 - smoothstep(progress - angular_aa,
			progress + angular_aa, turn);
		if (progress <= 0.0 || orbit_only) {
			completed = 0.0;
		}
		float tail = pow(max(0.0, 1.0 - behind / tail_turns), 1.7);
		if (!orbit_only && turn > progress) {
			tail = 0.0;
		}
		float rim = 1.0 - smoothstep(rim_width * 0.5, rim_width * 0.5 + aa, edge);
		float halo = exp(-pow(edge / halo_width, 2.0));
		float sweep = (1.0 - smoothstep(sweep_width * 0.5,
			sweep_width * 0.5 + aa, edge)) * completed;
		float tail_width = head_width * sqrt(tail);
		float trail = (1.0 - smoothstep(tail_width * 0.5,
			tail_width * 0.5 + aa, edge)) * tail;
		vec2 head_axis = vec2(cos(progress * TAU - TAU * 0.25),
			sin(progress * TAU - TAU * 0.25));
		vec2 head_delta = local_position - head_axis * radius;
		vec2 head_uv = vec2(dot(head_delta, head_axis),
			dot(head_delta, vec2(-head_axis.y, head_axis.x))) / head_width;
		float spark = exp(-dot(head_uv, head_uv) * 2.0);
		float spark_glow = exp(-dot(head_uv, head_uv) * 0.3);
		float lit = max(sweep * sweep_alpha, max(trail, spark)) * signal_alpha;
		alpha = max(rim * rim_alpha, halo * halo_alpha);
		alpha = max(alpha, lit);
		alpha = max(alpha, spark_glow * halo_alpha * signal_alpha);
		vec3 hot = mix(tint.rgb, vec3(1.0, 0.96, 0.85), 0.7);
		// A thin, saturated chromatic core survives pale ice and lava glow.
		// The soft halo keeps its original tint; no black keyline is added.
		vec3 base = mix(tint.rgb, tint.rgb * rim_value, rim);
		color = mix(base, hot, clamp(lit, 0.0, 1.0));
	}
	// Polygon2D has no texture. COLOR is only its incoming canvas modulation;
	// do not multiply a texture sample into the analytic edge a second time.
	COLOR = vec4(color, clamp(alpha, 0.0, 1.0) * COLOR.a);
}
