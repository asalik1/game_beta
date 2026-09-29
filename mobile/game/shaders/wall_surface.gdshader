shader_type canvas_item;

uniform vec4 floor_rect;
uniform vec4 lanes[4];
uniform int lane_count = 0;
uniform bool cut_floor = false;
uniform float cap_depth;
uniform vec4 cap_edge : source_color;
uniform vec4 cap_dark : source_color;
uniform bool face = false;
uniform vec2 face_size;
uniform int face_axis = 1;
uniform bool reverse_face = false;
uniform float lip_width;
uniform float ao_width;
uniform vec4 face_top : source_color;
uniform vec4 face_base : source_color;
uniform vec4 face_ao : source_color;
uniform vec4 face_lip : source_color;
varying vec2 world_at;
varying vec2 local_at;

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	local_at = VERTEX;
}

float distance_to_rect(vec2 p, vec4 rect) {
	vec2 outside = max(max(rect.xy - p, p - rect.zw), vec2(0.0));
	return length(outside);
}

void fragment() {
	vec3 shade;
	if (face) {
		float extent = face_axis == 1 ? face_size.y : face_size.x;
		float at = face_axis == 1 ? local_at.y : local_at.x;
		if (reverse_face) { at = extent - at; }
		shade = mix(face_top.rgb, face_base.rgb, clamp(at / extent, 0.0, 1.0));
		shade = mix(shade, face_ao.rgb, smoothstep(extent - ao_width, extent, at));
		if (at < lip_width) { shade = face_lip.rgb; }
	} else {
		float distance = distance_to_rect(world_at, floor_rect);
		for (int i = 0; i < lane_count; i++) {
			distance = min(distance, distance_to_rect(world_at, lanes[i]));
		}
		if (cut_floor && distance <= 0.0) { discard; }
		shade = mix(cap_edge.rgb, cap_dark.rgb, smoothstep(0.0, cap_depth, distance));
	}
	// COLOR already contains the repeated terrain texture and canvas tint.
	COLOR.rgb *= shade;
}
