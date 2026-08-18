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
uniform int arm_count = 0;
uniform vec4 arms[6];
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
	for (int i = 0; i < arm_count; i++) {
		vec4 a = arms[i];
		float d = sd_box(p, a.xy + a.zw * 0.5, a.zw * 0.5, min(corner, min(a.z, a.w) * 0.45));
		inside = max(inside, -d);
	}
	float edge = inside + n * wobble * 2.0;
	float cov = smoothstep(0.0, feather, edge);
	float m = 1.0 - mottle * texture(noise_tex, p * noise_scale * 3.3 + vec2(0.37, 0.71)).r;
	COLOR = vec4(path_color, cov * m * COLOR.a);
}
