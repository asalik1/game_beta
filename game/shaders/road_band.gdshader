shader_type canvas_item;

// A room's worn ROAD, drawn once over the crisp floor (gameplay-polish
// 2026-08-18). The union of up to 6 axis-aligned arm rects (room-local px:
// xy = position, zw = size) with rounded corners, a FEATHERED edge that
// wanders with a noise field, and a mottled interior — so the walkway reads
// as trodden ground instead of the hard-edged tint rectangle the old
// _mark_roads sprite laid down (one of the "beta / RuneScape" tells in the
// trailer footage). Being ONE quad, the arms never double up where they
// cross. Colour is a uniform (the path kind's palette colour); strength rides
// the node's modulate.a — reuse ONLY COLOR.a per the silhouette convention.
// Each arm bends along a seeded wave that settles to the straight lane at the
// junction, the doorways and any pinned crossing. game_world.road_curve()
// MIRRORS the centreline math below (scenery clearance uses it): change both.
uniform int arm_count = 0;
uniform vec4 arms[6];
uniform float arm_offsets[6];
uniform vec2 arm_doors[6];         // px the stone rim runs past each end (start, end)
uniform int pin_count = 0;
uniform vec4 pins[4];              // x: 0 east-west / 1 north-south arms; y..z: straight span
uniform float pin_settle_px = 1.0;
uniform float room_seed = 0.0;
uniform float meander_px = 0.0;
uniform float meander_cycles = 0.0;
uniform float width_variation = 0.0;
uniform float door_settle_px = 1.0;
uniform vec4 play_bounds;
uniform float stone_edge_px = 0.0;
uniform float stone_edge_darken = 0.0;
uniform vec2 room_size = vec2(2112.0, 1248.0);
uniform vec3 path_color : source_color = vec3(0.4, 0.3, 0.2);
uniform float feather = 34.0;      // px of soft edge
uniform float wobble = 22.0;       // px the edge wanders
uniform float corner = 40.0;       // rounded corner radius per arm
uniform float mottle = 0.22;       // interior alpha variation (0 = flat)
uniform float noise_scale = 0.0045;
uniform sampler2D noise_tex : repeat_enable, filter_linear;

float sd_box(vec2 p, vec2 c, vec2 h, float r) {
	vec2 d = abs(p - c) - h + vec2(r);
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * room_size;
	float n = texture(noise_tex, p * noise_scale).r - 0.5;
	float inside = -1e6;
	float inside_rim = -1e6;
	for (int i = 0; i < arm_count; i++) {
		vec4 a = arms[i];
		bool horizontal = a.z > a.w;
		float along = horizontal ? p.x : p.y;
		float start = horizontal ? a.x : a.y;
		float span = horizontal ? a.z : a.w;
		float t = clamp((along - start) / span, 0.0, 1.0);
		float door_start = horizontal ? play_bounds.x : play_bounds.y;
		float door_end = horizontal ? play_bounds.z : play_bounds.w;
		// Pin both the arm junction and the actual inset door lanes. Outside
		// the playable room the connecting corridor stays centred as before.
		float envelope = sin(t * 3.14159265) * smoothstep(0.0, door_settle_px,
			min(along - door_start, door_end - along));
		// Crossings (a river's bridge, an arcade's arch) hold the straight lane.
		float axis = horizontal ? 0.0 : 1.0;
		for (int k = 0; k < pin_count; k++) {
			vec4 pin = pins[k];
			if (abs(pin.x - axis) < 0.5) {
				envelope *= smoothstep(0.0, pin_settle_px, max(pin.y - along, along - pin.z));
			}
		}
		float phase = room_seed + arm_offsets[i];
		float wave = sin(t * 6.28318531 * meander_cycles + phase);
		vec2 q = p;
		vec2 half_size = a.zw * 0.5;
		float width_scale = 1.0 + width_variation * envelope * cos(t * 6.28318531 + phase);
		if (horizontal) {
			q.y -= meander_px * envelope * wave;
			half_size.y *= width_scale;
		} else {
			q.x -= meander_px * envelope * wave;
			half_size.x *= width_scale;
		}
		vec2 c = a.xy + a.zw * 0.5;
		float r = min(corner, min(a.z, a.w) * 0.45);
		inside = max(inside, -sd_box(q, c, half_size, r));
		// The laid-stone rim follows the long sides only: a doorway end is
		// stretched past the quad, so its end cap never lays a bar across it.
		vec2 open = arm_doors[i];
		vec2 reach = horizontal ? vec2(open.x + open.y, 0.0) : vec2(0.0, open.x + open.y);
		vec2 shift = horizontal ? vec2(open.y - open.x, 0.0) : vec2(0.0, open.y - open.x);
		inside_rim = max(inside_rim, -sd_box(q, c + shift * 0.5, half_size + reach * 0.5, r));
	}
	float edge = inside + n * wobble * 2.0;
	float cov = smoothstep(0.0, feather, edge);
	float m = 1.0 - mottle * texture(noise_tex, p * noise_scale * 3.3 + vec2(0.37, 0.71)).r;
	// A narrow inset border along the UNION's sides, never across a junction.
	float edge_rim = inside_rim + n * wobble * 2.0;
	float rim = step(feather, edge_rim) * (1.0 - smoothstep(feather, feather + max(stone_edge_px, 1.0), edge_rim));
	if (stone_edge_px <= 0.0) { rim = 0.0; }
	COLOR = vec4(path_color * (1.0 - rim * stone_edge_darken), cov * m * COLOR.a);
}
