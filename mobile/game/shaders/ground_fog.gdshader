// Low GROUND FOG (atmosphere pass 2026-08-19): one room-sized quad over the
// floor layers, under the actors. Two octaves of the shared noise texture
// drift in different directions; the mix is thresholded into soft banks and
// faded at the room's edges so it never cuts hard at a wall. Alpha is the
// whole mood knob (Balance.GROUND_FOG_A) — banks should read on a second look,
// never as a white sheet. Misty terrains only (ambient preset "mist").
shader_type canvas_item;

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec2 room_size = vec2(2112.0, 1248.0);
uniform float alpha : hint_range(0.0, 1.0) = 0.14;
uniform float scale_px = 420.0;     // world px per noise tile
uniform float speed = 0.018;        // drift, tiles per second
uniform vec4 tint : source_color = vec4(0.86, 0.89, 0.92, 1.0);

void fragment() {
	vec2 p = UV * room_size / scale_px;
	float t = TIME * speed;
	float n1 = texture(noise_tex, p + vec2(t, t * 0.35)).r;
	float n2 = texture(noise_tex, p * 0.57 - vec2(t * 0.7, -t * 0.22) + vec2(0.37, 0.61)).r;
	float n3 = texture(noise_tex, p * 1.9 + vec2(-t * 0.4, t * 0.5)).r;
	float f = smoothstep(0.38, 0.86, n1 * 0.55 + n2 * 0.35 + n3 * 0.10);
	vec2 e = smoothstep(0.0, 0.05, UV) * smoothstep(0.0, 0.05, 1.0 - UV);
	COLOR = vec4(tint.rgb, f * alpha * e.x * e.y);
}
